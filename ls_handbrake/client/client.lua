-- ============================================================================
-- ls_handbrake - Client Script
--   * Hold the handbrake key to pull / release the parking brake (a tap stays a
--     normal handbrake for stopping / drifting).
--   * The sound is 3D: people inside the car hear it fully, people outside hear it
--     quieter the further they are, and nobody hears it past Config.sound.max_distance.
--   * The brake keeps holding even when the car changes owner, and cars left
--     without the parking brake roll down hills.
-- ============================================================================

local hasBeenNotified = not (Config and Config.handbrake_alert)
local tracked = {}      -- [vehicle] = true  → handbrake engaged, close to us
local rolling = {}      -- [vehicle] = true  → rolling down a hill (we own it)
local lastSound = {}    -- [vehicle] = { value, time } (no double sounds)
local markedDriven = {} -- [netId] = true

-- ── Helpers ──────────────────────────────────────────────────────────────────
local function TriggerHandbrakeNotification()
    if hasBeenNotified then return end
    hasBeenNotified = true
    CreateThread(function()
        Wait(1000)
        if HandBrakeNotify then HandBrakeNotify() end
    end)
end

local function IsEngaged(vehicle)
    return Entity(vehicle).state.handbrakeEngaged == true
end

local vehicleClasses = {
    [0] = "Compacts", [1] = "Sedans", [2] = "SUVs", [3] = "Coupes", [4] = "Muscle",
    [5] = "Sports Classics", [6] = "Sports", [7] = "Super", [8] = "Motorcycles", [9] = "Off-road",
    [10] = "Industrial", [11] = "Utility", [12] = "Vans", [13] = "Cycles", [14] = "Boats",
    [15] = "Helicopters", [16] = "Planes", [17] = "Service", [18] = "Emergency", [19] = "Military",
    [20] = "Commercial", [21] = "Trains", [22] = "Open Wheel",
}
local exemptClass, exemptModel = {}, {}
for _, name in pairs(Config.automatic_handbrake_vehicles.classes or {}) do
    for id, cname in pairs(vehicleClasses) do if cname == name then exemptClass[id] = true end end
    if name == 'Bikes' then exemptClass[8] = true end -- "Bikes" = motorcycles
end
for _, m in pairs(Config.automatic_handbrake_vehicles.models or {}) do exemptModel[joaat(m)] = true end

local function IsExempt(vehicle)
    return exemptClass[GetVehicleClass(vehicle)] or exemptModel[GetEntityModel(vehicle)] or false
end

-- ── 3D sound ─────────────────────────────────────────────────────────────────
local function PlayHandbrakeSound(vehicle, engaged)
    local s = Config.sound
    local ped = PlayerPedId()
    local volume, pan

    if GetVehiclePedIsIn(ped, false) == vehicle then
        volume, pan = s.volume, 0.0
    else
        local myPos = GetEntityCoords(ped)
        local vehPos = GetEntityCoords(vehicle)
        local dist = #(myPos - vehPos)
        if dist > s.max_distance then return end
        local falloff = 1.0 - (dist / s.max_distance)
        volume = s.volume * s.outside_volume * falloff * falloff
        pan = 0.0
        if s.stereo and dist > 0.5 then
            -- where is the car compared to where the camera looks (left = -1, right = 1)
            local camHeading = GetGameplayCamRot(2).z
            local dx, dy = vehPos.x - myPos.x, vehPos.y - myPos.y
            local toCar = math.deg(math.atan(dy, dx)) - 90.0
            pan = -math.sin(math.rad(toCar - camHeading)) * 0.8
        end
    end
    if volume <= 0.01 then return end
    SendNUIMessage({ action = engaged and 'tightenHandbrake' or 'releaseHandbrake', volume = volume, pan = pan })
end

-- ── Indicator (P) ────────────────────────────────────────────────────────────
local indicatorShown = false
local function SetIndicator(show)
    if not Config.indicator.enabled or show == indicatorShown then return end
    indicatorShown = show
    SendNUIMessage({ action = 'indicator', show = show, position = Config.indicator.position })
end

-- ── State bag: sound + brake for everyone near the car ───────────────────────
AddStateBagChangeHandler("handbrakeEngaged", nil, function(bagName, _, value)
    local entity = GetEntityFromStateBagName(bagName)
    if not entity or entity == 0 or not DoesEntityExist(entity) or not IsEntityAVehicle(entity) then return end
    local engaged = value == true

    local now = GetGameTimer()
    local last = lastSound[entity]
    if not (last and last.value == engaged and now - last.time < 600) then
        lastSound[entity] = { value = engaged, time = now }
        PlayHandbrakeSound(entity, engaged)
    end

    if engaged then tracked[entity] = true else tracked[entity] = nil end
    if NetworkGetEntityOwner(entity) == PlayerId() then
        SetVehicleHandbrake(entity, engaged)
    end
end)

-- Find engaged cars around us (also the ones that were engaged before we got here).
CreateThread(function()
    while true do
        local myPos = GetEntityCoords(PlayerPedId())
        local found = {}
        for _, veh in ipairs(GetGamePool('CVehicle')) do
            if #(GetEntityCoords(veh) - myPos) < 150.0 and IsEngaged(veh) then found[veh] = true end
        end
        tracked = found
        for veh in pairs(lastSound) do
            if not DoesEntityExist(veh) then lastSound[veh] = nil end
        end
        Wait(1000)
    end
end)

-- Keep the brake on (the new owner of a car used to let it roll) + brake lights.
CreateThread(function()
    local nextHold = 0
    while true do
        local any = false
        local now = GetGameTimer()
        local me = PlayerId()
        for veh in pairs(tracked) do
            if DoesEntityExist(veh) then
                any = true
                if IsEntityVisible(veh) then SetVehicleBrakeLights(veh, true) end
                if now >= nextHold and NetworkGetEntityOwner(veh) == me then
                    SetVehicleHandbrake(veh, true)
                end
            end
        end
        if now >= nextHold then nextHold = now + 250 end

        local myVeh = GetVehiclePedIsIn(PlayerPedId(), false)
        SetIndicator(myVeh ~= 0 and IsEngaged(myVeh))
        Wait(any and 0 or 300)
    end
end)

-- ── Driver: hold the key to pull / release ──────────────────────────────────
local function PlayPullAnim(ped)
    local a = Config.anim
    if not a.enabled or not DoesAnimDictExist(a.dict) then return end
    RequestAnimDict(a.dict)
    local t = GetGameTimer() + 1000
    while not HasAnimDictLoaded(a.dict) and GetGameTimer() < t do Wait(10) end
    if HasAnimDictLoaded(a.dict) then
        TaskPlayAnim(ped, a.dict, a.name, 8.0, -8.0, a.duration, 48, 0, false, false, false)
    end
end

local function RequestToggle(vehicle, engaged)
    if not NetworkGetEntityIsNetworked(vehicle) then
        SetVehicleHandbrake(vehicle, engaged) -- local-only car: no sync needed
        return
    end
    TriggerServerEvent("ls_handbrake:server:toggleHandbrake", VehToNet(vehicle), engaged)
end

CreateThread(function()
    local input = Config.handbrake_input
    local pressStart, handled = nil, false
    local lastAutoRelease = 0
    while true do
        local sleep = 500
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)

        if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped then
            sleep = 0
            local netId = NetworkGetEntityIsNetworked(vehicle) and VehToNet(vehicle) or nil
            if netId and not markedDriven[netId] then
                markedDriven[netId] = true
                TriggerServerEvent("ls_handbrake:server:markDriven", netId)
            end

            if input.enabled then
                if IsControlPressed(0, input.control) then
                    pressStart = pressStart or GetGameTimer()
                    if not handled and GetGameTimer() - pressStart >= (input.hold_time or 400) then
                        handled = true
                        local engaged = IsEngaged(vehicle)
                        local speedKmh = GetEntitySpeed(vehicle) * 3.6
                        if engaged or speedKmh <= (input.max_speed_kmh or 8.0) then
                            if not CanUseHandbrake or CanUseHandbrake(vehicle) then
                                PlayPullAnim(ped)
                                RequestToggle(vehicle, not engaged)
                            end
                        end
                    end
                else
                    pressStart, handled = nil, false
                end
            end

            -- driving off releases it (unless Config.require_handbrake_release)
            if not Config.require_handbrake_release and IsEngaged(vehicle)
                and (IsControlPressed(0, 71) or IsControlPressed(0, 72))
                and GetGameTimer() - lastAutoRelease > 1000 then
                lastAutoRelease = GetGameTimer()
                RequestToggle(vehicle, false)
            end
        else
            pressStart, handled = nil, false
        end
        Wait(sleep)
    end
end)

-- ── Rolling down hills ──────────────────────────────────────────────────────
-- Cars someone has driven, with nobody in the driver seat and no parking brake,
-- roll down a slope. Only the client that owns the car moves it (no fighting).
CreateThread(function()
    while true do
        local myPos = GetEntityCoords(PlayerPedId())
        local me = PlayerId()
        local found = {}
        for _, veh in ipairs(GetGamePool('CVehicle')) do
            if NetworkGetEntityOwner(veh) == me
                and #(GetEntityCoords(veh) - myPos) < Config.roll_check_distance
                and Entity(veh).state.lsDriven == true
                and not IsEngaged(veh)
                and IsVehicleSeatFree(veh, -1)
                and not IsEntityPositionFrozen(veh)
                and not IsExempt(veh)
                and IsVehicleOnAllWheels(veh) then
                local pitch = GetEntityRotation(veh, 2).x
                if math.abs(pitch) > Config.angle_threshold then found[veh] = true end
            end
        end
        rolling = found
        Wait(1000)
    end
end)

CreateThread(function()
    local maxSpeed = (Config.max_roll_speed_kmh or 35.0) / 3.6
    while true do
        local any = false
        for veh in pairs(rolling) do
            if DoesEntityExist(veh) and not IsEngaged(veh) and IsVehicleSeatFree(veh, -1) then
                any = true
                TriggerHandbrakeNotification()
                SetVehicleHandbrake(veh, false)
                SetVehicleBrake(veh, false)
                if GetEntitySpeed(veh) < maxSpeed then
                    local pitch = math.max(-15.0, math.min(15.0, GetEntityRotation(veh, 2).x))
                    local forceY = -math.sin(math.rad(pitch)) * 0.8 * (Config.roll_speed or 2.0)
                    ApplyForceToEntity(veh, 1, 0.0, forceY, 0.0, 0.0, 0.0, 0.0, 0, true, true, true, false, true)
                end
            else
                rolling[veh] = nil
            end
        end
        Wait(any and 10 or 500)
    end
end)

-- ── Exports ─────────────────────────────────────────────────────────────────
exports("SetVehicleHandbrake", function(vehicle, engaged)
    if not vehicle or not DoesEntityExist(vehicle) then return end
    if CanUseHandbrake and not CanUseHandbrake(vehicle) then return end
    RequestToggle(vehicle, engaged == true)
end)

exports("IsHandbrakeEngaged", function(vehicle)
    return vehicle and DoesEntityExist(vehicle) and IsEngaged(vehicle) or false
end)
