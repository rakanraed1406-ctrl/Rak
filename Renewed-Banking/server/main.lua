local QBCore = exports['qb-core']:GetCoreObject()

local cachedAccounts = {}   -- org / shared / extra personal accounts, keyed by account id
local cachedPlayers = {}    -- default personal account data, keyed by citizenid
local ibanIndex = {}        -- IBAN -> account id (or citizenid for default personal accounts)
local sessions = {}         -- [source] = { mode = 'bank' | 'atm', card = { account, restricted, slot } }
local busy = {}             -- [source] = true while one of their bank actions is running
local pendingCards = {}     -- [citizenid] = { account, iban, holder, version, readyAt }
local pinFails = {}         -- ["account:version"] = { count, lockedUntil }
local nameCache = {}        -- citizenid -> "Firstname Lastname"
local accountsReady = false

-- =========================================================================
-- Generic helpers
-- =========================================================================

local function notify(src, msg, kind)
    if not msg then return end
    TriggerClientEvent('Renewed-Banking:client:sendNotification', src, msg, kind or 'error')
end

local function fmtMoney(amount)
    local formatted = tostring(math.floor(tonumber(amount) or 0))
    local k
    repeat
        formatted, k = formatted:gsub('^(-?%d+)(%d%d%d)', '%1,%2')
    until k == 0
    return '$' .. formatted
end

local function decodeJson(str, default)
    if type(str) == 'table' then return str end
    if type(str) ~= 'string' or str == '' then return default end
    local ok, res = pcall(json.decode, str)
    if ok and type(res) == 'table' then return res end
    return default
end

local function fullName(Player)
    local info = Player.PlayerData.charinfo or {}
    return ('%s %s'):format(info.firstname or '', info.lastname or '')
end

-- Whole dollars only, positive, below the configured cap. Blocks negative,
-- fractional, NaN and inf amounts (the classic money-dupe payloads).
local function cleanAmount(value)
    local n = tonumber(value)
    if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
    n = math.floor(n)
    if n < 1 or n > config.maxTransactionAmount then return nil end
    return n
end

-- Strips control characters / angle brackets and truncates (UTF-8 safe,
-- so Arabic text is never cut in the middle of a character).
local function cleanText(value, max)
    if type(value) ~= 'string' and type(value) ~= 'number' then return '' end
    local str = tostring(value):gsub('[%c<>]', '')
    str = str:gsub('^%s+', ''):gsub('%s+$', '')
    if utf8.len(str) then
        if utf8.len(str) > max then str = str:sub(1, utf8.offset(str, max + 1) - 1) end
    elseif #str > max then
        str = str:sub(1, max)
    end
    return str
end

local function getTimeElapsed(seconds)
    local minutes = math.floor(seconds / 60)
    local hours = math.floor(minutes / 60)
    local days = math.floor(hours / 24)
    local weeks = math.floor(days / 7)

    if weeks > 1 then return Lang:t('time.weeks', {time = weeks}) end
    if weeks == 1 then return Lang:t('time.aweek') end
    if days > 1 then return Lang:t('time.days', {time = days}) end
    if days == 1 then return Lang:t('time.aday') end
    if hours > 1 then return Lang:t('time.hours', {time = hours}) end
    if hours == 1 then return Lang:t('time.ahour') end
    if minutes > 1 then return Lang:t('time.mins', {time = minutes}) end
    if minutes == 1 then return Lang:t('time.amin') end
    return Lang:t('time.secs')
end

local function genTransactionID()
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return (string.gsub(template, '[xy]', function(c)
        local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
        return string.format('%x', v)
    end))
end

local function waitUntilReady()
    local tries = 0
    while not accountsReady and tries < 150 do
        Wait(100)
        tries = tries + 1
    end
    return accountsReady
end

-- Generates a unique display IBAN, e.g. "B617521932" (1 letter + 9 digits).
local function genIBAN()
    local letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ'
    for _ = 1, 25 do
        local idx = math.random(1, #letters)
        local iban = letters:sub(idx, idx) .. tostring(math.random(100000000, 999999999))
        if not ibanIndex[iban] then
            local taken = MySQL.scalar.await('SELECT 1 FROM player_transactions WHERE iban = ? UNION SELECT 1 FROM bank_accounts_new WHERE iban = ? LIMIT 1', {iban, iban})
            if not taken then return iban end
        end
    end
    error('could not generate a unique IBAN')
end

local pinSalt = GetResourceKvpString('pinSalt')
if not pinSalt then
    pinSalt = ('%d%d'):format(math.random(100000000, 999999999), os.time())
    SetResourceKvp('pinSalt', pinSalt)
end

-- PINs are never stored on the item (anyone holding a stolen card could
-- read item metadata client side). Only a salted hash is kept server side.
local function hashPin(account, version, pin)
    return tostring(GetHashKey(('%s|%s|%s|%s'):format(pinSalt, account, version, pin)))
end

-- =========================================================================
-- Physical card item
-- =========================================================================

if QBCore.Shared.Items and not QBCore.Shared.Items[config.cardItem] then
    QBCore.Shared.Items[config.cardItem] = {
        name = config.cardItem,
        label = 'Visa Card',
        weight = 10,
        type = 'item',
        image = 'visacard.png',
        unique = true,
        useable = true,
        shouldClose = true,
        combinable = nil,
        description = 'A personal debit card linked to your bank account.'
    }
end

-- Updates an item's metadata in place. Works with the stock qb-inventory
-- and its forks without the remove/re-add trick (which could lose the card
-- if the re-add failed).
local function setItemInfo(Player, slot, info)
    local items = Player.PlayerData.items
    local item = items and items[slot]
    if not item or item.name ~= config.cardItem then return false end
    item.info = info
    Player.Functions.SetPlayerData('items', items)
    return true
end

local function getItemBySlot(Player, slot)
    local items = Player.PlayerData.items
    return items and items[slot] or nil
end

-- qb-core moved AddItem into qb-inventory exports in newer versions.
local function addItem(Player, name, amount, info)
    if Player.Functions.AddItem then
        return Player.Functions.AddItem(name, amount, false, info)
    end
    return exports['qb-inventory']:AddItem(Player.PlayerData.source, name, amount, false, info, 'Renewed-Banking')
end

local function getCardItems(Player)
    local cards = {}
    for _, item in pairs(Player.PlayerData.items or {}) do
        if item and item.name == config.cardItem and type(item.info) == 'table' and item.info.account then
            cards[#cards+1] = item
        end
    end
    return cards
end

-- =========================================================================
-- Database bootstrap + caches
-- =========================================================================

local function ensureColumn(tbl, col, definition)
    local exists = MySQL.scalar.await('SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?', {tbl, col})
    if (tonumber(exists) or 0) == 0 then
        MySQL.query.await(('ALTER TABLE `%s` ADD COLUMN `%s` %s'):format(tbl, col, definition))
    end
end

local function ensureSchema()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `bank_accounts_new` (
        `id` varchar(50) NOT NULL,
        `amount` int(11) DEFAULT 0,
        `transactions` longtext,
        `auth` longtext,
        `isFrozen` int(11) DEFAULT 0,
        `creator` varchar(50) DEFAULT NULL,
        `iban` varchar(20) DEFAULT NULL,
        PRIMARY KEY (`id`)
    )]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `player_transactions` (
        `id` varchar(50) NOT NULL,
        `isFrozen` int(11) DEFAULT 0,
        `hasCard` int(11) DEFAULT 0,
        `iban` varchar(20) DEFAULT NULL,
        `transactions` longtext,
        PRIMARY KEY (`id`)
    )]])
    ensureColumn('bank_accounts_new', 'iban', 'varchar(20) DEFAULT NULL')
    ensureColumn('bank_accounts_new', 'hasCard', 'TINYINT(1) NOT NULL DEFAULT 0')
    ensureColumn('bank_accounts_new', 'cardVersion', 'INT NOT NULL DEFAULT 1')
    ensureColumn('bank_accounts_new', 'cardPin', 'varchar(32) DEFAULT NULL')
    ensureColumn('player_transactions', 'iban', 'varchar(20) DEFAULT NULL')
    ensureColumn('player_transactions', 'hasCard', 'int(11) DEFAULT 0')
    ensureColumn('player_transactions', 'cardVersion', 'INT NOT NULL DEFAULT 1')
    ensureColumn('player_transactions', 'cardPin', 'varchar(32) DEFAULT NULL')
end

local function orgLabel(id)
    local job = QBCore.Shared.Jobs[id]
    if job then return job.label end
    local gang = QBCore.Shared.Gangs[id]
    if gang then return gang.label end
    return id
end

local function cacheAccountRow(row)
    local id = row.id
    local acc = {
        id = id,
        type = Lang:t('ui.org'),
        name = orgLabel(id),
        frozen = row.isFrozen == 1 or row.isFrozen == true,
        amount = tonumber(row.amount) or 0,
        transactions = decodeJson(row.transactions, {}),
        auth = {},
        creator = row.creator,
        iban = row.iban,
        hasCard = row.hasCard == 1 or row.hasCard == true,
        cardVersion = tonumber(row.cardVersion) or 1,
        cardPin = row.cardPin
    }

    -- extra personal accounts are named "<citizenid>:2" / "<citizenid>:3"
    local personalIndex = id:match(':(%d+)$')
    if personalIndex and acc.creator then
        acc.type = Lang:t('ui.personal')
        acc.name = Lang:t('ui.personal_account_n', {index = personalIndex})
        acc.personal = true
    elseif acc.creator then
        acc.type = Lang:t('ui.shared')
        acc.shared = true
    end

    for _, cid in ipairs(decodeJson(row.auth, {})) do
        acc.auth[cid] = true
    end

    if not acc.iban or acc.iban == '' then
        acc.iban = genIBAN()
        MySQL.update.await('UPDATE bank_accounts_new SET iban = ? WHERE id = ?', {acc.iban, id})
    end
    ibanIndex[acc.iban] = id
    cachedAccounts[id] = acc
    return acc
end

-- Loads (once) the default personal account data of a citizen. Works for
-- offline citizens too, so transfers / stolen cards don't need the owner
-- to be online.
local function loadPlayer(cid)
    if not cid then return nil end
    if cachedPlayers[cid] then return cachedPlayers[cid] end

    local row = MySQL.single.await('SELECT * FROM player_transactions WHERE id = ?', {cid})
    if cachedPlayers[cid] then return cachedPlayers[cid] end

    local data = {
        isFrozen = row ~= nil and row.isFrozen == 1,
        hasCard = row ~= nil and row.hasCard == 1,
        cardVersion = row and tonumber(row.cardVersion) or 1,
        cardPin = row and row.cardPin or nil,
        iban = row and row.iban or nil,
        transactions = row and decodeJson(row.transactions, {}) or {}
    }

    if not data.iban or data.iban == '' then
        data.iban = genIBAN()
        MySQL.query.await('INSERT INTO player_transactions (id, iban) VALUES (:id, :iban) ON DUPLICATE KEY UPDATE iban = :iban', {id = cid, iban = data.iban})
    end

    if cachedPlayers[cid] then return cachedPlayers[cid] end
    cachedPlayers[cid] = data
    ibanIndex[data.iban] = cid
    return data
end

local function citizenExists(cid)
    if QBCore.Functions.GetPlayerByCitizenId(cid) then return true end
    return MySQL.scalar.await('SELECT 1 FROM players WHERE citizenid = ? LIMIT 1', {cid}) ~= nil
end

local function nameOf(cid)
    local Player = QBCore.Functions.GetPlayerByCitizenId(cid)
    if Player then
        nameCache[cid] = fullName(Player)
        return nameCache[cid]
    end
    if nameCache[cid] then return nameCache[cid] end
    local charinfo = decodeJson(MySQL.scalar.await('SELECT charinfo FROM players WHERE citizenid = ?', {cid}), nil)
    nameCache[cid] = charinfo and ('%s %s'):format(charinfo.firstname or '', charinfo.lastname or '') or cid
    return nameCache[cid]
end

CreateThread(function()
    local ok, err = pcall(ensureSchema)
    if not ok then print(('^1[Renewed-Banking] schema check failed: %s^0'):format(err)) end
    local accounts = MySQL.query.await('SELECT * FROM bank_accounts_new', {}) or {}
    for _, row in ipairs(accounts) do
        cacheAccountRow(row)
    end
    accountsReady = true

    for _, src in pairs(QBCore.Functions.GetPlayers()) do
        local Player = QBCore.Functions.GetPlayer(src)
        if Player then loadPlayer(Player.PlayerData.citizenid) end
    end
end)

local function onPlayerLoaded(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    if not waitUntilReady() then return end
    local cid = Player.PlayerData.citizenid
    loadPlayer(cid)
    local pending = pendingCards[cid]
    if pending and os.time() >= pending.readyAt and pending.notifiedSrc ~= src then
        pending.notifiedSrc = src
        TriggerClientEvent('Renewed-Banking:client:cardReady', src)
    end
end

RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    onPlayerLoaded(source)
end)

AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    if Player and Player.PlayerData then onPlayerLoaded(Player.PlayerData.source) end
end)

AddEventHandler('playerDropped', function()
    sessions[source] = nil
    busy[source] = nil
end)

-- =========================================================================
-- Account money (org / shared / extra personal live in cachedAccounts,
-- default personal accounts are the player's QBCore bank money)
-- =========================================================================

local function saveAccountAmount(account)
    local acc = cachedAccounts[account]
    if acc then MySQL.update('UPDATE bank_accounts_new SET amount = ? WHERE id = ?', {acc.amount, account}) end
end

local function getAccountMoney(account)
    if not cachedAccounts[account] then
        print(Lang:t('logs.invalid_account', {account = account}))
        return false
    end
    return cachedAccounts[account].amount
end exports('getAccountMoney', getAccountMoney)

local function addAccountMoney(account, amount)
    amount = tonumber(amount)
    if not cachedAccounts[account] or not amount or amount <= 0 then
        print(Lang:t('logs.invalid_account', {account = account}))
        return false
    end
    cachedAccounts[account].amount = cachedAccounts[account].amount + math.floor(amount)
    saveAccountAmount(account)
    return true
end exports('addAccountMoney', addAccountMoney)

local function removeAccountMoney(account, amount)
    amount = tonumber(amount)
    if not cachedAccounts[account] or not amount or amount <= 0 then
        print(Lang:t('logs.invalid_account', {account = account}))
        return false
    end
    amount = math.floor(amount)
    if cachedAccounts[account].amount < amount then
        print(Lang:t('logs.broke_account', {account = account, amount = amount}))
        return false
    end
    cachedAccounts[account].amount = cachedAccounts[account].amount - amount
    saveAccountAmount(account)
    return true
end exports('removeAccountMoney', removeAccountMoney)

local function personalBalance(cid)
    local Player = QBCore.Functions.GetPlayerByCitizenId(cid)
    if Player then return Player.PlayerData.money.bank end
    local money = decodeJson(MySQL.scalar.await('SELECT money FROM players WHERE citizenid = ?', {cid}), nil)
    return money and tonumber(money.bank) or 0
end

local function personalAdd(cid, amount, reason)
    local Player = QBCore.Functions.GetPlayerByCitizenId(cid)
    if Player then return Player.Functions.AddMoney('bank', amount, reason) ~= false end
    local affected = MySQL.update.await("UPDATE players SET money = JSON_SET(money, '$.bank', CAST(JSON_EXTRACT(money, '$.bank') AS DECIMAL(20,0)) + ?) WHERE citizenid = ?", {amount, cid})
    return (affected or 0) > 0
end

-- Explicit balance check: stock qb-core allows the bank balance to go
-- negative, so RemoveMoney('bank') alone never fails (infinite money).
local function personalRemove(cid, amount, reason)
    local Player = QBCore.Functions.GetPlayerByCitizenId(cid)
    if Player then
        if (Player.PlayerData.money.bank or 0) < amount then return false end
        return Player.Functions.RemoveMoney('bank', amount, reason) ~= false
    end
    local affected = MySQL.update.await("UPDATE players SET money = JSON_SET(money, '$.bank', CAST(JSON_EXTRACT(money, '$.bank') AS DECIMAL(20,0)) - ?) WHERE citizenid = ? AND CAST(JSON_EXTRACT(money, '$.bank') AS DECIMAL(20,0)) >= ?", {amount, cid, amount})
    return (affected or 0) > 0
end

local function accountBalance(account)
    if cachedAccounts[account] then return cachedAccounts[account].amount end
    return personalBalance(account)
end

local function accountAdd(account, amount, reason)
    if cachedAccounts[account] then return addAccountMoney(account, amount) end
    return personalAdd(account, amount, reason)
end

local function accountRemove(account, amount, reason)
    if cachedAccounts[account] then return removeAccountMoney(account, amount) end
    return personalRemove(account, amount, reason)
end

local function accountName(account)
    if cachedAccounts[account] then return cachedAccounts[account].name end
    return nameOf(account)
end

local function accountTitle(account)
    if cachedAccounts[account] then return ('%s / %s'):format(cachedAccounts[account].name, account) end
    return Lang:t('ui.personal_acc') .. account
end

local function isAccountFrozen(account)
    if cachedAccounts[account] then return cachedAccounts[account].frozen == true end
    local data = cachedPlayers[account]
    return data ~= nil and data.isFrozen == true
end

-- Balance right after the transaction, used by the statistics charts.
-- Never touches the database (this function is also a public export).
local function liveBalance(account)
    if cachedAccounts[account] then return cachedAccounts[account].amount end
    local Player = QBCore.Functions.GetPlayerByCitizenId(account)
    return Player and Player.PlayerData.money.bank or nil
end

local function handleTransaction(account, title, amount, message, issuer, receiver, transType, transID)
    local list
    if cachedAccounts[account] then
        list = cachedAccounts[account].transactions
    else
        if not cachedPlayers[account] and type(account) == 'string' and citizenExists(account) then
            loadPlayer(account)
        end
        list = cachedPlayers[account] and cachedPlayers[account].transactions
    end
    if not list then
        print(Lang:t('logs.invalid_account', {account = account}))
        return { trans_id = transID or genTransactionID() }
    end

    local transaction = {
        trans_id = transID or genTransactionID(),
        title = title,
        amount = math.floor(tonumber(amount) or 0),
        trans_type = transType,
        receiver = receiver,
        message = message,
        issuer = issuer,
        time = os.time(),
        balance = liveBalance(account)
    }
    table.insert(list, 1, transaction)
    while #list > config.maxTransactions do
        table.remove(list)
    end

    if cachedAccounts[account] then
        MySQL.update('UPDATE bank_accounts_new SET amount = ?, transactions = ? WHERE id = ?', {
            cachedAccounts[account].amount, json.encode(list), account
        })
    else
        MySQL.query('INSERT INTO player_transactions (id, transactions) VALUES (:id, :transactions) ON DUPLICATE KEY UPDATE transactions = :transactions', {
            id = account, transactions = json.encode(list)
        })
    end
    return transaction
end exports('handleTransaction', handleTransaction)

-- =========================================================================
-- Permissions
-- =========================================================================

local function groupHasBankAuth(group, shared)
    if not group or not group.name then return false end
    local def = shared[group.name]
    if not def or not def.grades then return false end
    local level = group.grade and group.grade.level or 0
    local grade = def.grades[tostring(level)] or def.grades[tonumber(level)]
    if grade and grade.bankAuth then return true end
    if config.bossAlwaysHasAccess and (group.isboss or (grade and grade.isboss)) then return true end
    return false
end

-- The citizen owns the account outright: their default personal account or
-- one of their extra personal accounts. Cards can only be tied to these.
local function ownsAccount(cid, account)
    if type(account) ~= 'string' then return false end
    if account == cid then return true end
    local acc = cachedAccounts[account]
    return acc ~= nil and acc.personal == true and acc.creator == cid
end

-- Can this player move money in/out of `account` in their current session?
local function canAccess(Player, account, session)
    if type(account) ~= 'string' then return false end
    if session and session.card then return account == session.card.account end

    local cid = Player.PlayerData.citizenid
    if account == cid then return true end
    local acc = cachedAccounts[account]
    if not acc then return false end
    if acc.personal then return acc.creator == cid end
    if account == Player.PlayerData.job.name and groupHasBankAuth(Player.PlayerData.job, QBCore.Shared.Jobs) then return true end
    if Player.PlayerData.gang and account == Player.PlayerData.gang.name and groupHasBankAuth(Player.PlayerData.gang, QBCore.Shared.Gangs) then return true end
    return acc.creator ~= nil and (acc.creator == cid or acc.auth[cid] == true)
end

local function isNearBank(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local coords = GetEntityCoords(ped)
    for _, p in ipairs(config.peds) do
        if #(coords - vector3(p.coords.x, p.coords.y, p.coords.z)) <= config.bankDistance then
            return true
        end
    end
    return false
end

local function servicesLocked(Player)
    local key = config.servicesCheck and config.servicesCheck.metadata
    return key ~= nil and Player.PlayerData.metadata[key] and true or false
end

-- Job / gang society accounts are created on demand the first time someone
-- with bank access opens the bank, so new jobs don't need manual SQL.
local function ensureOrgAccount(name)
    if not name or name == '' or name == 'unemployed' or name == 'none' or cachedAccounts[name] then return end
    MySQL.insert.await('INSERT IGNORE INTO bank_accounts_new (id, amount, transactions, auth, isFrozen) VALUES (?, 0, ?, ?, 0)', {name, '[]', '[]'})
    local row = MySQL.single.await('SELECT * FROM bank_accounts_new WHERE id = ?', {name})
    if row and not cachedAccounts[name] then cacheAccountRow(row) end
end

-- =========================================================================
-- Data sent to the NUI
-- =========================================================================

local function formatTransactions(list)
    local now = os.time()
    local out = {}
    for i, tx in ipairs(list or {}) do
        local ts = tonumber(tx.time) or now
        out[i] = {
            trans_id = tx.trans_id,
            title = tx.title,
            amount = tx.amount,
            trans_type = tx.trans_type,
            receiver = tx.receiver,
            issuer = tx.issuer,
            message = tx.message,
            balance = tx.balance,
            timestamp = ts,
            time = getTimeElapsed(now - ts)
        }
    end
    return out
end

local function cardInfoFor(Player, account, version)
    for _, item in ipairs(getCardItems(Player)) do
        if item.info.account == account and (item.info.version or 1) == version then
            return item
        end
    end
    return nil
end

local function describeAccount(account, Player)
    local cid = Player.PlayerData.citizenid
    local pending = pendingCards[cid]
    local out

    if cachedAccounts[account] then
        local acc = cachedAccounts[account]
        out = {
            id = account,
            type = acc.type,
            name = acc.name,
            amount = acc.amount,
            isFrozen = acc.frozen == true,
            iban = acc.iban,
            personal = acc.personal == true,
            shared = acc.shared == true,
            isCreator = acc.creator == cid,
            hasCard = acc.hasCard == true,
            cardVersion = acc.cardVersion,
            cardPin = acc.cardPin ~= nil,
            transactions = formatTransactions(acc.transactions)
        }
    else
        local data = loadPlayer(account)
        if not data then return nil end
        local isSelf = account == cid
        out = {
            id = account,
            type = Lang:t('ui.personal'),
            name = isSelf and fullName(Player) or nameOf(account),
            amount = isSelf and Player.PlayerData.money.bank or personalBalance(account),
            isFrozen = data.isFrozen == true,
            iban = data.iban,
            personal = true,
            isDefault = true,
            isCreator = isSelf,
            hasCard = data.hasCard == true,
            cardVersion = data.cardVersion,
            cardPin = data.cardPin ~= nil,
            transactions = formatTransactions(data.transactions)
        }
    end

    out.canCard = ownsAccount(cid, account)
    if out.canCard then
        out.cardPending = pending ~= nil and pending.account == account
        out.cardReady = out.cardPending and os.time() >= pending.readyAt or false
        out.cardReadyIn = out.cardPending and math.max(0, pending.readyAt - os.time()) or nil
        local card = out.hasCard and cardInfoFor(Player, account, out.cardVersion)
        out.cardOnYou = card ~= nil and card ~= false
        out.cardBalance = card and (tonumber(card.info.balance) or 0) or 0
        out.cardColor = card and card.info.color or nil
    else
        out.cardPin = nil
    end
    out.cardVersion = nil
    return out
end

local function getBankData(src, Player)
    Player = Player or QBCore.Functions.GetPlayer(src)
    if not Player then return false end
    local session = sessions[src]
    local cid = Player.PlayerData.citizenid
    local payload = {
        cash = Player.PlayerData.money.cash or 0,
        citizenid = cid,
        costs = {
            pin = config.cardPinCost,
            replace = config.cardReplacementCost,
            shared = config.sharedAccountCost,
            personal = config.personalAccountCosts,
            maxCard = config.maxCardBalance
        }
    }

    if session and session.card then
        local acc = describeAccount(session.card.account, Player)
        if not acc then return false end
        acc.canCard = false
        acc.cardPin = nil
        acc.cardOnYou = nil
        acc.cardBalance = nil
        payload.accounts = { acc }
        payload.atm = true
        payload.restricted = session.card.restricted
        return payload
    end

    local accounts = {}
    local added = {}
    local function add(id)
        if added[id] then return end
        local acc = describeAccount(id, Player)
        if acc then
            added[id] = true
            accounts[#accounts+1] = acc
        end
    end

    add(cid)

    local job = Player.PlayerData.job
    if cachedAccounts[job.name] and groupHasBankAuth(job, QBCore.Shared.Jobs) then add(job.name) end
    local gang = Player.PlayerData.gang
    if gang and cachedAccounts[gang.name] and groupHasBankAuth(gang, QBCore.Shared.Gangs) then add(gang.name) end

    local extra = {}
    for id, acc in pairs(cachedAccounts) do
        if (acc.personal and acc.creator == cid) or (acc.shared and (acc.creator == cid or acc.auth[cid])) then
            extra[#extra+1] = id
        end
    end
    table.sort(extra, function(a, b)
        local pa, pb = cachedAccounts[a].personal and 0 or 1, cachedAccounts[b].personal and 0 or 1
        if pa ~= pb then return pa < pb end
        return a < b
    end)
    for _, id in ipairs(extra) do add(id) end

    payload.accounts = accounts
    payload.atm = false
    return payload
end

-- =========================================================================
-- Sessions: every bank action needs an open session. Bank sessions are
-- only valid near a bank teller, ATM sessions are bound to the card that
-- was inserted (and that card has to still be in the inventory).
-- =========================================================================

local function validateSession(src, Player, bankOnly)
    local session = sessions[src]
    if not session then return nil, Lang:t('notify.no_session') end

    if session.mode == 'bank' then
        if not isNearBank(src) then
            sessions[src] = nil
            return nil, Lang:t('notify.too_far')
        end
    elseif session.card then
        if bankOnly then return nil, Lang:t('notify.bank_only') end
        local item = getItemBySlot(Player, session.card.slot)
        if not item or item.name ~= config.cardItem or not item.info or item.info.account ~= session.card.account then
            sessions[src] = nil
            return nil, Lang:t('notify.card_removed')
        end
    end
    return session
end

-- Registers "Renewed-Banking:server:<name>". The handler returns:
--   false/nil -> failure (handler already notified), true -> refreshed bank
--   data is sent back, table -> sent back as is.
local function bankCallback(name, opts, handler)
    QBCore.Functions.CreateCallback('Renewed-Banking:server:' .. name, function(source, cb, data)
        local src = source
        local Player = QBCore.Functions.GetPlayer(src)
        if not Player or not accountsReady then return cb(false) end
        if type(data) ~= 'table' then data = {} end

        local session, err = validateSession(src, Player, opts.bankOnly)
        if not session then
            notify(src, err)
            return cb(false)
        end
        if busy[src] then return cb(false) end

        busy[src] = true
        local ok, res = pcall(handler, src, Player, data, session)
        busy[src] = nil

        if not ok then
            print(('^1[Renewed-Banking] %s failed: %s^0'):format(name, res))
            notify(src, Lang:t('notify.generic_error'))
            return cb(false)
        end
        if not res then return cb(false) end
        if res == true then return cb(getBankData(src, Player)) end
        cb(res)
    end)
end

QBCore.Functions.CreateCallback('Renewed-Banking:server:openBank', function(source, cb)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not waitUntilReady() then return cb(false) end
    if not isNearBank(src) then
        notify(src, Lang:t('notify.too_far'))
        return cb(false)
    end

    loadPlayer(Player.PlayerData.citizenid)
    if groupHasBankAuth(Player.PlayerData.job, QBCore.Shared.Jobs) then ensureOrgAccount(Player.PlayerData.job.name) end
    if Player.PlayerData.gang and groupHasBankAuth(Player.PlayerData.gang, QBCore.Shared.Gangs) then ensureOrgAccount(Player.PlayerData.gang.name) end

    sessions[src] = { mode = 'bank' }
    cb(getBankData(src, Player))
end)

RegisterNetEvent('Renewed-Banking:server:closeSession', function()
    sessions[source] = nil
end)

-- =========================================================================
-- ATM: insert a physical card (+ PIN)
-- =========================================================================

local function cardState(account)
    if cachedAccounts[account] then return cachedAccounts[account] end
    if type(account) == 'string' and not account:find(':') and citizenExists(account) then
        return loadPlayer(account)
    end
    return nil
end

local function saveCardState(account)
    local acc = cachedAccounts[account]
    if acc then
        MySQL.update('UPDATE bank_accounts_new SET hasCard = ?, cardVersion = ?, cardPin = ? WHERE id = ?', {
            acc.hasCard and 1 or 0, acc.cardVersion or 1, acc.cardPin, account
        })
        return
    end
    local data = cachedPlayers[account]
    if data then
        MySQL.query('INSERT INTO player_transactions (id, hasCard, cardVersion, cardPin) VALUES (:id, :hasCard, :cardVersion, :cardPin) ON DUPLICATE KEY UPDATE hasCard = :hasCard, cardVersion = :cardVersion, cardPin = :cardPin', {
            id = account, hasCard = data.hasCard and 1 or 0, cardVersion = data.cardVersion or 1, cardPin = data.cardPin
        })
    end
end

QBCore.Functions.CreateCallback('Renewed-Banking:server:openAtmWithCard', function(source, cb, data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not waitUntilReady() or type(data) ~= 'table' then return cb(false) end
    if busy[src] then return cb(false) end
    busy[src] = true

    local ok, res = pcall(function()
        local slot = tonumber(data.slot)
        local item = slot and getItemBySlot(Player, slot)
        if not item or item.name ~= config.cardItem or type(item.info) ~= 'table' or not item.info.account then
            return { error = Lang:t('notify.invalid_card') }
        end

        local info = item.info
        local account = info.account
        local state = cardState(account)
        local version = tonumber(info.version) or 1
        if not state or version ~= (state.cardVersion or 1) then
            return { error = Lang:t('notify.card_deactivated') }
        end

        local failKey = ('%s:%s'):format(account, version)
        local fails = pinFails[failKey]
        if fails and fails.lockedUntil and os.time() < fails.lockedUntil then
            return { error = Lang:t('notify.card_locked', {time = fails.lockedUntil - os.time()}), locked = true }
        end

        local legacyPin = (not state.cardPin) and info.pin ~= nil and tostring(info.pin) ~= '' and tostring(info.pin) or nil
        local hasPin = state.cardPin ~= nil or legacyPin ~= nil

        if hasPin then
            local pin = tostring(data.pin or '')
            if pin == '' then return { needPin = true } end

            local valid
            if state.cardPin then
                valid = pin:match('^%d%d%d%d$') ~= nil and hashPin(account, version, pin) == state.cardPin
            else
                valid = pin == legacyPin
            end

            if not valid then
                fails = fails or { count = 0 }
                fails.count = fails.count + 1
                if fails.count >= config.pinMaxAttempts then
                    fails.count = 0
                    fails.lockedUntil = os.time() + config.pinLockSeconds
                    pinFails[failKey] = fails
                    return { error = Lang:t('notify.card_locked', {time = config.pinLockSeconds}), locked = true }
                end
                pinFails[failKey] = fails
                return { error = Lang:t('notify.wrong_pin'), attemptsLeft = config.pinMaxAttempts - fails.count, needPin = true }
            end
            pinFails[failKey] = nil

            -- migrate cards made by the old version (PIN in plain text on the item)
            if legacyPin then
                state.cardPin = hashPin(account, version, pin)
                saveCardState(account)
            end
        end

        if info.pin ~= nil or info.hasPin ~= hasPin then
            info.pin = nil
            info.hasPin = hasPin
            setItemInfo(Player, slot, info)
        end

        sessions[src] = { mode = 'atm', card = { account = account, restricted = not hasPin, slot = slot } }
        local payload = getBankData(src, Player)
        if not payload then
            sessions[src] = nil
            return { error = Lang:t('notify.loading_failed') }
        end
        return payload
    end)

    busy[src] = nil
    if not ok then
        print(('^1[Renewed-Banking] openAtmWithCard failed: %s^0'):format(res))
        return cb({ error = Lang:t('notify.generic_error') })
    end
    cb(res)
end)

-- =========================================================================
-- Deposit / withdraw / transfer
-- =========================================================================

local function txComment(data, name, kind, amount)
    local comment = cleanText(data.comment, config.maxCommentLength)
    if comment == '' then
        comment = Lang:t('notify.comp_transaction', {name = name, type = kind, amount = amount})
    end
    return comment
end

local function checkAccountUsable(src, Player, account, session, allowRestricted)
    if not canAccess(Player, account, session) then
        notify(src, Lang:t('notify.no_access'))
        print(Lang:t('logs.illegal_action', {name = GetPlayerName(src)}))
        return false
    end
    if session.card and session.card.restricted and not allowRestricted then
        notify(src, Lang:t('notify.card_no_pin'))
        return false
    end
    if isAccountFrozen(account) then
        notify(src, Lang:t('notify.account_frozen'))
        return false
    end
    return true
end

bankCallback('deposit', {}, function(src, Player, data, session)
    local account = data.fromAccount
    if not checkAccountUsable(src, Player, account, session) then return false end

    local amount = cleanAmount(data.amount)
    if not amount then
        notify(src, Lang:t('notify.invalid_amount', {type = 'deposit'}))
        return false
    end
    if (Player.PlayerData.money.cash or 0) < amount or not Player.Functions.RemoveMoney('cash', amount, 'bank-deposit') then
        notify(src, Lang:t('notify.not_enough_cash'))
        return false
    end
    if not accountAdd(account, amount, 'bank-deposit') then
        Player.Functions.AddMoney('cash', amount, 'bank-deposit-refund')
        notify(src, Lang:t('notify.generic_error'))
        return false
    end

    local name = fullName(Player)
    handleTransaction(account, accountTitle(account), amount, txComment(data, name, 'deposited', amount), name, accountName(account), 'deposit')
    notify(src, Lang:t('notify.deposited', {amount = fmtMoney(amount)}), 'success')
    return true
end)

bankCallback('withdraw', {}, function(src, Player, data, session)
    local account = data.fromAccount
    if not checkAccountUsable(src, Player, account, session, true) then return false end
    if servicesLocked(Player) then
        notify(src, Lang:t('notify.services_locked'))
        return false
    end

    local amount = cleanAmount(data.amount)
    if not amount then
        notify(src, Lang:t('notify.invalid_amount', {type = 'withdraw'}))
        return false
    end
    if not accountRemove(account, amount, 'bank-withdraw') then
        notify(src, Lang:t('notify.not_enough_money'))
        return false
    end
    Player.Functions.AddMoney('cash', amount, 'bank-withdraw')

    local name = fullName(Player)
    handleTransaction(account, accountTitle(account), amount, txComment(data, name, 'withdrew', amount), accountName(account), name, 'withdraw')
    notify(src, Lang:t('notify.withdrew', {amount = fmtMoney(amount)}), 'success')
    return true
end)

-- Resolves what the player typed as recipient: account id, IBAN, server id
-- or citizen id (online or offline).
local function resolveRecipient(input)
    input = cleanText(input, 50)
    if input == '' then return nil end

    if cachedAccounts[input] then return input end

    local upper = input:upper()
    if ibanIndex[upper] then return ibanIndex[upper] end

    local serverId = tonumber(input)
    if serverId then
        local Target = QBCore.Functions.GetPlayer(serverId)
        if Target then return Target.PlayerData.citizenid end
    end

    -- citizens are matched before the case-insensitive account lookup, so
    -- an account can never "catch" transfers meant for a citizen ID
    for _, cid in ipairs({input, upper}) do
        if QBCore.Functions.GetPlayerByCitizenId(cid) then return cid end
    end
    local cid = MySQL.scalar.await('SELECT citizenid FROM players WHERE citizenid = ?', {input})
    if cid then return cid end

    if cachedAccounts[input:lower()] then return input:lower() end

    local ibanOwner = MySQL.scalar.await('SELECT id FROM player_transactions WHERE iban = ?', {upper})
    if ibanOwner and citizenExists(ibanOwner) then return ibanOwner end
    return nil
end

bankCallback('transfer', {}, function(src, Player, data, session)
    local account = data.fromAccount
    if not checkAccountUsable(src, Player, account, session) then return false end
    if servicesLocked(Player) then
        notify(src, Lang:t('notify.services_locked'))
        return false
    end

    local amount = cleanAmount(data.amount)
    if not amount then
        notify(src, Lang:t('notify.invalid_amount', {type = 'transfer'}))
        return false
    end

    local target = resolveRecipient(data.stateid)
    if not target then
        notify(src, Lang:t('notify.fail_transfer'))
        return false
    end
    if target == account then
        notify(src, Lang:t('notify.same_account'))
        return false
    end
    if not cachedAccounts[target] then loadPlayer(target) end

    if not accountRemove(account, amount, 'bank-transfer') then
        notify(src, Lang:t('notify.not_enough_money'))
        return false
    end
    if not accountAdd(target, amount, 'bank-transfer') then
        accountAdd(account, amount, 'bank-transfer-refund')
        notify(src, Lang:t('notify.fail_transfer'))
        return false
    end

    local fromName = accountName(account)
    local toName = accountName(target)
    local title = accountTitle(account)
    local comment = txComment(data, fullName(Player), 'transferred', amount)
    local transaction = handleTransaction(account, title, amount, comment, fromName, toName, 'withdraw')
    handleTransaction(target, title, amount, comment, fromName, toName, 'deposit', transaction.trans_id)

    local TargetPlayer = not cachedAccounts[target] and QBCore.Functions.GetPlayerByCitizenId(target)
    if TargetPlayer then
        TriggerClientEvent('QBCore:Notify', TargetPlayer.PlayerData.source, Lang:t('notify.received_transfer', {amount = fmtMoney(amount), name = fromName}), 'success')
    end
    notify(src, Lang:t('notify.transferred', {amount = fmtMoney(amount), name = toName}), 'success')
    return true
end)

-- =========================================================================
-- Account management (freeze, personal / shared accounts, members)
-- =========================================================================

bankCallback('toggleFreeze', { bankOnly = true }, function(src, Player, data)
    local cid = Player.PlayerData.citizenid
    local account = data.account
    if account == cid then
        local p = loadPlayer(cid)
        p.isFrozen = not p.isFrozen
        MySQL.query('INSERT INTO player_transactions (id, isFrozen) VALUES (:id, :isFrozen) ON DUPLICATE KEY UPDATE isFrozen = :isFrozen', {
            id = cid, isFrozen = p.isFrozen and 1 or 0
        })
        notify(src, p.isFrozen and Lang:t('notify.frozen') or Lang:t('notify.unfrozen'), 'success')
        return true
    end

    local acc = cachedAccounts[account]
    if not acc or acc.creator ~= cid then
        notify(src, Lang:t('notify.no_freeze_permission'))
        return false
    end
    acc.frozen = not acc.frozen
    MySQL.update('UPDATE bank_accounts_new SET isFrozen = ? WHERE id = ?', {acc.frozen and 1 or 0, account})
    notify(src, acc.frozen and Lang:t('notify.frozen') or Lang:t('notify.unfrozen'), 'success')
    return true
end)

local function countOwned(cid, kind)
    local n = 0
    for _, acc in pairs(cachedAccounts) do
        if acc.creator == cid and acc[kind] then n = n + 1 end
    end
    return n
end

bankCallback('openAccount', { bankOnly = true }, function(src, Player)
    local cid = Player.PlayerData.citizenid
    local extra = countOwned(cid, 'personal')
    if extra >= #config.personalAccountCosts then
        notify(src, Lang:t('notify.max_accounts'))
        return false
    end

    -- first free index (an account in the middle may have been closed)
    local index = 2
    while cachedAccounts[('%s:%d'):format(cid, index)] do index = index + 1 end
    local accountid = ('%s:%d'):format(cid, index)

    local cost = config.personalAccountCosts[extra + 1]
    if cost > 0 and not personalRemove(cid, cost, 'bank-open-account') then
        notify(src, Lang:t('notify.need_bank_money', {amount = fmtMoney(cost)}))
        return false
    end

    local iban = genIBAN()
    MySQL.insert.await('INSERT INTO bank_accounts_new (id, amount, transactions, auth, isFrozen, creator, iban) VALUES (?, 0, ?, ?, 0, ?, ?)', {
        accountid, '[]', json.encode({cid}), cid, iban
    })
    cacheAccountRow({ id = accountid, amount = 0, transactions = '[]', auth = json.encode({cid}), isFrozen = 0, creator = cid, iban = iban })
    notify(src, Lang:t('notify.account_opened', {name = cachedAccounts[accountid].name, amount = fmtMoney(cost)}), 'success')
    return true
end)

local function validAccountName(name)
    if type(name) ~= 'string' then return nil end
    name = name:lower():gsub('%s+', '')
    if #name < 3 or #name > 24 or not name:match('^[a-z0-9_]+$') then return nil end
    if QBCore.Shared.Jobs[name] or QBCore.Shared.Gangs[name] or cachedAccounts[name] then return nil end
    if MySQL.scalar.await('SELECT 1 FROM players WHERE citizenid = ? LIMIT 1', {name}) then return nil end
    return name
end

bankCallback('createShared', { bankOnly = true }, function(src, Player, data)
    local cid = Player.PlayerData.citizenid
    local name = validAccountName(data.name)
    if not name then
        notify(src, Lang:t('notify.invalid_account_name'))
        return false
    end
    if countOwned(cid, 'shared') >= config.maxSharedAccounts then
        notify(src, Lang:t('notify.max_shared', {max = config.maxSharedAccounts}))
        return false
    end
    if MySQL.scalar.await('SELECT 1 FROM bank_accounts_new WHERE id = ?', {name}) then
        notify(src, Lang:t('notify.account_taken'))
        return false
    end
    if config.sharedAccountCost > 0 and not personalRemove(cid, config.sharedAccountCost, 'bank-shared-account') then
        notify(src, Lang:t('notify.need_bank_money', {amount = fmtMoney(config.sharedAccountCost)}))
        return false
    end

    local iban = genIBAN()
    MySQL.insert.await('INSERT INTO bank_accounts_new (id, amount, transactions, auth, isFrozen, creator, iban) VALUES (?, 0, ?, ?, 0, ?, ?)', {
        name, '[]', json.encode({cid}), cid, iban
    })
    cacheAccountRow({ id = name, amount = 0, transactions = '[]', auth = json.encode({cid}), isFrozen = 0, creator = cid, iban = iban })
    notify(src, Lang:t('notify.shared_created', {name = name}), 'success')
    return true
end)

local function renameAccount(account, newName)
    local acc = cachedAccounts[account]
    if not acc then return false end
    MySQL.update.await('UPDATE bank_accounts_new SET id = ? WHERE id = ?', {newName, account})
    cachedAccounts[newName] = acc
    cachedAccounts[account] = nil
    acc.id = newName
    if acc.shared or not acc.personal then acc.name = acc.shared and newName or orgLabel(newName) end
    ibanIndex[acc.iban] = newName
    for _, s in pairs(sessions) do
        if s.card and s.card.account == account then s.card.account = newName end
    end
    return true
end

bankCallback('renameAccount', { bankOnly = true }, function(src, Player, data)
    local acc = cachedAccounts[data.account]
    if not acc or not acc.shared or acc.creator ~= Player.PlayerData.citizenid then
        notify(src, Lang:t('notify.no_access'))
        return false
    end
    local newName = validAccountName(data.newName)
    if not newName or MySQL.scalar.await('SELECT 1 FROM bank_accounts_new WHERE id = ?', {newName}) then
        notify(src, Lang:t('notify.invalid_account_name'))
        return false
    end
    renameAccount(data.account, newName)
    notify(src, Lang:t('notify.account_renamed', {name = newName}), 'success')
    return { renamed = newName, data = getBankData(src, Player) }
end)

-- Closes an extra personal account or a shared account (creator only).
-- Remaining money goes back to the creator's main account.
bankCallback('closeAccount', { bankOnly = true }, function(src, Player, data)
    local cid = Player.PlayerData.citizenid
    local account = data.fromAccount
    local acc = cachedAccounts[account]
    if not acc or acc.creator ~= cid or not (acc.personal or acc.shared) then
        notify(src, Lang:t('notify.cant_close'))
        return false
    end
    if acc.frozen then
        notify(src, Lang:t('notify.account_frozen'))
        return false
    end

    local balance = acc.amount
    cachedAccounts[account] = nil
    ibanIndex[acc.iban] = nil
    MySQL.query.await('DELETE FROM bank_accounts_new WHERE id = ?', {account})
    if balance > 0 then
        personalAdd(cid, balance, 'bank-close-account')
        handleTransaction(cid, Lang:t('ui.personal_acc') .. cid, balance, Lang:t('notify.close_refund_msg', {name = acc.name}), acc.name, fullName(Player), 'deposit')
    end
    local pending = pendingCards[cid]
    if pending and pending.account == account then pendingCards[cid] = nil end
    notify(src, Lang:t('notify.account_closed'), 'success')
    return true
end)

local function sharedAccountOf(Player, account)
    local acc = cachedAccounts[account]
    if not acc or not acc.shared or acc.creator ~= Player.PlayerData.citizenid then return nil end
    return acc
end

local function memberList(acc)
    local list = {}
    for cid in pairs(acc.auth) do
        list[#list+1] = { cid = cid, name = nameOf(cid), creator = cid == acc.creator }
    end
    table.sort(list, function(a, b)
        if a.creator ~= b.creator then return a.creator end
        return a.name < b.name
    end)
    return list
end

local function saveAuth(account)
    local auth = {}
    for cid in pairs(cachedAccounts[account].auth) do auth[#auth+1] = cid end
    MySQL.update('UPDATE bank_accounts_new SET auth = ? WHERE id = ?', {json.encode(auth), account})
end

bankCallback('getMembers', { bankOnly = true }, function(src, Player, data)
    local acc = sharedAccountOf(Player, data.account)
    if not acc then
        notify(src, Lang:t('notify.no_access'))
        return false
    end
    return { members = memberList(acc) }
end)

local function resolveCitizen(input)
    input = cleanText(input, 50)
    if input == '' then return nil end
    local serverId = tonumber(input)
    if serverId then
        local Target = QBCore.Functions.GetPlayer(serverId)
        if Target then return Target.PlayerData.citizenid end
    end
    for _, cid in ipairs({input, input:upper()}) do
        if QBCore.Functions.GetPlayerByCitizenId(cid) then return cid end
    end
    return MySQL.scalar.await('SELECT citizenid FROM players WHERE citizenid = ?', {input})
end

bankCallback('addMember', { bankOnly = true }, function(src, Player, data)
    local acc = sharedAccountOf(Player, data.account)
    if not acc then
        notify(src, Lang:t('notify.no_access'))
        return false
    end
    local cid = resolveCitizen(data.member)
    if not cid then
        notify(src, Lang:t('notify.unknown_player', {id = cleanText(data.member, 50)}))
        return false
    end
    if acc.auth[cid] then
        notify(src, Lang:t('notify.already_member'))
        return false
    end
    local count = 0
    for _ in pairs(acc.auth) do count = count + 1 end
    if count >= config.maxAccountMembers then
        notify(src, Lang:t('notify.max_members', {max = config.maxAccountMembers}))
        return false
    end
    acc.auth[cid] = true
    saveAuth(acc.id)
    notify(src, Lang:t('notify.member_added', {name = nameOf(cid)}), 'success')
    return { members = memberList(acc) }
end)

bankCallback('removeMember', { bankOnly = true }, function(src, Player, data)
    local acc = sharedAccountOf(Player, data.account)
    if not acc then
        notify(src, Lang:t('notify.no_access'))
        return false
    end
    local cid = data.cid
    if type(cid) ~= 'string' or not acc.auth[cid] or cid == acc.creator then
        notify(src, Lang:t('notify.cant_remove_member'))
        return false
    end
    acc.auth[cid] = nil
    saveAuth(acc.id)
    notify(src, Lang:t('notify.member_removed', {name = nameOf(cid)}), 'success')
    return { members = memberList(acc) }
end)

-- =========================================================================
-- Cards
-- =========================================================================

-- Starts preparing a new card. The player collects it from the teller once
-- it's ready (see collectCard).
local function issueCard(src, Player, account)
    local cid = Player.PlayerData.citizenid
    if pendingCards[cid] then
        return false, Lang:t('notify.card_already_pending')
    end
    local state = cardState(account)
    pendingCards[cid] = {
        account = account,
        iban = state.iban,
        holder = fullName(Player),
        version = state.cardVersion or 1,
        readyAt = os.time() + config.cardPrepSeconds
    }

    TriggerClientEvent('Renewed-Banking:client:cardPending', src, config.cardPrepSeconds)
    SetTimeout(config.cardPrepSeconds * 1000, function()
        local pending = pendingCards[cid]
        local Owner = QBCore.Functions.GetPlayerByCitizenId(cid)
        if pending and Owner then
            TriggerClientEvent('Renewed-Banking:client:cardReady', Owner.PlayerData.source)
        end
    end)
    return true, Lang:t('notify.card_preparing')
end

bankCallback('requestCard', { bankOnly = true }, function(src, Player, data)
    local cid = Player.PlayerData.citizenid
    local account = data.fromAccount
    if not ownsAccount(cid, account) then
        notify(src, Lang:t('notify.not_your_account'))
        return false
    end
    local state = cardState(account)
    if not state or state.hasCard then
        notify(src, Lang:t('notify.card_exists'))
        return false
    end
    local ok, msg = issueCard(src, Player, account)
    notify(src, msg, ok and 'success' or 'error')
    return ok
end)

RegisterNetEvent('Renewed-Banking:server:collectCard', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local cid = Player.PlayerData.citizenid
    local pending = pendingCards[cid]

    if not pending then
        TriggerClientEvent('QBCore:Notify', src, Lang:t('notify.no_pending_card'), 'error')
        return
    end
    if not isNearBank(src) then
        TriggerClientEvent('QBCore:Notify', src, Lang:t('notify.too_far'), 'error')
        return
    end
    if os.time() < pending.readyAt then
        TriggerClientEvent('QBCore:Notify', src, Lang:t('notify.card_not_ready', {time = pending.readyAt - os.time()}), 'error')
        return
    end

    local state = cardState(pending.account)
    if not state or (state.cardVersion or 1) ~= pending.version then
        pendingCards[cid] = nil
        TriggerClientEvent('QBCore:Notify', src, Lang:t('notify.card_deactivated'), 'error')
        return
    end

    local colors = config.cardColors or {'blue'}
    local added = addItem(Player, config.cardItem, 1, {
        iban = pending.iban,
        holder = pending.holder,
        account = pending.account,
        color = colors[math.random(1, #colors)],
        balance = 0,
        version = pending.version,
        hasPin = state.cardPin ~= nil
    })
    if not added then
        TriggerClientEvent('QBCore:Notify', src, Lang:t('notify.no_inventory_space'), 'error')
        return
    end

    pendingCards[cid] = nil
    state.hasCard = true
    saveCardState(pending.account)
    TriggerClientEvent('Renewed-Banking:client:cardCollected', src)
    TriggerClientEvent('QBCore:Notify', src, Lang:t('notify.card_collected'), 'success')
end)

bankCallback('setCardPin', { bankOnly = true }, function(src, Player, data)
    local cid = Player.PlayerData.citizenid
    local account = data.fromAccount
    if not ownsAccount(cid, account) then
        notify(src, Lang:t('notify.not_your_account'))
        return false
    end
    local state = cardState(account)
    if not state or not state.hasCard then
        notify(src, Lang:t('notify.no_card'))
        return false
    end
    local pin = tostring(data.pin or '')
    if not pin:match('^%d%d%d%d$') then
        notify(src, Lang:t('notify.pin_format'))
        return false
    end
    if config.cardPinCost > 0 and not personalRemove(cid, config.cardPinCost, 'bank-card-pin') then
        notify(src, Lang:t('notify.need_bank_money', {amount = fmtMoney(config.cardPinCost)}))
        return false
    end

    local version = state.cardVersion or 1
    state.cardPin = hashPin(account, version, pin)
    saveCardState(account)
    pinFails[('%s:%s'):format(account, version)] = nil

    local card = cardInfoFor(Player, account, version)
    if card then
        card.info.pin = nil
        card.info.hasPin = true
        setItemInfo(Player, card.slot, card.info)
    end
    notify(src, Lang:t('notify.pin_set'), 'success')
    return true
end)

bankCallback('replaceCard', { bankOnly = true }, function(src, Player, data)
    local cid = Player.PlayerData.citizenid
    local account = data.fromAccount
    if not ownsAccount(cid, account) then
        notify(src, Lang:t('notify.not_your_account'))
        return false
    end
    local state = cardState(account)
    if not state or not state.hasCard then
        notify(src, Lang:t('notify.no_card_to_replace'))
        return false
    end
    if pendingCards[cid] then
        notify(src, Lang:t('notify.card_already_pending'))
        return false
    end
    if config.cardReplacementCost > 0 and not personalRemove(cid, config.cardReplacementCost, 'bank-card-replacement') then
        notify(src, Lang:t('notify.need_bank_money', {amount = fmtMoney(config.cardReplacementCost)}))
        return false
    end

    -- bumping the version kills the old card wherever it is
    state.cardVersion = (state.cardVersion or 1) + 1
    state.hasCard = false
    state.cardPin = nil
    saveCardState(account)
    for s, sess in pairs(sessions) do
        if sess.card and sess.card.account == account then sessions[s] = nil end
    end

    local ok, msg = issueCard(src, Player, account)
    notify(src, Lang:t('notify.card_replaced') .. ' ' .. msg, ok and 'success' or 'error')
    return true
end)

bankCallback('loadCard', { bankOnly = true }, function(src, Player, data)
    local cid = Player.PlayerData.citizenid
    local account = data.fromAccount
    if not ownsAccount(cid, account) then
        notify(src, Lang:t('notify.not_your_account'))
        return false
    end
    if isAccountFrozen(account) then
        notify(src, Lang:t('notify.account_frozen'))
        return false
    end
    local amount = cleanAmount(data.amount)
    if not amount then
        notify(src, Lang:t('notify.invalid_amount', {type = 'load'}))
        return false
    end
    local state = cardState(account)
    local card = state and state.hasCard and cardInfoFor(Player, account, state.cardVersion or 1)
    if not card then
        notify(src, Lang:t('notify.card_not_on_you'))
        return false
    end
    local current = tonumber(card.info.balance) or 0
    if current + amount > config.maxCardBalance then
        notify(src, Lang:t('notify.card_max_balance', {amount = fmtMoney(config.maxCardBalance)}))
        return false
    end
    if not accountRemove(account, amount, 'bank-card-load') then
        notify(src, Lang:t('notify.not_enough_money'))
        return false
    end
    card.info.balance = current + amount
    if not setItemInfo(Player, card.slot, card.info) then
        accountAdd(account, amount, 'bank-card-load-refund')
        notify(src, Lang:t('notify.generic_error'))
        return false
    end

    local name = fullName(Player)
    handleTransaction(account, Lang:t('ui.card_topup'), amount, Lang:t('ui.card_topup_msg'), accountName(account), name, 'withdraw')
    notify(src, Lang:t('notify.card_loaded', {amount = fmtMoney(amount)}), 'success')
    return true
end)

bankCallback('unloadCard', { bankOnly = true }, function(src, Player, data)
    local cid = Player.PlayerData.citizenid
    local account = data.fromAccount
    if not ownsAccount(cid, account) then
        notify(src, Lang:t('notify.not_your_account'))
        return false
    end

    -- any card of this account works, including a deactivated (recovered) one
    local card
    for _, item in ipairs(getCardItems(Player)) do
        if item.info.account == account and (tonumber(item.info.balance) or 0) > 0 then
            card = item
            break
        end
    end
    if not card then
        notify(src, Lang:t('notify.card_empty'))
        return false
    end

    local balance = math.floor(tonumber(card.info.balance) or 0)
    card.info.balance = 0
    if not setItemInfo(Player, card.slot, card.info) then
        notify(src, Lang:t('notify.generic_error'))
        return false
    end
    accountAdd(account, balance, 'bank-card-unload')
    handleTransaction(account, Lang:t('ui.card_unload'), balance, Lang:t('ui.card_unload_msg'), fullName(Player), accountName(account), 'deposit')
    notify(src, Lang:t('notify.card_unloaded', {amount = fmtMoney(balance)}), 'success')
    return true
end)

-- Card usable from inventory: shows the card preview, enriched with its
-- live status (frozen / deactivated).
QBCore.Functions.CreateUseableItem(config.cardItem, function(source, item)
    local info = item and item.info
    if type(info) ~= 'table' then return end
    local state = info.account and cardState(info.account)
    TriggerClientEvent('Renewed-Banking:client:openCardUI', source, {
        iban = info.iban,
        holder = info.holder,
        color = info.color,
        balance = tonumber(info.balance) or 0,
        hasPin = info.hasPin == true or (state and state.cardPin ~= nil) or false,
        frozen = info.account and isAccountFrozen(info.account) or false,
        deactivated = not state or (tonumber(info.version) or 1) ~= (state.cardVersion or 1)
    })
end)

-- Card validity for payments: right version and account not frozen.
local function usableCard(item)
    if not item or type(item.info) ~= 'table' or not item.info.account then return false end
    local state = cardState(item.info.account)
    if not state or (tonumber(item.info.version) or 1) ~= (state.cardVersion or 1) then return false end
    if isAccountFrozen(item.info.account) then return false end
    return true
end

local function firstUsableCard(Player, amount)
    for _, item in ipairs(getCardItems(Player)) do
        if usableCard(item) and (tonumber(item.info.balance) or 0) >= amount then return item end
    end
    return nil
end

-- Pays another nearby player from the card balance (tap-to-pay, they get cash).
QBCore.Functions.CreateCallback('Renewed-Banking:server:payWithCard', function(source, cb, data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or type(data) ~= 'table' then return cb(false) end

    local amount = cleanAmount(data.amount)
    local targetId = tonumber(data.target)
    if not amount or not targetId or targetId == src then
        TriggerClientEvent('QBCore:Notify', src, Lang:t('notify.invalid_payment'), 'error')
        return cb(false)
    end
    local Target = QBCore.Functions.GetPlayer(targetId)
    if not Target then
        TriggerClientEvent('QBCore:Notify', src, Lang:t('notify.player_offline'), 'error')
        return cb(false)
    end
    local dist = #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(targetId)))
    if dist > config.cardPaymentDistance then
        TriggerClientEvent('QBCore:Notify', src, Lang:t('notify.player_too_far'), 'error')
        return cb(false)
    end

    local card = firstUsableCard(Player, amount)
    if not card then
        TriggerClientEvent('QBCore:Notify', src, Lang:t('notify.card_insufficient'), 'error')
        return cb(false)
    end
    card.info.balance = (tonumber(card.info.balance) or 0) - amount
    if not setItemInfo(Player, card.slot, card.info) then return cb(false) end
    Target.Functions.AddMoney('cash', amount, 'card-payment')

    TriggerClientEvent('QBCore:Notify', targetId, Lang:t('notify.card_payment_received', {amount = fmtMoney(amount), name = fullName(Player)}), 'success')
    cb({ balance = card.info.balance })
end)

-- Lets other resources (shops, POS terminals, vending machines...) charge
-- a player's card balance:
--   local ok = exports['Renewed-Banking']:chargeCard(source, 250, "Ammu-Nation purchase")
local function chargeCard(source, amount, reason)
    local Player = QBCore.Functions.GetPlayer(source)
    amount = cleanAmount(amount)
    if not Player or not amount then return false end
    local card = firstUsableCard(Player, amount)
    if not card then return false end
    card.info.balance = (tonumber(card.info.balance) or 0) - amount
    if not setItemInfo(Player, card.slot, card.info) then return false end
    TriggerClientEvent('QBCore:Notify', source, Lang:t('notify.card_charged', {amount = fmtMoney(amount), reason = reason and (' - ' .. tostring(reason)) or ''}), 'primary')
    return true
end exports('chargeCard', chargeCard)

-- =========================================================================
-- Server-side exports (trusted callers only)
-- =========================================================================

local function changeAccountName(account, newName)
    if not account or not newName then return false end
    if cachedAccounts[newName] then print(Lang:t('logs.existing_account', {account = newName})) return false end
    if not cachedAccounts[account] then print(Lang:t('logs.invalid_account', {account = account})) return false end
    return renameAccount(account, newName)
end exports('changeAccountName', changeAccountName)

local function addAccountMember(account, member)
    local acc = cachedAccounts[account]
    if not acc then print(Lang:t('logs.invalid_account', {account = account})) return false end
    local cid = resolveCitizen(member)
    if not cid then return false end
    acc.auth[cid] = true
    saveAuth(account)
    return true
end exports('addAccountMember', addAccountMember)

local function removeAccountMember(account, member)
    local acc = cachedAccounts[account]
    if not acc then print(Lang:t('logs.invalid_account', {account = account})) return false end
    local cid = resolveCitizen(member) or member
    if not acc.auth[cid] then return false end
    acc.auth[cid] = nil
    saveAuth(account)
    return true
end exports('removeAccountMember', removeAccountMember)
