--[[═════════════════════════════════════════════════════════════════════
    أنظمة تساعد على الرول بلاي وتحل مشاكل متكررة (كل وحدة تنطفي من الكونفيق)
═════════════════════════════════════════════════════════════════════════]]

local RP = Config.Roleplay

----------------------------------------------------------------------
-- فلاقات البيد (تنعاد كل ما تغير السكن أو ركبت سيارة)
----------------------------------------------------------------------
local function applyPedFlags(ped)
    ped = ped or cache.ped
    if RP.SeatShuffle.Enabled then SetPedConfigFlag(ped, 184, true) end  -- ما ينتقل لكرسي السواق لحاله
    if RP.NoAutoHelmet then SetPedConfigFlag(ped, 35, false) end         -- ما يلبس خوذة تلقائي
end

lib.onCache('ped', applyPedFlags)
lib.onCache('vehicle', function(veh) if veh then applyPedFlags() end end)
CreateThread(function() Wait(1000) applyPedFlags() end)

----------------------------------------------------------------------
-- /shuff — تنتقل لكرسي السواق
----------------------------------------------------------------------
if RP.SeatShuffle.Enabled then
    RegisterCommand(RP.SeatShuffle.Command, function()
        local ped, veh = cache.ped, cache.vehicle
        if not veh then return end
        if GetPedInVehicleSeat(veh, 0) ~= ped then
            return Utils.Notify('لازم تكون جالس جنب السواق', 'error')
        end
        if not IsVehicleSeatFree(veh, -1) then
            return Utils.Notify('كرسي السواق مو فاضي', 'error')
        end

        SetPedConfigFlag(ped, 184, false)
        TaskShuffleToNextVehicleSeat(ped, veh)
        CreateThread(function()
            local deadline = GetGameTimer() + 4000
            while GetGameTimer() < deadline and GetPedInVehicleSeat(veh, -1) ~= ped do Wait(100) end
            SetPedConfigFlag(cache.ped, 184, true)
        end)
    end, false)
    TriggerEvent('chat:addSuggestion', '/' .. RP.SeatShuffle.Command, 'تنتقل لكرسي السواق')
end

----------------------------------------------------------------------
-- لوب السيارة: أسلحة سيارات الشرطة + التحكم بالجو + القلب
----------------------------------------------------------------------
-- خفيف: كل فريم بس وقت الركوب (السلاح ينعطى وقت الركوب) أو والسيارة طايرة/مقفلبة
local rewardUntil, airClassOk = 0, false
lib.onCache('vehicle', function(veh)
    if veh then
        rewardUntil = GetGameTimer() + 2000
        airClassOk = not RP.AntiAirControl.IgnoreClasses[GetVehicleClass(veh)]
    end
end)

CreateThread(function()
    local air = RP.AntiAirControl
    while true do
        local sleep = 500
        local ped, veh, t = cache.ped, cache.vehicle, GetGameTimer()

        if RP.NoVehicleRewards then
            if not veh then
                sleep = 250
                if GetVehiclePedIsTryingToEnter(ped) ~= 0 then rewardUntil = t + 2000 end
            end
            if t < rewardUntil then
                DisablePlayerVehicleRewards(PlayerId())
                sleep = 0
            end
        end

        if air.Enabled and veh and airClassOk and GetPedInVehicleSeat(veh, -1) == ped then
            if IsEntityInAir(veh) or (air.BlockFlipBack and math.abs(GetEntityRoll(veh)) > 75.0) then
                DisableControlAction(0, 59, true) -- يمين/يسار
                DisableControlAction(0, 60, true) -- قدام/ورا
                sleep = 0
            elseif sleep > 100 then
                sleep = 100
            end
        end

        Wait(sleep)
    end
end)

----------------------------------------------------------------------
-- كاميرا الخمول
----------------------------------------------------------------------
if RP.NoIdleCam then
    CreateThread(function()
        while true do
            InvalidateIdleCam()
            InvalidateVehicleIdleCam()
            Wait(10000)
        end
    end)
end

----------------------------------------------------------------------
-- /stuck — يفك التعليق (أنيميشن معلق / غرض لاصق باليد)
-- ما يشتغل وأنت ميت / مكلبش / محمول / مسحوب (عشان ما ينستغل للهروب)
----------------------------------------------------------------------
if RP.Stuck.Enabled then
    local lastUse = -RP.Stuck.Cooldown * 1000

    RegisterCommand(RP.Stuck.Command, function()
        local ped = cache.ped
        local t = GetGameTimer()

        local left = math.ceil((RP.Stuck.Cooldown * 1000 - (t - lastUse)) / 1000)
        if left > 0 then
            return Utils.Notify(('انتظر %d ثانية'):format(left), 'error')
        end

        local pd = Utils.PlayerData()
        local meta = pd and pd.metadata or {}
        if IsEntityDead(ped) or meta.isdead or meta.inlaststand then
            return Utils.Notify('ما تقدر وأنت طايح', 'error')
        end
        if meta.ishandcuffed or IsPedCuffed(ped) then
            return Utils.Notify('ما تقدر وأنت مكلبش', 'error')
        end
        if IsEntityAttached(ped) then
            return Utils.Notify('ما تقدر وأحد ماسكك أو شايلك', 'error')
        end
        -- عشان ما ينستغل للقومة بعد ما أحد يطيحك (تاكل) أو وأنت طايح/بالباراشوت
        if IsPedRagdoll(ped) or IsPedFalling(ped) or IsPedGettingUp(ped) or IsPedInParachuteFreeFall(ped)
            or GetPedParachuteState(ped) ~= -1 or IsPedSwimmingUnderWater(ped) then
            return Utils.Notify('ما تقدر الحين، انتظر لين توقف', 'error')
        end
        if GetEntitySpeed(ped) > 2.0 then
            return Utils.Notify('وقّف أول', 'error')
        end

        lastUse = t
        ClearPedSecondaryTask(ped)
        if not cache.vehicle then ClearPedTasksImmediately(ped) end

        -- يشيل الأغراض اللاصقة فيك (جوال، كوب، صندوق...) بس اللي حقك
        local weaponObj = GetCurrentPedWeaponEntityIndex(ped)
        for _, obj in ipairs(GetGamePool('CObject')) do
            if obj ~= weaponObj and IsEntityAttachedToEntity(obj, ped) and Utils.Owns(obj) then
                DetachEntity(obj, true, true)
                SetEntityAsMissionEntity(obj, true, true)
                DeleteEntity(obj)
            end
        end

        Utils.Notify('تم فك التعليق', 'success')
    end, false)
    TriggerEvent('chat:addSuggestion', '/' .. RP.Stuck.Command, 'يفك التعليق (أنيميشن أو غرض لاصق)')
end
