--[[ client/map.lua - officer feed, calibration, bodycam trigger (markers appended by hand) ]]

local QBCore = MDTClient.QBCore

function MDTClient.StopMapSubscription()
    MDTClient.mapSubscribed = false
end

RegisterNUICallback('mapSubscribe', function(_, cb)
    if not MDTClient.mapSubscribed then
        MDTClient.mapSubscribed = true
        CreateThread(function()
            while MDTClient.mapSubscribed do
                TriggerServerEvent('police:server:RequestMapOfficers')
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

RegisterNetEvent('police:client:UpdateMapOfficers', function(officers)
    if not MDTClient.mapSubscribed then return end -- ignore stale responses after leaving the Map app
    SendNUIMessage({ action = 'mapOfficers', officers = officers })
end)

-- Setup helper (Boss only, server-checked) — logs your exact coords to the
-- server console to help calibrate Config.MapWorldBounds. Not meant for
-- day-to-day use, just installation/tuning.
RegisterCommand('mdtmapcalibrate', function()
    local coords = GetEntityCoords(PlayerPedId())
    TriggerServerEvent('police:server:LogMapCalibration', { x = coords.x, y = coords.y, z = coords.z })
end, false)

RegisterNUICallback('viewBodycam', function(data, cb)
    TriggerServerEvent('police:server:RequestBodycam', data.serverId)
    cb('ok')
end)

-- ===================================================================
-- BOLO board
-- ===================================================================

RegisterNUICallback('mapAddMarker', function(data, cb)
    TriggerServerEvent('police:server:AddMapMarker', data)
    cb('ok')
end)

RegisterNUICallback('mapClearMarker', function(data, cb)
    TriggerServerEvent('police:server:ClearMapMarker', data.id)
    cb('ok')
end)

RegisterNUICallback('mapClearAllMarkers', function(_, cb)
    TriggerServerEvent('police:server:ClearAllMapMarkers')
    cb('ok')
end)

RegisterNetEvent('police:client:MapMarkersUpdated', function(markers)
    if not MDTClient.mapSubscribed then return end
    SendNUIMessage({ action = 'mapMarkers', markers = markers })
end)
