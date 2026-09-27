--[[ server/cameras.lua - CCTV access. Requires a server round trip before rendering anything. ]]

local QBCore = MDT.QBCore

RegisterNetEvent('police:server:LogCameraView', function(camIndex)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsBoss(Player) then return end
    MDT.LogMdtAction(Player, 'Viewed CCTV Feed', 'Camera #' .. tostring(camIndex))
end)

--- SECURITY FIX (kept from the original patch): camera viewing used to be
--- triggered straight from the client with zero server authorization. Now
--- the client only ever *asks*; this event decides, and only then does the
--- client render anything.
RegisterNetEvent('police:server:RequestCameraAccess', function(camIndex)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsBoss(Player) then
        TriggerClientEvent('QBCore:Notify', src, 'Boss access required to view CCTV feeds.', 'error')
        return
    end

    camIndex = tonumber(camIndex)
    if not camIndex or not Config.Cameras[camIndex] then return end

    TriggerClientEvent('police:client:CameraAccessGranted', src, camIndex)
end)
