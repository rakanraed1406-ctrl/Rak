local AnimSet = "default"

-- Code

RegisterNetEvent('AnimSet:default');
AddEventHandler('AnimSet:default', function()
    ResetPedMovementClipset(PlayerPedId(), 0)
    AnimSet = "default";
end)

RegisterNetEvent('AnimSet:Hurry');
AddEventHandler('AnimSet:Hurry', function()
    RequestAnimSet("move_m@hurry@a")
    while not HasAnimSetLoaded("move_m@hurry@a") do Citizen.Wait(0) end
    SetPedMovementClipset(PlayerPedId(), "move_m@hurry@a", true)
    AnimSet = "move_m@hurry@a";
end)

RegisterNetEvent('AnimSet:Business');
AddEventHandler('AnimSet:Business', function()
    RequestAnimSet("move_m@business@a")
    while not HasAnimSetLoaded("move_m@business@a") do Citizen.Wait(0) end
    SetPedMovementClipset(PlayerPedId(), "move_m@business@a", true)
    AnimSet = "move_m@business@a";
end)

RegisterNetEvent('AnimSet:Brave');
AddEventHandler('AnimSet:Brave', function()
    RequestAnimSet("move_m@brave")
    while not HasAnimSetLoaded("move_m@brave") do Citizen.Wait(0) end
    SetPedMovementClipset(PlayerPedId(), "move_m@brave", true)
    AnimSet = "move_m@brave";
end)

RegisterNetEvent('AnimSet:Tipsy');
AddEventHandler('AnimSet:Tipsy', function()
    RequestAnimSet("move_m@drunk@slightlydrunk")
    while not HasAnimSetLoaded("move_m@drunk@slightlydrunk") do
        Citizen.Wait(0)
    end
    SetPedMovementClipset(PlayerPedId(), "move_m@drunk@slightlydrunk", true)
    AnimSet = "move_m@drunk@slightlydrunk";
end)

RegisterNetEvent('AnimSet:Injured');
AddEventHandler('AnimSet:Injured', function()
    RequestAnimSet("move_m@injured")
    while not HasAnimSetLoaded("move_m@injured") do Citizen.Wait(0) end
    SetPedMovementClipset(PlayerPedId(), "move_m@injured", true)
    AnimSet = "move_m@injured";
end)

RegisterNetEvent('AnimSet:ToughGuy');
AddEventHandler('AnimSet:ToughGuy', function()
    RequestAnimSet("move_m@tough_guy@")
    while not HasAnimSetLoaded("move_m@tough_guy@") do Citizen.Wait(0) end
    SetPedMovementClipset(PlayerPedId(), "move_m@tough_guy@", true)
    AnimSet = "move_m@tough_guy@";
end)

RegisterNetEvent('AnimSet:Sassy');
AddEventHandler('AnimSet:Sassy', function()
    RequestAnimSet("move_m@sassy")
    while not HasAnimSetLoaded("move_m@sassy") do Citizen.Wait(0) end
    SetPedMovementClipset(PlayerPedId(), "move_m@sassy", true)
    AnimSet = "move_m@sassy";
end)

RegisterNetEvent('AnimSet:Sad');
AddEventHandler('AnimSet:Sad', function()
    RequestAnimSet("move_m@sad@a")
    while not HasAnimSetLoaded("move_m@sad@a") do Citizen.Wait(0) end
    SetPedMovementClipset(PlayerPedId(), "move_m@sad@a", true)
    AnimSet = "move_m@sad@a";
end)

RegisterNetEvent('AnimSet:Posh');
AddEventHandler('AnimSet:Posh', function()
    RequestAnimSet("move_m@posh@")
    while not HasAnimSetLoaded("move_m@posh@") do Citizen.Wait(0) end
    SetPedMovementClipset(PlayerPedId(), "move_m@posh@", true)
    AnimSet = "move_m@posh@";
end)

RegisterNetEvent('AnimSet:Alien');
AddEventHandler('AnimSet:Alien', function()
    RequestAnimSet("move_m@alien")
    while not HasAnimSetLoaded("move_m@alien") do Citizen.Wait(0) end
    SetPedMovementClipset(PlayerPedId(), "move_m@alien", true)
    AnimSet = "move_m@alien";
end)

RegisterNetEvent('AnimSet:NonChalant');
AddEventHandler('AnimSet:NonChalant', function()
    RequestAnimSet("move_m@non_chalant")
    while not HasAnimSetLoaded("move_m@non_chalant") do Citizen.Wait(0) end
    SetPedMovementClipset(PlayerPedId(), "move_m@non_chalant", true)
    AnimSet = "move_m@non_chalant";
end)

RegisterNetEvent('AnimSet:Hobo');
AddEventHandler('AnimSet:Hobo', function()
    RequestAnimSet("move_m@hobo@a")
    while not HasAnimSetLoaded("move_m@hobo@a") do Citizen.Wait(0) end
    SetPedMovementClipset(PlayerPedId(), "move_m@hobo@a", true)
    AnimSet = "move_m@hobo@a";
end)

RegisterNetEvent('AnimSet:Money');
AddEventHandler('AnimSet:Money', function()
    RequestAnimSet("move_m@money")
    while not HasAnimSetLoaded("move_m@money") do Citizen.Wait(0) end
    SetPedMovementClipset(PlayerPedId(), "move_m@money", true)
    AnimSet = "move_m@money";
end)

RegisterNetEvent('AnimSet:Swagger');
AddEventHandler('AnimSet:Swagger', function()
    RequestAnimSet("move_m@swagger")
    while not HasAnimSetLoaded("move_m@swagger") do Citizen.Wait(0) end
    SetPedMovementClipset(PlayerPedId(), "move_m@swagger", true)
    AnimSet = "move_m@swagger";
end)

RegisterNetEvent('AnimSet:Joy');
AddEventHandler('AnimSet:Joy', function()
    RequestAnimSet("move_m@joy")
    while not HasAnimSetLoaded("move_m@joy") do Citizen.Wait(0) end
    SetPedMovementClipset(PlayerPedId(), "move_m@joy", true)
    AnimSet = "move_m@joy";
end)

RegisterNetEvent('AnimSet:Moon');
AddEventHandler('AnimSet:Moon', function()
    RequestAnimSet("move_m@powerwalk")
    while not HasAnimSetLoaded("move_m@powerwalk") do Citizen.Wait(0) end
    SetPedMovementClipset(PlayerPedId(), "move_m@powerwalk", true)
    AnimSet = "move_m@powerwalk";
end)

RegisterNetEvent('AnimSet:Shady');
AddEventHandler('AnimSet:Shady', function()
    RequestAnimSet("move_m@shadyped@a")
    while not HasAnimSetLoaded("move_m@shadyped@a") do Citizen.Wait(0) end
    SetPedMovementClipset(PlayerPedId(), "move_m@shadyped@a", true)
    AnimSet = "move_m@shadyped@a";
end)

RegisterNetEvent('AnimSet:Tired');
AddEventHandler('AnimSet:Tired', function()
    RequestAnimSet("move_m@tired")
    while not HasAnimSetLoaded("move_m@tired") do Citizen.Wait(0) end
    SetPedMovementClipset(PlayerPedId(), "move_m@tired", true)
    AnimSet = "move_m@tired";
end)

RegisterNetEvent('AnimSet:Sexy');
AddEventHandler('AnimSet:Sexy', function()
    RequestAnimSet("move_f@sexy")
    while not HasAnimSetLoaded("move_f@sexy") do Citizen.Wait(0) end
    SetPedMovementClipset(PlayerPedId(), "move_f@sexy", true)
    AnimSet = "move_f@sexy";
end)

RegisterNetEvent('AnimSet:ManEater');
AddEventHandler('AnimSet:ManEater', function()
    RequestAnimSet("move_f@maneater")
    while not HasAnimSetLoaded("move_f@maneater") do Citizen.Wait(0) end
    SetPedMovementClipset(PlayerPedId(), "move_f@maneater", true)
    AnimSet = "move_f@maneater";
end)

RegisterNetEvent('AnimSet:ChiChi');
AddEventHandler('AnimSet:ChiChi', function()
    RequestAnimSet("move_f@chichi")
    while not HasAnimSetLoaded("move_f@chichi") do Citizen.Wait(0) end
    SetPedMovementClipset(PlayerPedId(), "move_f@chichi", true)
    AnimSet = "move_f@chichi";
end)

RegisterNetEvent("expressions")
AddEventHandler("expressions", function(pArgs)
    if #pArgs ~= 1 then return end
    local expressionName = pArgs[1]
    SetFacialIdleAnimOverride(PlayerPedId(), expressionName, 0)
    return
end)

RegisterNetEvent("expressions:clear")
AddEventHandler("expressions:clear",function() 
    ClearFacialIdleAnimOverride(PlayerPedId()) 
end)

RegisterNetEvent("qb-radialmenu:client:OfficerBackup",function() 
    local data = exports['cd_dispatch']:GetPlayerInfo()
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
        local vehicle = data.entity
        SetVehicleOnGroundProperly(vehicle)
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
  QBCore.Functions.TriggerCallback('LRCore:HasItem', function(HasItem)
      if HasItem then
          local Player = QBCore.Functions.GetPlayerData()
          local Info = {['Firstname'] = Player.charinfo.firstname, ['Lastname'] = Player.charinfo.lastname, ['Callsign'] = Player.metadata['callsign']}
          local StreetLabel = QBCore.Functions.GetStreetLabel()
          TriggerServerEvent('qb-police:server:send:alert:panic:button', GetEntityCoords(PlayerPedId()), StreetLabel, Info)
      else
          QBCore.Functions.Notify(_U("noradio"), "error")
      end
  end, "radio")
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
    QBCore.Functions.TriggerCallback('LRCore:HasItem', function(HasItem)
        if HasItem then
            QBCore.Functions.GetPlayerData(function(PlayerData)
                if PlayerData ~= nil and PlayerData.money ~= nil then
                    favorietefrequentie = PlayerData.metadata["favofrequentie"]
                end
            end)     
            if favorietefrequentie > 4 then       
            --exports['qb-radio']:SetRadioState(true)
            exports['qb-radio']:JoinRadio(favorietefrequentie, 1)
            QBCore.Functions.Notify("Connected to "..favorietefrequentie, "info", 8500)
            else
                QBCore.Functions.Notify("You have not set any favorite frequency yet.Do this with /frequency number", "info", 8500)
            end
        else
            QBCore.Functions.Notify("You don't have a radio", "error", 4500)
        end
    end, "radio")
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
 
    if veh ~= nil then
        local plate = GetVehicleNumberPlateText(closestVehicle)
 
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


RegisterNetEvent("qb-radialmenu:client:tattooshop")
AddEventHandler("qb-radialmenu:client:tattooshop", function()
    local coords = GetEntityCoords(PlayerPedId())
    local closest = 1500
    local closestCoords2

    for k,v in pairs(TattoShops) do 
        local dstcheck = GetDistanceBetweenCoords(coords, v) -- Dövemeci dükkanları ile oyuncu arasındaki kordinatları alıp değişkene atıyoruz.

        if dstcheck < closest then
            closest = dstcheck
            closestCoords2 = v
        end
    end

    if not closestCoords2 then return end
   
    SetNewWaypoint(closestCoords2)
    QBCore.Functions.Notify('The nearest tattoo shop is marked', 'success', 2500)
end)

TattoShops = {
    vector3(1322.6,-1651.9,51.2),
    vector3(-1153.6,-1425.6,4.9),
    vector3(322.1,180.4,103.5),
    vector3(-3170.0,1075.0,20.8),
    vector3(1864.6,3747.7,33.0),
    vector3(-293.7,6200.0,31.4)
}


--Berber
RegisterNetEvent("qb-radialmenu:client:barbershop")
AddEventHandler("qb-radialmenu:client:barbershop", function()
    local coords = GetEntityCoords(PlayerPedId())
    local closest = 1500
    local closestCoords2

    for k,v in pairs(BarberShops) do 
        local dstcheck = GetDistanceBetweenCoords(coords, v) -- Berber dükkanları ile oyuncu arasındaki kordinatları alıp değişkene atıyoruz.

        if dstcheck < closest then
            closest = dstcheck
            closestCoords2 = v
        end
    end

    if not closestCoords2 then return end
   
    SetNewWaypoint(closestCoords2)
    QBCore.Functions.Notify('The nearest hairdresser is marked', 'success', 2500)
end)

BarberShops = {
    vector3(1932.0756835938,3729.6706542969,32.844413757324),
	vector3(-278.19036865234,6228.361328125,31.695510864258),
	vector3(1211.9903564453,-472.77117919922,66.207984924316),
	vector3(-33.224239349365,-152.62608337402,57.076496124268),
	vector3(136.7181854248,-1708.2673339844,29.291622161865),
	vector3(-815.18896484375,-184.53868103027,37.568943023682),
	vector3(-1283.2886962891,-1117.3210449219,6.9901118278503)
}
-- --Garajlar
-- RegisterNetEvent("qb-radialmenu:client:garage")
-- AddEventHandler("qb-radialmenu:client:garage", function()
--     local coords = GetEntityCoords(PlayerPedId())
--     local closest = 1000
--     local closestCoords2

--     for k,v in pairs(Garages) do 
--         local dstcheck = GetDistanceBetweenCoords(coords, v) -- Garaj dükkanları ile oyuncu arasındaki kordinatları alıp değişkene atıyoruz.

--         if dstcheck < closest then
--             closest = dstcheck
--             closestCoords2 = v
--         end
--     end
   
--     SetNewWaypoint(closestCoords2)
--     QBCore.Functions.Notify('Het dichtsbijzijnde garage is gemarkeerd', 'success', 2500)
-- end)

-- Garages = {
--     --Garaj dükkanı kordinatları  --örnek kod vector3(0,0,0)
--     vector3(265.648,-1261.309,29.292),
--     vector3(175.7781,-1563.175,29.26973),
--     vector3(-526.0278,-1210.04,29.292),
--     vector3(1182.153,-334.2567,69.17635),
--     vector3(2680.084,3264.406,55.40473)
-- }   


--Benzin İstasyonu
RegisterNetEvent("qb-radialmenu:client:benzine")
AddEventHandler("qb-radialmenu:client:benzine", function()
    local coords = GetEntityCoords(PlayerPedId())
    local closest = 1500
    local closestCoords2

    for k,v in pairs(Gas) do 
        local dstcheck = GetDistanceBetweenCoords(coords, v)

        if dstcheck < closest then
            closest = dstcheck
            closestCoords2 = v
        end
    end

    if not closestCoords2 then return end
   
    SetNewWaypoint(closestCoords2)
    QBCore.Functions.Notify('The nearest gas station is highlighted.', 'success', 2500)
end)

Gas = {
    vector3(2680.084, 3264.406, 55.40473),
    vector3(180.0386, 6602.869, 31.86831),
    vector3(2580.995, 361.7617, 108.4688),
    vector3(263.971, 2607.397, 44.98296),
    vector3(175.7781, -1563.175, 29.26973),
    vector3(620.85229492188,269.10330200195,103.0834274292),
    vector3(-2092.9604492188,-318.94287109375,13.027338981628),
}   

RegisterNetEvent("qb-radialmenu:client:bennys")
AddEventHandler("qb-radialmenu:client:bennys", function()
    local coords = GetEntityCoords(PlayerPedId())
    local closest = 1500
    local closestCoords2

    for k,v in pairs(bennys) do 
        local dstcheck = GetDistanceBetweenCoords(coords, v)

        if dstcheck < closest then
            closest = dstcheck
            closestCoords2 = v
        end
    end

    if not closestCoords2 then return end
   
    SetNewWaypoint(closestCoords2)
    QBCore.Functions.Notify('The nearest bennys is highlighted.', 'success', 2500)
end)

bennys = {
    vector3(-35.54655456543,-1052.0559082031,28.396501541138),
    vector3(-1417.7275390625,-445.89529418945,35.909717559814),
    vector3(109.89, 6627.07, 31.78),
    vector3(1177.6300048828,2639.8493652344,37.75382232666),
    vector3(-1155.3909912109,-2008.1177978516,12.573175430298),
    vector3(731.12182617188,-1076.7602539063,22.168933868408),
    vector3(-338.49310302734,-135.80899047852,39.00955581665),
} 

RegisterNetEvent("qb-radialmenu:client:clothing")
AddEventHandler("qb-radialmenu:client:clothing", function()
    local coords = GetEntityCoords(PlayerPedId())
    local closest = 1500
    local closestCoords2

    for k,v in pairs(clothShop) do 
        local dstcheck = GetDistanceBetweenCoords(coords, v)

        if dstcheck < closest then
            closest = dstcheck
            closestCoords2 = v
        end
    end

    if not closestCoords2 then return end
   
    SetNewWaypoint(closestCoords2)
    QBCore.Functions.Notify('The nearest clothing store is marked.', 'success', 2500)
end)

clothShop = {
    vector3(1693.45667,4823.17725,42.1631294),
	vector3(-712.215881,-155.352982,37.4151268),
	vector3(-1192.94495,-772.688965,17.3255997),
	vector3(425.236,-806.008,28.491),
	vector3(-162.658,-303.397,38.733),
	vector3(75.950,-1392.891,28.376),
	vector3(-822.194,-1074.134,10.328),
	vector3(-1450.711,-236.83,48.809),
	vector3(4.254,6512.813,30.877),
	vector3(615.180,2762.933,41.088),
	vector3(1196.785,2709.558,37.222),
	vector3(-3171.453,1043.857,19.863)
} 


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
