local QBCore = exports['qb-core']:GetCoreObject()

PlayerData = {}

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData()
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    PlayerData = {}
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    PlayerData.job = JobInfo
end)


Citizen.CreateThread(function()
    local Blip = AddBlipForCoord(1162.8116455078,-1347.2601318359,36.188400268555)
    SetBlipSprite(Blip, 79)
    SetBlipDisplay(Blip, 4)
    SetBlipScale(Blip, 0.5)
    SetBlipAsShortRange(Blip, true)
    SetBlipColour(Blip, 47)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName('Tools Factory')
    EndTextCommandSetBlipName(Blip)
end)

RegisterNetEvent('qb-toolsfactory:client:openmenu', function()
    if GetClockHours() >= 6 and GetClockHours() <= 21 then
        QBCore.Functions.TriggerCallback('qb-toolsfactory:server:getconfig', function(ItemsData)
            if ItemsData then 
                local ShopItems = {}
                ShopItems.items = ItemsData
                ShopItems.shop = 'toolsfactory'
                ShopItems.label = 'Shop'
                TriggerServerEvent("inventory:server:OpenInventory", "shop", ShopItems.shop, ShopItems)
            end
        end)
    else
        QBCore.Functions.Notify("We are closed! <br>Our working hours is from 6AM to 10PM", "error", 8000)
    end
end)
