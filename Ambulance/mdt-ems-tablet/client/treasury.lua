--[[ client/treasury.lua - Command staff only, enforced server-side ]]

local QBCore = MDTClient.QBCore

RegisterNUICallback('depositMoney', function(data, cb)
    TriggerServerEvent('ems-mdt:server:DepositMoney', data.amount)
    cb('ok')
end)

RegisterNUICallback('withdrawMoney', function(data, cb)
    TriggerServerEvent('ems-mdt:server:WithdrawMoney', data.amount)
    cb('ok')
end)

