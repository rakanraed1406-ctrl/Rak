--[[ client/directives.lua - Directives app callbacks ]]

local QBCore = MDTClient.QBCore

RegisterNUICallback('getDirectives', function(_, cb)
    TriggerServerEvent('police:server:GetDirectives')
    cb('ok')
end)

RegisterNUICallback('postDirective', function(data, cb)
    TriggerServerEvent('police:server:PostDirective', data)
    cb('ok')
end)

RegisterNUICallback('deleteDirective', function(data, cb)
    TriggerServerEvent('police:server:DeleteDirective', data.id)
    cb('ok')
end)

RegisterNetEvent('police:client:ReceiveDirectives', function(directives)
    SendNUIMessage({ action = 'receiveDirectives', directives = directives })
end)

-- ===================================================================
-- Department broadcast / alert level
-- ===================================================================
