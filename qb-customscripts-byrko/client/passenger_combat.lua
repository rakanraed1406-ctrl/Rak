--[[═════════════════════════════════════════════════════════════════════
    الضرب داخل نفس السيارة (gp_passengerCombat)
    إصلاحات:
    - قيم الكونفيق كانت ناقصة (MaxDistance/Damage/...) → كان يطلع Error
    - كان يرسل ضربة للسيرفر كل 5ms وأنت ضاغط (قتل فوري) → صار حد أدنى بين الطلقات
    - RemoveNamedPtfxAsset('core') كان يشيل مؤثرات اللعبة كلها
═════════════════════════════════════════════════════════════════════════]]

local Cfg = Config.PassengerCombat
if not Cfg.Enabled then return end

local UNARMED = `WEAPON_UNARMED`
local running = false
local lastShot = 0

local function findTarget(ped, veh, muzzle, endCoords)
    for seat = -1, GetVehicleMaxNumberOfPassengers(veh) - 1 do
        local target = GetPedInVehicleSeat(veh, seat)
        if target ~= 0 and target ~= ped and not IsEntityDead(target) then
            local head = GetPedBoneCoords(target, 31086, 0.0, 0.0, 0.0)
            if Utils.DistancePointToLine(head, muzzle, endCoords) < Cfg.HeadshotRadius then
                return target
            end
        end
    end
    return 0
end

local function startThread()
    if running then return end
    running = true

    CreateThread(function()
        while running do
            local sleep = 500
            local ped, veh, weapon = cache.ped, cache.vehicle, cache.weapon

            if veh and weapon and weapon ~= UNARMED then
                sleep = 250
                local aiming = IsControlPressed(0, 25)
                local canShoot = aiming
                if not Cfg.RequireAiming then canShoot = aiming or IsControlPressed(0, 69) end
                local firstPerson = GetFollowVehicleCamViewMode() == 4

                if canShoot and (not Cfg.FirstPersonOnly or firstPerson) then
                    sleep = 0
                    local muzzle    = Utils.WeaponMuzzleCoords(ped)
                    local direction = Utils.RotationToDirection(GetGameplayCamRot(2))
                    local endCoords = muzzle + direction * Cfg.MaxDistance
                    local target    = findTarget(ped, veh, muzzle, endCoords)

                    if target ~= 0 then
                        DisablePlayerFiring(PlayerId(), true)
                        DisableControlAction(0, 24, true)
                        DisableControlAction(0, 69, true)

                        local t = GetGameTimer()
                        if (IsDisabledControlPressed(0, 24) or IsDisabledControlJustPressed(0, 69))
                            and t - lastShot >= Cfg.FireInterval then
                            local hasAmmo, clip = GetAmmoInClip(ped, weapon)
                            if hasAmmo and clip > 0 then
                                lastShot = t
                                SetPedShootsAtCoord(ped, endCoords.x, endCoords.y, endCoords.z, true)

                                -- نرسل الرصاص الحقيقي بعد ما تطلع الطلقة (قبل كان ينقص قبل الطلقة = يختلف مع الشنطة)
                                if GetResourceState('ox_inventory') == 'started' then
                                    local w = weapon
                                    SetTimeout(60, function()
                                        TriggerServerEvent('ox_inventory:updateWeapon', 'ammo', GetAmmoInPedWeapon(cache.ped, w))
                                    end)
                                end

                                if IsPedAPlayer(target) then
                                    local sid = GetPlayerServerId(NetworkGetPlayerIndexFromPed(target))
                                    TriggerServerEvent('gp_passengerCombat:hitTarget', sid)
                                elseif GetEntityHealth(target) > 0 then
                                    ApplyDamageToPed(target, Cfg.Damage, false)
                                end
                            end
                        end
                    end
                end
            end
            Wait(sleep)
        end
    end)
end

lib.onCache('vehicle', function(vehicle)
    if vehicle then startThread() else running = false end
end)
if cache.vehicle then startThread() end

RegisterNetEvent('gp_passengerCombat:receiveDamage', function(damage)
    local ped = cache.ped
    if GetPlayerInvincible(PlayerId()) or not GetEntityCanBeDamaged(ped) then return end

    ApplyDamageToPed(ped, tonumber(damage) or 0, false)

    RequestNamedPtfxAsset('core')
    local deadline = GetGameTimer() + 1000
    while not HasNamedPtfxAssetLoaded('core') and GetGameTimer() < deadline do Wait(0) end
    if HasNamedPtfxAssetLoaded('core') then
        UseParticleFxAssetNextCall('core')
        StartNetworkedParticleFxNonLoopedOnPedBone('blood_headshot', ped, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 31086, 1.5, false, false, false)
    end
end)
