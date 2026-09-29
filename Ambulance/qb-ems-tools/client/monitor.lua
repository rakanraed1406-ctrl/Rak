-- Live vitals monitor (NUI overlay, no mouse focus — you can keep treating).
local monitor = { open = false, target = nil, prop = nil, anim = nil }

local function CloseMonitor()
    if not monitor.open then return end
    monitor.open = false
    SendNUIMessage({ action = 'close' })
    if monitor.prop and DoesEntityExist(monitor.prop) then DeleteEntity(monitor.prop) end
    EMS.StopAnim(monitor.anim)
    monitor.prop, monitor.anim, monitor.target = nil, nil, nil
end
EMS.CloseMonitor = CloseMonitor

function EMS.OpenMonitor(targetId)
    if monitor.open then return CloseMonitor() end
    if not EMS.IsMedic() then return EMS.Notify('Only on-duty paramedics can use the monitor', 'error') end
    if not targetId then
        local pid = EMS.ClosestPlayer(3.0)
        targetId = pid and GetPlayerServerId(pid) or nil
    end
    if not targetId then return EMS.Notify('No patient nearby', 'error') end

    local vitals = EMS.TriggerCallback('ems-tools:server:GetVitals', targetId)
    if not vitals then return EMS.Notify('Can\'t read the patient\'s vitals', 'error') end

    monitor.open, monitor.target = true, targetId
    SendNUIMessage({ action = 'open', volume = Config.Monitor.Volume, data = vitals })
    monitor.prop = Config.Monitor.Prop and EMS.SpawnProp(Config.Monitor.Prop) or nil
    monitor.anim = Config.Monitor.Anim and EMS.PlayAnim(Config.Monitor.Anim) or nil

    CreateThread(function()
        local nextRefresh = GetGameTimer() + Config.Monitor.Refresh
        while monitor.open do
            local ped = PlayerPedId()
            if IsControlJustReleased(0, Config.Monitor.CloseKey) or IsEntityDead(ped) then
                CloseMonitor()
                break
            end
            if monitor.anim and not IsPedInAnyVehicle(ped, false) and not IsEntityPlayingAnim(ped, monitor.anim.dict, monitor.anim.anim, 3) then
                TaskPlayAnim(ped, monitor.anim.dict, monitor.anim.anim, 3.0, 3.0, -1, monitor.anim.flag or 49, 0, false, false, false)
            end
            if GetGameTimer() >= nextRefresh then
                nextRefresh = GetGameTimer() + Config.Monitor.Refresh
                local pid = GetPlayerFromServerId(monitor.target)
                local tped = pid ~= -1 and GetPlayerPed(pid) or 0
                if tped == 0 or #(GetEntityCoords(tped) - GetEntityCoords(ped)) > Config.Monitor.Range then
                    EMS.Notify('Monitor disconnected — too far from the patient', 'error')
                    CloseMonitor()
                    break
                end
                CreateThread(function()
                    local v = EMS.TriggerCallback('ems-tools:server:GetVitals', monitor.target)
                    if monitor.open and v then SendNUIMessage({ action = 'vitals', data = v }) end
                end)
            end
            Wait(0)
        end
    end)
end

RegisterNetEvent('ems-tools:client:OpenMonitor', function() EMS.OpenMonitor() end)
RegisterNetEvent('ems-tools:client:ExamineClosest', function() EMS.OpenMonitor() end)
RegisterCommand('emsmonitor', function() EMS.OpenMonitor() end, false)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then CloseMonitor() end
end)
