--[[ server/tactical.lua - in-world GPS blip toggle, lockdown, Code 99 backup (unchanged) ]]
local QBCore = MDT.QBCore

RegisterNetEvent('police:server:RequestOnDutyLocations', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsBoss(Player) then return end

    local officers = {}
    local players = QBCore.Functions.GetQBPlayers()
    for _, v in pairs(players) do
        if v and v.PlayerData.job.name == Config.JobName and v.PlayerData.job.onduty then
            local ped = GetPlayerPed(v.PlayerData.source)
            if ped ~= 0 then
                local coords = GetEntityCoords(ped)
                local charinfo = v.PlayerData.charinfo
                table.insert(officers, {
                    serverId = v.PlayerData.source,
                    name = (charinfo and charinfo.firstname or 'Officer') .. ' ' .. (charinfo and charinfo.lastname or ''),
                    coords = { x = coords.x, y = coords.y, z = coords.z }
                })
            end
        end
    end

    TriggerClientEvent('police:client:UpdateOnDutyBlips', src, officers)
end)

RegisterNetEvent('police:server:ToggleLockdown', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsBoss(Player) then return end

    MDT.State.lockdown = not MDT.State.lockdown
    local deptLockdown = MDT.State.lockdown
    MDT.NotifyAllPolice(
        ('Police HQ: Facility lockdown has been %s.'):format(deptLockdown and 'ENGAGED' or 'LIFTED'),
        deptLockdown and 'error' or 'success'
    )
    MDT.LogMdtAction(Player, 'Toggled Facility Lockdown', deptLockdown and 'ENGAGED' or 'LIFTED')
    TriggerClientEvent('police:client:LockdownState', -1, deptLockdown)
end)

-- Exposed so other resources (armory doors, garages, evidence lockers, etc.) can
-- check lockdown state without needing their own event wiring.
exports('IsDepartmentLocked', function()
    return MDT.State.lockdown
end)

RegisterNetEvent('police:server:RequestGlobalBackup', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsBoss(Player) then return end

    local ped = GetPlayerPed(src)
    if ped == 0 then return end
    local coords = GetEntityCoords(ped)
    local charinfo = Player.PlayerData.charinfo
    local callerName = (charinfo.firstname or 'Chief') .. ' ' .. (charinfo.lastname or '')

    local players = QBCore.Functions.GetQBPlayers()
    for _, v in pairs(players) do
        if v and v.PlayerData.job.name == Config.JobName and v.PlayerData.job.onduty and v.PlayerData.source ~= src then
            TriggerClientEvent('QBCore:Notify', v.PlayerData.source, ('CODE 99: All units requested by %s. Check your map.'):format(callerName), 'error', 8000)
            TriggerClientEvent('police:client:ReceiveBackupPing', v.PlayerData.source, coords, callerName)
        end
    end

    MDT.LogMdtAction(Player, 'Requested Global Backup (Code 99)', nil)
end)

--- Boss-gated relay for the dispatch broadcast/alert level features. Routing these
--- through the server (instead of letting the NUI fire the dispatch event directly)
--- closes off a path where a modified client could spam fake alerts without ever
--- actually being a boss.
