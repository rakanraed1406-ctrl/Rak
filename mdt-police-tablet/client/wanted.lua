RegisterNUICallback('getWanted', function(_, cb)
    TriggerServerEvent('police:server:GetWanted')
    cb('ok')
end)

RegisterNUICallback('addWanted', function(data, cb)
    TriggerServerEvent('police:server:AddWanted', data)
    cb('ok')
end)

RegisterNUICallback('removeWanted', function(data, cb)
    TriggerServerEvent('police:server:RemoveWanted', data.id)
    cb('ok')
end)

RegisterNetEvent('police:client:ReceiveWanted', function(wanted)
    SendNUIMessage({ action = 'receiveWanted', wanted = wanted })
end)
