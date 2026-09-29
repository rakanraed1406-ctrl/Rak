local statusCheckPed = nil
local PlayerJob = {}
local onDuty = false
currentGarage = 1
HeliVeh = nil
EMSveh = nil 

-- Functions

local function loadAnimDict(dict)
    while (not HasAnimDictLoaded(dict)) do
        RequestAnimDict(dict)
        Wait(5)
    end
end

local function GetClosestPlayer()
    local closestPlayers = QBCore.Functions.GetPlayersFromCoords()
    local closestDistance = -1
    local closestPlayer = -1
    local coords = GetEntityCoords(PlayerPedId())

    for i=1, #closestPlayers, 1 do
        if closestPlayers[i] ~= PlayerId() then
            local pos = GetEntityCoords(GetPlayerPed(closestPlayers[i]))
            local distance = #(pos - coords)

            if closestDistance == -1 or closestDistance > distance then
                closestPlayer = closestPlayers[i]
                closestDistance = distance
            end
        end
	end
	return closestPlayer, closestDistance
end

local function HasItem(item)
    if QBCore.Functions.HasItem then return QBCore.Functions.HasItem(item) end
    for _, v in pairs(QBCore.Functions.GetPlayerData().items or {}) do
        if v and v.name == item then return true end
    end
    return false
end

local function DrawText3D(x, y, z, text)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(true)
    AddTextComponentString(text)
    SetDrawOrigin(x,y,z, 0)
    DrawText(0.0, 0.0)
    local factor = (string.len(text)) / 370
    DrawRect(0.0, 0.0+0.0125, 0.017+ factor, 0.03, 0, 0, 0, 75)
    ClearDrawOrigin()
end

function TakeOutVehicle(vehicleInfo)
    local coords = Config.Locations["vehicle"][currentGarage]
    QBCore.Functions.SpawnVehicle(vehicleInfo, function(veh)
        SetVehicleNumberPlateText(veh, Lang:t('info.amb_plate')..tostring(math.random(1000, 9999)))
        SetEntityHeading(veh, coords.w)
        SetFuel(veh, 100.0)
        TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
        if Config.VehicleSettings[vehicleInfo] ~= nil then
            QBCore.Shared.SetDefaultVehicleExtras(veh, Config.VehicleSettings[vehicleInfo].extras)
        end
        TriggerEvent("vehiclekeys:client:SetOwner", QBCore.Functions.GetPlate(veh))
        SetVehicleEngineOn(veh, true, true)
        EMSveh = veh
    end, coords, true)
end

function MenuGarage()
    local vehicleMenu = {
        {
            header = Lang:t('menu.amb_vehicles'),
            isMenuHeader = true
        }
    }

    local authorizedVehicles = Config.AuthorizedVehicles[QBCore.Functions.GetPlayerData().job.grade.level] or Config.AuthorizedVehicles[0] or {}
    for veh, label in pairs(authorizedVehicles) do
        vehicleMenu[#vehicleMenu+1] = {
            header = label,
            txt = "",
            params = {
                event = "ambulance:client:TakeOutVehicle",
                args = {
                    vehicle = veh
                }
            }
        }
    end
    vehicleMenu[#vehicleMenu+1] = {
        header = Lang:t('menu.close'),
        txt = "",
        params = {
            event = "qb-menu:client:closeMenu"
        }

    }
    exports['qb-menu']:openMenu(vehicleMenu)
end

-- Events

RegisterNetEvent('ambulance:client:TakeOutVehicle', function(data)
    local vehicle = data.vehicle
    TakeOutVehicle(vehicle)
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    PlayerJob = JobInfo
    TriggerServerEvent("hospital:server:SetDoctor")
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    exports.spawnmanager:setAutoSpawn(false)
    local ped = PlayerPedId()
    local player = PlayerId()
    TriggerServerEvent("hospital:server:SetDoctor")
    CreateThread(function()
        Wait(5000)
        SetEntityMaxHealth(ped, 200)
        SetEntityHealth(ped, 200)
        SetPlayerHealthRechargeMultiplier(player, 0.0)
        SetPlayerHealthRechargeLimit(player, 0.0)
    end)
    CreateThread(function()
        Wait(1000)
        QBCore.Functions.GetPlayerData(function(PlayerData)
            PlayerJob = PlayerData.job
            onDuty = PlayerData.job.onduty
            SetPedArmour(PlayerPedId(), PlayerData.metadata["armor"])
            if (not PlayerData.metadata["inlaststand"] and PlayerData.metadata["isdead"]) then
                deathTime = Laststand.ReviveInterval
                OnDeath()
                DeathTimer()
            elseif (PlayerData.metadata["inlaststand"] and not PlayerData.metadata["isdead"]) then
                SetLaststand(true, true)
            else
                TriggerServerEvent("hospital:server:SetDeathStatus", false)
                TriggerServerEvent("hospital:server:SetLaststandStatus", false)
            end
        end)
    end)
end)

RegisterNetEvent('QBCore:Client:SetDuty', function(duty)
    onDuty = duty
    TriggerServerEvent("hospital:server:SetDoctor")
end)

RegisterNetEvent('hospital:client:onDuty', function(data)
    onDuty = not onDuty
    TriggerServerEvent("QBCore:ToggleDuty")
    TriggerServerEvent("police:server:UpdateBlips")
    TriggerServerEvent('qb-emshub:server:refresh', QBCore.Functions.GetPlayerData().job.name,onDuty)
end)

RegisterNetEvent('hospital:client:CheckStatus', function()
    local player, distance = GetClosestPlayer()
    if player == -1 or distance >= 5.0 then
        QBCore.Functions.Notify(Lang:t('error.no_player'), 'error')
        return
    end
    local playerId = GetPlayerServerId(player)
    statusCheckPed = GetPlayerPed(player)
    QBCore.Functions.TriggerCallback('hospital:GetPlayerStatus', function(result)
        if not result then return end
        -- the old loop mixed up the keys: bleeding was never shown and gunshot
        -- wounds were printed once per injured limb
        statusChecks = {}
        local healthy = true
        for k, v in pairs(result) do
            if k ~= "BLEED" and k ~= "WEAPONWOUNDS" and Config.BoneIndexes[k] then
                healthy = false
                statusChecks[#statusChecks+1] = {bone = Config.BoneIndexes[k], label = v.label .." (".. (Config.WoundStates[v.severity] or '') ..")"}
            end
        end
        for _, weapon in pairs(result["WEAPONWOUNDS"] or {}) do
            healthy = false
            TriggerEvent('chat:addMessage', {
                color = { 255, 0, 0},
                multiline = false,
                args = {Lang:t('info.status'), (QBCore.Shared.Weapons[weapon] and QBCore.Shared.Weapons[weapon].damagereason) or tostring(weapon)}
            })
        end
        local bleed = tonumber(result["BLEED"]) or 0
        if bleed > 0 and Config.BleedingStates[bleed] then
            healthy = false
            TriggerEvent('chat:addMessage', {
                color = { 255, 0, 0},
                multiline = false,
                args = {Lang:t('info.status'), Lang:t('info.is_status', {status = Config.BleedingStates[bleed].label})}
            })
        end
        if healthy then
            QBCore.Functions.Notify(Lang:t('success.healthy_player'), 'success', 3000)
        end
        isStatusChecking = true
        statusCheckTime = Config.CheckTime
    end, playerId)
end)

RegisterNetEvent('hospital:client:RevivePlayer', function()
    local player, distance = GetClosestPlayer()
    if player == -1 or distance >= 5.0 then
        QBCore.Functions.Notify(Lang:t('error.no_player'), "error")
        return
    end
    local playerId = GetPlayerServerId(player)
    QBCore.Functions.TriggerCallback('hospital:server:GetPlayerStatus', function(isdead, inlaststand)
        if not isdead and not inlaststand then
            QBCore.Functions.Notify(Lang:t('error.cant_help'), "error")
            return
        end
        local item = isdead and 'defibrillator' or 'firstaid'
        if not HasItem(item) then
            QBCore.Functions.Notify(isdead and Lang:t('error.no_defib') or Lang:t('error.no_firstaid'), "error")
            return
        end
        local time = math.random(10000, 15000)
        isHealingPerson = true
        HealAnim(time, isdead and 'defib' or 'cpr', GetPlayerPed(player))
        QBCore.Functions.Progressbar("hospital_revive", isdead and "Defibrillating..." or "Helping person...", time, false, true, {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true,
        }, {}, {}, {}, function() -- Done
            StopHealAnim()
            QBCore.Functions.Notify(Lang:t('success.revived'), 'success')
            TriggerServerEvent("hospital:server:RevivePlayer", playerId, false)
        end, function() -- Cancel
            StopHealAnim()
            QBCore.Functions.Notify(Lang:t('error.canceled'), "error")
        end)
    end, playerId)
end)

RegisterNetEvent('hospital:client:TreatWounds', function()
    QBCore.Functions.TriggerCallback('QBCore:HasItem', function(hasItem)
        if hasItem then
            local player, distance = GetClosestPlayer()
            if player ~= -1 and distance < 5.0 then
                local playerId = GetPlayerServerId(player)
                local RandomTime = math.random(10000, 15000)
                isHealingPerson = true
                HealAnim(RandomTime, 'treat', GetPlayerPed(player))
                QBCore.Functions.Progressbar("hospital_healwounds", Lang:t('progress.healing'), RandomTime, false, true, {
                    disableMovement = true,
                    disableCarMovement = true,
                    disableMouse = false,
                    disableCombat = true,
                }, {}, {}, {}, function() -- Done
                    StopHealAnim()
                    QBCore.Functions.Notify(Lang:t('success.helped_player'), 'success')
                    TriggerServerEvent("hospital:server:TreatWounds", playerId)
                end, function() -- Cancel
                    StopHealAnim()
                    QBCore.Functions.Notify(Lang:t('error.canceled'), "error")
                end)
            else
                QBCore.Functions.Notify(Lang:t('error.no_player'), "error")
            end
        else
            QBCore.Functions.Notify(Lang:t('error.no_bandage'), "error")
        end
    end, 'bandage')
end)

-- Medic animations with props (see Config.HealAnims): CPR for first aid, kneel +
-- trauma bag for wound care, defibrillator with shocks for a patient without pulse.
local healProps = {}

local function SpawnHealProp(model, onGround, bone, offset, rot, ped)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) then return end
    RequestModel(hash)
    local timeout = GetGameTimer() + 3000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do Wait(10) end
    if not HasModelLoaded(hash) then return end
    local c = GetEntityCoords(ped)
    local obj = CreateObject(hash, c.x, c.y, c.z - 1.0, true, true, false)
    if onGround then
        local pos = GetOffsetFromEntityInWorldCoords(ped, offset.x, offset.y, offset.z)
        SetEntityCoords(obj, pos.x, pos.y, pos.z, false, false, false, false)
        SetEntityHeading(obj, GetEntityHeading(ped) + (rot and rot.z or 0.0))
        PlaceObjectOnGroundProperly(obj)
        FreezeEntityPosition(obj, true)
    else
        AttachEntityToEntity(obj, ped, GetPedBoneIndex(ped, bone), offset.x, offset.y, offset.z, rot.x, rot.y, rot.z, true, true, false, true, 1, true)
    end
    SetModelAsNoLongerNeeded(hash)
    healProps[#healProps + 1] = obj
end

function StopHealAnim()
    isHealingPerson = false
    local ped = PlayerPedId()
    for _, obj in ipairs(healProps) do
        if DoesEntityExist(obj) then DeleteEntity(obj) end
    end
    healProps = {}
    ClearPedTasks(ped)
end

function HealAnim(time, kind, patientPed)
    local cfg = (Config.HealAnims or {})[kind or 'treat'] or (Config.HealAnims or {}).treat
    local ped = PlayerPedId()
    if not cfg then return end
    -- face the patient
    if patientPed and DoesEntityExist(patientPed) then
        TaskTurnPedToFaceEntity(ped, patientPed, 800)
        Wait(800)
    end
    for _, p in ipairs(cfg.props or {}) do
        SpawnHealProp(p.model, p.ground, p.bone or 57005, p.offset or vector3(0.0, 0.0, 0.0), p.rotation or vector3(0.0, 0.0, 0.0), ped)
    end
    loadAnimDict(cfg.dict)
    isHealingPerson = true
    local endAt = GetGameTimer() + time
    CreateThread(function()
        local nextShock = GetGameTimer() + (cfg.shockEvery or 0)
        while isHealingPerson and GetGameTimer() < endAt do
            if not IsEntityPlayingAnim(ped, cfg.dict, cfg.anim, 3) then
                TaskPlayAnim(ped, cfg.dict, cfg.anim, 3.0, 3.0, -1, cfg.flag or 1, 0, false, false, false)
            end
            if cfg.shockEvery and GetGameTimer() >= nextShock then
                nextShock = GetGameTimer() + cfg.shockEvery
                PlaySoundFrontend(-1, "Hack_Success", "DLC_HEIST_BIOLAB_PREP_HACKING_SOUNDS", true)
                if patientPed and DoesEntityExist(patientPed) then
                    local pc = GetEntityCoords(patientPed)
                    UseParticleFxAssetNextCall("core")
                    StartParticleFxNonLoopedAtCoord("ent_sht_electrical_box", pc.x, pc.y, pc.z - 0.6, 0.0, 0.0, 0.0, 0.35, false, false, false)
                end
            end
            Wait(250)
        end
        if isHealingPerson then StopHealAnim() end
    end)
end

CreateThread(function()
    while true do
        Wait(10)
        if isStatusChecking then
            for k, v in pairs(statusChecks) do
                local x,y,z = table.unpack(GetPedBoneCoords(statusCheckPed, v.bone))
                DrawText3D(x, y, z, v.label)
            end
        end
    end
end)

RegisterNetEvent('hospital:hospitalBoss', function(data)
  --  if PlayerJob.name =="ambulance" and PlayerJob.isboss then
        TriggerEvent("qb-bossmenu:client:OpenMenu")
  --  end
end)
