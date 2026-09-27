--[[ server/main.lua — shared helpers used by stock.lua and auction.lua ]]

QBCore = exports['qb-core']:GetCoreObject()
VS = {}

function VS.Notify(src, msg, kind, ms)
    TriggerClientEvent('QBCore:Notify', src, msg, kind or 'primary', ms or 5000)
end

function VS.IsAdmin(src)
    if src == 0 then return true end -- server console
    for _, group in ipairs(Config.AdminGroups or {}) do
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
    return Player.PlayerData.money[Config.MoneyType] or 0
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
        { Player.PlayerData.license, Player.PlayerData.citizenid, model, joaat(model), '{}', plate, Config.DefaultGarage, 0 }
    )

    TriggerClientEvent('rk-vehiclesales:client:deliverVehicle', src, {
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
    if not VS.IsAdmin(source) then return VS.Notify(source, Config.Lang.no_permission, 'error') end
    TriggerClientEvent('rk-vehiclesales:client:printCoords', source)
end)
