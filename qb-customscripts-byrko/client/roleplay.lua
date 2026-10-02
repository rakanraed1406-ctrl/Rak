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
CreateThread(function()
    local air = RP.AntiAirControl
    while true do
        local sleep = 500
        local ped, veh = cache.ped, cache.vehicle

        if RP.NoVehicleRewards and (veh or GetVehiclePedIsTryingToEnter(ped) ~= 0) then
            sleep = 0
            DisablePlayerVehicleRewards(PlayerId())
        end

        if air.Enabled and veh and GetPedInVehicleSeat(veh, -1) == ped
            and not air.IgnoreClasses[GetVehicleClass(veh)] then
            sleep = 0
            local upsideDown = air.BlockFlipBack and math.abs(GetEntityRoll(veh)) > 75.0
            if IsEntityInAir(veh) or upsideDown then
                DisableControlAction(0, 59, true) -- يمين/يسار
                DisableControlAction(0, 60, true) -- قدام/ورا
            end
        end

        Wait(sleep)
    end
end)

----------------------------------------------------------------------
-- الرول وأنت مصوّب + النط المتكرر
-- على أزرار (Key Mapping) بدل لوب كل فريم → وأنت ماشي ما فيه استهلاك
----------------------------------------------------------------------
local aimHeld, jumpBlockUntil, blocking = false, 0, false

local function blockJumpLoop()
    if blocking then return end
    blocking = true
    -- يشتغل بس وأنت مصوّب أو بوقت منع النط، وبعدها يوقف
    CreateThread(function()
        while (aimHeld and RP.NoCombatRoll and cache.weapon) or GetGameTimer() < jumpBlockUntil do
            DisableControlAction(0, 22, true)
            Wait(0)
        end
        blocking = false
    end)
end

if RP.NoCombatRoll then
    RegisterCommand('+rk_aim', function()
        aimHeld = true
        if cache.weapon and not cache.vehicle then blockJumpLoop() end
    end, false)
    RegisterCommand('-rk_aim', function() aimHeld = false end, false)
    RegisterKeyMapping('+rk_aim', 'RP: منع الرول وأنت مصوّب', 'MOUSE_BUTTON', 'MOUSE_RIGHT')
end

if RP.AntiBunnyHop.Enabled then
    local hop, jumps = RP.AntiBunnyHop, {}

    RegisterCommand('+rk_jump', function()
        local ped = cache.ped
        if cache.vehicle or IsPedSwimming(ped) or IsPedClimbing(ped) then return end
        SetTimeout(150, function()
            if not IsPedJumping(cache.ped) then return end
            local t = GetGameTimer()
            jumps[#jumps + 1] = t
            while jumps[1] and t - jumps[1] > hop.Window do table.remove(jumps, 1) end

            if #jumps >= hop.MaxJumps then
                jumps = {}
                jumpBlockUntil = t + hop.BlockTime
                blockJumpLoop()
                if hop.Ragdoll then SetPedToRagdoll(cache.ped, 1500, 1500, 0, false, false, false) end
            end
        end)
    end, false)
    RegisterCommand('-rk_jump', function() end, false)
    RegisterKeyMapping('+rk_jump', 'RP: منع النط المتكرر', 'keyboard', 'SPACE')
end

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
