local QBCore = MDTClient.QBCore

RegisterNUICallback('sendAlertMessage', function(data, cb)
    TriggerServerEvent('police:server:BroadcastEmergencyAlert', data.message)
    cb('ok')
end)

RegisterNUICallback('setAlertLevel', function(data, cb)
    TriggerServerEvent('police:server:SetAlertLevel', data.level)
    cb('ok')
end)

RegisterNUICallback('sendUnitsAlert', function(data, cb)
    TriggerServerEvent('police:server:SendUnitsAlert', data.message)
    cb('ok')
end)

RegisterNetEvent('police:client:AlertLevelChanged', function(level)
    SendNUIMessage({ action = 'alertLevelChanged', level = level })
end)

RegisterNUICallback('openRadio', function(_, cb)
    local resourceName = Config.RadioResource
    if not resourceName or resourceName == '' or GetResourceState(resourceName) ~= 'started' then
        QBCore.Functions.Notify('No radio script is configured (Config.RadioResource).', 'error')
        cb('ok')
        return
    end
    ExecuteCommand(Config.RadioOpenCommand or 'radio')
    cb('ok')
end)
