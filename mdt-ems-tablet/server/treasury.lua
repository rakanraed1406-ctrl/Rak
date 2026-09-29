--[[ server/treasury.lua - department bank, Command staff only ]]
local QBCore = MDT.QBCore

RegisterNetEvent('ems-mdt:server:DepositMoney', function(amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    amount = tonumber(amount)
    if not MDT.IsSeniorCommand(Player) or not amount or amount <= 0 then return end
    amount = math.floor(amount)

    if Player.Functions.RemoveMoney('bank', amount, 'ems-deposit') then
        MDT.AddSocietyMoney(amount)
        MDT.NotifyAllEms('EMS Command: $' .. amount .. ' has been deposited into the department treasury.', 'success')
        MDT.LogMdtAction(Player, 'Treasury Deposit', '$' .. amount)
        MDT.SendBossData(src)
    else
        TriggerClientEvent('QBCore:Notify', src, 'You do not have enough money in your bank account.', 'error')
    end
end)

RegisterNetEvent('ems-mdt:server:WithdrawMoney', function(amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    amount = tonumber(amount)
    if not MDT.IsSeniorCommand(Player) or not amount or amount <= 0 then return end
    amount = math.floor(amount)

    -- Conditional UPDATE so two withdrawals at the same moment can't overdraw the treasury.
    exports.oxmysql:update(
        'UPDATE ' .. MDT.Tables.Funds .. ' SET amount = amount - ? WHERE job_name = ? AND amount >= ?',
        { amount, Config.JobName, amount },
        function(affected)
            if not affected or affected < 1 then
                TriggerClientEvent('QBCore:Notify', src, 'The department treasury does not hold that much. Current balance: $' .. MDT.GetSocietyMoney(), 'error')
                return
            end
            Player.Functions.AddMoney('bank', amount, 'ems-withdraw')
            MDT.NotifyAllEms('EMS Command: $' .. amount .. ' has been withdrawn from the department treasury.', 'error')
            MDT.LogMdtAction(Player, 'Treasury Withdrawal', '$' .. amount)
            MDT.SendBossData(src)
        end
    )
end)

-- Other resources can pay into / read the EMS treasury.
exports('AddTreasuryMoney', function(amount) MDT.AddSocietyMoney(amount) end)
exports('GetTreasuryMoney', function() return MDT.GetSocietyMoney() end)
