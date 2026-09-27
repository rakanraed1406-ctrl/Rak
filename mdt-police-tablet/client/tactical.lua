--[[ client/tactical.lua - in-world GPS blip toggle, lockdown, Code 99 backup ]]

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
        QBCore.Functions.Notify('On-duty officer tracking enabled.', 'success')
        CreateThread(function()
            while MDTClient.gpsActive do
                TriggerServerEvent('police:server:RequestOnDutyLocations')
                Wait(Config.GPSRefreshInterval)
            end
        end)
    else
        QBCore.Functions.Notify('On-duty officer tracking disabled.', 'primary')
        MDTClient.ClearDeptBlips()
    end
end

RegisterNetEvent('police:client:UpdateOnDutyBlips', function(officers)
    if not MDTClient.gpsActive then return end -- ignore stale responses after tracking was turned off

    local seen = {}
    for _, officer in pairs(officers) do
        seen[officer.serverId] = true
        local blip = MDTClient.deptBlips[officer.serverId]

        if not blip or not DoesBlipExist(blip) then
            blip = AddBlipForCoord(officer.coords.x, officer.coords.y, officer.coords.z)
            SetBlipSprite(blip, 60)
            SetBlipColour(blip, 3)
            SetBlipScale(blip, 0.85)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(officer.name)
            EndTextCommandSetBlipName(blip)
            MDTClient.deptBlips[officer.serverId] = blip
        else
            SetBlipCoords(blip, officer.coords.x, officer.coords.y, officer.coords.z)
        end
    end

    for id, blip in pairs(MDTClient.deptBlips) do
        if not seen[id] then
            if DoesBlipExist(blip) then RemoveBlip(blip) end
            MDTClient.deptBlips[id] = nil
        end
    end
end)

-- ===================================================================
-- Tactical Map app — separate from the GPS blip toggle above. Any on-duty
-- officer can subscribe while the Map app is open; command actions taken
-- from a pin still route through the exact same Personnel events/checks.
-- ===================================================================


RegisterNetEvent('police:client:ReceiveBackupPing', function(coords, callerName)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, 161)
    SetBlipColour(blip, 1)
    SetBlipScale(blip, 1.1)
    SetBlipFlashes(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Code 99: ' .. callerName)
    EndTextCommandSetBlipName(blip)

    SetTimeout(Config.BackupPingDuration, function()
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end)
end)

RegisterNetEvent('police:client:LockdownState', function(isLocked)
    if isLocked then
        QBCore.Functions.Notify('~r~FACILITY LOCKDOWN ENGAGED', 'error', 7000)
    else
        QBCore.Functions.Notify('~g~Facility lockdown lifted', 'success', 7000)
    end
end)

RegisterNUICallback('triggerBossAction', function(data, cb)
    local action = data.action

    if action == 'toggleOnDutyGPS' then
        ToggleOnDutyGPS()
    elseif action == 'lockdownDept' then
        TriggerServerEvent('police:server:ToggleLockdown')
    elseif action == 'requestBackupAll' then
        TriggerServerEvent('police:server:RequestGlobalBackup')
    elseif action == 'clearDepartmentBlips' then
        MDTClient.ClearDeptBlips()
    end

    cb('ok')
end)

-- ===================================================================
-- CCTV camera system
-- (state locals declared at the top of the file — see the comment there)
-- ===================================================================

--- Hides HUD elements that don't make sense while looking through a fixed camera.
