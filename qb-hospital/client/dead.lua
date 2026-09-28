local QBCore = exports['qb-core']:GetCoreObject()

local deadAnimDict = "dead"
local deadAnim = "dead_a"
local respawnHold = 5
local hold = respawnHold
deathTime = 0

-- Functions

local function loadAnimDict(dict)
    while (not HasAnimDictLoaded(dict)) do
        RequestAnimDict(dict)
        Wait(5)
    end
end

function OnDeath()
    if not isDead then
        isDead = true
        TriggerServerEvent("hospital:server:SetDeathStatus", true)
        TriggerServerEvent("InteractSound_SV:PlayOnSource", "demo", 0.1)
        local player = PlayerPedId()

        while GetEntitySpeed(player) > 0.5 or IsPedRagdoll(player) do
            Wait(10)
        end

        if isDead then
            local pos = GetEntityCoords(player)
            local heading = GetEntityHeading(player)

            local ped = PlayerPedId()
            if IsPedInAnyVehicle(ped) then
                local veh = GetVehiclePedIsIn(ped)
                local vehseats = GetVehicleModelNumberOfSeats(GetHashKey(GetEntityModel(veh)))
                for i = -1, vehseats do
                    local occupant = GetPedInVehicleSeat(veh, i)
                    if occupant == ped then
                        NetworkResurrectLocalPlayer(pos.x, pos.y, pos.z + 0.5, heading, true, false)
                        SetPedIntoVehicle(ped, veh, i)
                    end
                end
            else
                NetworkResurrectLocalPlayer(pos.x, pos.y, pos.z + 0.5, heading, true, false)
            end
			
            SetEntityInvincible(player, true)
            SetEntityHealth(player, GetEntityMaxHealth(player))
            if IsPedInAnyVehicle(player, false) then
                loadAnimDict("veh@low@front_ps@idle_duck")
                TaskPlayAnim(player, "veh@low@front_ps@idle_duck", "sit", 1.0, 1.0, -1, 1, 0, 0, 0, 0)
            else
                loadAnimDict(deadAnimDict)
                TaskPlayAnim(player, deadAnimDict, deadAnim, 1.0, 1.0, -1, 1, 0, 0, 0, 0)
            end
            -- TriggerServerEvent('hospital:server:ambulanceAlert', Lang:t('info.civ_died'))
            -- EMSAlert('Civilian Down')
        end
    end
end

function DeathTimer()
    hold = respawnHold
    while isDead do
        Wait(1000)
        deathTime = deathTime - 1
        if deathTime <= 0 then
            if IsControlPressed(0, 38) and hold <= 0 and not isInHospitalBed then
                TriggerEvent("hospital:client:RespawnAtHospital")
                hold = respawnHold
            end
            if IsControlPressed(0, 38) then
                if hold - 1 >= 0 then
                    hold = hold - 1
                else
                    hold = 0
                end
            end
            if IsControlReleased(0, 38) then
                hold = respawnHold
            end
        end
    end
end

-- Death screen (html/)

local nuiReady = false
local deathScreenVisible = false
local deathScreenState = nil
local deathScreenToken = 0

-- only used when the html page did not load
local function DrawTxt(x, y, width, height, scale, text, r, g, b, a)
    SetTextFont(4)
    SetTextProportional(0)
    SetTextScale(scale, scale)
    SetTextColour(r, g, b, a)
    SetTextDropShadow(0, 0, 0, 0,255)
    SetTextEdge(2, 0, 0, 0, 255)
    SetTextDropShadow()
    SetTextOutline()
    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(x - width/2, y - height/2 + 0.005)
end

local function SendShowMessage()
    SendNUIMessage({
        action = 'show',
        sound = Config.DeathScreen.Sound,
        volume = Config.DeathScreen.Volume,
        texts = {
            bleeding = Lang:t('death_screen.bleeding'),
            dead = Lang:t('death_screen.dead'),
            request_help = Lang:t('death_screen.request_help'),
            help_requested = Lang:t('death_screen.help_requested'),
            respawn_wait = Lang:t('death_screen.respawn_wait'),
            respawn_hold = Lang:t('death_screen.respawn_hold', {cost = Config.BillCost}),
        }
    })
end

local function SetDeathFilter(strength)
    local cfg = Config.DeathScreen
    SetTimecycleModifierStrength(cfg.TimecycleStrength * strength)
    if cfg.ExtraTimecycle then
        SetExtraTimecycleModifierStrength(cfg.ExtraTimecycleStrength * strength)
    end
end

local function ShowDeathScreen()
    local cfg = Config.DeathScreen
    deathScreenVisible = true
    deathScreenState = nil
    deathScreenToken = deathScreenToken + 1

    -- screen goes black, comes back black and white, then the timer animates in
    if cfg.FadeToBlack then
        DoScreenFadeOut(cfg.FadeOutTime)
        local timeout = GetGameTimer() + cfg.FadeOutTime + 1000
        while not IsScreenFadedOut() and GetGameTimer() < timeout do
            Wait(0)
        end
    end

    if cfg.Grayscale then
        SetTimecycleModifier(cfg.Timecycle)
        if cfg.ExtraTimecycle then
            SetExtraTimecycleModifier(cfg.ExtraTimecycle)
        end
        SetDeathFilter(1.0)
    end
    if cfg.CameraShake > 0 then
        ShakeGameplayCam('DRUNK_SHAKE', cfg.CameraShake)
    end

    if cfg.FadeToBlack then
        Wait(cfg.BlackTime)
    end
    SendShowMessage()
    if cfg.FadeToBlack then
        DoScreenFadeIn(cfg.FadeInTime)
    end
end

local function HideDeathScreen()
    local cfg = Config.DeathScreen
    deathScreenVisible = false
    deathScreenState = nil
    deathScreenToken = deathScreenToken + 1
    local token = deathScreenToken

    SendNUIMessage({ action = 'hide' })
    StopGameplayCamShaking(true)
    if IsScreenFadedOut() or IsScreenFadingOut() then
        DoScreenFadeIn(500)
    end
    if not cfg.Grayscale then return end

    -- colour comes back smoothly
    CreateThread(function()
        local steps = 25
        for i = steps - 1, 0, -1 do
            if token ~= deathScreenToken then return end
            SetDeathFilter(i / steps)
            Wait(40)
        end
        if token ~= deathScreenToken then return end
        ClearTimecycleModifier()
        ClearExtraTimecycleModifier()
    end)
end

local function UpdateDeathScreen()
    local time = math.max(0, math.ceil(isDead and deathTime or LaststandTime))
    local canRespawn = isDead and deathTime <= 0
    local canRequestHelp = not emsNotified and (isDead or LaststandTime <= Config.MinimumRevive)
    local key = ('%s|%d|%s|%d|%s|%s'):format(isDead and 'dead' or 'bleeding', time, canRespawn, hold, emsNotified, canRequestHelp)
    if key == deathScreenState then return end
    deathScreenState = key
    SendNUIMessage({
        action = 'update',
        mode = isDead and 'dead' or 'bleeding',
        time = time,
        canRespawn = canRespawn,
        hold = hold,
        holdMax = respawnHold,
        helpRequested = emsNotified,
        canRequestHelp = canRequestHelp,
    })
end

RegisterNUICallback('ready', function(_, cb)
    if not nuiReady then
        print('^2[qb-hospital] death screen page loaded^7')
    end
    nuiReady = true
    if deathScreenVisible then
        deathScreenState = nil
        SendShowMessage()
    end
    cb('ok')
end)

RegisterNUICallback('pageError', function(data, cb)
    print(('^1[qb-hospital] death screen page error (line %s): %s^7'):format(tostring(data.line), tostring(data.message)))
    cb('ok')
end)

CreateThread(function()
    Wait(20000)
    if not nuiReady then
        print('^1[qb-hospital] death screen page did not load. Run "refresh" then "ensure qb-hospital" in the server console and reconnect.^7')
    end
end)

-- /deathscreen : preview the death screen for 10 seconds without dying
RegisterCommand('deathscreen', function()
    if isDead or InLaststand then return end
    print(('[qb-hospital] death screen preview (page loaded: %s)'):format(tostring(nuiReady)))
    SendShowMessage()
    for t = 10, 0, -1 do
        SendNUIMessage({
            action = 'update', mode = t > 0 and 'bleeding' or 'dead', time = t,
            canRespawn = t == 0, hold = respawnHold, holdMax = respawnHold,
            helpRequested = false, canRequestHelp = true,
        })
        Wait(1000)
    end
    Wait(3000)
    if not (isDead or InLaststand) then
        SendNUIMessage({ action = 'hide' })
    end
end, false)

-- Threads

CreateThread(function()
	while true do
		Wait(10)
		local player = PlayerId()
		if NetworkIsPlayerActive(player) then
            local playerPed = PlayerPedId()
            if IsEntityDead(playerPed) and not InLaststand then

                local killer_2, killerWeapon = NetworkGetEntityKillerOfPlayer(player)
                local killer = GetPedSourceOfDeath(playerPed)

                if killer_2 ~= 0 and killer_2 ~= -1 then
                    killer = killer_2
                end
                SetLaststand(true, killer, killerWeapon)
            elseif IsEntityDead(playerPed) and InLaststand and not isDead then
                SetLaststand(false)
                local killer_2, killerWeapon = NetworkGetEntityKillerOfPlayer(player)
                local killer = GetPedSourceOfDeath(playerPed)

                if killer_2 ~= 0 and killer_2 ~= -1 then
                    killer = killer_2
                end

                local killerId = NetworkGetPlayerIndexFromPed(killer)
                local killerName = killerId ~= -1 and GetPlayerName(killerId) .. " " .. "("..GetPlayerServerId(killerId)..")" or Lang:t('info.self_death')
                local weaponLabel = Lang:t('info.wep_unknown')
                local weaponName = Lang:t('info.wep_unknown')
                local weaponItem = QBCore.Shared.Weapons[killerWeapon]
                if weaponItem then
                    weaponLabel = weaponItem.label
                    weaponName = weaponItem.name
                end
                TriggerServerEvent("qb-hospital:sv:sendkilllog", GetPlayerServerId(killerId), GetPlayerServerId(player), weaponLabel, weaponName)
                -- TriggerServerEvent("qb-log:server:CreateLog", 
                --     "death", 
                --     Lang:t('logs.death_log_title', {
                --         playername = GetPlayerName(player), playerid = GetPlayerServerId(player)
                --     }), 
                --     "red", 
                --     Lang:t('logs.death_log_message', {
                --         killername = killerName, playername = GetPlayerName(player), weaponlabel = weaponLabel, weaponname = weaponName
                --     })
                -- )
                deathTime = Config.DeathTime
                OnDeath()
                DeathTimer()
            end
		end
	end
end)

emsNotified = false


CreateThread(function()
	while true do
        local sleep = 1000
		if isDead or InLaststand then
            sleep = 5
            local ped = PlayerPedId()
            DisableAllControlActions(0)
            EnableControlAction(0, 1, true)
			EnableControlAction(0, 2, true)
			EnableControlAction(0, 245, true)
            EnableControlAction(0, 38, true)
            EnableControlAction(0, 0, true)
            EnableControlAction(0, 322, true)
            EnableControlAction(0, 288, true)
            EnableControlAction(0, 213, true)
            EnableControlAction(0, 249, true)
            EnableControlAction(0, 46, true)
            EnableControlAction(0, 47, true)

            if isDead then
                if not nuiReady and not isInHospitalBed then
                    if deathTime > 0 then
                        DrawTxt(0.93, 1.44, 1.0,1.0,0.6, Lang:t('info.respawn_txt', {deathtime = math.ceil(deathTime)}), 255, 255, 255, 255)
                    else
                        DrawTxt(0.865, 1.44, 1.0, 1.0, 0.6, Lang:t('info.respawn_revive', {holdtime = hold, cost = Config.BillCost}), 255, 255, 255, 255)
                    end
                end

                if not isInHospitalBed and IsControlJustPressed(0, 47) and not emsNotified then
                    EMSAlert(Lang:t('info.civ_died'))
                    emsNotified = true
                end

                if IsPedInAnyVehicle(ped, false) then
                    loadAnimDict("veh@low@front_ps@idle_duck")
                    if not IsEntityPlayingAnim(ped, "veh@low@front_ps@idle_duck", "sit", 3) then
                        TaskPlayAnim(ped, "veh@low@front_ps@idle_duck", "sit", 1.0, 1.0, -1, 1, 0, 0, 0, 0)
                    end
                else
                    if isInHospitalBed then
                        if not IsEntityPlayingAnim(ped, inBedDict, inBedAnim, 3) then
                            loadAnimDict(inBedDict)
                            TaskPlayAnim(ped, inBedDict, inBedAnim, 1.0, 1.0, -1, 1, 0, 0, 0, 0)
                        end
                    else
                        if not IsEntityPlayingAnim(ped, deadAnimDict, deadAnim, 3) then
                            loadAnimDict(deadAnimDict)
                            TaskPlayAnim(ped, deadAnimDict, deadAnim, 1.0, 1.0, -1, 1, 0, 0, 0, 0)
                        end
                    end
                end

                SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
            elseif InLaststand then
                sleep = 5

                if not nuiReady then
                    DrawTxt(0.845, 1.44, 1.0, 1.0, 0.6, Lang:t('info.bleed_out_help', {time = math.ceil(LaststandTime)}), 255, 255, 255, 255)
                    if not emsNotified then
                        DrawTxt(0.91, 1.40, 1.0, 1.0, 0.6, Lang:t('info.request_help'), 255, 255, 255, 255)
                    else
                        DrawTxt(0.90, 1.40, 1.0, 1.0, 0.6, Lang:t('info.help_requested'), 255, 255, 255, 255)
                    end
                end

                if LaststandTime <= Config.MinimumRevive then
                    if IsControlJustPressed(0, 47) and not emsNotified then
                        -- TriggerServerEvent('hospital:server:ambulanceAlert', Lang:t('info.civ_down'))
                        EMSAlert(Lang:t('info.civ_down'))
                        emsNotified = true
                    end
                end

                if not isEscorted then
                    if IsPedInAnyVehicle(ped, false) then
                        loadAnimDict("veh@low@front_ps@idle_duck")
                        if not IsEntityPlayingAnim(ped, "veh@low@front_ps@idle_duck", "sit", 3) then
                            TaskPlayAnim(ped, "veh@low@front_ps@idle_duck", "sit", 1.0, 1.0, -1, 1, 0, 0, 0, 0)
                        end
                    else
                        loadAnimDict(lastStandDict)
                        if not IsEntityPlayingAnim(ped, lastStandDict, lastStandAnim, 3) then
                            TaskPlayAnim(ped, lastStandDict, lastStandAnim, 1.0, 1.0, -1, 1, 0, 0, 0, 0)
                        end
                    end
                else
                    if IsPedInAnyVehicle(ped, false) then
                        loadAnimDict("veh@low@front_ps@idle_duck")
                        if IsEntityPlayingAnim(ped, "veh@low@front_ps@idle_duck", "sit", 3) then
                            StopAnimTask(ped, "veh@low@front_ps@idle_duck", "sit", 3)
                        end
                    else
                        loadAnimDict(lastStandDict)
                        if IsEntityPlayingAnim(ped, lastStandDict, lastStandAnim, 3) then
                            StopAnimTask(ped, lastStandDict, lastStandAnim, 3)
                        end
                    end
                end
            end
		end
        Wait(sleep)
	end
end)

CreateThread(function()
    while true do
        local sleep = 500
        if (isDead or InLaststand) and not isInHospitalBed then
            sleep = 250
            if not deathScreenVisible then
                ShowDeathScreen()
            end
            UpdateDeathScreen()
        elseif deathScreenVisible then
            HideDeathScreen()
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() and deathScreenVisible then
        ClearTimecycleModifier()
        ClearExtraTimecycleModifier()
        StopGameplayCamShaking(true)
    end
end)
