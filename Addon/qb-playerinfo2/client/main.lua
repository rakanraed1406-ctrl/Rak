local QBCore = exports['qb-core']:GetCoreObject()

PlayerData = QBCore.Functions.GetPlayerData()
local isUiOpened = false

RegisterNetEvent('mainplayerinfo', function()
    if not isUiOpened then
        if not PlayerData then return end 
        isUiOpened = true
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = "open",
            PlayerData = QBCore.Functions.GetPlayerData()
        })
    end
end) 

RegisterNUICallback('SetLocation', function(data, cb)
    if not data then return end 
    if not data.location then return end 
    if Config.JobCenter[data.location] then 
        SetNewWaypoint(Config.JobCenter[data.location].Coords[1], Config.JobCenter[data.location].Coords[2])
        QBCore.Functions.Notify('GPS set to '..Config.JobCenter[data.location].label..'', "success")
    end
end)

RegisterNUICallback('close', function()
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = "close",
    })
    isUiOpened = false
end)
