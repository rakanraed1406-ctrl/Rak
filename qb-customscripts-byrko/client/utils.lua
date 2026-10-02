Utils = {}

local QBCore

function Utils.Log(...)
    if Config.Debug then print(('[customscripts] %s'):format(table.concat({ ... }, ' '))) end
end

function Utils.Notify(msg, kind)
    kind = kind or 'inform'
    if Config.Notify == 'qb' and GetResourceState('qb-core') == 'started' then
        QBCore = QBCore or exports['qb-core']:GetCoreObject()
        QBCore.Functions.Notify(msg, kind == 'inform' and 'primary' or kind)
        return
    end
    lib.notify({ description = msg, type = kind, position = 'top' })
end

local lastNotify = {}
--- نفس الرسالة ما تتكرر أكثر من مرة كل `gap` ملّي ثانية
function Utils.NotifyOnce(key, msg, kind, gap)
    local now = GetGameTimer()
    if lastNotify[key] and now - lastNotify[key] < (gap or 3000) then return end
    lastNotify[key] = now
    Utils.Notify(msg, kind)
end

function Utils.PlayerData()
    if GetResourceState('qb-core') ~= 'started' then return nil end
    QBCore = QBCore or exports['qb-core']:GetCoreObject()
    return QBCore.Functions.GetPlayerData()
end

function Utils.IsAircraft(veh)
    local model = GetEntityModel(veh)
    return IsThisModelAPlane(model) or IsThisModelAHeli(model)
end

--- السرعة بالوحدة اللي بالكونفيق (كم/س أو ميل/س)
function Utils.Speed(veh)
    local mps = GetEntitySpeed(veh)
    return (Config.Engine.SpeedUnit == 'mph') and mps * 2.236936 or mps * 3.6
end

function Utils.SpeedUnitLabel()
    return (Config.Engine.SpeedUnit == 'mph') and 'ميل/س' or 'كم/س'
end

function Utils.Plate(veh)
    return (GetVehicleNumberPlateText(veh) or ''):gsub('^%s*(.-)%s*$', '%1')
end

--- نملك السيارة بالشبكة؟ (التغييرات ما تنحفظ إلا للمالك)
function Utils.Owns(entity)
    if not NetworkGetEntityIsNetworked(entity) then return true end
    return NetworkGetEntityOwner(entity) == PlayerId()
end

----------------------------------------------------------------------
-- حسابات (من functions.lua القديم)
----------------------------------------------------------------------
function Utils.DistancePointToLine(point, lineStart, lineEnd)
    local ab = lineEnd - lineStart
    local ap = point - lineStart
    local ab2 = ab.x * ab.x + ab.y * ab.y + ab.z * ab.z
    if ab2 == 0.0 then return #(point - lineStart) end

    local t = (ap.x * ab.x + ap.y * ab.y + ap.z * ab.z) / ab2
    if t < 0.0 then t = 0.0 elseif t > 1.0 then t = 1.0 end -- ما نضرب اللي ورانا

    return #(point - (lineStart + ab * t))
end

function Utils.WeaponMuzzleCoords(ped)
    local weaponEntity = GetCurrentPedWeaponEntityIndex(ped)
    if DoesEntityExist(weaponEntity) then
        local bone = GetEntityBoneIndexByName(weaponEntity, 'gun_muzzle')
        if bone ~= -1 then return GetWorldPositionOfEntityBone(weaponEntity, bone) end
    end
    return GetPedBoneCoords(ped, 24806, 0.0, 0.0, 0.0) -- اليد اليمين
end

function Utils.RotationToDirection(rot)
    local z, x = math.rad(rot.z), math.rad(rot.x)
    local n = math.abs(math.cos(x))
    return vector3(-math.sin(z) * n, math.cos(z) * n, math.sin(x))
end
