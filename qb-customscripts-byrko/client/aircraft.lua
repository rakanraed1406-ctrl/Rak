--[[═════════════════════════════════════════════════════════════════════
    هوا المراوح: هزة كاميرا + دفع السيارات القريبة من الطيارة/الهيلي
    إصلاحات:
    - GetClosestVehicle ما يرجع طيارات/هيلي وكان يرجع قيمة وحدة (الدفع ما كان يشتغل)
    - كان يمسح كل 50ms حتى لو ما فيه طيارة قريبة
    - الهيلي اللي واقفة بالجو (Hover) ما كان لها هوا
    - ما نوقف هزة كاميرا سكربت ثاني
═════════════════════════════════════════════════════════════════════════]]

local Cfg = Config.RotorWash
if not Cfg.Enabled then return end

local shaking = false

local function stopShake()
    if shaking then
        StopGameplayCamShaking(false)
        shaking = false
    end
end

local function shake(amount)
    if shaking and IsGameplayCamShaking() then
        SetGameplayCamShakeAmplitude(amount)
    elseif not IsGameplayCamShaking() then
        ShakeGameplayCam('SKY_DIVING_SHAKE', amount)
        shaking = true
    end
end

--- أقرب طيارة/هيلي موترها شغال (نفحص المسافة أول = أخف) + السيارات القريبة منها للدفع
local function findAircraft(pos)
    local best, bestDist = 0, Cfg.Range
    local near = {}
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        local d = #(GetEntityCoords(veh) - pos)
        if d < Cfg.Range + Cfg.PushRange then
            near[#near + 1] = veh
            if d < bestDist then
                local model = GetEntityModel(veh)
                if (IsThisModelAHeli(model) or IsThisModelAPlane(model))
                    and GetIsVehicleEngineRunning(veh) and not IsEntityDead(veh) then
                    best, bestDist = veh, d
                end
            end
        end
    end
    return best, near
end

local function pushVehicles(aircraft, coords, scale, isPlane, near)
    local force = (isPlane and Cfg.PushForcePlane or Cfg.PushForceHeli) * scale
    for _, v in ipairs(near) do
        if v ~= aircraft and DoesEntityExist(v) and NetworkHasControlOfEntity(v) then
            local diff = GetEntityCoords(v) - coords
            local dist = #diff
            if dist < Cfg.PushRange and dist > 0.5 and GetPedInVehicleSeat(v, -1) == 0 then
                local dir = vector3(diff.x, diff.y, 0.0) / math.max(#vector3(diff.x, diff.y, 0.0), 0.01)
                ApplyForceToEntity(v, 1, dir.x * force, dir.y * force, -force * 0.5,
                    0.0, 0.0, 0.0, 0, false, true, true, false, true)
            end
        end
    end
end

-- خفيف: مسح كل 2.5 ثانية لما ما فيه طيارة، والهزة كل 100ms بس لما فيه وحدة قريبة
CreateThread(function()
    local aircraft, near, nextScan, nextPush = 0, {}, 0, 0

    while true do
        local sleep = 1000
        local t = GetGameTimer()
        local pos = GetEntityCoords(cache.ped)

        if t >= nextScan then
            aircraft, near = findAircraft(pos)
            nextScan = t + (aircraft ~= 0 and 1000 or 2500)
        end

        if aircraft ~= 0 and DoesEntityExist(aircraft) and GetIsVehicleEngineRunning(aircraft) then
            sleep = 100
            local isPlane = IsThisModelAPlane(GetEntityModel(aircraft))
            local coords  = GetEntityCoords(aircraft)
            local height  = GetEntityHeightAboveGround(aircraft)
            local rpm     = GetVehicleCurrentRpm(aircraft)
            local dist    = #(pos - coords)

            -- الطيارة لازم تتحرك، الهيلي يكفي إنها بالجو
            local active = GetEntitySpeed(aircraft) > 1.5 or (not isPlane and IsEntityInAir(aircraft))

            if active and height < Cfg.MaxHeight and rpm > 0.02 and dist < Cfg.Range then
                local scale = ((Cfg.MaxHeight - height) / Cfg.MaxHeight) * rpm * ((1.0 - dist / Cfg.Range) + 0.02)
                if scale < 0.02 then scale = 0.02 end

                if height < 35.0 and dist < 35.0 then
                    local amount = isPlane and Cfg.ShakePlane or Cfg.ShakeHeli
                    if cache.vehicle == aircraft then amount = amount * 0.25 end
                    shake(scale * amount)
                else
                    stopShake()
                end

                if Cfg.PushVehicles and height < Cfg.PushRange and t >= nextPush then
                    nextPush = t + 300
                    pushVehicles(aircraft, coords, scale * 3.0, isPlane, near)
                end
            else
                stopShake()
            end
        else
            stopShake()
        end

        Wait(sleep)
    end
end)
