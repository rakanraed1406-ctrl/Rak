--[[ server.lua — helicopter shop / hangar.
     Everything is decided here: the model and price come from Config, the
     player must be on Config.AllowedCitizens and standing at the bot, the
     aircraft is spawned by the server, and storing needs the real aircraft
     (same plate AND model) near the hangar — it is deleted by the server. ]]

local QBCore = exports['qb-core']:GetCoreObject()

local catalog = {} -- [model] = config entry
for _, h in ipairs(Config.Helicopters) do catalog[h.model] = h end

local botPos = vector3(Config.Bot.coords.x, Config.Bot.coords.y, Config.Bot.coords.z)
local busy, cooldowns = {}, {}

local function notify(src, msg, kind)
    TriggerClientEvent('QBCore:Notify', src, msg, kind or 'primary')
end

local function cooldown(src, ms)
    local now = GetGameTimer()
    if cooldowns[src] and now - cooldowns[src] < ms then return false end
    cooldowns[src] = now
    return true
end

--- The player, if allowed and standing at the bot.
local function allowedPlayer(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not Config.AllowedCitizens[Player.PlayerData.citizenid] then return nil end
    local ped = GetPlayerPed(src)
    if ped == 0 or #(GetEntityCoords(ped) - botPos) > (Config.UseDistance or 10.0) then return nil end
    return Player
end

local function trim(s) return (tostring(s or ''):gsub('^%s*(.-)%s*$', '%1')) end
local function sameHash(a, b) return (a & 0xFFFFFFFF) == (b & 0xFFFFFFFF) end
local function isStored(v) return v == true or tonumber(v) == 1 end -- oxmysql may return TINYINT(1) as a boolean

local function findVehicleByPlate(plate)
    for _, veh in ipairs(GetAllVehicles()) do
        if DoesEntityExist(veh) and trim(GetVehicleNumberPlateText(veh)) == plate then return veh end
    end
end

local function validPlate(plate) return type(plate) == 'string' and #plate > 0 and #plate <= 8 end

local function generatePlate()
    for _ = 1, 30 do
        local plate = 'HELI' .. math.random(1000, 9999)
        if not MySQL.scalar.await('SELECT 1 FROM player_helicopters WHERE plate = ? LIMIT 1', { plate }) then return plate end
    end
end

-- closest free pad to the player (nothing within 4 m)
local function freeSpawnPoint(src)
    local ped = GetPlayerPed(src)
    local from = ped ~= 0 and GetEntityCoords(ped) or botPos
    local points = {}
    for _, p in ipairs(Config.SpawnPoints) do points[#points + 1] = p end
    table.sort(points, function(a, b)
        return #(from - vector3(a.x, a.y, a.z)) < #(from - vector3(b.x, b.y, b.z))
    end)
    local vehicles = GetAllVehicles()
    for _, p in ipairs(points) do
        local pos, free = vector3(p.x, p.y, p.z), true
        for _, veh in ipairs(vehicles) do
            if #(GetEntityCoords(veh) - pos) < 4.0 then
                free = false
                break
            end
        end
        if free then return p end
    end
end

--- Spawns it on the server and hands it to the player. Returns the entity or nil.
local function spawnFor(src, model, plate)
    local point = freeSpawnPoint(src)
    if not point then return nil end
    local hash = joaat(model)
    local vtype = catalog[model] and catalog[model].type
    local veh = vtype and CreateVehicleServerSetter(hash, vtype, point.x, point.y, point.z, point.w)
        or CreateVehicle(hash, point.x, point.y, point.z, point.w, true, true)
    local timeout = GetGameTimer() + 5000
    while not veh or veh == 0 or not DoesEntityExist(veh) do
        if GetGameTimer() > timeout then
            if veh and veh ~= 0 and DoesEntityExist(veh) then DeleteEntity(veh) end
            return nil
        end
        Wait(50)
    end
    SetVehicleNumberPlateText(veh, plate)
    TriggerClientEvent('qb-militaryhelipad-byrko:client:TakeHelicopter', src, NetworkGetNetworkIdFromEntity(veh), plate)
    return veh
end

local function locked(src, fn)
    if busy[src] then return end
    busy[src] = true
    local ok, err = pcall(fn)
    busy[src] = nil
    if not ok then print(('^1[qb-militaryhelipad] %s^0'):format(err)) end
end

QBCore.Functions.CreateCallback('qb-militaryhelipad-byrko:server:GetOwnedHelicopters', function(source, cb)
    local Player = allowedPlayer(source)
    if not Player then return cb({}) end
    local rows = MySQL.query.await('SELECT vehicle, plate, stored FROM player_helicopters WHERE citizenid = ?', { Player.PlayerData.citizenid }) or {}
    local out = {}
    for _, r in ipairs(rows) do
        if isStored(r.stored) then
            out[#out + 1] = { vehicle = r.vehicle, plate = r.plate }
        elseif Config.RecoverLost and not findVehicleByPlate(r.plate) then
            out[#out + 1] = { vehicle = r.vehicle, plate = r.plate, lost = true }
        end
    end
    cb(out)
end)

RegisterNetEvent('qb-militaryhelipad-byrko:server:BuyHelicopter', function(modelName)
    local src = source
    if not cooldown(src, 2000) then return end
    locked(src, function()
        local Player = allowedPlayer(src)
        if not Player then return end
        local entry = type(modelName) == 'string' and catalog[modelName]
        local price = entry and math.floor(tonumber(entry.price) or 0)
        if not entry or price <= 0 then return end -- only what is for sale, at the config price
        if not freeSpawnPoint(src) then return notify(src, 'All helipads are currently occupied!', 'error') end

        local mt = Config.MoneyType == 'bank' and 'bank' or 'cash'
        if (Player.PlayerData.money[mt] or 0) < price or not Player.Functions.RemoveMoney(mt, price, 'helicopter-purchase') then
            return notify(src, 'Not enough ' .. mt .. '!', 'error')
        end

        local plate = generatePlate()
        local id = plate and MySQL.insert.await('INSERT INTO player_helicopters (citizenid, vehicle, plate, stored) VALUES (?, ?, ?, ?)',
            { Player.PlayerData.citizenid, entry.model, plate, 0 })
        if not id then
            Player.Functions.AddMoney(mt, price, 'helicopter-purchase-refund')
            return notify(src, 'Purchase failed, money refunded', 'error')
        end
        if spawnFor(src, entry.model, plate) then
            notify(src, 'Helicopter purchased and spawned successfully!', 'success')
        else
            MySQL.update.await('UPDATE player_helicopters SET stored = 1 WHERE plate = ?', { plate })
            notify(src, 'Helicopter purchased — it is in your hangar (pads busy)', 'success')
        end
        TriggerEvent('qb-log:server:CreateLog', 'vehicleshop', 'Helicopter Purchase', 'green',
            ('%s (%s) bought %s [%s] for $%s'):format(GetPlayerName(src) or '?', Player.PlayerData.citizenid, entry.model, plate, price))
    end)
end)

RegisterNetEvent('qb-militaryhelipad-byrko:server:SpawnOwnedHeli', function(plate)
    local src = source
    if not cooldown(src, 2000) or not validPlate(plate) then return end
    locked(src, function()
        local Player = allowedPlayer(src)
        if not Player then return end
        local cid = Player.PlayerData.citizenid
        local row = MySQL.single.await('SELECT vehicle, stored FROM player_helicopters WHERE plate = ? AND citizenid = ? LIMIT 1', { plate, cid })
        if not row then return notify(src, 'You do not own this helicopter!', 'error') end

        if isStored(row.stored) then
            -- only one request can take it out
            local changed = MySQL.update.await('UPDATE player_helicopters SET stored = 0 WHERE plate = ? AND citizenid = ? AND stored = 1', { plate, cid })
            if not changed or changed < 1 then return end
        elseif not Config.RecoverLost or findVehicleByPlate(plate) then
            return notify(src, 'This helicopter is already outside!', 'error')
        end

        if spawnFor(src, row.vehicle, plate) then
            notify(src, 'Helicopter spawned from garage!', 'success')
        else
            MySQL.update.await('UPDATE player_helicopters SET stored = 1 WHERE plate = ? AND citizenid = ?', { plate, cid })
            notify(src, 'All helipads are currently occupied!', 'error')
        end
    end)
end)

RegisterNetEvent('qb-militaryhelipad-byrko:server:StoreHelicopter', function(plate)
    local src = source
    if not cooldown(src, 1500) or not validPlate(plate) then return end
    locked(src, function()
        local Player = allowedPlayer(src)
        if not Player then return end
        local cid = Player.PlayerData.citizenid
        local row = MySQL.single.await('SELECT vehicle FROM player_helicopters WHERE plate = ? AND citizenid = ? LIMIT 1', { plate, cid })
        if not row then return notify(src, 'Action denied: Invalid helicopter ownership!', 'error') end

        -- the real aircraft must be here: same plate AND same model (a fake plate
        -- on another vehicle used to mark it stored while the real one stayed out)
        local veh = findVehicleByPlate(plate)
        if not veh or not sameHash(GetEntityModel(veh), joaat(row.vehicle)) then
            return notify(src, 'That helicopter is not here', 'error')
        end
        if #(GetEntityCoords(veh) - botPos) > (Config.StoreDistance or 60.0) then
            return notify(src, 'Bring the helicopter closer to the hangar', 'error')
        end
        local driver = GetPedInVehicleSeat(veh, -1)
        if driver ~= 0 and driver ~= GetPlayerPed(src) then
            return notify(src, 'Someone is flying it', 'error')
        end

        DeleteEntity(veh)
        MySQL.update.await('UPDATE player_helicopters SET stored = 1 WHERE plate = ? AND citizenid = ?', { plate, cid })
        notify(src, 'Helicopter stored in garage successfully!', 'success')
    end)
end)

AddEventHandler('playerDropped', function()
    busy[source] = nil
    cooldowns[source] = nil
end)
