--[[ server/alerts.lua — validates the automatic alerts from client/alerts.lua and
     turns them into dispatch calls (built-in dispatch, same colours / sounds).
     Also: speed-camera fines, the panic sound for nearby players. ]]

local QBCore = MDT.QBCore
local ACfg = Config.Alerts or {}

local cooldowns = { gunshot = {}, stolen = {}, speed = {} }
local KIND_CFG = { gunshot = 'Gunshots', stolen = 'StolenCar', speed = 'SpeedTrap' }

local function clean(v, max, fallback)
    if type(v) ~= 'string' and type(v) ~= 'number' then return fallback end
    v = tostring(v):gsub('[<>]', ''):gsub('^%s*(.-)%s*$', '%1')
    if v == '' then return fallback end
    return v:sub(1, max or 60)
end

local function isIgnored(Player)
    local job = Player.PlayerData.job
    for _, name in ipairs(ACfg.IgnoreJobs or {}) do
        if job.name == name and job.onduty then return true end
    end
    return false
end

local function pedCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    return { x = c.x, y = c.y, z = c.z }
end

local function vehicleTags(d)
    local tags = {}
    if d.vehicle then tags[#tags + 1] = { icon = 'fa-car', label = (d.color and (d.color .. ' ') or '') .. d.vehicle } end
    if d.plate then tags[#tags + 1] = { icon = 'fa-id-card', label = d.plate } end
    if d.heading then tags[#tags + 1] = { icon = 'fa-compass', label = 'Heading ' .. d.heading } end
    return tags
end

-- ---------------------------------------------------------------------------
-- Builders
-- ---------------------------------------------------------------------------

local BUILD = {}

function BUILD.gunshot(d)
    local tags = { { icon = 'fa-gun', label = d.weapon, isWeapon = true } }
    if d.inVehicle and d.vehicle then
        for _, t in ipairs(vehicleTags(d)) do tags[#tags + 1] = t end
        return {
            code = '10-60', title = 'Shots Fired From Vehicle',
            description = ('Shots fired from a %s %s [%s] heading %s on %s.'):format(d.color or '', d.vehicle, d.plate or '?', d.heading or '?', d.street),
            tags = tags,
        }
    end
    tags[#tags + 1] = { icon = 'fa-person', label = d.sex .. ' suspect' }
    tags[#tags + 1] = { icon = 'fa-compass', label = 'Facing ' .. (d.heading or '?') }
    return {
        code = '10-11', title = 'Shots Fired',
        description = ('%s suspect firing a %s near %s.'):format(d.sex, d.weapon, d.street),
        tags = tags,
    }
end

function BUILD.stolen(d)
    local tags = vehicleTags(d)
    table.insert(tags, 1, { icon = 'fa-person', label = d.sex .. ' suspect' })
    if d.jacking then
        return {
            code = '10-35', title = 'Carjacking In Progress',
            description = ('%s suspect pulled a driver out of a %s %s [%s] on %s, heading %s.'):format(d.sex, d.color, d.vehicle, d.plate, d.street, d.heading),
            tags = tags,
        }
    end
    return {
        code = '10-16', title = 'Vehicle Theft',
        description = ('%s suspect breaking into a %s %s [%s] on %s.'):format(d.sex, d.color, d.vehicle, d.plate, d.street),
        tags = tags,
    }
end

function BUILD.speed(d)
    local T = ACfg.SpeedTrap
    local unit = (T.unit == 'mph') and 'mph' or 'km/h'
    local tags = vehicleTags(d)
    table.insert(tags, 1, { icon = 'fa-gauge-high', label = ('%s %s (limit %s)'):format(d.speed, unit, d.limit) })
    return {
        code = 'SPEEDING', title = 'Speed Camera',
        description = ('%s %s [%s] clocked at %s %s (limit %s) heading %s on %s.'):format(d.color, d.vehicle, d.plate, d.speed, unit, d.limit, d.heading, d.street),
        tags = tags,
    }
end

-- ---------------------------------------------------------------------------
-- Speed-camera fine
-- ---------------------------------------------------------------------------

local function ownsVehicle(Player, plate)
    local row = exports.oxmysql:executeSync('SELECT 1 FROM player_vehicles WHERE plate = ? AND citizenid = ? LIMIT 1',
        { plate, Player.PlayerData.citizenid })
    return row and row[1] ~= nil
end

local function handleSpeed(src, Player, d, coords)
    local T = ACfg.SpeedTrap
    local loc = T.Locations and T.Locations[math.floor(tonumber(d.index) or 0)]
    if not loc then return false end
    -- Must really be at that camera (stops faked fines / alerts).
    if #(vector3(coords.x, coords.y, coords.z) - loc.coords) > (loc.radius or 10.0) + 25.0 then return false end
    d.speed = math.floor(tonumber(d.speed) or 0)
    if d.speed <= (loc.limit or 100) or d.speed > 600 then return false end
    d.limit = loc.limit

    local unit = (T.unit == 'mph') and 'mph' or 'km/h'
    local fine = math.floor(tonumber(loc.fine) or 0)
    if fine > 0 and (not T.checkOwner or ownsVehicle(Player, d.plate)) then
        Player.Functions.RemoveMoney(T.fineAccount or 'bank', fine, 'speed-camera')
        TriggerClientEvent('QBCore:Notify', src,
            ('Speed camera: %s %s in a %s zone — fined $%s'):format(d.speed, unit, loc.limit, fine), 'error', 7000)
    end
    return T.alertPolice ~= false
end

-- ---------------------------------------------------------------------------
-- Entry point
-- ---------------------------------------------------------------------------

RegisterNetEvent('police:server:AutoAlert', function(kind, data)
    local src = source
    if not ACfg.Enabled or not KIND_CFG[kind] or type(data) ~= 'table' then return end
    local kcfg = ACfg[KIND_CFG[kind]]
    if not kcfg or not kcfg.enabled then return end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or isIgnored(Player) then return end

    local now = os.time()
    local cd = math.max(tonumber(kcfg.cooldown) or 10, 3)
    if cooldowns[kind][src] and now - cooldowns[kind][src] < cd then return end
    cooldowns[kind][src] = now

    local coords = pedCoords(src)
    if not coords then return end

    local d = {
        street = clean(data.street, 80, 'Unknown location'),
        weapon = clean(data.weapon, 40, 'Firearm'),
        sex = (data.sex == 'Female') and 'Female' or 'Male',
        heading = clean(data.heading, 12, nil),
        vehicle = clean(data.vehicle, 40, nil),
        plate = clean(data.plate, 10, nil),
        color = clean(data.color, 30, nil),
        inVehicle = data.inVehicle == true,
        jacking = data.jacking == true,
        index = data.index,
        speed = data.speed,
    }

    if kind == 'stolen' and not d.vehicle then return end
    if kind == 'speed' and not handleSpeed(src, Player, d, coords) then return end

    local call = BUILD[kind](d)
    call.street = d.street
    call.coords = coords
    call.origin = 'auto'
    MDT.SendDispatchCall('police', call)
end)

AddEventHandler('playerDropped', function()
    local src = source
    for _, t in pairs(cooldowns) do t[src] = nil end
end)

-- ---------------------------------------------------------------------------
-- Panic sound for nearby players (anyone, not only police)
-- ---------------------------------------------------------------------------

function MDT.PlayPanicNearby(coords)
    local radius = tonumber(ACfg.PanicSoundRadius) or 0
    if radius <= 0 or not coords then return end
    local center = vector3(coords.x, coords.y, coords.z)
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local ped = GetPlayerPed(src)
        if ped and ped ~= 0 and #(GetEntityCoords(ped) - center) <= radius then
            TriggerClientEvent('police:client:PanicNearby', src, coords)
        end
    end
end
