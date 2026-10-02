--[[═════════════════════════════════════════════════════════════════════
    حفظ ظبط القومة (/carcalib) بملف calibration.json وتوزيعه على الكل
═════════════════════════════════════════════════════════════════════════]]

local Cfg = Config.VehicleTuning
if not Cfg.Enabled then return end

local RES, FILE = GetCurrentResourceName(), 'calibration.json'
local calibration = json.decode(LoadResourceFile(RES, FILE) or '') or {}

local function isAdmin(src)
    if IsPlayerAceAllowed(src, Cfg.AdminAce) then return true end
    if GetResourceState('qb-core') == 'started' then
        local QBCore = exports['qb-core']:GetCoreObject()
        return QBCore.Functions.HasPermission(src, 'admin') or QBCore.Functions.HasPermission(src, 'god')
    end
    return false
end

lib.callback.register('qb-customscripts-byrko:server:getCalibration', function()
    return calibration
end)

lib.callback.register('qb-customscripts-byrko:server:canCalibrate', function(source)
    return isAdmin(source)
end)

RegisterNetEvent('qb-customscripts-byrko:server:saveCalibration', function(model, force)
    local src = source
    if not isAdmin(src) then return end

    model, force = tonumber(model), tonumber(force)
    if not model or not force or force < 0.05 or force > 2.0 then return end

    calibration[tostring(model)] = math.floor(force * 10000 + 0.5) / 10000
    SaveResourceFile(RES, FILE, json.encode(calibration, { indent = true }), -1)
    TriggerClientEvent('qb-customscripts-byrko:client:calibration', -1, calibration)
    print(('[carcalib] %s ظبط موديل %d → fInitialDriveForce %.4f'):format(GetPlayerName(src) or src, model, force))
end)
