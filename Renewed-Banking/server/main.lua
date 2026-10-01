local QBCore = exports['qb-core']:GetCoreObject()
local cachedAccounts = {}
local cachedPlayers = {}
local cachedOffline = {}

-- Generates a simple display IBAN, e.g. "B617521932" (1 letter + 9 digits).
local function genIBAN()
    local letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ'
    local idx = math.random(1, #letters)
    local letter = letters:sub(idx, idx)
    local digits = ''
    for i = 1, 9 do
        digits = digits .. tostring(math.random(0, 9))
    end
    return letter .. digits
end

-- Registers the physical bank card item without needing to touch qb-core's
-- own shared/items.lua. Remove this block if you'd rather define it there
-- yourself (e.g. to set a custom item image) -- just keep the item name
-- "bank_card" the same so the rest of this script keeps working.
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

QBCore.Functions.CreateUseableItem(config.cardItem, function(source, item)
    TriggerClientEvent("Renewed-Banking:client:openCardUI", source, item)
end)

-- Finds the player's physical card item (with its inventory slot), if any.
local function getCardItem(Player)
    return Player.Functions.GetItemByName(config.cardItem)
end

-- Writes a new balance onto the card's own metadata. Removing + re-adding
-- the item (in the same slot) is the safest way to update item metadata
-- across different qb-inventory forks.
local function setCardBalance(Player, cardItem, newBalance)
    local newInfo = cardItem.info
    newInfo.balance = newBalance
    Player.Functions.RemoveItem(config.cardItem, 1, cardItem.slot)
    Player.Functions.AddItem(config.cardItem, 1, cardItem.slot, newInfo)
    return newInfo
end

-- Account-agnostic helpers: an "account" here is either a citizenid (the
-- default personal account) or an extra-personal account id ("cid:2"), so
-- every one of these checks both cachedAccounts and cachedPlayers.
local function accountHasCard(account)
    if cachedAccounts[account] then return cachedAccounts[account].hasCard == true end
    if cachedPlayers[account] then return cachedPlayers[account].hasCard == true end
    return false
end

local function getCardVersion(account)
    if cachedAccounts[account] then return cachedAccounts[account].cardVersion or 1 end
    if cachedPlayers[account] then return cachedPlayers[account].cardVersion or 1 end
    return 1
end

-- Marks whether `account` has an active card, persisting it. Only the
-- default personal account and extra personal accounts support cards.
local function persistCardState(account, hasCard, version)
    if cachedAccounts[account] then
        cachedAccounts[account].hasCard = hasCard
        cachedAccounts[account].cardVersion = version
        MySQL.query("UPDATE bank_accounts_new SET hasCard = ?, cardVersion = ? WHERE id = ?", {hasCard and 1 or 0, version, account})
    elseif cachedPlayers[account] then
        cachedPlayers[account].hasCard = hasCard
        cachedPlayers[account].cardVersion = version
        MySQL.query("INSERT INTO player_transactions (id, hasCard, cardVersion) VALUES (:id, :hasCard, :cardVersion) ON DUPLICATE KEY UPDATE hasCard = :hasCard, cardVersion = :cardVersion", {
            ['id'] = account,
            ['hasCard'] = hasCard and 1 or 0,
            ['cardVersion'] = version
        })
    end
end

-- Returns {iban, holder, account name} for display purposes and confirms
-- the given citizen actually owns/has access to `account`.
local function ownsAccount(cid, account)
    if account == cid then return true end
    local acc = cachedAccounts[account]
    return acc ~= nil and acc.personal == true and acc.creator == cid
end

-- Pending card requests: [cid] = {account, iban, holder, version, readyAt}.
-- A card isn't handed over instantly - the player has to come back and
-- collect it from the ped once it's ready (see collectCard below).
local pendingCards = {}
local CARD_PREP_SECONDS = 60

-- Starts issuing a brand new physical card for `account` (must not already
-- have one/one pending). Shared by first-time issuance and the lost/stolen
-- replacement flow (which bumps the version first so any old card stops
-- working). Doesn't hand over the item - see collectCard.
local function issueCard(source, Player, account, iban, holder)
    local cid = Player.PlayerData.citizenid
    if pendingCards[cid] then
        return false, "You already have a card being prepared. Come back in a bit."
    end

    pendingCards[cid] = {
        account = account,
        iban = iban,
        holder = holder,
        version = getCardVersion(account),
        readyAt = os.time() + CARD_PREP_SECONDS
    }

    TriggerClientEvent('Renewed-Banking:client:cardPending', source, CARD_PREP_SECONDS)
    SetTimeout(CARD_PREP_SECONDS * 1000, function()
        if pendingCards[cid] then
            TriggerClientEvent('Renewed-Banking:client:cardReady', source)
        end
    end)

    return true, "Wait right there - your card is being prepared. Come back to the counter in a minute to collect it."
end

-- Hands over a prepared card once its wait is up. Called from the "Take
-- the Card" ped target option.
RegisterNetEvent('Renewed-Banking:server:collectCard', function()
    local source = source
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    local cid = Player.PlayerData.citizenid
    local pending = pendingCards[cid]

    if not pending then
        QBCore.Functions.Notify(source, "You don't have a card being prepared.", "error")
        return
    end
    if os.time() < pending.readyAt then
        QBCore.Functions.Notify(source, ("Not ready yet - wait %d more seconds."):format(pending.readyAt - os.time()), "error")
        return
    end

    local colors = config.cardColors or {'blue'}
    local added = Player.Functions.AddItem(config.cardItem, 1, false, {
        iban = pending.iban,
        holder = pending.holder,
        account = pending.account,
        frozen = false,
        color = colors[math.random(1, #colors)],
        balance = 0,
        version = pending.version
    })

    if not added then
        QBCore.Functions.Notify(source, "You don't have enough inventory space for a card.", "error")
        return
    end

    persistCardState(pending.account, true, pending.version)
    pendingCards[cid] = nil
    QBCore.Functions.Notify(source, "You picked up your new card.", "success")
end)

AddEventHandler('playerDropped', function()
    local Player = QBCore.Functions.GetPlayer(source)
    if Player then pendingCards[Player.PlayerData.citizenid] = nil end
end)


-- One-time, idempotent schema additions so card ownership/versioning can be
-- tracked for personal accounts (default + extra) without a manual migration.
MySQL.query("ALTER TABLE bank_accounts_new ADD COLUMN IF NOT EXISTS hasCard TINYINT(1) NOT NULL DEFAULT 0")
MySQL.query("ALTER TABLE bank_accounts_new ADD COLUMN IF NOT EXISTS cardVersion INT NOT NULL DEFAULT 1")
MySQL.query("ALTER TABLE player_transactions ADD COLUMN IF NOT EXISTS cardVersion INT NOT NULL DEFAULT 1")

CreateThread(function()
    MySQL.query('SELECT * FROM bank_accounts_new', {}, function(accounts)
        for _,v in pairs (accounts) do
            local job = v.id
            v.auth = json.decode(v.auth)
            cachedAccounts[job] = { --  cachedAccounts[#cachedAccounts+1]
                id = job,
                type = Lang:t("ui.org"),
                name = QBCore.Shared.Jobs[job] and QBCore.Shared.Jobs[job].label or QBCore.Shared.Gangs[job] and QBCore.Shared.Gangs[job].label or job,
                frozen = v.isFrozen == 1,
                amount = v.amount,
                transactions = json.decode(v.transactions),
                auth = {},
                creator = v.creator,
                iban = v.iban,
                hasCard = v.hasCard == 1,
                cardVersion = v.cardVersion or 1
            }
            if not cachedAccounts[job].iban or cachedAccounts[job].iban == "" then
                cachedAccounts[job].iban = genIBAN()
                MySQL.update('UPDATE bank_accounts_new SET iban = ? WHERE id = ?', {cachedAccounts[job].iban, job})
            end
            -- extra personal accounts are named "<citizenid>:2" / "<citizenid>:3"
            local personalIndex = job:match(":(%d)$")
            if personalIndex then
                cachedAccounts[job].type = Lang:t("ui.personal")
                cachedAccounts[job].name = ("Personal Account #%s"):format(personalIndex)
                cachedAccounts[job].personal = true
            end
            if #v.auth >= 1 then
                for k=1, #v.auth do
                    cachedAccounts[job].auth[v.auth[k]] = true
                end
            end
        end
    end)
end)

local function getTimeElapsed(seconds)
    local retData = ""
    local minutes = math.floor(seconds / 60)
    local hours = math.floor(minutes / 60)
    local days = math.floor(hours / 24)
    local weeks = math.floor(days / 7)

    if weeks ~= 0 and weeks > 1 then
        retData = Lang:t("time.weeks",{time=weeks})
    elseif weeks ~= 0 and weeks == 1 then
        retData = Lang:t("time.aweek")
    elseif days ~= 0 and days > 1 then
        retData = Lang:t("time.days",{time=days})
    elseif days ~= 0 and days == 1 then
        retData = Lang:t("time.aday")
    elseif hours ~= 0 and hours > 1 then
        retData = Lang:t("time.hours",{time=hours})
    elseif hours ~= 0 and hours == 1 then
        retData = Lang:t("time.ahour")
    elseif minutes ~= 0 and minutes > 1 then
        retData = Lang:t("time.mins",{time=minutes})
    elseif minutes ~= 0 and minutes == 1 then
        retData = Lang:t("time.amin")
    else
        retData = Lang:t("time.secs")
    end
    return retData
end

-- Active ATM-with-card sessions: [source] = {account = id, restricted = bool}
-- While set, getBankData/deposit/withdraw operate on the CARD's linked
-- account instead of the operator's own - this is what makes a stolen
-- card actually usable against its real owner's account.
local atmCardSession = {}

local function getCardSessionData(source)
    local session = atmCardSession[source]
    local time = os.time()

    if cachedAccounts[session.account] then
        local acc = json.decode(json.encode(cachedAccounts[session.account]))
        for i=1, #acc.transactions do
            acc.transactions[i].time = getTimeElapsed(time-acc.transactions[i].time)
        end
        acc.isFrozen = acc.frozen
        acc.frozen = nil
        return {acc}
    end

    local OwnerPlayer = QBCore.Functions.GetPlayerByCitizenId(session.account)
    if not OwnerPlayer then return nil end
    local trans = cachedPlayers[session.account] and json.decode(json.encode(cachedPlayers[session.account].transactions)) or {}
    for i=1, #trans do
        trans[i].time = getTimeElapsed(time-trans[i].time)
    end

    return {{
        id = session.account,
        type = Lang:t("ui.personal"),
        name = ("%s %s"):format(OwnerPlayer.PlayerData.charinfo.firstname, OwnerPlayer.PlayerData.charinfo.lastname),
        isFrozen = cachedPlayers[session.account] and cachedPlayers[session.account].isFrozen or false,
        amount = OwnerPlayer.PlayerData.money.bank,
        cash = QBCore.Functions.GetPlayer(source) and QBCore.Functions.GetPlayer(source).PlayerData.money.cash or 0,
        iban = cachedPlayers[session.account] and cachedPlayers[session.account].iban,
        transactions = trans
    }}
end

local function getBankData(source)
    if atmCardSession[source] then
        local data = getCardSessionData(source)
        if data then return data end
    end

    local Player = QBCore.Functions.GetPlayer(source)
    local bankData = {}
    local time = os.time()

    bankData[#bankData+1] = {
        id = Player.PlayerData.citizenid,
        type = Lang:t("ui.personal"),
        name = ("%s %s"):format(Player.PlayerData.charinfo.firstname, Player.PlayerData.charinfo.lastname),
        frozen = cachedPlayers[Player.PlayerData.citizenid].isFrozen,
        amount = Player.PlayerData.money.bank,
        cash = Player.PlayerData.money.cash,
        iban = cachedPlayers[Player.PlayerData.citizenid].iban,
        hasCard = cachedPlayers[Player.PlayerData.citizenid].hasCard == true,
        transactions = json.decode(json.encode(cachedPlayers[Player.PlayerData.citizenid].transactions)),
    }

    for k=1, #bankData[1].transactions do
        bankData[1].transactions[k].time = getTimeElapsed(time-bankData[1].transactions[k].time)
    end

    local job = json.decode(json.encode(cachedAccounts[Player.PlayerData.job.name]))
    if job and QBCore.Shared.Jobs[Player.PlayerData.job.name].grades[tostring(Player.PlayerData.job.grade.level)].bankAuth then
        for k=1, #job.transactions do
            job.transactions[k].time = getTimeElapsed(time-job.transactions[k].time)
        end
        bankData[#bankData+1] = job
    end

    local gang = json.decode(json.encode(cachedAccounts[Player.PlayerData.gang.name]))
    if gang and QBCore.Shared.Gangs[Player.PlayerData.gang.name].grades[tostring(Player.PlayerData.gang.grade.level)].bankAuth then
        for k=1, #gang.transactions do
            gang.transactions[k].time = getTimeElapsed(time-gang.transactions[k].time)
        end
        bankData[#bankData+1] = gang
    end

    local sharedAccounts = cachedPlayers[Player.PlayerData.citizenid].accounts
    for k=1, #sharedAccounts do
        local sAccount = json.decode(json.encode(cachedAccounts[sharedAccounts[k]]))
        for i=1, #sAccount.transactions do
            sAccount.transactions[i].time = getTimeElapsed(time-sAccount.transactions[i].time)
        end
        bankData[#bankData+1] = sAccount
    end

    for k=1, #bankData do
        if bankData[k].frozen ~= nil then
            bankData[k].isFrozen = bankData[k].frozen
            bankData[k].frozen = nil
        end
    end

    return bankData
end

QBCore.Functions.CreateCallback("Renewed-Banking:server:initalizeBanking", function(source, cb)
    local bankData = getBankData(source)
    cb(bankData)
end)

local function updatePlayerAccount(cid)
    MySQL.query('SELECT * FROM player_transactions WHERE id = @id ', {['@id'] = cid}, function(account)
        local query = '%' .. cid .. '%'
        MySQL.query("SELECT * FROM bank_accounts_new WHERE auth LIKE ? ", {query}, function(shared)
            cachedPlayers[cid] = {
                isFrozen = #account > 0 and account[1].isFrozen == 1,
                hasCard = #account > 0 and account[1].hasCard == 1,
                cardVersion = (#account > 0 and account[1].cardVersion) or 1,
                iban = #account > 0 and account[1].iban or nil,
                transactions = #account > 0 and json.decode(account[1].transactions) or {},
                accounts = {}
            }

            if not cachedPlayers[cid].iban or cachedPlayers[cid].iban == "" then
                cachedPlayers[cid].iban = genIBAN()
                MySQL.query("INSERT INTO player_transactions (id, iban) VALUES (:id, :iban) ON DUPLICATE KEY UPDATE iban = :iban", {
                    ['id'] = cid,
                    ['iban'] = cachedPlayers[cid].iban
                })
            end

            if #shared >= 1 then
                for k=1, #shared do
                    cachedPlayers[cid].accounts[#cachedPlayers[cid].accounts+1] = shared[k].id
                end
            end
        end)
    end)
end

RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    local Player = QBCore.Functions.GetPlayer(source)
    local cid = Player.PlayerData.citizenid
    updatePlayerAccount(cid)
end)

-- Events
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        for _, v in pairs(QBCore.Functions.GetPlayers()) do
            local Player = QBCore.Functions.GetPlayer(v)
            if Player then
                local cid = Player.PlayerData.citizenid
                updatePlayerAccount(cid)
            end
        end
    end
end)

local function genTransactionID()
    local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function (c)
        local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
        return string.format('%x', v)
    end)
end

local function handleTransaction(account, title, amount, message, issuer, receiver, type, transID)
    local transaction = {
        trans_id = transID or genTransactionID(),
        title = title,
        amount = amount,
        trans_type = type,
        receiver = receiver,
        message = message,
        issuer = issuer,
        time = os.time()
    }
    if cachedAccounts[account] then
        table.insert(cachedAccounts[account].transactions, 1, transaction)
        MySQL.query("INSERT INTO bank_accounts_new (id, amount, transactions) VALUES (:id, :amount, :transactions) ON DUPLICATE KEY UPDATE amount = :amount, transactions = :transactions",{
            ['id'] = account,
            ['amount'] = cachedAccounts[account].amount,
            ['transactions'] = json.encode(cachedAccounts[account].transactions)
        })
    elseif cachedPlayers[account] then
        table.insert(cachedPlayers[account].transactions, 1, transaction)
        MySQL.query("INSERT INTO player_transactions (id, transactions) VALUES (:id, :transactions) ON DUPLICATE KEY UPDATE transactions = :transactions",{
            ['id'] = account,
            ['transactions'] = json.encode(cachedPlayers[account].transactions)
        })
    else
        print(Lang:t("logs.invalid_account",{account=account}))
    end
    return transaction
end exports("handleTransaction", handleTransaction)

local function getAccountMoney(account)
    if not cachedAccounts[account] then
        Lang:t("logs.invalid_account",{account=account})
        return false
    end
    return cachedAccounts[account].amount
end exports('getAccountMoney', getAccountMoney)

local function addAccountMoney(account, amount)
    if not cachedAccounts[account] then
        Lang:t("logs.invalid_account",{account=account})
        return false
    end
    cachedAccounts[account].amount += amount
    return true
end exports('addAccountMoney', addAccountMoney)

local function isAccountFrozen(account)
    if cachedAccounts[account] then return cachedAccounts[account].frozen == true or cachedAccounts[account].frozen == 1 end
    if cachedPlayers[account] then return cachedPlayers[account].isFrozen == true or cachedPlayers[account].isFrozen == 1 end
    return false
end

-- Resolves whose PERSONAL (non-shared) bank money an operation should hit:
-- normally the operator's own, but inside a card session pointed at
-- someone else's account (a stolen card), it's that account's owner.
local function resolveBankOwner(source, account)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player or Player.PlayerData.citizenid == account then return Player end
    return QBCore.Functions.GetPlayerByCitizenId(account)
end

QBCore.Functions.CreateCallback("Renewed-Banking:server:deposit", function(source, cb, data)
    local Player = QBCore.Functions.GetPlayer(source)
    if isAccountFrozen(data.fromAccount) then
        TriggerClientEvent('Renewed-Banking:client:sendNotification', source, "This account is frozen and cannot be used.")
        cb(false)
        return
    end
    if atmCardSession[source] and atmCardSession[source].restricted then
        TriggerClientEvent('Renewed-Banking:client:sendNotification', source, "This card has no PIN set - it can only be used to withdraw.")
        cb(false)
        return
    end
    local amount = tonumber(data.amount)
    if not amount or amount < 1 then QBCore.Functions.Notify(source, Lang:t("notify.invalid_amount",{type="deposit"}), 'error', 5000) end
    local name = ("%s %s"):format(Player.PlayerData.charinfo.firstname, Player.PlayerData.charinfo.lastname)
    if not data.comment or data.comment == "" then data.comment = Lang:t("notify.comp_transaction",{name = name, type="deposited", amount = amount}) end
    if Player.Functions.RemoveMoney('cash', amount, data.comment) then
        if cachedAccounts[data.fromAccount] then
            addAccountMoney(data.fromAccount, amount)
        else
            local OwnerPlayer = resolveBankOwner(source, data.fromAccount)
            if not OwnerPlayer then
                Player.Functions.AddMoney('cash', amount, data.comment) -- refund, owner not reachable
                TriggerClientEvent('Renewed-Banking:client:sendNotification', source, "That account's owner must be online.")
                cb(false)
                return
            end
            OwnerPlayer.Functions.AddMoney('bank', amount, data.comment)
        end
        handleTransaction(data.fromAccount,Lang:t("ui.personal_acc") .. data.fromAccount, amount, data.comment, name, data.fromAccount, "deposit")
        local bankData = getBankData(source)
        cb(bankData)
    else
        TriggerClientEvent('Renewed-Banking:client:sendNotification', source, Lang:t("notify.not_enough_money"))
        cb(false)
    end
end)

local function removeAccountMoney(account, amount)
    if not cachedAccounts[account] then
        print(Lang:t("logs.invalid_account",{account=account}))
        return false
    end
    if cachedAccounts[account].amount < amount then
        print(Lang:t("logs.broke_account",{account=account, amount=amount}))
        return false
    end

    cachedAccounts[account].amount -= amount
    return true
end exports('removeAccountMoney', removeAccountMoney)

QBCore.Functions.CreateCallback("Renewed-Banking:server:withdraw", function(source, cb, data)
    local Player = QBCore.Functions.GetPlayer(source)
    if isAccountFrozen(data.fromAccount) then
        TriggerClientEvent('Renewed-Banking:client:sendNotification', source, "This account is frozen and cannot be used.")
        cb(false)
        return
    end
    local MyMeta = Player.PlayerData.metadata['services']
    if MyMeta then 
        TriggerClientEvent('Renewed-Banking:client:sendNotification', source, 'Your services is locked you can\'t withdraw money')
        cb(false)
    else
        local amount = tonumber(data.amount)
        if not amount or amount < 1 then QBCore.Functions.Notify(source, Lang:t("notify.invalid_amount",{type="withdraw"}), 'error', 5000) end
        local name = ("%s %s"):format(Player.PlayerData.charinfo.firstname, Player.PlayerData.charinfo.lastname)
        if not data.comment or data.comment == "" then data.comment = Lang:t("notify.comp_transaction",{name = name, type="withdrawed", amount = amount}) end
    
        local canWithdraw = false
        local OwnerPlayer = nil
        if cachedAccounts[data.fromAccount] then
            canWithdraw = removeAccountMoney(data.fromAccount, amount)
        else
            OwnerPlayer = resolveBankOwner(source, data.fromAccount)
            if not OwnerPlayer then
                TriggerClientEvent('Renewed-Banking:client:sendNotification', source, "That account's owner must be online.")
                cb(false)
                return
            end
            canWithdraw = OwnerPlayer.Functions.RemoveMoney('bank', amount, data.comment)
        end
        if canWithdraw then
            Player.Functions.AddMoney('cash', amount, data.comment)
            handleTransaction(data.fromAccount,Lang:t("ui.personal_acc") .. data.fromAccount, amount, data.comment, data.fromAccount, name, "withdraw")
            local bankData = getBankData(source)
            cb(bankData)
        else
            TriggerClientEvent('Renewed-Banking:client:sendNotification', source, Lang:t("notify.not_enough_money"))
            cb(false)
        end
    end
end)

local function getPlayerData(source, id)
    local Player = QBCore.Functions.GetPlayer(tonumber(id))
    if not Player then Player = QBCore.Functions.GetPlayerByCitizenId(id) end
    if Player and not cachedPlayers[Player.PlayerData.citizenid] then
        local offlineTrans = {}
        local pushingP = promise.new()
        MySQL.query('SELECT * FROM player_transactions WHERE id = @id ', {['@id'] = id}, function(account)
            local resolve = account[1] and json.decode(account[1].transactions) or {}
            pushingP:resolve(resolve)
        end)
        offlineTrans = Citizen.Await(pushingP)
        cachedPlayers[id] = {transactions = offlineTrans}
    end
    if not Player then
        local msg = ("Cannot Find Account(%s)"):format(id)
        print(Lang:t("logs.invalid_account",{account=id}))
        if source then
            QBCore.Functions.Notify(source, msg, 'error', 5000)
        end
    end
    return Player
end

QBCore.Functions.CreateCallback("Renewed-Banking:server:transfer", function(source, cb, data)
    local Player = QBCore.Functions.GetPlayer(source)
    if isAccountFrozen(data.fromAccount) then
        TriggerClientEvent('Renewed-Banking:client:sendNotification', source, "This account is frozen and cannot be used.")
        cb(false)
        return
    end
    if atmCardSession[source] and atmCardSession[source].restricted then
        TriggerClientEvent('Renewed-Banking:client:sendNotification', source, "This card has no PIN set - it can only be used to withdraw.")
        cb(false)
        return
    end
    local MyMeta = Player.PlayerData.metadata['services']
    if MyMeta then 
        TriggerClientEvent('Renewed-Banking:client:sendNotification', source, 'Your services is locked you can\'t transfer money')
        cb(false)
    else
        local amount = tonumber(data.amount)
        if not amount or amount < 1 then QBCore.Functions.Notify(source, Lang:t("notify.invalid_amount",{type="transfer"}), 'error', 5000) end
        if not data.comment or data.comment == "" then data.comment = Lang:t("notify.comp_transaction",{name = name, type="transfered", amount = amount}) end
        if cachedAccounts[data.fromAccount] then
            if cachedAccounts[data.stateid] then
                local canTransfer = removeAccountMoney(data.fromAccount, amount)
                if canTransfer then
                    addAccountMoney(data.stateid, amount)
                    local title = ("%s / %s"):format(cachedAccounts[data.fromAccount].name, data.fromAccount)
                    local transaction = handleTransaction(data.fromAccount, title, amount, data.comment, cachedAccounts[data.fromAccount].name, cachedAccounts[data.stateid].name, "withdraw")
                    handleTransaction(data.stateid, title, amount, data.comment, cachedAccounts[data.fromAccount].name, cachedAccounts[data.stateid].name, "deposit", transaction.trans_id)
                else
                    TriggerClientEvent('Renewed-Banking:client:sendNotification', source, Lang:t("notify.not_enough_money"))
                    cb(false)
                    return
                end
            else
                local Player2 = getPlayerData(source, data.stateid)
                if not Player2 then
                    TriggerClientEvent('Renewed-Banking:client:sendNotification', source, Lang:t("notify.fail_transfer"))
                    cb(false)
                    return
                end
                local canTransfer = removeAccountMoney(data.fromAccount, amount)
                if canTransfer then
                    Player2.Functions.AddMoney('bank', amount, data.comment)
                    local name = ("%s %s"):format(Player2.PlayerData.charinfo.firstname, Player2.PlayerData.charinfo.lastname)
                    local transaction = handleTransaction(data.fromAccount, ("%s / %s"):format(cachedAccounts[data.fromAccount].name, data.fromAccount), amount, data.comment, cachedAccounts[data.fromAccount].name, name, "withdraw")
                    handleTransaction(data.stateid, ("%s / %s"):format(cachedAccounts[data.fromAccount].name, data.fromAccount), amount, data.comment, cachedAccounts[data.fromAccount].name, name, "deposit", transaction.trans_id)
                else
                    TriggerClientEvent('Renewed-Banking:client:sendNotification', source, Lang:t("notify.not_enough_money"))
                    cb(false)
                    return
                end
            end
        else
            if cachedAccounts[data.stateid] then
                if Player.Functions.RemoveMoney('bank', amount, data.comment) then
                    addAccountMoney(data.stateid, amount)
                    local name = ("%s %s"):format(Player.PlayerData.charinfo.firstname, Player.PlayerData.charinfo.lastname)
                    local transaction = handleTransaction(data.fromAccount, Lang:t("ui.personal_acc") .. data.fromAccount, amount, data.comment, name, cachedAccounts[data.stateid].name, "withdraw")
                    handleTransaction(data.stateid, Lang:t("ui.personal_acc") .. data.fromAccount, amount, data.comment, name, cachedAccounts[data.stateid].name, "deposit", transaction.trans_id)
                else
                    TriggerClientEvent('Renewed-Banking:client:sendNotification', source, Lang:t("notify.not_enough_money"))
                    cb(false)
                    return
                end
            else
                local Player2 = getPlayerData(source, data.stateid)
                if not Player2 then
                    TriggerClientEvent('Renewed-Banking:client:sendNotification', source, Lang:t("notify.fail_transfer"))
                    cb(false)
                    return
                end
    
                if Player.Functions.RemoveMoney('bank', amount, data.comment) then
                    Player2.Functions.AddMoney('bank', amount, data.comment)
                    local name = ("%s %s"):format(Player.PlayerData.charinfo.firstname, Player.PlayerData.charinfo.lastname)
                    local name2 = ("%s %s"):format(Player2.PlayerData.charinfo.firstname, Player2.PlayerData.charinfo.lastname)
                    local transaction = handleTransaction(data.fromAccount, Lang:t("ui.personal_acc") .. data.fromAccount, amount, data.comment, name, name2, "withdraw")
                    handleTransaction(data.stateid, Lang:t("ui.personal_acc") .. data.fromAccount, amount, data.comment, name, name2, "deposit", transaction.trans_id)
                else
                    TriggerClientEvent('Renewed-Banking:client:sendNotification', source, Lang:t("notify.not_enough_money"))
                    cb(false)
                    return
                end
            end
        end
        local bankData = getBankData(source)
        cb(bankData)
    end
end)

RegisterNetEvent('Renewed-Banking:server:createNewAccount', function(accountid)
    local Player = QBCore.Functions.GetPlayer(source)
    if cachedAccounts[accountid] then QBCore.Functions.Notify(source, Lang:t("notify.account_taken"), "error") return end
    cachedAccounts[accountid] = {
        id = accountid,
        type = Lang:t("ui.org"),
        name = accountid,
        frozen = 0,
        amount = 0,
        transactions = {},
        auth = { [Player.PlayerData.citizenid] = true },
        creator = Player.PlayerData.citizenid,
        iban = genIBAN()

    }
    cachedPlayers[Player.PlayerData.citizenid].accounts[#cachedPlayers[Player.PlayerData.citizenid].accounts+1] = accountid
    MySQL.query("INSERT INTO bank_accounts_new (id, amount, transactions, auth, isFrozen, creator, iban) VALUES (:id, :amount, :transactions, :auth, :isFrozen, :creator, :iban) ",{
        ['id'] = accountid,
        ['amount'] = cachedAccounts[accountid].amount,
        ['transactions'] = json.encode(cachedAccounts[accountid].transactions),
        ['auth'] = json.encode({Player.PlayerData.citizenid}),
        ['isFrozen'] = cachedAccounts[accountid].frozen,
        ['creator'] = Player.PlayerData.citizenid,
        ['iban'] = cachedAccounts[accountid].iban
    })
end)

RegisterNetEvent("Renewed-Banking:server:getPlayerAccounts", function()
    local Player = QBCore.Functions.GetPlayer(source)

    local table = {{
        isMenuHeader = true,
        header = Lang:t("menu.bank_name")
    }}
    local accounts = cachedPlayers[Player.PlayerData.citizenid].accounts
    if #accounts >= 1 then
        for k=1, #accounts do
            if cachedAccounts[accounts[k]].creator == Player.PlayerData.citizenid then
                table[#table+1] = {
                    header = accounts[k],
                    txt = Lang:t("menu.view_members"),
                    params = {
                        isServer =true,
                        event = 'Renewed-Banking:server:viewAccountMenu',
                        args = {
                            account = accounts[k],
                        }
                    }
                }
            end
        end
    end
    if #table == 1 then
        table[#table+1] = {
            header = Lang:t("menu.no_account"),
            txt = Lang:t("menu.no_account_txt"),
            isMenuHeader = true
        }
    end
    TriggerClientEvent("qb-menu:client:openMenu", source, table)
end)

RegisterNetEvent("Renewed-Banking:server:viewAccountMenu", function(data)
    local Player = QBCore.Functions.GetPlayer(source)

    local table = {
        {
            isMenuHeader = true,
            header = Lang:t("menu.bank_name")
        },
        {
            header = Lang:t("menu.manage_members"),
            txt = Lang:t("menu.manage_members_txt"),
            params = {
                isServer =true,
                event = 'Renewed-Banking:server:viewMemberManagement',
                args = data
            }
        },
        {
            header = Lang:t("menu.edit_acc_name"),
            txt = Lang:t("menu.edit_acc_name_txt"),
            params = {
                event = 'Renewed-Banking:client:changeAccountName',
                args = data
            }
        }
    }
    TriggerClientEvent("qb-menu:client:openMenu", source, table)
end)

RegisterNetEvent("Renewed-Banking:server:viewMemberManagement", function(data)
    local Player = QBCore.Functions.GetPlayer(source)

    local table = {{
        isMenuHeader = true,
        header = Lang:t("menu.bank_name")
    }}
    local account = data.account
    for k,_ in pairs(cachedAccounts[account].auth) do
        local Player2 = getPlayerData(source, k)
        local charInfo = Player2.PlayerData.charinfo
        if Player.PlayerData.citizenid ~= Player2.PlayerData.citizenid then
            table[#table+1] = {
                header = ("%s %s"):format(charInfo.firstname, charInfo.lastname),
                txt = Lang:t("menu.remove_member_txt"),
                params = {
                    isServer =true,
                    event = 'Renewed-Banking:server:removeMemberConfirmation',
                    args = {
                        account = account,
                        cid = k,
                    }
                }
            }
        end
    end
    table[#table+1] = {
        header = Lang:t("menu.add_member"),
        txt = Lang:t("menu.add_member_txt"),
        params = {
            event = 'Renewed-Banking:client:addAccountMember',
            args = {
                account = account
            }
        }
    }
    TriggerClientEvent("qb-menu:client:openMenu", source, table)
end)

RegisterNetEvent('Renewed-Banking:server:addAccountMember', function(account, member)
    local Player = QBCore.Functions.GetPlayer(source)

    if Player.PlayerData.citizenid ~= cachedAccounts[account].creator then print(Lang:t("logs.illegal_action", {name=GetPlayerName(source)})) return end
    local Player2 = getPlayerData(source, member)
    if not Player2 then return end

    local targetCID = Player2.PlayerData.citizenid
    if not Player2.Offline and cachedPlayers[targetCID] then
        cachedPlayers[targetCID].accounts[#cachedPlayers[targetCID].accounts+1] = account
    end

    local auth = {}
    for k,v in pairs(cachedAccounts[account].auth) do auth[#auth+1] = k end
    auth[#auth+1] = targetCID
    cachedAccounts[account].auth[targetCID] = true
    MySQL.update('UPDATE bank_accounts_new SET auth = ? WHERE id = ?',{json.encode(auth), account})
end)

RegisterNetEvent('Renewed-Banking:server:removeMemberConfirmation', function(data)
    local Player = QBCore.Functions.GetPlayer(source)
    local table = {
        {
            isMenuHeader = true,
            header = Lang:t("menu.bank_name")
        },
        {
            header = Lang:t("menu.back"),
            icon = "fa-solid fa-angle-left",
            params = {
                isServer =true,
                event = "Renewed-Banking:server:viewAccountMenu",
                args = data
            }
        },
        {
            header = Lang:t("menu.remove_member"),
            txt = Lang:t("menu.remove_member_txt2", {id=data.cid}),
            params = {
                isServer =true,
                event = 'Renewed-Banking:server:removeAccountMember',
                args = data
            }
        }
    }

    TriggerClientEvent("qb-menu:client:openMenu", source, table)

end)

RegisterNetEvent('Renewed-Banking:server:removeAccountMember', function(data)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player.PlayerData.citizenid ~= cachedAccounts[data.account].creator then print(Lang:t("logs.illegal_action", {name=GetPlayerName(source)})) return end
    local Player2 = getPlayerData(source, data.cid)
    if not Player2 then return end

    local targetCID = Player2.PlayerData.citizenid
    local tmp = {}
    for k in pairs(cachedAccounts[data.account].auth) do
        if targetCID ~= k then
            tmp[#tmp+1] = k
        end
    end

    if not Player2.Offline and cachedPlayers[targetCID] then
        local newAccount = {}
        if #cachedPlayers[targetCID].accounts >= 1 then
            for k=1, #cachedPlayers[targetCID].accounts do
                if cachedPlayers[targetCID].accounts[k] ~= data.account then
                    newAccount[#newAccount+1] = cachedPlayers[targetCID].accounts[k]
                end
            end
        end
        cachedPlayers[targetCID].accounts = newAccount
    end
    cachedAccounts[data.account].auth[targetCID] = nil
    MySQL.update('UPDATE bank_accounts_new SET auth = ? WHERE id = ?',{json.encode(tmp), data.account})
end)

RegisterNetEvent('Renewed-Banking:server:changeAccountName', function(account, newName)
    local Player = QBCore.Functions.GetPlayer(source)
    if not cachedAccounts[account] then print(Lang:t("logs.invalid_account",{account=account})) return end
    if Player.PlayerData.citizenid ~= cachedAccounts[account].creator then print(Lang:t("logs.illegal_action", {name=GetPlayerName(source)})) return end

    cachedAccounts[newName] = json.decode(json.encode(cachedAccounts[account]))
    cachedAccounts[newName].id = newName
    cachedAccounts[newName].name = newName
    cachedAccounts[account] = nil

    for _, v in pairs(QBCore.Functions.GetPlayers()) do
        local Player2 = QBCore.Functions.GetPlayer(v)
        if Player2 then
            local cid = Player2.PlayerData.citizenid
            if #cachedPlayers[cid].accounts >= 1 then
                for k=1, #cachedPlayers[cid].accounts do
                    if cachedPlayers[cid].accounts[k] == account then
                        table.remove(cachedPlayers[cid].accounts, k)
                        cachedPlayers[cid].accounts[#cachedPlayers[cid].accounts+1] = newName
                    end
                end
            end
        end
    end

    MySQL.update('UPDATE bank_accounts_new SET id = ? WHERE id = ?',{newName, account})
end)

-- Should only use this on very secure backends to avoid anyone using this as this is a server side ONLY export --
local function changeAccountName(account, newName)
    if not account or not newName then return end
    if cachedAccounts[newName] then print(Lang:t("logs.invalid_account",{account=account})) return end
    if not cachedAccounts[account] then print(Lang:t("logs.existing_account",{account=account})) return end

    cachedAccounts[newName] = json.decode(json.encode(cachedAccounts[account]))
    cachedAccounts[newName].id = newName
    cachedAccounts[newName].name = newName
    cachedAccounts[account] = nil

    for _, v in pairs(QBCore.Functions.GetPlayers()) do
        local Player2 = QBCore.Functions.GetPlayer(v)
        if Player2 then
            local cid = Player2.PlayerData.citizenid
            if #cachedPlayers[cid].accounts >= 1 then
                for k=1, #cachedPlayers[cid].accounts do
                    if cachedPlayers[cid].accounts[k] == account then
                        table.remove(cachedPlayers[cid].accounts, k)
                        cachedPlayers[cid].accounts[#cachedPlayers[cid].accounts+1] = newName
                    end
                end
            end
        end
    end

    MySQL.update('UPDATE bank_accounts_new SET id = ? WHERE id = ?',{newName, account})

    return true
end exports("changeAccountName", changeAccountName)


local function addAccountMember(account, member)
    if not account or not member then return end

    if not cachedAccounts[account] then print(Lang:t("logs.invalid_account",{account=account})) return end

    local Player2 = getPlayerData(false, member)
    if not Player2 then return end

    local targetCID = Player2.PlayerData.citizenid
    if not Player2.Offline and cachedPlayers[targetCID] then
        cachedPlayers[targetCID].accounts[#cachedPlayers[targetCID].accounts+1] = account
    end

    local auth = {}
    for k, _ in pairs(cachedAccounts[account].auth) do auth[#auth+1] = k end
    auth[#auth+1] = targetCID
    cachedAccounts[account].auth[targetCID] = true
    MySQL.update('UPDATE bank_accounts_new SET auth = ? WHERE id = ?',{json.encode(auth), account})

end exports("addAccountMember", addAccountMember)

local function removeAccountMember(account, member)
    local Player2 = getPlayerData(false, member)

    if not Player2 then return end
    if not cachedAccounts[account] then print(Lang:t("logs.invalid_account",{account=account})) return end

    local targetCID = Player2.PlayerData.citizenid

    local tmp = {}
    for k in pairs(cachedAccounts[account].auth) do
        if targetCID ~= k then
            tmp[#tmp+1] = k
        end
    end


    if not Player2.Offline and cachedPlayers[targetCID] then
        local newAccount = {}
        if #cachedPlayers[targetCID].accounts >= 1 then
            for k=1, #cachedPlayers[targetCID].accounts do
                if cachedPlayers[targetCID].accounts[k] ~= account then
                    newAccount[#newAccount+1] = cachedPlayers[targetCID].accounts[k]
                end
            end
        end
        cachedPlayers[targetCID].accounts = newAccount
    end

    cachedAccounts[account].auth[targetCID] = nil

    MySQL.update('UPDATE bank_accounts_new SET auth = ? WHERE id = ?',{json.encode(tmp), account})
end exports("removeAccountMember", removeAccountMember)

-- Card freeze / unfreeze (Cards tab security feature)
-- Personal account: player can freeze/unfreeze their own card at will.
-- Shared/org account: only the account creator may freeze/unfreeze it.
QBCore.Functions.CreateCallback("Renewed-Banking:server:toggleFreeze", function(source, cb, data)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then cb(false) return end
    local cid = Player.PlayerData.citizenid
    local account = data.account

    if account == cid and cachedPlayers[cid] then
        cachedPlayers[cid].isFrozen = not (cachedPlayers[cid].isFrozen == true or cachedPlayers[cid].isFrozen == 1)
        MySQL.query("INSERT INTO player_transactions (id, isFrozen) VALUES (:id, :isFrozen) ON DUPLICATE KEY UPDATE isFrozen = :isFrozen", {
            ['id'] = cid,
            ['isFrozen'] = cachedPlayers[cid].isFrozen and 1 or 0
        })
    elseif cachedAccounts[account] then
        if cachedAccounts[account].creator ~= cid then
            TriggerClientEvent('Renewed-Banking:client:sendNotification', source, "You do not have permission to freeze this account.")
            cb(false)
            return
        end
        cachedAccounts[account].frozen = not (cachedAccounts[account].frozen == true or cachedAccounts[account].frozen == 1)
        MySQL.update('UPDATE bank_accounts_new SET isFrozen = ? WHERE id = ?', {cachedAccounts[account].frozen and 1 or 0, account})
    else
        cb(false)
        return
    end

    local bankData = getBankData(source)
    cb(bankData)
end)


-- Issues the physical bank card item for the player's default personal
-- account. Gate-kept to ATMs client-side, and now to one card per account.
QBCore.Functions.CreateCallback("Renewed-Banking:server:requestCard", function(source, cb, data)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then cb(false) return end
    local cid = Player.PlayerData.citizenid
    if not cachedPlayers[cid] then cb(false) return end

    if accountHasCard(cid) then
        TriggerClientEvent('Renewed-Banking:client:sendNotification', source, "You already have a card for this account. Report it lost/stolen to replace it.")
        cb(false)
        return
    end

    if not cachedPlayers[cid].iban or cachedPlayers[cid].iban == "" then
        cachedPlayers[cid].iban = genIBAN()
    end

    local name = ("%s %s"):format(Player.PlayerData.charinfo.firstname, Player.PlayerData.charinfo.lastname)
    local ok, msg = issueCard(source, Player, cid, cachedPlayers[cid].iban, name)
    TriggerClientEvent('Renewed-Banking:client:sendNotification', source, msg)
    if not ok then
        cb(false)
        return
    end

    local bankData = getBankData(source)
    cb(bankData)
end)

-- Card payment system -------------------------------------------------
-- Loads money from the player's personal bank account onto their physical
-- card's own balance.
QBCore.Functions.CreateCallback("Renewed-Banking:server:loadCard", function(source, cb, data)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then cb(false) return end

    local amount = tonumber(data and data.amount)
    if not amount or amount < 1 then
        TriggerClientEvent('Renewed-Banking:client:sendNotification', source, "Invalid amount.")
        cb(false)
        return
    end

    local cardItem = getCardItem(Player)
    if not cardItem or not cardItem.info then
        TriggerClientEvent('Renewed-Banking:client:sendNotification', source, "You don't have a bank card.")
        cb(false)
        return
    end

    if isAccountFrozen(cardItem.info.account) then
        TriggerClientEvent('Renewed-Banking:client:sendNotification', source, "This account is frozen and cannot be used.")
        cb(false)
        return
    end

    if not Player.Functions.RemoveMoney('bank', amount, "Loaded onto bank card") then
        TriggerClientEvent('Renewed-Banking:client:sendNotification', source, Lang:t("notify.not_enough_money"))
        cb(false)
        return
    end

    local newInfo = setCardBalance(Player, cardItem, (cardItem.info.balance or 0) + amount)

    local name = ("%s %s"):format(Player.PlayerData.charinfo.firstname, Player.PlayerData.charinfo.lastname)
    handleTransaction(cardItem.info.account, "Card Top-Up", amount, "Loaded onto physical card", name, "CARD", "withdraw")

    cb({balance = newInfo.balance})
end)

-- Pays another online player straight from the card's balance (cash in
-- their hand, like a tap-to-pay). Doesn't touch the bank account at all.
QBCore.Functions.CreateCallback("Renewed-Banking:server:payWithCard", function(source, cb, data)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then cb(false) return end

    local amount = tonumber(data and data.amount)
    local targetId = tonumber(data and data.target)
    if not amount or amount < 1 or not targetId then
        TriggerClientEvent('Renewed-Banking:client:sendNotification', source, "Invalid payment details.")
        cb(false)
        return
    end

    if targetId == source then
        TriggerClientEvent('Renewed-Banking:client:sendNotification', source, "You can't pay yourself.")
        cb(false)
        return
    end

    local Target = QBCore.Functions.GetPlayer(targetId)
    if not Target then
        TriggerClientEvent('Renewed-Banking:client:sendNotification', source, "That player isn't online.")
        cb(false)
        return
    end

    local cardItem = getCardItem(Player)
    if not cardItem or not cardItem.info then
        TriggerClientEvent('Renewed-Banking:client:sendNotification', source, "You don't have a bank card.")
        cb(false)
        return
    end

    if cardItem.info.frozen then
        TriggerClientEvent('Renewed-Banking:client:sendNotification', source, "This card is frozen.")
        cb(false)
        return
    end

    if (cardItem.info.balance or 0) < amount then
        TriggerClientEvent('Renewed-Banking:client:sendNotification', source, "Not enough balance on your card.")
        cb(false)
        return
    end

    local newInfo = setCardBalance(Player, cardItem, cardItem.info.balance - amount)
    Target.Functions.AddMoney('cash', amount, "Card payment received")

    local payerName = ("%s %s"):format(Player.PlayerData.charinfo.firstname, Player.PlayerData.charinfo.lastname)
    TriggerClientEvent('Renewed-Banking:client:sendNotification', targetId, ("You received $%d by card from %s"):format(amount, payerName))

    cb({balance = newInfo.balance})
end)

-- Lets other resources (shops, POS terminals, vending machines, etc.)
-- charge a player's card balance directly, e.g.:
--   local ok = exports['Renewed-Banking']:chargeCard(source, 250, "Ammu-Nation purchase")
local function chargeCard(source, amount, reason)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end
    amount = tonumber(amount)
    if not amount or amount < 1 then return false end

    local cardItem = getCardItem(Player)
    if not cardItem or not cardItem.info then return false end
    if cardItem.info.frozen then return false end
    if (cardItem.info.balance or 0) < amount then return false end

    setCardBalance(Player, cardItem, cardItem.info.balance - amount)
    TriggerClientEvent('Renewed-Banking:client:sendNotification', source, ("Card charged $%d%s"):format(amount, reason and (" - " .. reason) or ""))
    return true
end exports('chargeCard', chargeCard)

-- ==========================================================================
-- Extra personal bank accounts (up to #config.personalAccountCosts extra,
-- on top of your free default one)
-- ==========================================================================

local function countExtraPersonalAccounts(cid)
    local extra = 0
    for _, accId in ipairs(cachedPlayers[cid].accounts) do
        local acc = cachedAccounts[accId]
        if acc and acc.personal and acc.creator == cid then extra = extra + 1 end
    end
    return extra
end

-- Shared core logic (used by both the ped qb-menu path and the NUI's
-- Accounts tab). Returns ok, message.
local function doOpenAccount(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false, "Player not found." end
    local cid = Player.PlayerData.citizenid

    local extra = countExtraPersonalAccounts(cid)
    if extra >= #config.personalAccountCosts then
        return false, "You've reached the maximum number of accounts."
    end

    local cost = config.personalAccountCosts[extra + 1]
    if not Player.Functions.RemoveMoney('bank', cost, "Opened a new personal bank account") then
        return false, ("You need $%d in your bank to open this account."):format(cost)
    end

    local index = extra + 2
    local accountid = ("%s:%d"):format(cid, index)
    cachedAccounts[accountid] = {
        id = accountid,
        type = Lang:t("ui.personal"),
        name = ("Personal Account #%d"):format(index),
        frozen = false,
        amount = 0,
        transactions = {},
        auth = { [cid] = true },
        creator = cid,
        personal = true,
        iban = genIBAN()
    }
    cachedPlayers[cid].accounts[#cachedPlayers[cid].accounts+1] = accountid

    MySQL.query("INSERT INTO bank_accounts_new (id, amount, transactions, auth, isFrozen, creator, iban) VALUES (:id, :amount, :transactions, :auth, :isFrozen, :creator, :iban)", {
        ['id'] = accountid,
        ['amount'] = 0,
        ['transactions'] = json.encode({}),
        ['auth'] = json.encode({cid}),
        ['isFrozen'] = 0,
        ['creator'] = cid,
        ['iban'] = cachedAccounts[accountid].iban
    })

    return true, ("Opened Personal Account #%d for $%d."):format(index, cost)
end

local function doCloseAccount(source, accId)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false, "Player not found." end
    local cid = Player.PlayerData.citizenid
    local acc = cachedAccounts[accId]

    if not acc or not acc.personal or acc.creator ~= cid then
        return false, "You can't close that account."
    end
    if acc.frozen then
        return false, "This account is frozen and cannot be closed."
    end

    if acc.amount > 0 then
        Player.Functions.AddMoney('bank', acc.amount, "Closed account refund")
    end

    cachedAccounts[accId] = nil
    for i, id in ipairs(cachedPlayers[cid].accounts) do
        if id == accId then table.remove(cachedPlayers[cid].accounts, i) break end
    end
    MySQL.query('DELETE FROM bank_accounts_new WHERE id = ?', {accId})
    return true, "Account closed. Any remaining balance was refunded to your main account."
end

-- NUI (Accounts tab) entry points: return refreshed bank data on success.
QBCore.Functions.CreateCallback("Renewed-Banking:server:openAccount", function(source, cb)
    local ok, msg = doOpenAccount(source)
    TriggerClientEvent('Renewed-Banking:client:sendNotification', source, msg)
    if not ok then cb(false) return end
    cb(getBankData(source))
end)

QBCore.Functions.CreateCallback("Renewed-Banking:server:closeAccount", function(source, cb, data)
    local ok, msg = doCloseAccount(source, data and data.fromAccount or data and data.account)
    TriggerClientEvent('Renewed-Banking:client:sendNotification', source, msg)
    if not ok then cb(false) return end
    cb(getBankData(source))
end)

-- ==========================================================================
-- ATM card access: requires holding a physical card, scopes the whole
-- session to that card's linked account, and gates full access behind its
-- PIN (if one is set).
-- ==========================================================================

QBCore.Functions.CreateCallback("Renewed-Banking:server:openAtmWithCard", function(source, cb, data)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then cb(false) return end

    local cardItem = Player.Functions.GetItemBySlot(tonumber(data and data.slot))
    if not cardItem or cardItem.name ~= config.cardItem or not cardItem.info or not cardItem.info.account then
        TriggerClientEvent('Renewed-Banking:client:sendNotification', source, "Invalid card.")
        cb(false)
        return
    end

    local hasPin = cardItem.info.pin ~= nil and cardItem.info.pin ~= ""
    if hasPin and tostring(data.pin or "") ~= tostring(cardItem.info.pin) then
        TriggerClientEvent('Renewed-Banking:client:sendNotification', source, "Incorrect PIN.")
        cb(false)
        return
    end

    if (cardItem.info.version or 1) ~= getCardVersion(cardItem.info.account) then
        TriggerClientEvent('Renewed-Banking:client:sendNotification', source, "This card has been deactivated by its owner.")
        cb(false)
        return
    end

    atmCardSession[source] = { account = cardItem.info.account, restricted = not hasPin }

    local bankData = getBankData(source)
    if not bankData then
        atmCardSession[source] = nil
        TriggerClientEvent('Renewed-Banking:client:sendNotification', source, "This card's account could not be reached (owner must be online).")
        cb(false)
        return
    end

    cb({ accounts = bankData, restricted = atmCardSession[source].restricted })
end)

RegisterNetEvent('Renewed-Banking:server:clearCardSession', function()
    atmCardSession[source] = nil
end)

AddEventHandler('playerDropped', function()
    atmCardSession[source] = nil
end)

-- ==========================================================================
-- NUI (Cards tab) versions of card management: resolved by ACCOUNT id
-- (the player's own inventory is scanned for that account's card) rather
-- than by inventory slot, since the NUI only knows account ids.
-- ==========================================================================

local function getCardItemForAccount(Player, account)
    for _, item in pairs(Player.PlayerData.items) do
        if item and item.name == config.cardItem and item.info and item.info.account == account then
            return item
        end
    end
    return nil
end

QBCore.Functions.CreateCallback("Renewed-Banking:server:requestCardForAccount", function(source, cb, data)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then cb(false) return end
    local cid = Player.PlayerData.citizenid
    local account = data and data.fromAccount

    if not account or not ownsAccount(cid, account) then
        TriggerClientEvent('Renewed-Banking:client:sendNotification', source, "That's not your account.")
        cb(false)
        return
    end
    if accountHasCard(account) then
        TriggerClientEvent('Renewed-Banking:client:sendNotification', source, "That account already has a card.")
        cb(false)
        return
    end

    local iban = account == cid and cachedPlayers[cid].iban or (cachedAccounts[account] and cachedAccounts[account].iban)
    local name = ("%s %s"):format(Player.PlayerData.charinfo.firstname, Player.PlayerData.charinfo.lastname)
    local ok, msg = issueCard(source, Player, account, iban, name)
    TriggerClientEvent('Renewed-Banking:client:sendNotification', source, msg)
    if not ok then
        cb(false)
        return
    end

    cb(getBankData(source))
end)

QBCore.Functions.CreateCallback("Renewed-Banking:server:setCardPinTab", function(source, cb, data)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then cb(false) return end
    if not ownsAccount(Player.PlayerData.citizenid, data and data.fromAccount) then
        TriggerClientEvent('Renewed-Banking:client:sendNotification', source, "That's not your account.")
        cb(false)
        return
    end

    local pin = tostring(data and data.pin or "")
    if not pin:match("^%d%d%d%d$") then
        TriggerClientEvent('Renewed-Banking:client:sendNotification', source, "PIN must be exactly 4 digits.")
        cb(false)
        return
    end

    local cardItem = getCardItemForAccount(Player, data and data.fromAccount)
    if not cardItem then
        TriggerClientEvent('Renewed-Banking:client:sendNotification', source, "You don't have that card on you.")
        cb(false)
        return
    end

    if not Player.Functions.RemoveMoney('bank', config.cardPinCost, "Set card PIN") then
        TriggerClientEvent('Renewed-Banking:client:sendNotification', source, ("You need $%d in your bank to set a PIN."):format(config.cardPinCost))
        cb(false)
        return
    end

    local newInfo = cardItem.info
    newInfo.pin = pin
    Player.Functions.RemoveItem(config.cardItem, 1, cardItem.slot)
    Player.Functions.AddItem(config.cardItem, 1, cardItem.slot, newInfo)

    TriggerClientEvent('Renewed-Banking:client:sendNotification', source, "PIN set on your card.")
    cb(getBankData(source))
end)

QBCore.Functions.CreateCallback("Renewed-Banking:server:replaceCardTab", function(source, cb, data)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then cb(false) return end
    local cid = Player.PlayerData.citizenid
    local account = data and data.fromAccount

    if not account or not ownsAccount(cid, account) then
        TriggerClientEvent('Renewed-Banking:client:sendNotification', source, "That's not your account.")
        cb(false)
        return
    end
    if not accountHasCard(account) then
        TriggerClientEvent('Renewed-Banking:client:sendNotification', source, "That account doesn't have a card to replace.")
        cb(false)
        return
    end

    if not Player.Functions.RemoveMoney('bank', config.cardReplacementCost, "Card replacement") then
        TriggerClientEvent('Renewed-Banking:client:sendNotification', source, ("You need $%d in your bank to replace your card."):format(config.cardReplacementCost))
        cb(false)
        return
    end

    local newVersion = getCardVersion(account) + 1
    persistCardState(account, false, newVersion)

    local iban = account == cid and cachedPlayers[cid].iban or (cachedAccounts[account] and cachedAccounts[account].iban)
    local name = ("%s %s"):format(Player.PlayerData.charinfo.firstname, Player.PlayerData.charinfo.lastname)
    local ok, msg = issueCard(source, Player, account, iban, name)
    if not ok then
        TriggerClientEvent('Renewed-Banking:client:sendNotification', source, msg)
        cb(false)
        return
    end

    TriggerClientEvent('Renewed-Banking:client:sendNotification', source, "Old card deactivated. " .. msg)
    cb(getBankData(source))
end)

QBCore.Functions.CreateCallback("Renewed-Banking:server:unloadCardTab", function(source, cb, data)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then cb(false) return end
    if not ownsAccount(Player.PlayerData.citizenid, data and data.fromAccount) then
        TriggerClientEvent('Renewed-Banking:client:sendNotification', source, "That's not your account.")
        cb(false)
        return
    end

    local cardItem = getCardItemForAccount(Player, data and data.fromAccount)
    if not cardItem then
        TriggerClientEvent('Renewed-Banking:client:sendNotification', source, "You don't have that card on you.")
        cb(false)
        return
    end

    local balance = cardItem.info.balance or 0
    if balance < 1 then
        TriggerClientEvent('Renewed-Banking:client:sendNotification', source, "This card has no balance to unload.")
        cb(false)
        return
    end

    local account = cardItem.info.account
    if cachedAccounts[account] then
        addAccountMoney(account, balance)
    else
        Player.Functions.AddMoney('bank', balance, "Unloaded card balance")
    end

    setCardBalance(Player, cardItem, 0)
    TriggerClientEvent('Renewed-Banking:client:sendNotification', source, ("Unloaded $%d from the card into the account."):format(balance))
    cb(getBankData(source))
end)
