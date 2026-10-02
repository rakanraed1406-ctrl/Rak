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
-- لوب المشي: الرول وأنت مصوّب + النط المتكرر
----------------------------------------------------------------------
CreateThread(function()
    local hop = RP.AntiBunnyHop
    local jumps, wasJumping, blockUntil = {}, false, 0

    while true do
        local sleep = 250
        local ped = cache.ped

        if not cache.vehicle then
            local t = GetGameTimer()

            if RP.NoCombatRoll and cache.weapon then
                sleep = 0
                if IsPlayerFreeAiming(PlayerId()) or IsControlPressed(0, 25) then
                    DisableControlAction(0, 22, true)
                end
            end

            if hop.Enabled then
                sleep = 0
                if t < blockUntil then
                    DisableControlAction(0, 22, true)
                end

                local jumping = IsPedJumping(ped)
                if jumping and not wasJumping then
                    jumps[#jumps + 1] = t
                    while jumps[1] and t - jumps[1] > hop.Window do table.remove(jumps, 1) end

                    if #jumps >= hop.MaxJumps then
                        jumps, blockUntil = {}, t + hop.BlockTime
                        if hop.Ragdoll then
                            SetPedToRagdoll(ped, 1500, 1500, 0, false, false, false)
                        end
                    end
                end
                wasJumping = jumping
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
