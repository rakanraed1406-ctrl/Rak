--[[ server.lua — Jinxed Town Military Logistics

     The server owns everything: budgets, stock, orders, the depot and every
     vehicle that is taken out. The client/NUI only ever sends ids and
     amounts; prices, limits, permissions and distances are checked here.

     Flow: open (permission) → cart → checkout (budget + stock) → order in
     transit (DeliveryMinutes) → depot.
     Vehicles work like a garage: once delivered the display car stays at its
     spot for good; take units out from it (spawned on free pads) and store
     them again by bringing them to the supply officer. Items: the officer. ]]

-- config.lua failed to load (a typo stops the whole file): say so once, clearly, instead of
-- erroring all over the place. Common one: vector4 needs exactly 4 numbers → vector4(x, y, z, heading)
if type(Config) ~= 'table' or type(Config.Shops) ~= 'table' or type(Config.Lang) ~= 'table' then
    print(('^1[%s] config.lua did not load — fix the error printed above it (check the commas in vector3 / vector4) and restart.^0'):format(GetCurrentResourceName()))
    return
end

local QBCore = exports['qb-core']:GetCoreObject()
local L = Config.Lang
local RES = GetCurrentResourceName()
local PERIOD = math.floor((Config.ResetHours or 24) * 3600)

local Shops = {}      -- [id] = { id, cfg, list = {products}, byId = {}, state = {} }
local viewers = {}    -- [shopId] = { [src] = true }  (players with the NUI open)
local spawned = {}    -- [entity] = { shop, pid, plate, wrecked }  (fleet vehicles that are out)
local creating = {}   -- [entity] = true while the server is creating it (anti-cheat exceptions)
local pendingModels = {} -- [model hash] = n, only during the CreateVehicleServerSetter call
local cooldowns = {}

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
local function notify(src, msg, kind, ms)
    if src and src > 0 then TriggerClientEvent('QBCore:Notify', src, msg, kind or 'primary', ms or 5000) end
end

local function log(title, color, msg)
    TriggerEvent('qb-log:server:CreateLog', 'logistics', title, color, msg)
end

local function comma(n)
    local s = tostring(math.floor(tonumber(n) or 0))
    return (s:reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', ''))
end

local function cooldown(src, key, ms)
    local now = GetGameTimer()
    local list = cooldowns[src]
    if not list then list = {}; cooldowns[src] = list end
    if list[key] and now - list[key] < ms then return false end
    list[key] = now
    return true
end

--- whole number in [lo, hi] or nil (rejects nan, inf, decimals, strings)
local function int(v, lo, hi)
    local n = tonumber(v)
    if not n or n ~= n or n == math.huge or n == -math.huge or n % 1 ~= 0 then return nil end
    n = math.tointeger(n)
    if not n or (lo and n < lo) or (hi and n > hi) then return nil end
    return n
end

local busy = false
--- one state change at a time (orders, deposits, pickups and the timer all
--- touch the same budgets / depot; the DB writes are awaited inside)
local function withLock(fn, ...)
    while busy do Wait(5) end
    busy = true
    local ok, a, b = pcall(fn, ...)
    busy = false
    if not ok then print(('^1[logistics] %s^0'):format(a)) return nil end
    return a, b
end

local function distanceTo(src, c)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return math.huge end
    return #(GetEntityCoords(ped) - vector3(c.x, c.y, c.z))
end

local function trim(s) return (tostring(s or ''):gsub('^%s*(.-)%s*$', '%1')) end

-- ---------------------------------------------------------------------------
-- Permissions
-- ---------------------------------------------------------------------------
local function matches(Player, rule)
    if type(rule) ~= 'table' then return false end
    local pd = Player.PlayerData
    if rule.citizenids and rule.citizenids[pd.citizenid] then return true end
    if rule.jobs and pd.job then
        local min = rule.jobs[pd.job.name]
        local grade = pd.job.grade and (pd.job.grade.level or pd.job.grade) or 0
        if min and (tonumber(grade) or 0) >= min and (not rule.onDuty or pd.job.onduty) then return true end
    end
    if rule.gangs and pd.gang then
        local min = rule.gangs[pd.gang.name]
        local grade = pd.gang.grade and (pd.gang.grade.level or pd.gang.grade) or 0
        if min and (tonumber(grade) or 0) >= min then return true end
    end
    return false
end

--- action = 'open' | 'order' | 'deposit' | 'pickup'
local function can(Player, shop, action)
    if not Player or not shop or not matches(Player, shop.cfg.access) then return false end
    if action == 'open' then return true end
    local rule = shop.cfg.permissions and shop.cfg.permissions[action]
    return rule == nil or matches(Player, rule)
end

local function atTerminal(src, shop)
    local t = shop.cfg.terminal
    return not t or distanceTo(src, t.coords) <= (t.distance or 15.0)
end

local function isAdmin(src)
    if src == 0 then return true end
    for _, g in ipairs(Config.AdminGroups or {}) do
        if QBCore.Functions.HasPermission(src, g) then return true end
    end
    return IsPlayerAceAllowed(src, 'command')
end

-- ---------------------------------------------------------------------------
-- Money / inventory
-- ---------------------------------------------------------------------------
local function takeMoney(Player, mt, amount, reason)
    if (Player.PlayerData.money[mt] or 0) < amount then return false end -- (qb-core lets bank go negative)
    return Player.Functions.RemoveMoney(mt, amount, reason) and true or false
end

local function invStarted() return GetResourceState('qb-inventory') == 'started' end

local function canAdd(src, Player, item, amount)
    if invStarted() then
        local ok, res = pcall(function() return exports['qb-inventory']:CanAddItem(src, item, amount) end)
        if ok and res ~= nil then return res and true or false end
    end
    return true -- older inventories: AddItem itself refuses when full
end

local function addItem(src, Player, item, amount)
    if invStarted() then
        local ok, res = pcall(function() return exports['qb-inventory']:AddItem(src, item, amount, false, false, 'jt-logistics') end)
        if ok then return res and true or false end
    end
    return (Player.Functions.AddItem and Player.Functions.AddItem(item, amount)) and true or false
end

local function itemBox(src, item, amount)
    local data = QBCore.Shared.Items[item]
    if not data then return end
    TriggerClientEvent('qb-inventory:client:ItemBox', src, data, 'add', amount)
    TriggerClientEvent('inventory:client:ItemBox', src, data, 'add', amount)
end

-- ---------------------------------------------------------------------------
-- Shops (config → runtime)
-- ---------------------------------------------------------------------------
local function vehicleImage(model)
    if LoadResourceFile(RES, 'html/img/vehicles/' .. model .. '.webp') then return 'img/vehicles/' .. model .. '.webp' end
    if Config.VehicleImageFallback then return Config.VehicleImageFallback:format(model) end
    return nil
end

-- model hashes can come back signed or unsigned: compare / key them as uint32
local function u32(h) h = math.tointeger(h) return h and (h & 0xFFFFFFFF) end

-- vehicle type for CreateVehicleServerSetter (vehicles.meta type)
local VTYPES = { automobile = true, bike = true, boat = true, heli = true, plane = true, submarine = true, trailer = true, train = true }
local VTYPE_BY_CATEGORY = { helicopters = 'heli', jets = 'plane', boats = 'boat' }

local function buildShops()
    for id, cfg in pairs(Config.Shops) do
        if cfg.enabled ~= false then
            local shop = { id = id, cfg = cfg, list = {}, byId = {} }
            for _, p in ipairs(cfg.products or {}) do
                local ok, why = true, nil
                if type(p.id) ~= 'string' or shop.byId[p.id] then ok, why = false, 'missing / duplicate id' end
                if ok and (int(p.price, 1) == nil or int(p.stock, 0) == nil) then ok, why = false, 'price / stock' end
                local image
                if ok and p.type == 'item' then
                    local data = QBCore.Shared.Items[p.item]
                    if not data then ok, why = false, ('item "%s" not in shared/items.lua'):format(tostring(p.item))
                    else image = data.image and (Config.ItemImages .. data.image) or nil end
                elseif ok and p.type == 'vehicle' then
                    if type(p.model) ~= 'string' or not p.display then ok, why = false, 'model / display missing'
                    elseif not (cfg.spawnPoints and cfg.spawnPoints[p.spawn or 'ground']) then ok, why = false, ('spawn group "%s" missing'):format(tostring(p.spawn))
                    elseif p.vtype ~= nil and not VTYPES[p.vtype] then ok, why = false, ('vtype "%s" (automobile / heli / plane / boat / bike …)'):format(tostring(p.vtype))
                    else image = vehicleImage(p.model) end
                elseif ok then
                    ok, why = false, 'type must be vehicle or item'
                end
                if ok then
                    local category = p.category or (p.type == 'vehicle' and 'armored' or 'items')
                    local vtype = p.vtype
                    if p.type == 'vehicle' and not vtype then
                        vtype = VTYPE_BY_CATEGORY[category] or 'automobile'
                        print(('^3[logistics] %s/%s: no vtype, using "%s" — set it in config.lua^0'):format(id, p.id, vtype))
                    end
                    local prod = {
                        id = p.id, type = p.type, label = p.label or p.model or p.item, desc = p.desc or '',
                        category = category,
                        price = math.tointeger(p.price), stock = math.tointeger(p.stock), image = image,
                        model = p.model, hash = p.model and u32(joaat(p.model)), vtype = vtype, item = p.item, display = p.display, spawn = p.spawn or 'ground',
                        unique = p.type == 'item' and QBCore.Shared.Items[p.item].unique or false,
                    }
                    shop.list[#shop.list + 1] = prod
                    shop.byId[prod.id] = prod
                else
                    print(('^3[logistics] %s/%s skipped: %s^0'):format(id, tostring(p.id), why))
                end
            end
            Shops[id] = shop
            viewers[id] = {}
        end
    end
end

-- ---------------------------------------------------------------------------
-- Database
-- ---------------------------------------------------------------------------
local function createTables()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `jt_logistics_shops` (
        `shop` VARCHAR(50) NOT NULL,
        `balance` BIGINT NOT NULL DEFAULT 0,
        `last_income` INT NOT NULL DEFAULT 0,
        `stock_reset` INT NOT NULL DEFAULT 0,
        `sold` LONGTEXT NULL,
        PRIMARY KEY (`shop`)
    )]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `jt_logistics_orders` (
        `id` INT NOT NULL AUTO_INCREMENT,
        `shop` VARCHAR(50) NOT NULL,
        `citizenid` VARCHAR(50) NULL,
        `name` VARCHAR(100) NULL,
        `items` LONGTEXT NOT NULL,
        `total` BIGINT NOT NULL,
        `created` INT NOT NULL,
        `arrive` INT NOT NULL,
        `delivered` TINYINT(1) NOT NULL DEFAULT 0,
        PRIMARY KEY (`id`),
        KEY `shop_delivered` (`shop`, `delivered`)
    )]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `jt_logistics_depot` (
        `shop` VARCHAR(50) NOT NULL,
        `product` VARCHAR(60) NOT NULL,
        `amount` INT NOT NULL DEFAULT 0,
        `out_count` INT NOT NULL DEFAULT 0,
        PRIMARY KEY (`shop`, `product`)
    )]])
    -- tables made by 3.0 don't have out_count yet
    local has = MySQL.scalar.await([[SELECT COUNT(*) FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'jt_logistics_depot' AND COLUMN_NAME = 'out_count']])
    if tonumber(has) == 0 then
        MySQL.query.await('ALTER TABLE `jt_logistics_depot` ADD COLUMN `out_count` INT NOT NULL DEFAULT 0')
    end
end

local function saveShop(shop)
    local st = shop.state
    MySQL.update.await('UPDATE jt_logistics_shops SET balance = ?, last_income = ?, stock_reset = ?, sold = ? WHERE shop = ?',
        { st.balance, st.lastIncome, st.stockReset, json.encode(st.sold), shop.id })
end

local function saveDepot(shop, pid)
    MySQL.update.await('INSERT INTO jt_logistics_depot (shop, product, amount, out_count) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE amount = VALUES(amount), out_count = VALUES(out_count)',
        { shop.id, pid, shop.state.depot[pid] or 0, shop.state.out[pid] or 0 })
end

local function loadState()
    local now = os.time()
    for id, shop in pairs(Shops) do
        local row = MySQL.single.await('SELECT balance, last_income, stock_reset, sold FROM jt_logistics_shops WHERE shop = ?', { id })
        local budget = shop.cfg.budget or {}
        if not row then
            row = { balance = int(budget.start, 0) or 0, last_income = now, stock_reset = now, sold = '{}' }
            MySQL.insert.await('INSERT INTO jt_logistics_shops (shop, balance, last_income, stock_reset, sold) VALUES (?, ?, ?, ?, ?)',
                { id, row.balance, now, now, '{}' })
        end
        local sold = row.sold and json.decode(row.sold) or {}
        shop.state = {
            balance = math.tointeger(tonumber(row.balance)) or 0,
            lastIncome = tonumber(row.last_income) or now,
            stockReset = tonumber(row.stock_reset) or now,
            sold = type(sold) == 'table' and sold or {},
            depot = {},   -- [pid] = in the garage / ready at the officer
            out = {},     -- [pid] = fleet vehicles currently out
            orders = {},
        }
        for _, d in ipairs(MySQL.query.await('SELECT product, amount, out_count FROM jt_logistics_depot WHERE shop = ?', { id }) or {}) do
            if shop.byId[d.product] then
                local n, o = math.tointeger(tonumber(d.amount)) or 0, math.tointeger(tonumber(d.out_count)) or 0
                if n > 0 then shop.state.depot[d.product] = n end
                if o > 0 then shop.state.out[d.product] = o end
            end
        end
        for _, o in ipairs(MySQL.query.await('SELECT id, citizenid, name, items, total, created, arrive FROM jt_logistics_orders WHERE shop = ? AND delivered = 0', { id }) or {}) do
            local lines = json.decode(o.items) or {}
            shop.state.orders[o.id] = { id = o.id, cid = o.citizenid, by = o.name, lines = lines, total = tonumber(o.total), created = tonumber(o.created), arrive = tonumber(o.arrive) }
        end
    end
end

-- ---------------------------------------------------------------------------
-- What the NUI gets
-- ---------------------------------------------------------------------------
--- [pid] = { g = in the garage, o = out } for every vehicle product
local function fleetOf(shop)
    local out = {}
    for _, p in ipairs(shop.list) do
        if p.type == 'vehicle' then out[p.id] = { g = shop.state.depot[p.id] or 0, o = shop.state.out[p.id] or 0 } end
    end
    return out
end

local function payload(shop, Player)
    local st, cfg = shop.state, shop.cfg
    local now = os.time()
    local products, cats = {}, {}
    for _, p in ipairs(shop.list) do
        cats[p.category] = true
        products[#products + 1] = {
            id = p.id, type = p.type, label = p.label, desc = p.desc, category = p.category, price = p.price,
            limit = p.stock, remaining = math.max(0, p.stock - (st.sold[p.id] or 0)), image = p.image,
            fallback = p.type == 'vehicle' and Config.VehicleImageFallback and Config.VehicleImageFallback:format(p.model) or nil,
            model = p.model, garage = st.depot[p.id] or 0, out = st.out[p.id] or 0,
        }
    end
    local categories = {}
    for _, c in ipairs(Config.Categories) do
        if cats[c.id] then categories[#categories + 1] = { id = c.id, label = c.label } end
    end
    local orders = {}
    for _, o in pairs(st.orders) do
        local lines = {}
        for _, l in ipairs(o.lines) do
            local p = shop.byId[l.id]
            lines[#lines + 1] = { label = p and p.label or l.id, amount = l.amount }
        end
        orders[#orders + 1] = { id = o.id, by = o.by, total = o.total, lines = lines,
            arriveIn = math.max(0, o.arrive - now), duration = math.max(1, o.arrive - o.created) }
    end
    table.sort(orders, function(a, b) return a.arriveIn < b.arriveIn end)
    local depot = {}
    for _, p in ipairs(shop.list) do
        local n, o = st.depot[p.id] or 0, st.out[p.id] or 0
        if n > 0 or o > 0 then
            depot[#depot + 1] = { id = p.id, label = p.label, type = p.type, amount = n, out = o, image = p.image,
                fallback = p.type == 'vehicle' and Config.VehicleImageFallback and Config.VehicleImageFallback:format(p.model) or nil }
        end
    end
    local dep = cfg.deposit or {}
    return {
        shop = { id = shop.id, label = cfg.label, badge = cfg.badge, authority = cfg.authority, title = cfg.title },
        categories = categories,
        balance = st.balance,
        income = { daily = (cfg.budget and cfg.budget.daily) or 0, nextIn = math.max(0, PERIOD - (now - st.lastIncome)) },
        restockIn = math.max(0, PERIOD - (now - st.stockReset)),
        products = products,
        orders = orders,
        depot = depot,
        perms = { order = can(Player, shop, 'order'), deposit = can(Player, shop, 'deposit'), pickup = can(Player, shop, 'pickup') },
        wallet = { cash = Player.PlayerData.money.cash or 0, bank = Player.PlayerData.money.bank or 0 },
        deposit = { min = dep.min or 1, max = dep.max or 10000000, from = dep.from or { 'bank' } },
        delivery = cfg.deliveryMinutes or Config.DeliveryMinutes,
        maxLines = Config.MaxLinesPerOrder,
    }
end

local function pushViewers(shop)
    for src in pairs(viewers[shop.id]) do
        local Player = QBCore.Functions.GetPlayer(src)
        if Player and can(Player, shop, 'open') then
            TriggerClientEvent('jt-logistics:client:update', src, shop.id, payload(shop, Player))
        else
            viewers[shop.id][src] = nil
        end
    end
end

local function broadcastDisplays(shop)
    TriggerClientEvent('jt-logistics:client:displays', -1, shop.id, fleetOf(shop))
end

local function notifyMembers(shop, msg)
    for _, Player in pairs(QBCore.Functions.GetQBPlayers()) do
        if can(Player, shop, 'pickup') then notify(Player.PlayerData.source, msg, 'success', 9000) end
    end
end

-- ---------------------------------------------------------------------------
-- Time: daily budget, stock reset, deliveries
-- ---------------------------------------------------------------------------
local function tickShop(shop, now)
    local st, changed = shop.state, false
    local passed = now - st.lastIncome
    if passed >= PERIOD then
        local n = math.floor(passed / PERIOD)
        local daily = (shop.cfg.budget and int(shop.cfg.budget.daily, 0)) or 0
        local max = shop.cfg.budget and int(shop.cfg.budget.max, 0)
        if daily > 0 then
            st.balance = st.balance + daily * n
            if max and st.balance > max then st.balance = math.max(max, st.balance - daily * n) end
        end
        st.lastIncome = st.lastIncome + n * PERIOD
        changed = true
    end
    passed = now - st.stockReset
    if passed >= PERIOD then
        st.sold = {}
        st.stockReset = st.stockReset + math.floor(passed / PERIOD) * PERIOD
        changed = true
    end
    if changed then saveShop(shop) end

    local delivered = false
    for oid, o in pairs(st.orders) do
        if o.arrive <= now then
            st.orders[oid] = nil
            MySQL.update.await('UPDATE jt_logistics_orders SET delivered = 1 WHERE id = ?', { oid })
            local parts = {}
            for _, l in ipairs(o.lines) do
                if shop.byId[l.id] then
                    st.depot[l.id] = (st.depot[l.id] or 0) + l.amount
                    saveDepot(shop, l.id)
                    parts[#parts + 1] = ('%s× %s'):format(l.amount, shop.byId[l.id].label)
                end
            end
            notifyMembers(shop, L.order_arrived:format(oid, table.concat(parts, ', ')))
            log('Order delivered', 'blue', ('[%s] #%s %s'):format(shop.id, oid, table.concat(parts, ', ')))
            delivered = true
        end
    end
    if delivered then broadcastDisplays(shop) end
    if changed or delivered then pushViewers(shop) end
end

local function sameHash(a, b)
    a, b = u32(a), u32(b)
    return a ~= nil and a == b
end

--- Which entities are fleet vehicles, kept in GlobalState: only the server can
--- write it (an entity state bag can be set by the client that owns the entity)
--- and it outlives a restart of this resource.
local function saveFleet()
    local t = {}
    for veh, info in pairs(spawned) do
        if DoesEntityExist(veh) then
            local shop = Shops[info.shop]
            local p = shop and shop.byId[info.pid]
            if p then t[tostring(NetworkGetNetworkIdFromEntity(veh))] = { s = info.shop, p = info.pid, m = p.hash, l = info.plate, c = info.cid } end
        end
    end
    GlobalState.jtLogisticsFleet = t
end

-- keys through the key script's server side, so it knows they are legit
local function keys(action, src, plate)
    local fn = Config.Keys and Config.Keys[action]
    if not fn or not src or not plate then return end
    local ok, err = pcall(fn, src, plate)
    if not ok then print(('^3[logistics] Config.Keys.%s failed: %s^0'):format(action, tostring(err))) end
end

-- the player who took it out loses the key once it is back in the garage / gone
local function dropKeys(info)
    local Player = info.cid and QBCore.Functions.GetPlayerByCitizenId(info.cid)
    if Player then keys('remove', Player.PlayerData.source, info.plate) end
end

local function isWrecked(veh)
    return GetEntityHealth(veh) <= 0 or GetVehicleEngineHealth(veh) <= -3000.0
end

--- Fleet vehicles that left the world: back to the garage, or lost if they
--- were blown up (Config.Fleet.DestroyedAreLost).
local function checkFleet()
    local touched = {}
    local lose = not Config.Fleet or Config.Fleet.DestroyedAreLost ~= false
    for veh, info in pairs(spawned) do
        local shop = Shops[info.shop]
        if not DoesEntityExist(veh) then
            spawned[veh] = nil
            dropKeys(info)
            if shop then
                local st = shop.state
                st.out[info.pid] = math.max(0, (st.out[info.pid] or 0) - 1)
                if info.wrecked and lose then
                    log('Fleet vehicle lost', 'red', ('[%s] %s [%s] was destroyed'):format(shop.id, info.pid, info.plate or '?'))
                else
                    st.depot[info.pid] = (st.depot[info.pid] or 0) + 1
                end
                touched[shop] = touched[shop] or {}
                touched[shop][info.pid] = true
            end
        else
            info.wrecked = isWrecked(veh)
        end
    end
    for shop, pids in pairs(touched) do
        for pid in pairs(pids) do saveDepot(shop, pid) end
        broadcastDisplays(shop)
        pushViewers(shop)
    end
    if next(touched) then saveFleet() end
end

--- After a resource restart the fleet vehicles are still in the world: pick
--- them up again from GlobalState (network id + model must still match).
--- Anything "out" that isn't there any more (server restart, cleanup) goes
--- back to the garage.
local function retrackFleet()
    local found = {}
    local saved = GlobalState.jtLogisticsFleet
    for net, e in pairs(type(saved) == 'table' and saved or {}) do
        local netId = int(net, 1)
        local veh = netId and NetworkGetEntityFromNetworkId(netId)
        local shop = type(e) == 'table' and Shops[e.s]
        local p = shop and shop.byId[e.p]
        if veh and veh ~= 0 and p and p.type == 'vehicle' and not spawned[veh] and DoesEntityExist(veh) and sameHash(GetEntityModel(veh), p.hash) then
            spawned[veh] = { shop = shop.id, pid = p.id, plate = type(e.l) == 'string' and e.l or trim(GetVehicleNumberPlateText(veh)),
                cid = type(e.c) == 'string' and e.c or nil, wrecked = isWrecked(veh) }
            found[shop] = found[shop] or {}
            found[shop][p.id] = (found[shop][p.id] or 0) + 1
        end
    end
    for _, shop in pairs(Shops) do
        local seen = found[shop] or {}
        local pids = {}
        for pid in pairs(shop.state.out) do pids[pid] = true end
        for pid in pairs(seen) do pids[pid] = true end
        for pid in pairs(pids) do
            local was, still = shop.state.out[pid] or 0, seen[pid] or 0
            if was ~= still then
                if still < was then shop.state.depot[pid] = (shop.state.depot[pid] or 0) + (was - still) end
                shop.state.out[pid] = still > 0 and still or nil
                saveDepot(shop, pid)
            end
        end
    end
    saveFleet()
end

local function tickAll()
    withLock(function()
        local now = os.time()
        for _, shop in pairs(Shops) do tickShop(shop, now) end
        checkFleet()
    end)
end

-- ---------------------------------------------------------------------------
-- Start
-- ---------------------------------------------------------------------------
local ready = false
CreateThread(function()
    Wait(500) -- shared items / vehicles
    buildShops()
    createTables()
    loadState()
    withLock(retrackFleet)
    ready = true
    print(('[logistics] %d shop(s) ready'):format((function() local n = 0 for _ in pairs(Shops) do n = n + 1 end return n end)()))
    for _, shop in pairs(Shops) do broadcastDisplays(shop) end
    while true do
        tickAll()
        Wait(30000)
    end
end)

-- ---------------------------------------------------------------------------
-- Open / close
-- ---------------------------------------------------------------------------
QBCore.Functions.CreateCallback('jt-logistics:server:open', function(source, cb, shopId)
    local shop = ready and type(shopId) == 'string' and Shops[shopId]
    local Player = QBCore.Functions.GetPlayer(source)
    if not shop or not Player or not cooldown(source, 'open', 800) then return cb(false) end
    if not can(Player, shop, 'open') then
        notify(source, L.no_access, 'error')
        return cb(false)
    end
    for _, v in pairs(viewers) do v[source] = nil end
    viewers[shopId][source] = true
    cb(payload(shop, Player))
end)

RegisterNetEvent('jt-logistics:server:close', function()
    local src = source
    for _, v in pairs(viewers) do v[src] = nil end
end)

QBCore.Functions.CreateCallback('jt-logistics:server:displays', function(_, cb)
    local out = {}
    for id, shop in pairs(Shops) do if shop.state then out[id] = fleetOf(shop) end end
    cb(out)
end)

-- ---------------------------------------------------------------------------
-- Checkout
-- ---------------------------------------------------------------------------
QBCore.Functions.CreateCallback('jt-logistics:server:checkout', function(source, cb, shopId, cart)
    local src = source
    if not ready or not cooldown(src, 'checkout', 2000) then return cb({ ok = false }) end
    local res = withLock(function()
        local shop = type(shopId) == 'string' and Shops[shopId]
        local Player = QBCore.Functions.GetPlayer(src)
        if not shop or not can(Player, shop, 'order') then return { ok = false, msg = L.no_permission } end
        if not atTerminal(src, shop) then return { ok = false, msg = L.too_far } end
        if type(cart) ~= 'table' or #cart == 0 then return { ok = false, msg = L.cart_empty } end
        if #cart > (Config.MaxLinesPerOrder or 25) then return { ok = false } end

        local st = shop.state
        local merged, order = {}, {}
        for _, line in ipairs(cart) do
            local p = type(line) == 'table' and type(line.id) == 'string' and shop.byId[line.id]
            local amount = p and int(line.amount, 1, 100000)
            if not p or not amount then return { ok = false } end
            if not merged[p.id] then merged[p.id] = 0; order[#order + 1] = p.id end
            merged[p.id] = merged[p.id] + amount
        end
        local total, lines = 0, {}
        for _, pid in ipairs(order) do
            local p, amount = shop.byId[pid], merged[pid]
            local remaining = p.stock - (st.sold[pid] or 0)
            if amount > remaining then return { ok = false, msg = L.out_of_stock:format(p.label, math.max(0, remaining)) } end
            total = total + p.price * amount
            lines[#lines + 1] = { id = pid, amount = amount }
        end
        if total <= 0 then return { ok = false } end
        if total > st.balance then return { ok = false, msg = L.not_enough_budget } end

        local now = os.time()
        local minutes = shop.cfg.deliveryMinutes or Config.DeliveryMinutes
        local arrive = now + math.floor(minutes * 60)
        local name = ((Player.PlayerData.charinfo.firstname or '') .. ' ' .. (Player.PlayerData.charinfo.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')

        -- apply in memory first (nothing can interleave: we hold the lock), then persist
        st.balance = st.balance - total
        for _, l in ipairs(lines) do st.sold[l.id] = (st.sold[l.id] or 0) + l.amount end
        local id = MySQL.insert.await('INSERT INTO jt_logistics_orders (shop, citizenid, name, items, total, created, arrive) VALUES (?, ?, ?, ?, ?, ?, ?)',
            { shop.id, Player.PlayerData.citizenid, name, json.encode(lines), total, now, arrive })
        if not id then -- roll back
            st.balance = st.balance + total
            for _, l in ipairs(lines) do st.sold[l.id] = st.sold[l.id] - l.amount end
            return { ok = false }
        end
        saveShop(shop)
        st.orders[id] = { id = id, cid = Player.PlayerData.citizenid, by = name, lines = lines, total = total, created = now, arrive = arrive }

        SetTimeout((arrive - now) * 1000 + 1000, tickAll)
        log('Order placed', 'green', ('[%s] #%s by %s (%s) $%s: %s'):format(shop.id, id, name, Player.PlayerData.citizenid, total, json.encode(lines)))
        notify(src, L.order_placed:format(id, minutes), 'success', 8000)
        pushViewers(shop)
        return { ok = true, id = id }
    end)
    cb(res or { ok = false })
end)

-- ---------------------------------------------------------------------------
-- Deposit
-- ---------------------------------------------------------------------------
QBCore.Functions.CreateCallback('jt-logistics:server:deposit', function(source, cb, shopId, amount, from)
    local src = source
    if not ready or not cooldown(src, 'deposit', 1500) then return cb({ ok = false }) end
    local res = withLock(function()
        local shop = type(shopId) == 'string' and Shops[shopId]
        local Player = QBCore.Functions.GetPlayer(src)
        if not shop or not can(Player, shop, 'deposit') then return { ok = false, msg = L.no_permission } end
        if not atTerminal(src, shop) then return { ok = false, msg = L.too_far } end
        local dep = shop.cfg.deposit or {}
        local min, max = dep.min or 1, dep.max or 10000000
        amount = int(amount, min, max)
        if not amount then return { ok = false, msg = L.bad_amount:format(comma(min), comma(max)) } end
        local allowed = false
        for _, mt in ipairs(dep.from or { 'bank' }) do if mt == from then allowed = true end end
        if not allowed or (from ~= 'cash' and from ~= 'bank') then return { ok = false } end
        local cap = shop.cfg.budget and int(shop.cfg.budget.max, 0)
        if cap and shop.state.balance + amount > cap then return { ok = false, msg = L.budget_full } end
        if not takeMoney(Player, from, amount, 'logistics-deposit') then return { ok = false, msg = L.not_enough_money } end

        shop.state.balance = shop.state.balance + amount
        saveShop(shop)
        log('Deposit', 'green', ('[%s] %s (%s) deposited $%s from %s'):format(shop.id, GetPlayerName(src) or '?', Player.PlayerData.citizenid, amount, from))
        notify(src, L.deposit_done:format(comma(amount), shop.cfg.badge or shop.id), 'success')
        pushViewers(shop)
        return { ok = true }
    end)
    cb(res or { ok = false })
end)

-- ---------------------------------------------------------------------------
-- Depot: vehicles
-- ---------------------------------------------------------------------------
local function freePoints(shop, group)
    local points = (shop.cfg.spawnPoints or {})[group] or {}
    local vehicles = GetAllVehicles()
    local free = {}
    for _, p in ipairs(points) do
        local pos, ok = vector3(p.x, p.y, p.z), true
        for _, veh in ipairs(vehicles) do
            if #(GetEntityCoords(veh) - pos) < 6.0 then ok = false break end
        end
        if ok then free[#free + 1] = p end
    end
    return free
end

local function randomPlate(prefix)
    prefix = tostring(prefix or 'MIL'):upper():gsub('[^%w]', ''):sub(1, 4)
    local digits = 8 - #prefix
    return prefix .. tostring(math.random(10 ^ (digits - 1), 10 ^ digits - 1))
end

--- Always created by the server itself (CreateVehicleServerSetter): no client
--- creates it, so blacklists that work on client spawns (entityCreating, e.g.
--- qb-smallresources BlacklistedVehs) don't remove it, and players still can't
--- spawn those models themselves. Other anti-cheats: IsFleetVehicle export.
local function spawnVehicle(p, point, plate)
    local hash = p.hash
    pendingModels[hash] = (pendingModels[hash] or 0) + 1
    local ok, veh = pcall(CreateVehicleServerSetter, hash, p.vtype, point.x, point.y, point.z, point.w)
    pendingModels[hash] = pendingModels[hash] > 1 and pendingModels[hash] - 1 or nil
    if not ok or not veh or veh == 0 then return nil end
    creating[veh] = true
    local timeout = GetGameTimer() + 5000
    while not DoesEntityExist(veh) do
        if GetGameTimer() > timeout then
            creating[veh] = nil
            return nil
        end
        Wait(50)
    end
    SetVehicleNumberPlateText(veh, plate)
    if Config.Fleet and Config.Fleet.KeepInWorld then SetEntityOrphanMode(veh, 2) end -- stays parked even with nobody around
    return veh
end

QBCore.Functions.CreateCallback('jt-logistics:server:pickupInfo', function(source, cb, shopId, kind, pid)
    local src = source
    local shop = ready and type(shopId) == 'string' and Shops[shopId]
    local Player = QBCore.Functions.GetPlayer(src)
    if not shop or not can(Player, shop, 'pickup') then notify(src, L.no_permission, 'error') return cb(false) end
    if kind == 'vehicle' then
        local p = type(pid) == 'string' and shop.byId[pid]
        if not p or p.type ~= 'vehicle' then return cb(false) end
        if distanceTo(src, p.display) > 10.0 then notify(src, L.too_far, 'error') return cb(false) end
        local n, o = shop.state.depot[p.id] or 0, shop.state.out[p.id] or 0
        if n + o < 1 then notify(src, L.nothing_here, 'error') return cb(false) end
        return cb({ kind = 'vehicle', shop = shop.cfg.badge or shop.id, list = { { id = p.id, label = p.label, desc = p.desc, image = p.image,
            fallback = Config.VehicleImageFallback and Config.VehicleImageFallback:format(p.model) or nil, category = p.category,
            amount = n, out = o, max = math.min(n, #freePoints(shop, p.spawn)) } } })
    elseif kind == 'items' then
        local ped = shop.cfg.itemPed
        if not ped or distanceTo(src, ped.coords) > 6.0 then notify(src, L.too_far, 'error') return cb(false) end
        local list = {}
        for _, p in ipairs(shop.list) do
            local n = shop.state.depot[p.id] or 0
            if p.type == 'item' and n > 0 then list[#list + 1] = { id = p.id, label = p.label, desc = p.desc, image = p.image, category = p.category, amount = n, max = n } end
        end
        if #list == 0 then notify(src, L.nothing_here, 'error') return cb(false) end
        return cb({ kind = 'items', shop = shop.cfg.badge or shop.id, list = list })
    end
    cb(false)
end)

QBCore.Functions.CreateCallback('jt-logistics:server:takeVehicles', function(source, cb, shopId, pid, amount)
    local src = source
    if not ready or not cooldown(src, 'take', 2000) then return cb({ ok = false }) end
    local res = withLock(function()
        local shop = type(shopId) == 'string' and Shops[shopId]
        local Player = QBCore.Functions.GetPlayer(src)
        if not shop or not can(Player, shop, 'pickup') then return { ok = false, msg = L.no_permission } end
        local p = type(pid) == 'string' and shop.byId[pid]
        if not p or p.type ~= 'vehicle' then return { ok = false } end
        if distanceTo(src, p.display) > 10.0 then return { ok = false, msg = L.too_far } end
        local have = shop.state.depot[p.id] or 0
        amount = int(amount, 1, have)
        if not amount then return { ok = false, msg = L.nothing_here } end
        local points = freePoints(shop, p.spawn)
        if #points == 0 then return { ok = false, msg = L.pads_busy } end

        local out = {}
        for i = 1, math.min(amount, #points) do
            local plate = randomPlate(shop.cfg.platePrefix)
            local veh = spawnVehicle(p, points[i], plate)
            if veh then
                shop.state.depot[p.id] = shop.state.depot[p.id] - 1
                shop.state.out[p.id] = (shop.state.out[p.id] or 0) + 1
                spawned[veh] = { shop = shop.id, pid = p.id, plate = plate, cid = Player.PlayerData.citizenid }
                creating[veh] = nil
                keys('give', src, plate)
                out[#out + 1] = { netId = NetworkGetNetworkIdFromEntity(veh), plate = plate }
            end
        end
        if #out == 0 then return { ok = false, msg = L.pads_busy } end
        saveDepot(shop, p.id) -- garage -n, out +n
        saveFleet()
        TriggerClientEvent('jt-logistics:client:tookVehicles', src, out)
        log('Vehicles taken out', 'orange', ('[%s] %s (%s) took %s× %s'):format(shop.id, GetPlayerName(src) or '?', Player.PlayerData.citizenid, #out, p.model))
        notify(src, L.vehicles_out:format(#out, p.label), 'success')
        if #out < amount then notify(src, L.pads_busy, 'error') end
        broadcastDisplays(shop)
        pushViewers(shop)
        return { ok = true, count = #out }
    end)
    cb(res or { ok = false })
end)

-- ---------------------------------------------------------------------------
-- Store fleet vehicles: bring them to the supply officer
-- ---------------------------------------------------------------------------
local function officerArea(shop)
    local ped = shop.cfg.itemPed
    if not ped then return nil end
    return vector3(ped.coords.x, ped.coords.y, ped.coords.z), shop.cfg.storeRadius or 30.0
end

local function condition(veh)
    return math.max(0, math.min(100, math.floor(GetVehicleEngineHealth(veh) / 10 + 0.5)))
end

QBCore.Functions.CreateCallback('jt-logistics:server:storeInfo', function(source, cb, shopId)
    local src = source
    local shop = ready and type(shopId) == 'string' and Shops[shopId]
    local Player = QBCore.Functions.GetPlayer(src)
    if not shop or not can(Player, shop, 'pickup') then notify(src, L.no_permission, 'error') return cb(false) end
    local center, radius = officerArea(shop)
    if not center or distanceTo(src, center) > 6.0 then notify(src, L.too_far, 'error') return cb(false) end
    local list = {}
    for veh, info in pairs(spawned) do
        if info.shop == shop.id and DoesEntityExist(veh) then
            local d = #(GetEntityCoords(veh) - center)
            local p = shop.byId[info.pid]
            if p and d <= radius then
                local netId = NetworkGetNetworkIdFromEntity(veh)
                list[#list + 1] = {
                    id = tostring(netId), label = p.label, plate = info.plate, image = p.image, category = p.category,
                    fallback = Config.VehicleImageFallback and Config.VehicleImageFallback:format(p.model) or nil,
                    condition = condition(veh), wrecked = isWrecked(veh), dist = math.floor(d),
                }
            end
        end
    end
    table.sort(list, function(a, b) return a.dist < b.dist end)
    cb({ kind = 'store', shop = shop.cfg.badge or shop.id, list = list, radius = math.floor(radius) })
end)

QBCore.Functions.CreateCallback('jt-logistics:server:storeVehicles', function(source, cb, shopId, ids)
    local src = source
    if not ready or not cooldown(src, 'store', 1500) then return cb({ ok = false }) end
    local res = withLock(function()
        local shop = type(shopId) == 'string' and Shops[shopId]
        local Player = QBCore.Functions.GetPlayer(src)
        if not shop or not can(Player, shop, 'pickup') then return { ok = false, msg = L.no_permission } end
        local center, radius = officerArea(shop)
        if not center or distanceTo(src, center) > 6.0 then return { ok = false, msg = L.too_far } end
        if type(ids) ~= 'table' then return { ok = false } end

        local myPed = GetPlayerPed(src)
        local stored, touched, labels, wrecked = 0, {}, {}, false
        for i, id in ipairs(ids) do
            if i > 20 then break end
            local netId = int(id, 1)
            local veh = netId and NetworkGetEntityFromNetworkId(netId)
            local info = veh and veh ~= 0 and spawned[veh]
            -- only this shop's fleet, here, intact, and nobody else at the controls
            if info and info.shop == shop.id and DoesEntityExist(veh) and #(GetEntityCoords(veh) - center) <= radius then
                local driver = GetPedInVehicleSeat(veh, -1)
                if isWrecked(veh) then
                    wrecked = true
                elseif driver == 0 or driver == myPed then
                    spawned[veh] = nil
                    DeleteEntity(veh)
                    dropKeys(info)
                    local st = shop.state
                    st.out[info.pid] = math.max(0, (st.out[info.pid] or 0) - 1)
                    st.depot[info.pid] = (st.depot[info.pid] or 0) + 1
                    touched[info.pid] = true
                    stored = stored + 1
                    labels[#labels + 1] = shop.byId[info.pid].label
                end
            end
        end
        if stored == 0 then return { ok = false, msg = wrecked and L.wrecked or L.nothing_to_store } end
        for pid in pairs(touched) do saveDepot(shop, pid) end
        saveFleet()
        log('Vehicles stored', 'blue', ('[%s] %s (%s) stored %s'):format(shop.id, GetPlayerName(src) or '?', Player.PlayerData.citizenid, table.concat(labels, ', ')))
        notify(src, L.stored:format(stored), 'success')
        broadcastDisplays(shop)
        pushViewers(shop)
        return { ok = true, count = stored }
    end)
    cb(res or { ok = false })
end)

-- ---------------------------------------------------------------------------
-- Depot: items (the NPC)
-- ---------------------------------------------------------------------------
QBCore.Functions.CreateCallback('jt-logistics:server:takeItems', function(source, cb, shopId, wanted)
    local src = source
    if not ready or not cooldown(src, 'take', 2000) then return cb({ ok = false }) end
    local res = withLock(function()
        local shop = type(shopId) == 'string' and Shops[shopId]
        local Player = QBCore.Functions.GetPlayer(src)
        if not shop or not can(Player, shop, 'pickup') then return { ok = false, msg = L.no_permission } end
        local ped = shop.cfg.itemPed
        if not ped or distanceTo(src, ped.coords) > 6.0 then return { ok = false, msg = L.too_far } end
        if type(wanted) ~= 'table' then return { ok = false } end

        local got, full = {}, false
        local count = 0
        for pid, amount in pairs(wanted) do
            count = count + 1
            if count > 50 then break end
            local p = type(pid) == 'string' and shop.byId[pid]
            local have = p and p.type == 'item' and (shop.state.depot[p.id] or 0) or 0
            amount = have > 0 and int(amount, 1, have)
            if amount then
                local given = 0
                if p.unique then -- weapons etc.: one slot each
                    for _ = 1, amount do
                        if not canAdd(src, Player, p.item, 1) or not addItem(src, Player, p.item, 1) then full = true break end
                        given = given + 1
                    end
                elseif canAdd(src, Player, p.item, amount) and addItem(src, Player, p.item, amount) then
                    given = amount
                else
                    full = true
                end
                if given > 0 then
                    shop.state.depot[p.id] = have - given
                    saveDepot(shop, p.id)
                    itemBox(src, p.item, given)
                    got[#got + 1] = ('%s× %s'):format(given, p.label)
                end
            end
        end
        if #got == 0 then return { ok = false, msg = full and L.inventory_full or L.nothing_here } end
        log('Items received', 'orange', ('[%s] %s (%s): %s'):format(shop.id, GetPlayerName(src) or '?', Player.PlayerData.citizenid, table.concat(got, ', ')))
        notify(src, L.items_received:format(table.concat(got, ', ')), 'success', 7000)
        if full then notify(src, L.inventory_full, 'error', 7000) end
        pushViewers(shop)
        return { ok = true }
    end)
    cb(res or { ok = false })
end)

-- ---------------------------------------------------------------------------
-- Admin
-- ---------------------------------------------------------------------------
QBCore.Commands.Add('logisticsbalance', 'Set a logistics budget (admin)', { { name = 'shop', help = 'cia / lspd ...' }, { name = 'amount', help = 'new balance' } }, true, function(source, args)
    if not isAdmin(source) then return notify(source, L.no_permission, 'error') end
    local shop = Shops[args[1] or '']
    local amount = int(args[2], 0, 1000000000000)
    if not shop or not amount then return notify(source, 'usage: /logisticsbalance shop amount', 'error') end
    withLock(function()
        shop.state.balance = amount
        saveShop(shop)
        log('Budget set', 'red', ('[%s] set to $%s by %s'):format(shop.id, amount, GetPlayerName(source) or 'console'))
        pushViewers(shop)
    end)
    notify(source, ('%s = $%s'):format(shop.id, comma(amount)), 'success')
end)

QBCore.Commands.Add('logisticsfleet', 'Set how many of a product are in a depot (admin)', { { name = 'shop', help = 'cia' }, { name = 'product', help = 'product id (lazer, carbine...)' }, { name = 'amount', help = 'in the garage / ready' } }, true, function(source, args)
    if not isAdmin(source) then return notify(source, L.no_permission, 'error') end
    local shop = Shops[args[1] or '']
    local p = shop and shop.byId[args[2] or '']
    local amount = int(args[3], 0, 100000)
    if not p or not amount then return notify(source, 'usage: /logisticsfleet shop product amount', 'error') end
    withLock(function()
        shop.state.depot[p.id] = amount > 0 and amount or nil
        saveDepot(shop, p.id)
        log('Depot set', 'red', ('[%s] %s = %s by %s'):format(shop.id, p.id, amount, GetPlayerName(source) or 'console'))
        broadcastDisplays(shop)
        pushViewers(shop)
    end)
    notify(source, ('%s / %s = %s'):format(shop.id, p.id, amount), 'success')
end)

-- every fleet vehicle of a shop (or one product) still out in the world → back to the garage
QBCore.Commands.Add('logisticsrecall', 'Bring a shop\'s fleet back to the garage (admin)', { { name = 'shop', help = 'cia' }, { name = 'product', help = 'optional: product id' } }, true, function(source, args)
    if not isAdmin(source) then return notify(source, L.no_permission, 'error') end
    local shop = Shops[args[1] or '']
    local only = args[2]
    if not shop or (only and not shop.byId[only]) then return notify(source, 'usage: /logisticsrecall shop [product]', 'error') end
    local n = withLock(function()
        local count, touched = 0, {}
        for veh, info in pairs(spawned) do
            if info.shop == shop.id and (not only or info.pid == only) then
                spawned[veh] = nil
                if DoesEntityExist(veh) then DeleteEntity(veh) end
                dropKeys(info)
                local st = shop.state
                st.out[info.pid] = math.max(0, (st.out[info.pid] or 0) - 1)
                st.depot[info.pid] = (st.depot[info.pid] or 0) + 1
                touched[info.pid] = true
                count = count + 1
            end
        end
        for pid in pairs(touched) do saveDepot(shop, pid) end
        saveFleet()
        if count > 0 then
            log('Fleet recalled', 'red', ('[%s] %s vehicle(s)%s by %s'):format(shop.id, count, only and (' of ' .. only) or '', GetPlayerName(source) or 'console'))
            broadcastDisplays(shop)
            pushViewers(shop)
        end
        return count
    end)
    notify(source, L.recalled:format(n or 0), 'success')
end)

QBCore.Commands.Add('logisticscoords', 'Print your position as vector4 (admin)', {}, false, function(source)
    if not isAdmin(source) then return notify(source, L.no_permission, 'error') end
    TriggerClientEvent('jt-logistics:client:coords', source)
end)

-- Vehicle photos: the admin's client shoots every vehicle in a studio, the NUI
-- cuts the background out and the result is saved in html/img/vehicles/.
local photoSessions = {}

QBCore.Commands.Add('logisticsphotos', 'Take the shop photos of every vehicle (admin)', { { name = 'model', help = 'optional: one model' } }, false, function(source, args)
    if source == 0 or not isAdmin(source) then return notify(source, L.no_permission, 'error') end
    local list, set = {}, {}
    local only = args[1] and args[1]:lower()
    for _, shop in pairs(Shops) do
        for _, p in ipairs(shop.list) do
            if p.type == 'vehicle' and not set[p.model] and (not only or only == p.model:lower()) then
                set[p.model] = true
                list[#list + 1] = p.model
            end
        end
    end
    if #list == 0 then return notify(source, 'no vehicles', 'error') end
    local token = tostring(math.random(100000000, 999999999))
    photoSessions[source] = { token = token, models = set }
    TriggerClientEvent('jt-logistics:client:photos', source, list, token)
end)

local b64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local b64i = {}
for i = 1, 64 do b64i[b64:byte(i)] = i - 1 end

local function b64decode(s)
    s = s:gsub('[^%w%+/]', '')
    local out, n = {}, 0
    for i = 1, #s, 4 do
        local a, b, c, d = b64i[s:byte(i)], b64i[s:byte(i + 1) or 0], b64i[s:byte(i + 2) or 0], b64i[s:byte(i + 3) or 0]
        if not a or not b then break end
        local v = (a << 18) | (b << 12) | ((c or 0) << 6) | (d or 0)
        n = n + 1
        if d then out[n] = string.char((v >> 16) & 255, (v >> 8) & 255, v & 255)
        elseif c then out[n] = string.char((v >> 16) & 255, (v >> 8) & 255)
        else out[n] = string.char((v >> 16) & 255) end
    end
    return table.concat(out)
end

RegisterNetEvent('jt-logistics:server:savePhoto', function(token, model, data)
    local src = source
    local session = photoSessions[src]
    if not session or token ~= session.token or not isAdmin(src) then return end
    if type(model) ~= 'string' or not session.models[model] or not model:match('^[%w_]+$') or #model > 40 then return end
    if type(data) ~= 'string' or #data > 2000000 then return end
    local body = data:match('^data:image/webp;base64,(.+)$')
    if not body then return TriggerClientEvent('jt-logistics:client:photoSaved', src, model, false) end
    local bin = b64decode(body)
    if bin:sub(1, 4) ~= 'RIFF' or bin:sub(9, 12) ~= 'WEBP' then return TriggerClientEvent('jt-logistics:client:photoSaved', src, model, false) end
    local ok = SaveResourceFile(RES, 'html/img/vehicles/' .. model .. '.webp', bin, #bin)
    if ok then
        for _, shop in pairs(Shops) do
            for _, p in ipairs(shop.list) do if p.model == model then p.image = 'img/vehicles/' .. model .. '.webp' end end
        end
    end
    TriggerClientEvent('jt-logistics:client:photoSaved', src, model, ok and true or false)
end)

-- ---------------------------------------------------------------------------
-- Cleanup
-- ---------------------------------------------------------------------------
AddEventHandler('playerDropped', function()
    local src = source
    for _, v in pairs(viewers) do v[src] = nil end
    cooldowns[src] = nil
    photoSessions[src] = nil
end)

--- For anti-cheats / entity blacklists: true for vehicles this script spawned
--- (tracked on the server, can't be faked by a client). Example (entityCreated):
---     if exports['JT-MilitaryArmory']:IsFleetVehicle(handle) then return end
exports('IsFleetVehicle', function(entity)
    entity = math.tointeger(entity)
    if not entity or entity == 0 then return false end
    if spawned[entity] or creating[entity] then return true end
    local n = pendingModels[u32(GetEntityModel(entity))]
    return n ~= nil and n > 0 -- created by the server right now (the call above hasn't returned yet)
end)

exports('GetBalance', function(shopId) local s = Shops[shopId] return s and s.state and s.state.balance or nil end)
