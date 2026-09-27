--[[ server/treasury.lua - department bank, Command staff only ]]
local QBCore = MDT.QBCore

RegisterNetEvent('police:server:DepositMoney', function(amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    amount = tonumber(amount)

    if not MDT.IsSeniorCommand(Player) or not amount or amount <= 0 then return end
    amount = math.floor(amount)

    if Player.Functions.RemoveMoney('bank', amount, 'police-deposit') then
        exports.oxmysql:execute('UPDATE police_funds SET amount = amount + ? WHERE job_name = ?', { amount, Config.JobName })
        MDT.NotifyAllPolice('Police HQ: $' .. amount .. ' has been deposited into the department treasury.', 'success')
        MDT.LogMdtAction(Player, 'Treasury Deposit', '$' .. amount)
        MDT.SendBossData(src)
    else
        TriggerClientEvent('QBCore:Notify', src, 'You do not have enough money in your bank account.', 'error')
    end
end)

RegisterNetEvent('police:server:WithdrawMoney', function(amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    amount = tonumber(amount)

    if not MDT.IsSeniorCommand(Player) or not amount or amount <= 0 then return end
    amount = math.floor(amount)

    local currentMoney = MDT.GetSocietyMoney(Config.JobName)
    if currentMoney < amount then
        TriggerClientEvent('QBCore:Notify', src, 'The department treasury does not hold that much. Current balance: $' .. currentMoney, 'error')
        return
    end

    exports.oxmysql:execute('UPDATE police_funds SET amount = amount - ? WHERE job_name = ?', { amount, Config.JobName })
    Player.Functions.AddMoney('bank', amount, 'police-withdraw')
    MDT.NotifyAllPolice('Police HQ: $' .. amount .. ' has been withdrawn from the department treasury.', 'error')
    MDT.LogMdtAction(Player, 'Treasury Withdrawal', '$' .. amount)
    MDT.SendBossData(src)
end)

-- ===================================================================
-- Recruitment applications (Command staff review — grade 9+ only)
-- ===================================================================
