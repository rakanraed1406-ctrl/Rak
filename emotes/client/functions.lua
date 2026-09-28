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
    if HasAnimSetLoaded(walkstyle) then return true end
    local timer = GetGameTimer() + 5000
    RequestAnimSet(walkstyle)
    while not HasAnimSetLoaded(walkstyle) do
        if GetGameTimer() > timer then
            return false, print("Could not load walk style: " .. tostring(walkstyle))
        end
        RequestAnimSet(walkstyle)
        Wait(10)
    end
    return true
end

function loadAnim(dict)
    if not dict or dict == "" then return false end
    if HasAnimDictLoaded(dict) then return true end
    local timer = GetGameTimer() + 5000
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > timer then
            return false, print("Could not load animation dictionary: " .. tostring(dict))
        end
        RequestAnimDict(dict)
        Wait(10)
    end
    return true
end

function clearProps(ped)
    local targetPed = ped or PlayerPedId()
    DetachEntity(targetPed, true, false)
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

    PtfxNotif = false
    PtfxPrompt = false
    Pointing = false

    if LocalPlayer.state.ptfx and PtfxStop then
        PtfxStop()
    end

    if playingEmote and type(playingEmote) == "table" and playingEmote.scenario then
        ClearPedTasks(targetPed)
        TaskStartScenarioInPlace(targetPed, playingEmote.scenario, 0, true)
        Wait(0)
        ClearPedTasksImmediately(targetPed)
        ClearPedTasks(targetPed)
        DetachEntity(targetPed, true, false)
        ClearAreaOfObjects(GetEntityCoords(targetPed), 2.0, 0)
    end

    ClearPedTasks(targetPed)
    clearProps(targetPed)
    TriggerEvent("turnoffsitting")
    TriggerEvent("animation:gotCanceled")
    playingEmote = false
    AnimationThreadStatus = false
    FreezeEntityPosition(targetPed, false)
end

function onAnimTriggered(anim, ped)
    if not anim then return end
    local targetPed = ped or PlayerPedId()

    if anim.disabled then
        return print("This emote is disabled for now", anim)
    end

    if anim.category == "walks" then
        return onWalk(anim)
    end

    if anim.category == "expressions" then
        return onExpression(anim)
    end

    if not Config.MultipleAnim and playingEmote then
        return print("Multiple emotes disabled", anim)
    end

    if anim.scenario then
        ClearPedTasks(targetPed)
        TaskStartScenarioInPlace(targetPed, anim.scenario, 0, true)
        playingEmote = anim
        return true
    end

    local animDict = anim.dict or (anim.AnimationOptions and anim.AnimationOptions.animDict)
    local animName = anim.anim or (anim.AnimationOptions and anim.AnimationOptions.animName)

    if animDict and animName then
        if loadAnim(animDict) then
            local flag = 0
            local animSettings = anim.animSettings or anim.AnimationOptions

            if animSettings then
                if animSettings.EmoteLoop or animSettings.loop or animSettings.Loop then
                    flag = 1
                    if animSettings.EmoteMoving or animSettings.move or animSettings.Move then
                        flag = 51
                    end
                elseif animSettings.EmoteMoving or animSettings.move or animSettings.Move then
                    flag = 51
                elseif animSettings.EmoteStuck then
                    flag = 50
                end
            end

            if anim.flag then
                flag = anim.flag
            end

            local cat = anim.category
            if flag == 0 and (cat == "dances" or cat == "custom" or cat == "police" or cat == "pd") then
                flag = 1
            end

            local duration = anim.duration or (animSettings and animSettings.EmoteDuration) or -1
            TaskPlayAnim(targetPed, animDict, animName, 8.0, -8.0, duration, flag, 0, false, false, false)
            playingEmote = anim
            currentAnim = anim

            local propName = anim.prop or (animSettings and animSettings.Prop)
            local propBone = anim.propBone or (animSettings and animSettings.PropBone)
            local propPlacement = anim.propPlacement or (animSettings and animSettings.PropPlacement)

            if propName then
                if AddPropToPlayer then
                    if type(propPlacement) == "table" then
                        AddPropToPlayer(propName, propBone or 28422, table.unpack(propPlacement))
                    else
                        AddPropToPlayer(propName, propBone or 28422)
                    end
                else
                    TriggerEvent("Dh-animmenu:propattach:attachItem", propName, targetPed)
                end
            end

            local prop2Name = anim.secondProp or (animSettings and animSettings.SecondProp)
            local prop2Bone = anim.secondPropBone or (animSettings and animSettings.SecondPropBone)
            local prop2Placement = anim.secondPropPlacement or (animSettings and animSettings.SecondPropPlacement)

            if prop2Name then
                if AddPropToPlayer then
                    if type(prop2Placement) == "table" then
                        AddPropToPlayer(prop2Name, prop2Bone or 28422, table.unpack(prop2Placement))
                    else
                        AddPropToPlayer(prop2Name, prop2Bone or 28422)
                    end
                else
                    TriggerEvent("Dh-animmenu:propattach:attachItem2", prop2Name, targetPed)
                end
            end
        end
    end
end

function onWalk(animation)
    if not animation or not animation.anim then return end
    local ped = PlayerPedId()
    if loadAnimSet(animation.anim) then
        SetPedMovementClipset(ped, animation.anim, 0.2)
        if Config.PersistentWalkStyle then
            SetResourceKvp("walkstyle", animation.anim)
        end
    end
end

function onWalkCancel()
    local ped = PlayerPedId()
    ResetPedMovementClipset(ped, 0.2)
    if Config.PersistentWalkStyle then
        DeleteResourceKvp("walkstyle")
    end
end

function onExpression(animation)
    if not animation or not animation.anim then return end
    local ped = PlayerPedId()
    SetFacialIdleAnimOverride(ped, animation.anim, 0)
    if Config.PersistentExpressions then
        SetResourceKvp("expression", animation.anim)
    end
end

function onExpressionCancel()
    local ped = PlayerPedId()
    ClearFacialIdleAnimOverride(ped)
    if Config.PersistentExpressions then
        DeleteResourceKvp("expression")
    end
end


-- Global Exports & Compatibility Wrappers
local function findEmoteByName(name)
    if not name then return nil end
    local query = string.gsub(string.lower(tostring(name)), "^%s*(.-)%s*$", "%1")
    if query == "" then return nil end
    for _, anim in ipairs(Config.AllAnimations or {}) do
        if anim.id and string.lower(anim.id) == query then return anim end
        if anim.label and string.lower(anim.label) == query then return anim end
        if anim.anim and string.lower(anim.anim) == query then return anim end
        if anim.dict and string.lower(anim.dict) == query then return anim end
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
