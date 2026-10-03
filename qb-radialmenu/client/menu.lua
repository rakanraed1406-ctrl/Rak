local MAX_MENU_ITEMS = 7
-- After the wheel closes it can't reopen for this long. Holding F1 and picking an option
-- (Emote Menu...) gave the focus back to the game while F1 was still down, so the wheel
-- opened again on top of the other menu and that menu stopped responding.
local REOPEN_COOLDOWN = 700 -- ms
local lastClose = 0

QBCore = exports["qb-core"]:GetCoreObject()
local isLoggedIn = LocalPlayer.state.isLoggedIn == true
local menuOpen = false
local allowed = {} -- "type|event" of the options on the last wheel that was opened

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

local function allow(ftype, fname)
    if ftype and fname then allowed[ftype .. '|' .. tostring(fname)] = true end
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
    allowed = {}
    local menus = {}
    for _, menuConfig in ipairs(Config.Menu) do
        if enabled(menuConfig) then
            local entry = {
                id = menuConfig.id,
                title = menuConfig.displayName,
                close = menuConfig.close,
                functiontype = menuConfig.functiontype,
                functionParameters = menuConfig.functionParameters,
                functionName = menuConfig.functionName,
                icon = menuConfig.icon,
            }
            allow(menuConfig.functiontype, menuConfig.functionName)
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
                            close = sub.close,
                            functiontype = sub.functiontype,
                            functionName = sub.functionName,
                            functionParameters = sub.functionParameters,
                        }
                        allow(sub.functiontype, sub.functionName)
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
    lastClose = GetGameTimer()
    SetNuiFocus(false, false)
    SendNUIMessage({ state = 'destroy' })
end

local function openMenu()
    if not isLoggedIn then -- older qb-core without the isLoggedIn state bag
        local pd = QBCore.Functions.GetPlayerData()
        isLoggedIn = pd ~= nil and pd.citizenid ~= nil
    end
    if menuOpen or not isLoggedIn or IsPauseMenuActive() or IsNuiFocused() then return end
    if GetGameTimer() - lastClose < REOPEN_COOLDOWN then return end
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

RegisterNUICallback('triggerAction', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' or (data.type ~= 'client' and data.type ~= 'server') then return end
    -- only an option that was on the wheel the player opened (kept after close:
    -- the NUI sends triggerAction and closemenu right after each other)
    if not allowed[data.type .. '|' .. tostring(data.action)] then return end
    if Config.GameSounds then PlaySoundFrontend(-1, "NAV", "HUD_AMMO_SHOP_SOUNDSET", 1) end
    if data.type == 'client' then
        TriggerEvent(data.action, data.parameters)
    else
        TriggerServerEvent(data.action, data.parameters)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and menuOpen then SetNuiFocus(false, false) end
end)
