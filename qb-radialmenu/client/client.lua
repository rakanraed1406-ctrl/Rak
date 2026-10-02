local AnimSet = "default"

-- Walk styles: one handler per event name (same events as before).
local walkStyles = {
    ['AnimSet:Hurry'] = "move_m@hurry@a", ['AnimSet:Business'] = "move_m@business@a",
    ['AnimSet:Brave'] = "move_m@brave", ['AnimSet:Tipsy'] = "move_m@drunk@slightlydrunk",
    ['AnimSet:Injured'] = "move_m@injured", ['AnimSet:ToughGuy'] = "move_m@tough_guy@",
    ['AnimSet:Sassy'] = "move_m@sassy", ['AnimSet:Sad'] = "move_m@sad@a",
    ['AnimSet:Posh'] = "move_m@posh@", ['AnimSet:Alien'] = "move_m@alien",
    ['AnimSet:NonChalant'] = "move_m@non_chalant", ['AnimSet:Hobo'] = "move_m@hobo@a",
    ['AnimSet:Money'] = "move_m@money", ['AnimSet:Swagger'] = "move_m@swagger",
    ['AnimSet:Joy'] = "move_m@joy", ['AnimSet:Moon'] = "move_m@powerwalk",
    ['AnimSet:Shady'] = "move_m@shadyped@a", ['AnimSet:Tired'] = "move_m@tired",
    ['AnimSet:Sexy'] = "move_f@sexy", ['AnimSet:ManEater'] = "move_f@maneater",
    ['AnimSet:ChiChi'] = "move_f@chichi",
}

for eventName, clipset in pairs(walkStyles) do
    RegisterNetEvent(eventName, function()
        RequestAnimSet(clipset)
        local timeout = GetGameTimer() + 3000
        while not HasAnimSetLoaded(clipset) do
            if GetGameTimer() > timeout then return end
            Wait(10)
        end
        SetPedMovementClipset(PlayerPedId(), clipset, true)
        AnimSet = clipset
    end)
end

RegisterNetEvent('AnimSet:default', function()
    ResetPedMovementClipset(PlayerPedId(), 0)
    AnimSet = "default"
end)

RegisterNetEvent("expressions")
AddEventHandler("expressions", function(pArgs)
    if type(pArgs) ~= 'table' or #pArgs ~= 1 then return end
    local expressionName = pArgs[1]
    SetFacialIdleAnimOverride(PlayerPedId(), expressionName, 0)
    return
end)

RegisterNetEvent("expressions:clear")
AddEventHandler("expressions:clear",function() 
    ClearFacialIdleAnimOverride(PlayerPedId()) 
end)

RegisterNetEvent("qb-radialmenu:client:OfficerBackup",function() 
    local ok, data = pcall(function() return exports['cd_dispatch']:GetPlayerInfo() end)
    if not ok or type(data) ~= 'table' then return end
    TriggerServerEvent('cd_dispatch:AddNotification', {
        job_table = { 'police' },
        coords = data.coords,
        title = "10-99 - Request Pick Up",
        message = "Officer Is Requesting Pick Up",
        flash = 0,
        unique_id = tostring(math.random(0000000, 9999999)),
        blip = {
            sprite = 480,
            scale = 1.0,
            colour = 1,
            flashes = false,
            text = "Requesting Pick Up",
            time = (5 * 60 * 1000),
            sound = 1,
        }
    })
end)

RegisterNetEvent("qb-radialmenu:client:OfficerDown",function() 
    -- local data = exports['cd_dispatch']:GetPlayerInfo()
    -- TriggerServerEvent('cd_dispatch:AddNotification', {
    --     job_table = { 'police', 'ambulance' },
    --     coords = data.coords,
    --     title = "10-99 - Officer Down",
    --     message = "Officer Is Down",
    --     flash = 0,
    --     unique_id = tostring(math.random(0000000, 9999999)),
    --     blip = {
    --         sprite = 526,
    --         scale = 1.0,
    --         colour = 1,
    --         flashes = true,
    --         text = "Officer Down",
    --         time = (5 * 60 * 1000),
    --         sound = 1,
    --     }
    -- })
    TriggerEvent('cd_dispatch:PanicButtonEvent')
end)

--  // Main Functions \\ --

RegisterNetEvent("hotel:client:stash")
AddEventHandler("hotel:client:stash",function() 
    TriggerServerEvent("inventory:server:OpenInventory", "hotel", "hotel_"..QBCore.Functions.GetPlayerData().citizenid, {
        maxweight = 300000,
        slots = 20,
    })
    TriggerEvent("inventory:client:SetCurrentStash", "hotel"..QBCore.Functions.GetPlayerData().citizenid)
end)


RegisterNetEvent('qb-radialmenu:flipVehicle', function(data)
    QBCore.Functions.Progressbar("pick_grape", "Flipping vehicle..", 5000, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {
        animDict = 'mini@repair',
        anim = 'fixing_a_ped',
        flags = 1,
    }, {}, {}, function() -- Done
        local vehicle = type(data) == 'table' and data.entity
        if vehicle and DoesEntityExist(vehicle) then SetVehicleOnGroundProperly(vehicle) end
        StopAnimTask(PlayerPedId(), 'mini@repair', 'fixing_a_ped', 1.0)
    end, function() -- Cancel
        QBCore.Functions.Notify("Cancel", "error")
        StopAnimTask(PlayerPedId(), 'mini@repair', 'fixing_a_ped', 1.0)
    end)
end)

RegisterNetEvent("hotel:client:logout")
AddEventHandler("hotel:client:logout",function() 
    TriggerServerEvent("hotel:server:LogoutLocation")
end)

RegisterNetEvent('qb-radialmenu:client:flip:vehicle')
AddEventHandler('qb-radialmenu:client:flip:vehicle', function()
    local Vehicle, Distance = QBCore.Functions.GetClosestVehicle()
    if Vehicle ~= 0 and Distance < 1.7 then
        QBCore.Functions.Progressbar("flip-vehicle", "Flipping vehicle", math.random(10000, 15000), false, true, {
            disableMovement = true,
            disableCarMovement = false,
            disableMouse = false,
            disableCombat = true,
        }, {
            animDict = "random@mugging4",
            anim = "struggle_loop_b_thief",
            flags = 49,
        }, {}, {}, function() -- Done
            SetVehicleOnGroundProperly(Vehicle)
            QBCore.Functions.Notify("Succes", "success")
        end, function()
            QBCore.Functions.Notify("Failed", "error")
        end)
    else
        QBCore.Functions.Notify("No vehicle nearby", "error")
    end
end)

RegisterNetEvent("qb-radialmenu:client:send:panic:button")
AddEventHandler("qb-radialmenu:client:send:panic:button",function()
  -- ('LRCore:HasItem' does not exist on qb-core, the old callback never answered)
  if QBCore.Functions.HasItem("radio") then
      local Player = QBCore.Functions.GetPlayerData()
      local Info = {['Firstname'] = Player.charinfo.firstname, ['Lastname'] = Player.charinfo.lastname, ['Callsign'] = Player.metadata['callsign']}
      local StreetLabel = QBCore.Functions.GetStreetLabel()
      TriggerServerEvent('qb-police:server:send:alert:panic:button', GetEntityCoords(PlayerPedId()), StreetLabel, Info)
  else
      QBCore.Functions.Notify(_U("noradio"), "error")
  end
end)

RegisterNetEvent("qb-radialmenu:client:send:down")
AddEventHandler("qb-radialmenu:client:send:down",function(Type)
    local Player = QBCore.Functions.GetPlayerData()
    local Info = {['Firstname'] = Player.charinfo.firstname, ['Lastname'] = Player.charinfo.lastname, ['Callsign'] = Player.metadata['callsign']}
    local StreetLabel = QBCore.Functions.GetStreetLabel()
    local Priority = 2
    if Type == 'Urgent' then
        Priority = 3
    end
    TriggerServerEvent('qb-police:server:send:alert:officer:down', GetEntityCoords(PlayerPedId()), StreetLabel, Info, Priority)
end)

RegisterNetEvent("qb-radialmenu:client:open:door")
AddEventHandler("qb-radialmenu:client:open:door",function(DoorNumber)
    local Vehicle = GetVehiclePedIsIn(PlayerPedId())
    if GetVehicleDoorAngleRatio(Vehicle, DoorNumber) > 0.0 then
        SetVehicleDoorShut(Vehicle, DoorNumber, false)
    else
        SetVehicleDoorOpen(Vehicle, DoorNumber, false, false)
    end
end)
RegisterNetEvent("qb-radialmenu:client:enter:playerradio")
AddEventHandler("qb-radialmenu:client:enter:playerradio",function()
    if not QBCore.Functions.HasItem("radio") then
        return QBCore.Functions.Notify("You don't have a radio", "error", 4500)
    end
    local PlayerData = QBCore.Functions.GetPlayerData() or {}
    local favorite = tonumber(PlayerData.metadata and PlayerData.metadata["favofrequentie"]) or 0
    if favorite > 4 then
        exports['qb-radio']:JoinRadio(favorite, 1)
        QBCore.Functions.Notify("Connected to " .. favorite, "info", 8500)
    else
        QBCore.Functions.Notify("You have not set any favorite frequency yet.Do this with /frequency number", "info", 8500)
    end
end)

RegisterNetEvent('qb-radialmenu:Anchor', function()
    local currVeh = GetVehiclePedIsIn(PlayerPedId(), false)
    if currVeh ~= 0 then
        local vehModel = GetEntityModel(currVeh)
        if vehModel ~= nil and vehModel ~= 0 then
            if DoesEntityExist(currVeh) then
                if IsThisModelABoat(vehModel) or IsThisModelAJetski(vehModel) or IsThisModelAnAmphibiousCar(vehModel) or IsThisModelAnAmphibiousQuadbike(vehModel) then
                    if IsBoatAnchoredAndFrozen(currVeh) then
                        QBCore.Functions.Notify('Retrieving Anchor', 'success')
                        Wait(2000)
						QBCore.Functions.Notify('Anchor Disabled', 'primary')
                        SetBoatAnchor(currVeh, false)
                        SetBoatFrozenWhenAnchored(currVeh, false)
                        SetForcedBoatLocationWhenAnchored(currVeh, false)
                    elseif not IsBoatAnchoredAndFrozen(currVeh) and CanAnchorBoatHere(currVeh) and GetEntitySpeed(currVeh) < 3 then
                        SetEntityAsMissionEntity(currVeh,false,true)
						QBCore.Functions.Notify('Dropping Anchor', 'primary')
                        Wait(2000)
						QBCore.Functions.Notify('Anchor Enabled', 'success')
                        SetBoatAnchor(currVeh, true)
                        SetBoatFrozenWhenAnchored(currVeh, true)
                        SetForcedBoatLocationWhenAnchored(currVeh, true)
                    end
                end
            end
        end
    end
end)

RegisterNetEvent("qb-radialmenu:client:enter:radio")
AddEventHandler("qb-radialmenu:client:enter:radio",function(RadioNumber)
    local HasItem = QBCore.Functions.HasItem("radio", 1)
    if HasItem then
        --exports['qb-radio']:SetRadioState(true)
        exports['qb-radio']:JoinRadio(RadioNumber, 1)
        -- QBCore.Functions.Notify("Connected to OC-0"..RadioNumber, "info", 8500)
    else
        QBCore.Functions.Notify("You don't have a radio", "error", 4500)
    end
end)

RegisterNetEvent('qb-radialmenu:client:setExtra')
AddEventHandler('qb-radialmenu:client:setExtra', function(data)
    local extra = tonumber(data)
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped)

    if extra and veh ~= 0 then
        if GetPedInVehicleSeat(veh, -1) == PlayerPedId() then
            if DoesExtraExist(veh, extra) then 
                if IsVehicleExtraTurnedOn(veh, extra) then
                    -- enginehealth = GetVehicleEngineHealth(veh)
                    -- bodydamage = GetVehicleBodyHealth(veh)
                    SetVehicleExtra(veh, extra, 1)
                    -- SetVehicleEngineHealth(veh, enginehealth)
                    -- SetVehicleBodyHealth(veh, bodydamage)
                    QBCore.Functions.Notify('Extra ' .. extra .. ' off', 'error', 2500)
                else
                    -- enginehealth = GetVehicleEngineHealth(veh)
                    -- bodydamage = GetVehicleBodyHealth(veh)
                    SetVehicleExtra(veh, extra, 0)
                    -- SetVehicleEngineHealth(veh, enginehealth)
                    -- SetVehicleBodyHealth(veh, bodydamage)
                    QBCore.Functions.Notify('Extra ' .. extra .. ' on', 'success', 2500)
                end    
            else
                QBCore.Functions.Notify('Extra ' .. extra .. ' is not available', 'error', 2500)
            end
        else
            QBCore.Functions.Notify(_U("notdriver"), 'error', 2500)
        end
    end
end)


-- "Mark the nearest ..." options (same events as before, one shared function)
local places = {
    ["qb-radialmenu:client:tattooshop"] = { msg = 'The nearest tattoo shop is marked', list = {
        vector3(1322.6,-1651.9,51.2), vector3(-1153.6,-1425.6,4.9), vector3(322.1,180.4,103.5),
        vector3(-3170.0,1075.0,20.8), vector3(1864.6,3747.7,33.0), vector3(-293.7,6200.0,31.4),
    } },
    ["qb-radialmenu:client:barbershop"] = { msg = 'The nearest hairdresser is marked', list = {
        vector3(1932.0756835938,3729.6706542969,32.844413757324), vector3(-278.19036865234,6228.361328125,31.695510864258),
        vector3(1211.9903564453,-472.77117919922,66.207984924316), vector3(-33.224239349365,-152.62608337402,57.076496124268),
        vector3(136.7181854248,-1708.2673339844,29.291622161865), vector3(-815.18896484375,-184.53868103027,37.568943023682),
        vector3(-1283.2886962891,-1117.3210449219,6.9901118278503),
    } },
    ["qb-radialmenu:client:benzine"] = { msg = 'The nearest gas station is highlighted.', list = {
        vector3(2680.084, 3264.406, 55.40473), vector3(180.0386, 6602.869, 31.86831), vector3(2580.995, 361.7617, 108.4688),
        vector3(263.971, 2607.397, 44.98296), vector3(175.7781, -1563.175, 29.26973), vector3(620.85229492188,269.10330200195,103.0834274292),
        vector3(-2092.9604492188,-318.94287109375,13.027338981628),
    } },
    ["qb-radialmenu:client:bennys"] = { msg = 'The nearest bennys is highlighted.', list = {
        vector3(-35.54655456543,-1052.0559082031,28.396501541138), vector3(-1417.7275390625,-445.89529418945,35.909717559814),
        vector3(109.89, 6627.07, 31.78), vector3(1177.6300048828,2639.8493652344,37.75382232666),
        vector3(-1155.3909912109,-2008.1177978516,12.573175430298), vector3(731.12182617188,-1076.7602539063,22.168933868408),
        vector3(-338.49310302734,-135.80899047852,39.00955581665),
    } },
    ["qb-radialmenu:client:clothing"] = { msg = 'The nearest clothing store is marked.', list = {
        vector3(1693.45667,4823.17725,42.1631294), vector3(-712.215881,-155.352982,37.4151268), vector3(-1192.94495,-772.688965,17.3255997),
        vector3(425.236,-806.008,28.491), vector3(-162.658,-303.397,38.733), vector3(75.950,-1392.891,28.376),
        vector3(-822.194,-1074.134,10.328), vector3(-1450.711,-236.83,48.809), vector3(4.254,6512.813,30.877),
        vector3(615.180,2762.933,41.088), vector3(1196.785,2709.558,37.222), vector3(-3171.453,1043.857,19.863),
    } },
}

for eventName, place in pairs(places) do
    RegisterNetEvent(eventName, function()
        local coords = GetEntityCoords(PlayerPedId())
        local closest, best = 1500.0, nil
        for _, v in ipairs(place.list) do
            local d = #(coords - v)
            if d < closest then closest, best = d, v end
        end
        if not best then return end
        SetNewWaypoint(best.x, best.y)
        QBCore.Functions.Notify(place.msg, 'success', 2500)
    end)
end

RegisterNetEvent("qb-radialmenu:client:deleteblips")
AddEventHandler("qb-radialmenu:client:deleteblips", function()
    DeleteWaypoint()
    QBCore.Functions.Notify('Blips removed', 'success', 2500) -- notify 
end)

exports('AddOption2', function(id, data)
    Config.MenuItems[id] = data
end)

exports('RemoveOption2', function(id)
    Config.MenuItems[id] = nil
end)
