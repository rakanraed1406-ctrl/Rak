--[[ client/bolo.lua - BOLO board callbacks ]]

local QBCore = MDTClient.QBCore

RegisterNUICallback('getBolos', function(_, cb)
    TriggerServerEvent('police:server:GetBolos')
    cb('ok')
end)

RegisterNUICallback('submitBolo', function(data, cb)
    TriggerServerEvent('police:server:SubmitBolo', data)
    cb('ok')
end)

RegisterNUICallback('clearBolo', function(data, cb)
    TriggerServerEvent('police:server:ClearBolo', data.id)
    cb('ok')
end)

RegisterNetEvent('police:client:ReceiveBolos', function(bolos)
    SendNUIMessage({ action = 'receiveBolos', bolos = bolos })
end)

-- ===================================================================
-- Vehicle lookup
-- ===================================================================
