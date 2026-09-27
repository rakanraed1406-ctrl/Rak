local lasttext = ''
local lasticon = ''

-- qb-core style calls pass a position ('left' / 'right' / 'top') where these
-- exports expect an icon; that value is used as the position and the default
-- icon is shown. A position can also be passed as the third argument.
local positions = { left = true, right = true, top = true, bottom = true }

local function sendDrawText(text, icon, defaultIcon, position)
    if positions[icon] then
        position = position or icon
        icon = nil
    end
    if icon == nil or icon == '' then
        icon = defaultIcon
    end
    if not positions[position] then
        position = 'bottom'
    end
    if text == nil then
        text = ''
    end
    lasttext = text
    lasticon = icon
    SendNUIMessage({
        type = 'open',
        icon = icon,
        text = text,
        position = position,
    })
end

-- Same exports as before; each one only differs by its default icon.
local defaults = {
    DrawText   = 'fa-solid fa-bells',
    DrawText1  = 'fas fa-lock',
    DrawText2  = 'fas fa-unlock',
    DrawText3  = 'fas fa-building',
    DrawText4  = 'fas fa-tshirt',
    DrawText5  = 'fas fa-clock',
    DrawText6  = 'fas fa-recycle',
    DrawText7  = 'fa-solid fa-bells',
    DrawText8  = 'fa-solid fa-x',
    DrawText9  = 'fa-solid fa-f',
    DrawText10 = 'fa-solid fa-e',
}

local DrawText
for name, defaultIcon in pairs(defaults) do
    local fn = function(text, icon, position)
        sendDrawText(text, icon, defaultIcon, position)
    end
    if name == 'DrawText' then DrawText = fn end
    exports(name, fn)
end

local function HideText()
    SendNUIMessage({
        type = 'close',
        icon = lasticon,
        text = lasttext,
    })
end

local function KeyPressed()
    CreateThread(function()
        SendNUIMessage({
            action = 'KEY_PRESSED',
        })
        Wait(500)
        HideText()
    end)
end

local function DrawBlackUi(action, text)
    SendNUIMessage({
        action = action,
        text = text,
    })
end

local function HideBlackUi()
    SendNUIMessage({
        action = 'hide'
    })
end

-- Notifications (new): exports['qb-ui']:Notify(text, type, length, caption, icon)
-- type: 'primary' | 'success' | 'error' | 'warning' | 'police' | 'ambulance'
-- text may also be a table: { text = '...', caption = '...' }
local function Notify(text, notifyType, length, caption, icon)
    if type(text) == 'table' then
        caption = caption or text.caption
        text = text.text or ''
    end
    SendNUIMessage({
        action = 'notify',
        text = tostring(text or ''),
        type = notifyType or 'primary',
        length = tonumber(length) or 5000,
        caption = caption,
        icon = icon,
    })
end

RegisterNetEvent('qb-core:client:DrawText', function(text, position)
    DrawText(text, position)
end)

RegisterNetEvent('qb-core:client:ChangeText', function(text, position)
    DrawText(text, position)
end)

RegisterNetEvent('qb-core:client:HideText', function()
    HideText()
end)

RegisterNetEvent('qb-core:client:KeyPressed', function()
    KeyPressed()
end)

RegisterNetEvent('qb-ui:client:notify', Notify)

exports('HideText', HideText)
exports('KeyPressed', KeyPressed)
exports('DrawBlackUi', DrawBlackUi)
exports('HideBlackUi', HideBlackUi)
exports('Notify', Notify)

-- Hide the whole UI while the pause menu / map is open (only sends on change).
CreateThread(function()
    local paused = false
    while true do
        local now = IsPauseMenuActive()
        if now ~= paused then
            paused = now
            SendNUIMessage({ action = 'pause', state = paused })
        end
        Wait(400)
    end
end)
