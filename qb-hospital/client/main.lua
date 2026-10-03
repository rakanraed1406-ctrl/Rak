QBCore = exports['qb-core']:GetCoreObject()

local getOutDict = 'switch@franklin@bed'
local getOutAnim = 'sleep_getup_rubeyes'
local canLeaveBed = true
local bedOccupying = nil
local bedObject = nil
local bedOccupyingData = nil
local closestBed = nil
local doctorCount = 0
local CurrentDamageList = {}
inBedDict = "anim@gangops@morgue@table@"
inBedAnim = "body_search"
isInHospitalBed = false
isBleeding = 0
bleedTickTimer, advanceBleedTimer = 0, 0
fadeOutTimer, blackoutTimer = 0, 0
legCount = 0
armcount = 0
headCount = 0
playerHealth = nil
isDead = false
isStatusChecking = false
statusChecks = {}
statusCheckTime = 0
isHealingPerson = false
healAnimDict = "mini@cpr@char_a@cpr_str"
healAnim = "cpr_pumpchest"
injured = {}
local bedText = false
JustHealed = false
isCheckIn = false

BodyParts = {
    ['HEAD'] =          { label = Lang:t('body.head'),          causeLimp = false, isDamaged = false, severity = 0 },
    ['NECK'] =          { label = Lang:t('body.neck'),          causeLimp = false, isDamaged = false, severity = 0 },
    ['SPINE'] =         { label = Lang:t('body.spine'),         causeLimp = true, isDamaged = false, severity = 0 },
    ['UPPER_BODY'] =    { label = Lang:t('body.upper_body'),    causeLimp = false, isDamaged = false, severity = 0 },
    ['LOWER_BODY'] =    { label = Lang:t('body.lower_body'),    causeLimp = true, isDamaged = false, severity = 0 },
    ['LARM'] =          { label = Lang:t('body.left_arm'),      causeLimp = false, isDamaged = false, severity = 0 },
    ['LHAND'] =         { label = Lang:t('body.left_hand'),     causeLimp = false, isDamaged = false, severity = 0 },
    ['LFINGER'] =       { label = Lang:t('body.left_fingers'),  causeLimp = false, isDamaged = false, severity = 0 },
    ['LLEG'] =          { label = Lang:t('body.left_leg'),      causeLimp = true, isDamaged = false, severity = 0 },
    ['LFOOT'] =         { label = Lang:t('body.left_foot'),     causeLimp = true, isDamaged = false, severity = 0 },
    ['RARM'] =          { label = Lang:t('body.right_arm'),     causeLimp = false, isDamaged = false, severity = 0 },
    ['RHAND'] =         { label = Lang:t('body.right_hand'),    causeLimp = false, isDamaged = false, severity = 0 },
    ['RFINGER'] =       { label = Lang:t('body.right_fingers'), causeLimp = false, isDamaged = false, severity = 0 },
    ['RLEG'] =          { label = Lang:t('body.right_leg'),     causeLimp = true, isDamaged = false, severity = 0 },
    ['RFOOT'] =         { label = Lang:t('body.right_foot'),    causeLimp = true, isDamaged = false, severity = 0 },
}

-- Functions

-- Fuel for EMS vehicles: works with LegacyFuel, cdn-fuel, ps-fuel, ox_fuel... or none.
function SetFuel(veh, amount)
    for _, res in ipairs({ 'LegacyFuel', 'cdn-fuel', 'ps-fuel', 'lj-fuel' }) do
        if GetResourceState(res) == 'started' then
            if pcall(function() exports[res]:SetFuel(veh, amount) end) then return end
        end
    end
    if Entity then Entity(veh).state.fuel = amount end -- ox_fuel
    SetVehicleFuelLevel(veh, amount)
end

-- Sends this player's injuries to the server (EMS tablet, vitals monitor, /status).
function SyncInjuries()
    TriggerServerEvent('hospital:server:SyncInjuries', {
        limbs = BodyParts,
        isBleeding = tonumber(isBleeding) or 0,
        onPainKillers = onPainKillers == true,
    })
end

local function GetAvailableBed(bedId)
    local pos = GetEntityCoords(PlayerPedId())
    local retval = nil
    if bedId == nil then
        for k, v in pairs(Config.Locations["beds"]) do
            if not Config.Locations["beds"][k].taken then
                if #(pos - vector3(Config.Locations["beds"][k].coords.x, Config.Locations["beds"][k].coords.y, Config.Locations["beds"][k].coords.z)) < 500 then
                        retval = k
                end
            end
        end
    else
        if not Config.Locations["beds"][bedId].taken then
            if #(pos - vector3(Config.Locations["beds"][bedId].coords.x, Config.Locations["beds"][bedId].coords.y, Config.Locations["beds"][bedId].coords.z))  < 500 then
                retval = bedId
            end
        end
    end
    return retval
end

local function GetAvailableBedsandy(bedId)
    local pos = GetEntityCoords(PlayerPedId())
    local retval = nil
    if bedId == nil then
        for k, v in pairs(Config.Locations["bedssandy"]) do
            if not Config.Locations["bedssandy"][k].taken then
                if #(pos - vector3(Config.Locations["bedssandy"][k].coords.x, Config.Locations["bedssandy"][k].coords.y, Config.Locations["bedssandy"][k].coords.z)) < 500 then
                        retval = k
                end
            end
        end
    else
        if not Config.Locations["bedssandy"][bedId].taken then
            if #(pos - vector3(Config.Locations["bedssandy"][bedId].coords.x, Config.Locations["bedssandy"][bedId].coords.y, Config.Locations["bedssandy"][bedId].coords.z))  < 500 then
                retval = bedId
            end
        end
    end
    return retval
end

local function GetDamagingWeapon(ped)
    for k, v in pairs(Config.Weapons) do
        if HasPedBeenDamagedByWeapon(ped, k, 0) then
            return v
        end
    end

    return nil
end

local function IsDamagingEvent(damageDone, weapon)
    local luck = math.random(100)
    local multi = damageDone / Config.HealthDamage

    return luck < (Config.HealthDamage * multi) or (damageDone >= Config.ForceInjury or multi > Config.MaxInjuryChanceMulti or Config.ForceInjuryWeapons[weapon])
end

local function DoLimbAlert()
    if not isDead and not InLaststand then
        if #injured > 0 then
            local limbDamageMsg = ''
            if #injured <= Config.AlertShowInfo then
                for k, v in pairs(injured) do
                    limbDamageMsg = limbDamageMsg..Lang:t('info.pain_message', {limb = v.label, severity = Config.WoundStates[v.severity]})
                    if k < #injured then
                        limbDamageMsg = limbDamageMsg .. " | "
                    end
                end
            else
                limbDamageMsg = Lang:t('info.many_places')
            end
            QBCore.Functions.Notify(limbDamageMsg, "primary")
        end
    end
end

local function DoBleedAlert()
    if not isDead and tonumber(isBleeding) > 0 then
        QBCore.Functions.Notify(Lang:t('info.bleed_alert', {bleedstate = Config.BleedingStates[tonumber(isBleeding)].label}), "error")
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

local function SetClosestBed()
    local pos = GetEntityCoords(PlayerPedId(), true)
    local current = nil
    local dist = nil
    for k, v in pairs(Config.Locations["beds"]) do
        local dist2 = #(pos - vector3(Config.Locations["beds"][k].coords.x, Config.Locations["beds"][k].coords.y, Config.Locations["beds"][k].coords.z))
        if current then
            if dist2 < dist then
                current = k
                dist = dist2
            end
        else
            dist = dist2
            current = k
        end
    end
    if current ~= closestBed and not isInHospitalBed then
        closestBed = current
    end
end

local function IsInjuryCausingLimp()
    for k, v in pairs(BodyParts) do
        if v.causeLimp and v.isDamaged then
            return true
        end
    end
    return false
end

local function ProcessRunStuff(ped)
    if IsInjuryCausingLimp() then
        RequestAnimSet("move_m@injured")
        while not HasAnimSetLoaded("move_m@injured") do
            Wait(0)
        end
        SetPedMovementClipset(ped, "move_m@injured", 1 )
        SetPlayerSprint(PlayerId(), false)
    end
end

function ResetPartial()
    for k, v in pairs(BodyParts) do
        if v.isDamaged and v.severity <= 2 then
            v.isDamaged = false
            v.severity = 0
        end
    end

    for k, v in pairs(injured) do
        if v.severity <= 2 then
            v.severity = 0
            table.remove(injured, k)
        end
    end

    if isBleeding <= 2 then
        isBleeding = 0
        bleedTickTimer = 0
        advanceBleedTimer = 0
        fadeOutTimer = 0
        blackoutTimer = 0
    end

    SyncInjuries()

    ProcessRunStuff(PlayerPedId())
    DoLimbAlert()
    DoBleedAlert()

    SyncInjuries()
end

exports('GetPlayerBleeding', function()
    return isBleeding
end)

local function ResetAll()
    isBleeding = 0
    bleedTickTimer = 0
    advanceBleedTimer = 0
    fadeOutTimer = 0
    blackoutTimer = 0
    onDrugs = 0
    wasOnDrugs = false
    onPainKiller = 0
    onPainKillers = false -- was never reset after a revive / full heal
    wasOnPainKillers = false
    injured = {}

    for k, v in pairs(BodyParts) do
        v.isDamaged = false
        v.severity = 0
    end

    SyncInjuries()

    CurrentDamageList = {}
    TriggerServerEvent('hospital:server:SetWeaponDamage', CurrentDamageList)

    ProcessRunStuff(PlayerPedId())
    DoLimbAlert()
    DoBleedAlert()

    SyncInjuries()
    TriggerServerEvent("hospital:server:SetMetaData")
    -- TriggerServerEvent("QBCore:Server:SetMetaData", "hunger", 100)
    -- TriggerServerEvent("QBCore:Server:SetMetaData", "thirst", 100)
end

local function loadAnimDict(dict)
	while(not HasAnimDictLoaded(dict)) do
		RequestAnimDict(dict)
		Wait(1)
	end
end

local function SetBedCam()
    isInHospitalBed = true
    canLeaveBed = false
    local player = PlayerPedId()

    DoScreenFadeOut(1000)

    local fadeTimeout = GetGameTimer() + 3000
    while not IsScreenFadedOut() and GetGameTimer() < fadeTimeout do
        Wait(100)
    end

	if IsPedDeadOrDying(player) then
		local pos = GetEntityCoords(player, true)
		NetworkResurrectLocalPlayer(pos.x, pos.y, pos.z, GetEntityHeading(player), true, false)
        player = PlayerPedId()
    end
    if IsPedInAnyVehicle(player, false) then
        ClearPedTasksImmediately(player) -- out of the car before the teleport
    end

    -- load the hospital (interior + collision) before putting the patient in the
    -- bed, otherwise you can fall through the floor after a long-distance respawn
    local c = bedOccupyingData.coords
    FreezeEntityPosition(player, true)
    SetEntityCoords(player, c.x, c.y, c.z + 0.02, false, false, false, false)
    RequestCollisionAtCoord(c.x, c.y, c.z)
    local interior = GetInteriorAtCoords(c.x, c.y, c.z)
    if interior ~= 0 then
        PinInteriorInMemory(interior)
        local t = GetGameTimer() + 5000
        while not IsInteriorReady(interior) and GetGameTimer() < t do Wait(50) end
    end
    local t = GetGameTimer() + 5000
    while not HasCollisionLoadedAroundEntity(player) and GetGameTimer() < t do
        RequestCollisionAtCoord(c.x, c.y, c.z)
        Wait(50)
    end

    bedObject = GetClosestObjectOfType(c.x, c.y, c.z, 1.0, bedOccupyingData.model, false, false, false)
    if bedObject ~= 0 then FreezeEntityPosition(bedObject, true) end

    SetEntityCoords(player, c.x, c.y, c.z + 0.02, false, false, false, false)
    --SetEntityInvincible(PlayerPedId(), true)
    Wait(500)
    FreezeEntityPosition(player, true)

    loadAnimDict(inBedDict)

    TaskPlayAnim(player, inBedDict , inBedAnim, 8.0, 1.0, -1, 1, 0, 0, 0, 0 )
    SetEntityHeading(player, bedOccupyingData.coords.w)

    cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", 1)
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 1, true, true)
    AttachCamToPedBone(cam, player, 31085, 0, 1.0, 1.0 , true)
    SetCamFov(cam, 90.0)
    local heading = GetEntityHeading(player)
    heading = (heading > 180) and heading - 180 or heading + 180
    SetCamRot(cam, -45.0, 0.0, heading, 2)

    DoScreenFadeIn(1000)

    Wait(1000)
    FreezeEntityPosition(player, true)
end

-- NetworkResurrectLocalPlayer recreates the ped: on a hospital bed that lost the
-- bed position/freeze and the player could fall through the floor. Put it back.
function KeepInBed()
    if not isInHospitalBed or not bedOccupyingData then return end
    local player = PlayerPedId()
    local c = bedOccupyingData.coords
    SetEntityCoords(player, c.x, c.y, c.z + 0.02, false, false, false, false)
    SetEntityHeading(player, c.w)
    FreezeEntityPosition(player, true)
    loadAnimDict(inBedDict)
    TaskPlayAnim(player, inBedDict, inBedAnim, 8.0, 1.0, -1, 1, 0, 0, 0, 0)
end

local function LeaveBed()
    exports['qb-ui']:HideText()
    bedText = false
    local player = PlayerPedId()

    RequestAnimDict(getOutDict)
    while not HasAnimDictLoaded(getOutDict) do
        Wait(0)
    end

    FreezeEntityPosition(player, false)
    SetEntityInvincible(player, false)
    SetEntityHeading(player, bedOccupyingData.coords.w + 90)
    TaskPlayAnim(player, getOutDict , getOutAnim, 100.0, 1.0, -1, 8, -1, 0, 0, 0)
    Wait(4000)
    ClearPedTasks(player)
    TriggerServerEvent('hospital:server:LeaveBed', bedOccupying)
    FreezeEntityPosition(bedObject, true)
    RenderScriptCams(0, true, 200, true, true)
    DestroyCam(cam, false)

    bedOccupying = nil
    bedObject = nil
    bedOccupyingData = nil
    isInHospitalBed = false
    JustHealed = true
    isCheckIn = false
end

local function DrawText3D(x, y, z, text)
	SetTextScale(0.3, 0.3)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(true)
    AddTextComponentString(text)
    SetDrawOrigin(x,y,z, 0)
    DrawText(0.0, 0.0)
    local factor = (string.len(text)) / 400
    DrawRect(0.0, 0.0+0.0110, 0.017+ factor, 0.03, 0, 0, 0, 75)
    ClearDrawOrigin()
end

local function IsInDamageList(damage)
    local retval = false
    if CurrentDamageList then
        for k, v in pairs(CurrentDamageList) do
            if CurrentDamageList[k] == damage then
                retval = true
            end
        end
    end
    return retval
end

local function CheckWeaponDamage(ped)
    local detected = false
    for k, v in pairs(QBCore.Shared.Weapons) do
        if HasPedBeenDamagedByWeapon(ped, GetHashKey(k), 0) then
            detected = true
            if not IsInDamageList(k) then
                TriggerEvent('chat:addMessage', {
                    color = { 255, 0, 0},
                    multiline = false,
                    args = {Lang:t('info.status'), v.damagereason}
                })
                CurrentDamageList[#CurrentDamageList+1] = k
            end
        end
    end
    if detected then
        TriggerServerEvent("hospital:server:SetWeaponDamage", CurrentDamageList)
    end
    ClearEntityLastDamageEntity(ped)
end

local function ApplyImmediateEffects(ped, bone, weapon, damageDone)
    local armor = GetPedArmour(ped)
    if Config.MinorInjurWeapons[weapon] and damageDone < Config.DamageMinorToMajor then
        if Config.CriticalAreas[Config.Bones[bone]] then
            if armor <= 0 then
                ApplyBleed(1)
            end
        end

        if Config.StaggerAreas[Config.Bones[bone]] and (Config.StaggerAreas[Config.Bones[bone]].armored or armor <= 0) then
            if math.random(100) <= math.ceil(Config.StaggerAreas[Config.Bones[bone]].minor) then
                -- SetPedToRagdoll(ped, 1500, 2000, 3, true, true, false)
            end
        end
    elseif Config.MajorInjurWeapons[weapon] or (Config.MinorInjurWeapons[weapon] and damageDone >= Config.DamageMinorToMajor) then
        if Config.CriticalAreas[Config.Bones[bone]] then
            if armor > 0 and Config.CriticalAreas[Config.Bones[bone]].armored then
                if math.random(100) <= math.ceil(Config.MajorArmoredBleedChance) then
                    ApplyBleed(1)
                end
            else
                ApplyBleed(1)
            end
        else
            if armor > 0 then
                if math.random(100) < (Config.MajorArmoredBleedChance) then
                    ApplyBleed(1)
                end
            else
                if math.random(100) < (Config.MajorArmoredBleedChance * 2) then
                    ApplyBleed(1)
                end
            end
        end

        if Config.StaggerAreas[Config.Bones[bone]] and (Config.StaggerAreas[Config.Bones[bone]].armored or armor <= 0) then
            if math.random(100) <= math.ceil(Config.StaggerAreas[Config.Bones[bone]].major) then
                -- SetPedToRagdoll(ped, 1500, 2000, 3, true, true, false)
            end
        end
    end
end

local function CheckDamage(ped, bone, weapon, damageDone)
    if weapon == nil then return end

    if Config.Bones[bone] and not isDead and not InLaststand then
        ApplyImmediateEffects(ped, bone, weapon, damageDone)

        if not BodyParts[Config.Bones[bone]].isDamaged then
            BodyParts[Config.Bones[bone]].isDamaged = true
            BodyParts[Config.Bones[bone]].severity = math.random(1, 3)
            injured[#injured+1] = {
                part = Config.Bones[bone],
                label = BodyParts[Config.Bones[bone]].label,
                severity = BodyParts[Config.Bones[bone]].severity
            }
        else
            if BodyParts[Config.Bones[bone]].severity < 4 then
                BodyParts[Config.Bones[bone]].severity = BodyParts[Config.Bones[bone]].severity + 1

                for k, v in pairs(injured) do
                    if v.part == Config.Bones[bone] then
                        v.severity = BodyParts[Config.Bones[bone]].severity
                    end
                end
            end
        end

        SyncInjuries()

        ProcessRunStuff(ped)
    end
end

local function ProcessDamage(ped)
    if not isDead and not InLaststand and not onPainKillers then
        for k, v in pairs(injured) do
            if (v.part == 'LLEG' and v.severity > 1) or (v.part == 'RLEG' and v.severity > 1) or (v.part == 'LFOOT' and v.severity > 2) or (v.part == 'RFOOT' and v.severity > 2) then
                if legCount >= Config.LegInjuryTimer then
                    if not IsPedRagdoll(ped) and IsPedOnFoot(ped) then
                        local chance = math.random(100)
                        if (IsPedRunning(ped) or IsPedSprinting(ped)) then
                            if chance <= Config.LegInjuryChance.Running then
                                ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.08) -- change this float to increase/decrease camera shake
                                -- SetPedToRagdollWithFall(ped, 1500, 2000, 1, GetEntityForwardVector(ped), 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
                            end
                        else
                            if chance <= Config.LegInjuryChance.Walking then
                                ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.08) -- change this float to increase/decrease camera shake
                                -- SetPedToRagdollWithFall(ped, 1500, 2000, 1, GetEntityForwardVector(ped), 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
                            end
                        end
                    end
                    legCount = 0
                else
                    legCount = legCount + 1
                end
            elseif (v.part == 'LARM' and v.severity > 1) or (v.part == 'LHAND' and v.severity > 1) or (v.part == 'LFINGER' and v.severity > 2) or (v.part == 'RARM' and v.severity > 1) or (v.part == 'RHAND' and v.severity > 1) or (v.part == 'RFINGER' and v.severity > 2) then
                if armcount >= Config.ArmInjuryTimer then
                    local chance = math.random(100)

                    if (v.part == 'LARM' and v.severity > 1) or (v.part == 'LHAND' and v.severity > 1) or (v.part == 'LFINGER' and v.severity > 2) then
                        local isDisabled = 15
                        CreateThread(function()
                            while isDisabled > 0 do
                                if IsPedInAnyVehicle(ped, true) then
                                    DisableControlAction(0, 63, true) -- veh turn left
                                end

                                if IsPlayerFreeAiming(PlayerId()) then
                                    DisablePlayerFiring(PlayerId(), true) -- Disable weapon firing
                                end

                                isDisabled = isDisabled - 1
                                Wait(1)
                            end
                        end)
                    else
                        local isDisabled = 15
                        CreateThread(function()
                            while isDisabled > 0 do
                                if IsPedInAnyVehicle(ped, true) then
                                    DisableControlAction(0, 63, true) -- veh turn left
                                end

                                if IsPlayerFreeAiming(PlayerId()) then
                                    DisableControlAction(0, 25, true) -- Disable weapon firing
                                end

                                isDisabled = isDisabled - 1
                                Wait(1)
                            end
                        end)
                    end

                    armcount = 0
                else
                    armcount = armcount + 1
                end
            elseif (v.part == 'HEAD' and v.severity > 2) then
                if headCount >= Config.HeadInjuryTimer then
                    local chance = math.random(100)

                    if chance <= Config.HeadInjuryChance then
                        SetFlash(0, 0, 100, 10000, 100)

                        DoScreenFadeOut(100)
                        while not IsScreenFadedOut() do
                            Wait(0)
                        end

                        if not IsPedRagdoll(ped) and IsPedOnFoot(ped) and not IsPedSwimming(ped) then
                            ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.08) -- change this float to increase/decrease camera shake
                            -- SetPedToRagdoll(ped, 5000, 1, 2)
                        end

                        Wait(5000)
                        DoScreenFadeIn(250)
                    end
                    headCount = 0
                else
                    headCount = headCount + 1
                end
            end
        end
    end
end

-- Events

RegisterNetEvent('hospital:client:ambulanceAlert', function(coords, text, name, ID)
    PlayerData = QBCore.Functions.GetPlayerData()
    if not PlayerData then return end
    if not PlayerData.job then return end
    if not PlayerData.job.name then return end
    if PlayerData.job.name == 'ambulance' or PlayerData.job.name == 'doctor' then 
        local street1, street2 = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
        local street1name = GetStreetNameFromHashKey(street1)
        local street2name = GetStreetNameFromHashKey(street2)
        if name then 
            PlaySound(-1, "Lose_1st", "GTAO_FM_Events_Soundset", 0, 0, 1)
            TriggerEvent('chatMessage', "997 ", 'warning', "Name :["..ID.."] "..name.." : "..text.."")
        end
        local transG = 250
        local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
        local blip2 = AddBlipForCoord(coords.x, coords.y, coords.z)
        local blipText = Lang:t('info.ems_alert', {text = text})
        SetBlipSprite(blip, 153)
        SetBlipSprite(blip2, 161)
        SetBlipColour(blip, 1)
        SetBlipColour(blip2, 1)
        SetBlipDisplay(blip, 4)
        SetBlipDisplay(blip2, 8)
        SetBlipAlpha(blip, transG)
        SetBlipAlpha(blip2, transG)
        SetBlipScale(blip, 0.8)
        SetBlipScale(blip2, 2.0)
        SetBlipAsShortRange(blip, false)
        SetBlipAsShortRange(blip2, false)
        PulseBlip(blip2)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(blipText)
        EndTextCommandSetBlipName(blip)
        while transG ~= 0 do
            Wait(180 * 4)
            transG = transG - 1
            SetBlipAlpha(blip, transG)
            SetBlipAlpha(blip2, transG)
            if transG == 0 then
                RemoveBlip(blip)
                return
            end
        end
    end
end)

local function HospitalStreetLabel()
    local coords = GetEntityCoords(PlayerPedId())
    local s1, s2 = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local street1, street2 = GetStreetNameFromHashKey(s1), GetStreetNameFromHashKey(s2)
    if street2 and street2 ~= '' then return street1 .. ' / ' .. street2 end
    return street1
end

-- "Request help" on the death screen (G). Goes to the EMS tablet (mdt-ems-tablet)
-- through the server with the patient's condition — cd_dispatch is no longer used.
function EMSAlert(msg)
    local info = { street = HospitalStreetLabel(), injuries = {} }

    local bleed = tonumber(isBleeding) or 0
    if bleed > 0 and Config.BleedingStates[bleed] then
        info.bleeding = Config.BleedingStates[bleed].label
    end
    for _, v in pairs(injured) do
        if v.label then info.injuries[#info.injuries + 1] = v.label end
    end
    local lastWeapon = CurrentDamageList[#CurrentDamageList]
    if lastWeapon then
        local weapon = QBCore.Shared.Weapons[lastWeapon]
        info.cause = weapon and weapon.label or tostring(lastWeapon)
    end

    TriggerServerEvent('hospital:server:ambulanceAlert', msg, isDead and 'dead' or 'down', info)
end



RegisterNetEvent('hospital:client:Revive', function()
    local player = PlayerPedId()

    if isDead or InLaststand then
        local pos = GetEntityCoords(player, true)
        NetworkResurrectLocalPlayer(pos.x, pos.y, pos.z, GetEntityHeading(player), true, false)
        isDead = false
        SetEntityInvincible(player, false)
        SetLaststand(false)
    end

    player = PlayerPedId() -- the resurrect above can give a new ped handle
    if isInHospitalBed then
        KeepInBed()
        SetEntityInvincible(player, true)
        canLeaveBed = true
    end

    JustHealed = true

    TriggerServerEvent("hospital:server:RestoreWeaponDamage")
    SetEntityMaxHealth(player, 200)
    SetEntityHealth(player, 200)
    ClearPedBloodDamage(player)
    SetPlayerSprint(PlayerId(), true)
    ResetAll()
    -- ResetPedMovementClipset(player, 0.0)
    -- TriggerServerEvent('hud:server:RelieveStress', 100)
    TriggerServerEvent("hospital:server:SetDeathStatus", false)
    TriggerServerEvent("hospital:server:SetLaststandStatus", false)
    emsNotified = false
    QBCore.Functions.Notify(Lang:t('info.healthy'),'warn',3000)
end)

RegisterNetEvent('hospital:client:SetPain', function()
    ApplyBleed(math.random(1,4))
    if not BodyParts[Config.Bones[24816]].isDamaged then
        BodyParts[Config.Bones[24816]].isDamaged = true
        BodyParts[Config.Bones[24816]].severity = math.random(1, 4)
        injured[#injured+1] = {
            part = Config.Bones[24816],
            label = BodyParts[Config.Bones[24816]].label,
            severity = BodyParts[Config.Bones[24816]].severity
        }
    end

    if not BodyParts[Config.Bones[40269]].isDamaged then
        BodyParts[Config.Bones[40269]].isDamaged = true
        BodyParts[Config.Bones[40269]].severity = math.random(1, 4)
        injured[#injured+1] = {
            part = Config.Bones[40269],
            label = BodyParts[Config.Bones[40269]].label,
            severity = BodyParts[Config.Bones[40269]].severity
        }
    end

    SyncInjuries()
end)

RegisterNetEvent('hospital:client:KillPlayer', function()
    SetEntityHealth(PlayerPedId(), 0)
end)

local function ResetPlayer()
    local player = PlayerPedId()
    isBleeding = 0
    bleedTickTimer = 0
    advanceBleedTimer = 0
    fadeOutTimer = 0
    blackoutTimer = 0
    onDrugs = 0
    wasOnDrugs = false
    onPainKiller = 0
    onPainKillers = false -- was never reset after a revive / full heal
    wasOnPainKillers = false
    injured = {}

    for k, v in pairs(BodyParts) do
        v.isDamaged = false
        v.severity = 0
    end

    SyncInjuries()

    CurrentDamageList = {}
    TriggerServerEvent('hospital:server:SetWeaponDamage', CurrentDamageList)

    SetEntityMaxHealth(player, 200)
    SetEntityHealth(player, 200)
    ClearPedBloodDamage(player)

    ProcessRunStuff(PlayerPedId())
    DoLimbAlert()
    DoBleedAlert()

    SyncInjuries()
    TriggerServerEvent("hospital:server:SetMetaData")
    -- TriggerServerEvent("QBCore:Server:SetMetaData", "hunger", 100)
    -- TriggerServerEvent("QBCore:Server:SetMetaData", "thirst", 100)
end

RegisterNetEvent('hospital:client:HealInjuries', function(type)
    if type == "full" then
        ResetPlayer()
    else
        ResetPartial()
    end
    TriggerServerEvent("hospital:server:RestoreWeaponDamage")
    QBCore.Functions.Notify(Lang:t('success.wounds_healed'), 'success')
end)

RegisterNetEvent('hospital:client:SendToBed', function(id, data, isRevive)
    bedOccupying = id
    bedOccupyingData = data
    SetBedCam()
    CreateThread(function ()
        Wait(5)
        if isRevive then
            -- Wait(Config.AIHealTimer * 1000)
            QBCore.Functions.Progressbar("hospital_checkin", Lang:t('success.being_helped'), Config.AIHealTimer * 1000, false, true, {
                disableMovement = true,
                disableCarMovement = true,
                disableMouse = false,
                disableCombat = true,
            }, {}, {}, {}, function() -- Done
            TriggerEvent("hospital:client:Revive")
        end)
        else
            canLeaveBed = true
        end
    end)
end)

RegisterNetEvent('hospital:client:SendToBedsandy', function(id, data, isRevive)
    bedOccupying = id
    bedOccupyingData = data
    SetBedCam()
    CreateThread(function ()
        Wait(5)
        if isRevive then
            -- Wait(Config.AIHealTimer * 1000)
            QBCore.Functions.Progressbar("hospital_checkin", Lang:t('success.being_helped'), Config.AIHealTimer * 1000, false, true, {
                disableMovement = true,
                disableCarMovement = true,
                disableMouse = false,
                disableCombat = true,
            }, {}, {}, {}, function() -- Done
            TriggerEvent("hospital:client:Revive")
        end)
        else
            canLeaveBed = true
        end
    end)
end)

RegisterNetEvent('hospital:client:SetBed', function(id, isTaken)
    Config.Locations["beds"][id].taken = isTaken
end)

RegisterNetEvent('hospital:client:SetBedsandy', function(id, isTaken)
    Config.Locations["bedssandy"][id].taken = isTaken
end)

RegisterNetEvent('hospital:client:RespawnAtHospital', function()
    TriggerServerEvent("hospital:server:RespawnAtHospital")
    -- qb-police is optional (the export used to throw an error without it)
    if GetResourceState('qb-police') == 'started' then
        local ok, cuffed = pcall(function() return exports["qb-police"]:IsHandcuffed() end)
        if ok and cuffed then TriggerEvent("police:client:GetCuffed", -1) end
    end
    TriggerEvent("police:client:DeEscort")
end)

RegisterNetEvent('hospital:client:SendBillEmail', function(amount)
    SetTimeout(math.random(2500, 4000), function()
        local gender = Lang:t('info.mr')
        if QBCore.Functions.GetPlayerData().charinfo.gender == 1 then
            gender = Lang:t('info.mrs')
        end
        local charinfo = QBCore.Functions.GetPlayerData().charinfo
        TriggerServerEvent('qb-phone:server:sendNewMail', {
            sender = Lang:t('mail.sender'),
            subject = Lang:t('mail.subject'),
            message = Lang:t('mail.message', {gender = gender, lastname = charinfo.lastname, costs = amount}),
            button = {}
        })
    end)
end)

RegisterNetEvent('hospital:client:SetDoctorCount', function(amount)
    doctorCount = amount
end)

local function AdminResetAll()
    isBleeding = 0
    bleedTickTimer = 0
    advanceBleedTimer = 0
    fadeOutTimer = 0
    blackoutTimer = 0
    onDrugs = 0
    wasOnDrugs = false
    onPainKiller = 0
    onPainKillers = false -- was never reset after a revive / full heal
    wasOnPainKillers = false
    injured = {}

    for k, v in pairs(BodyParts) do
        v.isDamaged = false
        v.severity = 0
    end

    SyncInjuries()

    CurrentDamageList = {}
    TriggerServerEvent('hospital:server:SetWeaponDamage', CurrentDamageList)

    ProcessRunStuff(PlayerPedId())
    DoLimbAlert()
    DoBleedAlert()

    SyncInjuries()
    -- food & water are refilled by the server (/arevive), not by the client
end

RegisterNetEvent('hospital:client:adminHeal', function()
    local player = PlayerPedId()

    if isDead or InLaststand then
        local pos = GetEntityCoords(player, true)
        NetworkResurrectLocalPlayer(pos.x, pos.y, pos.z, GetEntityHeading(player), true, false)
        isDead = false
        SetEntityInvincible(player, false)
        SetLaststand(false)
    end

    player = PlayerPedId() -- the resurrect above can give a new ped handle
    if isInHospitalBed then
        KeepInBed()
        SetEntityInvincible(player, true)
        canLeaveBed = true
    end

    JustHealed = true

    TriggerServerEvent("hospital:server:RestoreWeaponDamage")
    SetEntityMaxHealth(player, 200)
    SetEntityHealth(player, 200)
    ClearPedBloodDamage(player)
    SetPlayerSprint(PlayerId(), true)
    AdminResetAll()
    -- ResetPedMovementClipset(player, 0.0)
    -- TriggerServerEvent('hud:server:RelieveStress', 100)
    TriggerServerEvent("hospital:server:SetDeathStatus", false)
    TriggerServerEvent("hospital:server:SetLaststandStatus", false)
    emsNotified = false
    QBCore.Functions.Notify(Lang:t('info.healthy'),'success',3000)
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    local ped = PlayerPedId()
    -- The dead / last stand state is NOT cleared any more: logging out used to be a free
    -- revive. OnPlayerLoaded already puts you back on the ground when you come back.
    TriggerServerEvent("hospital:server:SetArmor", GetPedArmour(ped))
    if bedOccupying then
        TriggerServerEvent("hospital:server:LeaveBed", bedOccupying)
    end
    isDead = false
    deathTime = 0
    SetEntityInvincible(ped, false)
    SetPedArmour(ped, 0)
    ResetAll()
end)

-- Threads

CreateThread(function()
    for k, station in pairs(Config.Locations["stations"]) do
        local blip = AddBlipForCoord(station.coords.x, station.coords.y, station.coords.z)
        SetBlipSprite(blip, 61)
        SetBlipAsShortRange(blip, true)
        SetBlipScale(blip, 0.6)
        SetBlipColour(blip, 18)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(station.label)
        EndTextCommandSetBlipName(blip)
    end
end)

CreateThread(function()
    while true do
        sleep = 1000
        if isInHospitalBed and canLeaveBed then
            sleep = 0
            local pos = GetEntityCoords(PlayerPedId())
            -- DrawText3D(pos.x, pos.y, pos.z, Lang:t('text.bed_out'))
            if not bedText then 
                bedText = true 
                exports['qb-ui']:DrawText10("Leave Bed")
            end
            if IsControlJustReleased(0, 38) then
                LeaveBed()
            end
        end
        Wait(sleep)
    end
end)

local SprintCounter = 15
-- CreateThread(function()
--     while true do
--         local sleep = 1000
--         if JustHealed then 
--             sleep = 1
--             DisableControlAction(0,21,true) -- disable sprint
--             DisableControlAction(0,22,true) -- disable jump
--         end
--         Wait(sleep)
--     end
-- end)

CreateThread(function()
    while true do
        Wait((1000 * Config.MessageTimer))
        DoLimbAlert()
    end
end)

CreateThread(function()
    while true do
        Wait(1000)
        SetClosestBed()
        if isStatusChecking then
            statusCheckTime = statusCheckTime - 1
            if statusCheckTime <= 0 then
                statusChecks = {}
                isStatusChecking = false
            end
        end
        if JustHealed then 
            SprintCounter = SprintCounter - 1
            if SprintCounter <= 0 then 
                SprintCounter = 15
                JustHealed = false 
            end
        end
    end
end)

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local health = GetEntityHealth(ped)
        local armor = GetPedArmour(ped)

        if not playerHealth then
            playerHealth = health
        end

        if not playerArmor then
            playerArmor = armor
        end

        local armorDamaged = (playerArmor ~= armor and armor < (playerArmor - Config.ArmorDamage) and armor > 0) -- Players armor was damaged
        local healthDamaged = (playerHealth ~= health) -- Players health was damaged

        local damageDone = (playerHealth - health)

        if armorDamaged or healthDamaged then
            local hit, bone = GetPedLastDamageBone(ped)
            local bodypart = Config.Bones[bone]
            local weapon = GetDamagingWeapon(ped)

            if hit and bodypart ~= 'NONE' then
                local checkDamage = true
                if damageDone >= Config.HealthDamage then
                    if weapon then
                        if armorDamaged and (bodypart == 'SPINE' or bodypart == 'UPPER_BODY') or weapon == Config.WeaponClasses['NOTHING'] then
                            checkDamage = false -- Don't check damage if the it was a body shot and the weapon class isn't that strong
                            if armorDamaged then
                                TriggerServerEvent("hospital:server:SetArmor", GetPedArmour(ped))
                            end
                        end

                        if checkDamage then
                            if IsDamagingEvent(damageDone, weapon) then
                                CheckDamage(ped, bone, weapon, damageDone)
                            end
                        end
                    end
                elseif Config.AlwaysBleedChanceWeapons[weapon] then
                    if armorDamaged and (bodypart == 'SPINE' or bodypart == 'UPPER_BODY') or weapon == Config.WeaponClasses['NOTHING'] then
                        checkDamage = false -- Don't check damage if the it was a body shot and the weapon class isn't that strong
                    end
                    if math.random(100) < Config.AlwaysBleedChance and checkDamage then
                        ApplyBleed(1)
                    end
                end
            end

            CheckWeaponDamage(ped)
        end

        playerHealth = health
        playerArmor = armor

        if not isInHospitalBed then
            ProcessDamage(ped)
        end
        Wait(100)
    end
end)

-- Depot Vehicle EMS
RegisterNetEvent('qb-hospital:client:impoundambulancemenu', function() 
    exports['qb-menu']:openMenu({
        {
            header = "Ambulance Depot Vehicle",
            isMenuHeader = true, -- Set to true to make a nonclickable title
        },
		{
            header = "Depot Vehicle",
			txt = "Send vehicle to impound",
            params = {
                event = "qb-police:client:impoundnewmenusecond",
                args = {
                    action = 1
                }
            }
        },
    })
end)

-- CreateThread(function()
--     while true do
--         sleep = 1000
--         if LocalPlayer.state['isLoggedIn'] then
--             local pos = GetEntityCoords(PlayerPedId())
--             for k, checkins in pairs(Config.Locations["checking"]) do
--                 if #(pos - checkins) < 1.5 then
--                     sleep = 5
--                     if doctorCount >= Config.MinimalDoctors then
--                         DrawText3D(checkins.x, checkins.y, checkins.z, Lang:t('text.call_doc'))
--                     else
--                         DrawText3D(checkins.x, checkins.y, checkins.z, Lang:t('text.check_in'))
--                     end
--                     if IsControlJustReleased(0, 38) then
--                         if doctorCount >= Config.MinimalDoctors then
--                             TriggerServerEvent("hospital:server:SendDoctorAlert", HospitalStreetLabel())
--                         else
--                             TriggerEvent('animations:client:EmoteCommandStart', {"notepad"})
--                             QBCore.Functions.Progressbar("hospital_checkin", Lang:t('progress.checking_in'), 2000, false, true, {
--                                 disableMovement = true,
--                                 disableCarMovement = true,
--                                 disableMouse = false,
--                                 disableCombat = true,
--                             }, {}, {}, {}, function() -- Done
--                                 TriggerEvent('animations:client:EmoteCommandStart', {"c"})
--                                 local bedId = GetAvailableBed()
--                                 if bedId then
--                                     TriggerServerEvent("hospital:server:SendToBed", bedId, true)
--                                 else
--                                     QBCore.Functions.Notify(Lang:t('error.beds_taken'), "error")
--                                 end
--                             end, function() -- Cancel
--                                 TriggerEvent('animations:client:EmoteCommandStart', {"c"})
--                                 QBCore.Functions.Notify(Lang:t('error.canceled'), "error")
--                             end)
--                         end
--                     end
--                 elseif #(pos - checkins) < 4.5 then
--                     sleep = 5
--                     if doctorCount >= Config.MinimalDoctors then
--                         DrawText3D(checkins.x, checkins.y, checkins.z, Lang:t('text.call'))
--                     else
--                         DrawText3D(checkins.x, checkins.y, checkins.z, Lang:t('text.check'))
--                     end
--                 end
--             end

--             -- if closestBed and not isInHospitalBed then
--             --     if #(pos - vector3(Config.Locations["beds"][closestBed].coords.x, Config.Locations["beds"][closestBed].coords.y, Config.Locations["beds"][closestBed].coords.z)) < 2 then
--             --         sleep = 5
--             --         DrawText3D(Config.Locations["beds"][closestBed].coords.x, Config.Locations["beds"][closestBed].coords.y, Config.Locations["beds"][closestBed].coords.z + 0.3, Lang:t('text.lie_bed'))
--             --         if IsControlJustReleased(0, 38) then
--             --             if GetAvailableBed(closestBed) then
--             --                 TriggerServerEvent("hospital:server:SendToBed", closestBed, false)
--             --             else
--             --                 QBCore.Functions.Notify(Lang:t('error.beds_taken'), "error")
--             --             end
--             --         end
--             --     end
--             -- end
--         end
--         Wait(sleep)
--     end
-- end)

function isPlayerDead()
    local answer = false
    QBCore.Functions.GetPlayerData(function(PlayerData)
        if PlayerData.metadata["inlaststand"] or PlayerData.metadata["isdead"] or PlayerData.metadata["ishandcuffed"] then 
            answer = true
        end
    end)
    return answer 
end

RegisterNetEvent('hospital:client:leanonbed', function(data)
    if GetAvailableBed(data.ID) then
        -- was sending the Pillbox bed id to the Sandy event (wrong bed / nothing happened)
        TriggerServerEvent("hospital:server:SendToBed", data.ID, false)
    else
        QBCore.Functions.Notify(Lang:t('error.beds_taken'), "error")
    end
end)

RegisterNetEvent('hospital:client:leanonbedsandy', function(data)
    if GetAvailableBedsandy(data.ID) then
        TriggerServerEvent("hospital:server:SendToBedsandy", data.ID, false)
    else
        QBCore.Functions.Notify(Lang:t('error.beds_taken'), "error")
    end
end)

RegisterNetEvent('hospital:client:FloorTP', function(data)
    if data.Floor == 1 then 
        local ped = PlayerPedId()
        DoScreenFadeOut(500)
        while not IsScreenFadedOut() do
            Wait(10)
        end
    
        local coords = vector4(319.63552856445,-572.64978027344,43.27087020874, 159.80027770996)
        SetEntityCoords(ped, coords.x, coords.y, coords.z, 0, 0, 0, false)
        SetEntityHeading(ped, coords.w)
    
        Wait(100)
    
        DoScreenFadeIn(1000)
    elseif data.Floor == 2 then 
        local ped = PlayerPedId()
        DoScreenFadeOut(500)
        while not IsScreenFadedOut() do
            Wait(10)
        end
    
        local coords = vector4(323.1130065918,-577.45257568359,28.759691238403, 343.30029296875)
        SetEntityCoords(ped, coords.x, coords.y, coords.z, 0, 0, 0, false)
        SetEntityHeading(ped, coords.w)
    
        Wait(100)
    
        DoScreenFadeIn(1000)
    elseif data.Floor == 3 then 
        local ped = PlayerPedId()
        DoScreenFadeOut(500)
        while not IsScreenFadedOut() do
            Wait(10)
        end
    
        local coords = vector4(330.68746948242,-579.31390380859,74.180328369141, 250.58782958984)
        SetEntityCoords(ped, coords.x, coords.y, coords.z, 0, 0, 0, false)
        SetEntityHeading(ped, coords.w)
    
        Wait(100)
    
        DoScreenFadeIn(1000)
    end
end)

RegisterNetEvent('hospital:client:CheckIn', function(data)
    if isCheckIn then QBCore.Functions.Notify('Please wait doctors are coming to help you', "success") return end
    QBCore.Functions.TriggerCallback('hospital:server:GetTotalDoc', function(isBlock)
        if isBlock then
            TriggerServerEvent("hospital:server:SendDoctorAlert", HospitalStreetLabel())
            QBCore.Functions.Notify('Please wait doctors are coming to help you', "success")
            isCheckIn = true
            Wait(5000)
            isCheckIn = false
        else
            TriggerEvent('animations:client:EmoteCommandStart', {"notepad"})
            isCheckIn = true
            QBCore.Functions.Progressbar("hospital_checkin", Lang:t('progress.checking_in'), 2000, false, true, {
                disableMovement = true,
                disableCarMovement = true,
                disableMouse = false,
                disableCombat = true,
            }, {}, {}, {}, function() -- Done
                TriggerEvent('animations:client:EmoteCommandStart', {"c"})
                local bedId = GetAvailableBed()
                if bedId then
                    TriggerServerEvent("hospital:server:SendToBed", bedId, true)
                else
                    QBCore.Functions.Notify(Lang:t('error.beds_taken'), "error")
                end
            end, function() -- Cancel
                TriggerEvent('animations:client:EmoteCommandStart', {"c"})
                QBCore.Functions.Notify(Lang:t('error.canceled'), "error")
                isCheckIn = false
            end)
        end
    end)
end)

RegisterNetEvent('hospital:client:CheckInsandy', function(data)
    if isCheckIn then QBCore.Functions.Notify('Please wait doctors are coming to help you', "success") return end
    QBCore.Functions.TriggerCallback('hospital:server:GetTotalDoc', function(isBlock)
        if isBlock then
            TriggerServerEvent("hospital:server:SendDoctorAlert", HospitalStreetLabel())
            QBCore.Functions.Notify('Please wait doctors are coming to help you', "success")
            isCheckIn = true
            Wait(5000)
            isCheckIn = false
        else
            TriggerEvent('animations:client:EmoteCommandStart', {"notepad"})
            isCheckIn = true
            QBCore.Functions.Progressbar("hospital_checkin", Lang:t('progress.checking_in'), 2000, false, true, {
                disableMovement = true,
                disableCarMovement = true,
                disableMouse = false,
                disableCombat = true,
            }, {}, {}, {}, function() -- Done
                TriggerEvent('animations:client:EmoteCommandStart', {"c"})
                local bedId = GetAvailableBedsandy()
                if bedId then
                    TriggerServerEvent("hospital:server:SendToBedsandy", bedId, true)
                else
                    QBCore.Functions.Notify(Lang:t('error.beds_taken'), "error")
                end
            end, function() -- Cancel
                TriggerEvent('animations:client:EmoteCommandStart', {"c"})
                QBCore.Functions.Notify(Lang:t('error.canceled'), "error")
                isCheckIn = false
            end)
        end
    end)
end)

RegisterNetEvent('hospital:client:Heli', function(data)
    local ped = PlayerPedId()
    if HeliVeh then
        if #(GetEntityCoords(HeliVeh) - vector3(312.71, -1465.24, 46.51)) <= 15 then 
            DeleteVehicle(HeliVeh)
            HeliVeh = nil
        end
    else
        local PlayerData = QBCore.Functions.GetPlayerData()
        if (PlayerData.metadata.ems or {}).iswing then 
            local coords = vector4(313.43, -1465.6, 46.51, 347.9)
            QBCore.Functions.SpawnVehicle(Config.Helicopter, function(veh)
                SetVehicleNumberPlateText(veh, Lang:t('info.heli_plate')..tostring(math.random(1000, 9999)))
                SetEntityHeading(veh, coords.w)
                SetVehicleLivery(veh, 1) -- Ambulance Livery
                SetFuel(veh, 100.0)
                TaskWarpPedIntoVehicle(ped, veh, -1)
                TriggerEvent("vehiclekeys:client:SetOwner", QBCore.Functions.GetPlate(veh))
                SetVehicleEngineOn(veh, true, true)
                HeliVeh = veh
            end, coords, true)
        else
            QBCore.Functions.Notify('You\'re not certified Air Unit', 'error', 7500)
        end
    end
end)

RegisterNetEvent('hospital:client:Vehicles', function(data)
    local ped = PlayerPedId()
    currentGarage = data.params.hospital
    MenuGarage()
end)

RegisterNetEvent('hospital:client:ReturnVehicles', function(data)
    local ped = PlayerPedId()
    if EMSveh then 
        local coords = vector3(Config.Locations["vehicle"][data.params.hospital].x, Config.Locations["vehicle"][data.params.hospital].y, Config.Locations["vehicle"][data.params.hospital].z)
        if #(GetEntityCoords(EMSveh) - coords) <= 15 then 
            DeleteVehicle(EMSveh)
            EMSveh = nil
        end
    end
end)

RegisterNetEvent('hospital:client:armory', function(data)
    TriggerServerEvent("inventory:server:OpenInventory", "shop", "", Config.Items)
end)

RegisterNetEvent('hospital:ToggleDispatch', function()
    local PlayerData = QBCore.Functions.GetPlayerData()
    if (PlayerData.metadata['ems'] or {})['dispatch'] then 
        TriggerServerEvent('hospital:ToggleDispatchoff')
    else
        QBCore.Functions.TriggerCallback('hospital:server:DispatchCheck', function(DispatchCheck)
            if DispatchCheck then 
                QBCore.Functions.Notify('You are now dispatch', 'success', 7500)
            else
                QBCore.Functions.Notify('You can\'t be dispatch right now', 'error', 7500)
            end
        end)
    end
end)

Citizen.CreateThread(function()
    -- Pillbox and Sandy both used "bed1", "bed2"... as zone names, so the Sandy
    -- zones replaced the Pillbox ones in qb-target. Each zone now has its own name.
    for k, v in pairs (Config.Locations["beds"]) do 
        local BedID = v.target
        exports['qb-target']:AddBoxZone('hospital_bed_' .. k, BedID.coords, BedID.info1, BedID.info2, {
            name= 'hospital_bed_' .. k,
            heading= BedID.heading,
            debugPoly= BedID.debugPoly,
            minZ= BedID.minZ,
            maxZ= BedID.maxZ
        }, {
            options = { 
            { 
                type = "client", 
                event = "hospital:client:leanonbed",  
                icon = 'fa-solid fa-bed-pulse', 
                label = 'To lie in bed', 
                ID = k
            }
            },
            distance = 2, 
        })
    end
    for k, v in pairs (Config.Locations["bedssandy"]) do 
        local BedID = v.target
        exports['qb-target']:AddBoxZone('hospital_bedsandy_' .. k, BedID.coords, BedID.info1, BedID.info2, {
            name= 'hospital_bedsandy_' .. k,
            heading= BedID.heading,
            debugPoly= BedID.debugPoly,
            minZ= BedID.minZ,
            maxZ= BedID.maxZ
        }, {
            options = { 
            { 
                type = "client", 
                event = "hospital:client:leanonbedsandy",  
                icon = 'fa-solid fa-bed-pulse', 
                label = 'To lie in bed', 
                ID = k
            }
            },
            distance = 2, 
        })
    end
    -- for k, v in pairs (Config.Locations["duty"]) do 
    --     -- exports['qb-target']:AddBoxZone(v.name, v.coords, v.info1, v.info2, {
    --     --     name= v.name,
    --     --     heading= v.heading,
    --     --     debugPoly= v.debugPoly,
    --     --     minZ= v.minZ,
    --     --     maxZ= v.maxZ
    --     -- }, {
    --     --     options = { 
    --     --         { 
    --     --             type = "client", 
    --     --             event = "hospital:client:onDuty",  
    --     --             icon = 'fa-solid fa-clipboard-list-check', 
    --     --             label = 'Duty', 
    --     --             job = 'ambulance'
    --     --         },
    --     --         { 
    --     --             type = "client", 
    --     --             event = "hospital:ToggleDispatch",  
    --     --             icon = 'fa-solid fa-clipboard-list-check', 
    --     --             label = 'Dispatch', 
    --     --             job = 'ambulance'
    --     --         },
    --     --     },
    --     --     distance = 1.5, 
    --     -- })
    --     exports.interact:AddInteraction({
    --         coords = v.coords,
    --         distance = 3.0, -- optional
    --         interactDst = 1.0, -- optional
    --         groups = {
    --             ['ambulance'] = 0, -- Jobname | Job grade
    --         },
    --         options = { 
    --             { 
    --                 type = "client", 
    --                 event = "hospital:client:onDuty",  
    --                 icon = 'fa-solid fa-clipboard-list-check', 
    --                 label = 'Duty', 
    --             },
    --             { 
    --                 type = "client", 
    --                 event = "hospital:ToggleDispatch",  
    --                 icon = 'fa-solid fa-clipboard-list-check', 
    --                 label = 'Dispatch', 
    --             },
    --         }
    --     })
    -- end
    for k, v in pairs (Config.Locations["armory"]) do 
        local Floor = Config.Locations["armory"][k]
        -- exports['qb-target']:AddBoxZone(Floor.name, Floor.coords, Floor.info1, Floor.info2, {
        --     name= Floor.name,
        --     heading= Floor.heading,
        --     debugPoly= Floor.debugPoly,
        --     minZ= Floor.minZ,
        --     maxZ= Floor.maxZ
        -- }, {
        --     options = { 
        --     { 
        --         type = "client", 
        --         event = "hospital:client:armory",  
        --         icon = 'fa-solid fa-vault', 
        --         label = 'Locker', 
        --         job = "ambulance",
        --     }
        --     },
        --     distance = 2.5, 
        -- })
        exports.interact:AddInteraction({
            coords = Floor.coords,
            distance = 4.0, -- optional
            interactDst = 2.0, -- optional
            groups = {
                ['ambulance'] = 0, -- Jobname | Job grade
            },
            options = { 
            { 
                type = "client", 
                event = "hospital:client:armory",  
                icon = 'fa-solid fa-vault', 
                label = 'Locker', 
            }
            }
        })
    end
    for k, v in pairs (Config.Locations["clothes"]) do 
        local Floor = Config.Locations["clothes"][k]
        exports['qb-target']:AddBoxZone(Floor.name, Floor.coords, Floor.info1, Floor.info2, {
            name= Floor.name,
            heading= Floor.heading,
            debugPoly= Floor.debugPoly,
            minZ= Floor.minZ,
            maxZ= Floor.maxZ
        }, {
            options = { 
                { 
                    type = "client", 
                    event = "qb-clothing:client:openMenu",  
                    icon = 'fas fa-shirt', 
                    label = 'Clothes', 
                    job = 'ambulance',
                },
                { 
                    type = "client", 
                    event = "qb-clothing:client:openOutfitMenu",  
                    icon = 'fas fa-shirt', 
                    label = 'Clothes Locker', 
                    job = 'ambulance',
                }
            },
            distance = 2.5, 
        })
        exports.interact:AddInteraction({
            coords = Floor.coords,
            distance = 4.0, -- optional
            interactDst = 2.0, -- optional
            groups = {
                ['ambulance'] = 0, -- Jobname | Job grade
            },
            options = { 
                { 
                    type = "client", 
                    event = "qb-clothing:client:openMenu",  
                    icon = 'fas fa-example', 
                    label = 'Clothes', 
                },
                { 
                    type = "client", 
                    event = "qb-clothing:client:openOutfitMenu",  
                    icon = 'fas fa-example', 
                    label = 'Clothes Locker', 
                }
            }
        })
    end
end)
