--[[═════════════════════════════════════════════════════════════════════
    الضرب داخل السيارة — تحقق السيرفر (الحدث هذا يجي من الكلاينت = ممكن ينغش)
    - حد أدنى بين الضربات لكل لاعب + حد أقصى ضربات على نفس الهدف
    - لازم شايل سلاح ناري (مو يد/سلاح أبيض/قنابل) + فيه رصاص (ox_inventory)
    - نفس السيارة، الاثنين أحياء، قريبين
    - الضرر من السيرفر مو من الكلاينت
    - أي محاولة غش تنسجل (ومع Config.Security.KickOnAbuse يطرده)
═════════════════════════════════════════════════════════════════════════]]

local Cfg = Config.PassengerCombat
local Sec = Config.Security

local blockedWeapons = {}
for _, name in ipairs(Cfg.BlockedWeapons or {}) do blockedWeapons[joaat(name)] = true end

local lastHit, targetHits, strikes = {}, {}, {}

local function identifiers(src)
    local ids = {}
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if id:find('^license:') or id:find('^discord:') or id:find('^fivem:') then ids[#ids + 1] = id end
    end
    return table.concat(ids, ' ')
end

local function abuse(src, reason)
    local now = os.time()
    local s = strikes[src]
    if not s or now - s.since > 60 then s = { count = 0, since = now } strikes[src] = s end
    s.count = s.count + 1

    print(('^1[customscripts][anti-cheat]^7 %s (%d) %s — %s [%d/%d]'):format(
        GetPlayerName(src) or '?', src, reason, identifiers(src), s.count, Sec.MaxStrikes))

    if Sec.KickOnAbuse and s.count >= Sec.MaxStrikes then
        DropPlayer(src, 'customscripts: محاولة غش (passengerCombat)')
    end
end

local function hasAmmo(src)
    if GetResourceState('ox_inventory') ~= 'started' then return true end
    local ok, weapon = pcall(function() return exports.ox_inventory:GetCurrentWeapon(src) end)
    if not ok or not weapon then return true end          -- ما نقدر نتأكد → ما نظلم اللاعب
    local ammo = weapon.metadata and weapon.metadata.ammo
    return ammo == nil or ammo > 0
end

RegisterNetEvent('gp_passengerCombat:hitTarget', function(targetServerId)
    local src = source
    if not Cfg.Enabled then return end

    targetServerId = tonumber(targetServerId)
    if not targetServerId or targetServerId ~= math.floor(targetServerId) or targetServerId == src
        or not GetPlayerName(targetServerId) then
        return abuse(src, 'هدف غلط')
    end

    local now = GetGameTimer()
    if lastHit[src] and now - lastHit[src] < math.max(Cfg.FireInterval - 50, 80) then
        return abuse(src, 'ضربات أسرع من السلاح')
    end
    lastHit[src] = now

    -- حد أقصى ضربات على نفس الهدف (حتى لو كذا واحد يغشون عليه)
    local th = targetHits[targetServerId]
    if not th or now - th.since > 1000 then th = { count = 0, since = now } targetHits[targetServerId] = th end
    th.count = th.count + 1
    if th.count > Cfg.MaxHitsPerSecond then return end

    local shooter, target = GetPlayerPed(src), GetPlayerPed(targetServerId)
    if not DoesEntityExist(shooter) or not DoesEntityExist(target) then return end
    if GetEntityHealth(shooter) <= 0 or GetEntityHealth(target) <= 0 then return end

    local weapon = GetSelectedPedWeapon(shooter)
    if weapon == `WEAPON_UNARMED` or blockedWeapons[weapon] then
        return abuse(src, 'ضرب بدون سلاح ناري')
    end
    if not hasAmmo(src) then return abuse(src, 'ضرب بدون رصاص') end

    local shooterVeh = GetVehiclePedIsIn(shooter, false)
    if shooterVeh == 0 or shooterVeh ~= GetVehiclePedIsIn(target, false) then
        return abuse(src, 'ضرب من برا السيارة أو من سيارة ثانية')
    end
    if #(GetEntityCoords(shooter) - GetEntityCoords(target)) > 6.0 then
        return abuse(src, 'الهدف بعيد')
    end

    TriggerClientEvent('gp_passengerCombat:receiveDamage', targetServerId, Cfg.Damage)
end)

AddEventHandler('playerDropped', function()
    lastHit[source], targetHits[source], strikes[source] = nil, nil, nil
end)
