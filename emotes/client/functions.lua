currentAnim = nil
playingEmote = false

AnimationDuration = -1
ChosenAnimation = ""
ChosenDict = ""
MostRecentChosenAnimation = ""
MostRecentChosenDict = ""
MovementType = 0
PlayerGender = "male"
PlayerHasProp = false
PlayerParticles = {}
SecondPropEmote = false
PtfxNotif = false
PtfxPrompt = false
PtfxWait = 500
PtfxCanHold = false
PtfxNoProp = false
AnimationThreadStatus = false

local lastEmoteAt = 0
local emoteToken = 0 -- changes every time an emote starts/stops (lets old watchers quit)

function sendNotification(data)
    local text = data and data.text or ""
    local title = data and data.title or "Notification"
    local notifType = data and data.type or "notification"
    local timeout = data and data.timeout or 5
    SendNUIMessage({
        action = "notification",
        data = {
            type = notifType,
            title = title,
            text = text,
            description = data and data.description or "",
            anim = data and data.anim,
            timeout = timeout
        }
    })
end

function loadAnimSet(walkstyle)
    if not walkstyle or walkstyle == "" then return false end
    if HasAnimSetLoaded(walkstyle) then return true end
    local timer = GetGameTimer() + 5000
    RequestAnimSet(walkstyle)
    while not HasAnimSetLoaded(walkstyle) do
        if GetGameTimer() > timer then
            print("Could not load walk style: " .. tostring(walkstyle))
            return false
        end
        RequestAnimSet(walkstyle)
        Wait(10)
    end
    return true
end

function loadAnim(dict)
    if not dict or dict == "" then return false end
    if HasAnimDictLoaded(dict) then return true end
    if not DoesAnimDictExist(dict) then
        print("Animation dictionary does not exist (missing stream file?): " .. tostring(dict))
        return false
    end
    local timer = GetGameTimer() + 5000
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > timer then
            print("Could not load animation dictionary: " .. tostring(dict))
            return false
        end
        RequestAnimDict(dict)
        Wait(10)
    end
    return true
end

-- walk styles / expressions keep their name in "value" (emotes use "anim")
local function animValue(a)
    return a and (a.value or a.anim) or nil
end

function clearProps(ped)
    local targetPed = ped or PlayerPedId()
    TriggerEvent("Dh-animmenu:propattach:destroyProp", targetPed)
    TriggerEvent("Dh-animmenu:propattach:destroyProp2", targetPed)
    TriggerEvent("cylex_animmenuv2:propattach:destroyProp", targetPed)
    TriggerEvent("cylex_animmenuv2:propattach:destroyProp2", targetPed)
    if DestroyAllProps then
        DestroyAllProps()
    end
end

function onEmoteCancel(ped)
    local targetPed = ped or PlayerPedId()
    if not playingEmote then return end
    local was = playingEmote
    emoteToken = emoteToken + 1

    PtfxNotif = false
    PtfxPrompt = false
    Pointing = false

    if LocalPlayer.state.ptfx and PtfxStop then
        PtfxStop()
    end

    if type(was) == "table" and was.scenario then
        ClearPedTasks(targetPed)
        ClearPedTasksImmediately(targetPed)
        ClearAreaOfObjects(GetEntityCoords(targetPed), 2.0, 0)
    elseif type(was) == "table" and was.exit and was.dict and loadAnim(was.dict) then
        -- the emote has its own "put away" animation
        TaskPlayAnim(targetPed, was.dict, was.exit, 8.0, -8.0, -1, 48, 0, false, false, false)
    else
        ClearPedTasks(targetPed)
    end

    clearProps(targetPed)
    TriggerEvent("turnoffsitting")
    TriggerEvent("animation:gotCanceled")
    playingEmote = false
    currentAnim = nil
    AnimationThreadStatus = false
    FreezeEntityPosition(targetPed, false)
end

local function attachProp(name, bone, placement)
    if not name or name == "" then return end
    if not AddPropToPlayer then
        TriggerEvent("Dh-animmenu:propattach:attachItem", name, PlayerPedId())
        return
    end
    if type(placement) == "table" then
        AddPropToPlayer(name, bone or 28422, table.unpack(placement))
    else
        AddPropToPlayer(name, bone or 28422)
    end
end

-- Props stay attached after a non-looping emote finishes -> clean them up.
local function watchEmote(dict, name, token)
    CreateThread(function()
        Wait(600)
        local ped = PlayerPedId()
        while emoteToken == token and playingEmote do
            if not IsEntityPlayingAnim(ped, dict, name, 3) then
                if emoteToken == token then
                    clearProps(ped)
                    playingEmote = false
                    currentAnim = nil
                end
                return
            end
            Wait(400)
        end
    end)
end

function onAnimTriggered(anim, ped)
    if not anim then return end
    local targetPed = ped or PlayerPedId()

    if anim.disabled then
        return print("This emote is disabled for now", anim.id)
    end

    if anim.category == "walks" then
        return onWalk(anim)
    end

    if anim.category == "expressions" then
        return onExpression(anim)
    end

    -- shared emotes need a second player
    if anim.category == "shared" or anim.category == "synced" or anim.sender then
        return SendSharedInvite(anim)
    end

    local now = GetGameTimer()
    if Config.AfterCooldown and Config.AfterCooldown > 0 and now - lastEmoteAt < Config.AfterCooldown then return end
    lastEmoteAt = now

    if IsPedInAnyVehicle(targetPed, false) and not Config.AnimOnVehicle then
        return Notify("You cannot use emotes in a vehicle", "error")
    end
    if IsPedSwimming(targetPed) or IsPedFalling(targetPed) or IsPedRagdoll(targetPed) or IsEntityDead(targetPed) then
        return
    end

    if playingEmote and not Config.MultipleAnim then
        return Notify("Cancel your current emote first (X)", "error")
    end

    -- switching emote: drop the old props / scenario first
    if playingEmote then
        clearProps(targetPed)
        if type(playingEmote) == "table" and playingEmote.scenario then
            ClearPedTasksImmediately(targetPed)
        end
    end
    emoteToken = emoteToken + 1
    local token = emoteToken

    if anim.scenario then
        ClearPedTasks(targetPed)
        TaskStartScenarioInPlace(targetPed, anim.scenario, 0, true)
        playingEmote = anim
        currentAnim = anim
        return true
    end

    local animSettings = anim.animSettings or anim.AnimationOptions
    local animDict = anim.dict or (anim.AnimationOptions and anim.AnimationOptions.animDict)
    local animName = anim.anim or (anim.AnimationOptions and anim.AnimationOptions.animName)
    if not animDict or not animName then return end
    if not loadAnim(animDict) then
        return Notify("This emote's animation is missing on the server", "error")
    end

    local flag = 0
    if animSettings then
        local loop = animSettings.EmoteLoop or animSettings.loop or animSettings.Loop
        local move = animSettings.EmoteMoving or animSettings.move or animSettings.Move
        if loop and move then flag = 51
        elseif loop then flag = 1
        elseif move then flag = 51
        elseif animSettings.EmoteStuck then flag = 50 end
    end
    if anim.flag then flag = anim.flag end

    local cat = anim.category
    if flag == 0 and (cat == "dances" or cat == "custom" or cat == "police" or cat == "pd" or cat == "newemote") then
        flag = 1
    end

    local duration = anim.duration or (animSettings and animSettings.EmoteDuration) or -1
    TaskPlayAnim(targetPed, animDict, animName, 8.0, -8.0, duration, flag, 0, false, false, false)
    RemoveAnimDict(animDict)
    playingEmote = anim
    currentAnim = anim

    -- props: prop / prop2 (emotes.lua) or Prop / SecondProp (AnimationList.json)
    attachProp(anim.prop or (animSettings and animSettings.Prop),
        anim.propBone or (animSettings and animSettings.PropBone),
        anim.propPlacement or (animSettings and animSettings.PropPlacement))
    attachProp(anim.prop2 or anim.secondProp or (animSettings and animSettings.SecondProp),
        anim.secondPropBone or (animSettings and animSettings.SecondPropBone),
        anim.secondPropPlacement or (animSettings and animSettings.SecondPropPlacement))

    -- non-looping emotes: clean up when they finish
    if flag % 2 == 0 then watchEmote(animDict, animName, token) end
    return true
end

-- ---------------------------------------------------------------------------
-- Walk styles & expressions (+ keep them after relog / revive)
-- ---------------------------------------------------------------------------
function onWalk(animation)
    local style = animValue(animation)
    if not style then return end
    local ped = PlayerPedId()
    if loadAnimSet(style) then
        SetPedMovementClipset(ped, style, 0.2)
        RemoveAnimSet(style)
        if Config.PersistentWalkStyle then
            SetResourceKvp("walkstyle", style)
        end
        return true
    end
    Notify("This walk style is missing on the server", "error")
end

function onWalkCancel()
    local ped = PlayerPedId()
    ResetPedMovementClipset(ped, 0.2)
    if Config.PersistentWalkStyle then
        DeleteResourceKvp("walkstyle")
    end
end

function onExpression(animation)
    local mood = animValue(animation)
    if not mood then return end
    local ped = PlayerPedId()
    SetFacialIdleAnimOverride(ped, mood, 0)
    if Config.PersistentExpressions then
        SetResourceKvp("expression", mood)
    end
    return true
end

function onExpressionCancel()
    local ped = PlayerPedId()
    ClearFacialIdleAnimOverride(ped)
    if Config.PersistentExpressions then
        DeleteResourceKvp("expression")
    end
end

local function restoreWalkAndMood()
    local ped = PlayerPedId()
    if Config.PersistentWalkStyle then
        local style = GetResourceKvpString("walkstyle")
        if style and style ~= "" and loadAnimSet(style) then
            SetPedMovementClipset(ped, style, 0.2)
        end
    end
    if Config.PersistentExpressions then
        local mood = GetResourceKvpString("expression")
        if mood and mood ~= "" then SetFacialIdleAnimOverride(ped, mood, 0) end
    end
end

for _, ev in ipairs(Config.SpawnEvents or {}) do
    AddEventHandler(ev, function()
        SetTimeout(1500, restoreWalkAndMood)
    end)
end
CreateThread(function()
    Wait(3000)
    restoreWalkAndMood() -- resource restart / already spawned
end)

-- ---------------------------------------------------------------------------
-- Shared emotes (handshake, hug, ...): invite the closest player, Y / M to answer
-- ---------------------------------------------------------------------------
local pendingInvite = nil -- { from = serverId, id = animId, expires = gameTimer }

local function findAnimById(id)
    for _, a in ipairs(Config.AllAnimations or {}) do
        if a.id == id then return a end
    end
end

local function closestPlayer(maxDist)
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local best, bestD
    for _, pl in ipairs(GetActivePlayers()) do
        local other = GetPlayerPed(pl)
        if other ~= ped and DoesEntityExist(other) then
            local d = #(pos - GetEntityCoords(other))
            if d <= maxDist and (not bestD or d < bestD) then best, bestD = pl, d end
        end
    end
    return best
end

function SendSharedInvite(anim)
    if not anim or not anim.id then return end
    local target = closestPlayer(3.0)
    if not target then
        return Notify("No player close to you", "error")
    end
    TriggerServerEvent("cylex_animmenuv2:server:sendAnimationInvite", GetPlayerServerId(target), anim.id)
    Notify(("Invite sent: %s"):format(anim.label or anim.id), "primary")
end

RegisterNetEvent("cylex_animmenuv2:client:receiveAnimationInvite", function(from, animId)
    local anim = findAnimById(animId)
    if not anim then return end
    pendingInvite = { from = from, id = animId, expires = GetGameTimer() + 10000 }
    local msg = ("Player [%s] wants to do: %s — Y accept / M refuse"):format(tostring(from), anim.label or animId)
    Notify(msg, "primary")
    sendNotification({ timeout = 10, title = "Shared emote", text = msg, type = "invite", anim = anim })

    CreateThread(function()
        local me = pendingInvite
        while pendingInvite == me and GetGameTimer() < me.expires do
            if IsControlJustPressed(0, Config.AcceptBind or 246) then
                pendingInvite = nil
                TriggerServerEvent("cylex_animmenuv2:server:acceptAnimationInvite", me.from, me.id)
                return
            elseif IsControlJustPressed(0, Config.RefuseBind or 244) then
                pendingInvite = nil
                Notify("Invite refused", "error")
                return
            end
            Wait(0)
        end
        if pendingInvite == me then pendingInvite = nil end
    end)
end)

RegisterNetEvent("cylex_animmenuv2:client:startSyncedAnimation", function(partner, animId, role)
    local anim = findAnimById(animId)
    if not anim or not anim.sender or not anim.receiver then return end
    local mine = role == "receiver" and anim.receiver or anim.sender
    local ped = PlayerPedId()

    -- the receiver steps in front of the sender, facing them
    if role == "receiver" then
        local pPed = GetPlayerPed(GetPlayerFromServerId(partner))
        if pPed and pPed ~= 0 and DoesEntityExist(pPed) then
            local front = GetOffsetFromEntityInWorldCoords(pPed, 0.0, 1.0, 0.0)
            SetEntityCoordsNoOffset(ped, front.x, front.y, front.z, false, false, false)
            SetEntityHeading(ped, (GetEntityHeading(pPed) + 180.0) % 360.0)
        end
    end

    if playingEmote then clearProps(ped) end
    emoteToken = emoteToken + 1
    if not loadAnim(mine.dict) then return end
    local flag = anim.flag or 0
    TaskPlayAnim(ped, mine.dict, mine.anim, 8.0, -8.0, -1, flag, 0, false, false, false)
    RemoveAnimDict(mine.dict)
    playingEmote = { dict = mine.dict, anim = mine.anim, label = anim.label, id = anim.id }
    currentAnim = playingEmote
    if flag % 2 == 0 then watchEmote(mine.dict, mine.anim, emoteToken) end
end)

-- ---------------------------------------------------------------------------
-- Global exports & compatibility wrappers
-- ---------------------------------------------------------------------------
local function findEmoteByName(name)
    if not name then return nil end
    local query = string.gsub(string.lower(tostring(name)), "^%s*(.-)%s*$", "%1")
    if query == "" then return nil end
    for _, anim in ipairs(Config.AllAnimations or {}) do
        if anim.id and string.lower(anim.id) == query then return anim end
    end
    for _, anim in ipairs(Config.AllAnimations or {}) do
        if anim.label and string.lower(anim.label) == query then return anim end
        if anim.anim and string.lower(anim.anim) == query then return anim end
    end
    return nil
end

function PlayEmoteByName(name)
    if not name then return false end
    local q = string.gsub(string.lower(tostring(name)), "^%s*(.-)%s*$", "%1")
    if q == "c" or q == "cancel" then
        onEmoteCancel()
        return true
    end
    local anim = findEmoteByName(q)
    if anim then
        onAnimTriggered(anim)
        return true
    end
    Notify(("Emote not found: %s"):format(q), "error")
    return false
end

exports("playEmoteByCommand", PlayEmoteByName)
exports("playEmote", PlayEmoteByName)
exports("EmoteCommandStart", PlayEmoteByName)
exports("OnEmotePlay", PlayEmoteByName)

exports("cancelEmote", onEmoteCancel)
exports("EmoteCancel", onEmoteCancel)
exports("CancelEmote", onEmoteCancel)

exports("openMenu", function(state) openMenu(state) end)
exports("toggleMenu", function() openMenu() end)
exports("ToggleMenu", function() openMenu() end)
exports("ToggleEmoteMenu", function() openMenu() end)
