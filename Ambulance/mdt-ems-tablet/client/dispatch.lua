--[[ client/dispatch.lua - EMS dispatch: notifications (with the tablet closed too),
     respond / dismiss keybinds, CAD NUI callbacks, command broadcasts, radio,
     client export + cd_dispatch GetPlayerInfo compatibility. ]]

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
            department = Config.Department or {},
            panicCommand = DCfg.PanicCommand or 'emspanic',
            muteCommand = 'emdtmute',
            replyCommand = DCfg.ReplyCommand or '997r',
            statuses = DCfg.Statuses,
            protocols = Config.Protocols or {},
            radioCodes = Config.RadioCodes or {},
            billingPresets = (Config.Billing and Config.Billing.Presets) or {},
            billingCharges = Config.Billing and Config.Billing.ChargePatient == true,
            billingMax = (Config.Billing and Config.Billing.MaxAmount) or 50000,
            pointsEnabled = Config.Points and Config.Points.Enabled == true,
            pointsMax = (Config.Points and Config.Points.MaxPerAction) or 100,
            panicPolice = DCfg.PanicAlsoAlertsPolice == true,
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

RegisterNetEvent('ems-mdt:client:DispatchNotify', function(call, serverTime)
    SendNUIMessage({ action = 'dispatchNotify', call = call, serverTime = serverTime })
end)

RegisterNetEvent('ems-mdt:client:DispatchSync', function(payload)
    SendNUIMessage({ action = 'dispatchSync', payload = payload })
end)

RegisterNetEvent('ems-mdt:client:DispatchCount', function(count)
    SendNUIMessage({ action = 'dispatchCount', count = count })
end)

RegisterNetEvent('ems-mdt:client:DispatchAssigned', function(call, byName)
    if type(call) ~= 'table' then return end
    QBCore.Functions.Notify(('Dispatch assigned you to %s %s'):format(call.code or '', call.title or ''), 'primary', 7000)
    if call.coords then SetNewWaypoint(call.coords.x + 0.0, call.coords.y + 0.0) end
    SendNUIMessage({ action = 'dispatchAssigned', call = call, by = byName })
end)

RegisterNetEvent('ems-mdt:client:Request911Street', function(callId)
    TriggerServerEvent('ems-mdt:server:Update911Street', callId, MDTClient.GetStreetName())
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
    TriggerServerEvent('ems-mdt:server:DispatchRespond', data.callId)
    if setGps(data.coords) then QBCore.Functions.Notify('Responding — GPS set to the call.', 'success') end
    cb('ok')
end)

RegisterNUICallback('dispatchDetach', function(data, cb)
    TriggerServerEvent('ems-mdt:server:DispatchDetach', data.callId)
    cb('ok')
end)

RegisterNUICallback('dispatchGps', function(data, cb)
    if setGps(data.coords) then QBCore.Functions.Notify('GPS set to the call location.', 'success') end
    cb('ok')
end)

RegisterNUICallback('dispatchUpdate', function(data, cb)
    TriggerServerEvent('ems-mdt:server:DispatchUpdate', data)
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
    TriggerServerEvent('ems-mdt:server:DispatchCreateManual', data)
    cb('ok')
end)

RegisterNUICallback('dispatchRequestSync', function(_, cb)
    TriggerServerEvent('ems-mdt:server:DispatchRequestSync')
    cb('ok')
end)

RegisterNUICallback('toastState', function(data, cb)
    hudToast = (data and data.callId) and { callId = data.callId, coords = data.coords } or nil
    cb('ok')
end)

-- ---------------------------------------------------------------------------
-- Keybinds that work while the tablet is CLOSED (no NUI focus needed)
-- ---------------------------------------------------------------------------

RegisterCommand('emdt_dispatch_respond', function()
    if not hudToast or MDTClient.mdtOpen then return end
    TriggerServerEvent('ems-mdt:server:DispatchRespond', hudToast.callId)
    if setGps(hudToast.coords) then QBCore.Functions.Notify('Responding — GPS set to the call.', 'success') end
    SendNUIMessage({ action = 'toastResponded', callId = hudToast.callId })
end, false)
RegisterKeyMapping('emdt_dispatch_respond', 'EMS Tablet: Respond to dispatch notification', 'keyboard', DCfg.RespondKey or 'G')

RegisterCommand('emdt_dispatch_dismiss', function()
    if not hudToast or MDTClient.mdtOpen then return end
    SendNUIMessage({ action = 'toastDismiss' })
end, false)
RegisterKeyMapping('emdt_dispatch_dismiss', 'EMS Tablet: Dismiss dispatch notification', 'keyboard', DCfg.DismissKey or 'DELETE')

RegisterCommand('emdtmute', function()
    SendNUIMessage({ action = 'toggleMute' })
end, false)
RegisterKeyMapping('emdtmute', 'EMS Tablet: Mute / unmute dispatch sounds', 'keyboard', DCfg.MuteKey or '')

RegisterNUICallback('notifyMuteState', function(data, cb)
    QBCore.Functions.Notify(data.muted and 'EMS dispatch sounds muted.' or 'EMS dispatch sounds on.', 'primary')
    cb('ok')
end)

-- ---------------------------------------------------------------------------
-- Client-side export / event for other CLIENT scripts
-- ---------------------------------------------------------------------------

local function clientCreateDispatchCall(dept, data)
    if type(dept) == 'table' and data == nil then data, dept = dept, 'ambulance' end
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
    TriggerServerEvent('ems-mdt:server:ClientDispatchCall', dept or 'ambulance', data)
end

exports('CreateDispatchCall', clientCreateDispatchCall)
-- Event version for other CLIENT scripts (no folder name needed):
--   TriggerEvent('ems-mdt:client:CreateDispatchCall', { code = '10-52', title = 'Injured hiker', priority = 'medium' })
AddEventHandler('ems-mdt:client:CreateDispatchCall', function(data, dept)
    clientCreateDispatchCall(dept or 'ambulance', data)
end)

-- cd_dispatch compatibility: if cd_dispatch is removed, scripts that still call
-- exports['cd_dispatch']:GetPlayerInfo() keep working (same fields it returned).
-- While cd_dispatch itself is running, its own export answers instead.
if DCfg.CdDispatchCompat then
    local function cardinal(heading)
        local dirs = { 'North', 'North-West', 'West', 'South-West', 'South', 'South-East', 'East', 'North-East' }
        return dirs[(math.floor(((heading or 0.0) + 22.5) / 45.0) % 8) + 1]
    end

    local function GetPlayerInfo()
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local s1, s2 = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
        local street1, street2 = GetStreetNameFromHashKey(s1), GetStreetNameFromHashKey(s2)
        local info = {
            ped = ped, coords = coords,
            street_1 = street1, street_2 = street2,
            street = (street2 and street2 ~= '') and (street1 .. ', ' .. street2) or street1,
            sex = IsPedMale(ped) and 'Male' or 'Female',
        }
        local veh = GetVehiclePedIsIn(ped, false)
        if veh ~= 0 then
            local label = GetLabelText(GetDisplayNameFromVehicleModel(GetEntityModel(veh)))
            info.vehicle = veh
            info.vehicle_label = (label and label ~= 'NULL') and label or GetDisplayNameFromVehicleModel(GetEntityModel(veh))
            info.vehicle_plate = (GetVehicleNumberPlateText(veh) or ''):gsub('^%s*(.-)%s*$', '%1')
            info.heading = cardinal(GetEntityHeading(ped))
            info.speed = GetEntitySpeed(veh) * 2.236936
        end
        return info
    end

    AddEventHandler('__cfx_export_cd_dispatch_GetPlayerInfo', function(setCB)
        if GetResourceState('cd_dispatch') == 'started' then return end
        setCB(GetPlayerInfo)
    end)
end

-- ---------------------------------------------------------------------------
-- Command features (alert level / broadcast / all-units) + radio
-- ---------------------------------------------------------------------------

RegisterNUICallback('sendAlertMessage', function(data, cb)
    TriggerServerEvent('ems-mdt:server:BroadcastEmergencyAlert', data.message)
    cb('ok')
end)

RegisterNUICallback('setAlertLevel', function(data, cb)
    TriggerServerEvent('ems-mdt:server:SetAlertLevel', data.level)
    cb('ok')
end)

RegisterNUICallback('sendUnitsAlert', function(data, cb)
    TriggerServerEvent('ems-mdt:server:SendUnitsAlert', data.message)
    cb('ok')
end)

RegisterNetEvent('ems-mdt:client:AlertLevelChanged', function(level)
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
