--[[ client/billing.lua - Medical bills callbacks ]]

RegisterNUICallback('getBills', function(_, cb)
    TriggerServerEvent('ems-mdt:server:GetBills')
    cb('ok')
end)

RegisterNUICallback('issueBill', function(data, cb)
    TriggerServerEvent('ems-mdt:server:IssueBill', data)
    cb('ok')
end)

RegisterNUICallback('voidBill', function(data, cb)
    TriggerServerEvent('ems-mdt:server:VoidBill', data.id)
    cb('ok')
end)

RegisterNetEvent('ems-mdt:client:ReceiveBills', function(bills)
    SendNUIMessage({ action = 'receiveBills', bills = bills })
end)
