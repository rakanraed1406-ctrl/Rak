--[[
    server/alerts.lua — EMS alerts that are not typed by a person:
      • qb-hospital: "Civilian down — bleeding out" / "No pulse" (the patient presses G),
        and "Patient waiting at check-in" — with the patient's injuries as tags.
        (this replaces the cd_dispatch notification qb-hospital used to send)
      • Traffic collisions detected on the driver's client (client/alerts.lua)
      • Panic sound for players standing near a medic who pressed panic

    qb-hospital (or any script) calls, on the SERVER:
        TriggerEvent('ems-mdt:server:HospitalAlert', patientSource, 'down' | 'dead' | 'checkin', info)
        TriggerEvent('ems-mdt:server:PatientRecovered', patientSource, 'revived' | 'respawned')
    info = { bleeding = 'bleeding a lot...', injuries = { 'Head', 'Left Leg' }, cause = 'Pistol' } (all optional)
]]

local QBCore = MDT.QBCore
local ACfg = Config.Alerts or {}
local D = MDT.Dispatch

local cooldowns = { down = {}, dead = {}, checkin = {}, crash = {} }
local KIND_COOLDOWN = { down = 30, dead = 30, checkin = 45 }

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

local function sexOf(Player)
    local g = Player.PlayerData.charinfo and tonumber(Player.PlayerData.charinfo.gender)
    return g == 1 and 'Female' or 'Male'
end

-- ---------------------------------------------------------------------------
-- qb-hospital alerts
-- ---------------------------------------------------------------------------

local HOSPITAL_KINDS = {
    down = { code = '10-47', title = 'Civilian Down — Bleeding Out', icon = 'fa-user-injured',
             text = '%s is down and bleeding out on %s. First aid needed before the timer runs out.' },
    dead = { code = '10-69', title = 'Civilian Down — No Pulse', icon = 'fa-heart-pulse',
             text = '%s is unconscious with no pulse on %s. Bring a defibrillator.' },
    checkin = { code = 'CHECK-IN', title = 'Patient Waiting — Hospital Check-in', icon = 'fa-hospital-user',
             text = '%s is waiting at the hospital check-in desk (%s) and needs a doctor.' },
}

local function HospitalAlert(src, kind, info)
    src = tonumber(src)
    local K = HOSPITAL_KINDS[kind]
    if not src or not K then return nil end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return nil end

    local now = os.time()
    local last = cooldowns[kind][src]
    if last and now - last < KIND_COOLDOWN[kind] then return nil end
    cooldowns[kind][src] = now

    local coords = MDT.PedCoords(src)
    info = type(info) == 'table' and info or {}
    local street = clean(info.street, 80, nil)
    local name = MDT.GetName(Player)

    local tags = {
        { icon = 'fa-user', label = name .. ' · ID ' .. src },
        { icon = 'fa-venus-mars', label = sexOf(Player) },
    }
    local blood = Player.PlayerData.metadata and Player.PlayerData.metadata.bloodtype
    if blood then tags[#tags + 1] = { icon = 'fa-droplet', label = 'Blood ' .. clean(blood, 4, '?') } end
    local bleeding = clean(info.bleeding, 40, nil)
    if bleeding then tags[#tags + 1] = { icon = 'fa-droplet', label = bleeding, danger = true } end
    local cause = clean(info.cause, 40, nil)
    if cause then tags[#tags + 1] = { icon = 'fa-crosshairs', label = 'Cause: ' .. cause, danger = true } end
    if type(info.injuries) == 'table' then
        local list = {}
        for i, part in ipairs(info.injuries) do
            if i > 4 then break end
            list[#list + 1] = clean(part, 24, nil)
        end
        if #list > 0 then tags[#tags + 1] = { icon = 'fa-bone', label = table.concat(list, ', ') } end
    end

    local callId = D.Create({
        code = K.code, title = K.title,
        description = K.text:format(name, street or 'their location'),
        street = street, coords = coords, origin = 'hospital', tags = tags,
        patientSource = src,
    }, 'ambulance')
    return callId
end

exports('HospitalAlert', HospitalAlert)
AddEventHandler('ems-mdt:server:HospitalAlert', function(src, kind, info) HospitalAlert(src, kind, info) end)

--- Patient got back up (revived by a medic / respawned at the hospital / left):
--- their open "civilian down" calls turn CONTAINED with a note, so units know.
local function PatientRecovered(src, reason)
    src = tonumber(src)
    if not src then return end
    local label = ({ revived = 'Patient revived', respawned = 'Patient respawned at hospital', left = 'Patient left the city' })[reason] or 'Patient recovered'
    local changed = false
    for _, call in pairs(D.calls) do
        if call.patientSource == src and call.status ~= 'contained' then
            call.status = 'contained'
            call.patientSource = nil
            if #call.tags < 8 then call.tags[#call.tags + 1] = { icon = 'fa-circle-check', label = label } end
            call.updatedAt = os.time()
            changed = true
        end
    end
    if changed then D.Broadcast() end
    for _, t in pairs(cooldowns) do t[src] = nil end
end

exports('PatientRecovered', PatientRecovered)
AddEventHandler('ems-mdt:server:PatientRecovered', function(src, reason) PatientRecovered(src, reason) end)

-- ---------------------------------------------------------------------------
-- Traffic collisions (client/alerts.lua)
-- ---------------------------------------------------------------------------

RegisterNetEvent('ems-mdt:server:AutoAlert', function(kind, data)
    local src = source
    if not ACfg.Enabled or kind ~= 'crash' or type(data) ~= 'table' then return end
    local C = ACfg.Crash
    if not C or not C.enabled then return end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or isIgnored(Player) then return end

    local now = os.time()
    local cd = math.max(tonumber(C.cooldown) or 60, 10)
    if cooldowns.crash[src] and now - cooldowns.crash[src] < cd then return end
    cooldowns.crash[src] = now

    local speed = math.floor(tonumber(data.speed) or 0)
    if speed < (C.minSpeed or 90) or speed > 700 then return end

    local street = clean(data.street, 80, 'Unknown location')
    local vehicle = clean(data.vehicle, 40, 'Vehicle')
    local color = clean(data.color, 30, nil)
    local occupants = math.max(1, math.min(16, math.floor(tonumber(data.occupants) or 1)))

    local tags = {
        { icon = 'fa-car-burst', label = (color and (color .. ' ') or '') .. vehicle },
        { icon = 'fa-gauge-high', label = ('~%d km/h impact'):format(speed) },
        { icon = 'fa-people-group', label = occupants .. ' occupant(s)' },
    }
    if data.plate then tags[#tags + 1] = { icon = 'fa-id-card', label = clean(data.plate, 10, '?') } end
    if data.rolled then tags[#tags + 1] = { icon = 'fa-triangle-exclamation', label = 'Vehicle overturned', danger = true } end

    MDT.SendDispatchCall('ambulance', {
        code = '10-50', title = data.rolled and 'Rollover Collision — Injuries Likely' or 'Traffic Collision — Possible Injuries',
        description = ('High-speed collision involving a %s%s on %s (%d occupant%s).'):format(color and (color .. ' ') or '', vehicle, street, occupants, occupants == 1 and '' or 's'),
        street = street, coords = MDT.PedCoords(src), origin = 'auto', tags = tags,
        priority = data.rolled and 'high' or 'medium',
    })
end)

AddEventHandler('playerDropped', function()
    local src = source
    PatientRecovered(src, 'left')
    for _, t in pairs(cooldowns) do t[src] = nil end
end)

-- ---------------------------------------------------------------------------
-- Panic sound for nearby players (anyone, not only EMS)
-- ---------------------------------------------------------------------------

function MDT.PlayPanicNearby(coords)
    local radius = tonumber(ACfg.PanicSoundRadius) or 0
    if radius <= 0 or not coords then return end
    local center = vector3(coords.x, coords.y, coords.z)
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local ped = GetPlayerPed(src)
        if ped and ped ~= 0 and #(GetEntityCoords(ped) - center) <= radius then
            TriggerClientEvent('ems-mdt:client:PanicNearby', src, coords)
        end
    end
end
