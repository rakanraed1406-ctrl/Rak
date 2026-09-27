local QBCore = exports["qb-core"]:GetCoreObject()


RegisterNetEvent('qb-shops:sv:pay')
AddEventHandler('qb-shops:sv:pay', function(data)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)

    if data.payType == "cash" then
        
        if xPlayer.PlayerData.money['cash'] >= data.price then
                xPlayer.Functions.RemoveMoney('cash', data.price)
--[[                 AC.Success() ]]
                for k,v in pairs(data.cartArr) do
                    if v.itemname == "lockpick" then 
                        local info = {
                            uses = math.random(3, 5)
                        }
                        xPlayer.Functions.AddItem('lockpick', tonumber(v.count), false, info)
                    elseif v.itemname == "ciggypack" then 
                        local info = {
                            uses = 18
                        }
                        xPlayer.Functions.AddItem('ciggypack', tonumber(v.count), false, info)
                   else
                    xPlayer.Functions.AddItem(v.itemname, tonumber(v.count))
                   end
                end
            else
                TriggerClientEvent('QBCore:Notify', src, "You don't have enough cash", 'error', 4000)
            end
        else        
            if xPlayer.PlayerData.money['bank'] >= data.price then
                xPlayer.Functions.RemoveMoney('bank', data.price)
--[[                 AC.Success() ]]
                for k,v in pairs(data.cartArr) do
                    if v.itemname == "lockpick" then 
                        local info = {
                            uses = math.random(3, 5)
                        }
                        xPlayer.Functions.AddItem('lockpick', tonumber(v.count), false, info)
                    elseif v.itemname == "ciggypack" then 
                        local info = {
                            uses = 18
                        }
                        xPlayer.Functions.AddItem('ciggypack', tonumber(v.count), false, info)
                   else
                    xPlayer.Functions.AddItem(v.itemname, tonumber(v.count))
                   end
                end
            else
                TriggerClientEvent('QBCore:Notify', src, "You don't have enought bank", 'error', 4000)
            end
        end
end)


RegisterNetEvent('qb-shops:server:UpdateShopItems', function(shop, itemData, amount)
    if not shop or not itemData or not amount then return end

    Config.Locations[shop]["products"][itemData.slot].amount -= amount
    if Config.Locations[shop]["products"][itemData.slot].amount < 0 then
        Config.Locations[shop]["products"][itemData.slot].amount = 0
    end

    if Config.Locations[shop] and Config.Locations[shop].canrob then 
        Config.Locations[shop].currentcash += amount * Config.Locations[shop]["products"][itemData.slot].price
    end

    TriggerClientEvent('qb-shops:client:SetShopItems', -1, shop, Config.Locations[shop]["products"])
end)
local QBCore = exports['qb-core']:GetCoreObject()

local QBCore = exports['qb-core']:GetCoreObject()

RegisterNetEvent('qb-shops:server:SetShopList', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end

    if currentShop and Config.Locations[currentShop] and Config.Locations[currentShop].requiredJob then
        local hasJob = false
        for jobName, _ in pairs(Config.Locations[currentShop].requiredJob) do
            if Player.PlayerData.job.name == jobName then
                hasJob = true
                break
            end
        end
        
        if not hasJob then
            TriggerClientEvent('QBCore:Notify', src, "This shop is restricted to police officers only!", "error")
            return
        end
    end
end)
