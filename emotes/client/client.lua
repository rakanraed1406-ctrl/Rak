menuState = false -- global: config.lua reads it (isMenuOpened, weapon wheel block)
local jsLoaded = false
local shortcuts = {}

function openMenu(state)
    if state ~= nil then
        menuState = state
    else
        menuState = not menuState
    end

    if not menuState then
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
    else
        SetNuiFocus(true, true)
        SetNuiFocusKeepInput(false)
    end

    SendNUIMessage({
        action = "open",
        state = menuState
    })
end

RegisterNUICallback("close", function(data, cb)
    openMenu(false)
    cb("ok")
end)

RegisterNUICallback("forceClose", function(data, cb)
    openMenu(false)
    cb("ok")
end)

RegisterNUICallback("toggleKeepInput", function(data, cb)
    -- Always block game input while emote menu is open
    SetNuiFocusKeepInput(false)
    cb("ok")
end)

RegisterNUICallback("jsLoaded", function(data, cb)
    jsLoaded = true
    cb("ok")
end)

RegisterNUICallback("stopAnim", function(data, cb)
    onEmoteCancel()
    cb("ok")
end)

RegisterNUICallback("onAnimClicked", function(data, cb)
    if data and data.animation then
        onAnimTriggered(data.animation)
    end
    cb("ok")
end)

RegisterNUICallback("getShortcuts", function(data, cb)
    if data and data.shortcuts then
        shortcuts = data.shortcuts
    end
    cb("ok")
end)

-- right click on a tile = invite the closest player to a shared emote
RegisterNUICallback("sendAnimationInvite", function(data, cb)
    cb("ok")
    local a = data and data.animation
    if not a or not a.id then return end
    for _, anim in ipairs(Config.AllAnimations or {}) do
        if anim.id == a.id then
            if anim.sender then return SendSharedInvite(anim) end
            return Notify("Right click is for shared emotes (Shared tab)", "error")
        end
    end
end)

RegisterNUICallback("animPos", function(data, cb)
    cb("ok")
end)

RegisterNUICallback("getSequences", function(data, cb)
    cb("ok")
end)

CreateThread(function()
    local function getAnimationList()
        local file = LoadResourceFile(GetCurrentResourceName(), "animations/AnimationList.json")
        if not file or file == "" then
            return {}
        end
        return json.decode(file) or {}
    end

    while not jsLoaded do
        Wait(100)
    end

    Config = Config or {}
    Config.AllAnimations = {}

    local categoryMap = {
        ["pd"] = "police",
        ["Police"] = "police",
        ["General"] = "emotes",
        ["Dances"] = "dances",
        ["Expressions"] = "expressions",
        ["Customs"] = "custom",
        ["Emotes"] = "emotes",
        ["Walks"] = "walks",
        ["PropEmotes"] = "propemotes",
        ["newemote"] = "newemote",
        ["synced"] = "shared"
    }

    if Config.Animations then
        for animGroupKey, animList in pairs(Config.Animations) do
            if type(animList) == "table" then
                for index, animation in pairs(animList) do
                    if type(animation) == "table" then
                        if not animation.category or animation.category == "" then
                            animation.category = animGroupKey
                        end

                        if categoryMap[animation.category] then
                            animation.category = categoryMap[animation.category]
                        end

                        if not animation.label and animation.category == "dances" then
                            animation.label = string.format("Dance %s", index)
                        end
                        if not animation.id then
                            animation.id = string.format("%s_%s", animation.category or "anim", index)
                            if animation.category == "walks" then
                                animation.gif = string.format("%s.webp", animation.id)
                            end
                        end
                        table.insert(Config.AllAnimations, animation)
                    end
                end
            end
        end
    end

    if Config.CustomEmotes then
        local customList = getAnimationList()
        if type(customList) == "table" then
            for groupKey, group in pairs(customList) do
                local defaultCat = categoryMap[groupKey] or tostring(groupKey):lower()
                if type(group) == "table" then
                    for animId, animation in pairs(group) do
                        if type(animation) == "table" then
                            if not animation.id or animation.id == "" then
                                animation.id = tostring(animId)
                            end
                            if not animation.category or animation.category == "" then
                                animation.category = defaultCat
                            end

                            if categoryMap[animation.category] then
                                animation.category = categoryMap[animation.category]
                            end

                            table.insert(Config.AllAnimations, animation)
                        end
                    end
                end
            end
        end
    end

    -- give duplicate ids a unique name (the lists contain some twice)
    local seen = {}
    for _, a in ipairs(Config.AllAnimations) do
        if a.id then
            local base, n = a.id, 1
            while seen[a.id] do n = n + 1; a.id = base .. "_" .. n end
            seen[a.id] = true
        end
    end

    SendNUIMessage({
        action = "load",
        animations = Config.AllAnimations,
        categories = Config.Categories or {},
        locales = Locales and Locales[Config.Language] or {}
    })
end)

CreateThread(function()
    local shiftPressed = false
    RegisterKeyMapping("+emote_shortcut", "Emote Shortcut Bind", "keyboard", "LSHIFT")
    RegisterCommand("+emote_shortcut", function()
        shiftPressed = true
    end, false)
    RegisterCommand("-emote_shortcut", function()
        shiftPressed = false
    end, false)

    for i = 1, 7 do
        RegisterCommand("emote_shortcut_" .. i, function(source, args)
            if not shiftPressed then return end

            local shortcut = shortcuts[i]
            if shortcut and next(shortcut) and shortcut.id then
                for _, animation in ipairs(Config.AllAnimations or {}) do
                    if animation.id == shortcut.id then
                        return onAnimTriggered(animation)
                    end
                end
            end
        end, false)

        RegisterKeyMapping("emote_shortcut_" .. i, "Emote Shortcut " .. i, "keyboard", tostring(i))
    end
end)

-- Reset & Fix NUI Command
RegisterCommand("fixnui", function()
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    menuState = false
    SendNUIMessage({ action = "open", state = false })
    local ped = cache and cache.ped or PlayerPedId()
    FreezeEntityPosition(ped, false)
    if lib and lib.notify then
        lib.notify({ type = "success", description = "NUI focus and controls reset!" })
    end
end, false)

RegisterCommand("e", function(source, args)
    if not args or not args[1] then
        openMenu()
        return
    end
    local name = args[1]
    if name == "c" or name == "cancel" then
        onEmoteCancel()
    else
        PlayEmoteByName(name)
    end
end, false)

-- menu key: config.lua (Config.OpenKey)
