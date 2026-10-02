-----------------------
----   Variables   ----
-----------------------
local QBCore = exports['qb-core']:GetCoreObject()
local KeysList = {}

local isTakingKeys = false
local isCarjacking = false
local canCarjack = true
local AlertSend = false
local lastPickedVehicle = nil
local usingAdvanced = false
local IsHotwiring = false
local runningClaims = {}   -- [vehicle] = 'pending' | 'granted' | 'denied'
local lastDriven = nil

-----------------------
----   Threads     ----
-----------------------

CreateThread(function()
    while true do
        local sleep = 1000
        if LocalPlayer.state.isLoggedIn then
            sleep = 100

            local ped = PlayerPedId()
            local entering = GetVehiclePedIsTryingToEnter(ped)
            local carIsImmune = false
            if entering ~= 0 and not isBlacklistedVehicle(entering) then
                sleep = 2000
                local plate = QBCore.Functions.GetPlate(entering)

                local driver = GetPedInVehicleSeat(entering, -1)
                for _, veh in ipairs(Config.ImmuneVehicles) do
                    if GetEntityModel(entering) == joaat(veh) then
                        carIsImmune = true
                    end
                end
                -- Driven vehicle logic
                if driver ~= 0 and not IsPedAPlayer(driver) and not HasKeys(plate) and not carIsImmune then
                    if IsEntityDead(driver) then
                        if not isTakingKeys then
                            isTakingKeys = true

                            TriggerServerEvent('qb-vehiclekeys:server:setVehLockState', NetworkGetNetworkIdFromEntity(entering), 1)
                            QBCore.Functions.Progressbar("steal_keys", Lang:t("progress.takekeys"), 2500, false, false, {
                                disableMovement = false,
                                disableCarMovement = true,
                                disableMouse = false,
                                disableCombat = true
                            }, {}, {}, {}, function() -- Done
                                TriggerServerEvent('qb-vehiclekeys:server:AcquireVehicleKeys', plate)
                                isTakingKeys = false
                            end, function()
                                isTakingKeys = false
                            end)
                        end
                    -- elseif Config.LockNPCDrivingCars then
                    --     TriggerServerEvent('qb-vehiclekeys:server:setVehLockState', NetworkGetNetworkIdFromEntity(entering), 2)
                    -- else
                    --     TriggerServerEvent('qb-vehiclekeys:server:setVehLockState', NetworkGetNetworkIdFromEntity(entering), 1)
                        -- if math.random(1, 100) >= 80 then 
                        --     TriggerServerEvent('qb-vehiclekeys:server:AcquireVehicleKeys', plate)

                        --     --Make passengers flee
                        --     local pedsInVehicle = GetPedsInVehicle(entering)
                        --     for _, pedInVehicle in pairs(pedsInVehicle) do
                        --         if pedInVehicle ~= GetPedInVehicleSeat(entering, -1) then
                        --             MakePedFlee(pedInVehicle)
                        --         end
                        --     end
                        -- end
                    end
                -- Parked car logic
                -- elseif driver == 0 and entering ~= lastPickedVehicle and not HasKeys(plate) and not isTakingKeys then
                --     if Config.LockNPCParkedCars then
                --         TriggerServerEvent('qb-vehiclekeys:server:setVehLockState', NetworkGetNetworkIdFromEntity(entering), 2)
                --     else
                --         TriggerServerEvent('qb-vehiclekeys:server:setVehLockState', NetworkGetNetworkIdFromEntity(entering), 1)
                --     end
                end
            end

            -- Hotwiring while in vehicle, also keeps engine off for vehicles you don't own keys to
            if IsPedInAnyVehicle(ped, false) and not IsHotwiring then
                sleep = 1000
                local vehicle = GetVehiclePedIsIn(ped)
                local plate = QBCore.Functions.GetPlate(vehicle)

                if GetPedInVehicleSeat(vehicle, -1) == ped then
                    lastDriven = vehicle
                    if not HasKeys(plate) and not isBlacklistedVehicle(vehicle) and not AreKeysJobShared(vehicle) then
                        sleep = 0
                        -- الموتر شغال (أحد نزل وتركه شغال) → نطلب المفتاح بدل ما نطفيه
                        if not ClaimRunningVehicle(vehicle) then
                            SetVehicleEngineOn(vehicle, false, false, true)
                        end
                    end
                end
            elseif not IsPedInAnyVehicle(ped, false) and lastDriven then
                ReportLeftVehicle(lastDriven)
                lastDriven = nil
                runningClaims = {}
            end

            if Config.CarJackEnable and canCarjack then
                local playerid = PlayerId()
                local aiming, target = GetEntityPlayerIsFreeAimingAt(playerid)
                if aiming and (target ~= nil and target ~= 0) then
                    if DoesEntityExist(target) and IsPedInAnyVehicle(target, false) and not IsEntityDead(target) and not IsPedAPlayer(target) then
                        local targetveh = GetVehiclePedIsIn(target)
                        for _, veh in ipairs(Config.ImmuneVehicles) do
                            if GetEntityModel(targetveh) == joaat(veh) then
                                carIsImmune = true
                            end
                        end
                        if GetPedInVehicleSeat(targetveh, -1) == target and not IsBlacklistedWeapon() then
                            local pos = GetEntityCoords(ped, true)
                            local targetpos = GetEntityCoords(target, true)
                            if #(pos - targetpos) < 5.0 and not carIsImmune then
                                CarjackVehicle(target)
                            end
                        end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

function isBlacklistedVehicle(vehicle)
    local isBlacklisted = false
    for _,v in ipairs(Config.NoLockVehicles) do
        if GetHashKey(v) == GetEntityModel(vehicle) then
            isBlacklisted = true
            break;
        end
    end
    if Entity(vehicle).state.ignoreLocks or GetVehicleClass(vehicle) == 13 then isBlacklisted = true end
    return isBlacklisted
end

-----------------------
---- Client Events ----
-----------------------

RegisterKeyMapping('togglelocks', Lang:t("info.tlock"), 'keyboard', 'L')
RegisterCommand('togglelocks', function()
    ToggleVehicleLocks(GetVehicle())
end)

RegisterKeyMapping('engine', Lang:t("info.engine"), 'keyboard', 'G')
RegisterCommand('engine', function()
    TriggerEvent("qb-vehiclekeys:client:ToggleEngine")
end)

AddEventHandler('onResourceStart', function(resourceName)
	if resourceName == GetCurrentResourceName() and QBCore.Functions.GetPlayerData() ~= {} then
		GetKeys()
	end
end)

-- Handles state right when the player selects their character and location.
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    GetKeys()
end)

-- Resets state on logout, in case of character change.
RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    KeysList = {}
end)

RegisterNetEvent('qb-vehiclekeys:client:AddKeys', function(plate)
    KeysList[plate] = true

    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        local vehicle = GetVehiclePedIsIn(ped)
        local vehicleplate = QBCore.Functions.GetPlate(vehicle)

        -- يرجّع التشغيل التلقائي، بس ما يطفي موتر شغال (مثل لما تاخذ مفتاح سيارة موترها شغال)
        if plate == vehicleplate and not GetIsVehicleEngineRunning(vehicle) then
            SetVehicleEngineOn(vehicle, false, false, false)
        end
    end
end)

RegisterNetEvent('qb-vehiclekeys:client:RemoveKeys', function(plate)
    KeysList[plate] = nil
end)

RegisterNetEvent('qb-vehiclekeys:client:ToggleEngine', function()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)

    if vehicle ~= 0 then
        if GetPedInVehicleSeat(vehicle, -1) ~= ped then return end   -- الراكب ما يطفي موتر السواق
    else
        -- برا السيارة: بس سيارتك الأخيرة وإذا كنت قريب منها
        vehicle = GetVehiclePedIsIn(ped, true)
        if vehicle == 0 or not DoesEntityExist(vehicle) or (Config.Engine.RemoteDistance or 0) <= 0 then return end
        if GetPedInVehicleSeat(vehicle, -1) ~= 0 then return end
        if #(GetEntityCoords(ped) - GetEntityCoords(vehicle)) > Config.Engine.RemoteDistance then return end
    end

    if not HasKeys(QBCore.Functions.GetPlate(vehicle)) then return end

    if GetIsVehicleEngineRunning(vehicle) then
        local blocked, msg = EngineOffBlocked(vehicle)
        if blocked then
            if msg then QBCore.Functions.Notify(msg, 'error') end
            return
        end
        SetVehicleEngineOn(vehicle, false, false, true)
    else
        SetVehicleEngineOn(vehicle, true, false, true)
    end
end)

RegisterNetEvent('qb-vehiclekeys:client:GiveKeys', function(id)
    local targetVehicle = GetVehicle()

    if targetVehicle then
        local targetPlate = QBCore.Functions.GetPlate(targetVehicle)
        if HasKeys(targetPlate) then
            if id and type(id) == "number" then -- Give keys to specific ID
                GiveKeys(id, targetPlate)
            else
                if IsPedSittingInVehicle(PlayerPedId(), targetVehicle) then -- Give keys to everyone in vehicle
                    local otherOccupants = GetOtherPlayersInVehicle(targetVehicle)
                    for p=1,#otherOccupants do
                        TriggerServerEvent('qb-vehiclekeys:server:GiveVehicleKeys', GetPlayerServerId(NetworkGetPlayerIndexFromPed(otherOccupants[p])), targetPlate)
                    end
                else -- Give keys to closest player
                    GiveKeys(GetPlayerServerId(QBCore.Functions.GetClosestPlayer()), targetPlate)
                end
            end
        else
            QBCore.Functions.Notify(Lang:t("notify.ydhk"), 'error')
        end
    end
end)

RegisterNetEvent('vehiclekeys:client:GiveKeys', function(id)
    local targetVehicle = GetVehicle()
    if targetVehicle then
        local targetPlate = QBCore.Functions.GetPlate(targetVehicle)
        if HasKeys(targetPlate) then
            QBCore.Functions.TriggerCallback('qb-vehiclekeys:server:GetClosestPlayer', function(ClosestPlayer)
                if #ClosestPlayer > 0 then 
                    local menu = {}
                    for k, v in pairs(ClosestPlayer) do 
                        menu[#menu + 1] = {
                            header = "Give Key To:",
                            txt = "ID: "..v.id.."",
                            params = {
                                isServer = false,
                                event = "vehiclekeys:client:GiveKeysChosed",
                                args = {
                                    playerId = v.id,
                                    targetPlate = targetPlate,
                                }
                            }
                        }
                    end
                    if #menu <= 0 then 
                        return 
                    end
                    exports['qb-menu']:openMenu(menu)
                else
                    QBCore.Functions.Notify(Lang:t("notify.ydhk"), 'error')
                end
            end)
        else
            QBCore.Functions.Notify(Lang:t("notify.ydhk"), 'error')
        end
    end
end)

RegisterNetEvent('vehiclekeys:client:GiveKeysChosed', function(data)
    GiveKeys(data.playerId, data.targetPlate)
end)


RegisterNetEvent('lockpicks:UseLockpick', function(isAdvanced, slot)
    LockpickDoor(isAdvanced, slot)
end)


-- Backwards Compatibility ONLY -- Remove at some point --
RegisterNetEvent('vehiclekeys:client:SetOwner', function(plate)
    TriggerServerEvent('qb-vehiclekeys:server:AcquireVehicleKeys', plate)
end)
-- Backwards Compatibility ONLY -- Remove at some point --

-----------------------
----   Functions   ----
-----------------------

function GiveKeys(id, plate)
    local distance = #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(GetPlayerPed(GetPlayerFromServerId(id))))
    if distance < 1.5 then
        TriggerServerEvent('qb-vehiclekeys:server:GiveVehicleKeys', id, plate)
    else
        QBCore.Functions.Notify(Lang:t("notify.nonear"),'error')
    end
end

function GetKeys()
    QBCore.Functions.TriggerCallback('qb-vehiclekeys:server:GetVehicleKeys', function(keysList)
        KeysList = keysList
    end)
end

function HasKeys(plate)
    return KeysList[plate]
end
exports('HasKeys', HasKeys)

-----------------------
----  Engine rules ----
-----------------------

local G_CONTROLS = { 47, 58, 113 }

local function gKeyDown()
    for _, c in ipairs(G_CONTROLS) do
        if IsControlPressed(0, c) or IsDisabledControlPressed(0, c)
            or IsControlJustPressed(0, c) or IsDisabledControlJustPressed(0, c) then
            return true
        end
    end
    return false
end

local function isAircraft(vehicle)
    local model = GetEntityModel(vehicle)
    return IsThisModelAPlane(model) or IsThisModelAHeli(model)
end

-- يرجّع: ممنوع؟ ، الرسالة (nil = بدون رسالة)
function EngineOffBlocked(vehicle)
    local gKey = gKeyDown()
    local aircraft = isAircraft(vehicle)

    -- بالطيارة زر G = الكفرات، ما نطفي الموتر ولا نزعجه برسالة
    if gKey and aircraft and Config.Engine.DisableKeyInAircraft then return true, nil end
    -- زر G مستخدم لشي ثاني (مثل الرد على بلاغ بالتابلت)
    if gKey and LocalPlayer.state.gKeyBusy then return true, Lang:t('notify.engine_gbusy') end
    if aircraft and IsEntityInAir(vehicle) then return true, Lang:t('notify.engine_air') end
    if GetEntitySpeed(vehicle) * 3.6 >= Config.Engine.MaxOffSpeed then
        return true, Lang:t('notify.engine_speed', { speed = Config.Engine.MaxOffSpeed })
    end
    return false, nil
end

-----------------------
---- Running engine ----
-----------------------

-- ركبت سواق بسيارة موترها شغال وما عندك مفتاحها: نطلب المفتاح من السيرفر.
-- يرجّع true = خل الموتر شغال (الطلب ماشي أو انقبل)
function ClaimRunningVehicle(vehicle)
    if not Config.RunningEngine.Enabled then return false end

    local claim = runningClaims[vehicle]
    if claim == 'pending' or claim == 'granted' then return true end
    if claim == 'denied' then return false end
    if not GetIsVehicleEngineRunning(vehicle) or not NetworkGetEntityIsNetworked(vehicle) then return false end

    runningClaims[vehicle] = 'pending'
    CreateThread(function()
        Wait(750) -- نعطي السيرفر وقت يشوفك بكرسي السواق
        if GetPedInVehicleSeat(vehicle, -1) ~= PlayerPedId() then
            runningClaims[vehicle] = nil
            return
        end
        QBCore.Functions.TriggerCallback('qb-vehiclekeys:server:ClaimRunningVehicle', function(ok)
            if runningClaims[vehicle] == 'pending' then
                runningClaims[vehicle] = ok and 'granted' or 'denied'
            end
        end, NetworkGetNetworkIdFromEntity(vehicle))
    end)
    SetTimeout(6000, function()
        if runningClaims[vehicle] == 'pending' then runningClaims[vehicle] = 'denied' end
    end)
    return true
end

-- نزلت من سيارتك: نقول للسيرفر إذا تركت الموتر شغال (المفتاح فيها)
function ReportLeftVehicle(vehicle)
    if not Config.RunningEngine.Enabled or not DoesEntityExist(vehicle) then return end
    if not HasKeys(QBCore.Functions.GetPlate(vehicle)) then return end
    if not NetworkGetEntityIsNetworked(vehicle) then return end

    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    SetTimeout(1500, function() -- بعد وقت "F مطوّل يطفي الموتر"
        TriggerServerEvent('qb-vehiclekeys:server:LeftVehicle', netId)
    end)
end

function loadAnimDict(dict)
    while (not HasAnimDictLoaded(dict)) do
        RequestAnimDict(dict)
        Wait(0)
    end
end

function GetVehicleInDirection(coordFromOffset, coordToOffset)
    local ped = PlayerPedId()
    local coordFrom = GetOffsetFromEntityInWorldCoords(ped, coordFromOffset.x, coordFromOffset.y, coordFromOffset.z)
    local coordTo = GetOffsetFromEntityInWorldCoords(ped, coordToOffset.x, coordToOffset.y, coordToOffset.z)

    local rayHandle = CastRayPointToPoint(coordFrom.x, coordFrom.y, coordFrom.z, coordTo.x, coordTo.y, coordTo.z, 10, PlayerPedId(), 0)
    local _, _, _, _, vehicle = GetShapeTestResult(rayHandle)
    return vehicle
end

-- If in vehicle returns that, otherwise tries 3 different raycasts to get the vehicle they are facing.
-- Raycasts picture: https://i.imgur.com/FRED0kV.png
function GetVehicle()
    local vehicle = GetVehiclePedIsIn(PlayerPedId())

    local RaycastOffsetTable = {
        { ['fromOffset'] = vector3(0.0, 0.0, 0.0), ['toOffset'] = vector3(0.0, 20.0, -10.0) }, -- Waist to ground 45 degree angle
        { ['fromOffset'] = vector3(0.0, 0.0, 0.7), ['toOffset'] = vector3(0.0, 10.0, -10.0) }, -- Head to ground 30 degree angle
        { ['fromOffset'] = vector3(0.0, 0.0, 0.7), ['toOffset'] = vector3(0.0, 10.0, -20.0) }, -- Head to ground 15 degree angle
    }

    local count = 0
    while vehicle == 0 and count < #RaycastOffsetTable do
        count = count + 1
        vehicle = GetVehicleInDirection(RaycastOffsetTable[count]['fromOffset'], RaycastOffsetTable[count]['toOffset'])
    end

    if not IsEntityAVehicle(vehicle) then vehicle = nil end
    return vehicle
end

function AreKeysJobShared(veh)
    local vehName = GetDisplayNameFromVehicleModel(GetEntityModel(veh))
    local vehPlate = QBCore.Functions.GetPlate(veh) -- كان بدون قص المسافات → يطلب المفتاح كل 100ms
    local jobName = QBCore.Functions.GetPlayerData().job.name
    local onDuty = QBCore.Functions.GetPlayerData().job.onduty
    for job, v in pairs(Config.SharedKeys) do
        if job == jobName then
	    if Config.SharedKeys[job].requireOnduty and not onDuty then return false end
	    for _, vehicle in pairs(v.vehicles) do
	        if string.upper(vehicle) == string.upper(vehName) then
		    if not HasKeys(vehPlate) then
		        TriggerServerEvent("qb-vehiclekeys:server:AcquireVehicleKeys", vehPlate)
		    end
		    return true
	        end
            end
        end
    end
    return false
end

function ToggleVehicleLocks(veh)
    if veh then
        if not isBlacklistedVehicle(veh) then
            if HasKeys(QBCore.Functions.GetPlate(veh)) or AreKeysJobShared(veh) then
                local ped = PlayerPedId()
                local vehLockStatus = GetVehicleDoorLockStatus(veh)

                loadAnimDict("anim@mp_player_intmenu@key_fob@")
                TaskPlayAnim(ped, 'anim@mp_player_intmenu@key_fob@', 'fob_click', 3.0, 3.0, -1, 49, 0, false, false, false)

                TriggerServerEvent("InteractSound_SV:PlayWithinDistance", 5, "lock", 0.3)

                NetworkRequestControlOfEntity(veh)
                if vehLockStatus == 1 then
                    TriggerServerEvent('qb-vehiclekeys:server:setVehLockState', NetworkGetNetworkIdFromEntity(veh), 2)
                    QBCore.Functions.Notify(Lang:t("notify.vlock"), "primary")
                else
                    TriggerServerEvent('qb-vehiclekeys:server:setVehLockState', NetworkGetNetworkIdFromEntity(veh), 1)
                    QBCore.Functions.Notify(Lang:t("notify.vunlock"), "success")
                end

                SetVehicleLights(veh, 2)
                Wait(250)
                SetVehicleLights(veh, 1)
                Wait(200)
                SetVehicleLights(veh, 0)
                Wait(300)
                ClearPedTasks(ped)
            else
                QBCore.Functions.Notify(Lang:t("notify.ydhk"), 'error')
            end
        else
            TriggerServerEvent('qb-vehiclekeys:server:setVehLockState', NetworkGetNetworkIdFromEntity(veh), 1)
        end
    end
end

function GetOtherPlayersInVehicle(vehicle)
    local otherPeds = {}
    for seat=-1,GetVehicleModelNumberOfSeats(GetEntityModel(vehicle))-2 do
        local pedInSeat = GetPedInVehicleSeat(vehicle, seat)
        if IsPedAPlayer(pedInSeat) and pedInSeat ~= PlayerPedId() then
            otherPeds[#otherPeds+1] = pedInSeat
        end
    end
    return otherPeds
end

function GetPedsInVehicle(vehicle)
    local otherPeds = {}
    for seat=-1,GetVehicleModelNumberOfSeats(GetEntityModel(vehicle))-2 do
        local pedInSeat = GetPedInVehicleSeat(vehicle, seat)
        if not IsPedAPlayer(pedInSeat) and pedInSeat ~= 0 then
            otherPeds[#otherPeds+1] = pedInSeat
        end
    end
    return otherPeds
end

function IsBlacklistedWeapon()
    local weapon = GetSelectedPedWeapon(PlayerPedId())
    if weapon ~= nil then
        for _, v in pairs(Config.NoCarjackWeapons) do
            if weapon == GetHashKey(v) then
                return true
            end
        end
    end
    return false
end

function LockpickDoor(isAdvanced, slot)
    if not slot then return end
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local vehicle = QBCore.Functions.GetClosestVehicle()

    if vehicle == nil or vehicle == 0 then return end
    if HasKeys(QBCore.Functions.GetPlate(vehicle)) then return end
    if #(pos - GetEntityCoords(vehicle)) > 2.5 then return end
    if GetVehicleDoorLockStatus(vehicle) <= 0 then return end

    usingAdvanced = isAdvanced
    if vehicle ~= 0 then 

        SetVehicleAlarm(vehicle, true)
        SetVehicleAlarmTimeLeft(vehicle, 6000)
        TriggerServerEvent('smallresources:server:lockPickHealth', slot)
        -- local success = exports['qb-ui']:StartLockPickCircle(circles, seconds, success)
        local success = exports["2na_lockpick"]:createGame(3, 1)
        if success then 
            SetVehicleAlarm(vehicle, false)
            LockpickFinishCallback(success)
        end
    end
end

function LockpickFinishCallback(success)
    local vehicle = QBCore.Functions.GetClosestVehicle()

    local chance = math.random()
    if success then
        TriggerServerEvent('hud:server:GainStress', math.random(3, 6))
        lastPickedVehicle = vehicle

        if GetPedInVehicleSeat(vehicle, -1) == PlayerPedId() then
            TriggerServerEvent('qb-vehiclekeys:server:AcquireVehicleKeys', QBCore.Functions.GetPlate(vehicle))
        else
            QBCore.Functions.Notify(Lang:t("notify.vlockpick"), 'success')
            TriggerServerEvent('qb-vehiclekeys:server:setVehLockState', NetworkGetNetworkIdFromEntity(vehicle), 1)
        end

    else
        TriggerServerEvent('hud:server:GainStress', math.random(3, 6))
        -- AttemptPoliceAlert("steal")
    end

    -- if usingAdvanced then
    --     if chance <= Config.RemoveLockpickAdvanced then
    --         TriggerServerEvent("qb-vehiclekeys:server:breakLockpick", "advancedlockpick")
    --     end
    -- else
    --     if chance <= Config.RemoveLockpickNormal then
    --         TriggerServerEvent("qb-vehiclekeys:server:breakLockpick", "lockpick")
    --     end
    -- end
end

function Hotwire(vehicle, plate)
    local hotwireTime = math.random(Config.minHotwireTime, Config.maxHotwireTime)
    local ped = PlayerPedId()
    IsHotwiring = true

    SetVehicleAlarm(vehicle, true)
    SetVehicleAlarmTimeLeft(vehicle, hotwireTime)
    QBCore.Functions.Progressbar("hotwire_vehicle", Lang:t("progress.hskeys"), hotwireTime, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true
    }, {
        animDict = "anim@amb@clubhouse@tutorial@bkr_tut_ig3@",
        anim = "machinic_loop_mechandplayer",
        flags = 16
    }, {}, {}, function() -- Done
        StopAnimTask(ped, "anim@amb@clubhouse@tutorial@bkr_tut_ig3@", "machinic_loop_mechandplayer", 1.0)
        TriggerServerEvent('hud:server:GainStress', math.random(1, 4))
        if (math.random() <= Config.HotwireChance) then
            TriggerServerEvent('qb-vehiclekeys:server:AcquireVehicleKeys', plate)
        else
            QBCore.Functions.Notify(Lang:t("notify.fvlockpick"), "error")
        end
        Wait(Config.TimeBetweenHotwires)
        IsHotwiring = false
    end, function() -- Cancel
        StopAnimTask(ped, "anim@amb@clubhouse@tutorial@bkr_tut_ig3@", "machinic_loop_mechandplayer", 1.0)
        IsHotwiring = false
    end)
    SetTimeout(10000, function()
        -- AttemptPoliceAlert("steal")
    end)
    IsHotwiring = false
end

function CarjackVehicle(target)
    if not Config.CarJackEnable then return end
    isCarjacking = true
    canCarjack = false
    loadAnimDict('mp_am_hold_up')
    local vehicle = GetVehiclePedIsUsing(target)
    local occupants = GetPedsInVehicle(vehicle)
    for p=1,#occupants do
        local ped = occupants[p]
        CreateThread(function()
            TaskPlayAnim(ped, "mp_am_hold_up", "holdup_victim_20s", 8.0, -8.0, -1, 49, 0, false, false, false)
            PlayPain(ped, 6, 0)
        end)
        Wait(math.random(200,500))
    end
    -- Cancel progress bar if: Ped dies during robbery, car gets too far away
    CreateThread(function()
        while isCarjacking do
            local distance = #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(target))
            if IsPedDeadOrDying(target) or distance > 7.5 then
                TriggerEvent("progressbar:client:cancel")
            end
            Wait(100)
        end
    end)
    QBCore.Functions.Progressbar("rob_keys", Lang:t("progress.acjack"), Config.CarjackingTime, false, true, {}, {}, {}, {}, function()
        local hasWeapon, weaponHash = GetCurrentPedWeapon(PlayerPedId(), true)
        if hasWeapon and isCarjacking then
            local carjackChance
            if Config.CarjackChance[tostring(GetWeapontypeGroup(weaponHash))] then
                carjackChance = Config.CarjackChance[tostring(GetWeapontypeGroup(weaponHash))]
            else
                carjackChance = 0.5
            end
            if math.random() <= carjackChance then
                local plate = QBCore.Functions.GetPlate(vehicle)
                    for p=1,#occupants do
                        local ped = occupants[p]
                        CreateThread(function()
                        TaskLeaveVehicle(ped, vehicle, 0)
                        PlayPain(ped, 6, 0)
                        Wait(1250)
                        ClearPedTasksImmediately(ped)
                        PlayPain(ped, math.random(7,8), 0)
                        MakePedFlee(ped)
                    end)
                end
                TriggerServerEvent('hud:server:GainStress', math.random(1, 4))
                TriggerServerEvent('qb-vehiclekeys:server:AcquireVehicleKeys', plate)
            else
                QBCore.Functions.Notify(Lang:t("notify.cjackfail"), "error")
                MakePedFlee(target)
                TriggerServerEvent('hud:server:GainStress', math.random(1, 4))
            end
            isCarjacking = false
            Wait(2000)
            -- AttemptPoliceAlert("carjack")
            Wait(Config.DelayBetweenCarjackings)
            canCarjack = true
        end
    end, function()
        MakePedFlee(target)
        isCarjacking = false
        Wait(Config.DelayBetweenCarjackings)
        canCarjack = true
    end)
end

-- function AttemptPoliceAlert(type)
--     if not AlertSend then
--         local chance = Config.PoliceAlertChance
--         if GetClockHours() >= 1 and GetClockHours() <= 6 then
--             chance = Config.PoliceNightAlertChance
--         end
--         if math.random() <= chance then
--            TriggerServerEvent('police:server:policeAlert', Lang:t("info.palert") .. type)
--         end
--         AlertSend = true
--         SetTimeout(Config.AlertCooldown, function()
--             AlertSend = false
--         end)
--     end
-- end

function MakePedFlee(ped)
    SetPedFleeAttributes(ped, 0, 0)
    TaskReactAndFleePed(ped, PlayerPedId())
end

function DrawText3D(x, y, z, text)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(true)
    AddTextComponentString(text)
    SetDrawOrigin(x, y, z, 0)
    DrawText(0.0, 0.0)
    local factor = (string.len(text)) / 370
    DrawRect(0.0, 0.0 + 0.0125, 0.017 + factor, 0.03, 0, 0, 0, 75)
    ClearDrawOrigin()
end

