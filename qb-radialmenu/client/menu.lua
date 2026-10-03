local MAX_MENU_ITEMS = 7

QBCore = exports["qb-core"]:GetCoreObject()
local isLoggedIn = LocalPlayer.state.isLoggedIn == true
local menuOpen = false
-- Options of the last wheel that was opened: [uid] = { type, action, params, close }.
-- The NUI only gets the uid, so the page can't fire any other event or change the
-- parameters (devtools / a broken NUI can't abuse it).
local actions = {}
local lastAction = 0

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function() isLoggedIn = true end)
RegisterNetEvent('QBCore:Client:OnPlayerUnload', function() isLoggedIn = false end)

local dispatch = false
RegisterNetEvent("qb-radialmenu:cl:Dispatch", function()
    ExecuteCommand("dispatchsmall")
    dispatch = true
end)

RegisterNetEvent("qb-radialmenu:cl:Large", function()
    if dispatch then
        ExecuteCommand("dispatchlarge")
    else
        QBCore.Functions.Notify("Open the dispatch first")
    end
end)

RegisterNetEvent("qb-radialmenu:cl:Resize", function()
    ExecuteCommand("movemode")
end)

-- ---------------------------------------------------------------------------
-- Building the wheel
-- ---------------------------------------------------------------------------

-- registers an option and returns the uid the NUI sends back (nil = not clickable)
local function register(cfg)
    local ftype, fname = cfg.functiontype, cfg.functionName
    if (ftype ~= 'client' and ftype ~= 'server') or type(fname) ~= 'string' or fname == '' then return nil end
    local uid = #actions + 1
    actions[uid] = { type = ftype, action = fname, params = cfg.functionParameters, close = cfg.close == true }
    return uid
end

local function enabled(menuConfig)
    if not menuConfig.enableMenu then return true end
    -- one broken check (missing export, nil player data...) must not kill F1
    local ok, res = pcall(menuConfig.enableMenu, menuConfig)
    return ok and res
end

-- 7 per ring; more than that goes behind a "More" item (same as before)
local function chunk(list)
    local top = {}
    local level = top
    for i = 1, #list do
        if #level == MAX_MENU_ITEMS and (#list - i + 1) > 1 then
            local nextLevel = {}
            level[#level + 1] = { id = "_more", title = "More", icon = "#more", items = nextLevel }
            level = nextLevel
        end
        level[#level + 1] = list[i]
    end
    return top
end

local function buildMenus()
    actions = {}
    local menus = {}
    for _, menuConfig in ipairs(Config.Menu) do
        if enabled(menuConfig) then
            local entry = {
                id = menuConfig.id,
                title = menuConfig.displayName,
                close = menuConfig.close == true,
                icon = menuConfig.icon,
                uid = register(menuConfig),
            }
            local subs = menuConfig.subMenus
            if subs and #subs > 0 then
                local list = {}
                for i = 1, #subs do
                    local sub = Config.SubMenus[subs[i]]
                    if sub then -- a missing entry used to crash the F1 thread for good
                        list[#list + 1] = {
                            id = subs[i],
                            title = sub.title,
                            icon = sub.icon,
                            close = sub.close == true,
                            uid = register(sub),
                        }
                    end
                end
                entry.items = chunk(list)
            end
            menus[#menus + 1] = entry
        end
    end
    return menus
end

-- the key the player bound in Settings → Key Bindings (the wheel closes when it is released)
local function boundKey()
    local btn = GetControlInstructionalButton(0, joaat('+radialmenu') | 0x80000000, true)
    if type(btn) == 'string' and btn:sub(1, 2) == 't_' then return btn:sub(3) end
    return 'F1'
end

local function closeMenu()
    menuOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ state = 'destroy' })
end

local function openMenu()
    if not isLoggedIn then -- older qb-core without the isLoggedIn state bag
        local pd = QBCore.Functions.GetPlayerData()
        isLoggedIn = pd ~= nil and pd.citizenid ~= nil
    end
    if menuOpen or not isLoggedIn or IsPauseMenuActive() or IsNuiFocused() then return end
    menuOpen = true
    SendNUIMessage({
        state = "show",
        data = buildMenus(),
        menuKeyBind = boundKey()
    })
    SetCursorLocation(0.5, 0.5)
    SetNuiFocus(true, true)
    if Config.GameSounds then PlaySoundFrontend(-1, "NAV", "HUD_AMMO_SHOP_SOUNDSET", 1) end
end

-- A key mapping instead of a thread checking F1 every 3 ms for the whole session.
RegisterCommand('+radialmenu', openMenu, false)
RegisterCommand('-radialmenu', function() end, false)
RegisterKeyMapping('+radialmenu', Lang:t('general.command_description'), 'keyboard', 'F1')

RegisterNetEvent('qb-radialmenu:client:force:close', closeMenu)

RegisterNetEvent('qb-radialmenu:client:GiveCash', function()
    TriggerServerEvent('qb-radialmenu:server:GiveCash')
end)

RegisterNetEvent('qb-radialmenu:client:GiveCashSecond', function(players)
    if type(players) ~= 'table' or #players == 0 then return end
    local GiveCashMenu = {
        {
            header = "Give Cash",
            isMenuHeader = true,
        },
    }
    for _, v in ipairs(players) do
        GiveCashMenu[#GiveCashMenu + 1] = {
            header = '',
            txt = 'ID : ' .. tostring(v.id),
            params = {
                event = 'qb-radialmenu:client:GiveCashThird',
                args = { ID = v.id }
            }
        }
    end
    GiveCashMenu[#GiveCashMenu + 1] = {
        header = "Exit",
        params = { event = "qb-menu:client:closeMenu" }
    }
    exports['qb-menu']:openMenu(GiveCashMenu)
end)

RegisterNetEvent('qb-radialmenu:client:GiveCashThird', function(data)
    if type(data) ~= 'table' then return end
    local dialog = exports['qb-input']:ShowInput({
        header = "Give Cash",
        submitText = 'Submit',
        inputs = {
            {
                text = 'Amount',
                name = "cashamount",
                type = "number",
                isRequired = true
            }
        }
    })
    if not dialog then return end
    local amount = tonumber(dialog['cashamount'])
    if amount and amount >= 1 then
        TriggerServerEvent("qb-radialmenu:server:GiveCashFinal", data.ID, math.floor(amount))
    else
        QBCore.Functions.Notify('Money must be higher than 0', "error")
    end
end)

RegisterNetEvent('qb-radialmenu:client:refresh', function()
    QBCore.Functions.Progressbar("reset-f1", "F1 wordt gereset..", 1200, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {}, {}, {}, function() -- Done
        closeMenu()
    end, function() -- Cancel
    end)
end)

RegisterNUICallback('closemenu', function(_, cb)
    closeMenu()
    if Config.GameSounds then PlaySoundFrontend(-1, "NAV", "HUD_AMMO_SHOP_SOUNDSET", 1) end
    cb('ok')
end)

local function runAction(a)
    if Config.GameSounds then PlaySoundFrontend(-1, "NAV", "HUD_AMMO_SHOP_SOUNDSET", 1) end
    if a.type == 'client' then
        TriggerEvent(a.action, a.params)
    else
        TriggerServerEvent(a.action, a.params)
    end
end

-- One request per click (was triggerAction + closemenu, two requests in any order):
-- an option that opens another menu (emotes, clothing, garage...) used to open while
-- the wheel still had the mouse/keyboard, then the wheel's SetNuiFocus(false) landed
-- on top of it and that menu froze. Now: close the wheel, wait for the focus to
-- really go, then run the option.
RegisterNUICallback('select', function(data, cb)
    cb('ok')
    local a = type(data) == 'table' and actions[tonumber(data.uid) or -1]
    if not a or not menuOpen then return end
    local now = GetGameTimer()
    local spam = now - lastAction < 250 -- double clicks / key spam
    if a.close then closeMenu() end    -- the page already hid the wheel: always let the focus go
    if spam then return end
    lastAction = now

    if not a.close then return runAction(a) end
    CreateThread(function()
        local deadline = GetGameTimer() + 300
        repeat Wait(0) until not IsNuiFocused() or GetGameTimer() > deadline
        runAction(a)
    end)
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and menuOpen then SetNuiFocus(false, false) end
end)
