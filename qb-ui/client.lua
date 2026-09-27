local lasttext = ''
local lasticon = ''

-- qb-core style calls pass a position ('left' / 'right' / 'top') where these
-- exports expect an icon; treat those as "no icon" so the default is used.
local positions = { left = true, right = true, top = true, bottom = true }

local function sendDrawText(text, icon, defaultIcon)
    if icon == nil or icon == '' or positions[icon] then
        icon = defaultIcon
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
    local fn = function(text, icon)
        sendDrawText(text, icon, defaultIcon)
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
