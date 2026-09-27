--[[ client/cameras.lua - CCTV feed rendering. Access is server-approved only. ]]

local QBCore = MDTClient.QBCore

local function ApplyCameraHudState(active)
    DisplayRadar(not active)
    if active then
        HideHudComponentThisFrame(1)  -- WantedStars
        HideHudComponentThisFrame(2)  -- WeaponIcon
        HideHudComponentThisFrame(3)  -- Cash
        HideHudComponentThisFrame(4)  -- MpCash
        HideHudComponentThisFrame(6)  -- VehicleName
        HideHudComponentThisFrame(7)  -- AreaName
        HideHudComponentThisFrame(9)  -- StreetName
        HideHudComponentThisFrame(13) -- CashChange
    end
end

-- BUGFIX (emote stuck on after closing the MDT): this used to unconditionally
-- hand focus back to the boss menu and resume the tablet emote whenever the
-- camera view was torn down — including when it was torn down *because the
-- whole MDT is closing* (CloseMdt() in core.lua calls this to clean up camera
-- state first). That meant closing the tablet while on a CCTV feed would
-- re-grab NUI focus, restart the "e tablet" emote, and only *then* the rest
-- of CloseMdt would fire the cancel command — a start-then-cancel race that
-- some emote resources lose (the animation finishes loading a moment later
-- and plays anyway, with nothing left around to cancel it since mdtOpen is
-- already false by then). closingMenu = true skips the "go back to the menu"
-- steps entirely so a full close only ever cancels, never restarts.
function MDTClient.ExitCameraView(closingMenu)
    if not MDTClient.inCameraView then return end
    MDTClient.inCameraView = false
    MDTClient.camGeneration = MDTClient.camGeneration + 1

    RenderScriptCams(false, true, 500, true, true)
    if MDTClient.activeCam and DoesCamExist(MDTClient.activeCam) then
        DestroyCam(MDTClient.activeCam, false)
    end
    MDTClient.activeCam = nil

    ClearTimecycleModifier()
    FreezeEntityPosition(PlayerPedId(), false)
    DisplayRadar(true)

    if closingMenu then return end

    SendNUIMessage({ action = 'closeCameraView' })

    -- Hand control back to the boss menu, parked on the Cameras tab so the
    -- boss can pick another feed without re-navigating from Overview.
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'reopenOnCameras' })

    -- Resume the tablet-holding emote now that we're back to browsing the
    -- menu (it was paused for the duration of the camera feed below).
    if MDTClient.mdtOpen then MDTClient.PlayTabletAnim() end
end

local function EnterCameraView(camIndex)
    local camConfig = Config.Cameras[camIndex]
    if not camConfig then return end

    if MDTClient.inCameraView then
        -- Switching directly from one camera to another: tear down the old
        -- one without bouncing focus back to the menu in between.
        MDTClient.inCameraView = false
        MDTClient.camGeneration = MDTClient.camGeneration + 1
        RenderScriptCams(false, false, 0, true, true)
        if MDTClient.activeCam and DoesCamExist(MDTClient.activeCam) then DestroyCam(MDTClient.activeCam, false) end
        MDTClient.activeCam = nil
    end

    MDTClient.inCameraView = true
    MDTClient.camGeneration = MDTClient.camGeneration + 1
    local myGeneration = MDTClient.camGeneration

    local coords = camConfig.coords
    local baseHeading = coords.w or 0.0
    local currentHeading = baseHeading
    local panLimit = camConfig.panLimit or Config.CameraDefaultPanLimit

    MDTClient.activeCam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', coords.x, coords.y, coords.z, 0.0, 0.0, baseHeading, camConfig.fov or 50.0, false, 0)
    SetCamActive(MDTClient.activeCam, true)
    RenderScriptCams(true, false, 0, true, true)
    SetTimecycleModifier(Config.CameraTimecycleModifier)
    FreezeEntityPosition(PlayerPedId(), true)

    SetNuiFocus(false, false) -- keyboard-only control from here; mouse passes through to the game
    SendNUIMessage({ action = 'openCameraView', name = camConfig.name })

    -- Pause the tablet emote while looking through a fixed camera — you're
    -- not holding/reading the tablet during that, you're watching a feed.
    if MDTClient.mdtOpen then MDTClient.StopTabletAnim() end

    CreateThread(function()
        while MDTClient.inCameraView and MDTClient.camGeneration == myGeneration do
            Wait(0)
            ApplyCameraHudState(true)

            -- Disable the controls we intercept for panning, plus movement/combat
            -- so the frozen player can't be hurt or wander off while "on camera".
            DisableControlAction(0, 30, true)  -- MoveLeftRight
            DisableControlAction(0, 31, true)  -- MoveUpDown
            DisableControlAction(0, 32, true)  -- W
            DisableControlAction(0, 33, true)  -- S
            DisableControlAction(0, 34, true)  -- A / MoveLeftOnly
            DisableControlAction(0, 35, true)  -- D / MoveRightOnly
            DisableControlAction(0, 24, true)  -- Attack
            DisableControlAction(0, 25, true)  -- Aim
            DisableControlAction(0, 37, true)  -- Weapon wheel

            local panDelta = 0.0
            if IsDisabledControlPressed(0, 34) then
                panDelta = Config.CameraPanSpeed
            elseif IsDisabledControlPressed(0, 35) then
                panDelta = -Config.CameraPanSpeed
            end

            if panDelta ~= 0.0 then
                local newHeading = currentHeading + panDelta
                local delta = newHeading - baseHeading

                -- wrap-safe clamp: keep the swivel within panLimit degrees of center
                if delta > panLimit then
                    newHeading = baseHeading + panLimit
                elseif delta < -panLimit then
                    newHeading = baseHeading - panLimit
                end

                currentHeading = newHeading
                SetCamRot(MDTClient.activeCam, 0.0, 0.0, currentHeading, 2)

                -- feed the NUI a 0-1 sweep position so it can draw a small pan indicator
                local sweep = panLimit > 0 and ((currentHeading - baseHeading) / panLimit) or 0.0
                SendNUIMessage({ action = 'cameraPanUpdate', sweep = sweep })
            end

            if IsDisabledControlJustPressed(0, 194) or IsControlJustPressed(0, 194) then -- Backspace
                MDTClient.ExitCameraView()
            end
        end
    end)
end

-- SECURITY FIX: this used to call EnterCameraView(camIndex) directly from the
-- NUI callback with no permission check at all — see the matching note on
-- police:server:RequestCameraAccess in server.lua for why that mattered.
-- Now this only ever *asks*; the server decides, and CameraAccessGranted
-- below is the only thing that's allowed to actually start the camera.
RegisterNUICallback('viewCamera', function(data, cb)
    local camIndex = tonumber(data.id)
    if camIndex and MDTClient.isBossCache then
        TriggerServerEvent('police:server:RequestCameraAccess', camIndex)
    elseif camIndex then
        QBCore.Functions.Notify('Boss access required to view CCTV feeds.', 'error')
    end
    cb('ok')
end)

RegisterNetEvent('police:client:CameraAccessGranted', function(camIndex)
    EnterCameraView(camIndex)
    TriggerServerEvent('police:server:LogCameraView', camIndex)
end)

RegisterNUICallback('exitCameraView', function(_, cb)
    MDTClient.ExitCameraView()
    cb('ok')
end)

-- Safety net: if the resource stops or the player disconnects mid-camera-view,
-- make sure controls, HUD, and the timecycle filter are properly restored.
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    if MDTClient.inCameraView then MDTClient.ExitCameraView(true) end
end)

-- ===================================================================
-- Recruitment applications (applicant side — qb-menu / qb-input)
-- ===================================================================
