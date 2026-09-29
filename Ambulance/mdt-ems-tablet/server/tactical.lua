--[[ server/tactical.lua - Command Ops: medic GPS blips, hospital lockdown, Mass Casualty (MCI) all-units ]]
local QBCore = MDT.QBCore

--- Live GPS of ON-DUTY medics only (never off-duty / offline personnel).
RegisterNetEvent('ems-mdt:server:RequestOnDutyLocations', function()
    local src = source
    if not MDT.IsBoss(QBCore.Functions.GetPlayer(src)) then return end

    local medics = {}
    for _, v in pairs(QBCore.Functions.GetQBPlayers()) do
        if v and v.PlayerData.job.name == Config.JobName and v.PlayerData.job.onduty then
            local ped = GetPlayerPed(v.PlayerData.source)
            if ped ~= 0 then
                local coords = GetEntityCoords(ped)
                medics[#medics + 1] = {
                    serverId = v.PlayerData.source,
                    name = MDT.GetName(v),
                    coords = { x = coords.x, y = coords.y, z = coords.z }
                }
            end
        end
    end

    TriggerClientEvent('ems-mdt:client:UpdateOnDutyBlips', src, medics)
end)

RegisterNetEvent('ems-mdt:server:ToggleLockdown', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsBoss(Player) then return end

    MDT.State.lockdown = not MDT.State.lockdown
    local locked = MDT.State.lockdown
    MDT.NotifyAllEms(('EMS Command: Hospital lockdown has been %s.'):format(locked and 'ENGAGED' or 'LIFTED'), locked and 'error' or 'success')
    MDT.LogMdtAction(Player, 'Toggled Hospital Lockdown', locked and 'ENGAGED' or 'LIFTED')
    TriggerClientEvent('ems-mdt:client:LockdownState', -1, locked)
end)

-- Other resources (doors, elevators, pharmacy…) can check the hospital lockdown.
exports('IsDepartmentLocked', function() return MDT.State.lockdown end)

--- Mass Casualty Incident: pings every on-duty medic + creates a RED call at the boss' position.
RegisterNetEvent('ems-mdt:server:RequestGlobalBackup', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsBoss(Player) then return end
    if not MDT.CheckCooldown('mci', Player.PlayerData.citizenid) then
        TriggerClientEvent('QBCore:Notify', src, 'Please wait before declaring another MCI.', 'error')
        return
    end

    local coords = MDT.PedCoords(src)
    local callerName = MDT.GetName(Player)

    for _, v in pairs(QBCore.Functions.GetQBPlayers()) do
        if v and v.PlayerData.job.name == Config.JobName and v.PlayerData.job.onduty and v.PlayerData.source ~= src then
            TriggerClientEvent('ems-mdt:client:ReceiveBackupPing', v.PlayerData.source, coords, callerName)
        end
    end

    MDT.SendDispatchCall('ambulance', {
        code = 'MCI', title = 'Mass Casualty Incident — All Units',
        description = ('%s declared a mass casualty incident. All available medics respond; triage on arrival.'):format(callerName),
        coords = coords, origin = 'command',
        tags = { { icon = 'fa-people-group', label = 'MCI declared' }, { icon = 'fa-user-doctor', label = callerName } }
    })

    MDT.LogMdtAction(Player, 'Declared Mass Casualty (MCI)', nil)
end)
