--[[ server/bodycam.lua - wired directly to qb-bodycam (! TMX). See comments for how/why. ]]
local QBCore = MDT.QBCore

local function HandleBodycamRequest(src, targetServerId)
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsSeniorCommand(Player) then return end

    targetServerId = tonumber(targetServerId)
    if not targetServerId or not GetPlayerName(targetServerId) then
        TriggerClientEvent('QBCore:Notify', src, 'That officer is no longer online.', 'error')
        return
    end

    if targetServerId == src then
        TriggerClientEvent('QBCore:Notify', src, 'You cannot watch your own bodycam feed from the map.', 'error')
        return
    end

    local resourceName = Config.BodycamResource
    if not resourceName or resourceName == '' or GetResourceState(resourceName) ~= 'started' then
        TriggerClientEvent('QBCore:Notify', src,
            'Bodycam script (' .. tostring(resourceName) .. ') is not installed/started on this server.',
            'error')
        return
    end

    -- qb-bodycam only ever lets you watch an officer while THEY have their
    -- own bodycam toggled on (it tracks this in a global state bag,
    -- GlobalState.PlayerOnBodycam, keyed by server id). Respecting that exact
    -- rule here means the MDT can't silently spectate someone who never
    -- turned their camera on — same privacy behavior as the vanilla script.
    local broadcasting = GlobalState.PlayerOnBodycam and GlobalState.PlayerOnBodycam[targetServerId]
    if not broadcasting then
        TriggerClientEvent('QBCore:Notify', src, "That officer's bodycam is not currently active.", 'error')
        return
    end

    TriggerClientEvent('qb-bodycam:startWatching', src, targetServerId)
    TriggerClientEvent('QBCore:Notify', src,
        'Connecting to bodycam feed… press ' .. tostring(Config.BodycamExitKeyLabel or 'BACKSPACE') .. ' to exit.',
        'primary')
    MDT.LogMdtAction(Player, 'Viewed Bodycam Feed', 'Target server id ' .. tostring(targetServerId))
end

RegisterNetEvent('police:server:RequestBodycam', function(targetServerId)
    HandleBodycamRequest(source, targetServerId)
end)

-- Generic export other resources can also call instead of guessing event
-- names — same permission/broadcasting checks either way.
exports('RequestBodycamView', function(src, targetServerId)
    HandleBodycamRequest(src, targetServerId)
end)

-- ===================================================================
-- BOLO / Be-On-The-Lookout board (all employees post & view; delete =
-- author or Command, identical pattern to Reports)
-- ===================================================================
