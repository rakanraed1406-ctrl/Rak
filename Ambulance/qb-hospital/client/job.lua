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
        exports['LegacyFuel']:SetFuel(veh, 100.0)
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

    local authorizedVehicles = Config.AuthorizedVehicles[QBCore.Functions.GetPlayerData().job.grade.level]
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
    if player ~= -1 and distance < 5.0 then
        local playerId = GetPlayerServerId(player)
        statusCheckPed = GetPlayerPed(player)
        QBCore.Functions.TriggerCallback('hospital:GetPlayerStatus', function(result)
            if result then
                for k, v in pairs(result) do
                    if k ~= "BLEED" and k ~= "WEAPONWOUNDS" then
                        statusChecks[#statusChecks+1] = {bone = Config.BoneIndexes[k], label = v.label .." (".. Config.WoundStates[v.severity] ..")"}
                    elseif result["WEAPONWOUNDS"] then
                        for k, v in pairs(result["WEAPONWOUNDS"]) do
                            TriggerEvent('chat:addMessage', {
                                color = { 255, 0, 0},
                                multiline = false,
                                args = {Lang:t('info.status'), (QBCore.Shared.Weapons[v] and QBCore.Shared.Weapons[v].damagereason) or tostring(v)}
                            })
                        end
                    elseif result["BLEED"] > 0 then
                        TriggerEvent('chat:addMessage', {
                            color = { 255, 0, 0},
                            multiline = false,
                            args = {Lang:t('info.status'), Lang:t('info.is_status', {status = Config.BleedingStates[v].label})}
                        })
                    else
                        QBCore.Functions.Notify(Lang:t('success.healthy_player'), 'success','error',3000)
                    end
                end
                isStatusChecking = true
                statusCheckTime = Config.CheckTime
            end
        end, playerId)
    else
        QBCore.Functions.Notify(Lang:t('error.no_player'), 'error')
    end
end)

RegisterNetEvent('hospital:client:RevivePlayer', function()
    local player, distance = GetClosestPlayer()
    local RandomTime = math.random(10000, 15000)
    if player ~= -1 and distance < 5.0 then
        local playerId = GetPlayerServerId(player)
        QBCore.Functions.TriggerCallback('hospital:server:GetPlayerStatus', function(isdead, inlaststand)
            if inlaststand then 
                QBCore.Functions.TriggerCallback('QBCore:HasItem', function(hasItem)
                    if hasItem then
                        local player, distance = GetClosestPlayer()
                        local RandomTime = math.random(10000, 15000)
                        if player ~= -1 and distance < 5.0 then
                            local playerId = GetPlayerServerId(player)
                            isHealingPerson = true
                            HealAnim(RandomTime)
                            QBCore.Functions.Progressbar("hospital_revive", "Helping Person", RandomTime, false, true, {
                                disableMovement = true,
                                disableCarMovement = true,
                                disableMouse = false,
                                disableCombat = true,
                            }, {}, {}, {}, function() -- Done
                                isHealingPerson = false
                                QBCore.Functions.Notify(Lang:t('success.revived'), 'success')
                                TriggerServerEvent("hospital:server:RevivePlayer", playerId, false, true)
                            end, function() -- Cancel
                                isHealingPerson = false
                                QBCore.Functions.Notify("Cancled", "error")
                            end)
                        else
                            QBCore.Functions.Notify(Lang:t('error.no_player'), "error")
                        end
                    else
                        QBCore.Functions.Notify(Lang:t('error.no_firstaid'), "error")
                    end
                end, 'firstaid')
            elseif isdead then 
                QBCore.Functions.TriggerCallback('QBCore:HasItem', function(hasItem)
                    if hasItem then
                        local player, distance = GetClosestPlayer()
                        local RandomTime = math.random(10000, 15000)
                        if player ~= -1 and distance < 5.0 then
                            local playerId = GetPlayerServerId(player)
                            isHealingPerson = true
                            HealAnim(RandomTime)
                            QBCore.Functions.Progressbar("hospital_revive", "Defibing", RandomTime, false, true, {
                                disableMovement = true,
                                disableCarMovement = true,
                                disableMouse = false,
                                disableCombat = true,
                            }, {}, {}, {}, function() -- Done
                                isHealingPerson = false
                                QBCore.Functions.Notify(Lang:t('success.revived'), 'success')
                                TriggerServerEvent("hospital:server:RevivePlayer", playerId, false, false)
                            end, function() -- Cancel
                                isHealingPerson = false
                                QBCore.Functions.Notify("Cancled", "error")
                            end)
                        else
                            QBCore.Functions.Notify(Lang:t('error.no_player'), "error")
                        end
                    else
                        QBCore.Functions.Notify("You don\'t have defibrillator", "error")
                    end
                end, 'defibrillator')
            end
        end, playerId)
    else
        QBCore.Functions.Notify(Lang:t('error.no_player'), "error")
    end
end)

RegisterNetEvent('hospital:client:TreatWounds', function()
    QBCore.Functions.TriggerCallback('QBCore:HasItem', function(hasItem)
        if hasItem then
            local player, distance = GetClosestPlayer()
            if player ~= -1 and distance < 5.0 then
                local playerId = GetPlayerServerId(player)
                local RandomTime = math.random(10000, 15000)
                isHealingPerson = true
                HealAnim(RandomTime)
                QBCore.Functions.Progressbar("hospital_healwounds", Lang:t('progress.healing'), RandomTime, false, true, {
                    disableMovement = false,
                    disableCarMovement = false,
                    disableMouse = false,
                    disableCombat = true,
                }, {}, {}, {}, function() -- Done
                    isHealingPerson = false
                    -- StopAnimTask(PlayerPedId(), healAnimDict, "exit", 1.0)
                    QBCore.Functions.Notify(Lang:t('success.helped_player'), 'success')
                    TriggerServerEvent("hospital:server:TreatWounds", playerId)
                end, function() -- Cancel
                    isHealingPerson = false
                    -- StopAnimTask(PlayerPedId(), healAnimDict, "exit", 1.0)
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

function HealAnim(time)
    time = time / 1000
    QBCore.Functions.RequestAnimationDict("weapons@first_person@aim_rng@generic@projectile@thermal_charge@")
    TaskPlayAnim(PlayerPedId(), "weapons@first_person@aim_rng@generic@projectile@thermal_charge@", "plant_floor" ,3.0, 3.0, -1, 16, 0, false, false, false)
    Healing = true
    Citizen.CreateThread(function()
        while isHealingPerson do
            TaskPlayAnim(PlayerPedId(), "weapons@first_person@aim_rng@generic@projectile@thermal_charge@", "plant_floor", 3.0, 3.0, -1, 16, 0, 0, 0, 0)
            Citizen.Wait(2000)
            time = time - 2
            if time <= 0 then
                isHealingPerson = false
                StopAnimTask(PlayerPedId(), "weapons@first_person@aim_rng@generic@projectile@thermal_charge@", "plant_floor", 1.0)
            end
        end
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
