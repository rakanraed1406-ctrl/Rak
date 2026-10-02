local prevPos = nil
onPainKillers = false
local painkillerAmount = 0

-- Functions

local function DoBleedAlert()
    if not isDead and tonumber(isBleeding) > 0 then
        QBCore.Functions.Notify("You are "..Config.BleedingStates[tonumber(isBleeding)].label, "error", 5000)
    end
end

function RemoveBleed(level)
    if isBleeding ~= 0 then
        if isBleeding - level < 0 then
            isBleeding = 0
        else
            isBleeding = isBleeding - level
        end
        if isBleeding == 0 then
            bleedTickTimer, advanceBleedTimer, fadeOutTimer, blackoutTimer = 0, 0, 0, 0
        end
        DoBleedAlert()
        SyncInjuries()
    end
end

local function ApplyBleed(level)
    if isBleeding ~= 4 then
        if isBleeding + level > 4 then
            isBleeding = 4
        else
            isBleeding = isBleeding + level
        end
        DoBleedAlert()
        SyncInjuries()
    end
end

-- Painkiller doses (each dose = Config.PainkillerInterval seconds, max 3 stacked)
function AddPainkillerDose(doses)
    onPainKillers = true
    painkillerAmount = math.min(3, painkillerAmount + (doses or 1))
    SyncInjuries()
end

-- Prop in the hand while using a medical item
local function HoldProp(model, bone, offset, rot)
    local hash = joaat(model)
    if not IsModelInCdimage(hash) then return nil end
    RequestModel(hash)
    local timeout = GetGameTimer() + 3000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do Wait(10) end
    if not HasModelLoaded(hash) then return nil end
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    local obj = CreateObject(hash, c.x, c.y, c.z + 0.2, true, true, false)
    AttachEntityToEntity(obj, ped, GetPedBoneIndex(ped, bone), offset.x, offset.y, offset.z, rot.x, rot.y, rot.z, true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(hash)
    return obj
end

local function DropProp(obj)
    if obj and DoesEntityExist(obj) then DeleteEntity(obj) end
end

-- Events

RegisterNetEvent('hospital:client:UseIfaks', function()
    local ped = PlayerPedId()
    local prop = HoldProp('prop_cs_pills', 58866, vector3(0.11, -0.01, 0.0), vector3(-60.0, 0.0, 0.0))
    QBCore.Functions.Progressbar("use_bandage", Lang:t('progress.ifaks'), 3000, false, true, {
        disableMovement = false,
        disableCarMovement = false,
		disableMouse = false,
		disableCombat = true,
    }, {
		animDict = "mp_suicide",
		anim = "pill",
		flags = 49,
    }, {}, {}, function() -- Done
        StopAnimTask(ped, "mp_suicide", "pill", 1.0)
        DropProp(prop)
        TriggerServerEvent("hospital:server:ConsumeItem", "ifaks")
        TriggerServerEvent('hud:server:RelieveStress', math.random(12, 24))
        SetEntityHealth(ped, math.min(GetEntityMaxHealth(ped), GetEntityHealth(ped) + 10))
        AddPainkillerDose(1)
        if math.random(1, 100) < 50 then
            RemoveBleed(1)
        end
    end, function() -- Cancel
        StopAnimTask(ped, "mp_suicide", "pill", 1.0)
        DropProp(prop)
        QBCore.Functions.Notify(Lang:t('error.canceled'), "error")
    end)
end)

local healcount = 0
local isHealingLoop = false

-- +1 HP per second. Was starting a new loop on every call (the flag was local),
-- so two bandages healed twice as fast.
function AddHealth(amount)
    healcount = healcount + amount
    if isHealingLoop then return end
    isHealingLoop = true
    CreateThread(function()
        while healcount > 0 do
            Wait(1000)
            healcount = healcount - 1
            local ped = PlayerPedId()
            if isDead or InLaststand then healcount = 0 break end
            SetEntityHealth(ped, math.min(GetEntityMaxHealth(ped), GetEntityHealth(ped) + 1))
        end
        healcount = 0
        isHealingLoop = false
    end)
end

RegisterNetEvent('hospital:client:UseBandage', function()
    local ped = PlayerPedId()
    local prop = HoldProp('prop_ld_health_pack', 18905, vector3(0.12, 0.02, 0.06), vector3(-90.0, 0.0, 0.0))
    QBCore.Functions.Progressbar("use_bandage", Lang:t('progress.bandage'), 4000, false, true, {
        disableMovement = false,
        disableCarMovement = false,
		disableMouse = false,
		disableCombat = true,
    }, {
		animDict = "amb@world_human_clipboard@male@idle_a",
		anim = "idle_c",
		flags = 49,
    }, {}, {}, function() -- Done
        StopAnimTask(ped, "amb@world_human_clipboard@male@idle_a", "idle_c", 1.0)
        DropProp(prop)
        TriggerServerEvent("hospital:server:ConsumeItem", "bandage")
        if math.random(1, 100) < 50 then
            RemoveBleed(1)
        end
        if math.random(1, 100) < 7 then
            ResetPartial()
        end
        AddHealth(10)
    end, function() -- Cancel
        StopAnimTask(ped, "amb@world_human_clipboard@male@idle_a", "idle_c", 1.0)
        DropProp(prop)
        QBCore.Functions.Notify(Lang:t('error.canceled'), "error")
    end)
end)

RegisterNetEvent('hospital:client:UsePainkillers', function()
    local ped = PlayerPedId()
    local prop = HoldProp('prop_cs_pills', 58866, vector3(0.11, -0.01, 0.0), vector3(-60.0, 0.0, 0.0))
    QBCore.Functions.Progressbar("use_bandage", Lang:t('progress.painkillers'), 3000, false, true, {
        disableMovement = false,
        disableCarMovement = false,
		disableMouse = false,
		disableCombat = true,
    }, {
		animDict = "mp_suicide",
		anim = "pill",
		flags = 49,
    }, {}, {}, function() -- Done
        StopAnimTask(ped, "mp_suicide", "pill", 1.0)
        DropProp(prop)
        TriggerServerEvent("hospital:server:ConsumeItem", "painkillers")
        AddPainkillerDose(1)
    end, function() -- Cancel
        StopAnimTask(ped, "mp_suicide", "pill", 1.0)
        DropProp(prop)
        QBCore.Functions.Notify(Lang:t('error.canceled'), "error")
    end)
end)

-- Threads

CreateThread(function()
    while true do
        Wait(1)
        if onPainKillers then
            painkillerAmount = painkillerAmount - 1
            Wait(Config.PainkillerInterval * 1000)
            if painkillerAmount <= 0 then
                painkillerAmount = 0
                onPainKillers = false
                SyncInjuries()
            end
        else
            Wait(3000)
        end
    end
end)

CreateThread(function()
	while true do
		if #injured > 0 then
			local level = 0
			for k, v in pairs(injured) do
				if v.severity > level then
					level = v.severity
				end
			end
			SetPedMoveRateOverride(PlayerPedId(), Config.MovementRate[level])
			Wait(5)
		else
			Wait(1000)
		end
	end
end)

CreateThread(function()
    Wait(2500)
    prevPos = GetEntityCoords(PlayerPedId(), true)
    while true do
        Wait(1000)
        if isBleeding > 0 and not onPainKillers then
            local player = PlayerPedId()
            if bleedTickTimer >= Config.BleedTickRate and not isInHospitalBed then
                if not isDead and not InLaststand then
                    if isBleeding > 0 then
                        if fadeOutTimer + 1 == Config.FadeOutTimer then
                            if blackoutTimer + 1 == Config.BlackoutTimer then
                                SetFlash(0, 0, 100, 7000, 100)

                                DoScreenFadeOut(500)
                                while not IsScreenFadedOut() do
                                    Wait(0)
                                end

                                if not IsPedRagdoll(player) and IsPedOnFoot(player) and not IsPedSwimming(player) then
                                    ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.08) -- change this float to increase/decrease camera shake
                                    SetPedToRagdollWithFall(player, 7500, 9000, 1, GetEntityForwardVector(player), 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
                                end

                                Wait(1500)
                                DoScreenFadeIn(1000)
                                blackoutTimer = 0
                            else
                                DoScreenFadeOut(500)
                                while not IsScreenFadedOut() do
                                    Wait(0)
                                end
                                DoScreenFadeIn(500)

                                if isBleeding > 3 then
                                    blackoutTimer = blackoutTimer + 2
                                else
                                    blackoutTimer = blackoutTimer + 1
                                end
                            end

                            fadeOutTimer = 0
                        else
                            fadeOutTimer = fadeOutTimer + 1
                        end

                        local bleedDamage = tonumber(isBleeding) * Config.BleedTickDamage
                        ApplyDamageToPed(player, bleedDamage, false)
                        DoBleedAlert()
                        playerHealth = playerHealth - bleedDamage
                        local randX = math.random() + math.random(-1, 1)
                        local randY = math.random() + math.random(-1, 1)
                        local coords = GetOffsetFromEntityInWorldCoords(player, randX, randY, 0)
                        TriggerServerEvent("evidence:server:CreateBloodDrop", QBCore.Functions.GetPlayerData().citizenid, QBCore.Functions.GetPlayerData().metadata["bloodtype"], coords)

                        if advanceBleedTimer >= Config.AdvanceBleedTimer then
                            ApplyBleed(1)
                            advanceBleedTimer = 0
                        else
                            advanceBleedTimer = advanceBleedTimer + 1
                        end
                    end
                end
                bleedTickTimer = 0
            else
                if math.floor(bleedTickTimer % (Config.BleedTickRate / 10)) == 0 then
                    local currPos = GetEntityCoords(player, true)
                    local moving = #(vector2(prevPos.x, prevPos.y) - vector2(currPos.x, currPos.y))
                    if (moving > 1 and not IsPedInAnyVehicle(player)) and isBleeding > 2 then
                        advanceBleedTimer = advanceBleedTimer + Config.BleedMovementAdvance
                        bleedTickTimer = bleedTickTimer + Config.BleedMovementTick
                        prevPos = currPos
                    else
                        bleedTickTimer = bleedTickTimer + 1
                    end
                end
                bleedTickTimer = bleedTickTimer + 1
            end
        end
    end
end)
