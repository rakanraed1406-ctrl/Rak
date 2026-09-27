--[[ client/vehicles.lua - plate lookup callback ]]

local QBCore = MDTClient.QBCore

RegisterNUICallback('lookupPlate', function(data, cb)
    TriggerServerEvent('police:server:LookupPlate', data.plate)
    cb('ok')
end)

RegisterNetEvent('police:client:ReceivePlateLookup', function(plate, result)
    SendNUIMessage({ action = 'plateLookupResult', plate = plate, result = result })
end)
