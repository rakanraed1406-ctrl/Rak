--[[ client/dispatch.lua - built-in dispatch: notifications (with the tablet closed too),
     respond / dismiss keybinds, CAD NUI callbacks, command broadcasts, radio. ]]

local QBCore = MDTClient.QBCore
local DCfg = Config.Dispatch or {}

-- The HUD notification currently on screen (set by the NUI), for the keybinds.
local hudToast = nil -- { callId = 'C1001', coords = {x,y,z} }

local function sendNuiConfig()
    SendNUIMessage({
        action = 'mdtConfig',
        config = {
            toastDuration = DCfg.ToastDuration,
            sounds = DCfg.Sounds,
            defaultVolume = DCfg.DefaultVolume,
            respondKey = DCfg.RespondKey,
            dismissKey = DCfg.DismissKey,
            roles = DCfg.UnitRoles,
            chatChannels = Config.Hub and Config.Hub.ChatChannels or {},
            autoClockIn = Config.Hub and Config.Hub.AutoClockIn == true,
        }
    })
end

CreateThread(function()
    Wait(1000)
    sendNuiConfig()
end)
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function() sendNuiConfig() end)

-- ---------------------------------------------------------------------------
-- Server → NUI
-- ---------------------------------------------------------------------------

RegisterNetEvent('police:client:DispatchNotify', function(call, serverTime)
    SendNUIMessage({ action = 'dispatchNotify', call = call, serverTime = serverTime })
end)

RegisterNetEvent('police:client:DispatchSync', function(payload)
    SendNUIMessage({ action = 'dispatchSync', payload = payload })
end)

RegisterNetEvent('police:client:DispatchCount', function(count)
    SendNUIMessage({ action = 'dispatchCount', count = count })
end)

RegisterNetEvent('police:client:DispatchAssigned', function(call, byName)
    if type(call) ~= 'table' then return end
    QBCore.Functions.Notify(('Dispatch assigned you to %s %s'):format(call.code or '', call.title or ''), 'primary', 7000)
    if call.coords then SetNewWaypoint(call.coords.x + 0.0, call.coords.y + 0.0) end
    SendNUIMessage({ action = 'dispatchAssigned', call = call, by = byName })
end)

RegisterNetEvent('police:client:Request911Street', function(callId)
    TriggerServerEvent('police:server:Update911Street', callId, MDTClient.GetStreetName())
end)

-- ---------------------------------------------------------------------------
-- NUI → server
-- ---------------------------------------------------------------------------

local function setGps(coords)
    if type(coords) == 'table' and tonumber(coords.x) and tonumber(coords.y) then
        SetNewWaypoint(tonumber(coords.x) + 0.0, tonumber(coords.y) + 0.0)
        return true
    end
    return false
end

RegisterNUICallback('dispatchRespond', function(data, cb)
    TriggerServerEvent('police:server:DispatchRespond', data.callId)
    if setGps(data.coords) then QBCore.Functions.Notify('Responding — GPS set to the call.', 'success') end
    cb('ok')
end)

RegisterNUICallback('dispatchDetach', function(data, cb)
    TriggerServerEvent('police:server:DispatchDetach', data.callId)
    cb('ok')
end)

RegisterNUICallback('dispatchGps', function(data, cb)
    if setGps(data.coords) then QBCore.Functions.Notify('GPS set to the call location.', 'success') end
    cb('ok')
end)

RegisterNUICallback('dispatchUpdate', function(data, cb)
    TriggerServerEvent('police:server:DispatchUpdate', data)
    cb('ok')
end)

RegisterNUICallback('dispatchCreate', function(data, cb)
    if data.useMyLocation then
        local c = GetEntityCoords(PlayerPedId())
        data.coords = { x = c.x, y = c.y, z = c.z }
        data.street = data.street ~= '' and data.street or MDTClient.GetStreetName(c)
    elseif data.useWaypoint then
        local wp = GetFirstBlipInfoId(8)
        if not DoesBlipExist(wp) then
            QBCore.Functions.Notify('Set a waypoint on the map first.', 'error')
            cb('ok')
            return
        end
        local c = GetBlipInfoIdCoord(wp)
        data.coords = { x = c.x, y = c.y, z = c.z }
        data.street = (data.street and data.street ~= '') and data.street or MDTClient.GetStreetName(c)
    end
    TriggerServerEvent('police:server:DispatchCreateManual', data)
    cb('ok')
end)

RegisterNUICallback('dispatchRequestSync', function(_, cb)
    TriggerServerEvent('police:server:DispatchRequestSync')
    cb('ok')
end)

RegisterNUICallback('toastState', function(data, cb)
    hudToast = (data and data.callId) and { callId = data.callId, coords = data.coords } or nil
    -- يقول لسكربت الموتر (qb-customscripts-byrko) إن زر G مستخدم للرد، عشان ما يطفي الموتر
    LocalPlayer.state:set('gKeyBusy', hudToast ~= nil and (DCfg.RespondKey or 'G'):upper() == 'G', false)
    cb('ok')
end)

-- ---------------------------------------------------------------------------
-- Keybinds that work while the tablet is CLOSED (no NUI focus needed)
-- ---------------------------------------------------------------------------

RegisterCommand('mdt_dispatch_respond', function()
    if not hudToast or MDTClient.mdtOpen then return end
    TriggerServerEvent('police:server:DispatchRespond', hudToast.callId)
    if setGps(hudToast.coords) then QBCore.Functions.Notify('Responding — GPS set to the call.', 'success') end
    SendNUIMessage({ action = 'toastResponded', callId = hudToast.callId })
end, false)
RegisterKeyMapping('mdt_dispatch_respond', 'MDT: Respond to dispatch notification', 'keyboard', DCfg.RespondKey or 'G')

RegisterCommand('mdt_dispatch_dismiss', function()
    if not hudToast or MDTClient.mdtOpen then return end
    SendNUIMessage({ action = 'toastDismiss' })
end, false)
RegisterKeyMapping('mdt_dispatch_dismiss', 'MDT: Dismiss dispatch notification', 'keyboard', DCfg.DismissKey or 'DELETE')

RegisterCommand('mdtmute', function()
    SendNUIMessage({ action = 'toggleMute' })
end, false)
RegisterKeyMapping('mdtmute', 'MDT: Mute / unmute dispatch sounds', 'keyboard', DCfg.MuteKey or '')

RegisterNUICallback('notifyMuteState', function(data, cb)
    QBCore.Functions.Notify(data.muted and 'Dispatch sounds muted.' or 'Dispatch sounds on.', 'primary')
    cb('ok')
end)

-- ---------------------------------------------------------------------------
-- Client-side export (same signature as sk1-hub's client export)
-- ---------------------------------------------------------------------------

local function clientCreateDispatchCall(dept, data)
    if type(dept) == 'table' and data == nil then data, dept = dept, 'police' end
    if type(data) ~= 'table' then return end
    local c = GetEntityCoords(PlayerPedId())
    if type(data.coords) == 'vector3' then
        data.coords = { x = data.coords.x, y = data.coords.y, z = data.coords.z }
    elseif type(data.coords) ~= 'table' then
        data.coords = { x = c.x, y = c.y, z = c.z }
    end
    if not data.street or data.street == '' then
        data.street = MDTClient.GetStreetName(vector3(data.coords.x, data.coords.y, data.coords.z or c.z))
    end
    TriggerServerEvent('police:server:ClientDispatchCall', dept or 'police', data)
end

exports('CreateDispatchCall', clientCreateDispatchCall)
-- Event version for other CLIENT scripts (no folder name needed):
--   TriggerEvent('mdt:client:CreateDispatchCall', { code = '10-90', title = 'Store Robbery', priority = 'high' })
AddEventHandler('mdt:client:CreateDispatchCall', function(data, dept)
    clientCreateDispatchCall(dept or 'police', data)
end)
if DCfg.Sk1HubCompat then
    AddEventHandler('__cfx_export_sk1-hub_CreateDispatchCall', function(setCB) setCB(clientCreateDispatchCall) end)
end

-- ---------------------------------------------------------------------------
-- Command features (alert level / broadcast / all-units) + radio
-- ---------------------------------------------------------------------------

RegisterNUICallback('sendAlertMessage', function(data, cb)
    TriggerServerEvent('police:server:BroadcastEmergencyAlert', data.message)
    cb('ok')
end)

RegisterNUICallback('setAlertLevel', function(data, cb)
    TriggerServerEvent('police:server:SetAlertLevel', data.level)
    cb('ok')
end)

RegisterNUICallback('sendUnitsAlert', function(data, cb)
    TriggerServerEvent('police:server:SendUnitsAlert', data.message)
    cb('ok')
end)

RegisterNetEvent('police:client:AlertLevelChanged', function(level)
    SendNUIMessage({ action = 'alertLevelChanged', level = level })
end)

RegisterNUICallback('openRadio', function(_, cb)
    local resourceName = Config.RadioResource
    if not resourceName or resourceName == '' or GetResourceState(resourceName) ~= 'started' then
        QBCore.Functions.Notify('No radio script is configured (Config.RadioResource).', 'error')
        cb('ok')
        return
    end
    ExecuteCommand(Config.RadioOpenCommand or 'radio')
    cb('ok')
end)
