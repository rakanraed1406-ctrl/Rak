-- =========================================================================
-- parkingrob (server) - settings
-- `local` so it never clashes with your resource's own Config.
-- =========================================================================
local Config = {}

-- Items that can open a meter, tried in this order. `uses` = how many
-- robberies ONE of these items lasts. Every finished robbery takes one use;
-- when the uses run out that one lockpick is removed (the rest of the stack
-- stays and the next one starts with full uses).
Config.Lockpicks = {
    { item = 'lockpick', uses = 5 },
    { item = 'advancedlockpick', uses = 12 },
}

-- % chance the lockpick snaps during a robbery (that one lockpick is lost).
Config.BreakChance = 5

-- How long the robbery takes (ms).
Config.RobTime = { min = 10000, max = 12500 }

-- A robbed meter is empty for this long (seconds) - for everyone.
Config.MeterCooldown = 16 * 60

-- Minimum time (seconds) between two robberies of the same player.
Config.PlayerCooldown = 45

-- Minimum on-duty police needed to rob a meter (0 = no requirement).
Config.MinPolice = 0
Config.PoliceJobs = { police = true, sheriff = true }

-- % chance the police get alerted when a robbery starts.
Config.AlertChance = 25

-- What a meter can contain. One row is picked by weight; `coins` gives a
-- random amount between min and max of each listed coin.
Config.Loot = {
    { weight = 30, coins = {} }, -- empty
    { weight = 45, coins = { silver = { 1, 3 } } },
    { weight = 18, coins = { silver = { 2, 4 }, gold = { 1, 1 } } },
    { weight = 7,  coins = { gold = { 1, 2 } } },
}

-- Each coin has a price range. Every day the buyer picks ONE price per coin
-- inside its range, the same for every player that day.
Config.Coins = {
    { id = 'silver', item = 'silvercoins', label = 'Silver Coin', min = 100, max = 200 },
    { id = 'gold',   item = 'goldcoins',   label = 'Gold Coin',   min = 500, max = 750 },
}

Config.Market = {
    -- 'random' = a fresh random price each day inside the range.
    -- 'trend'  = realistic: the new price moves from yesterday's price by at
    --            most `dailyChange` of the range, always inside the range.
    mode = 'trend',
    dailyChange = 0.35,
    resetHour = 6,      -- hour (server time) when a new market day starts
    saturation = 0,     -- e.g. 0.002 = every coin sold today lowers the price 0.2%
    payment = 'cash',   -- 'cash' or 'bank'
    maxPerSale = 500,
}

-- Coin buyer ped: SET ITS LOCATION HERE (the client gets it from the server).
Config.Buyer = {
    model = 'a_m_m_hasjew_01',
    coords = vector4(195.17, -933.77, 30.69, 144.0),
    scenario = 'WORLD_HUMAN_STAND_IMPATIENT',
    sellDistance = 4.0,
    blip = { enabled = false, sprite = 500, color = 46, scale = 0.7, label = 'Coin Buyer' },
}

local QBCore = exports['qb-core']:GetCoreObject()

local meterCooldowns = {}   -- meterKey -> os.time() when it can be robbed again
local playerCooldowns = {}  -- citizenid -> os.time() of the next allowed robbery
local active = {}           -- [source] = { key, coords, startedAt, duration }
local rateLimits = {}       -- [source] = { start, count }

local coinById = {}
for _, coin in ipairs(Config.Coins) do coinById[coin.id] = coin end

-- =========================================================================
-- Helpers
-- =========================================================================

local function notify(src, msg, kind, time)
    TriggerClientEvent('QBCore:Notify', src, msg, kind or 'primary', time)
end

local function itemBox(src, item, action, amount)
    local data = QBCore.Shared.Items[item]
    if not data then return end
    TriggerClientEvent('inventory:client:ItemBox', src, data, action, amount)
    TriggerClientEvent('qb-inventory:client:ItemBox', src, data, action, amount)
end

local function rateLimited(src)
    local now = GetGameTimer()
    local r = rateLimits[src]
    if not r or now - r.start > 5000 then
        rateLimits[src] = { start = now, count = 1 }
        return false
    end
    r.count = r.count + 1
    return r.count > 10
end

local function meterKey(c)
    return ('%.1f:%.1f:%.1f'):format(c.x, c.y, c.z)
end

local function toVector3(v)
    if type(v) ~= 'vector3' and type(v) ~= 'table' then return nil end
    local x, y, z = tonumber(v.x), tonumber(v.y), tonumber(v.z)
    if not x or not y or not z then return nil end
    return vector3(x, y, z)
end

local function distanceTo(src, coords)
    return #(GetEntityCoords(GetPlayerPed(src)) - coords)
end

-- qb-core moved the item functions into qb-inventory exports in newer versions
local function addItem(Player, item, amount, info)
    if Player.Functions.AddItem then return Player.Functions.AddItem(item, amount, false, info) end
    return exports['qb-inventory']:AddItem(Player.PlayerData.source, item, amount, false, info, 'parkingrob')
end

local function removeItem(Player, item, amount, slot)
    if Player.Functions.RemoveItem then return Player.Functions.RemoveItem(item, amount, slot) end
    return exports['qb-inventory']:RemoveItem(Player.PlayerData.source, item, amount, slot, 'parkingrob')
end

local function countItem(Player, item)
    local total = 0
    for _, it in pairs(Player.PlayerData.items or {}) do
        if it and it.name == item then total = total + (tonumber(it.amount) or 1) end
    end
    return total
end

local function onDutyPolice()
    local count = 0
    for _, src in pairs(QBCore.Functions.GetPlayers()) do
        local P = QBCore.Functions.GetPlayer(src)
        local job = P and P.PlayerData.job
        if job and (Config.PoliceJobs[job.name] or job.type == 'leo') and job.onduty then
            count = count + 1
        end
    end
    return count
end

-- Coin items are registered automatically if qb-core doesn't have them.
for _, coin in ipairs(Config.Coins) do
    if QBCore.Shared.Items and not QBCore.Shared.Items[coin.item] then
        QBCore.Shared.Items[coin.item] = {
            name = coin.item, label = coin.label, weight = 10, type = 'item',
            image = coin.item .. '.png', unique = false, useable = false, shouldClose = false,
            description = 'Can be sold to the coin buyer.'
        }
    end
end

-- =========================================================================
-- Lockpick uses
-- =========================================================================

local function findLockpick(Player)
    for _, lp in ipairs(Config.Lockpicks) do
        for _, item in pairs(Player.PlayerData.items or {}) do
            if item and item.name == lp.item and (tonumber(item.amount) or 1) > 0 then
                return item, lp
            end
        end
    end
    return nil
end

local function setItemInfo(Player, slot, info)
    local items = Player.PlayerData.items
    if not items or not items[slot] then return end
    items[slot].info = info
    Player.Functions.SetPlayerData('items', items)
end

-- Takes one use from the lockpick (or the whole lockpick when it snaps).
-- The uses live on the item slot; when they hit 0 one lockpick of the
-- stack is removed and the next one starts with full uses.
-- Returns usesLeft, removed.
local function useLockpick(Player, item, lp, snapped)
    local info = type(item.info) == 'table' and item.info or {}
    local uses = math.min(tonumber(info.uses) or lp.uses, lp.uses)
    uses = snapped and 0 or uses - 1

    if uses > 0 then
        info.uses = uses
        info.maxUses = lp.uses
        setItemInfo(Player, item.slot, info)
        return uses, false
    end

    local slot = item.slot
    removeItem(Player, item.name, 1, slot)
    itemBox(Player.PlayerData.source, item.name, 'remove', 1)
    local rest = Player.PlayerData.items[slot]
    if rest and rest.name == item.name then
        local restInfo = type(rest.info) == 'table' and rest.info or {}
        restInfo.uses = lp.uses
        restInfo.maxUses = lp.uses
        setItemInfo(Player, slot, restInfo)
    end
    return 0, true
end

-- =========================================================================
-- Robbery (server decides everything: lockpick, cooldowns, time, loot)
-- =========================================================================

local function rollLoot()
    local total = 0
    for _, row in ipairs(Config.Loot) do total = total + row.weight end
    local pick = math.random() * total
    for _, row in ipairs(Config.Loot) do
        pick = pick - row.weight
        if pick <= 0 then return row end
    end
    return Config.Loot[#Config.Loot]
end

QBCore.Functions.CreateCallback('parkingrob:server:start', function(source, cb, rawCoords)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or rateLimited(src) then return cb(false) end
    if active[src] then return cb({ error = 'You are already robbing a meter.' }) end

    local coords = toVector3(rawCoords)
    if not coords or distanceTo(src, coords) > 3.0 then
        return cb({ error = 'You are too far from the meter.' })
    end

    local now = os.time()
    local cid = Player.PlayerData.citizenid
    if playerCooldowns[cid] and now < playerCooldowns[cid] then
        return cb({ error = ('Take it easy - wait %d seconds.'):format(playerCooldowns[cid] - now) })
    end

    local key = meterKey(coords)
    if meterCooldowns[key] and now < meterCooldowns[key] then
        return cb({ error = 'This meter has already been emptied.' })
    end

    if Config.MinPolice > 0 and onDutyPolice() < Config.MinPolice then
        return cb({ error = 'Not enough police in the city.' })
    end

    if not findLockpick(Player) then
        return cb({ error = 'You need a lockpick.' })
    end

    local duration = math.random(Config.RobTime.min, Config.RobTime.max)
    active[src] = { key = key, coords = coords, startedAt = GetGameTimer(), duration = duration }
    cb({ duration = duration, alert = math.random(100) <= Config.AlertChance })
end)

RegisterNetEvent('parkingrob:server:cancel', function()
    active[source] = nil
end)

RegisterNetEvent('parkingrob:server:finish', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local job = active[src]
    active[src] = nil
    if not Player or not job then return end

    -- the progress bar can't be skipped and the player must still be there
    if GetGameTimer() - job.startedAt < job.duration - 1500 then
        print(('^3[parkingrob] %s (%s) finished a robbery too fast^0'):format(GetPlayerName(src), src))
        return
    end
    if distanceTo(src, job.coords) > 4.0 then
        return notify(src, 'You walked away from the meter.', 'error')
    end

    local now = os.time()
    if meterCooldowns[job.key] and now < meterCooldowns[job.key] then
        return notify(src, 'Someone emptied this meter before you.', 'error')
    end

    local lockpick, lp = findLockpick(Player)
    if not lockpick then
        return notify(src, 'You need a lockpick.', 'error')
    end

    meterCooldowns[job.key] = now + Config.MeterCooldown
    playerCooldowns[Player.PlayerData.citizenid] = now + Config.PlayerCooldown
    TriggerClientEvent('parkingrob:client:meterCooldown', -1, job.key, Config.MeterCooldown)

    local snapped = math.random(100) <= Config.BreakChance
    local usesLeft, removed = useLockpick(Player, lockpick, lp, snapped)
    local label = QBCore.Shared.Items[lockpick.name] and QBCore.Shared.Items[lockpick.name].label or lockpick.name
    if snapped then
        notify(src, ('Your %s snapped!'):format(label), 'error')
    elseif removed then
        notify(src, ('Your %s is worn out.'):format(label), 'error')
    else
        notify(src, ('%s: %d/%d uses left'):format(label, usesLeft, lp.uses), 'primary')
    end

    if snapped then return end

    local found = false
    for coinId, range in pairs(rollLoot().coins) do
        local coin = coinById[coinId]
        local amount = coin and math.random(range[1], range[2]) or 0
        if amount > 0 and addItem(Player, coin.item, amount) then
            itemBox(src, coin.item, 'add', amount)
            found = true
        end
    end
    if not found then notify(src, 'The meter was empty.', 'error') end
end)

-- The client gets the buyer ped (location, model) from here, so it is set
-- in one place only.
QBCore.Functions.CreateCallback('parkingrob:server:buyerInfo', function(source, cb)
    cb(Config.Buyer)
end)

-- Clients ask for the current meter cooldowns when they load in.
RegisterNetEvent('parkingrob:server:syncCooldowns', function()
    local src = source
    if rateLimited(src) then return end
    local now, list = os.time(), {}
    for key, untilTime in pairs(meterCooldowns) do
        if untilTime > now then list[key] = untilTime - now else meterCooldowns[key] = nil end
    end
    TriggerClientEvent('parkingrob:client:allCooldowns', src, list)
end)

AddEventHandler('playerDropped', function()
    active[source] = nil
    rateLimits[source] = nil
end)

-- =========================================================================
-- Daily coin market: one price per coin per day, the same for everyone.
-- Saved in KVP so a restart keeps the day's price.
-- =========================================================================

local market = {}
do
    local saved = GetResourceKvpString('parkingrob:market')
    local ok, data = pcall(json.decode, saved or '')
    if ok and type(data) == 'table' then market = data end
end
market.prices = market.prices or {}
market.sold = market.sold or {}
market.history = market.history or {}

local function today()
    return os.date('%Y-%m-%d', os.time() - (Config.Market.resetHour or 0) * 3600)
end

local function newPrice(coin, previous)
    if Config.Market.mode ~= 'trend' or not previous then
        return math.random(coin.min, coin.max)
    end
    local maxStep = math.floor((coin.max - coin.min) * Config.Market.dailyChange)
    local price = previous + math.random(-maxStep, maxStep)
    return math.max(coin.min, math.min(coin.max, price))
end

local function refreshMarket()
    local day = today()
    if market.day == day then return end

    if market.day then
        table.insert(market.history, 1, { day = market.day, prices = market.prices })
        while #market.history > 7 do table.remove(market.history) end
    end

    local prices = {}
    for _, coin in ipairs(Config.Coins) do
        prices[coin.id] = newPrice(coin, market.prices[coin.id])
    end
    market.day = day
    market.prices = prices
    market.sold = {}
    SetResourceKvp('parkingrob:market', json.encode(market))

    local parts = {}
    for _, coin in ipairs(Config.Coins) do parts[#parts+1] = ('%s $%d'):format(coin.label, prices[coin.id]) end
    print(('^2[parkingrob] Coin prices for %s: %s^0'):format(day, table.concat(parts, ', ')))
end

local function currentPrice(coin)
    refreshMarket()
    local base = market.prices[coin.id] or coin.min
    local sold = market.sold[coin.id] or 0
    local price = math.floor(base * (1 - sold * (Config.Market.saturation or 0)))
    return math.max(coin.min, math.min(coin.max, price))
end

local function trendOf(coin)
    local yesterday = market.history[1] and market.history[1].prices[coin.id]
    if not yesterday or yesterday == 0 then return 0 end
    return math.floor((currentPrice(coin) - yesterday) / yesterday * 100 + 0.5)
end

CreateThread(function()
    while true do
        refreshMarket()
        Wait(60 * 1000)
    end
end)

exports('GetCoinPrice', function(coinId)
    local coin = coinById[coinId]
    return coin and currentPrice(coin) or nil
end)

QBCore.Functions.CreateCallback('parkingrob:server:market', function(source, cb)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or rateLimited(src) then return cb(false) end
    local coins = {}
    for _, coin in ipairs(Config.Coins) do
        coins[#coins+1] = {
            id = coin.id,
            label = coin.label,
            price = currentPrice(coin),
            trend = trendOf(coin),
            have = countItem(Player, coin.item)
        }
    end
    cb({ day = market.day, coins = coins })
end)

RegisterNetEvent('parkingrob:server:sell', function(coinId, rawAmount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or rateLimited(src) then return end

    local b = Config.Buyer.coords
    if distanceTo(src, vector3(b.x, b.y, b.z)) > Config.Buyer.sellDistance then
        return notify(src, 'You are too far from the buyer.', 'error')
    end

    local coin = coinById[coinId]
    local amount = math.floor(tonumber(rawAmount) or 0)
    if not coin or amount < 1 or amount > Config.Market.maxPerSale then
        return notify(src, 'Invalid amount.', 'error')
    end
    if countItem(Player, coin.item) < amount then
        return notify(src, ("You don't have %d %s."):format(amount, coin.label), 'error')
    end

    local price = currentPrice(coin)
    if not removeItem(Player, coin.item, amount) then
        return notify(src, 'Something went wrong.', 'error')
    end
    itemBox(src, coin.item, 'remove', amount)

    local total = price * amount
    Player.Functions.AddMoney(Config.Market.payment, total, 'coin-buyer')
    market.sold[coin.id] = (market.sold[coin.id] or 0) + amount
    SetResourceKvp('parkingrob:market', json.encode(market))
    notify(src, ('Sold %d %s for $%d ($%d each).'):format(amount, coin.label, total, price), 'success', 7000)
end)
