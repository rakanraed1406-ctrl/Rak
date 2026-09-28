-- Variables
local isEscorting = false
local isKidnapped = false
local KidnapperID = 0

-- Functions
exports('IsHandcuffed', function()
    return isHandcuffed
end)

local function loadAnimDict(dict) -- interactions, job,
    while (not HasAnimDictLoaded(dict)) do
        RequestAnimDict(dict)
        Wait(10)
    end
end

local function IsTargetDead(playerId)
    local retval = false
    QBCore.Functions.TriggerCallback('police:server:isPlayerDead', function(result)
        retval = result
    end, playerId)
    Wait(100)
    return retval
end

local function HandCuffAnimation()
    local ped = PlayerPedId()
    if isHandcuffed == true then
        TriggerServerEvent("InteractSound_SV:PlayOnSource", "Cuff", 0.2)
    else
        TriggerServerEvent("InteractSound_SV:PlayOnSource", "Uncuff", 0.2)
    end

    loadAnimDict("mp_arrest_paired")
	Wait(100)
    TaskPlayAnim(ped, "mp_arrest_paired", "cop_p2_back_right", 3.0, 3.0, -1, 48, 0, 0, 0, 0)
    TriggerServerEvent("InteractSound_SV:PlayOnSource", "Cuff", 0.2)
	Wait(3500)
    TaskPlayAnim(ped, "mp_arrest_paired", "exit", 3.0, 3.0, -1, 48, 0, 0, 0, 0)
end

local function GetCuffedAnimation(playerId)
    local ped = PlayerPedId()
    local cuffer = GetPlayerPed(GetPlayerFromServerId(playerId))
    local heading = GetEntityHeading(cuffer)
    TriggerServerEvent("InteractSound_SV:PlayOnSource", "Cuff", 0.2)
    loadAnimDict("mp_arrest_paired")
    SetEntityCoords(ped, GetOffsetFromEntityInWorldCoords(cuffer, 0.0, 0.45, 0.0))

	Wait(100)
	SetEntityHeading(ped, heading)
	TaskPlayAnim(ped, "mp_arrest_paired", "crook_p2_back_right", 3.0, 3.0, -1, 32, 0, 0, 0, 0 ,true, true, true)
	Wait(2500)
end

-- Events
RegisterNetEvent('police:client:SetOutVehicle', function()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        local vehicle = GetVehiclePedIsIn(ped, false)
        TaskLeaveVehicle(ped, vehicle, 16)
    end
end)

RegisterNetEvent('police:client:PutInVehicle', function()
    local ped = PlayerPedId()
    if isHandcuffed or isEscorted then
        local vehicle = QBCore.Functions.GetClosestVehicle()
        if DoesEntityExist(vehicle) then
            local seat = -1
            for i=0,8,1 do
                if GetPedInVehicleSeat(vehicle,i) == 0 then
                    seat = i
                    break
                end
            end
            if seat ~= -1 then
                isEscorted = false
                TriggerEvent('hospital:client:isEscorted', isEscorted)
                ClearPedTasks(ped)
                DetachEntity(ped, true, false)

                Wait(100)
                SetPedIntoVehicle(ped, vehicle, seat)
            end
		end
    end
end)

RegisterNetEvent('police:client:SearchPlayer', function()
    local player, distance = QBCore.Functions.GetClosestPlayer()
    if player ~= -1 and distance < 2.5 then
        local playerId = GetPlayerServerId(player)
        TriggerServerEvent("inventory:server:OpenInventory", "otherplayer", playerId)
        TriggerServerEvent("police:server:SearchPlayer", playerId)
    else
        QBCore.Functions.Notify(Lang:t("error.none_nearby"), "error")
    end
end)

RegisterNetEvent('police:client:SeizeCash', function()
    local player, distance = QBCore.Functions.GetClosestPlayer()
    if player ~= -1 and distance < 2.5 then
        local playerId = GetPlayerServerId(player)
        TriggerServerEvent("police:server:SeizeCash", playerId)
    else
        QBCore.Functions.Notify(Lang:t("error.none_nearby"), "error")
    end
end)

RegisterNetEvent('police:client:SeizeDriverLicense', function()
    local player, distance = QBCore.Functions.GetClosestPlayer()
    if player ~= -1 and distance < 2.5 then
        local playerId = GetPlayerServerId(player)
        TriggerServerEvent("police:server:SeizeDriverLicense", playerId)
    else
        QBCore.Functions.Notify(Lang:t("error.none_nearby"), "error")
    end
end)


RegisterNetEvent('police:client:RobPlayer', function()
    local player, distance = QBCore.Functions.GetClosestPlayer()
    local ped = PlayerPedId()
    if player ~= -1 and distance < 2.5 then
        local playerPed = GetPlayerPed(player)
        local playerId = GetPlayerServerId(player)
        QBCore.Functions.TriggerCallback('police:server:isPlayerDead', function(result)
            if result then 
                QBCore.Functions.Progressbar("robbing_player", Lang:t("progressbar.robbing"), math.random(5000, 7000), false, true, {
                    disableMovement = true,
                    disableCarMovement = true,
                    disableMouse = false,
                    disableCombat = true,
                }, {
                    animDict = "random@shop_robbery",
                    anim = "robbery_action_b",
                    flags = 16,
                }, {}, {}, function() -- Done
                    local plyCoords = GetEntityCoords(playerPed)
                    local pos = GetEntityCoords(ped)
                    if #(pos - plyCoords) < 2.5 then
                        StopAnimTask(ped, "random@shop_robbery", "robbery_action_b", 1.0)
                        TriggerServerEvent("inventory:server:OpenInventory", "otherplayer", playerId)
                        TriggerEvent("inventory:server:RobPlayer", playerId)
                        -- TriggerServerEvent("inventory:server:LockInv", playerId, true)
                    else
                        QBCore.Functions.Notify(Lang:t("error.none_nearby"), "error")
                    end
                end, function() -- Cancel
                    StopAnimTask(ped, "random@shop_robbery", "robbery_action_b", 1.0)
                    QBCore.Functions.Notify(Lang:t("error.canceled"), "error")
                end)
            else
                if IsEntityPlayingAnim(playerPed, "missminuteman_1ig_2", "handsup_base", 3) or IsEntityPlayingAnim(playerPed, "mp_arresting", "idle", 3) then
                    QBCore.Functions.Progressbar("robbing_player", Lang:t("progressbar.robbing"), math.random(5000, 7000), false, true, {
                        disableMovement = true,
                        disableCarMovement = true,
                        disableMouse = false,
                        disableCombat = true,
                    }, {
                        animDict = "random@shop_robbery",
                        anim = "robbery_action_b",
                        flags = 16,
                    }, {}, {}, function() -- Done
                        local plyCoords = GetEntityCoords(playerPed)
                        local pos = GetEntityCoords(ped)
                        if #(pos - plyCoords) < 2.5 then
                            StopAnimTask(ped, "random@shop_robbery", "robbery_action_b", 1.0)
                            TriggerServerEvent("inventory:server:OpenInventory", "otherplayer", playerId)
                            TriggerEvent("inventory:server:RobPlayer", playerId)
                        else
                            QBCore.Functions.Notify(Lang:t("error.none_nearby"), "error")
                        end
                    end, function() -- Cancel
                        StopAnimTask(ped, "random@shop_robbery", "robbery_action_b", 1.0)
                        QBCore.Functions.Notify(Lang:t("error.canceled"), "error")
                    end)
                end
            end
        end, playerId)
    else
        QBCore.Functions.Notify(Lang:t("error.none_nearby"), "error")
    end
end)

RegisterNetEvent('police:client:JailCommand', function(playerId, time)
    TriggerServerEvent("police:server:JailPlayer", playerId, tonumber(time))
end)

RegisterNetEvent('police:client:BillCommand', function(playerId, price)
    TriggerServerEvent("police:server:BillPlayer", playerId, tonumber(price))
end)

RegisterNetEvent('police:client:JailPlayer', function()
    TriggerServerEvent("police:server:JailPlayerMenu")
end)

RegisterNetEvent('police:client:billplayer', function()
    TriggerServerEvent("police:server:billplayer")
end)

RegisterNetEvent('police:server:JailPlayerMenuThird', function(data)
    local dialog = exports['qb-input']:ShowInput({
        header = Lang:t('info.jail_time_input'),
        submitText = Lang:t('info.submit'),
        inputs = {
            {
                text = Lang:t('info.time_months'),
                name = "jailtime",
                type = "number",
                isRequired = true
            }
        }
    })
    if not dialog then return end
    if tonumber(dialog['jailtime']) > 0 then
        TriggerServerEvent("police:server:JailPlayer", data.ID, tonumber(dialog['jailtime']))
    else
        QBCore.Functions.Notify(Lang:t("error.time_higher"), "error")
    end
end)

RegisterNetEvent('police:server:billplayerMenuThird', function(data)
    local dialog = exports['qb-input']:ShowInput({
        header = 'Bill',
        submitText = Lang:t('info.submit'),
        inputs = {
            {
                text = 'Bill amount',
                name = "billamount",
                type = "number",
                isRequired = true
            }
        }
    })
    if not dialog then return end
    if tonumber(dialog['billamount']) > 0 then
        TriggerServerEvent("police:server:BillPlayerFinal", data.ID, tonumber(dialog['billamount']))
    else
        QBCore.Functions.Notify("Amount must be higher than 0", "error")
    end
end)

RegisterNetEvent('police:server:JailPlayerMenuSecond', function(players)
    if players then 
        local JailMenu = {
            {
                header = "Jail",
                isMenuHeader = true, -- Set to true to make a nonclickable title
            },
        }
        for k, v in pairs(players) do 
            JailMenu[#JailMenu + 1] = {
                header = 'Name : '..v.name,
                txt = 'ID : '..v.id,
                params = {
                    event = 'police:server:JailPlayerMenuThird',
                    args = {
                        ID = v.id,
                        name = v.name
                    }
                }
            }
        end
        JailMenu[#JailMenu + 1] = {
            header = "Exit",
            params = {
                event = "qb-menu:closeMenu",
            }
        }
        if #JailMenu > 0 then 
            exports['qb-menu']:openMenu(JailMenu)
        end
    end
end)

RegisterNetEvent('police:server:billplayerMenuSecond', function(players)
    if players then 
        local BillMenu = {
            {
                header = "Bill",
                isMenuHeader = true, -- Set to true to make a nonclickable title
            },
        }
        for k, v in pairs(players) do 
            BillMenu[#BillMenu + 1] = {
                header = 'Name : '..v.name,
                txt = 'ID : '..v.id,
                params = {
                    event = 'police:server:billplayerMenuThird',
                    args = {
                        ID = v.id,
                        name = v.name
                    }
                }
            }
        end
        BillMenu[#BillMenu + 1] = {
            header = "Exit",
            params = {
                event = "qb-menu:closeMenu",
            }
        }
        if #BillMenu > 0 then 
            exports['qb-menu']:openMenu(BillMenu)
        end
    end
end)

RegisterNetEvent('police:client:BillPlayer', function()
    local player, distance = QBCore.Functions.GetClosestPlayer()
    if player ~= -1 and distance < 2.5 then
        local playerId = GetPlayerServerId(player)
        local dialog = exports['qb-input']:ShowInput({
            header = Lang:t('info.bill'),
            submitText = Lang:t('info.submit'),
            inputs = {
                {
                    text = Lang:t('info.amount'),
                    name = "bill",
                    type = "number",
                    isRequired = true
                }
            }
        })
        if tonumber(dialog['bill']) > 0 then
            TriggerServerEvent("police:server:BillPlayer", playerId, tonumber(dialog['bill']))
        else
            QBCore.Functions.Notify(Lang:t("error.amount_higher"), "error")
        end
    else
        QBCore.Functions.Notify(Lang:t("error.none_nearby"), "error")
    end
end)

RegisterNetEvent('police:client:PutPlayerInVehicle', function()
    local player, distance = QBCore.Functions.GetClosestPlayer()
    if player ~= -1 and distance < 2.5 then
        local playerId = GetPlayerServerId(player)
        if not isHandcuffed and not isEscorted then
            TriggerServerEvent("police:server:PutPlayerInVehicle", playerId)
        end
    else
        QBCore.Functions.Notify(Lang:t("error.none_nearby"), "error")
    end
end)

RegisterNetEvent('police:client:SetPlayerOutVehicle', function()
    local player, distance = QBCore.Functions.GetClosestPlayer()
    if player ~= -1 and distance < 2.5 then
        local playerId = GetPlayerServerId(player)
        if not isHandcuffed and not isEscorted then
            TriggerServerEvent("police:server:SetPlayerOutVehicle", playerId)
        end
    else
        QBCore.Functions.Notify(Lang:t("error.none_nearby"), "error")
    end
end)

RegisterNetEvent('police:client:EscortPlayer', function()
    local player, distance = QBCore.Functions.GetClosestPlayer()
    if player ~= -1 and distance < 2.5 then
        local playerId = GetPlayerServerId(player)
        if not isHandcuffed and not isEscorted then
            TriggerServerEvent("police:server:EscortPlayer", playerId)
        end
    else
        QBCore.Functions.Notify(Lang:t("error.none_nearby"), "error")
    end
end)

RegisterNetEvent('police:client:KidnapPlayer', function()
    local player, distance = QBCore.Functions.GetClosestPlayer()
    if player ~= -1 and distance < 2.5 then
        local playerId = GetPlayerServerId(player)
        if not IsPedInAnyVehicle(GetPlayerPed(player)) then
            if not isHandcuffed and not isEscorted then
                TriggerServerEvent("police:server:KidnapPlayer", playerId)
            end
        end
    else
        QBCore.Functions.Notify(Lang:t("error.none_nearby"), "error")
    end
end)

RegisterNetEvent('qb-police:client:show:tablet', function()
    QBCore.Functions.AddProp('Tablet')
    QBCore.Functions.RequestAnimationDict('amb@code_human_in_bus_passenger_idles@female@tablet@base')
    TaskPlayAnim(PlayerPedId(), "amb@code_human_in_bus_passenger_idles@female@tablet@base", "base", 3.0, 3.0, -1, 49, 0, 0, 0, 0)
    Citizen.Wait(500)
    SetNuiFocus(true, true)
    SendNUIMessage({
        type = "databank",
    })
end)

RegisterNUICallback('closeDatabank', function()
    SetNuiFocus(false, false)
    PlaySoundFrontend(-1, "NAV", "HUD_AMMO_SHOP_SOUNDSET", 1)
    TaskPlayAnim(PlayerPedId(), "amb@code_human_in_bus_passenger_idles@female@tablet@base", "exit", 3.0, 3.0, -1, 49, 0, 0, 0, 0)
    QBCore.Functions.RemoveProp()
end)

RegisterNetEvent('police:client:CuffPlayerSoft', function()
    if not IsPedRagdoll(PlayerPedId()) then
        local player, distance = QBCore.Functions.GetClosestPlayer()
        if player ~= -1 and distance < 1.5 then
            local playerId = GetPlayerServerId(player)
            if not IsPedInAnyVehicle(GetPlayerPed(player)) and not IsPedInAnyVehicle(PlayerPedId()) then
                QBCore.Functions.TriggerCallback('police:server:isVictomCuffed', function(isVictomCuffed)
                    if isVictomCuffed then 
                        TriggerServerEvent("police:server:CuffPlayer", playerId, true)
                        HandCuffAnimation()
                    else
                        TriggerServerEvent("police:server:CuffPlayer", playerId, true)
                        HandCuffAnimation()
                    end
                end, playerId)
            else
                QBCore.Functions.Notify(Lang:t("error.vehicle_cuff"), "error")
            end
        else
            QBCore.Functions.Notify(Lang:t("error.none_nearby"), "error")
        end
    else
        Wait(2000)
    end
end)

RegisterNetEvent('police:client:CuffPlayer', function()
    if not IsPedRagdoll(PlayerPedId()) then
        local player, distance = QBCore.Functions.GetClosestPlayer()
        if player ~= -1 and distance < 1.5 then
            QBCore.Functions.TriggerCallback('QBCore:HasItem', function(result)
                if result then
                    local playerId = GetPlayerServerId(player)
                    if not IsPedInAnyVehicle(GetPlayerPed(player)) and not IsPedInAnyVehicle(PlayerPedId()) then
                        TriggerServerEvent("police:server:CuffPlayer", playerId, false)
                        HandCuffAnimation()
                    else
                        QBCore.Functions.Notify(Lang:t("error.vehicle_cuff"), "error")
                    end
                else
                    QBCore.Functions.Notify(Lang:t("error.no_cuff"), "error")
                end
            end, Config.HandCuffItem)
        else
            QBCore.Functions.Notify(Lang:t("error.none_nearby"), "error")
        end
    else
        Wait(2000)
    end
end)

RegisterNetEvent('police:client:GetEscorted', function(playerId)
    local ped = PlayerPedId()
    QBCore.Functions.GetPlayerData(function(PlayerData)
        if PlayerData.metadata["isdead"] or isHandcuffed or PlayerData.metadata["inlaststand"] then
            if not isEscorted then
                isEscorted = true
                draggerId = playerId
                local dragger = GetPlayerPed(GetPlayerFromServerId(playerId))
                SetEntityCoords(ped, GetOffsetFromEntityInWorldCoords(dragger, 0.0, 0.45, 0.0))
                AttachEntityToEntity(ped, dragger, 11816, 0.45, 0.45, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
            else
                isEscorted = false
                DetachEntity(ped, true, false)
            end
            TriggerEvent('hospital:client:isEscorted', isEscorted)
        end
    end)
end)

RegisterNetEvent('police:client:DeEscort', function()
    isEscorted = false
    TriggerEvent('hospital:client:isEscorted', isEscorted)
    DetachEntity(PlayerPedId(), true, false)
end)

RegisterNetEvent('police:client:GetKidnappedTarget', function(playerId)
    local ped = PlayerPedId()
    QBCore.Functions.GetPlayerData(function(PlayerData)
        if not isEscorted then
            isEscorted = true
            isKidnapped = true
            KidnapperID = playerId
            draggerId = playerId
            local dragger = GetPlayerPed(GetPlayerFromServerId(playerId))
            RequestAnimDict("nm")

            while not HasAnimDictLoaded("nm") do
                Wait(10)
            end
            AttachEntityToEntity(ped, dragger, 0, 0.27, 0.15, 0.63, 0.5, 0.5, 0.0, false, false, false, false, 2, false)
            TaskPlayAnim(ped, "nm", "firemans_carry", 8.0, -8.0, 100000, 33, 0, false, false, false)
        else
            isEscorted = false
            isKidnapped = false
            KidnapperID = 0
            DetachEntity(ped, true, false)
            ClearPedTasksImmediately(ped)
        end
        TriggerEvent('hospital:client:isEscorted', isEscorted)
    end)
end)

RegisterNetEvent('police:client:GetKidnappedDragger', function(playerId)
    QBCore.Functions.GetPlayerData(function(PlayerData)
        if not isEscorting then
            draggerId = playerId
            local dragger = PlayerPedId()
            RequestAnimDict("missfinale_c2mcs_1")

            while not HasAnimDictLoaded("missfinale_c2mcs_1") do
                Wait(10)
            end
            TaskPlayAnim(dragger, "missfinale_c2mcs_1", "fin_c2_mcs_1_camman", 8.0, -8.0, 100000, 49, 0, false, false, false)
            isEscorting = true
        else
            local dragger = PlayerPedId()
            ClearPedSecondaryTask(dragger)
            ClearPedTasksImmediately(dragger)
            isEscorting = false
        end
        TriggerEvent('hospital:client:SetEscortingState', isEscorting)
        TriggerEvent('qb-kidnapping:client:SetKidnapping', isEscorting)
    end)
end)

local KidnapTxt = false

CreateThread(function()
    while true do 
        local sleep = 1000
        if isKidnapped then 
            sleep = 2
            if not KidnapTxt then 
                KidnapTxt = true 
                exports['qb-ui']:DrawText("[ E ]")
            end
            if IsControlJustPressed(0, 38) then
                if KidnapperID ~= 0 then 
                    TriggerServerEvent('police:server:RemoveKidnapPlayer', KidnapperID)
                end
                exports['qb-ui']:HideText()
                KidnapTxt = false 
                Wait(50)
            end
        end
        Wait(sleep)
    end
end)

RegisterNetEvent('police:client:RemoveKidnappedTarget', function()
    local dragger = PlayerPedId()
    local ped = PlayerPedId()
    ClearPedSecondaryTask(dragger)
    ClearPedTasksImmediately(dragger)
    DetachEntity(ped, true, false)
    ClearPedTasksImmediately(ped)
    isEscorting = false
    isEscorted = false
    isKidnapped = false
    KidnapperID = 0
    TriggerEvent('hospital:client:isEscorted', isEscorted)
    TriggerEvent('hospital:client:SetEscortingState', isEscorting)
    exports['qb-ui']:HideText()
    KidnapTxt = false 
    Wait(50)
end)

RegisterNetEvent('police:client:GetCuffed', function(playerId, isSoftcuff)
    local ped = PlayerPedId()
    if not isHandcuffed then
        isHandcuffed = true
        TriggerServerEvent('police:server:SetHandcuffStatus', true)
        ClearPedTasksImmediately(ped)
        if GetSelectedPedWeapon(ped) ~= `WEAPON_UNARMED` then
            SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
        end
        if not isSoftcuff then
            cuffType = 16
            GetCuffedAnimation(playerId)
            QBCore.Functions.Notify(Lang:t('info.cuff'), 'primary')
        else
            cuffType = 49
            GetCuffedAnimation(playerId)
            QBCore.Functions.Notify(Lang:t('info.cuffed_walk'), 'primary')
        end
    else
        isHandcuffed = false
        isEscorted = false
        TriggerEvent('hospital:client:isEscorted', isEscorted)
        DetachEntity(ped, true, false)
        TriggerServerEvent('police:server:SetHandcuffStatus', false)
        ClearPedTasksImmediately(ped)
        TriggerServerEvent('InteractSound_SV:PlayOnSource', 'Uncuff', 0.2)
        QBCore.Functions.Notify(Lang:t('success.uncuffed'), 'success')
    end
end)

-- Threads
CreateThread(function()
    while true do
        Wait(1)
        if isEscorted then
            DisableAllControlActions(0)
            EnableControlAction(0, 1, true)
			EnableControlAction(0, 2, true)
            EnableControlAction(0, 245, true)
            EnableControlAction(0, 38, true)
            EnableControlAction(0, 322, true)
            EnableControlAction(0, 249, true)
            EnableControlAction(0, 46, true)
        end

        if isHandcuffed then
            DisableControlAction(0, 24, true) -- Attack
			DisableControlAction(0, 257, true) -- Attack 2
			DisableControlAction(0, 25, true) -- Aim
			DisableControlAction(0, 263, true) -- Melee Attack 1
            -- DisableControlAction(0,21,true) -- disable sprint
			DisableControlAction(0, 137, true) -- CAPSLOCK
			DisableControlAction(0, 45, true) -- Reload
			DisableControlAction(0, 22, true) -- Jump
			DisableControlAction(0, 44, true) -- Cover
			DisableControlAction(0, 37, true) -- Select Weapon
			DisableControlAction(0, 23, true) -- Also 'enter'?

			DisableControlAction(0, 288, true) -- Disable phone
			DisableControlAction(0, 289, true) -- Inventory
			DisableControlAction(0, 170, true) -- Animations
			DisableControlAction(0, 167, true) -- Job

			DisableControlAction(0, 26, true) -- Disable looking behind
			DisableControlAction(0, 73, true) -- Disable clearing animation
			DisableControlAction(2, 199, true) -- Disable pause screen

			DisableControlAction(0, 59, true) -- Disable steering in vehicle
			DisableControlAction(0, 71, true) -- Disable driving forward in vehicle
			DisableControlAction(0, 72, true) -- Disable reversing in vehicle

			DisableControlAction(2, 36, true) -- Disable going stealth

			DisableControlAction(0, 264, true) -- Disable melee
			DisableControlAction(0, 257, true) -- Disable melee
			DisableControlAction(0, 140, true) -- Disable melee
			DisableControlAction(0, 141, true) -- Disable melee
			DisableControlAction(0, 142, true) -- Disable melee
			DisableControlAction(0, 143, true) -- Disable melee
			DisableControlAction(0, 75, true)  -- Disable exit vehicle
			DisableControlAction(27, 75, true) -- Disable exit vehicle
            EnableControlAction(0, 249, true) -- Added for talking while cuffed
            EnableControlAction(0, 46, true)  -- Added for talking while cuffed

            if (not IsEntityPlayingAnim(PlayerPedId(), "mp_arresting", "idle", 3) and not IsEntityPlayingAnim(PlayerPedId(), "mp_arrest_paired", "crook_p2_back_right", 3)) and not QBCore.Functions.GetPlayerData().metadata["isdead"] then
                loadAnimDict("mp_arresting")
                TaskPlayAnim(PlayerPedId(), "mp_arresting", "idle", 8.0, -8, -1, cuffType, 0, 0, 0, 0)
            end
        end
        if not isHandcuffed and not isEscorted then
            Wait(2000)
        end
    end
end)
