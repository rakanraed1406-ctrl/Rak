--[[ client/tactical.lua - Command Ops: medic GPS blips, hospital lockdown, Mass Casualty (MCI) ping ]]

local QBCore = MDTClient.QBCore

function MDTClient.ClearDeptBlips()
    for _, blip in pairs(MDTClient.deptBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    MDTClient.deptBlips = {}
end

function MDTClient.StopOnDutyGPS()
    if MDTClient.gpsActive then
        MDTClient.gpsActive = false
        MDTClient.ClearDeptBlips()
    end
end

local function ToggleOnDutyGPS()
    MDTClient.gpsActive = not MDTClient.gpsActive

    if MDTClient.gpsActive then
        QBCore.Functions.Notify('On-duty medic tracking enabled.', 'success')
        CreateThread(function()
            while MDTClient.gpsActive do
                TriggerServerEvent('ems-mdt:server:RequestOnDutyLocations')
                Wait(Config.GPSRefreshInterval)
            end
        end)
    else
        QBCore.Functions.Notify('On-duty medic tracking disabled.', 'primary')
        MDTClient.ClearDeptBlips()
    end
end

RegisterNetEvent('ems-mdt:client:UpdateOnDutyBlips', function(medics)
    if not MDTClient.gpsActive then return end -- stale response after tracking was turned off

    local seen = {}
    for _, medic in pairs(medics) do
        seen[medic.serverId] = true
        local blip = MDTClient.deptBlips[medic.serverId]

        if not blip or not DoesBlipExist(blip) then
            blip = AddBlipForCoord(medic.coords.x, medic.coords.y, medic.coords.z)
            SetBlipSprite(blip, 1)
            SetBlipColour(blip, 1)
            SetBlipScale(blip, 0.85)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(medic.name)
            EndTextCommandSetBlipName(blip)
            MDTClient.deptBlips[medic.serverId] = blip
        else
            SetBlipCoords(blip, medic.coords.x, medic.coords.y, medic.coords.z)
        end
    end

    for id, blip in pairs(MDTClient.deptBlips) do
        if not seen[id] then
            if DoesBlipExist(blip) then RemoveBlip(blip) end
            MDTClient.deptBlips[id] = nil
        end
    end
end)

RegisterNetEvent('ems-mdt:client:ReceiveBackupPing', function(coords, callerName)
    QBCore.Functions.Notify(('MCI: mass casualty declared by %s — all available units respond. Check your map.'):format(callerName or 'Command'), 'error', 9000)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, 153)
    SetBlipColour(blip, 1)
    SetBlipScale(blip, 1.2)
    SetBlipFlashes(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('MCI: ' .. tostring(callerName))
    EndTextCommandSetBlipName(blip)

    SetTimeout(Config.BackupPingDuration, function()
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end)
end)

RegisterNetEvent('ems-mdt:client:LockdownState', function(isLocked)
    if isLocked then
        QBCore.Functions.Notify('HOSPITAL LOCKDOWN ENGAGED', 'error', 7000)
    else
        QBCore.Functions.Notify('Hospital lockdown lifted', 'success', 7000)
    end
end)

RegisterNUICallback('triggerBossAction', function(data, cb)
    local action = data.action

    if action == 'toggleOnDutyGPS' then
        ToggleOnDutyGPS()
    elseif action == 'lockdownDept' then
        TriggerServerEvent('ems-mdt:server:ToggleLockdown')
    elseif action == 'requestBackupAll' then
        TriggerServerEvent('ems-mdt:server:RequestGlobalBackup')
    elseif action == 'clearDepartmentBlips' then
        MDTClient.ClearDeptBlips()
    end

    cb('ok')
end)
