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
                local vehseats = GetVehicleModelNumberOfSeats(GetEntityModel(veh))
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
            -- asked for help while bleeding out and then the heart stopped:
            -- EMS automatically gets the red "no pulse" call too
            if emsNotified and EMSAlert then
                EMSAlert(Lang:t('info.civ_died'))
            end
        end
    end
end

local respawnRequestedAt = -1e9
local RESPAWN_RETRY_MS = 15000 -- if no bed was free, you can try again after this
local holdingRespawn = false

local function RespawnPending()
    return GetGameTimer() - respawnRequestedAt < RESPAWN_RETRY_MS
end

-- Death countdown + "hold E to respawn". Runs every frame so the hold reacts
-- instantly (it used to only look at E once per second).
function DeathTimer()
    hold = respawnHold
    local holdStart = nil
    local nextSecond = GetGameTimer() + 1000
    while isDead do
        Wait(0)
        local now = GetGameTimer()
        if now >= nextSecond then
            nextSecond = nextSecond + 1000
            if deathTime > 0 then deathTime = deathTime - 1 end
        end

        local pressed = IsControlPressed(0, 38) or IsDisabledControlPressed(0, 38)
        if deathTime <= 0 and not isInHospitalBed and not RespawnPending() and pressed then
            holdStart = holdStart or now
            holdingRespawn = true
            hold = math.max(0.0, respawnHold - (now - holdStart) / 1000)
            if hold <= 0 then
                respawnRequestedAt = now
                holdStart, holdingRespawn, hold = nil, false, respawnHold
                TriggerEvent("hospital:client:RespawnAtHospital")
            end
        elseif holdStart then
            holdStart, holdingRespawn, hold = nil, false, respawnHold
        end
    end
    holdingRespawn, hold = false, respawnHold
end

-- Death screen (html/)

local nuiReady = false
local deathScreenVisible = false
local respawnCost, respawnInsured = Config.BillCost, false
local deathScreenState = nil

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
            respawn_hold = respawnInsured
                and Lang:t('death_screen.respawn_hold_insured', {cost = respawnCost})
                or Lang:t('death_screen.respawn_hold', {cost = respawnCost}),
            respawning = Lang:t('death_screen.respawning'),
        }
    })
end

-- asks the server what this player pays (insurance → cheaper) and updates the E prompt
local function RefreshRespawnCost()
    QBCore.Functions.TriggerCallback('hospital:server:GetRespawnCost', function(cost, insured)
        respawnCost, respawnInsured = tonumber(cost) or Config.BillCost, insured == true
        if deathScreenVisible then
            SendNUIMessage({
                action = 'texts',
                respawn_hold = respawnInsured
                    and Lang:t('death_screen.respawn_hold_insured', {cost = respawnCost})
                    or Lang:t('death_screen.respawn_hold', {cost = respawnCost}),
            })
        end
    end)
end

-- one black & white filter, no screen fades, no camera shake
local function ShowDeathScreen()
    local cfg = Config.DeathScreen
    RefreshRespawnCost()
    deathScreenVisible = true
    deathScreenState = nil
    if cfg.Grayscale then
        SetTimecycleModifier(cfg.Timecycle)
        SetTimecycleModifierStrength(cfg.TimecycleStrength)
    end
    SendShowMessage()
end

local function HideDeathScreen()
    deathScreenVisible = false
    deathScreenState = nil
    respawnRequestedAt = -1e9
    SendNUIMessage({ action = 'hide' })
    if Config.DeathScreen.Grayscale then
        ClearTimecycleModifier()
    end
end

local function UpdateDeathScreen()
    local time = math.max(0, math.ceil(isDead and deathTime or LaststandTime))
    local canRespawn = isDead and deathTime <= 0 and not RespawnPending()
    local canRequestHelp = not emsNotified and (isDead or LaststandTime <= Config.MinimumRevive)
    local holdShown = math.floor(hold * 10 + 0.5) / 10
    local key = ('%s|%d|%s|%.1f|%s|%s'):format(isDead and 'dead' or 'bleeding', time, tostring(canRespawn), holdShown, tostring(emsNotified), tostring(canRequestHelp))
    if key == deathScreenState then return end
    deathScreenState = key
    SendNUIMessage({
        action = 'update',
        mode = isDead and 'dead' or 'bleeding',
        time = time,
        canRespawn = canRespawn,
        hold = holdShown,
        holdMax = respawnHold,
        respawning = isDead and deathTime <= 0 and RespawnPending(),
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
                -- finished off while down: the heart stops right away (timer 00:00, flat line)
                deathTime = 0
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
            EnableControlAction(0, 199, true) -- P (pause menu)
            EnableControlAction(0, 200, true) -- ESC (pause menu)

            if isDead then
                if not nuiReady and not isInHospitalBed then
                    if deathTime > 0 then
                        DrawTxt(0.93, 1.44, 1.0,1.0,0.6, Lang:t('info.respawn_txt', {deathtime = math.ceil(deathTime)}), 255, 255, 255, 255)
                    else
                        DrawTxt(0.865, 1.44, 1.0, 1.0, 0.6, Lang:t('info.respawn_revive', {holdtime = math.ceil(hold), cost = respawnCost}), 255, 255, 255, 255)
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
            sleep = holdingRespawn and 50 or 250
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
    end
end)
