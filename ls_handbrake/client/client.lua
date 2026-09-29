
-- ============================================================================
-- ls_handbrake - Client Script
-- Clean, human-written implementation replacing decompiled code
-- ============================================================================

local hasBeenNotified = not (Config and Config.handbrake_alert)
local lastVehicle = 0

-- ─────────────────────────────────────────────────────────────────────────────
-- Helper Functions
-- ─────────────────────────────────────────────────────────────────────────────

--- Displays handbrake help notification once
local function TriggerHandbrakeNotification()
    if not hasBeenNotified then
        hasBeenNotified = true
        CreateThread(function()
            Wait(1000)
            if HandBrakeNotify then
                HandBrakeNotify()
            end
        end)
    end
end

--- Plays handbrake tighten or release NUI audio sound
--- @param soundType string "tightenHandbrake" or "releaseHandbrake"
local function PlayHandbrakeSound(soundType)
    local actionName = (soundType == "handbrake_tighten" or soundType == "tightenHandbrake") and "tightenHandbrake" or "releaseHandbrake"
    SendNUIMessage({
        action = actionName,
        transactionType = actionName,
        volume = 0.65
    })
end

--- Checks if a ped is the driver of a vehicle
--- @param ped number
--- @param vehicle number
--- @return boolean
local function IsPedDriver(ped, vehicle)
    return GetPedInVehicleSeat(vehicle, -1) == ped
end

local vehicleClasses = {
    [0]  = "Compacts",
    [1]  = "Sedans",
    [2]  = "SUVs",
    [3]  = "Coupes",
    [4]  = "Muscle",
    [5]  = "Sports Classics",
    [6]  = "Sports",
    [7]  = "Super",
    [8]  = "Motorcycles",
    [9]  = "Off-road",
    [10] = "Industrial",
    [11] = "Utility",
    [12] = "Vans",
    [13] = "Cycles",
    [14] = "Boats",
    [15] = "Helicopters",
    [16] = "Planes",
    [17] = "Service",
    [18] = "Emergency",
    [19] = "Military",
    [20] = "Commercial",
    [21] = "Trains",
    [22] = "Open Wheel"
}

--- Checks if vehicle class is in automatic_handbrake_vehicles config
--- @param vehicle number
--- @return boolean
local function IsClassExempt(vehicle)
    local vehClassInt = GetVehicleClass(vehicle)
    local className = vehicleClasses[vehClassInt]
    if not className then return false end

    local exemptClasses = Config and Config.automatic_handbrake_vehicles and Config.automatic_handbrake_vehicles.classes
    if not exemptClasses then return false end

    for _, name in pairs(exemptClasses) do
        if name == className then
            return true
        end
    end
    return false
end

--- Checks if vehicle model is in automatic_handbrake_vehicles config
--- @param vehicle number
--- @return boolean
local function IsModelExempt(vehicle)
    local modelHash = GetEntityModel(vehicle)
    local exemptModels = Config and Config.automatic_handbrake_vehicles and Config.automatic_handbrake_vehicles.models
    if not exemptModels then return false end

    for _, modelName in pairs(exemptModels) do
        if modelHash == joaat(modelName) then
            return true
        end
    end
    return false
end

--- Gets handbrake state with short cache
--- @param vehicle number
--- @return boolean
local function IsHandbrakeEngaged(vehicle)
    return UseCache("hand_brake_state" .. vehicle, function()
        local state = Entity(vehicle).state.handbrakeEngaged
        return state == true
    end, 500)
end

--- Flash brake lights when handbrake is active and vehicle is stationary
--- @param vehicle number
local function HandleBrakeLights(vehicle)
    CreateThread(function()
        while IsHandbrakeEngaged(vehicle) do
            local sleep = 200
            if IsEntityVisible(vehicle) then
                sleep = 1
                SetVehicleBrakeLights(vehicle, true)
            end
            Wait(sleep)
        end
    end)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- State Bag Listener
-- ─────────────────────────────────────────────────────────────────────────────

AddStateBagChangeHandler("handbrakeEngaged", nil, function(bagName, key, value, _reserved, replicated)
    if replicated then return end
    local entity = GetEntityFromStateBagName(bagName)
    if not entity or not DoesEntityExist(entity) or not IsEntityAVehicle(entity) then return end

    if value == true then
        PlayHandbrakeSound("tightenHandbrake")
        HandleBrakeLights(entity)
    elseif value == false then
        PlayHandbrakeSound("releaseHandbrake")
    end

    -- If local player owns entity, sync game native handbrake
    if NetworkGetEntityOwner(entity) == PlayerId() then
        SetVehicleHandbrake(entity, value == true)
    end
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Hill Roll Thread
-- ─────────────────────────────────────────────────────────────────────────────

CreateThread(function()
    while true do
        local sleep = 1000
        local playerPed = PlayerPedId()

        if not IsPedInAnyVehicle(playerPed, false) and lastVehicle ~= 0 and DoesEntityExist(lastVehicle) then
            if not IsClassExempt(lastVehicle) and not IsModelExempt(lastVehicle) then
                if NetworkGetEntityOwner(lastVehicle) == PlayerId() then
                    if not IsHandbrakeEngaged(lastVehicle) and IsVehicleOnAllWheels(lastVehicle) then
                        local rotation = GetEntityRotation(lastVehicle, 0)
                        local pitch = math.max(-6.0, math.min(6.0, rotation.x))
                        local absPitch = math.abs(pitch)

                        local threshold = (Config and Config.angle_threshold) or 5
                        if absPitch > threshold then
                            TriggerHandbrakeNotification()
                            sleep = 10

                            SetVehicleHandbrake(lastVehicle, false)
                            SetVehicleBrake(lastVehicle, false)
                            SetVehicleClutch(lastVehicle, 0.0)

                            local rollSpeed = (Config and Config.roll_speed) or 1.8
                            local forceY = pitch * -0.014 * rollSpeed

                            ApplyForceToEntity(
                                lastVehicle, 1,
                                0.0, forceY, 0.0,
                                0.0, 0.0, 0.0,
                                0, true, true, true, false, true
                            )
                        end
                    end
                end
            end
        end

        Wait(sleep)
    end
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Main Input & Driver Control Thread
-- ─────────────────────────────────────────────────────────────────────────────

CreateThread(function()
    while true do
        local sleep = 1000
        local playerPed = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(playerPed, false)

        if vehicle ~= 0 and IsPedDriver(playerPed, vehicle) then
            if lastVehicle ~= vehicle then
                if NetworkGetEntityOwner(vehicle) ~= PlayerId() then
                    NetworkRequestControlOfEntity(vehicle)
                    local timeout = GetGameTimer() + 1000
                    while NetworkGetEntityOwner(vehicle) ~= PlayerId() and GetGameTimer() < timeout do
                        Wait(50)
                    end
                end
                lastVehicle = vehicle
            end

            sleep = 250
            local speed = GetEntitySpeed(vehicle)

            if speed <= 5.0 then
                -- Check manual handbrake input
                if Config and Config.handbrake_input and Config.handbrake_input.enabled then
                    local controlKey = Config.handbrake_input.control or 76
                    if IsControlPressed(0, controlKey) then
                        if CanUseHandbrake and CanUseHandbrake(vehicle) then
                            if PlayAnim then
                                PlayAnim("veh@driveby@first_person@passenger_rear_right_handed@smg", "outro_90r", 1000)
                            end

                            local currentEngaged = Entity(vehicle).state.handbrakeEngaged or false
                            Entity(vehicle).state:set("handbrakeEngaged", not currentEngaged, true)
                        end

                        while IsControlPressed(0, controlKey) do
                            Wait(10)
                        end
                    end
                end

                -- Auto release handbrake when pressing throttle if configured
                if Config and not Config.require_handbrake_release then
                    local throttle = math.abs(GetVehicleThrottleOffset(vehicle))
                    if throttle > 0.0 then
                        if Entity(vehicle).state.handbrakeEngaged then
                            Entity(vehicle).state:set("handbrakeEngaged", false, true)
                        end
                    end
                end
            end
        end

        Wait(sleep)
    end
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Exports
-- ─────────────────────────────────────────────────────────────────────────────

exports("SetVehicleHandbrake", function(vehicle, engaged)
    if not vehicle or not DoesEntityExist(vehicle) then return end
    if CanUseHandbrake and not CanUseHandbrake(vehicle) then return end

    if NetworkGetEntityOwner(vehicle) == PlayerId() then
        Entity(vehicle).state:set("handbrakeEngaged", engaged == true, true)
    end
end)
