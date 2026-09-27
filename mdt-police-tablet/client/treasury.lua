--[[ client/treasury.lua - Command staff only, enforced server-side ]]

local QBCore = MDTClient.QBCore

RegisterNUICallback('depositMoney', function(data, cb)
    TriggerServerEvent('police:server:DepositMoney', data.amount)
    cb('ok')
end)

RegisterNUICallback('withdrawMoney', function(data, cb)
    TriggerServerEvent('police:server:WithdrawMoney', data.amount)
    cb('ok')
end)

-- ===================================================================
-- Personnel management
-- ===================================================================

--- Finds the nearest other player ped within Config.HireDistance and returns
--- their server id, or nil if nobody is close enough. The server independently
--- re-validates the distance, so this is purely for UX — not a trust boundary.
