local QBCore = exports['qb-core']:GetCoreObject()
RegisterNetEvent('QBCore:Client:UpdateObject', function() QBCore = exports['qb-core']:GetCoreObject() end)

-- true = play the old GTA frontend sound when a button is clicked (the menu itself has no sounds).
local GameSounds = false

local headerShown = false
local sendData = nil
-- Functions

local function sortData(data, skipfirst)
    local header = data[1]
    local tempData = data
    if skipfirst then table.remove(tempData,1) end
    table.sort(tempData, function(a,b) return tostring(a.header or "") < tostring(b.header or "") end)
    if skipfirst then table.insert(tempData,1,header) end
    return tempData
end

-- an item name as icon → that item's inventory image
local function itemIcons(data)
    local items = QBCore.Shared.Items or {}
    for _, v in pairs(data) do
        if type(v) == 'table' and v.icon then
            local icon = tostring(v.icon)
            local item = items[icon]
            if item and type(item.image) == 'string' and not item.image:find('//', 1, true) and not icon:find('//', 1, true) then
                v.icon = "nui://qb-inventory/html/images/" .. item.image
            end
        end
    end
end

local function openMenu(data, sort, skipFirst)
    if type(data) ~= 'table' or not next(data) then return end
    if sort then data = sortData(data, skipFirst) end
    itemIcons(data)
    SetNuiFocus(true, true)
    headerShown = false
    sendData = data
    SendNUIMessage({
        action = 'OPEN_MENU',
        data = table.clone(data),
        time = 	GetClockHours()
    })
end

local function openMenuPrison(data, sort, skipFirst)
    if type(data) ~= 'table' or not next(data) then return end
    if sort then data = sortData(data, skipFirst) end
    itemIcons(data)
    SetNuiFocus(false, false)
    headerShown = false
    sendData = data
    SendNUIMessage({
        action = 'OPEN_MENU',
        data = table.clone(data),
        time = 	GetClockHours()
    })
end

local function closeMenu()
    sendData = nil
    headerShown = false
    SetNuiFocus(false)
    SendNUIMessage({
        action = 'CLOSE_MENU'
    })
end

local function showHeader(data)
    if type(data) ~= 'table' or not next(data) then return end
    headerShown = true
    sendData = data
    SendNUIMessage({
        action = 'SHOW_HEADER',
        data = table.clone(data),
        time = 	GetClockHours()
    })
end

-- Events

RegisterNetEvent('qb-menu:client:openMenu', function(data, sort, skipFirst)
    openMenu(data, sort, skipFirst)
end)

RegisterNetEvent('qb-menu:client:closeMenu', function()
    closeMenu()
end)

-- NUI Callbacks

RegisterNUICallback('clickedButton', function(option, cb)
    if headerShown then headerShown = false end
    if GameSounds then PlaySoundFrontend(-1, 'Highlight_Cancel', 'DLC_HEIST_PLANNING_BOARD_SOUNDS', 1) end
    SetNuiFocus(false)
    if sendData then
        local data = sendData[tonumber(option)]
        sendData = nil
        if type(data) == 'table' and type(data.params) == 'table' and not data.disabled and not data.isMenuHeader then
            if data.params.event then
                if data.params.isServer then
                    TriggerServerEvent(data.params.event, data.params.args)
                elseif data.params.isCommand then
                    ExecuteCommand(data.params.event)
                elseif data.params.isQBCommand then
                    TriggerServerEvent('QBCore:CallCommand', data.params.event, data.params.args)
                elseif data.params.isAction then
                    if type(data.params.event) == 'function' or type(data.params.event) == 'table' then data.params.event(data.params.args) end
                else
                    TriggerEvent(data.params.event, data.params.args)
                end
            end
        end
    end
    cb('ok')
end)

RegisterNUICallback('closeMenu', function(_, cb)
    headerShown = false
    sendData = nil
    SetNuiFocus(false)
    cb('ok')
    TriggerEvent("qb-menu:client:menuClosed")
end)

-- Command and Keymapping

RegisterCommand('playerfocus', function()
    if headerShown then
        SetNuiFocus(true, true)
    end
end)
RegisterKeyMapping('playerFocus', 'Give Menu Focus', 'keyboard', 'LMENU')

-- Exports

exports('openMenu', openMenu)
exports('openMenuPrison', openMenuPrison)
exports('closeMenu', closeMenu)
exports('showHeader', showHeader)
