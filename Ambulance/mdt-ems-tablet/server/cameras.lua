--[[ server/cameras.lua - hospital CCTV. The client only asks; the server decides. ]]

local QBCore = MDT.QBCore

RegisterNetEvent('ems-mdt:server:LogCameraView', function(camIndex)
    local Player = QBCore.Functions.GetPlayer(source)
    if not MDT.IsBoss(Player) then return end
    MDT.LogMdtAction(Player, 'Viewed CCTV Feed', 'Camera #' .. tostring(camIndex))
end)

RegisterNetEvent('ems-mdt:server:RequestCameraAccess', function(camIndex)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsBoss(Player) then
        TriggerClientEvent('QBCore:Notify', src, 'Boss access required to view CCTV feeds.', 'error')
        return
    end

    camIndex = tonumber(camIndex)
    if not camIndex or not Config.Cameras[camIndex] then return end

    TriggerClientEvent('ems-mdt:client:CameraAccessGranted', src, camIndex)
end)
