-- ============================================================================
-- ls_handbrake - Server Script
-- The handbrake state lives in the vehicle state bag "handbrakeEngaged".
-- Only the server writes it, after checking the player is really at the car.
-- ============================================================================

local MAX_DISTANCE = 6.0
local lastToggle = {}

local function SetHandbrake(vehicle, engaged)
    Entity(vehicle).state:set("handbrakeEngaged", engaged == true, true)
end

-- Server-side export to set handbrake state on a vehicle netId
exports('SetVehicleHandbrake', function(vehicleNetId, engaged)
    if not vehicleNetId then return false end
    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return false end
    SetHandbrake(vehicle, engaged)
    return true
end)

-- Was: any client could lock / unlock the handbrake of any car on the map.
RegisterNetEvent("ls_handbrake:server:toggleHandbrake", function(vehicleNetId, engaged)
    local src = source
    vehicleNetId = tonumber(vehicleNetId)
    if not vehicleNetId then return end
    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) or GetEntityType(vehicle) ~= 2 then return end

    local ped = GetPlayerPed(src)
    if ped == 0 then return end
    local inside = GetVehiclePedIsIn(ped, false) == vehicle
    if not inside and #(GetEntityCoords(ped) - GetEntityCoords(vehicle)) > MAX_DISTANCE then return end

    local now = GetGameTimer()
    if lastToggle[src] and now - lastToggle[src] < 250 then return end
    lastToggle[src] = now

    if (Entity(vehicle).state.handbrakeEngaged == true) ~= (engaged == true) then
        SetHandbrake(vehicle, engaged)
    end
end)

AddEventHandler('playerDropped', function() lastToggle[source] = nil end)

-- A player drove this car: from now on it can roll down hills when left without the brake
-- (ambient / showroom cars nobody touched stay where they are).
RegisterNetEvent("ls_handbrake:server:markDriven", function(vehicleNetId)
    local src = source
    local vehicle = NetworkGetEntityFromNetworkId(tonumber(vehicleNetId) or 0)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end
    local ped = GetPlayerPed(src)
    if ped == 0 or GetVehiclePedIsIn(ped, false) ~= vehicle then return end
    if Entity(vehicle).state.lsDriven ~= true then
        Entity(vehicle).state:set("lsDriven", true, true)
    end
end)
