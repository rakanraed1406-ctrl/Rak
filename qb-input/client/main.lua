local properties = nil

local function setStyle()
    SendNUIMessage({
        action = 'SET_STYLE',
        data = Config.Style
    })
end

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then
        return
    end
    Wait(1000)
    setStyle()
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', setStyle)

local function resolve(value)
    SetNuiFocus(false, false)
    if properties then
        local p = properties
        properties = nil
        p:resolve(value)
    end
end

RegisterNUICallback('buttonSubmit', function(data, cb)
    cb('ok')
    resolve(data and data.data or nil)
end)

RegisterNUICallback('closeMenu', function(_, cb)
    cb('ok')
    resolve(nil)
end)

local function ShowInput(data)
    Wait(150)
    if not data then return end
    if properties then return end

    properties = promise.new()

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'OPEN_MENU',
        data = data
    })

    return Citizen.Await(properties)
end

exports('ShowInput', ShowInput)
