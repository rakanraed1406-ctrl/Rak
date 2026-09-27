RegisterNUICallback('getCitations', function(_, cb)
    TriggerServerEvent('police:server:GetCitations')
    cb('ok')
end)

RegisterNUICallback('issueCitation', function(data, cb)
    TriggerServerEvent('police:server:IssueCitation', data)
    cb('ok')
end)

RegisterNUICallback('deleteCitation', function(data, cb)
    TriggerServerEvent('police:server:DeleteCitation', data.id)
    cb('ok')
end)

RegisterNetEvent('police:client:ReceiveCitations', function(citations)
    SendNUIMessage({ action = 'receiveCitations', citations = citations })
end)
