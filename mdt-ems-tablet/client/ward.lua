--[[ client/ward.lua - Ward board callbacks ]]

RegisterNUICallback('getWard', function(_, cb)
    TriggerServerEvent('ems-mdt:server:GetWard')
    cb('ok')
end)

RegisterNUICallback('admitPatient', function(data, cb)
    TriggerServerEvent('ems-mdt:server:AdmitPatient', data)
    cb('ok')
end)

RegisterNUICallback('updateWardSeverity', function(data, cb)
    TriggerServerEvent('ems-mdt:server:UpdateWardSeverity', data.id, data.severity)
    cb('ok')
end)

RegisterNUICallback('dischargePatient', function(data, cb)
    TriggerServerEvent('ems-mdt:server:DischargePatient', data.id)
    cb('ok')
end)

RegisterNetEvent('ems-mdt:client:ReceiveWard', function(entries)
    SendNUIMessage({ action = 'receiveWard', entries = entries })
end)
