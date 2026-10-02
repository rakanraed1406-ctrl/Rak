--[[═════════════════════════════════════════════════════════════════════
    ضبط السيارات
    - حد سرعة الريوس (الهاندلنق ما فيه خانة للريوس، فنضبطه من هنا)
    - /cartest       : يقيس 0-100 ومسافة الفرامل 100-0
    - /cartest top   : يقيس السرعة القصوى (يبي لك خط طويل)
    - /carcalib      : (للأدمن) يظبط القومة على 4.0 ثواني بالضبط ويحفظها للسيرفر كله
═════════════════════════════════════════════════════════════════════════]]

local Cfg = Config.VehicleTuning
if not Cfg.Enabled then return end

local calibration = {}   -- [tostring(modelHash)] = fInitialDriveForce
local testing = false

local SKIP_CLASSES = { [14] = true, [15] = true, [16] = true, [21] = true }

----------------------------------------------------------------------
-- تطبيق القومة المظبوطة على السيارة اللي تسوقها
----------------------------------------------------------------------
local function applyTuning(veh)
    if not veh or not DoesEntityExist(veh) then return end
    local force = calibration[tostring(GetEntityModel(veh))]
    if force then
        SetVehicleHandlingFloat(veh, 'CHandlingData', 'fInitialDriveForce', force + 0.0)
    end
end

local function applyIfDriver()
    local veh = cache.vehicle
    if veh and GetPedInVehicleSeat(veh, -1) == cache.ped then applyTuning(veh) end
end

RegisterNetEvent('qb-customscripts-byrko:client:calibration', function(data)
    if type(data) == 'table' then calibration = data end
    applyIfDriver()
end)

CreateThread(function()
    calibration = lib.callback.await('qb-customscripts-byrko:server:getCalibration', false) or {}
    applyIfDriver()
end)

lib.onCache('seat', function(seat) if seat == -1 then SetTimeout(250, applyIfDriver) end end)

----------------------------------------------------------------------
-- حد سرعة الريوس
----------------------------------------------------------------------
local reverseLimits = {}
for name, limit in pairs(Cfg.Reverse.Models or {}) do reverseLimits[joaat(name)] = limit end

if Cfg.Reverse.Enabled then
    CreateThread(function()
        local curVeh, limit, skip = 0, Cfg.Reverse.Default, true
        while true do
            local sleep = 500
            local veh = cache.vehicle
            if veh ~= curVeh then
                curVeh = veh or 0
                if veh then
                    limit = reverseLimits[GetEntityModel(veh)] or Cfg.Reverse.Default
                    skip = SKIP_CLASSES[GetVehicleClass(veh)] or false
                end
            end
            if veh and not skip and not testing and GetPedInVehicleSeat(veh, -1) == cache.ped then
                -- خفيف: كل 200ms، وكل فريم بس لما ترجع ريوس قريب من الحد
                local back = -GetEntitySpeedVector(veh, true).y * 3.6
                if back > limit then
                    DisableControlAction(0, 72, true) -- يوقف دعسة الريوس فوق الحد
                    sleep = 0
                elseif back > limit - 8.0 then
                    sleep = 0
                else
                    sleep = 200
                end
            end
            Wait(sleep)
        end
    end)
end

----------------------------------------------------------------------
-- أدوات القياس
----------------------------------------------------------------------
local function kmh(veh) return GetEntitySpeed(veh) * 3.6 end

local function stillDriving(veh)
    return cache.vehicle == veh and GetPedInVehicleSeat(veh, -1) == cache.ped and not IsEntityDead(veh)
end

local function modelLabel(veh)
    local name = GetDisplayNameFromVehicleModel(GetEntityModel(veh))
    return (name and name ~= 'CARNOTFOUND') and name:lower() or tostring(GetEntityModel(veh))
end

local function countdown()
    for i = 3, 1, -1 do
        Utils.Notify(('يبدأ القياس بعد %d — خل الدركسون مستقيم'):format(i), 'inform')
        Wait(1000)
    end
end

--- يدعس بنزين لين 100 → يرجع الوقت بالثواني (أو nil لو انلغى)
local function launch(veh)
    if kmh(veh) > 1.0 then
        Utils.Notify('وقف السيارة أول', 'error')
        return nil
    end
    countdown()

    local health = GetVehicleBodyHealth(veh)
    local t0 = GetGameTimer()
    while true do
        Wait(0)
        if not stillDriving(veh) then return nil end
        if IsControlPressed(0, 72) or IsDisabledControlPressed(0, 72) then
            Utils.Notify('انلغى القياس (فرامل)', 'error') return nil
        end
        if health - GetVehicleBodyHealth(veh) > 5.0 then
            Utils.Notify('انلغى القياس (صدمت)', 'error') return nil
        end
        if GetGameTimer() - t0 > 20000 then
            Utils.Notify('انلغى القياس (أكثر من 20 ثانية)', 'error') return nil
        end

        SetControlNormal(0, 71, 1.0)
        if kmh(veh) >= 100.0 then return (GetGameTimer() - t0) / 1000.0 end
    end
end

--- فرامل كاملة لين توقف → مسافة الوقوف محسوبة من 100 كم/س بالضبط
local function brake(veh)
    local v0 = GetEntitySpeed(veh)
    if v0 < 5.0 then return nil end
    local start = GetEntityCoords(veh)
    local deadline = GetGameTimer() + 15000
    while GetEntitySpeed(veh) > 0.3 and GetGameTimer() < deadline do
        if not stillDriving(veh) then return nil end
        SetControlNormal(0, 72, 1.0)
        Wait(0)
    end
    local dist = #(GetEntityCoords(veh) - start)
    return dist * (27.7778 / v0) ^ 2
end

local function topSpeed(veh)
    countdown()
    local best, lastGain, t0 = 0.0, GetGameTimer(), GetGameTimer()
    while GetGameTimer() - t0 < 90000 do
        Wait(0)
        if not stillDriving(veh) or IsControlPressed(0, 72) then break end
        SetControlNormal(0, 71, 1.0)
        local s = kmh(veh)
        if s > best + 0.3 then best, lastGain = s, GetGameTimer() end
        if GetGameTimer() - lastGain > 4000 and best > 50.0 then break end  -- ما عاد تزيد
    end
    return best
end

local function needDriver()
    local veh = cache.vehicle
    if not veh or GetPedInVehicleSeat(veh, -1) ~= cache.ped then
        Utils.Notify('لازم تكون سايق', 'error')
        return nil
    end
    if testing then Utils.Notify('فيه قياس شغال', 'error') return nil end
    return veh
end

----------------------------------------------------------------------
-- /cartest
----------------------------------------------------------------------
RegisterCommand(Cfg.TestCommand, function(_, args)
    local veh = needDriver()
    if not veh then return end
    testing = true

    CreateThread(function()
        if args[1] == 'top' then
            local top = topSpeed(veh)
            local msg = ('%s | السرعة القصوى: %.1f كم/س'):format(modelLabel(veh), top)
            Utils.Notify(msg, 'success') print('[cartest] ' .. msg)
        else
            local t = launch(veh)
            if t then
                local d = brake(veh)
                local msg = ('%s | 0-100: %.2f ثانية | الفرامل 100-0: %s'):format(
                    modelLabel(veh), t, d and ('%.1f متر'):format(d) or '-')
                Utils.Notify(msg, 'success') print('[cartest] ' .. msg)
            end
        end
        testing = false
    end)
end, false)
TriggerEvent('chat:addSuggestion', '/' .. Cfg.TestCommand, 'يقيس 0-100 والفرامل (أو top للسرعة القصوى)', {
    { name = 'top', help = 'اكتب top عشان تقيس السرعة القصوى' },
})

----------------------------------------------------------------------
-- /carcalib — يظبط القومة على Target0to100 ويحفظها للكل
----------------------------------------------------------------------
local function waitForContinue()
    Utils.Notify('رجع السيارة لمكان فاضي، وقفها، واضغط E للمحاولة الجاية (X = إلغاء)', 'inform')
    while true do
        Wait(0)
        if IsControlJustPressed(0, 73) then return false end          -- X
        if IsControlJustPressed(0, 38) and kmh(cache.vehicle or 0) < 1.0 then return true end -- E
        if not cache.vehicle then return false end
    end
end

RegisterCommand(Cfg.CalibCommand, function()
    local veh = needDriver()
    if not veh then return end
    if not lib.callback.await('qb-customscripts-byrko:server:canCalibrate', false) then
        return Utils.Notify('هذا الأمر للأدمن بس', 'error')
    end
    testing = true

    CreateThread(function()
        local target, tol = Cfg.Target0to100, Cfg.Tolerance
        local force = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fInitialDriveForce')
        local lastTime, done = nil, false

        for run = 1, Cfg.MaxCalibRuns do
            Utils.Notify(('محاولة %d/%d — القومة الحالية %.4f'):format(run, Cfg.MaxCalibRuns, force), 'inform')
            local t = launch(veh)
            if not t then break end
            brake(veh)
            print(('[carcalib] %s run %d: force %.4f → 0-100 %.2fs'):format(modelLabel(veh), run, force, t))

            if math.abs(t - target) <= tol then done = true break end

            -- زودنا القومة والوقت ما تحسن = الكفرات تفحط (حد الجريب)
            if lastTime and t > target and t >= lastTime - 0.02 then
                Utils.Notify('السيارة توصل حد الجريب (تفحط) — ما تقدر تنزل أقل من كذا بدون جريب أكثر', 'error')
                break
            end
            lastTime = t

            local factor = (t / target) ^ 1.15
            factor = math.max(0.6, math.min(1.6, factor))
            force = force * factor
            SetVehicleHandlingFloat(veh, 'CHandlingData', 'fInitialDriveForce', force + 0.0)

            if run < Cfg.MaxCalibRuns and not waitForContinue() then break end
        end

        if done then
            TriggerServerEvent('qb-customscripts-byrko:server:saveCalibration', GetEntityModel(veh), force)
            local msg = ('%s مظبوطة: 0-100 = %.1f ثانية | fInitialDriveForce = %.4f (انحفظت للسيرفر كله)')
                :format(modelLabel(veh), target, force)
            Utils.Notify(msg, 'success') print('[carcalib] ' .. msg)
        else
            Utils.Notify('ما اكتمل الظبط — ما انحفظ شي', 'error')
            applyTuning(veh)
        end
        testing = false
    end)
end, false)
TriggerEvent('chat:addSuggestion', '/' .. Cfg.CalibCommand, '(أدمن) يظبط 0-100 على ' .. Cfg.Target0to100 .. ' ثواني ويحفظها')
