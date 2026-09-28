local QBCore = exports['qb-core']:GetCoreObject()


RegisterNetEvent('qb-police:server:PayMyInvoice', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local MyMeta = Player.PlayerData.metadata['services']
    local MyFines = Player.PlayerData.metadata['policefines']
    if not MyFines then return end 
    if Player.PlayerData.money.bank >= tonumber(MyFines.amount) then
        if Player.Functions.RemoveMoney('bank', tonumber(MyFines.amount), "police fines") then 
            TriggerEvent('qb-bossmenu:server:societyMoney', 'police', tonumber(MyFines.amount))
            if MyMeta then 
                Wait(1000)
                Player.Functions.SetMetaData('services', false)
                TriggerClientEvent('QBCore:Notify', src, 'Your services have been unlocked', 'success', 8000)
            end
            TriggerClientEvent('QBCore:Notify', src, 'You paid your fines with total of $'..tonumber(MyFines.amount)..'', 'success', 8000)
            MyFines.amount = 0
            Player.Functions.SetMetaData('policefines', MyFines)
        end
    end
end)

RegisterNetEvent('qb-police:server:CreateInvoice', function(billed, biller, amount, society)
    local billedID = tonumber(billed)
    local cash = tonumber(amount)
    local billedCID = QBCore.Functions.GetPlayer(billedID)
    local MyMeta = billedCID.PlayerData.metadata['services']
    local MyFines = billedCID.PlayerData.metadata['policefines']

    if MyFines then 
        MyFines.amount += tonumber(amount)
        if tonumber(MyFines.amount) >= 20000 then 
            billedCID.Functions.SetMetaData('services', true)
            TriggerClientEvent('QBCore:Notify', billedCID.PlayerData.source, 'Your services have been stoped pay all your Police Fines to unlock it', 8000)
        end
        Wait(1000)
        TriggerClientEvent('QBCore:Notify', billedCID.PlayerData.source, 'You received a police fine with amount of $'..tonumber(amount)..' <br>total fines is $'..tonumber(MyFines.amount)..'', 'warning', 8000)
        billedCID.Functions.SetMetaData('policefines', MyFines)
    end
end)
