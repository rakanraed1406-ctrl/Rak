--[[ client/alerts.lua — automatic EMS alerts detected on the player's client and
     validated + turned into dispatch calls by server/alerts.lua:
       • High-speed traffic collisions (vehicle, colour, plate, occupants, rollover)
     (Civilian down / no pulse alerts come from qb-hospital — see server/alerts.lua)
]]

local ACfg = Config.Alerts or {}

-- Panic sound for people standing near a medic who pressed panic (always on).
RegisterNetEvent('ems-mdt:client:PanicNearby', function(coords)
    if type(coords) ~= 'table' then return end
    for _ = 1, 3 do
        PlaySoundFromCoord(-1, 'TIMER_STOP', coords.x, coords.y, coords.z, 'HUD_MINI_GAME_SOUNDSET', false, ACfg.PanicSoundRadius or 40.0, false)
        Wait(350)
    end
end)

if not ACfg.Enabled then return end

local QBCore = MDTClient.QBCore

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

-- On-duty EMS / police never trigger automatic alerts.
local function isIgnored()
    local pd = QBCore.Functions.GetPlayerData()
    if not pd or not pd.job then return false end
    for _, job in ipairs(ACfg.IgnoreJobs or {}) do
        if pd.job.name == job and pd.job.onduty then return true end
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Traffic collisions
-- ---------------------------------------------------------------------------

local C = ACfg.Crash
if C and C.enabled then
    local SKIP_CLASS = { [13] = true, [14] = true, [15] = true, [16] = true, [21] = true } -- bikes, boats, helis, planes, trains

    CreateThread(function()
        local lastSpeed, lastBody, lastVeh = 0.0, 1000.0, 0
        local lastAlertAt = -1e9
        while true do
            local sleep = 1000
            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, false)
            if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped and not SKIP_CLASS[GetVehicleClass(veh)] then
                sleep = 100
                local speed = GetEntitySpeed(veh) * 3.6
                local body = GetVehicleBodyHealth(veh)
                if veh == lastVeh
                    and lastSpeed >= (C.minSpeed or 90)
                    and (lastSpeed - speed) >= (C.minDrop or 60)
                    and (lastBody - body) >= (C.minBodyDamage or 60.0)
                    and GetGameTimer() - lastAlertAt > (C.cooldown or 60) * 1000
                    and not isIgnored() then
                    lastAlertAt = GetGameTimer()
                    local impactSpeed = math.floor(lastSpeed)
                    local crashedVeh = veh
                    CreateThread(function()
                        Wait(1500) -- let the car settle so a rollover can be detected
                        if not DoesEntityExist(crashedVeh) then return end
                        local model = GetEntityModel(crashedVeh)
                        local label = GetLabelText(GetDisplayNameFromVehicleModel(model))
                        if not label or label == 'NULL' then label = GetDisplayNameFromVehicleModel(model) end
                        local primary = GetVehicleColours(crashedVeh)
                        local roll = math.abs(GetEntityRoll(crashedVeh))
                        TriggerServerEvent('ems-mdt:server:AutoAlert', 'crash', {
                            speed = impactSpeed,
                            vehicle = label,
                            color = COLOURS[primary],
                            plate = (GetVehicleNumberPlateText(crashedVeh) or ''):gsub('^%s*(.-)%s*$', '%1'),
                            occupants = GetVehicleNumberOfPassengers(crashedVeh) + (IsVehicleSeatFree(crashedVeh, -1) and 0 or 1),
                            rolled = IsEntityUpsidedown(crashedVeh) or roll > 75.0,
                            street = MDTClient.GetStreetName(GetEntityCoords(crashedVeh)),
                        })
                    end)
                end
                lastSpeed, lastBody, lastVeh = speed, body, veh
            else
                lastSpeed, lastBody, lastVeh = 0.0, 1000.0, 0
            end
            Wait(sleep)
        end
    end)
end
