--[[═════════════════════════════════════════════════════════════════════
    الضرب داخل السيارة — تحقق السيرفر
    إصلاحات الثغرات: حد أدنى بين الضربات، لازم يكون شايل سلاح، نفس السيارة،
    الهدف حي وقريب، والضرر من السيرفر مو من الكلاينت.
═════════════════════════════════════════════════════════════════════════]]

local Cfg = Config.PassengerCombat
local UNARMED = `WEAPON_UNARMED`
local lastHit = {}

RegisterNetEvent('gp_passengerCombat:hitTarget', function(targetServerId)
    local src = source
    if not Cfg.Enabled then return end

    targetServerId = tonumber(targetServerId)
    if not targetServerId or targetServerId == src or not GetPlayerName(targetServerId) then return end

    local now = GetGameTimer()
    if lastHit[src] and now - lastHit[src] < math.max(Cfg.FireInterval - 50, 80) then return end
    lastHit[src] = now

    local shooter, target = GetPlayerPed(src), GetPlayerPed(targetServerId)
    if not DoesEntityExist(shooter) or not DoesEntityExist(target) then return end
    if GetEntityHealth(shooter) <= 0 or GetEntityHealth(target) <= 0 then return end
    if GetSelectedPedWeapon(shooter) == UNARMED then return end

    local shooterVeh = GetVehiclePedIsIn(shooter, false)
    if shooterVeh == 0 or shooterVeh ~= GetVehiclePedIsIn(target, false) then
        print(('[passengerCombat] %s (%d) حاول يضرب من برا السيارة أو من سيارة ثانية'):format(GetPlayerName(src), src))
        return
    end
    if #(GetEntityCoords(shooter) - GetEntityCoords(target)) > 6.0 then return end

    TriggerClientEvent('gp_passengerCombat:receiveDamage', targetServerId, Cfg.Damage)
end)

AddEventHandler('playerDropped', function()
    lastHit[source] = nil
end)
