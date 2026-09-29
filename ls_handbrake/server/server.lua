
-- ============================================================================
-- ls_handbrake - Server Script
-- Handles server-side handbrake toggling, state bags, and exports
-- ============================================================================

local MTCore = nil
pcall(function() MTCore = exports['mt_core']:GetCoreObject() end)
if not MTCore then
    pcall(function() MTCore = exports['qb-core']:GetCoreObject() end)
end

-- Server-side export to set handbrake state on a vehicle netId
exports('SetVehicleHandbrake', function(vehicleNetId, engaged)
    if not vehicleNetId then return false end
    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    if not DoesEntityExist(vehicle) then return false end

    Entity(vehicle).state:set("handbrakeEngaged", engaged == true, true)
    return true
end)

-- NetEvent handler to set handbrake state from client
RegisterNetEvent("ls_handbrake:server:toggleHandbrake", function(vehicleNetId, engaged)
    local src = source
    if not vehicleNetId then return end
    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    if not DoesEntityExist(vehicle) then return false end

    Entity(vehicle).state:set("handbrakeEngaged", engaged == true, true)
end)

print("[ls_handbrake] Server side initialized successfully!")
