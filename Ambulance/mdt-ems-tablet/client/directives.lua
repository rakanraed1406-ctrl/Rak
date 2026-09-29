--[[ client/directives.lua - Directives app callbacks ]]

local QBCore = MDTClient.QBCore

RegisterNUICallback('getDirectives', function(_, cb)
    TriggerServerEvent('ems-mdt:server:GetDirectives')
    cb('ok')
end)

RegisterNUICallback('postDirective', function(data, cb)
    TriggerServerEvent('ems-mdt:server:PostDirective', data)
    cb('ok')
end)

RegisterNUICallback('deleteDirective', function(data, cb)
    TriggerServerEvent('ems-mdt:server:DeleteDirective', data.id)
    cb('ok')
end)

RegisterNetEvent('ems-mdt:client:ReceiveDirectives', function(directives)
    SendNUIMessage({ action = 'receiveDirectives', directives = directives })
end)

