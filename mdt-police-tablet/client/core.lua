local QBCore = MDTClient.QBCore

RegisterNetEvent('police:client:OpenBossMenuUI', function(data)
    SetNuiFocus(true, true)
    MDTClient.isBossCache = data.isBoss == true
    MDTClient.isCommandStaffCache = data.isCommandStaff == true
    MDTClient.selfCitizenId = data.selfCitizenId

    if not MDTClient.mdtOpen then
        MDTClient.mdtOpen = true
        MDTClient.PlayTabletAnim()
        TriggerServerEvent('police:server:MdtSession', true)
    end

    local cameraList = {}
    for i, cam in ipairs(Config.Cameras) do cameraList[i] = { id = i, name = cam.name } end

    SendNUIMessage({
        action = 'openBossMenu', selfName = data.selfName, selfGrade = data.selfGrade,
        selfGradeLevel = data.selfGradeLevel, selfCitizenId = data.selfCitizenId, selfOnDuty = data.selfOnDuty,
        isCommandStaff = data.isCommandStaff, isBoss = data.isBoss, minCommandGrade = data.minCommandGrade,
        isLockdown = data.isLockdown, alertLevel = data.alertLevel, money = data.money,
        employees = data.employees, applications = data.applications or {}, onDutyCount = data.onDutyCount,
        cameras = cameraList, mapBounds = Config.MapWorldBounds,
        selfServerId = data.selfServerId, selfCallsign = data.selfCallsign, selfStatus = data.selfStatus,
        canManageDispatch = data.canManageDispatch
    })
end)

-- Loads the tablet anim dict + prop model and plays the hold/type animation
-- directly on the ped, with the prop attached to its hand. Guarded by
-- MDTClient.tabletAnimGeneration so an ExitCameraView resume that lands after
-- the tablet was already closed doesn't start the animation back up again.
function MDTClient.PlayTabletAnim()
    MDTClient.tabletAnimGeneration = (MDTClient.tabletAnimGeneration or 0) + 1
    local myGeneration = MDTClient.tabletAnimGeneration

    CreateThread(function()
        local ped = PlayerPedId()

        RequestAnimDict(Config.TabletAnimDict)
        while not HasAnimDictLoaded(Config.TabletAnimDict) do Wait(0) end

        RequestModel(Config.TabletProp)
        while not HasModelLoaded(Config.TabletProp) do Wait(0) end

        -- Bail out if the tablet was closed (or the anim was restarted again)
        -- while the dict/model above were still streaming in.
        if myGeneration ~= MDTClient.tabletAnimGeneration then
            SetModelAsNoLongerNeeded(Config.TabletProp)
            return
        end

        if MDTClient.tabletPropObj and DoesEntityExist(MDTClient.tabletPropObj) then
            DeleteEntity(MDTClient.tabletPropObj)
            MDTClient.tabletPropObj = nil
        end

        local coords = GetEntityCoords(ped)
        local propObj = CreateObject(Config.TabletProp, coords.x, coords.y, coords.z, true, true, false)
        local boneIndex = GetPedBoneIndex(ped, Config.TabletPropBone)
        AttachEntityToEntity(propObj, ped, boneIndex,
            Config.TabletPropOffset.x, Config.TabletPropOffset.y, Config.TabletPropOffset.z,
            Config.TabletPropRotation.x, Config.TabletPropRotation.y, Config.TabletPropRotation.z,
            true, true, false, true, 1, true)
        MDTClient.tabletPropObj = propObj
        SetModelAsNoLongerNeeded(Config.TabletProp)

        -- Flags: 1 (looping) + 16 (upper body only) + 32 (secondary/cancelable)
        TaskPlayAnim(ped, Config.TabletAnimDict, Config.TabletAnimName, 8.0, -8.0, -1, 49, 0, false, false, false)
    end)
end

-- Cancels the tablet animation defensively. Bumping the generation counter
-- first stops a still-loading PlayTabletAnim thread (see above) from
-- attaching the prop/playing the anim after the fact, on top of the
-- immediate cleanup below.
function MDTClient.StopTabletAnim()
    MDTClient.tabletAnimGeneration = (MDTClient.tabletAnimGeneration or 0) + 1

    local ped = PlayerPedId()
    ClearPedSecondaryTask(ped)
    StopAnimTask(ped, Config.TabletAnimDict, Config.TabletAnimName, 1.0)

    if MDTClient.tabletPropObj and DoesEntityExist(MDTClient.tabletPropObj) then
        DeleteEntity(MDTClient.tabletPropObj)
        MDTClient.tabletPropObj = nil
    end
end

local function CloseMdt()
    SetNuiFocus(false, false)
    if MDTClient.StopOnDutyGPS then MDTClient.StopOnDutyGPS() end
    if MDTClient.StopMapSubscription then MDTClient.StopMapSubscription() end
    -- closingMenu = true: just tear down the camera (unfreeze, restore HUD/
    -- radar) without handing focus back to the menu or resuming the emote —
    -- the whole tablet is closing, not just the camera feed.
    if MDTClient.inCameraView and MDTClient.ExitCameraView then MDTClient.ExitCameraView(true) end
    if MDTClient.mdtOpen then
        MDTClient.mdtOpen = false
        MDTClient.StopTabletAnim()
        TriggerServerEvent('police:server:MdtSession', false)
    end
end

-- Safety net: if this resource restarts/stops while the tablet is open (a
-- server restart, `restart mdt`, etc.), make sure NUI focus is released and
-- the emote is actually cancelled instead of being left running forever with
-- no resource left to close it.
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    if MDTClient.mdtOpen then CloseMdt() end
end)

RegisterNUICallback('close', function(_, cb) CloseMdt() cb('ok') end)

RegisterNetEvent('police:client:ForceCloseMdt', function(reason)
    if not MDTClient.mdtOpen then return end
    CloseMdt()
    SendNUIMessage({ action = 'forceClose' })
    QBCore.Functions.Notify(reason or 'Your MDT session has been ended.', 'error', 6000)
end)

RegisterNetEvent('police:client:TriggerBossMenu', function()
    TriggerServerEvent('police:server:GetBossData')
end)

local lastMdtCommandAt = 0
RegisterCommand('mdt', function()
    local now = GetGameTimer()
    if (now - lastMdtCommandAt) < 1000 then return end
    lastMdtCommandAt = now
    TriggerEvent('police:client:TriggerBossMenu')
end, false)

RegisterNUICallback('clockOut', function(_, cb)
    TriggerServerEvent('police:server:HubSetDuty', false)
    cb('ok')
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    if not MDTClient.mdtOpen then return end
    if not job or job.name ~= Config.JobName then
        -- Fired / job changed while the tablet was open.
        CloseMdt()
        SendNUIMessage({ action = 'forceClose' })
        return
    end
    SendNUIMessage({ action = 'dutyChanged', onDuty = job.onduty == true })
    -- Old behaviour (tablet auto-clocks you in) → clocking out closes it again.
    if not job.onduty and Config.Hub and Config.Hub.AutoClockIn then
        CloseMdt()
        SendNUIMessage({ action = 'forceClose' })
        QBCore.Functions.Notify('You clocked out — MDT closed.', 'primary')
    end
end)
