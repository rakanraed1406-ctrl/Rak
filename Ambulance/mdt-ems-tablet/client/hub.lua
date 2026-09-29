--[[ client/hub.lua - EMS Hub inside the tablet: presence, duty, status, callsign,
     PANIC, department chat and team blips. ]]

local QBCore = MDTClient.QBCore
local HubCfg = Config.Hub or {}

MDTClient.onDuty = false
MDTClient.unitBlips = {}

local function isEms(job)
    return job and job.name == Config.JobName
end

local function refreshDuty()
    local pd = QBCore.Functions.GetPlayerData()
    MDTClient.onDuty = pd and isEms(pd.job) and pd.job.onduty == true or false
end

-- ---------------------------------------------------------------------------
-- Location helpers
-- ---------------------------------------------------------------------------

function MDTClient.GetStreetName(coords)
    coords = coords or GetEntityCoords(PlayerPedId())
    local streetHash, crossingHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local street = GetStreetNameFromHashKey(streetHash)
    if crossingHash and crossingHash ~= 0 then
        local crossing = GetStreetNameFromHashKey(crossingHash)
        if crossing and crossing ~= '' then street = street .. ' / ' .. crossing end
    end
    if not street or street == '' then
        street = GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z))
    end
    return (street and street ~= '' and street ~= 'NULL') and street or 'Los Santos'
end

local function getTransport()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then return 'person', 'On foot' end
    local class = GetVehicleClass(GetVehiclePedIsIn(ped, false))
    if class == 8 or class == 13 then return 'bike', 'Motorcycle' end
    if class == 15 then return 'helicopter', 'Air unit' end
    if class == 16 then return 'plane', 'Aircraft' end
    if class == 14 then return 'boat', 'Marine unit' end
    return 'car', 'Ambulance'
end

local function getRadio()
    local ok, channel = pcall(function() return LocalPlayer.state.radioChannel end)
    channel = ok and tonumber(channel) or nil
    return (channel and channel > 0) and channel or false
end

-- Presence: light payload every few seconds, server stores it (no broadcast storm).
CreateThread(function()
    while true do
        Wait(HubCfg.PresenceInterval or 5000)
        refreshDuty()
        if MDTClient.onDuty then
            local vType, transport = getTransport()
            TriggerServerEvent('ems-mdt:server:HubPresence', {
                street = MDTClient.GetStreetName(),
                vehicleType = vType,
                transport = transport,
                radio = getRadio(),
                siren = (function()
                    local ped = PlayerPedId()
                    local veh = GetVehiclePedIsIn(ped, false)
                    return veh ~= 0 and IsVehicleSirenOn(veh) or false
                end)(),
            })
        elseif next(MDTClient.unitBlips) then
            MDTClient.ClearUnitBlips()
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Team blips (from the roster push)
-- ---------------------------------------------------------------------------

function MDTClient.ClearUnitBlips()
    for _, blip in pairs(MDTClient.unitBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    MDTClient.unitBlips = {}
end

local function updateUnitBlips(roster, selfId)
    if not HubCfg.UnitBlips or not MDTClient.onDuty then
        if next(MDTClient.unitBlips) then MDTClient.ClearUnitBlips() end
        return
    end

    local seen = {}
    for _, m in ipairs(roster) do
        if m.duty and m.coords and m.id ~= selfId then
            seen[m.id] = true
            local sprite = (HubCfg.UnitBlipSprites or {})[m.vehicleType] or 1
            local blip = MDTClient.unitBlips[m.id]
            if not blip or not DoesBlipExist(blip) then
                blip = AddBlipForCoord(m.coords.x, m.coords.y, m.coords.z)
                SetBlipAsShortRange(blip, true)
                MDTClient.unitBlips[m.id] = blip
            else
                SetBlipCoords(blip, m.coords.x, m.coords.y, m.coords.z)
            end
            SetBlipSprite(blip, sprite)
            SetBlipScale(blip, HubCfg.UnitBlipScale or 0.8)
            SetBlipColour(blip, m.isPanic and (HubCfg.PanicBlipColor or 5) or (HubCfg.UnitBlipColor or 1))
            local flash = m.isPanic == true or (Config.Alerts and Config.Alerts.FlashBlipOnSiren and m.siren == true)
            SetBlipFlashes(blip, flash)
            ShowHeadingIndicatorOnBlip(blip, sprite == 1)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(('[%s] %s'):format(m.callsign, m.name))
            EndTextCommandSetBlipName(blip)
        end
    end

    for id, blip in pairs(MDTClient.unitBlips) do
        if not seen[id] then
            if DoesBlipExist(blip) then RemoveBlip(blip) end
            MDTClient.unitBlips[id] = nil
        end
    end
end

RegisterNetEvent('ems-mdt:client:HubRoster', function(roster, selfId)
    refreshDuty()
    updateUnitBlips(roster or {}, selfId)
    if MDTClient.mdtOpen then
        SendNUIMessage({ action = 'hubRoster', roster = roster or {}, selfId = selfId })
    end
end)

RegisterNetEvent('ems-mdt:client:HubChatHistory', function(history)
    SendNUIMessage({ action = 'hubChatHistory', history = history or {} })
end)

RegisterNetEvent('ems-mdt:client:HubChatMessage', function(channel, msg)
    SendNUIMessage({ action = 'hubChatMessage', channel = channel, message = msg })
end)

RegisterNetEvent('ems-mdt:client:HubDutyChanged', function(onDuty)
    MDTClient.onDuty = onDuty == true
    if not MDTClient.onDuty then MDTClient.ClearUnitBlips() end
    SendNUIMessage({ action = 'dutyChanged', onDuty = MDTClient.onDuty })
end)

RegisterNetEvent('ems-mdt:client:HubStatusChanged', function(status)
    SendNUIMessage({ action = 'statusChanged', status = status })
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    MDTClient.onDuty = false
    MDTClient.ClearUnitBlips()
end)

-- ---------------------------------------------------------------------------
-- NUI callbacks
-- ---------------------------------------------------------------------------

RegisterNUICallback('hubSetDuty', function(data, cb)
    TriggerServerEvent('ems-mdt:server:HubSetDuty', data.onDuty == true)
    cb('ok')
end)

RegisterNUICallback('hubSetStatus', function(data, cb)
    TriggerServerEvent('ems-mdt:server:HubSetStatus', data.status)
    cb('ok')
end)

RegisterNUICallback('hubSetCallsign', function(data, cb)
    TriggerServerEvent('ems-mdt:server:HubSetCallsign', data.callsign)
    cb('ok')
end)

RegisterNUICallback('hubChat', function(data, cb)
    TriggerServerEvent('ems-mdt:server:HubChat', data.channel, data.text)
    cb('ok')
end)

RegisterNUICallback('setWaypoint', function(data, cb)
    local x, y = tonumber(data.x), tonumber(data.y)
    if x and y then
        SetNewWaypoint(x + 0.0, y + 0.0)
        QBCore.Functions.Notify(data.label and ('GPS set: ' .. tostring(data.label):sub(1, 40)) or 'GPS waypoint set.', 'success')
    end
    cb('ok')
end)

-- ---------------------------------------------------------------------------
-- PANIC
-- ---------------------------------------------------------------------------

function MDTClient.TriggerPanic()
    TriggerServerEvent('ems-mdt:server:HubPanic', { street = MDTClient.GetStreetName() })
end

RegisterNUICallback('hubPanic', function(_, cb)
    MDTClient.TriggerPanic()
    cb('ok')
end)

local panicCmd = Config.Dispatch.PanicCommand or 'emspanic'
RegisterCommand(panicCmd, function()
    local pd = QBCore.Functions.GetPlayerData()
    if not pd or not isEms(pd.job) then return end
    MDTClient.TriggerPanic()
end, false)
RegisterKeyMapping(panicCmd, 'EMS Tablet: Medic panic button (10-99)', 'keyboard', Config.Dispatch.PanicKey or '')

-- Legacy hook some scripts still fire (only acts for EMS — the police MDT handles police).
RegisterNetEvent('cd_dispatch:PanicButtonEvent', function()
    local pd = QBCore.Functions.GetPlayerData()
    if pd and isEms(pd.job) then MDTClient.TriggerPanic() end
end)

RegisterNetEvent('ems-mdt:client:PanicAlert', function(info)
    if type(info) ~= 'table' or not info.coords then return end
    ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.2)
    SetTimeout(900, function() StopGameplayCamShaking(true) end)

    local blip = AddBlipForCoord(info.coords.x, info.coords.y, info.coords.z)
    SetBlipSprite(blip, 526)
    SetBlipColour(blip, HubCfg.PanicBlipColor or 5)
    SetBlipScale(blip, 1.2)
    SetBlipFlashes(blip, true)
    SetBlipPriority(blip, 12)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(('10-99 MEDIC PANIC: [%s] %s'):format(info.callsign or '?', info.name or 'Medic'))
    EndTextCommandSetBlipName(blip)
    SetTimeout(HubCfg.PanicBlipDuration or 90000, function()
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    MDTClient.ClearUnitBlips()
end)
