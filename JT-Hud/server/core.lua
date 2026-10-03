
local QBCore = exports['qb-core']:GetCoreObject()

-- ════════════════════════════════════════════════════════════
--              SERVER CALLBACK HANDLER
-- ════════════════════════════════════════════════════════════

RegisterNetEvent("qb-hud:Server:HandleCallback", function(key, payload)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        TriggerClientEvent("qb-hud:Client:HandleCallback", src, key, nil)
        return
    end

    if key == "qb-hud:Server:GetHudSettings" then
        -- Retrieve HUD settings from player metadata
        local hudSettings = Player.PlayerData.metadata["hudsettings"] or {}
        TriggerClientEvent("qb-hud:Client:HandleCallback", src, key, hudSettings)
    else
        -- If any other server callback is triggered
        TriggerClientEvent("qb-hud:Client:HandleCallback", src, key, nil)
    end
end)
