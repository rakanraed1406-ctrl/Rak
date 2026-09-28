local QBCore = exports['qb-core']:GetCoreObject()

-- Variables
local currentGarage = 0
local inFingerprint = false
local FingerPrintSessionId = nil
local currentVeh = nil 

-- Functions
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

local function loadAnimDict(dict) -- interactions, job,
    while (not HasAnimDictLoaded(dict)) do
        RequestAnimDict(dict)
        Citizen.Wait(10)
    end
end

local function GetClosestPlayer() -- interactions, job, tracker
    local closestPlayers = QBCore.Functions.GetPlayersFromCoords()
    local closestDistance = -1
    local closestPlayer = -1
    local coords = GetEntityCoords(PlayerPedId())

    for i = 1, #closestPlayers, 1 do
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

local function openFingerprintUI()
    SendNUIMessage({
        type = "fingerprintOpen"
    })
    inFingerprint = true
    SetNuiFocus(true, true)
end

local function SetCarItemsInfo()
	local items = {}
	for k, item in pairs(Config.CarItems) do
		local itemInfo = QBCore.Shared.Items[item.name:lower()]
		items[item.slot] = {
			name = itemInfo["name"],
			amount = tonumber(item.amount),
			info = item.info,
			label = itemInfo["label"],
			description = itemInfo["description"] and itemInfo["description"] or "",
			weight = itemInfo["weight"],
			type = itemInfo["type"],
			unique = itemInfo["unique"],
			useable = itemInfo["useable"],
			image = itemInfo["image"],
			slot = item.slot,
		}
	end
	Config.CarItems = items
end

local function doCarDamage(currentVehicle, veh)
	local smash = false
	local damageOutside = false
	local damageOutside2 = false
	local engine = veh.engine + 0.0
	local body = veh.body + 0.0

	if engine < 200.0 then engine = 200.0 end
    if engine  > 1000.0 then engine = 950.0 end
	if body < 150.0 then body = 150.0 end
	if body < 950.0 then smash = true end
	if body < 920.0 then damageOutside = true end
	if body < 920.0 then damageOutside2 = true end

    Citizen.Wait(100)
    SetVehicleEngineHealth(currentVehicle, engine)

	if smash then
		SmashVehicleWindow(currentVehicle, 0)
		SmashVehicleWindow(currentVehicle, 1)
		SmashVehicleWindow(currentVehicle, 2)
		SmashVehicleWindow(currentVehicle, 3)
		SmashVehicleWindow(currentVehicle, 4)
	end

	if damageOutside then
		SetVehicleDoorBroken(currentVehicle, 1, true)
		SetVehicleDoorBroken(currentVehicle, 6, true)
		SetVehicleDoorBroken(currentVehicle, 4, true)
	end

	if damageOutside2 then
		SetVehicleTyreBurst(currentVehicle, 1, false, 990.0)
		SetVehicleTyreBurst(currentVehicle, 2, false, 990.0)
		SetVehicleTyreBurst(currentVehicle, 3, false, 990.0)
		SetVehicleTyreBurst(currentVehicle, 4, false, 990.0)
	end

	if body < 1000 then
		SetVehicleBodyHealth(currentVehicle, 985.1)
	end
end

function TakeOutImpound(vehicle)
    local coords = Config.Locations["impound"][currentGarage]
    if coords then
        QBCore.Functions.SpawnVehicle(vehicle.vehicle, function(veh)
            QBCore.Functions.TriggerCallback('qb-garage:server:GetVehicleProperties', function(properties)
                QBCore.Functions.SetVehicleProperties(veh, properties)
                SetVehicleNumberPlateText(veh, vehicle.plate)
                SetEntityHeading(veh, coords.w)
                exports['LegacyFuel']:SetFuel(veh, vehicle.fuel)
                doCarDamage(veh, vehicle)
                TriggerServerEvent('police:server:TakeOutImpound',vehicle.plate)
                closeMenuFull()
                TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
                TriggerEvent("vehiclekeys:client:SetOwner", QBCore.Functions.GetPlate(veh))
                SetVehicleEngineOn(veh, true, true)
            end, vehicle.plate)
        end, coords, true)
    end
end

function TakeOutVehicle(vehicleInfo)
    local coords = Config.Locations["vehicle"][currentGarage]
    if coords then
        QBCore.Functions.SpawnVehicle(vehicleInfo, function(veh)
            SetCarItemsInfo()
            SetVehicleNumberPlateText(veh, Lang:t('info.police_plate')..tostring(math.random(1000, 9999)))
            SetEntityHeading(veh, coords.w)
            exports['LegacyFuel']:SetFuel(veh, 100.0)
            closeMenuFull()
            if Config.VehicleSettings[vehicleInfo] ~= nil then
                QBCore.Shared.SetDefaultVehicleExtras(veh, Config.VehicleSettings[vehicleInfo].extras)
            end
            -- TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
            TriggerEvent("vehiclekeys:client:SetOwner", QBCore.Functions.GetPlate(veh))
            -- TriggerServerEvent("inventory:server:addTrunkItems", QBCore.Functions.GetPlate(veh), Config.CarItems)
            SetVehicleEngineOn(veh, true, true)
            currentVeh = veh
        end, coords, true)
    end
end

local function IsArmoryWhitelist() -- being removed
    local retval = false

    if QBCore.Functions.GetPlayerData().job.name == 'police' then
        retval = true
    end
    return retval
end

local function SetWeaponSeries()
    for k, v in pairs(Config.Items.items) do
        if Config.Items.items[k].type == "weapon" then 
            Config.Items.items[k].info.serie = 'PD'.. tostring(QBCore.Shared.RandomStr(3) .. QBCore.Shared.RandomInt(1) .. QBCore.Shared.RandomStr(2) .. QBCore.Shared.RandomInt(3) .. QBCore.Shared.RandomStr(4))
        end
    end
end

local function SetSheriffWeaponSeries()
    for k, v in pairs(Config.Items.items) do
        if k < 6 then
            Config.Items.items[k].info.serie = 'SH'.. tostring(QBCore.Shared.RandomStr(3) .. QBCore.Shared.RandomInt(1) .. QBCore.Shared.RandomStr(2) .. QBCore.Shared.RandomInt(3) .. QBCore.Shared.RandomStr(4))
        end
    end
end

function MenuGarage(currentSelection)
    local vehicleMenu = {
        {
            header = Lang:t('menu.garage_title'),
            isMenuHeader = true
        }
    }

    local authorizedVehicles = Config.AuthorizedVehicles[QBCore.Functions.GetPlayerData().job.grade.level]
    for veh, label in pairs(authorizedVehicles) do
        vehicleMenu[#vehicleMenu+1] = {
            header = label,
            txt = "",
            params = {
                event = "police:client:TakeOutVehicle",
                args = {
                    vehicle = veh,
                    currentSelection = currentSelection
                }
            }
        }
    end

    if IsArmoryWhitelist() then
        for veh, label in pairs(Config.WhitelistedVehicles) do
            vehicleMenu[#vehicleMenu+1] = {
                header = label,
                txt = "",
                params = {
                    event = "police:client:TakeOutVehicle",
                    args = {
                        vehicle = veh,
                        currentSelection = currentSelection
                    }
                }
            }
        end
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

function MenuImpound(currentSelection)
    local impoundMenu = {
        {
            header = Lang:t('menu.impound'),
            isMenuHeader = true
        }
    }
    QBCore.Functions.TriggerCallback("police:GetImpoundedVehicles", function(result)
        local shouldContinue = false
        if result == nil then
            QBCore.Functions.Notify(Lang:t("error.no_impound"), "error", 5000)
        else
            shouldContinue = true
            for _ , v in pairs(result) do
                local enginePercent = QBCore.Shared.Round(v.engine / 10, 0)
                local bodyPercent = QBCore.Shared.Round(v.body / 10, 0)
                local currentFuel = v.fuel
                local vname = QBCore.Shared.Vehicles[v.vehicle].name

                impoundMenu[#impoundMenu+1] = {
                    header = vname.." ["..v.plate.."]",
                    txt =  Lang:t('info.vehicle_info', {value = enginePercent, value2 = currentFuel}),
                    params = {
                        event = "police:client:TakeOutImpound",
                        args = {
                            vehicle = v,
                            currentSelection = currentSelection
                        }
                    }
                }
            end
        end


        if shouldContinue then
            impoundMenu[#impoundMenu+1] = {
                header = Lang:t('menu.close'),
                txt = "",
                params = {
                    event = "qb-menu:client:closeMenu"
                }
            }
            exports['qb-menu']:openMenu(impoundMenu)
        end
    end)

end

function closeMenuFull()
    exports['qb-menu']:closeMenu()
end

--NUI Callbacks
RegisterNUICallback('closeFingerprint', function()
    SetNuiFocus(false, false)
    inFingerprint = false
end)

--Events
RegisterNetEvent('police:client:showFingerprint', function(playerId)
    openFingerprintUI()
    FingerPrintSessionId = playerId
end)

RegisterNetEvent('police:client:showFingerprintId', function(fid)
    SendNUIMessage({
        type = "updateFingerprintId",
        fingerprintId = fid
    })
    PlaySound(-1, "Event_Start_Text", "GTAO_FM_Events_Soundset", 0, 0, 1)
end)

RegisterNUICallback('doFingerScan', function(data)
    TriggerServerEvent('police:server:showFingerprintId', FingerPrintSessionId)
end)

RegisterNetEvent('police:client:SendEmergencyMessage', function(coords, message)
    TriggerServerEvent("police:server:SendEmergencyMessage", coords, message)
    TriggerEvent("police:client:CallAnim")
end)

RegisterNetEvent('police:client:EmergencySound', function()
    PlaySound(-1, "Event_Start_Text", "GTAO_FM_Events_Soundset", 0, 0, 1)
end)

RegisterNetEvent('police:client:CallAnim', function()
    local isCalling = true
    local callCount = 5
    loadAnimDict("cellphone@")
    TaskPlayAnim(PlayerPedId(), 'cellphone@', 'cellphone_call_listen_base', 3.0, -1, -1, 49, 0, false, false, false)
    Citizen.Wait(1000)
    Citizen.CreateThread(function()
        while isCalling do
            Citizen.Wait(1000)
            callCount = callCount - 1
            if callCount <= 0 then
                isCalling = false
                StopAnimTask(PlayerPedId(), 'cellphone@', 'cellphone_call_listen_base', 1.0)
            end
        end
    end)
end)

local function isempty(text)
    return text == nil or text == '' or text == ' ' or text == '  ' or text == '   ' or text == '    ' or text == '     '
end

RegisterNetEvent('police:client:FlagMenu', function()
    lib.registerContext({
        id = 'flag_menu',
        title = 'Flags',
        options = {
            {
                title = 'Flag Plate',
                description = 'Flag A Plate',
                icon = 'fas fa-circle',
                onSelect = function()
                    local input = lib.inputDialog('Flag Plate', {
                        {type = 'input', label = 'Plate', description = 'Vehicle Plate'},
                        {type = 'input', label = 'Reason', description = 'Reason For Flag'},
                    })

                    if input and input[1] and not isempty(input[2]) then
                        TriggerServerEvent("police:server:flagplate", input[1], input[2])
                    else
                        QBCore.Functions.Notify("one of the input is empty", "error")
                    end
                end,
          },
          {
            title = 'Unflag Plate',
            description = 'Unflag A Plate',
            icon = 'fas fa-circle',
            onSelect = function()
                local input = lib.inputDialog('unflag Plate', {
                    {type = 'input', label = 'Plate', description = 'Vehicle Plate'},
                })

                if input and input[1] then
                    TriggerServerEvent("police:server:unflagplate", input[1])
                end
            end,
          },
          {
            title = 'Plate Info',
            description = 'Search For A Plate',
            icon = 'fas fa-circle',
            onSelect = function()
                local input = lib.inputDialog('Plate info', {
                    {type = 'input', label = 'Plate', description = 'Vehicle Plate'},
                })

                if input and input[1] then
                    TriggerServerEvent("plateinfo", input[1])
                end
            end,
          },
        }
    })
    lib.showContext('flag_menu')
end)

RegisterNetEvent('police:client:ImpoundVehicle', function(fullImpound, price)
    local vehicle = QBCore.Functions.GetClosestVehicle()
    local bodyDamage = math.ceil(GetVehicleBodyHealth(vehicle))
    local engineDamage = math.ceil(GetVehicleEngineHealth(vehicle))
    local totalFuel = exports['LegacyFuel']:GetFuel(vehicle)
    if vehicle ~= 0 and vehicle then
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        local vehpos = GetEntityCoords(vehicle)
        if #(pos - vehpos) < 10.0 and not IsPedInAnyVehicle(ped) then
            QBCore.Functions.Progressbar("impound-vehicle", "Depot vehicle..", math.random(4000, 5000), false, true, {
                disableMovement = true,
                disableCarMovement = false,
                disableMouse = false,
                disableCombat = true,
            }, {
                animDict = "random@mugging4",
                anim = "struggle_loop_b_thief",
                flags = 49,
            }, {}, {}, function() -- Done
                local plate = QBCore.Functions.GetPlate(vehicle)
                TriggerServerEvent("police:server:Impound", plate, fullImpound, price, bodyDamage, engineDamage, totalFuel)
                NetworkRequestControlOfEntity(vehicle)
                while NetworkGetEntityOwner(vehicle) ~= 128 do  -- Ensure we have entity ownership to prevent inconsistent vehicle deletion
                    NetworkRequestControlOfEntity(vehicle)
                    Wait(100)
                end
                QBCore.Functions.DeleteVehicle(vehicle)
                QBCore.Functions.Notify("Vehicle has been successfully removed!", "success")
            end, function()
                QBCore.Functions.Notify("Cancelled...", "error")
            end)
        end
    else
        QBCore.Functions.Notify("No vehicle found", "error")
    end
end)

RegisterNetEvent('qb-police:client:impoundnewmenu', function() 
    exports['qb-menu']:openMenu({
        {
            header = "Impound Vehicle",
            icon ="fad fa-car-garage",
            isMenuHeader = true, -- Set to true to make a nonclickable title
        },
		{
            header = "Normal impound",
			txt = "Send vehicle to impound",
            icon ="fad fa-garage-car",
            params = {
                event = "qb-police:client:impoundnewmenusecond",
                args = {
                    action = 1
                }
            }
        },
		{
            header = "Fine Impound",
			txt = "Send vehicle to impound with fine",
            icon ="fad fa-garage-open",
            params = {
                event = "qb-police:client:impoundnewmenusecond",
                args = {
                    action = 2
                }
            }
        },
		{
            header = "Full impound",
			txt = "Send vehicle to impound with fine and certain amount of days",
            icon ="fad fa-warehouse",
            params = {
                event = "qb-police:client:impoundnewmenusecond",
                args = {
                    action = 3
                }
            }
        },
    })
end)

local isInImpound = false
CreateThread(function()
    exports['qb-target']:AddGlobalVehicle({
        options = {
          {
            type = "client",
            icon = "fa-solid fa-car-burst",
            label = 'Impound/Depot',
            action = function(entity)
                if entity and entity ~= 0 then 
                    TriggerEvent('qb-police:client:newimpoundmenu', entity)
                end
              return true
            end,
            canInteract = function(entity, distance, data)
                if isInImpound then 
                    return false 
                end
                return true
            end,
            job = 'police',
          }
        },
        distance = 2.0,
      })
end)

RegisterNetEvent('qb-police:client:newimpoundmenu', function(vehicle) 
    if not vehicle then return end
    local Menu = {}
    Menu[#Menu + 1] = {
       header = "Impound/Depot Actions",
       icon = "fad fa-duotone fa-user-police-tie",
       isMenuHeader = true
    }
    Menu[#Menu + 1] = {
        header = 'Depot',
        txt = 'Send Vehicle to Depot',
        icon = "fad fa-solid fa-car-burst",
        params = {
            event = "qb-garage:cl:impoundaction",
            args = {
                action = 1,
                veh = vehicle,
            }
        }
    }
    Menu[#Menu + 1] = {
        header = 'Depot With Fine',
        txt = 'Send Vehicle to Depot With Fine',
        icon = "fad fa-duotone fa-money-bill",
        params = {
            event = "qb-garage:cl:impoundaction",
            args = {
                action = 2,
                veh = vehicle,
            }
        }
    }
    Menu[#Menu + 1] = {
        header ='Impound',
        txt = "Send Vehicle to impound With Money, hours",
        icon = "fad fa-lock",
        params = {
            event = "qb-garage:cl:impoundaction",
            args = {
                action = 3,
                veh = vehicle,
            }
        }
    }
    Menu[#Menu + 1] = {
        header ='Close Menu',
        icon = "fad fa-duotone fa-circle-xmark",
        params = {
            event = "qb-menu:client:closeMenu",
        }
    }
    exports['qb-menu']:openMenu(Menu)
end)



RegisterNetEvent("qb-garage:cl:impoundaction", function(data)
    local vehicle = data.veh
    if data.action == 1 then
        if isInImpound then return end 
        isInImpound = true
        local bodyDamage = math.ceil(GetVehicleBodyHealth(vehicle))
        local engineDamage = math.ceil(GetVehicleEngineHealth(vehicle))
        local totalFuel = exports['LegacyFuel']:GetFuel(vehicle)
        local ped = PlayerPedId()
        if not IsPedInAnyVehicle(ped) then
            local plate = QBCore.Functions.GetPlate(vehicle)
            local tempveh = NetworkGetNetworkIdFromEntity(vehicle)
            TriggerEvent('animations:client:EmoteCommandStart', {"notepad"})
            QBCore.Functions.Progressbar("impound-vehicle", "Depot vehicle", math.random(5000, 10000), false, true, {
                disableMovement = true,
                disableCarMovement = false,
                disableMouse = false,
                disableCombat = true,
            }, {}, {}, {}, function() -- Done
                TriggerEvent('animations:client:EmoteCommandStart', {"c"})
                TriggerServerEvent("police:server:Impound", plate, false, 0, bodyDamage, engineDamage, totalFuel, tempveh)
                QBCore.Functions.Notify("Vehicle has been successfully removed!", "success")
                isInImpound = false 
            end, function()
                TriggerEvent('animations:client:EmoteCommandStart', {"c"})
                QBCore.Functions.Notify("Cancelled...", "error")
                isInImpound = false 
            end)
        else
            isInImpound = false 
        end
    elseif data.action == 2 then
        local input = lib.inputDialog('Depot With Fine', {
            {type = 'number', label = 'Fine amount', icon = 'dollar-sign'},
        })
        if input and input[1] then 
            if isInImpound then return end 
            isInImpound = true 
            local bodyDamage = math.ceil(GetVehicleBodyHealth(vehicle))
            local engineDamage = math.ceil(GetVehicleEngineHealth(vehicle))
            local totalFuel = exports['LegacyFuel']:GetFuel(vehicle)
            local ped = PlayerPedId()
            if not IsPedInAnyVehicle(ped) then
                local plate = QBCore.Functions.GetPlate(vehicle)
                local tempveh = NetworkGetNetworkIdFromEntity(vehicle)
                TriggerEvent('animations:client:EmoteCommandStart', {"notepad"})
                QBCore.Functions.Progressbar("impound-vehicle", "Depot Vehicle", math.random(5000, 10000), false, true, {
                    disableMovement = true,
                    disableCarMovement = false,
                    disableMouse = false,
                    disableCombat = true,
                }, {}, {}, {}, function() -- Done
                    TriggerEvent('animations:client:EmoteCommandStart', {"c"})
                    TriggerServerEvent("police:server:Impound", plate, false, tonumber(input[1]), bodyDamage, engineDamage, totalFuel, tempveh)
                    QBCore.Functions.Notify("Vehicle has been successfully removed!", "success")
                    isInImpound = false 
                end, function()
                    TriggerEvent('animations:client:EmoteCommandStart', {"c"})
                    QBCore.Functions.Notify("Cancelled...", "error")
                    isInImpound = false 
                end)
            else
                isInImpound = false 
            end
        else
            isInImpound = false 
        end
    elseif data.action == 3 then
        if isInImpound then return end 
        isInImpound = true 
        local input = lib.inputDialog('Impound Vehicle With Price - Time', {
            {type = 'number', label = 'Fine amount', icon = 'dollar-sign'},
            {type = 'slider',
                label = 'Impond Hours',
                description = 'Some input description',
                required = true,
                default = 1,
                min = 1,
                max = 168
            },
        })
        if input and input[1] and input[2] then 
            if tonumber(input[1]) <= 0 then QBCore.Functions.Notify("You must put fine bigger than 0", "error") isInImpound = false return end
            local fine = tonumber(input[1]) or 100
            local Hours = tonumber(input[2]) * 3600
            local bodyDamage = math.ceil(GetVehicleBodyHealth(vehicle))
            local engineDamage = math.ceil(GetVehicleEngineHealth(vehicle))
            local totalFuel = exports['LegacyFuel']:GetFuel(vehicle)
            local ped = PlayerPedId()
            Hours = tostring(Hours) or '3600'
            if not IsPedInAnyVehicle(ped) then
                local plate = QBCore.Functions.GetPlate(vehicle)
                local tempveh = NetworkGetNetworkIdFromEntity(vehicle)
                SetEntityAsMissionEntity(vehicle)
                TriggerEvent('animations:client:EmoteCommandStart', {"notepad"})
                QBCore.Functions.Progressbar("impound-vehicle", "Impound Vehicle", math.random(5000, 10000), false, true, {
                    disableMovement = true,
                    disableCarMovement = false,
                    disableMouse = false,
                    disableCombat = true,
                }, {}, {}, {}, function() -- Done
                    TriggerEvent('animations:client:EmoteCommandStart', {"c"})
                    TriggerServerEvent("police:server:Impound", plate, false, fine, bodyDamage, engineDamage, totalFuel, tempveh, Hours)
                    QBCore.Functions.Notify("Vehicle has been successfully removed!", "success")
                    isInImpound = false 
                end, function()
                    TriggerEvent('animations:client:EmoteCommandStart', {"c"})
                    QBCore.Functions.Notify("Cancelled...", "error")
                    isInImpound = false 
                end)
            end
        else
            isInImpound = false 
        end
    end
end)
-- RegisterNetEvent('qb-police:client:newimpoundmenu', function(vehicle) 
--     if not vehicle then return end 
--     lib.registerContext({
--         id = 'some_menu',
--         title = 'Impound Actions',
--         options = {
--           {
--             title = 'Normal impound',
--             description = 'Send vehicle to impound',
--             icon = '1',
--             onSelect = function()
--                 if isInImpound then return end 
--                 isInImpound = true 
--                 local bodyDamage = math.ceil(GetVehicleBodyHealth(vehicle))
--                 local engineDamage = math.ceil(GetVehicleEngineHealth(vehicle))
--                 local totalFuel = exports['LegacyFuel']:GetFuel(vehicle)
--                 local ped = PlayerPedId()
--                 if not IsPedInAnyVehicle(ped) then
--                     local plate = QBCore.Functions.GetPlate(vehicle)
--                     local tempveh = NetworkGetNetworkIdFromEntity(vehicle)
--                     QBCore.Functions.Progressbar("impound-vehicle", "Depot vehicle..", math.random(5000, 10000), false, true, {
--                         disableMovement = true,
--                         disableCarMovement = false,
--                         disableMouse = false,
--                         disableCombat = true,
--                     }, {}, {}, {}, function() -- Done
--                         TriggerServerEvent("police:server:Impound", plate, false, 0, bodyDamage, engineDamage, totalFuel, tempveh)
--                         QBCore.Functions.Notify("Vehicle has been successfully removed!", "success")
--                         isInImpound = false 
--                     end, function()
--                         QBCore.Functions.Notify("Cancelled...", "error")
--                         isInImpound = false 
--                     end)
--                 end
--             end,
--           },
--           {
--             title = 'Impound With Fine',
--             description = 'Send vehicle to impound with fine',
--             icon = '2',
--             onSelect = function()
--                 local input = lib.inputDialog('Impond vehicle', {
--                     {type = 'number', label = 'Fine amount', description = 'Fine amount', icon = 'dollar-sign'},
--                 })
--                 if input and input[1] then 
--                     if isInImpound then return end 
--                     isInImpound = true 
--                     local bodyDamage = math.ceil(GetVehicleBodyHealth(vehicle))
--                     local engineDamage = math.ceil(GetVehicleEngineHealth(vehicle))
--                     local totalFuel = exports['LegacyFuel']:GetFuel(vehicle)
--                     local ped = PlayerPedId()
--                     if not IsPedInAnyVehicle(ped) then
--                         local plate = QBCore.Functions.GetPlate(vehicle)
--                         local tempveh = NetworkGetNetworkIdFromEntity(vehicle)
--                         QBCore.Functions.Progressbar("impound-vehicle", "Depot vehicle..", math.random(5000, 10000), false, true, {
--                             disableMovement = true,
--                             disableCarMovement = false,
--                             disableMouse = false,
--                             disableCombat = true,
--                         }, {}, {}, {}, function() -- Done
--                             TriggerServerEvent("police:server:Impound", plate, false, tonumber(input[1]), bodyDamage, engineDamage, totalFuel, tempveh)
--                             QBCore.Functions.Notify("Vehicle has been successfully removed!", "success")
--                             isInImpound = false 
--                         end, function()
--                             QBCore.Functions.Notify("Cancelled...", "error")
--                             isInImpound = false 
--                         end)
--                     end
--                 else
--                     isInImpound = false 
--                 end
--             end,
--           },
--           {
--             title = 'Full impound',
--             description = 'Send vehicle to impound with fine and certain amount of days',
--             icon = '3',
--             onSelect = function()
--                 if isInImpound then return end 
--                 isInImpound = true 
--                 local input = lib.inputDialog('Full impound', {
--                     {type = 'number', label = 'Fine amount', description = 'Fine amount', icon = 'dollar-sign'},
--                     {type = 'slider',
--                         label = 'Impond Hours',
--                         description = 'Some input description',
--                         required = true,
--                         default = 1,
--                         min = 1,
--                         max = 72
--                     },
--                 })
--                 if input and input[1] and input[2] then 
--                     local fine = tonumber(input[1]) or 100
--                     local Hours = tonumber(input[2]) * 3600
--                     local bodyDamage = math.ceil(GetVehicleBodyHealth(vehicle))
--                     local engineDamage = math.ceil(GetVehicleEngineHealth(vehicle))
--                     local totalFuel = exports['LegacyFuel']:GetFuel(vehicle)
--                     local ped = PlayerPedId()
--                     Hours = tostring(Hours) or '3600'
--                     if not IsPedInAnyVehicle(ped) then
--                         local plate = QBCore.Functions.GetPlate(vehicle)
--                         local tempveh = NetworkGetNetworkIdFromEntity(vehicle)
--                         SetEntityAsMissionEntity(vehicle)
--                         QBCore.Functions.Progressbar("impound-vehicle", "Depot vehicle..", math.random(5000, 10000), false, true, {
--                             disableMovement = true,
--                             disableCarMovement = false,
--                             disableMouse = false,
--                             disableCombat = true,
--                         }, {}, {}, {}, function() -- Done
--                             TriggerServerEvent("police:server:Impound", plate, false, fine, bodyDamage, engineDamage, totalFuel, tempveh, Hours)
--                             QBCore.Functions.Notify("Vehicle has been successfully removed!", "success")
--                             isInImpound = false 
--                         end, function()
--                             QBCore.Functions.Notify("Cancelled...", "error")
--                             isInImpound = false 
--                         end)
--                     end
--                 else
--                     isInImpound = false 
--                 end
--             end,
--           }
--         }
--     })
--     lib.showContext('some_menu')
-- end)

RegisterNetEvent('qb-police:client:impoundnewmenusecond', function(data) 
    if data.action == 1 then 
        local vehicle, Distance = QBCore.Functions.GetClosestVehicle()
        if vehicle ~= 0 then
            if Distance < 1.7 then 
                local bodyDamage = math.ceil(GetVehicleBodyHealth(vehicle))
                local engineDamage = math.ceil(GetVehicleEngineHealth(vehicle))
                local totalFuel = exports['LegacyFuel']:GetFuel(vehicle)
                local ped = PlayerPedId()
                local pos = GetEntityCoords(ped)
                if not IsPedInAnyVehicle(ped) then
                    local plate = QBCore.Functions.GetPlate(vehicle)
                    local tempveh = NetworkGetNetworkIdFromEntity(vehicle)
                    QBCore.Functions.Progressbar("impound-vehicle", "Depot vehicle..", math.random(5000, 10000), false, true, {
                        disableMovement = true,
                        disableCarMovement = false,
                        disableMouse = false,
                        disableCombat = true,
                    }, {}, {}, {}, function() -- Done
                        TriggerServerEvent("police:server:Impound", plate, false, 0, bodyDamage, engineDamage, totalFuel, tempveh)
                        QBCore.Functions.Notify("Vehicle has been successfully removed!", "success")
                    end, function()
                        QBCore.Functions.Notify("Cancelled...", "error")
                    end)
                end
            else
                QBCore.Functions.Notify("No vehicle nearby!", "error")
            end
        else
            QBCore.Functions.Notify("No vehicle nearby!", "error")
        end
    elseif data.action == 2 then 
        local dialog = exports['qb-input']:ShowInput({
            header = "Impond vehicle",
            submitText = "Submit",
            inputs = {
                {
                    text = "Fine amount ($)", -- text you want to be displayed as a place holder
                    name = "fine", -- name of the input should be unique otherwise it might override
                    type = "number", -- type of the input - number will not allow non-number characters in the field so only accepts 0-9
                    isRequired = true -- Optional [accepted values: true | false] but will submit the form if no value is inputted
                },
            },
        })
        if dialog then 
            if dialog.fine then 
                local vehicle, Distance = QBCore.Functions.GetClosestVehicle()
                if vehicle ~= 0 then
                    if Distance < 1.7 then 
                        local bodyDamage = math.ceil(GetVehicleBodyHealth(vehicle))
                        local engineDamage = math.ceil(GetVehicleEngineHealth(vehicle))
                        local totalFuel = exports['LegacyFuel']:GetFuel(vehicle)
                        local ped = PlayerPedId()
                        local pos = GetEntityCoords(ped)
                        if not IsPedInAnyVehicle(ped) then
                            local plate = QBCore.Functions.GetPlate(vehicle)
                            local tempveh = NetworkGetNetworkIdFromEntity(vehicle)
                            QBCore.Functions.Progressbar("impound-vehicle", "Depot vehicle..", math.random(5000, 10000), false, true, {
                                disableMovement = true,
                                disableCarMovement = false,
                                disableMouse = false,
                                disableCombat = true,
                            }, {}, {}, {}, function() -- Done
                                TriggerServerEvent("police:server:Impound", plate, false, tonumber(dialog.fine), bodyDamage, engineDamage, totalFuel, tempveh)
                                QBCore.Functions.Notify("Vehicle has been successfully removed!", "success")
                            end, function()
                                QBCore.Functions.Notify("Cancelled...", "error")
                            end)
                        end
                    else
                        QBCore.Functions.Notify("No vehicle nearby!", "error")
                    end
                else
                    QBCore.Functions.Notify("No vehicle nearby!", "error")
                end
            end
        end
    elseif data.action == 3 then 
        local dialog = exports['qb-input']:ShowInput({
            header = "Impond vehicle",
            submitText = "Submit",
            inputs = {
                {
                    text = "Fine amount ($)", -- text you want to be displayed as a place holder
                    name = "fine", -- name of the input should be unique otherwise it might override
                    type = "number", -- type of the input - number will not allow non-number characters in the field so only accepts 0-9
                    isRequired = true -- Optional [accepted values: true | false] but will submit the form if no value is inputted
                },
                {
                    text = "How many days ?", -- text you want to be displayed as a input header
                    name = "someselect", -- name of the input should be unique otherwise it might override
                    type = "select", -- type of the input - Select is useful for 3+ amount of "or" options e.g; someselect = none OR other OR other2 OR other3...etc
                    options = { -- Select drop down options, the first option will by default be selected
                        { value = "1", text = "1 day" }, -- Options MUST include a value and a text option
                        { value = "2", text = "2 days" }, -- Options MUST include a value and a text option
                        { value = "3", text = "3 days" }, -- Options MUST include a value and a text option
                    }
                }
            },
        })
        if dialog then 
            local impoundDay = nil 
            local dTable = {
                ['1'] = "86400",
                ['2'] = "172800",
                ['3'] = "259200",
            }
            if dTable[dialog.someselect] then 
                impoundDay = dTable[dialog.someselect]
                if dialog.fine then 
                    local vehicle, Distance = QBCore.Functions.GetClosestVehicle()
                    local fine = tonumber(dialog.fine) or 100
                    if vehicle ~= 0 then
                        if Distance < 1.7 then 
                            local bodyDamage = math.ceil(GetVehicleBodyHealth(vehicle))
                            local engineDamage = math.ceil(GetVehicleEngineHealth(vehicle))
                            local totalFuel = exports['LegacyFuel']:GetFuel(vehicle)
                            local ped = PlayerPedId()
                            local pos = GetEntityCoords(ped)
                            if not IsPedInAnyVehicle(ped) then
                                local plate = QBCore.Functions.GetPlate(vehicle)
                                NetworkRegisterEntityAsNetworked(vehicle)
                                NetworkRequestControlOfEntity(vehicle)
                                while NetworkGetEntityOwner(vehicle) ~= 128 do  -- Ensure we have entity ownership to prevent inconsistent vehicle deletion
                                    NetworkRequestControlOfEntity(vehicle)
                                    Wait(100)
                                end
                                local tempveh = NetworkGetNetworkIdFromEntity(vehicle)
                                SetEntityAsMissionEntity(vehicle)
                                QBCore.Functions.Progressbar("impound-vehicle", "Depot vehicle..", math.random(5000, 10000), false, true, {
                                    disableMovement = true,
                                    disableCarMovement = false,
                                    disableMouse = false,
                                    disableCombat = true,
                                }, {}, {}, {}, function() -- Done
                                    TriggerServerEvent("police:server:Impound", plate, false, fine, bodyDamage, engineDamage, totalFuel, tempveh, impoundDay)
                                    QBCore.Functions.Notify("Vehicle has been successfully removed!", "success")
                                end, function()
                                    QBCore.Functions.Notify("Cancelled...", "error")
                                end)
                            end
                        else
                            QBCore.Functions.Notify("No vehicle nearby!", "error")
                        end
                    else
                        QBCore.Functions.Notify("No vehicle nearby!", "error")
                    end
                end
            end
        end
    end
end)

RegisterNetEvent('police:client:CheckStatus', function()
    QBCore.Functions.GetPlayerData(function(PlayerData)
        if PlayerData.job.name == "police" or PlayerData.job.name == "sheriff" then
            local player, distance = GetClosestPlayer()
            if player ~= -1 and distance < 5.0 then
                local playerId = GetPlayerServerId(player)
                QBCore.Functions.TriggerCallback('police:GetPlayerStatus', function(result)
                    if result then
                        for k, v in pairs(result) do
                            QBCore.Functions.Notify(''..v..'')
                        end
                    end
                end, playerId)
            else
                QBCore.Functions.Notify(Lang:t("error.none_nearby"), 'error',3000)
            end
        end
    end)
end)

RegisterNetEvent("police:client:VehicleMenuHeader", function (data)
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local takeDist = Config.Locations['vehicle'][data.currentSelection]
    takeDist = vector3(takeDist.x, takeDist.y,  takeDist.z)
    if #(pos - takeDist) <= 1.5 then
        MenuGarage(data.currentSelection)
        currentGarage = data.currentSelection
    end
end)


RegisterNetEvent("police:client:ImpoundMenuHeader", function (data)
    local pos = GetEntityCoords(PlayerPedId())
    local takeDist = Config.Locations['impound'][data.currentSelection]
    takeDist = vector3(takeDist.x, takeDist.y,  takeDist.z)
    if #(pos - takeDist) <= 1.5 then
        MenuImpound(data.currentSelection)
        currentGarage = data.currentSelection
    end
end)

RegisterNetEvent('police:client:TakeOutImpound', function(data)
    local pos = GetEntityCoords(PlayerPedId())
    local takeDist = Config.Locations['impound'][data.currentSelection]
    takeDist = vector3(takeDist.x, takeDist.y,  takeDist.z)
    if #(pos - takeDist) <= 1.5 then
        local vehicle = data.vehicle
        TakeOutImpound(vehicle)
    end
end)

RegisterNetEvent('police:client:TakeOutVehicle', function(data)
    local pos = GetEntityCoords(PlayerPedId())
    local takeDist = Config.Locations['vehicle'][data.currentSelection]
    takeDist = vector3(takeDist.x, takeDist.y,  takeDist.z)
    if #(pos - takeDist) <= 10 then
        local vehicle = data.vehicle
        TakeOutVehicle(vehicle)
    end
end)

-- RegisterNetEvent('police:client:EvidenceStashDrawer', function(data)
--     local currentEvidence = data.currentEvidence
--     local pos = GetEntityCoords(PlayerPedId())
--     local takeLoc = Config.Locations["evidence"][currentEvidence]

--     if not takeLoc then return end

--     if #(pos - takeLoc) <= 1.0 then
--         local drawer = exports['qb-input']:ShowInput({
--             header = Lang:t('info.evidence_stash', {value = currentEvidence}),
--             submitText = "open",
--             inputs = {
--                 {
--                     type = 'number',
--                     isRequired = true,
--                     name = 'slot',
--                     text = Lang:t('info.slot')
--                 }
--             }
--         })
--         if drawer then
--             if not drawer.slot then return end
--             TriggerServerEvent("inventory:server:OpenInventory", "stash", Lang:t('info.current_evidence', {value = currentEvidence, value2 = drawer.slot}), {
--                 maxweight = 4000000,
--                 slots = 500,
--             })
--             TriggerEvent("inventory:client:SetCurrentStash", Lang:t('info.current_evidence', {value = currentEvidence, value2 = drawer.slot}))
--         end
--     else
--         exports['qb-menu']:closeMenu()
--     end
-- end)


-- Toggle Duty in an event.

RegisterNetEvent('qb-police:policeactions', function()
	exports['qb-menu']:openMenu({
        {
            header = "Police Actions",
            icon = 'fad fa-city',
            isMenuHeader = true, -- Set to true to make a nonclickable title
        },
		{
            header = "Duty",
            icon = 'fad fa-thin fa-user-police',
			txt = "Sign in / out",
            params = {
                event = "qb-police:ToggleDuty",
            }
        },
		{
            header = "Dispatch",
            icon = 'fad fa-bullhorn',
			txt = "Sign in / out",
            params = {
                event = "qb-police:ToggleDispatch",
            }
        },
        {
            header = "Maybe later..",
            txt = "Here You Can Close The Menu And Come Back Soon",
            icon = "fa-duotone fa-clock",
            params = {
                event = "",
            }
        },
    })
end)

RegisterNetEvent('police:requestpickup', function()
    local PlayerData = QBCore.Functions.GetPlayerData()
    local pos = GetEntityCoords(PlayerPedId())
    local name = ""..PlayerData.charinfo.firstname.." "..PlayerData.charinfo.lastname..""
    local DispatchData = {
        jobs = {[PlayerData.job.name] = true},
        code = "xx-x",
        callname = "Request Pick Up",
        coords = pos,
        info = {{
            icon = "fas fa-passport",
            label = ""..name.." is requesting pick up",
        }},
        blip = {
            label = "xx-x",
            sprite = 42,
            colour = 0,
            scale = 0.6,
            flash = false,
            fadeTime = 250,
            leaveMiniMap = false
        },
        sound = "robbery",
    }
    TriggerServerEvent('qb-dispatch:server:NewAlert', DispatchData)
end)

RegisterNetEvent('police:requesthelpNormal', function()
    local PlayerData = QBCore.Functions.GetPlayerData()
    local pos = GetEntityCoords(PlayerPedId())
    local name = ""..PlayerData.charinfo.firstname.." "..PlayerData.charinfo.lastname..""
    local DispatchData = {
        jobs = {[PlayerData.job.name] = true},
        code = "xx-x",
        callname = "Requesting Help",
        coords = pos,
        info = {{
            icon = "fas fa-passport",
            label = ""..name.." is requesting Help",
        }},
        blip = {
            label = "xx-x",
            sprite = 42,
            colour = 0,
            scale = 0.6,
            flash = false,
            fadeTime = 250,
            leaveMiniMap = false
        },
        sound = "robbery",
    }
    TriggerServerEvent('qb-dispatch:server:NewAlert', DispatchData)
end)

RegisterNetEvent('police:requesthelpAergent', function()
    local PlayerData = QBCore.Functions.GetPlayerData()
    local pos = GetEntityCoords(PlayerPedId())
    local name = ""..PlayerData.charinfo.firstname.." "..PlayerData.charinfo.lastname..""
    local DispatchData = {
        jobs = {[PlayerData.job.name] = true},
        code = "xx-x",
        callname = "Officer Down",
        coords = pos,
        info = {{
            icon = "fas fa-passport",
            label = ""..name.." is requesting Help",
        }},
        blip = {
            label = "xx-x",
            sprite = 42,
            colour = 0,
            scale = 0.6,
            flash = false,
            fadeTime = 250,
            leaveMiniMap = false
        },
        sound = "panic",
    }
    TriggerServerEvent('qb-dispatch:server:NewAlert', DispatchData)
end)

RegisterNetEvent('qb-police:ToggleDuty', function()
    onDuty = not onDuty
    TriggerServerEvent("police:server:UpdateCurrentCops")
    TriggerServerEvent("QBCore:ToggleDuty")
    TriggerEvent('axon:updateDuty', onDuty)
    TriggerServerEvent('cd_dispatch:OnDutyChecks', onDuty)
    TriggerServerEvent('qb-phub:server:refresh', QBCore.Functions.GetPlayerData().job.name, onDuty)
end)

RegisterNetEvent('qb-police:ToggleDispatch', function()
    TriggerServerEvent('qb-police:ToggleDispatch')
    local PlayerData = QBCore.Functions.GetPlayerData()
    if PlayerData.metadata['cops']['dispatch'] then 
        TriggerServerEvent('qb-police:ToggleDispatchoff')
    else
        TriggerServerEvent('qb-police:ToggleDispatchone')
    end
end)

RegisterNetEvent('qb-police:policeArmory', function()
    PlayerJob = QBCore.Functions.GetPlayerData().job
    local authorizedItems = {
        label = Lang:t('menu.pol_armory'),
        slots = 30,
        items = {}
    }
    local index = 1
    for _, armoryItem in pairs(Config.Items.items) do
        for i=1, #armoryItem.authorizedJobGrades do
            if armoryItem.authorizedJobGrades[i] == PlayerJob.grade.level then
                authorizedItems.items[index] = armoryItem
                authorizedItems.items[index].slot = index
                index = index + 1
            end
        end
    end
    SetWeaponSeries()
    TriggerServerEvent("inventory:server:OpenInventory", "shop", "Police", authorizedItems)
end)

RegisterNetEvent('qb-police:sheriffArmory', function()
    PlayerJob = QBCore.Functions.GetPlayerData().job
    local authorizedItems = {
        label = "sheriff armory",
        slots = 30,
        items = {}
    }
    local index = 1
    for _, armoryItem in pairs(Config.SheriffItems.items) do
        for i=1, #armoryItem.authorizedJobGrades do
            if armoryItem.authorizedJobGrades[i] == PlayerJob.grade.level then
                authorizedItems.items[index] = armoryItem
                authorizedItems.items[index].slot = index
                index = index + 1
            end
        end
    end
    SetSheriffWeaponSeries()
    TriggerServerEvent("inventory:server:OpenInventory", "shop", "sheriff", authorizedItems)
end)

RegisterNetEvent('qb-police:policePersonalStash', function(data)
    if data.params.place == 'davis' then 
        TriggerServerEvent("inventory:server:OpenInventory", "stash", "policedavispersonalstash_"..QBCore.Functions.GetPlayerData().citizenid)
        TriggerEvent("inventory:client:SetCurrentStash", "policedavispersonalstash_"..QBCore.Functions.GetPlayerData().citizenid)
    else
        TriggerServerEvent("inventory:server:OpenInventory", "stash", "mrpdspersonalstash_"..QBCore.Functions.GetPlayerData().citizenid, {
            maxweight = 3000000,
            slots = 40,
        })
        TriggerEvent("inventory:client:SetCurrentStash", "mrpdspersonalstash_"..QBCore.Functions.GetPlayerData().citizenid)

    end
end)

RegisterNetEvent('qb-police:sheriffPersonalStash', function()
    TriggerServerEvent("inventory:server:OpenInventory", "stash", "sheriffstash_"..QBCore.Functions.GetPlayerData().citizenid)
    TriggerEvent("inventory:client:SetCurrentStash", "sheriffstash_"..QBCore.Functions.GetPlayerData().citizenid)
end)

RegisterNetEvent('qb-police:sandysheriffPersonalStash', function()
    TriggerServerEvent("inventory:server:OpenInventory", "stash", "sandysheriffstash_"..QBCore.Functions.GetPlayerData().citizenid)
    TriggerEvent("inventory:client:SetCurrentStash", "sandysheriffstash_"..QBCore.Functions.GetPlayerData().citizenid)
end)

RegisterNetEvent('qb-police:policeFinger', function()
    local player, distance = GetClosestPlayer()
    if player ~= -1 and distance < 2.5 then
        local playerId = GetPlayerServerId(player)
        TriggerServerEvent("police:server:showFingerprint", playerId)
    else
        QBCore.Functions.Notify(Lang:t("error.none_nearby"), 'error',3000)
    end
end)

-- Search the event police:client:EvidenceStashDrawer and replace
RegisterNetEvent('police:client:EvidenceStashDrawer', function(data)
    local currentEvidence = data.currentEvidence
    -- local pos = GetEntityCoords(PlayerPedId())
    -- local takeLoc = Config.Locations["evidence"][currentEvidence]

    -- if not takeLoc then return end

    -- if #(pos - takeLoc) <= 1.0 then
        local drawer = exports['qb-input']:ShowInput({
            header = Lang:t('info.evidence_stash', { value = currentEvidence }),
            submitText = 'open',
            inputs = {
                {
                    type = 'text',
                    isRequired = true,
                    name = 'slot',
                    text = "Case Number"
                }
            }
        })
        if drawer then
            if not drawer.slot then return end
            TriggerServerEvent('inventory:server:OpenInventory', 'stash', Lang:t('info.current_evidence', { value = currentEvidence, value2 = drawer.slot }), {
                maxweight = 4000000,
                slots = 500,
            })
            TriggerEvent('inventory:client:SetCurrentStash', Lang:t('info.current_evidence', { value = currentEvidence, value2 = drawer.slot }))
        end
    -- else
        -- exports['qb-menu']:closeMenu()
    -- end
end)



RegisterNetEvent('qb-police:policeEvidence', function(data)
    if data.params.place == 'davis' then 
        TriggerServerEvent("inventory:server:OpenInventory", "stash", "DavispoliceEvidence".. data.params.id, {
            maxweight = 4000000,
            slots = 500,
        })
        TriggerEvent("inventory:client:SetCurrentStash", "DavispoliceEvidence".. data.params.id)
    else
        TriggerServerEvent("inventory:server:OpenInventory", "stash", "policeEvidence".. data.params.id, {
            maxweight = 4000000,
            slots = 500,
        })
        TriggerEvent("inventory:client:SetCurrentStash", "policeEvidence".. data.params.id)
    end
end)

RegisterNetEvent('qb-police:sheriffEvidence', function(data)
    TriggerServerEvent("inventory:server:OpenInventory", "stash", "sheriffEvidence".. data.params.id, {
        maxweight = 4000000,
        slots = 500,
    })
    TriggerEvent("inventory:client:SetCurrentStash", "sheriffEvidence".. data.params.id)
end)

RegisterNetEvent('qb-police:sandysheriffEvidence', function(data)
    TriggerServerEvent("inventory:server:OpenInventory", "stash", "sandysheriffEvidence", {
        maxweight = 4000000,
        slots = 500,
    })
    TriggerEvent("inventory:client:SetCurrentStash", "sandysheriffEvidence")
end)

local heliEntety = nil

RegisterNetEvent('qb-police:policeHeli', function(data)
    local coords = Config.Locations["helicopter"][data.params.id]
    local pos = GetEntityCoords(PlayerPedId())
    local PlayerData = QBCore.Functions.GetPlayerData()
    if PlayerData.metadata.cops.iswing then 
        if #(pos - vector3(coords.x, coords.y, coords.z)) < 15 then
            if heliEntety then 
                if not heliEntety then return end
                QBCore.Functions.DeleteVehicle(heliEntety)
                heliEntety = nil
            else
                QBCore.Functions.SpawnVehicle(Config.PoliceHelicopter, function(veh)
                    SetVehicleLivery(veh , 0)
                    SetVehicleMod(veh, 0, 48)
                    SetVehicleNumberPlateText(veh, "LSPD"..tostring(math.random(1000, 9999)))
                    SetEntityHeading(veh, coords.w)
                    exports['LegacyFuel']:SetFuel(veh, 100.0)
                    closeMenuFull()
                    -- TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
                    TriggerEvent("vehiclekeys:client:SetOwner", QBCore.Functions.GetPlate(veh))
                    SetVehicleEngineOn(veh, true, true)
                    heliEntety = veh
                end, coords, true)
            end
        end
    else
        QBCore.Functions.Notify('You don\'t have air unit wing', 'error', 7500)
    end
end)

RegisterNetEvent('qb-police:policeHeliTaining', function(data)
    local coords = vec3(-1819.6239013672,-2813.8959960938,13.944267272949)
    local pos = GetEntityCoords(PlayerPedId())
    local PlayerData = QBCore.Functions.GetPlayerData()
    if PlayerData.metadata.cops.iswing then 
        if #(pos - vector3(coords.x, coords.y, coords.z)) < 30 then
            if heliEntety then 
                if not heliEntety then return end
                QBCore.Functions.DeleteVehicle(heliEntety)
                heliEntety = nil
            else
                local traincoords = vec4(-1819.6239013672,-2813.8959960938,13.944267272949, 60.438358306885)
                QBCore.Functions.SpawnVehicle(Config.PoliceHelicopter, function(veh)
                    SetVehicleLivery(veh , 0)
                    SetVehicleMod(veh, 0, 48)
                    SetVehicleNumberPlateText(veh, "LSPD"..tostring(math.random(1000, 9999)))
                    SetEntityHeading(veh, traincoords.w)
                    exports['LegacyFuel']:SetFuel(veh, 100.0)
                    closeMenuFull()
                    -- TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
                    TriggerEvent("vehiclekeys:client:SetOwner", QBCore.Functions.GetPlate(veh))
                    SetVehicleEngineOn(veh, true, true)
                    heliEntety = veh
                end, traincoords, true)
            end
        end
    else
        QBCore.Functions.Notify('You don\'t have air unit wing', 'error', 7500)
    end
end)

RegisterNetEvent('qb-police:sheriffHeli', function(data)
    local coords = Config.Locations["helicopter"][data.params.id]
    local pos = GetEntityCoords(PlayerPedId())
    local PlayerData = QBCore.Functions.GetPlayerData()
    -- if PlayerData.globalinfo.cops.iswing then 
        if #(pos - vector3(coords.x, coords.y, coords.z)) < 25 then
            if heliEntety then 
                if not heliEntety then return end
                QBCore.Functions.DeleteVehicle(heliEntety)
                heliEntety = nil
            else
                QBCore.Functions.SpawnVehicle(Config.SheriffHelicopter, function(veh)
                    SetVehicleLivery(veh , 1)
                    SetVehicleMod(veh, 0, 48)
                    SetVehicleNumberPlateText(veh, "SHRF"..tostring(math.random(1000, 9999)))
                    SetEntityHeading(veh, coords.w)
                    exports['LegacyFuel']:SetFuel(veh, 100.0)
                    closeMenuFull()
                    -- TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
                    TriggerEvent("vehiclekeys:client:SetOwner", QBCore.Functions.GetPlate(veh))
                    SetVehicleEngineOn(veh, true, true)
                    heliEntety = veh
                end, coords, true)
            end
        end
    -- else
    --     QBCore.Functions.Notify('You don\'t have wing', 'error', 7500)
    -- end
end)

RegisterNetEvent('qb-police:Vehicle', function(data)
end)

RegisterNetEvent('qb-police:policeBoss', function(data)
    if PlayerJob.name == "police" and PlayerJob.isboss then
        TriggerEvent("qb-bossmenu:client:OpenMenu")
    end
end)

RegisterNetEvent('qb-police:sheriffBoss', function(data)
    if PlayerJob.name == "sheriff" and PlayerJob.isboss then
        TriggerEvent("qb-bossmenu:client:OpenMenu")
    end
end)

RegisterNetEvent('qb-police:policeDavisVeh', function(data)
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local takeDist = Config.Locations['vehicle'][data.params.id]
    takeDist = vector3(takeDist.x, takeDist.y,  takeDist.z)
    if #(pos - takeDist) <= 10 then
        MenuGarage(data.params.id)
        currentGarage = data.params.id
    end
end)

RegisterNetEvent('qb-police:policeReturnVeh', function(data)
    if currentVeh then 
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        local vehPos = GetEntityCoords(currentVeh)
        if #(pos - vehPos) <= 50 then 
            DeleteVehicle(currentVeh)
        end
    end
end)

RegisterNetEvent('qb-police:trainingshop', function()
    local shopItems = {
        label = 'Police Training',
        slots = 30,
        items = {
            [1] = {
                name = "radio",
                price = 0,
                amount = 50,
                info = {},
                type = "item",
                slot = 1,
            },
            [2] = {
                name = "sandwich",
                price = 0,
                amount = 50,
                info = {},
                type = "item",
                slot = 2,
            },
            [3] = {
                name = "water_bottle",
                price = 0,
                amount = 50,
                info = {},
                type = "item",
                slot = 3,
            },
            [4] = {
                name = "bandage",
                price = 0,
                amount = 50,
                info = {},
                type = "item",
                slot = 4,
            },
        }
    }
    TriggerServerEvent("inventory:server:OpenInventory", "shop", "police", shopItems)
end)

RegisterNetEvent('qb-police:trainingVehicle', function()
    exports['qb-menu']:openMenu({
        {
            header = 'Ford',
            txt = "",
            params = {
                event = "qb-police:trainingVehicleS",
                args = {
                    model = 'npolvic',
                }
            }
        },
        {
            header = 'Motorcycle',
            txt = "",
            params = {
                event = "qb-police:trainingVehicleS",
                args = {
                    model = 'spc1bm',
                }
            }
        },
        {
            header = 'Sultan',
            txt = "",
            params = {
                event = "qb-police:trainingVehicleS",
                args = {
                    model = 'sultan',
                }
            }
        },
        {
            header = "Exit",
            params = {
                event = "qb-menu:closeMenu",
            }
        }
    })
end)

local trainingveh = nil

RegisterNetEvent('qb-police:trainingVehicleS', function(data)
    local coords = vec4(-1993.3497314453,-2085.3955078125,21.54673576355, 94.714393615723)
    local pos = GetEntityCoords(PlayerPedId())
    local PlayerData = QBCore.Functions.GetPlayerData()
    if #(pos - vector3(coords.x, coords.y, coords.z)) < 30 then
        if trainingveh then 
            if not trainingveh then return end
            QBCore.Functions.DeleteVehicle(trainingveh)
            trainingveh = nil
        else
            QBCore.Functions.SpawnVehicle(data.model, function(veh)
                SetVehicleLivery(veh , 0)
                SetVehicleMod(veh, 0, 48)
                SetVehicleNumberPlateText(veh, "LSPD"..tostring(math.random(1000, 9999)))
                SetEntityHeading(veh, coords.w)
                exports['LegacyFuel']:SetFuel(veh, 100.0)
                closeMenuFull()
                -- TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
                TriggerEvent("vehiclekeys:client:SetOwner", QBCore.Functions.GetPlate(veh))
                SetVehicleEngineOn(veh, true, true)
                trainingveh = veh
            end, coords, true)
        end
    end
end)

-- CreateThread(function()
--     Wait(1000)
--     local headerDrawn = false

--     while true do
--         local sleep = 2000
--         if LocalPlayer.state.isLoggedIn and PlayerJob.name == "police" then
--             local pos = GetEntityCoords(PlayerPedId())
--             for k, v in pairs(Config.Locations["impound"]) do
--                 if #(pos - vector3(v.x, v.y, v.z)) < 7.5 then
--                     if onDuty then
--                         sleep = 5
--                         DrawMarker(2, v.x, v.y, v.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.2, 0.15, 200, 0, 0, 222, false, false, false, true, false, false, false)
--                         if #(pos - vector3(v.x, v.y, v.z)) <= 1.5 then
--                             if IsPedInAnyVehicle(PlayerPedId(), false) then
--                                 DrawText3D(v.x, v.y, v.z, Lang:t('info.impound_veh'))
--                             else
--                                 if not headerDrawn then
--                                     headerDrawn = true
--                                     exports['qb-menu']:showHeader({
--                                         {
--                                             header = Lang:t('menu.pol_impound'),
--                                             params = {
--                                                 event = 'police:client:ImpoundMenuHeader',
--                                                 args = {
--                                                     currentSelection = k,
--                                                 }
--                                             }
--                                         }
--                                     })
--                                 end
--                             end
--                             if IsControlJustReleased(0, 38) then
--                                 if IsPedInAnyVehicle(PlayerPedId(), false) then
--                                     QBCore.Functions.DeleteVehicle(GetVehiclePedIsIn(PlayerPedId()))
--                                 end
--                             end
--                         else
--                             if headerDrawn then
--                                 headerDrawn = false
--                                 exports['qb-menu']:closeMenu()
--                             end
--                         end
--                     end
--                 end
--             end
--         end
--         Wait(sleep)
--     end
-- end)

-- Police Vehicle Garage
-- CreateThread(function()
--     Wait(1000)
--     local headerDrawn = false
--     while true do
--         local sleep = 2000
--         if LocalPlayer.state.isLoggedIn and PlayerJob.name == "police" then
--             local pos = GetEntityCoords(PlayerPedId())
--             for k, v in pairs(Config.Locations["vehicle"]) do
--                 if #(pos - vector3(v.x, v.y, v.z)) < 7.5 then
--                     if onDuty then
--                         sleep = 5
--                         DrawMarker(2, v.x, v.y, v.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.2, 0.15, 200, 0, 0, 222, false, false, false, true, false, false, false)
--                         if #(pos - vector3(v.x, v.y, v.z)) < 1.5 then
--                             if IsPedInAnyVehicle(PlayerPedId(), false) then
--                                 DrawText3D(v.x, v.y, v.z, Lang:t('info.store_veh'))
--                             else
--                                 if not headerDrawn then
--                                     headerDrawn = true
--                                     exports['qb-menu']:showHeader({
--                                         {
--                                             header = Lang:t('menu.pol_garage'),
--                                             params = {
--                                                 event = 'police:client:VehicleMenuHeader',
--                                                 args = {
--                                                     currentSelection = k,
--                                                 }
--                                             }
--                                         }
--                                     })
--                                 end
--                             end
--                             if IsControlJustReleased(0, 38) then
--                                 if IsPedInAnyVehicle(PlayerPedId(), false) then
--                                     QBCore.Functions.DeleteVehicle(GetVehiclePedIsIn(PlayerPedId()))
--                                 end
--                             end
--                         else
--                             if headerDrawn then
--                                 headerDrawn = false
--                                 exports['qb-menu']:closeMenu()
--                             end
--                         end
--                     end
--                 end
--             end
--         end
--         Wait(sleep)
--     end
-- end)
