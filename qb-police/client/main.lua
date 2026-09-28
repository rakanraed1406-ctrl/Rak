-- Variables
QBCore = exports['qb-core']:GetCoreObject()
isHandcuffed = false
cuffType = 1
isEscorted = false
draggerId = 0
PlayerJob = {}
onDuty = false
local DutyBlips = {}


Citizen.CreateThread(function()
    for k, v in pairs(Config.Target) do 
        -- exports['qb-target']:AddBoxZone(v.name, v.coords, v.info1, v.info2, {
        --     name= "depot"..v.name,
        --     heading= v.heading,
        --     debugPoly= v.debugPoly,
        --     minZ= v.minZ,
        --     maxZ= v.maxZ
        -- }, {
        --     options = { 
        --     { 
        --         type = v.type,
        --         event = v.event, 
        --         icon = v.icon,
        --         label = v.label,
        --         job = v.job,
        --         params = v.params,
        --         canInteract = v.canInteract,
        --     }
        --     },
        --     distance = v.distance, 
        -- })
        exports.interact:AddInteraction({
            coords = v.coords,
            distance = 3.0, -- optional
            interactDst = 1.0, -- optional
            id = 7, -- needed for removing interactions
            name = 'job', -- optional
            groups = {
                [v.job] = 0, -- Jobname | Job grade
            },
            options = {
                 {
                type = v.type,
                event = v.event, 
                label = v.label,
                params = v.params,
                canInteract = v.canInteract,
                },
            }
        })
    end
end)

-- Functions
local function CreateDutyBlips(playerId, playerLabel, playerJob, playerLocation)
    local ped = GetPlayerPed(playerId)
    local blip = GetBlipFromEntity(ped)
    if not DoesBlipExist(blip) then
        if NetworkIsPlayerActive(playerId) then
            blip = AddBlipForEntity(ped)
        else
            blip = AddBlipForCoord(playerLocation.x, playerLocation.y, playerLocation.z)
        end
        SetBlipSprite(blip, 1)
        ShowHeadingIndicatorOnBlip(blip, true)
        SetBlipRotation(blip, math.ceil(playerLocation.w))
        SetBlipScale(blip, 1.0)
        if playerJob == "police" then
            SetBlipColour(blip, 38)
        elseif playerJob == "sheriff" then 
            SetBlipColour(blip, 33)
        else
            SetBlipColour(blip, 41)
        end
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(playerLabel)
        EndTextCommandSetBlipName(blip)
        DutyBlips[#DutyBlips+1] = blip
    end

    if GetBlipFromEntity(PlayerPedId()) == blip then
        -- Ensure we remove our own blip.
        RemoveBlip(blip)
    end
end

-- Events
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    local player = QBCore.Functions.GetPlayerData()
    PlayerJob = player.job
    onDuty = player.job.onduty
    isHandcuffed = false
    TriggerServerEvent("QBCore:Server:SetMetaData", "ishandcuffed", false)
    TriggerServerEvent("police:server:SetHandcuffStatus", false)
    TriggerServerEvent("police:server:UpdateBlips")
    TriggerServerEvent("police:server:UpdateCurrentCops")
    if player.metadata['cops']['dispatch'] then 
        TriggerServerEvent('qb-police:ToggleDispatchoff')
    end

    if player.metadata.tracker then
        local trackerClothingData = {
            outfitData = {
                ["accessory"] = {
                    item = 13,
                    texture = 0
                }
            }
        }
        TriggerEvent('qb-clothing:client:loadOutfit', trackerClothingData)
    else
        local trackerClothingData = {
            outfitData = {
                ["accessory"] = {
                    item = -1,
                    texture = 0
                }
            }
        }
        TriggerEvent('qb-clothing:client:loadOutfit', trackerClothingData)
    end

    if PlayerJob and PlayerJob.name ~= "police" then
        if DutyBlips then
            for k, v in pairs(DutyBlips) do
                RemoveBlip(v)
            end
        end
        DutyBlips = {}
    end

    if PlayerJob and PlayerJob.name ~= "sheriff" then
        if DutyBlips then
            for k, v in pairs(DutyBlips) do
                RemoveBlip(v)
            end
        end
        DutyBlips = {}
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    TriggerServerEvent('police:server:UpdateBlips')
    TriggerServerEvent('police:server:SetHandcuffStatus', false)
    TriggerServerEvent('police:server:UpdateCurrentCops')
    isHandcuffed = false
    isEscorted = false
    PlayerJob = {}
    ClearPedTasks(PlayerPedId())
    DetachEntity(PlayerPedId(), true, false)
    if DutyBlips then
        for _, v in pairs(DutyBlips) do
            RemoveBlip(v)
        end
        DutyBlips = {}
    end
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    PlayerJob = JobInfo
    TriggerServerEvent("police:server:UpdateBlips")
    if JobInfo.name == "police" then
        if PlayerJob.onduty then
            TriggerServerEvent("QBCore:ToggleDuty")
            onDuty = false
        end
    end

    if JobInfo.name == "sheriff" then
        if PlayerJob.onduty then
            TriggerServerEvent("QBCore:ToggleDuty")
            onDuty = false
        end
    end

    if (PlayerJob ~= nil) and PlayerJob.name ~= "police" then
        if DutyBlips then
            for k, v in pairs(DutyBlips) do
                RemoveBlip(v)
            end
        end
        DutyBlips = {}
    end

    if (PlayerJob ~= nil) and PlayerJob.name ~= "sheriff" then
        if DutyBlips then
            for k, v in pairs(DutyBlips) do
                RemoveBlip(v)
            end
        end
        DutyBlips = {}
    end
end)

RegisterNetEvent('police:client:sendBillingMail', function(amount)
    SetTimeout(math.random(2500, 4000), function()
        local gender = Lang:t('info.mr')
        if QBCore.Functions.GetPlayerData().charinfo.gender == 1 then
            gender = Lang:t('info.mrs')
        end
        local charinfo = QBCore.Functions.GetPlayerData().charinfo
        TriggerServerEvent('qb-phone:server:sendNewMail', {
            sender = Lang:t('email.sender'),
            subject = Lang:t('email.subject'),
            message = Lang:t('email.message', {value = gender, value2 = charinfo.lastname, value3 = amount}),
            button = {}
        })
    end)
end)

local function CreatePoliceBlips()
    if PlayerJob and (PlayerJob.name == 'police' or PlayerJob.name == 'ambulance') then
        if DutyBlips then
            for _, v in pairs(DutyBlips) do
                RemoveBlip(v)
            end
        end
        DutyBlips = {}
        local players = GlobalState['policeplayers']
        if players then
            for _, data in pairs(players) do
                local id = GetPlayerFromServerId(data.source)
                CreateDutyBlips(id, data.label, data.job, data.location)
            end
        end
    end
end

-- CreateThread(function()
--     while true do
--         if LocalPlayer.state.isLoggedIn then
--             if PlayerJob and (PlayerJob.name == 'police' or PlayerJob.name == 'ambulance') then
--                 CreatePoliceBlips()
--             end
--         end
--         Wait(2000)
--     end
-- end)

RegisterNetEvent('police:client:UpdateBlips', function(players)
    local PlayerJob = QBCore.Functions.GetPlayerData().job
    if PlayerJob and (PlayerJob.name == 'police' or PlayerJob.name == 'ambulance') then
        if DutyBlips then
            for _, v in pairs(DutyBlips) do
                RemoveBlip(v)
            end
        end
        DutyBlips = {}
        if players then
            for _, data in pairs(players) do
                local id = GetPlayerFromServerId(data.source)
                CreateDutyBlips(id, data.label, data.job, data.location)
            end
        end
    end
end)

RegisterNetEvent('police:client:policeAlert', function(coords, text)
    local street1, street2 = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local street1name = GetStreetNameFromHashKey(street1)
    local street2name = GetStreetNameFromHashKey(street2)
    -- QBCore.Functions.Notify(''..text..'', 'warning')
    PlaySound(-1, "Lose_1st", "GTAO_FM_Events_Soundset", 0, 0, 1)
    local transG = 250
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    local blip2 = AddBlipForCoord(coords.x, coords.y, coords.z)
    local blipText = Lang:t('info.blip_text', {value = text})
    SetBlipSprite(blip, 60)
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
end)

RegisterNetEvent('police:client:SendToJail', function(time)
    TriggerServerEvent('police:server:SetHandcuffStatus', false)
    isHandcuffed = false
    isEscorted = false
    ClearPedTasks(PlayerPedId())
    DetachEntity(PlayerPedId(), true, false)
    TriggerEvent('prison:client:Enter', time)
end)


CreateThread(function()
    for k, station in pairs(Config.Locations["stations"]) do
        local blip = AddBlipForCoord(station.coords.x, station.coords.y, station.coords.z)
        SetBlipSprite(blip, 60)
        SetBlipAsShortRange(blip, true)
        SetBlipScale(blip, 0.7)
        if station.sheriff then 
            SetBlipColour(blip, 33)
        else
            SetBlipColour(blip, 32)
        end
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(station.label)
        EndTextCommandSetBlipName(blip)
    end
end)

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

local function CheckPlayers(vehicle)
    for i = -1, 5,1 do
        seat = GetPedInVehicleSeat(vehicle,i)
        if seat ~= 0 then
            TaskLeaveVehicle(seat,vehicle,0)
            SetVehicleDoorsLocked(vehicle)
            Wait(1500)
            QBCore.Functions.DeleteVehicle(vehicle)
        end
   end
end

RegisterNetEvent('qb-police:MRPDparking', function()
    local ped = PlayerPedId()
    local curVeh = GetVehiclePedIsIn(ped)
    if curVeh ~= 0 then 
        CheckPlayers(curVeh)
    else
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
                    event = "police:client:TakeOutnewpoliceVehicle",
                    args = {
                        vehicle = veh,
                        station = 'mrpd'
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
end)

RegisterNetEvent('qb-police:Davisparking', function()
    local ped = PlayerPedId()
    local curVeh = GetVehiclePedIsIn(ped)
    if curVeh ~= 0 then 
        CheckPlayers(curVeh)
    else
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
                    event = "police:client:TakeOutnewpoliceVehicle",
                    args = {
                        vehicle = veh,
                        station = 'davis'
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
end)

RegisterNetEvent('qb-police:SandySheriffparking', function()
    local ped = PlayerPedId()
    local curVeh = GetVehiclePedIsIn(ped)
    if curVeh ~= 0 then 
        CheckPlayers(curVeh)
    else
        local vehicleMenu = {
            {
                header = Lang:t('menu.garage_title'),
                isMenuHeader = true
            }
        }
    
        local authorizedVehicles = Config.SheriffAuthorizedVehicles[QBCore.Functions.GetPlayerData().job.grade.level]
        for veh, label in pairs(authorizedVehicles) do
            vehicleMenu[#vehicleMenu+1] = {
                header = label,
                txt = "",
                params = {
                    event = "police:client:TakeOutnewpoliceVehicle",
                    args = {
                        vehicle = veh,
                        station = 'sandy'
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
end)

RegisterNetEvent('qb-police:PaletoSheriffparking', function()
    local ped = PlayerPedId()
    local curVeh = GetVehiclePedIsIn(ped)
    if curVeh ~= 0 then 
        CheckPlayers(curVeh)
    else
        local vehicleMenu = {
            {
                header = Lang:t('menu.garage_title'),
                isMenuHeader = true
            }
        }
    
        local authorizedVehicles = Config.SheriffAuthorizedVehicles[QBCore.Functions.GetPlayerData().job.grade.level]
        for veh, label in pairs(authorizedVehicles) do
            vehicleMenu[#vehicleMenu+1] = {
                header = label,
                txt = "",
                params = {
                    event = "police:client:TakeOutnewpoliceVehicle",
                    args = {
                        vehicle = veh,
                        station = 'paleto'
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
end)


RegisterNetEvent('police:client:reportRobbery', function()
    exports['qb-menu']:openMenu({
        {
            header = 'Report to dispatch',
            icon = "fad fa-headphones",
            isMenuHeader = true
        },
        {
            header = 'Store',
            icon = "fad fa-store-slash",
            txt = "Report store robbery",
            params = {
                event = "police:client:reportRobberyType",
                args = {
                    report = 'store'
                }
            }
        },
        {
            header = 'House',
            icon = "fad fa-house-damage",
            txt = "Report house robbery",
            params = {
                event = "police:client:reportRobberyType",
                args = {
                    report = 'house'
                }
            }
        },
        {
            header = "Maybe later..",
            txt = "Here You Can Close The Menu And Come Back Soon",
            icon = "fa-duotone fa-clock",
            params = {
                event = "qb-menu:client:closeMenu"
            }
        },
    })
end)

RegisterNetEvent('police:client:reportRobberyType', function(data)
    local Report = {
        coords = GetEntityCoords(PlayerPedId()),
        report = data.report
    }
    TriggerServerEvent('police:server:reportRobbery', Report)
end)

local playAnim = false
local phoneProp = 0
local phoneModel = 'prop_npc_phone_02'


-- Item checks to return whether or not the client has a phone or not
local function HasPhone()
    return QBCore.Functions.HasItem("phone")
end


-- Loads the animdict so we can execute it on the ped
local function loadAnimDict(dict)
    RequestAnimDict(dict)

    while not HasAnimDictLoaded(dict) do
        Wait(0)
    end
end

local function DeletePhone()
	if phoneProp ~= 0 then
		DeleteObject(phoneProp)
		phoneProp = 0
	end
end

local function NewPropWhoDis()
	DeletePhone()
	RequestModel(phoneModel)
	while not HasModelLoaded(phoneModel) do
		Wait(1)
	end
	phoneProp = CreateObject(phoneModel, 1.0, 1.0, 1.0, 1, 1, 0)

	local bone = GetPedBoneIndex(PlayerPedId(), 28422)
	if phoneModel == Config.PhoneModel then
		AttachEntityToEntity(phoneProp, PlayerPedId(), bone, 0.0, 0.0, 0.0, 15.0, 0.0, 0.0, 1, 1, 0, 0, 2, 1)
	else
		AttachEntityToEntity(phoneProp, PlayerPedId(), bone, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1, 1, 0, 0, 2, 1)
	end
end

-- Does the actual animation of the animation when calling 911
local function PhoneCallAnim()
    loadAnimDict("cellphone@")
    local ped = PlayerPedId()
    CreateThread(function()
        NewPropWhoDis()
        playAnim = true
        while playAnim do
            if not IsEntityPlayingAnim(ped, "cellphone@", 'cellphone_text_to_call', 3) then
                TaskPlayAnim(ped, "cellphone@", 'cellphone_text_to_call', 3.0, 3.0, -1, 50, 0, false, false, false)
            end
            Wait(100)
        end
    end)
end


-- Regular 911 call that goes straight to the Police
RegisterCommand('911', function(source, args, rawCommand)
    local msg = rawCommand:sub(5)
    if string.len(msg) > 0 then
        if not exports['qb-police']:IsHandcuffed() then
            if HasPhone() then
                PhoneCallAnim()
                Wait(math.random(3,8) * 1000)
                playAnim = false
                local data = exports['cd_dispatch']:GetPlayerInfo()
                TriggerServerEvent('cd_dispatch:AddNotification', {
                    job_table = { 'police', 'ambulance' },
                    coords = data.coords,
                    title = "10-90 - 911 Call",
                    message = msg,
                    flash = 0,
                    unique_id = tostring(math.random(0000000, 9999999)),
                    blip = {
                        sprite = 126,
                        scale = 0.8,
                        colour = 3,
                        flashes = false,
                        text = "911 Call",
                        time = (5 * 60 * 1000),
                        sound = 1,
                    }
                })
                Wait(1000)
                DeletePhone()
                StopEntityAnim(PlayerPedId(), 'cellphone_text_to_call', "cellphone@", 3)
            else
                QBCore.Functions.Notify("You can't call without a Phone!", "error", 4500)
            end
        else
            QBCore.Functions.Notify("You can't call police while handcuffed!", "error", 4500)
        end
    else
        QBCore.Functions.Notify('Please put a reason after the 911', "success")
    end
end)

-- RegisterCommand('911a', function(source, args, rawCommand)
--     local msg = rawCommand:sub(5)
--     if string.len(msg) > 0 then
--         if not exports['qb-police']:IsHandcuffed() then
--             if HasPhone() then
--                 PhoneCallAnim()
--                 Wait(math.random(3,8) * 1000)
--                 playAnim = false
--                 local plyData = QBCore.Functions.GetPlayerData()
--                 local currentPos = GetEntityCoords(PlayerPedId())
--                 local locationInfo = getStreetandZone(currentPos)
--                 local gender = GetPedGender()
--                 TriggerServerEvent("dispatch:server:notify",{
--                     dispatchcodename = "911call", -- has to match the codes in sv_dispatchcodes.lua so that it generates the right blip
--                     dispatchCode = "911",
--                     firstStreet = locationInfo,
--                     priority = 2, -- priority
--                     name = "Anonymous",
--                     number = "Hidden Number",
--                     origin = {
--                         x = currentPos.x,
--                         y = currentPos.y,
--                         z = currentPos.z
--                     },
--                     dispatchMessage = "Incoming Anonymous Call", -- message
--                     information = msg,
--                     job = {"police", "ambulance"} -- jobs that will get the alerts
--                 })
--                 Wait(1000)
--                 DeletePhone()
--                 StopEntityAnim(PlayerPedId(), 'cellphone_text_to_call', "cellphone@", 3)
--             else
--                 QBCore.Functions.Notify("You can't call without a Phone!", "error", 4500)
--             end
--         else
--             QBCore.Functions.Notify("You can't call police while handcuffed!", "error", 4500)
--         end
--     else
--         QBCore.Functions.Notify('Please put a reason after the 911', "success")
--     end
-- end)

exports('isInPoliceBenny', function()
    return isPoliceBenny
end)

exports('isInMrpdClothes', function()
    return ismrpdclothes
end)
exports('isInMrpdParking', function()
    return ismrpdparking
end)
exports('isInDavisParking', function()
    return isdavisparking
end)
exports('isInSandySheriffParking', function()
    return issheriffsandyparking
end)
exports('isInPaletoSheriffParking', function()
    return issheriffpaletoparking
end)
