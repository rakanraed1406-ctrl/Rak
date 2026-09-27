--[[ client/reports.lua - Reports app callbacks ]]

local QBCore = MDTClient.QBCore

RegisterNUICallback('getReports', function(_, cb)
    TriggerServerEvent('police:server:GetReports')
    cb('ok')
end)

RegisterNUICallback('submitReport', function(data, cb)
    TriggerServerEvent('police:server:SubmitReport', data)
    cb('ok')
end)

RegisterNUICallback('deleteReport', function(data, cb)
    TriggerServerEvent('police:server:DeleteReport', data.id)
    cb('ok')
end)

RegisterNetEvent('police:client:ReceiveReports', function(reports)
    SendNUIMessage({ action = 'receiveReports', reports = reports })
end)

-- ===================================================================
-- Directives / Circulars app
-- ===================================================================
