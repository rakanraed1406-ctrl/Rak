-- Treatment API — lets field tools (qb-ems-tools) change this player's injuries
-- through qb-hospital's own state, so bleeding / limbs / painkillers / last stand
-- stay in one place and everything (tablet, vitals, death screen) keeps agreeing.
--
--   server: TriggerClientEvent('hospital:client:ApplyTreatment', patientSrc, kind, data)
--   kinds : bleed {amount}, stopbleed, limbs {parts?, max?}, painkiller {doses},
--           health {amount}, stabilize {seconds, max}, oxygen {health}, minor, sethealth {health}

local LIMB_GROUPS = {
    legs = { 'LLEG', 'RLEG', 'LFOOT', 'RFOOT', 'LOWER_BODY' },
    arms = { 'LARM', 'RARM', 'LHAND', 'RHAND', 'LFINGER', 'RFINGER' },
    spine = { 'SPINE', 'NECK' },
}

local function RefreshMovement()
    local ped = PlayerPedId()
    for _, part in pairs(BodyParts) do
        if part.causeLimp and part.isDamaged then return end
    end
    ResetPedMovementClipset(ped, 0.0)
    SetPedMoveRateOverride(ped, 1.0)
    SetPlayerSprint(PlayerId(), true)
end

local function HealLimbs(parts, maxSeverity)
    maxSeverity = maxSeverity or 4
    local list = {}
    if type(parts) == 'string' and LIMB_GROUPS[parts] then
        list = LIMB_GROUPS[parts]
    elseif type(parts) == 'table' then
        for _, p in ipairs(parts) do
            if LIMB_GROUPS[p] then
                for _, q in ipairs(LIMB_GROUPS[p]) do list[#list + 1] = q end
            else
                list[#list + 1] = p
            end
        end
    else
        for name in pairs(BodyParts) do list[#list + 1] = name end
    end

    local healed = 0
    for _, name in ipairs(list) do
        local part = BodyParts[name]
        if part and part.isDamaged and part.severity <= maxSeverity then
            part.isDamaged = false
            part.severity = 0
            healed = healed + 1
        end
    end
    for i = #injured, 1, -1 do
        local part = BodyParts[injured[i].part]
        if part and not part.isDamaged then table.remove(injured, i) end
    end
    RefreshMovement()
    return healed
end

local Treatments = {
    bleed = function(data) RemoveBleed(tonumber(data.amount) or 1) end,
    stopbleed = function() RemoveBleed(4) end,
    limbs = function(data) HealLimbs(data.parts, data.max) end,
    minor = function() ResetPartial() end,
    painkiller = function(data) AddPainkillerDose(tonumber(data.doses) or 1) end,
    health = function(data) AddHealth(tonumber(data.amount) or 10) end,
    oxygen = function(data)
        fadeOutTimer, blackoutTimer = 0, 0
        if IsScreenFadedOut() and not isDead then DoScreenFadeIn(500) end
        AddHealth(tonumber(data.health) or 15)
    end,
    -- woke up weak (CPR): after the revive set the health lower
    sethealth = function(data)
        local health = math.max(101, math.min(200, tonumber(data.health) or 150))
        SetTimeout(600, function()
            local ped = PlayerPedId()
            if not isDead and not InLaststand then SetEntityHealth(ped, health) end
        end)
    end,
    stabilize = function(data)
        if not InLaststand or isDead then return end
        local cap = tonumber(data.max) or 240
        LaststandTime = math.min(cap, math.max(LaststandTime, 0) + (tonumber(data.seconds) or 60))
    end,
}

RegisterNetEvent('hospital:client:ApplyTreatment', function(kind, data)
    local fn = Treatments[kind]
    if not fn then return end
    data = type(data) == 'table' and data or {}
    fn(data)
    SyncInjuries()
    if data.notify then QBCore.Functions.Notify(data.notify, 'success', 4000) end
end)

-- Timer pause while someone treats you (Config.TreatmentPause).
-- BeingTreated is read by the bleed-out timer (laststand.lua) and the death timer (dead.lua).
BeingTreated = false
local treatedUntil = 0

-- other resources (CPR / first aid scripts) can say "this patient is being treated"
RegisterNetEvent('hospital:client:SetBeingTreated', function(seconds)
    seconds = math.max(0, math.min(60, tonumber(seconds) or 0))
    treatedUntil = GetGameTimer() + seconds * 1000
end)

local pauseCfg = Config.TreatmentPause or {}
local treatAnims = {}
for _, a in pairs(Config.HealAnims or {}) do treatAnims[#treatAnims + 1] = { a.dict, a.anim } end
for _, a in ipairs(pauseCfg.Anims or {}) do treatAnims[#treatAnims + 1] = a end

local function SomeoneTreatingMe()
    local myCoords = GetEntityCoords(PlayerPedId())
    local maxDist = pauseCfg.Distance or 2.5
    local me = PlayerId()
    for _, player in ipairs(GetActivePlayers()) do
        if player ~= me then
            local ped = GetPlayerPed(player)
            if ped ~= 0 and #(GetEntityCoords(ped) - myCoords) <= maxDist then
                for _, a in ipairs(treatAnims) do
                    if IsEntityPlayingAnim(ped, a[1], a[2], 3) then return true end
                end
                for _, scenario in ipairs(pauseCfg.Scenarios or {}) do
                    if IsPedUsingScenario(ped, scenario) then return true end
                end
            end
        end
    end
    return false
end

CreateThread(function()
    local pausedMs, last = 0, GetGameTimer()
    while true do
        local now = GetGameTimer()
        if pauseCfg.Enabled ~= false and (isDead or InLaststand) and not isInHospitalBed then
            local treated = now < treatedUntil or SomeoneTreatingMe()
            if treated then pausedMs = pausedMs + (now - last) end
            -- capped per down, so a friend can't keep you alive forever by standing over you
            BeingTreated = treated and pausedMs < (pauseCfg.MaxPause or 180) * 1000
        else
            BeingTreated = false
            if not (isDead or InLaststand) then pausedMs, treatedUntil = 0, 0 end
        end
        last = now
        Wait((isDead or InLaststand) and 500 or 1000)
    end
end)

-- Local state for other resources on this client.
exports('GetLocalState', function()
    return {
        dead = isDead == true,
        laststand = InLaststand == true,
        laststandTime = LaststandTime,
        bleeding = tonumber(isBleeding) or 0,
        painkillers = onPainKillers == true,
        inBed = isInHospitalBed == true,
        beingTreated = BeingTreated == true,
    }
end)
