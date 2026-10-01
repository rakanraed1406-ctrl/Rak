local QBCore = exports['qb-core']:GetCoreObject()
local L = GetLocale()

local PREFS_KVP = 'jtpause:prefs'
local CONTROL_PAUSE = 199        -- P / controller start
local CONTROL_PAUSE_ALT = 200    -- ESC

local state = {
    open = false,
    loggedIn = false,
    disabled = false,
    nativeActive = false,
    blurActive = false,
    initSent = false,
    fetching = false,
    fetchStarted = 0,
    revision = -1,
    serverData = nil,
    session = 0,
}

-- ════════════════════════════════════════════════════════════
--  Preferences (one KVP entry, written at most once per second)
-- ════════════════════════════════════════════════════════════
local prefs = {}
do
    local raw = GetResourceKvpString(PREFS_KVP)
    if raw then
        local ok, decoded = pcall(json.decode, raw)
        if ok and type(decoded) == 'table' then prefs = decoded end
    end
end

local saveQueued = false
local function SavePrefs()
    if saveQueued then return end
    saveQueued = true
    SetTimeout(1000, function()
        saveQueued = false
        SetResourceKvp(PREFS_KVP, json.encode(prefs))
    end)
end

local function Pref(key, default)
    if prefs[key] == nil then return default end
    return prefs[key]
end

-- ════════════════════════════════════════════════════════════
--  Audio
-- ════════════════════════════════════════════════════════════
local PROFILE_SFX, PROFILE_MUSIC_MP = 300, 306

local function ReadProfileVolume(setting)
    local value = GetProfileSetting(setting)
    if type(value) == 'number' and value >= 0 and value <= 10 then
        return math.floor(value * 10 + 0.5)
    end
end

local function ApplyVolume(kind, volume)
    local level = math.floor(math.max(0, math.min(100, volume)) / 10 + 0.5)
    if kind == 'sfx' then
        ExecuteCommand(('profile_sfxVolume %d'):format(level))
    elseif kind == 'music' then
        ExecuteCommand(('profile_musicVolumeInMp %d'):format(level))
    end
end

local ToggleHandlers = {
    radio = function(on) SetFrontendRadioActive(on) end,
    scanner = function(on) SetAudioFlag('PoliceScannerDisabled', not on) end,
    sirens = function(on) DistantCopCarSirens(on) end,
    flightMusic = function(on) SetAudioFlag('DisableFlightMusic', not on) end,
    wantedMusic = function(on) SetAudioFlag('WantedMusicDisabled', not on) end,
}

-- Only settings the player changed are applied, so other resources keep control otherwise.
local function ApplySavedAudio()
    for key, handler in pairs(ToggleHandlers) do
        local value = prefs['audio_' .. key]
        if value ~= nil then handler(value == true) end
    end
    if prefs.sfx and ReadProfileVolume(PROFILE_SFX) ~= prefs.sfx then ApplyVolume('sfx', prefs.sfx) end
    if prefs.music and ReadProfileVolume(PROFILE_MUSIC_MP) ~= prefs.music then ApplyVolume('music', prefs.music) end
end

local function GetAudioToggles()
    local toggles = {}
    for key in pairs(ToggleHandlers) do
        toggles[key] = Pref('audio_' .. key, Config.AudioDefaults[key] ~= false)
    end
    return toggles
end

local function GetAudioState()
    return {
        sfx = prefs.sfx or ReadProfileVolume(PROFILE_SFX) or 100,
        music = prefs.music or ReadProfileVolume(PROFILE_MUSIC_MP) or 100,
        toggles = GetAudioToggles(),
    }
end

local function GetUiPrefs()
    return {
        sounds = Pref('ui_sounds', Config.Sounds.enabled ~= false),
        blur = Pref('ui_blur', Config.BackgroundBlur ~= false),
        reducedMotion = Pref('ui_reducedMotion', false),
        seenUpdate = prefs.seenUpdate or '',
    }
end

-- ════════════════════════════════════════════════════════════
--  NUI data
-- ════════════════════════════════════════════════════════════
local function BuildInit()
    local robberies = {}
    for _, robbery in ipairs(Config.Robberies) do
        robberies[#robberies + 1] = {
            id = robbery.id,
            icon = robbery.icon or 'store',
            minPolice = tonumber(robbery.minPolice) or 0,
            label = LocalizeValue(robbery.label),
            description = LocalizeValue(robbery.description),
        }
    end

    local strings = {}
    for key, value in pairs(Locales['en']) do strings[key] = L[key] or value end

    return {
        action = 'init',
        locale = Config.Locale,
        strings = strings,
        brand = {
            name = Config.ServerName,
            logo = Config.Logo,
            logoHeight = Config.LogoHeight,
            accent = Config.AccentColor,
        },
        clock = Config.Clock,
        robberies = robberies,
        showRequirement = Config.ShowRequirement,
        playerCard = Config.PlayerCard,
        links = Config.Links,
        sounds = { volume = Config.Sounds.volume or 0.35 },
        prefs = GetUiPrefs(),
    }
end

local function EnsureInit()
    if state.initSent then return end
    state.initSent = true
    SendNUIMessage(BuildInit())
end

local function BuildPlayer(data)
    data = data or QBCore.Functions.GetPlayerData() or {}
    local charinfo = data.charinfo or {}
    local job = data.job or {}
    local gang = data.gang or {}
    local money = data.money or {}
    local card = Config.PlayerCard

    return {
        name = ('%s %s'):format(charinfo.firstname or '', charinfo.lastname or ''):gsub('^%s+', ''):gsub('%s+$', ''),
        citizenid = data.citizenid or '',
        serverId = GetPlayerServerId(PlayerId()),
        job = card.job and {
            label = job.label or job.name or '',
            grade = type(job.grade) == 'table' and (job.grade.name or '') or '',
            onduty = job.onduty == true,
        } or nil,
        gang = (card.gang and gang.name and gang.name ~= 'none') and {
            label = gang.label or gang.name,
            grade = type(gang.grade) == 'table' and (gang.grade.name or '') or '',
        } or nil,
        cash = card.cash and (money.cash or 0) or nil,
        bank = card.bank and (money.bank or 0) or nil,
    }
end

local function RequestServerData()
    if state.fetching and GetGameTimer() - state.fetchStarted < 5000 then return end
    state.fetching = true
    state.fetchStarted = GetGameTimer()

    QBCore.Functions.TriggerCallback('jt-pause:server:getData', function(data)
        state.fetching = false
        if type(data) ~= 'table' then return end
        if data.updates then state.revision = data.revision end
        state.serverData = data
        -- Sent even if the menu closed meanwhile, so the changelog is never missed.
        SendNUIMessage({ action = 'server', data = data })
    end, state.revision)
end

-- ════════════════════════════════════════════════════════════
--  Open / close
-- ════════════════════════════════════════════════════════════
local function SetBlur(enabled)
    if enabled and not state.blurActive then
        state.blurActive = true
        TriggerScreenblurFadeIn(Config.BlurFadeTime)
    elseif not enabled and state.blurActive then
        state.blurActive = false
        TriggerScreenblurFadeOut(Config.BlurFadeTime)
    end
end

local function SetOpenState(open)
    state.open = open
    LocalPlayer.state:set('pauseMenuOpen', open, false)
    TriggerEvent('jt-pause:client:toggled', open)
end

local function OpenMenu(options)
    if state.open or state.disabled then return end
    EnsureInit()
    SetOpenState(true)
    SetNuiFocus(true, true)
    SetBlur(GetUiPrefs().blur)

    SendNUIMessage({
        action = 'open',
        view = options and options.view or nil,
        modal = options and options.modal or nil,
        player = BuildPlayer(),
        server = state.serverData,
        audio = GetAudioState(),
    })
    RequestServerData()

    state.session = state.session + 1
    local session = state.session
    CreateThread(function()
        while true do
            Wait(Config.RefreshInterval)
            if not state.open or state.session ~= session then return end
            RequestServerData()
        end
    end)
end

local function CloseMenu(fromNui)
    if not state.open then return end
    SetOpenState(false)
    SetNuiFocus(false, false)
    SetBlur(false)
    if not fromNui then
        SendNUIMessage({ action = 'close' })
    end
end

local function CanOpen()
    return state.loggedIn
        and not state.disabled
        and not state.nativeActive
        and not IsNuiFocused()
        and not IsPauseMenuActive()
        and not IsScreenFadedOut()
end

-- Opens a native GTA frontend (map / settings) and gives ESC back to the game until it closes.
local function OpenNative(kind)
    local menu = Config.NativeMenus[kind]
    if not menu or state.nativeActive then return end
    state.nativeActive = true
    CloseMenu(false)

    CreateThread(function()
        Wait(50)
        ActivateFrontendMenu(GetHashKey(menu.menu), false, menu.tab or -1)
        if menu.goDeeper then
            Wait(150)
            PauseMenuceptionGoDeeper(0)
        end

        Wait(500)
        while IsPauseMenuActive() or IsFrontendFading() do
            Wait(150)
        end
        -- Wait until the key that closed the native menu is released, so ours does not pop open.
        while IsControlPressed(0, CONTROL_PAUSE_ALT) or IsDisabledControlPressed(0, CONTROL_PAUSE_ALT)
            or IsControlPressed(0, CONTROL_PAUSE) or IsDisabledControlPressed(0, CONTROL_PAUSE) do
            Wait(0)
        end
        Wait(150)
        state.nativeActive = false
    end)
end

-- ════════════════════════════════════════════════════════════
--  Main loop: replaces the GTA pause menu.
--  Runs every frame only while the player is logged in (disabling a
--  control has to be done each frame); sleeps otherwise.
-- ════════════════════════════════════════════════════════════
CreateThread(function()
    while true do
        if not state.loggedIn then
            Wait(500)
        elseif state.disabled or state.nativeActive then
            Wait(100)
        elseif not state.open and IsPauseMenuActive() then
            -- A native menu opened by another resource: leave it alone.
            Wait(100)
        else
            DisableControlAction(0, CONTROL_PAUSE, true)
            DisableControlAction(0, CONTROL_PAUSE_ALT, true)

            if state.open then
                if Config.HideHud then HideHudAndRadarThisFrame() end
            elseif IsDisabledControlJustPressed(0, CONTROL_PAUSE_ALT) or IsDisabledControlJustPressed(0, CONTROL_PAUSE) then
                SetPauseMenuActive(false)
                if CanOpen() then OpenMenu() end
            end
            Wait(0)
        end
    end
end)

-- ════════════════════════════════════════════════════════════
--  Login state
-- ════════════════════════════════════════════════════════════
local function RefreshLoginState()
    local data = QBCore.Functions.GetPlayerData()
    state.loggedIn = LocalPlayer.state.isLoggedIn == true or (data ~= nil and data.citizenid ~= nil)
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    state.loggedIn = true
    ApplySavedAudio()
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    CloseMenu(false)
    state.loggedIn = false
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(data)
    if state.open then
        SendNUIMessage({ action = 'player', player = BuildPlayer(type(data) == 'table' and data or nil) })
    end
end)

CreateThread(function()
    RefreshLoginState()
    ApplySavedAudio()
end)

-- ════════════════════════════════════════════════════════════
--  NUI callbacks
-- ════════════════════════════════════════════════════════════
RegisterNUICallback('ready', function(_, cb)
    state.initSent = true
    SendNUIMessage(BuildInit())
    cb('ok')
end)

RegisterNUICallback('close', function(_, cb)
    CloseMenu(true)
    cb('ok')
end)

RegisterNUICallback('openMap', function(_, cb)
    cb('ok')
    OpenNative('map')
end)

RegisterNUICallback('openSettings', function(_, cb)
    cb('ok')
    OpenNative('settings')
end)

RegisterNUICallback('quit', function(_, cb)
    cb('ok')
    CloseMenu(false)
    TriggerServerEvent('jt-pause:server:quit')
end)

RegisterNUICallback('setVolume', function(data, cb)
    local kind, value = data and data.kind, tonumber(data and data.value)
    if (kind == 'sfx' or kind == 'music') and value then
        value = math.floor(math.max(0, math.min(100, value)) + 0.5)
        ApplyVolume(kind, value)
        prefs[kind] = value
        SavePrefs()
    end
    cb('ok')
end)

RegisterNUICallback('setToggle', function(data, cb)
    local key = data and data.key
    local handler = key and ToggleHandlers[key]
    if handler then
        local value = data.value == true
        handler(value)
        prefs['audio_' .. key] = value
        SavePrefs()
    end
    cb('ok')
end)

RegisterNUICallback('resetAudio', function(_, cb)
    for key, handler in pairs(ToggleHandlers) do
        if prefs['audio_' .. key] ~= nil then
            handler(Config.AudioDefaults[key] ~= false)
            prefs['audio_' .. key] = nil
        end
    end
    ApplyVolume('sfx', 100)
    ApplyVolume('music', 100)
    prefs.sfx, prefs.music = nil, nil
    SavePrefs()
    cb({ sfx = 100, music = 100, toggles = GetAudioToggles() })
end)

local UiPrefKeys = { sounds = 'ui_sounds', blur = 'ui_blur', reducedMotion = 'ui_reducedMotion' }
RegisterNUICallback('setPref', function(data, cb)
    local key = data and UiPrefKeys[data.key]
    if key then
        prefs[key] = data.value == true
        SavePrefs()
        if data.key == 'blur' and state.open then SetBlur(prefs[key]) end
    end
    cb('ok')
end)

RegisterNUICallback('seenUpdate', function(data, cb)
    if data and type(data.id) == 'string' and prefs.seenUpdate ~= data.id then
        prefs.seenUpdate = data.id
        SavePrefs()
    end
    cb('ok')
end)

RegisterNUICallback('publishUpdate', function(data, cb)
    if type(data) == 'table' then
        TriggerServerEvent('jt-pause:server:publishUpdate', {
            version = data.version,
            title = data.title,
            added = data.added,
            removed = data.removed,
        })
    end
    cb('ok')
end)

RegisterNUICallback('deleteUpdate', function(data, cb)
    if data and type(data.id) == 'string' then
        TriggerServerEvent('jt-pause:server:deleteUpdate', data.id)
    end
    cb('ok')
end)

-- ════════════════════════════════════════════════════════════
--  Server events
-- ════════════════════════════════════════════════════════════
RegisterNetEvent('jt-pause:client:openPublish', function()
    if state.open then
        SendNUIMessage({ action = 'show', view = 'updates', modal = 'publish' })
    else
        OpenMenu({ view = 'updates', modal = 'publish' })
    end
end)

RegisterNetEvent('jt-pause:client:updatesChanged', function(revision)
    if revision ~= state.revision and state.open then
        RequestServerData()
    end
end)

RegisterNetEvent('jt-pause:client:result', function(ok, key)
    local message = L[key] or key
    if state.open then
        SendNUIMessage({ action = 'toast', ok = ok, text = message })
    else
        QBCore.Functions.Notify(message, ok and 'success' or 'error')
    end
end)

-- ════════════════════════════════════════════════════════════
--  Exports (for other resources)
-- ════════════════════════════════════════════════════════════
exports('IsOpen', function() return state.open end)
exports('Open', function(view) if CanOpen() then OpenMenu({ view = view }) end end)
exports('Close', function() CloseMenu(false) end)
exports('SetDisabled', function(disabled)
    state.disabled = disabled == true
    if state.disabled then CloseMenu(false) end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if state.open then SetNuiFocus(false, false) end
    if state.blurActive then TriggerScreenblurFadeOut(0) end
    LocalPlayer.state:set('pauseMenuOpen', false, false)
end)
