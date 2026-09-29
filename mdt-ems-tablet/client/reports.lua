--[[ client/reports.lua - Medical reports app callbacks ]]

local QBCore = MDTClient.QBCore

RegisterNUICallback('getReports', function(_, cb)
    TriggerServerEvent('ems-mdt:server:GetReports')
    cb('ok')
end)

RegisterNUICallback('submitReport', function(data, cb)
    TriggerServerEvent('ems-mdt:server:SubmitReport', data)
    cb('ok')
end)

RegisterNUICallback('deleteReport', function(data, cb)
    TriggerServerEvent('ems-mdt:server:DeleteReport', data.id)
    cb('ok')
end)

RegisterNetEvent('ems-mdt:client:ReceiveReports', function(reports)
    SendNUIMessage({ action = 'receiveReports', reports = reports })
end)

