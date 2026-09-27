--[[
    server/dispatch.lua
    Everything that sends a dispatch call — routed through MDT.SendDispatchCall
    (server/_shared.lua), which talks to sk1-hub ONLY
    (exports['sk1-hub']:CreateDispatchCall — see Config.DispatchResource).
    No other dispatch script is used anywhere in this resource.
]]

local QBCore = MDT.QBCore

RegisterNetEvent('police:server:BroadcastEmergencyAlert', function(message)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsBoss(Player) then return end
    if type(message) ~= 'string' or message:gsub('%s+', '') == '' then return end
    message = message:sub(1, 250)

    local ped = GetPlayerPed(src)
    local coords = ped ~= 0 and GetEntityCoords(ped) or vector3(0.0, 0.0, 0.0)
    local charinfo = Player.PlayerData.charinfo
    local callerName = (charinfo and charinfo.firstname or 'Command') .. ' ' .. (charinfo and charinfo.lastname or '')

    MDT.SendDispatchCall('police', {
        code = '911-CALL', title = '911 Call — MDT Broadcast', priority = 'HIGH',
        description = message, coords = { x = coords.x, y = coords.y, z = coords.z },
        tags = { { icon = 'fa-shield', label = callerName } }
    })

    MDT.LogMdtAction(Player, 'Sent Emergency Broadcast', message)
end)

RegisterNetEvent('police:server:SetAlertLevel', function(level)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsBoss(Player) then return end
    if level ~= 'green' and level ~= 'yellow' and level ~= 'red' then return end

    MDT.State.alertLevel = level

    local ped = GetPlayerPed(src)
    local coords = ped ~= 0 and GetEntityCoords(ped) or vector3(0.0, 0.0, 0.0)

    MDT.SendDispatchCall('police', {
        code = 'ALERT-LEVEL', title = 'Department Alert Level: CODE ' .. level:upper(),
        priority = level == 'red' and 'HIGH' or 'NORMAL',
        description = 'Department alert level has been changed to CODE ' .. level:upper() .. '.',
        coords = { x = coords.x, y = coords.y, z = coords.z }
    })

    local players = QBCore.Functions.GetQBPlayers()
    for _, v in pairs(players) do
        if v and v.PlayerData.job.name == Config.JobName then
            TriggerClientEvent('police:client:AlertLevelChanged', v.PlayerData.source, level)
        end
    end

    MDT.LogMdtAction(Player, 'Changed Alert Level', level)
end)

-- "All Units" text alert — open to any on-duty employee, cooldown-limited.
RegisterNetEvent('police:server:SendUnitsAlert', function(message)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsEmployee(Player) then return end
    if type(message) ~= 'string' or message:gsub('%s+', '') == '' then return end
    message = message:sub(1, 200)

    local citizenid = Player.PlayerData.citizenid
    if not MDT.CheckCooldown('unitsAlert', citizenid) then
        TriggerClientEvent('QBCore:Notify', src, 'Please wait before sending another all-units alert.', 'error')
        return
    end

    local ped = GetPlayerPed(src)
    local coords = ped ~= 0 and GetEntityCoords(ped) or vector3(0.0, 0.0, 0.0)
    local charinfo = Player.PlayerData.charinfo
    local senderName = (charinfo and charinfo.firstname or 'Unit') .. ' ' .. (charinfo and charinfo.lastname or '')

    MDT.SendDispatchCall('police', {
        code = 'ALL-UNITS', title = 'All Units — ' .. senderName, priority = 'NORMAL',
        description = message, coords = { x = coords.x, y = coords.y, z = coords.z },
        tags = { { icon = 'fa-bullhorn', label = senderName } }
    })

    MDT.LogMdtAction(Player, 'Sent All-Units Alert', message)
end)
