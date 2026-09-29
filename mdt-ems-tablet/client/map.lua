--[[ client/map.lua - live medic feed, calibration helper, shared map pins ]]

local QBCore = MDTClient.QBCore

function MDTClient.StopMapSubscription()
    MDTClient.mapSubscribed = false
end

RegisterNUICallback('mapSubscribe', function(_, cb)
    if not MDTClient.mapSubscribed then
        MDTClient.mapSubscribed = true
        CreateThread(function()
            while MDTClient.mapSubscribed do
                TriggerServerEvent('ems-mdt:server:RequestMapOfficers')
                Wait(Config.GPSRefreshInterval)
            end
        end)
    end
    cb('ok')
end)

RegisterNUICallback('mapUnsubscribe', function(_, cb)
    MDTClient.StopMapSubscription()
    cb('ok')
end)

RegisterNetEvent('ems-mdt:client:UpdateMapOfficers', function(officers)
    if not MDTClient.mapSubscribed then return end -- ignore stale responses after leaving the Map app
    SendNUIMessage({ action = 'mapOfficers', officers = officers })
end)

-- Setup helper (Boss only, server-checked) — logs your exact coords to the
-- server console (map calibration / placing hospital cameras).
RegisterCommand('emdtmapcalibrate', function()
    local coords = GetEntityCoords(PlayerPedId())
    TriggerServerEvent('ems-mdt:server:LogMapCalibration', { x = coords.x, y = coords.y, z = coords.z })
end, false)

RegisterNUICallback('mapAddMarker', function(data, cb)
    TriggerServerEvent('ems-mdt:server:AddMapMarker', data)
    cb('ok')
end)

RegisterNUICallback('mapClearMarker', function(data, cb)
    TriggerServerEvent('ems-mdt:server:ClearMapMarker', data.id)
    cb('ok')
end)

RegisterNUICallback('mapClearAllMarkers', function(_, cb)
    TriggerServerEvent('ems-mdt:server:ClearAllMapMarkers')
    cb('ok')
end)

RegisterNetEvent('ems-mdt:client:MapMarkersUpdated', function(markers)
    if not MDTClient.mapSubscribed then return end
    SendNUIMessage({ action = 'mapMarkers', markers = markers })
end)
