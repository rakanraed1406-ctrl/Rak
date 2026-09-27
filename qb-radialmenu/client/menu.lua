local showMenu = false
local MAX_MENU_ITEMS = 7

QBCore = exports["qb-core"]:GetCoreObject()
local isLoggedIn = false
local MenuOpend = false
local PlayerData = {}

RegisterNetEvent('QBCore:Client:OnPlayerLoaded')
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
      isLoggedIn = true
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload')
AddEventHandler('QBCore:Client:OnPlayerUnload', function()
    isLoggedIn = false
end)

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


-- Code

-- Builds the wheel from Config.Menu (same structure as before: sub menus are
-- split into pages of MAX_MENU_ITEMS with a "More" entry).
local function buildMenus()
    local enabledMenus = {}
    for _, menuConfig in ipairs(Config.Menu) do
        if menuConfig:enableMenu() then
            local dataElements = {}
            local hasSubMenus = false
            if menuConfig.subMenus ~= nil and #menuConfig.subMenus > 0 then
                hasSubMenus = true
                local previousMenu = dataElements
                local currentElement = {}
                for i = 1, #menuConfig.subMenus do
                    currentElement[#currentElement+1] = Config.SubMenus[menuConfig.subMenus[i]]
                    currentElement[#currentElement].id = menuConfig.subMenus[i]
                    currentElement[#currentElement].enableMenu = nil

                    if i % MAX_MENU_ITEMS == 0 and i < (#menuConfig.subMenus - 1) then
                        previousMenu[MAX_MENU_ITEMS + 1] = {
                            id = "_more",
                            title = "More",
                            icon = "#more",
                            items = currentElement
                        }
                        previousMenu = currentElement
                        currentElement = {}
                    end
                end
                if #currentElement > 0 then
                    previousMenu[MAX_MENU_ITEMS + 1] = {
                        id = "_more",
                        title = "More",
                        icon = "#more",
                        items = currentElement
                    }
                end
                dataElements = dataElements[MAX_MENU_ITEMS + 1].items
            end
            enabledMenus[#enabledMenus+1] = {
                id = menuConfig.id,
                title = menuConfig.displayName,
                close = menuConfig.close,
                functiontype = menuConfig.functiontype,
                functionParameters = menuConfig.functionParameters,
                functionName = menuConfig.functionName,
                icon = menuConfig.icon,
            }
            if hasSubMenus then
                enabledMenus[#enabledMenus].items = dataElements
            end
        end
    end
    return enabledMenus
end

local function openRadial()
    if showMenu or IsPauseMenuActive() or IsNuiFocused() then return end
    showMenu = true
    MenuOpend = true
    SendNUIMessage({
        state = "show",
        data = buildMenus(),
        menuKeyBind = Config.MenuKey or 'F1'
    })
    SetCursorLocation(0.5, 0.5)
    SetNuiFocus(true, true)
    if Config.GameSounds then PlaySoundFrontend(-1, "NAV", "HUD_AMMO_SHOP_SOUNDSET", 1) end
end

-- Key mapping instead of a loop checking F1 every 3 ms: zero cost while the
-- wheel is closed. Players can rebind it in Settings > Key Bindings > FiveM.
-- Releasing the key closes the wheel (handled in the NUI, like before).
RegisterCommand('+radialmenu', openRadial, false)
RegisterCommand('-radialmenu', function() end, false)
RegisterKeyMapping('+radialmenu', 'Open radial menu', 'keyboard', Config.MenuKey or 'F1')

RegisterNetEvent('qb-radialmenu:client:force:close')
AddEventHandler('qb-radialmenu:client:force:close', function()
  showMenu = false
  MenuOpend = false
  SetNuiFocus(false, false)
  SendNUIMessage({
      state = 'destroy'
  })
end)


RegisterNetEvent('qb-radialmenu:client:GiveCash', function()
    TriggerServerEvent('qb-radialmenu:server:GiveCash')
end)

RegisterNetEvent('qb-radialmenu:client:GiveCashSecond', function(players)
    if players then 
        local GiveCashMenu = {
            {
                header = "Give Cash",
                isMenuHeader = true, -- Set to true to make a nonclickable title
            },
        }
        for k, v in pairs(players) do 
            GiveCashMenu[#GiveCashMenu + 1] = {
                header = '',
                txt = 'ID : '..v.id,
                params = {
                    event = 'qb-radialmenu:client:GiveCashThird',
                    args = {
                        ID = v.id,
                        name = v.name
                    }
                }
            }
        end
        GiveCashMenu[#GiveCashMenu + 1] = {
            header = "Exit",
            params = {
                event = "qb-menu:closeMenu",
            }
        }
        if #GiveCashMenu > 0 then 
            exports['qb-menu']:openMenu(GiveCashMenu)
        end
    end
end)


RegisterNetEvent('qb-radialmenu:client:GiveCashThird', function(data)
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
    if tonumber(dialog['cashamount']) > 0 then
        TriggerServerEvent("qb-radialmenu:server:GiveCashFinal", data.ID, tonumber(dialog['cashamount']))
    else
        QBCore.Functions.Notify('Money must be higher than 0', "error")
    end
end)

RegisterNetEvent('qb-radialmenu:client:refresh')
AddEventHandler('qb-radialmenu:client:refresh', function()
    QBCore.Functions.Progressbar("reset-f1", "F1 wordt gereset..", 1200, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {}, {}, {}, function() -- Done
        showMenu = false
        MenuOpend = false
        SetNuiFocus(false, false)
        SendNUIMessage({
            state = 'destroy'
        })
    end, function() -- Cancel
    end)
end)

RegisterNUICallback('closemenu', function(data, cb)
 showMenu = false
 MenuOpend = false
 SetNuiFocus(false, false)
 SendNUIMessage({
     state = 'destroy'
 })
 if Config.GameSounds then PlaySoundFrontend(-1, "NAV", "HUD_AMMO_SHOP_SOUNDSET", 1) end
 cb('ok')
end)

RegisterNUICallback('triggerAction', function(data, cb)
 if Config.GameSounds then PlaySoundFrontend(-1, "NAV", "HUD_AMMO_SHOP_SOUNDSET", 1) end
 if data.type == 'client' then
     TriggerEvent(data.action, data.parameters)
 elseif data.type == 'server' then 
     TriggerServerEvent(data.action, data.parameters)
 end
 cb('ok')
end)
