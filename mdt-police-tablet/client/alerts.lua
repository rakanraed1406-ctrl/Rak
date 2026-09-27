--[[ client/alerts.lua — automatic police alerts, detected on the offender's client
     and validated + turned into dispatch calls by server/alerts.lua:
       • Shots fired (weapon name, or vehicle / plate / colour / direction for drive-bys)
       • Vehicle theft / carjacking (vehicle, plate, colour, suspect sex, direction)
       • Speed cameras (optional, fines + a low-priority call)
]]

local ACfg = Config.Alerts
if not ACfg or not ACfg.Enabled then return end

local QBCore = MDTClient.QBCore

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local COLOURS = {}
do
    local names = 'Black|Graphite|Black Steel|Dark Silver|Silver|Blue Silver|Steel Gray|Shadow Silver|Stone Silver|Midnight Silver|' ..
        'Gun Metal|Anthracite Gray|Black|Gray|Light Gray|Black|Black|Dark Silver|Silver|Gun Metal|' ..
        'Shadow Silver|Black|Graphite|Silver Gray|Silver|Blue Silver|Shadow Silver|Red|Torino Red|Formula Red|' ..
        'Blaze Red|Graceful Red|Garnet Red|Desert Red|Cabernet Red|Candy Red|Sunrise Orange|Classic Gold|Orange|Red|' ..
        'Dark Red|Orange|Yellow|Red|Bright Red|Garnet Red|Red|Golden Red|Dark Red|Dark Green|' ..
        'Racing Green|Sea Green|Olive Green|Green|Blue Green|Lime Green|Dark Green|Green|Dark Green|Green|' ..
        'Sea Wash|Midnight Blue|Dark Blue|Saxony Blue|Blue|Mariner Blue|Harbor Blue|Diamond Blue|Surf Blue|Nautical Blue|' ..
        'Bright Blue|Purple Blue|Spinnaker Blue|Ultra Blue|Bright Blue|Dark Blue|Midnight Blue|Blue|Sea Foam Blue|Lightning Blue|' ..
        'Maui Blue|Bright Blue|Dark Blue|Blue|Midnight Blue|Dark Blue|Blue|Light Blue|Taxi Yellow|Race Yellow|' ..
        'Bronze|Yellow|Lime|Champagne|Beige|Dark Ivory|Brown|Golden Brown|Light Brown|Beige|' ..
        'Moss Brown|Brown|Beechwood|Dark Beechwood|Orange|Sand|Sand|Cream|Brown|Brown|' ..
        'Light Brown|White|Frost White|Beige|Brown|Dark Brown|Beige|Steel|Black Steel|Aluminium|' ..
        'Chrome|Off White|Off White|Orange|Light Orange|Green|Taxi Yellow|Blue|Green|Brown|' ..
        'Orange|White|White|Army Green|White|Hot Pink|Pink|Pink|Orange|Green|' ..
        'Blue|Black Blue|Black Purple|Black Red|Hunter Green|Purple|Dark Blue|Black|Purple|Dark Purple|' ..
        'Red|Forest Green|Olive Drab|Desert Brown|Desert Tan|Foliage Green|Alloy|Blue|Gold|Gold'
    local i = 0
    for name in names:gmatch('[^|]+') do COLOURS[i] = name; i = i + 1 end
end

local function cardinal(heading)
    local dirs = { 'North', 'North-West', 'West', 'South-West', 'South', 'South-East', 'East', 'North-East' }
    return dirs[(math.floor((heading + 22.5) / 45.0) % 8) + 1]
end

local function suspectSex(ped)
    local model = GetEntityModel(ped)
    if model == `mp_f_freemode_01` then return 'Female' end
    if model == `mp_m_freemode_01` then return 'Male' end
    return IsPedMale(ped) and 'Male' or 'Female'
end

local function vehicleInfo(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return nil end
    local label = GetLabelText(GetDisplayNameFromVehicleModel(GetEntityModel(veh)))
    if not label or label == 'NULL' then label = GetDisplayNameFromVehicleModel(GetEntityModel(veh)) end
    local primary = GetVehicleColours(veh)
    return {
        vehicle = label,
        plate = (GetVehicleNumberPlateText(veh) or ''):gsub('^%s*(.-)%s*$', '%1'),
        color = COLOURS[primary] or 'Unknown colour',
        heading = cardinal(GetEntityHeading(veh)),
    }
end

-- On-duty police / EMS never trigger alerts.
local function isIgnored()
    local pd = QBCore.Functions.GetPlayerData()
    if not pd or not pd.job then return false end
    for _, job in ipairs(ACfg.IgnoreJobs or {}) do
        if pd.job.name == job and pd.job.onduty then return true end
    end
    return false
end

local function send(kind, data)
    data.street = MDTClient.GetStreetName()
    TriggerServerEvent('police:server:AutoAlert', kind, data)
end

-- ---------------------------------------------------------------------------
-- Shots fired
-- ---------------------------------------------------------------------------

local G = ACfg.Gunshots
if G and G.enabled then
    local function inWhitelistedZone(pos)
        for _, z in ipairs(G.WhitelistedZones or {}) do
            if #(pos - z.coords) <= (z.radius or 20.0) then return true end
        end
        return false
    end

    CreateThread(function()
        local last = -1e9
        while true do
            local ped = PlayerPedId()
            if IsPedArmed(ped, 4) then -- 4 = firearms only
                Wait(0)
                if IsPedShooting(ped) and GetGameTimer() - last > (G.cooldown or 15) * 1000 then
                    local _, hash = GetCurrentPedWeapon(ped, true)
                    local pos = GetEntityCoords(ped)
                    if not (G.WhitelistedWeapons or {})[hash]
                        and not (G.ignoreSilenced ~= false and IsPedCurrentWeaponSilenced(ped))
                        and not inWhitelistedZone(pos)
                        and not isIgnored() then
                        last = GetGameTimer()
                        local data = {
                            weapon = (G.WeaponLabels or {})[hash] or 'Firearm',
                            sex = suspectSex(ped),
                            heading = cardinal(GetEntityHeading(ped)),
                        }
                        if IsPedInAnyVehicle(ped, false) then
                            local v = vehicleInfo(GetVehiclePedIsIn(ped, false))
                            if v then
                                data.inVehicle = true
                                data.vehicle, data.plate, data.color, data.heading = v.vehicle, v.plate, v.color, v.heading
                            end
                        end
                        send('gunshot', data)
                    end
                end
            else
                Wait(500)
            end
        end
    end)
end

-- ---------------------------------------------------------------------------
-- Vehicle theft / carjacking
-- ---------------------------------------------------------------------------

local S = ACfg.StolenCar
if S and S.enabled then
    local function hasKeys(plate)
        if GetResourceState('qb-vehiclekeys') ~= 'started' then return false end
        local ok, result = pcall(function() return exports['qb-vehiclekeys']:HasKeys(plate) end)
        return ok and result == true
    end

    CreateThread(function()
        local last = -1e9
        while true do
            Wait(250)
            local ped = PlayerPedId()
            local jacking = IsPedJacking(ped)
            if (jacking or IsPedTryingToEnterALockedVehicle(ped)) and GetGameTimer() - last > (S.cooldown or 25) * 1000 then
                local veh = GetVehiclePedIsTryingToEnter(ped)
                if not veh or veh == 0 then veh = GetVehiclePedIsIn(ped, false) end
                local v = vehicleInfo(veh)
                -- Unlocking your own car (keys) is not a theft.
                if v and not hasKeys(v.plate) and not isIgnored() then
                    last = GetGameTimer()
                    send('stolen', {
                        jacking = jacking == true,
                        sex = suspectSex(ped),
                        vehicle = v.vehicle, plate = v.plate, color = v.color, heading = v.heading,
                    })
                end
            end
        end
    end)
end

-- ---------------------------------------------------------------------------
-- Speed cameras
-- ---------------------------------------------------------------------------

local T = ACfg.SpeedTrap
if T and T.enabled then
    local mult = (T.unit == 'mph') and 2.236936 or 3.6
    local blips = {}

    if T.blip and T.blip.enabled then
        for _, loc in ipairs(T.Locations or {}) do
            local b = AddBlipForCoord(loc.coords.x, loc.coords.y, loc.coords.z)
            SetBlipSprite(b, T.blip.sprite or 184)
            SetBlipDisplay(b, T.blip.display or 5)
            SetBlipScale(b, T.blip.scale or 0.6)
            SetBlipColour(b, T.blip.color or 1)
            SetBlipAsShortRange(b, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(T.blip.name or 'Speed Camera')
            EndTextCommandSetBlipName(b)
            blips[#blips + 1] = b
        end
    end

    CreateThread(function()
        local last = -1e9
        while true do
            local sleep = 1000
            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, false)
            if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
                local class = GetVehicleClass(veh)
                if class ~= 15 and class ~= 16 and class ~= 18 then -- no helis, planes, emergency
                    sleep = 200
                    local pos = GetEntityCoords(ped)
                    for i, loc in ipairs(T.Locations or {}) do
                        if #(pos - loc.coords) <= (loc.radius or 10.0) then
                            local speed = math.floor(GetEntitySpeed(veh) * mult)
                            if speed > (loc.limit or 100) and GetGameTimer() - last > (T.cooldown or 10) * 1000 and not isIgnored() then
                                last = GetGameTimer()
                                local v = vehicleInfo(veh)
                                send('speed', {
                                    index = i, speed = speed,
                                    vehicle = v.vehicle, plate = v.plate, color = v.color, heading = v.heading,
                                })
                                PlaySoundFrontend(-1, 'Camera_Shoot', 'Phone_Soundset_Franklin', true)
                            end
                        end
                    end
                end
            end
            Wait(sleep)
        end
    end)

    AddEventHandler('onResourceStop', function(res)
        if res ~= GetCurrentResourceName() then return end
        for _, b in ipairs(blips) do RemoveBlip(b) end
    end)
end

-- ---------------------------------------------------------------------------
-- Panic sound for people standing nearby
-- ---------------------------------------------------------------------------

RegisterNetEvent('police:client:PanicNearby', function(coords)
    if type(coords) ~= 'table' then return end
    for _ = 1, 3 do
        PlaySoundFromCoord(-1, 'TIMER_STOP', coords.x, coords.y, coords.z, 'HUD_MINI_GAME_SOUNDSET', false, ACfg.PanicSoundRadius or 40.0, false)
        Wait(350)
    end
end)
