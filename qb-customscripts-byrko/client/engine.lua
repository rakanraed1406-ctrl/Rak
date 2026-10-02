--[[═════════════════════════════════════════════════════════════════════
    نظام الموتر
    - الموتر ما ينطفي إلا والسرعة أقل من Config.Engine.MaxOffSpeed
    - بالطيارة/الهيلي ما ينطفي وهي بالجو
    - إذا زر G مستخدم لشي ثاني (كفرات الطيارة، بلاغ التابلت، ...) ما يطفي الموتر
    - الموتر يبقى شغال لما تنزل (F مطوّل = تنزل وتطفيه) + الكفرات تبقى ملفوفة

    ملاحظة: زر G اللي يطفي الموتر جاي من سكربت المفاتيح (qb-vehiclekeys)،
    والزر هذا ما ينقفل من سكربت ثاني، فالنظام هنا يراقب الموتر: إذا انطفى
    بوقت ما يصير فيه ينطفي، يرجع يشغله بنفس اللحظة والسيارة ما توقف.
═════════════════════════════════════════════════════════════════════════]]

local Cfg  = Config.Engine
local Keep = Config.KeepEngineOn

local busyModels = {}
for name, on in pairs(Cfg.GKey.Models or {}) do
    if on then busyModels[joaat(name)] = true end
end

local guard = {
    veh = 0, running = false, runningSince = 0, disarmed = false,
    aircraft = false, heli = false, class = -1, staticBusy = false,
    lastG = -100000, lastGBusy = -100000, allowUntil = 0,
    blocks = {}, lastBlock = 0,
    health = 0, lastDamage = -100000,
    wasDriving = false, nextKeepFlag = 0,
}

local exitState = { pressAt = 0, veh = 0, handled = false, angle = 0.0, applyUntil = 0 }

local MESSAGES = {
    speed = function()
        return ('ما تقدر تطفي الموتر وأنت ماشي — لازم السرعة أقل من %s %s')
            :format(Cfg.MaxOffSpeed, Utils.SpeedUnitLabel())
    end,
    air  = function() return 'ما تقدر تطفي الموتر وأنت بالجو' end,
    gkey = function()
        return ('زر G مستخدم لشي ثاني — الموتر ما انطفى (استخدم /%s)'):format(Cfg.Toggle.Command)
    end,
}

----------------------------------------------------------------------
-- أدوات
----------------------------------------------------------------------
local function gKeyPressed()
    for _, c in ipairs(Cfg.GKey.Controls) do
        if IsControlPressed(0, c) or IsDisabledControlPressed(0, c) then return true end
    end
    return false
end

local function getFuel(veh)
    local st = Entity(veh).state.fuel                         -- ox_fuel
    if type(st) == 'number' then return st end
    if DecorExistOn(veh, '_FUEL_LEVEL') then                   -- LegacyFuel / ps-fuel / cdn-fuel
        return DecorGetFloat(veh, '_FUEL_LEVEL')
    end
    return GetVehicleFuelLevel(veh)
end

--- انطفى لسبب طبيعي؟ (خربان / بنزين / غرق / حادث / سكربت ثاني طلب)
local function isLegitShutdown(veh, t)
    if not IsVehicleDriveable(veh, false) then return true end
    if GetVehicleEngineHealth(veh) <= Cfg.AllowOffBelowEngineHealth then return true end
    if getFuel(veh) <= Cfg.AllowOffBelowFuel then return true end
    if guard.class ~= 14 and IsEntityInWater(veh) and GetEntitySubmergedLevel(veh) > 0.6 then return true end
    if t - guard.lastDamage <= Cfg.CrashWindow then return true end
    if Entity(veh).state.engineForcedOff then return true end
    return false
end

local function shouldBlock(veh, t, driving)
    if t < guard.allowUntil then return nil end                       -- طفاه من /motor أو F مطوّل
    if guard.disarmed or t - guard.runningSince < Cfg.ArmDelay then return nil end
    if not Utils.Owns(veh) then return nil end
    if isLegitShutdown(veh, t) then return nil end

    if driving then
        if Cfg.BlockInAir and guard.aircraft and IsEntityInAir(veh) then return 'air' end
        if Utils.Speed(veh) >= Cfg.MaxOffSpeed then return 'speed' end
    end

    if t - guard.lastG <= Cfg.GKey.Window and t - guard.lastGBusy <= Cfg.GKey.Window then
        return 'gkey'
    end
    return nil
end

--- لو سكربت ثاني يصر يطفي الموتر، نتركه بدل ما نتهاوش معه
local function registerBlock(t)
    if t - guard.lastBlock < 300 then return true end   -- نفس الضغطة
    guard.lastBlock = t

    local list = guard.blocks
    list[#list + 1] = t
    while list[1] and t - list[1] > 3000 do table.remove(list, 1) end

    if #list > Cfg.MaxBlocks then
        guard.disarmed, guard.blocks = true, {}
        Utils.Log('engine guard: سكربت ثاني يطفي الموتر باستمرار — وقفنا الحماية لين يشتغل من جديد')
        return false
    end
    return true
end

local function restore(veh)
    SetVehicleEngineOn(veh, true, true, false)
    if guard.heli and IsEntityInAir(veh) then SetHeliBladesFullSpeed(veh) end
end

local function applyKeepFlag(veh)
    local keep = Keep.Enabled and (Keep.Aircraft or not guard.aircraft)
    SetVehicleKeepEngineOnWhenAbandoned(veh, keep and true or false)
end

local function setGuardVehicle(veh, t)
    guard.veh, guard.blocks, guard.disarmed = veh, {}, false
    if veh == 0 then return end

    local model = GetEntityModel(veh)
    guard.running      = GetIsVehicleEngineRunning(veh)
    guard.runningSince = t
    guard.heli         = IsThisModelAHeli(model)
    guard.aircraft     = guard.heli or IsThisModelAPlane(model)
    guard.class        = GetVehicleClass(veh)
    guard.staticBusy   = (Cfg.GKey.Aircraft and guard.aircraft) or Cfg.GKey.Classes[guard.class] or busyModels[model] or false
    guard.health       = GetVehicleEngineHealth(veh) + GetVehicleBodyHealth(veh)
    guard.lastDamage   = -100000
end

----------------------------------------------------------------------
-- النزول من السيارة: F مطوّل يطفي الموتر + الكفرات تبقى ملفوفة
----------------------------------------------------------------------
local function exitPressed(just)
    if just then
        return IsControlJustPressed(0, 75) or IsDisabledControlJustPressed(0, 75)
    end
    return IsControlPressed(0, 75) or IsDisabledControlPressed(0, 75)
        or IsControlPressed(0, 23) or IsDisabledControlPressed(0, 23)
end

local function handleExit(ped, veh, t, driving)
    if driving then
        if t >= exitState.applyUntil then exitState.angle = GetVehicleSteeringAngle(veh) end

        if exitPressed(true) then
            exitState.pressAt, exitState.veh, exitState.handled = t, veh, false
            exitState.applyUntil = t + 4000
        end
    elseif guard.wasDriving and exitState.veh == veh then
        exitState.applyUntil = math.max(exitState.applyUntil, t + 1500)
    end

    -- F مطوّل
    if exitState.pressAt > 0 then
        if not exitPressed(false) then
            exitState.pressAt = 0
        elseif Keep.HoldToTurnOff and not exitState.handled and t - exitState.pressAt >= Keep.HoldTime then
            exitState.handled = true
            local v = exitState.veh
            if DoesEntityExist(v) and GetIsVehicleEngineRunning(v) and Utils.Speed(v) < Cfg.MaxOffSpeed then
                guard.allowUntil = t + 1500
                SetVehicleEngineOn(v, false, false, true)
                Utils.Notify('طفيت الموتر', 'inform')
            end
        end
    end

    -- الكفرات تبقى على نفس اللفة
    if Keep.KeepWheelAngle and exitState.veh == veh and t < exitState.applyUntil
        and (not driving or GetIsTaskActive(ped, 2)) and Utils.Owns(veh) then
        SetVehicleSteeringAngle(veh, exitState.angle)
    end
end

----------------------------------------------------------------------
-- اللوب
----------------------------------------------------------------------
local function tick(ped, veh, t, driving)
    if gKeyPressed() then guard.lastG = t end
    if guard.staticBusy or Cfg.GKey.Always or LocalPlayer.state.gKeyBusy then guard.lastGBusy = t end

    local h = GetVehicleEngineHealth(veh) + GetVehicleBodyHealth(veh)
    if guard.health - h >= Cfg.CrashDamage then guard.lastDamage = t end
    guard.health = h

    if driving and t >= guard.nextKeepFlag then
        guard.nextKeepFlag = t + 1000
        applyKeepFlag(veh)
    end

    handleExit(ped, veh, t, driving)

    local running = GetIsVehicleEngineRunning(veh)
    if running then
        if not guard.running then guard.runningSince, guard.disarmed = t, false end
    elseif guard.running then
        local reason = shouldBlock(veh, t, driving)
        if reason and registerBlock(t) then
            restore(veh)
            running = true
            Utils.NotifyOnce('engine_' .. reason, MESSAGES[reason](), 'error', 2500)
            Utils.Log('engine guard: رجّعنا الموتر —', reason)
        end
    end
    guard.running = running
    guard.wasDriving = driving
    return running
end

CreateThread(function()
    if not Cfg.Enabled and not Keep.Enabled then return end

    while true do
        local sleep = 500
        local ped   = cache.ped
        local veh   = cache.vehicle
        local t     = GetGameTimer()
        local driving = veh and GetPedInVehicleSeat(veh, -1) == ped or false

        local target = nil
        if driving then
            target = veh
        elseif not veh and guard.veh ~= 0 and DoesEntityExist(guard.veh)
            and GetPedInVehicleSeat(guard.veh, -1) == 0
            and #(GetEntityCoords(ped) - GetEntityCoords(guard.veh)) < 40.0 then
            target = guard.veh  -- سيارتك اللي نزلت منها وموترها شغال
        end

        if target then
            if target ~= guard.veh then setGuardVehicle(target, t) end

            if Cfg.Enabled then
                local running = tick(ped, target, t, driving)
                sleep = (driving or running or exitState.pressAt > 0 or t < exitState.applyUntil) and 0 or 250
            else
                if driving and t >= guard.nextKeepFlag then
                    guard.nextKeepFlag = t + 1000
                    applyKeepFlag(target)
                end
                handleExit(ped, target, t, driving)
                guard.wasDriving = driving
                sleep = (driving or exitState.pressAt > 0 or t < exitState.applyUntil) and 0 or 250
            end
        elseif guard.veh ~= 0 then
            setGuardVehicle(0, t)
            guard.wasDriving = false
        end

        Wait(sleep)
    end
end)

----------------------------------------------------------------------
-- /motor — تشغيل / إطفاء (نفس القوانين)
----------------------------------------------------------------------
local function canStart(veh)
    if GetResourceState('qb-vehiclekeys') ~= 'started' then return true end
    local ok, has = pcall(function() return exports['qb-vehiclekeys']:HasKeys(Utils.Plate(veh)) end)
    return ok and has == true
end

local function toggleEngine()
    local ped, veh = cache.ped, cache.vehicle
    if not veh or GetPedInVehicleSeat(veh, -1) ~= ped then
        return Utils.Notify('لازم تكون أنت السواق', 'error')
    end

    if GetIsVehicleEngineRunning(veh) then
        if Cfg.BlockInAir and Utils.IsAircraft(veh) and IsEntityInAir(veh) then
            return Utils.Notify(MESSAGES.air(), 'error')
        end
        if Utils.Speed(veh) >= Cfg.MaxOffSpeed then
            return Utils.Notify(MESSAGES.speed(), 'error')
        end
        guard.allowUntil = GetGameTimer() + 1500
        SetVehicleEngineOn(veh, false, false, true)
        Utils.Notify('طفيت الموتر', 'inform')
    else
        if not IsVehicleDriveable(veh, false) or GetVehicleEngineHealth(veh) <= 0.0 then
            return Utils.Notify('الموتر خربان', 'error')
        end
        if not canStart(veh) then
            return Utils.Notify('ما عندك مفتاح هذي المركبة', 'error')
        end
        SetVehicleEngineOn(veh, true, false, false)
        Utils.Notify('شغلت الموتر', 'success')
    end
end

RegisterCommand(Cfg.Toggle.Command, toggleEngine, false)
if Cfg.Toggle.Key and Cfg.Toggle.Key ~= '' then
    RegisterKeyMapping(Cfg.Toggle.Command, 'تشغيل / إطفاء الموتر', 'keyboard', Cfg.Toggle.Key)
end
TriggerEvent('chat:addSuggestion', '/' .. Cfg.Toggle.Command, 'تشغيل / إطفاء الموتر (لازم السرعة أقل من ' .. Cfg.MaxOffSpeed .. ')')

-- للراديال منيو: TriggerEvent('qb-customscripts-byrko:client:toggleEngine')
AddEventHandler('qb-customscripts-byrko:client:toggleEngine', toggleEngine)

----------------------------------------------------------------------
-- Exports لباقي السكربتات
----------------------------------------------------------------------
-- سكربت يبي يطفي الموتر وهو ماشي (EMP، ميكانيكي، ...) يناديها قبل:
--   exports['qb-customscripts-byrko']:AllowEngineOff(2000)
exports('AllowEngineOff', function(ms)
    guard.allowUntil = GetGameTimer() + (tonumber(ms) or 2000)
end)

-- سكربت يستخدم زر G: يقول "G مستخدم الحين" عشان ما يطفي الموتر
exports('SetGKeyBusy', function(state)
    LocalPlayer.state:set('gKeyBusy', state and true or false, false)
end)

exports('ToggleEngine', toggleEngine)
