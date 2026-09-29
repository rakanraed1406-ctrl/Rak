--[[ stock/server.lua — random stock showroom for qb-vehicleshop.
     Each spot of each category rolls one random vehicle per restart (/restockcars,
     optional timer). Buying removes it until the next restock. ]]

local QBCore = exports['qb-core']:GetCoreObject()
local VS = {}

function VS.Notify(src, msg, kind, ms)
    TriggerClientEvent('QBCore:Notify', src, msg, kind or 'primary', ms or 5000)
end

function VS.IsAdmin(src)
    if src == 0 then return true end -- server console
    for _, group in ipairs(Config.Stock.AdminGroups or {}) do
        if QBCore.Functions.HasPermission(src, group) then return true end
    end
    return IsPlayerAceAllowed(src, 'command')
end

function VS.CharName(Player)
    local ci = Player and Player.PlayerData.charinfo or {}
    return ((ci.firstname or 'Unknown') .. ' ' .. (ci.lastname or '')):gsub('%s+$', '')
end

function VS.VehicleLabel(model)
    local v = QBCore.Shared.Vehicles[model]
    if v then
        local name = v.name or model
        if v.brand and v.brand ~= '' then return v.brand .. ' ' .. name end
        return name
    end
    return model
end

function VS.Money(Player)
    return Player.PlayerData.money[Config.Stock.MoneyType] or 0
end

function VS.DistanceTo(src, coords)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return math.huge end
    local p = GetEntityCoords(ped)
    return #(vector3(p.x, p.y, p.z) - vector3(coords.x, coords.y, coords.z))
end

-- Unique plate (8 chars like "AB12CD34"), checked against player_vehicles.
local charset = 'ABCDEFGHJKLMNPQRSTUVWXYZ'
local function randomPlate()
    local out = {}
    for i = 1, 8 do
        if i % 2 == 1 then
            local n = math.random(1, #charset)
            out[i] = charset:sub(n, n)
        else
            out[i] = tostring(math.random(0, 9))
        end
    end
    return table.concat(out)
end

function VS.GeneratePlate()
    for _ = 1, 25 do
        local plate = randomPlate()
        local taken = MySQL.scalar.await('SELECT 1 FROM player_vehicles WHERE plate = ?', { plate })
        if not taken then return plate end
    end
    return randomPlate()
end

--- Saves the vehicle to the player's garage table and tells their client to
--- spawn it at `spawn` and hand over the keys.
function VS.GiveVehicle(src, model, spawn, reason)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false end
    local plate = VS.GeneratePlate()

    MySQL.insert.await(
        'INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, garage, state) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        { Player.PlayerData.license, Player.PlayerData.citizenid, model, joaat(model), '{}', plate, Config.Stock.DefaultGarage, 0 }
    )

    TriggerClientEvent('qb-vehicleshop:stock:client:deliverVehicle', src, {
        model = model,
        plate = plate,
        spawn = { x = spawn.x, y = spawn.y, z = spawn.z, w = spawn.w },
    })

    TriggerEvent('qb-log:server:CreateLog', 'vehicleshop', reason or 'Vehicle Purchase', 'green',
        ('**%s** (%s) got **%s** [%s]'):format(GetPlayerName(src) or '?', Player.PlayerData.citizenid, model, plate))
    return plate
end

-- Admin helper: prints your coords as a vector4 so filling the config is easy.
QBCore.Commands.Add('vscoords', 'Print your position as vector4 (vehicle sales setup)', {}, false, function(source)
    if not VS.IsAdmin(source) then return VS.Notify(source, Config.StockLang.no_permission, 'error') end
    TriggerClientEvent('qb-vehicleshop:stock:client:printCoords', source)
end)

VS.Stock = {} -- [storeId] = { [slotId] = { id, category, categoryLabel, model, label, price, coords, sold } }

local function warnMissingModels()
    for storeId, store in pairs(Config.Stock.Stores) do
        for catId, cat in pairs(store.categories) do
            for _, v in ipairs(cat.vehicles or {}) do
                if not QBCore.Shared.Vehicles[v.model] then
                    print(('^3[qb-vehicleshop stock] "%s" (%s/%s) is not in qb-core/shared/vehicles.lua — garages may not show it.^0')
                        :format(v.model, storeId, catId))
                end
            end
        end
    end
end

function VS.StatOverride(v)
    local byModel = (Config.Stock.VehicleStats or {})[v.model] or {}
    local out, any = {}, false
    for _, k in ipairs({ 'speed', 'acceleration', 'braking', 'handling' }) do
        local val = tonumber(v[k]) or tonumber(byModel[k])
        if val then out[k] = val; any = true end
    end
    return any and out or nil
end

function VS.Restock()
    VS.Stock = {}
    for storeId, store in pairs(Config.Stock.Stores) do
        local slots = {}
        for catId, cat in pairs(store.categories) do
            local pool = cat.vehicles or {}
            local spots = cat.spots or (cat.spot and { cat.spot }) or {}
            if #pool > 0 then
                -- Shuffle so several spots of the same category don't repeat a car
                -- while there are still other cars in the list.
                local bag = {}
                for i, v in ipairs(pool) do bag[i] = v end
                for i = #bag, 2, -1 do
                    local j = math.random(1, i)
                    bag[i], bag[j] = bag[j], bag[i]
                end
                for i, spot in ipairs(spots) do
                    local v = bag[((i - 1) % #bag) + 1]
                    local slotId = catId .. '_' .. i
                    slots[slotId] = {
                        id = slotId,
                        category = catId,
                        categoryLabel = cat.label or catId,
                        model = v.model,
                        label = v.label or VS.VehicleLabel(v.model),
                        price = math.floor(tonumber(v.price) or 0),
                        coords = { x = spot.x, y = spot.y, z = spot.z, w = spot.w },
                        sold = false,
                        -- stats you set yourself (the car entry wins over VehicleStats);
                        -- anything left out is measured by the client from the game
                        stats = VS.StatOverride(v),
                    }
                end
            end
        end
        VS.Stock[storeId] = slots
    end
    TriggerClientEvent('qb-vehicleshop:stock:client:stock', -1, VS.Stock)
end

CreateThread(function()
    math.randomseed(os.time())
    Wait(1000) -- let qb-core shared vehicles load
    warnMissingModels()
    VS.Restock()

    local minutes = tonumber(Config.Stock.RestockEveryMinutes) or 0
    if minutes > 0 then
        while true do
            Wait(minutes * 60000)
            VS.Restock()
            TriggerClientEvent('QBCore:Notify', -1, Config.StockLang.restocked, 'primary')
        end
    end
end)

QBCore.Functions.CreateCallback('qb-vehicleshop:stock:server:getStock', function(_, cb)
    cb(VS.Stock)
end)

QBCore.Commands.Add('restockcars', 'Re-roll every vehicle showroom (admin)', {}, false, function(source)
    if not VS.IsAdmin(source) then return VS.Notify(source, Config.StockLang.no_permission, 'error') end
    VS.Restock()
    VS.Notify(source, Config.StockLang.restocked, 'success')
end)

local buyCooldown = {}

RegisterNetEvent('qb-vehicleshop:stock:server:buy', function(storeId, slotId)
    local src = source
    local now = GetGameTimer()
    if buyCooldown[src] and now - buyCooldown[src] < 2000 then return end
    buyCooldown[src] = now

    local Player = QBCore.Functions.GetPlayer(src)
    local store = Config.Stock.Stores[storeId]
    local slot = VS.Stock[storeId] and VS.Stock[storeId][slotId]
    if not Player or not store or not slot then return end

    if slot.sold then return VS.Notify(src, Config.StockLang.already_sold, 'error') end
    if VS.DistanceTo(src, slot.coords) > (Config.Stock.BuyDistance or 8.0) then
        return VS.Notify(src, Config.StockLang.too_far, 'error')
    end
    if VS.Money(Player) < slot.price then
        return VS.Notify(src, Config.StockLang.not_enough_money:format(slot.price), 'error')
    end

    -- Mark sold + take the money in the same tick (no await in between), so
    -- two players clicking at once can never both buy the same car.
    if not Player.Functions.RemoveMoney(Config.Stock.MoneyType, slot.price, 'vehicle-showroom') then
        return VS.Notify(src, Config.StockLang.not_enough_money:format(slot.price), 'error')
    end
    slot.sold = true
    TriggerClientEvent('qb-vehicleshop:stock:client:slotSold', -1, storeId, slotId)

    VS.GiveVehicle(src, slot.model, store.deliverySpawn, 'Showroom Purchase')
    VS.Notify(src, Config.StockLang.bought:format(slot.label, slot.price), 'success', 7000)
end)

AddEventHandler('playerDropped', function() buyCooldown[source] = nil end)

-- For other scripts / debugging: current showroom stock.
exports('GetStock', function() return VS.Stock end)

-- ---------------------------------------------------------------------------
-- Test drive (G on the showroom card)
-- ---------------------------------------------------------------------------
local testDrives = {} -- [src] = { price, moneyType, started, netId, token }

local function tdRemoveMoney(Player, amount, preferred)
    if amount <= 0 then return preferred or 'cash' end
    local first = preferred or 'cash'
    local second = first == 'cash' and 'bank' or 'cash'
    for _, mt in ipairs({ first, second }) do
        if (Player.PlayerData.money[mt] or 0) >= amount and Player.Functions.RemoveMoney(mt, amount, 'vehicle-testdrive') then
            return mt
        end
    end
    return nil
end

local function tdCleanup(src)
    local td = testDrives[src]
    if not td then return end
    testDrives[src] = nil
    if td.netId then
        local ent = NetworkGetEntityFromNetworkId(td.netId)
        if ent and ent ~= 0 and DoesEntityExist(ent) then DeleteEntity(ent) end
    end
end

RegisterNetEvent('qb-vehicleshop:stock:server:testDrive', function(storeId, slotId)
    local src = source
    local cfg = Config.Stock.TestDrive or {}
    if not cfg.Enabled then return VS.Notify(src, Config.StockLang.testdrive_off, 'error') end
    if testDrives[src] then return VS.Notify(src, Config.StockLang.testdrive_busy, 'error') end

    local now = GetGameTimer()
    if buyCooldown[src] and now - buyCooldown[src] < 2000 then return end
    buyCooldown[src] = now

    local Player = QBCore.Functions.GetPlayer(src)
    local store = Config.Stock.Stores[storeId]
    local slot = VS.Stock[storeId] and VS.Stock[storeId][slotId]
    if not Player or not store or not slot then return end
    if slot.sold then return VS.Notify(src, Config.StockLang.already_sold, 'error') end
    if VS.DistanceTo(src, slot.coords) > (Config.Stock.BuyDistance or 8.0) then
        return VS.Notify(src, Config.StockLang.too_far, 'error')
    end

    local price = math.floor(tonumber(cfg.Price) or 0)
    local paidWith = tdRemoveMoney(Player, price, cfg.MoneyType)
    if not paidWith then
        return VS.Notify(src, Config.StockLang.testdrive_money:format(price), 'error')
    end

    local seconds = math.max(10, math.floor(tonumber(cfg.Seconds) or 60))
    local token = math.random(100000, 999999)
    testDrives[src] = { price = price, moneyType = paidWith, started = false, token = token }

    local spawn = store.testDriveSpawn or store.deliverySpawn
    TriggerClientEvent('qb-vehicleshop:stock:client:startTestDrive', src, {
        model = slot.model,
        label = slot.label,
        seconds = seconds,
        leaveSeconds = tonumber(cfg.LeaveSeconds) or 3,
        spawn = { x = spawn.x, y = spawn.y, z = spawn.z, w = spawn.w },
    })

    -- backstop: if the client never reports the end, clean up anyway
    SetTimeout((seconds + 45) * 1000, function()
        local td = testDrives[src]
        if td and td.token == token then
            tdCleanup(src)
            TriggerClientEvent('qb-vehicleshop:stock:client:forceEndTestDrive', src)
        end
    end)
end)

RegisterNetEvent('qb-vehicleshop:stock:server:testDriveSpawned', function(netId)
    local td = testDrives[source]
    if td and not td.started and type(netId) == 'number' then
        td.started = true
        td.netId = netId
    end
end)

-- the car could not be spawned: give the money back (only before it started)
RegisterNetEvent('qb-vehicleshop:stock:server:testDriveFailed', function()
    local src = source
    local td = testDrives[src]
    if not td or td.started then return end
    testDrives[src] = nil
    local Player = QBCore.Functions.GetPlayer(src)
    if Player and td.price > 0 then Player.Functions.AddMoney(td.moneyType, td.price, 'vehicle-testdrive-refund') end
    VS.Notify(src, Config.StockLang.testdrive_failed, 'error')
end)

RegisterNetEvent('qb-vehicleshop:stock:server:testDriveEnd', function()
    tdCleanup(source)
end)

AddEventHandler('playerDropped', function() tdCleanup(source) end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for src in pairs(testDrives) do tdCleanup(src) end
end)
