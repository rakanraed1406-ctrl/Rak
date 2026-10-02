--[[ common/client.lua — helpers shared by the client files: NUI focus, local
     display cars, taking over a car the server spawned, and the test drive
     (stock showroom + old showroom use the same one). ]]

local QBCore = exports['qb-core']:GetCoreObject()
VShopC = { nuiFocus = false }

function VShopC.Focus(state)
    VShopC.nuiFocus = state
    SetNuiFocus(state, state)
end

function VShopC.LoadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then return nil end
    RequestModel(hash)
    local timeout = GetGameTimer() + 8000
    while not HasModelLoaded(hash) do
        if GetGameTimer() > timeout then return nil end
        Wait(10)
    end
    return hash
end

--- Local (non-networked) display car: frozen, locked, can't be damaged.
function VShopC.SpawnDisplay(model, c, plateText)
    local hash = VShopC.LoadModel(model)
    if not hash then
        print(('[qb-vehicleshop] model "%s" does not exist — check the config'):format(model))
        return nil
    end
    local veh = CreateVehicle(hash, c.x, c.y, c.z, c.w or 0.0, false, false)
    SetModelAsNoLongerNeeded(hash)
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleOnGroundProperly(veh)
    FreezeEntityPosition(veh, true)
    SetEntityInvincible(veh, true)
    SetEntityCanBeDamaged(veh, false)
    SetVehicleDoorsLocked(veh, 2)
    SetVehicleDirtLevel(veh, 0.0)
    SetVehicleNumberPlateText(veh, plateText or 'FORSALE')
    SetVehicleEngineOn(veh, false, true, true)
    return veh
end

function VShopC.DeleteLocal(veh)
    if veh and DoesEntityExist(veh) then
        SetEntityAsMissionEntity(veh, true, true)
        DeleteVehicle(veh)
    end
end

function VShopC.Draw3DText(x, y, z, text)
    SetDrawOrigin(x, y, z, 0)
    SetTextScale(0.34, 0.34)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextColour(255, 255, 255, 230)
    SetTextOutline()
    SetTextCentre(true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

VShopC.FormatMoney = VShared.Comma

function VShopC.AddBlip(coords, sprite, color, scale, label)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, sprite or 326)
    SetBlipDisplay(blip, 4)
    SetBlipColour(blip, color or 3)
    SetBlipScale(blip, scale or 0.7)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label or 'Vehicle Shop')
    EndTextCommandSetBlipName(blip)
    return blip
end

-- ---------------------------------------------------------------------------
-- Taking over a car the server spawned (purchase / auction win / test drive)
-- ---------------------------------------------------------------------------
local function cfgFor(name)
    if name == 'stock' then return Config.Stock end
    if name == 'auction' then return Config.Auction end
    return nil
end

local function setFuel(veh, cfg)
    local res = cfg and cfg.FuelResource
    if res == nil then res = 'LegacyFuel' end
    if res ~= '' and GetResourceState(res) == 'started' then
        if pcall(function() exports[res]:SetFuel(veh, 100.0) end) then return end
    end
    SetVehicleFuelLevel(veh, 100.0)
end

local function giveKeys(veh, plate, cfg)
    if cfg and cfg.GiveKeys then
        cfg.GiveKeys(veh, plate)
    else
        TriggerEvent('vehiclekeys:client:SetOwner', plate)
    end
end

local function waitForVehicle(netId, ms)
    local timeout = GetGameTimer() + (ms or 8000)
    while not NetworkDoesNetworkIdExist(netId) do
        if GetGameTimer() > timeout then return nil end
        Wait(25)
    end
    local veh = NetToVeh(netId)
    while not DoesEntityExist(veh) do
        if GetGameTimer() > timeout then return nil end
        Wait(25)
        veh = NetToVeh(netId)
    end
    return veh
end

local function prepareVehicle(veh, plate, warp, cfg)
    local timeout = GetGameTimer() + 1500
    while not NetworkHasControlOfEntity(veh) and GetGameTimer() < timeout do
        NetworkRequestControlOfEntity(veh)
        Wait(25)
    end
    SetVehicleNumberPlateText(veh, plate)
    SetVehicleDirtLevel(veh, 0.0)
    setFuel(veh, cfg)
    if warp then
        local ped = PlayerPedId()
        timeout = GetGameTimer() + 3000
        while GetVehiclePedIsIn(ped, false) ~= veh and GetGameTimer() < timeout do
            TaskWarpPedIntoVehicle(ped, veh, -1)
            Wait(100)
        end
    end
    giveKeys(veh, plate, cfg)
    SetVehicleEngineOn(veh, true, true, false)
end

RegisterNetEvent('qb-vehicleshop:client:takeVehicle', function(netId, plate, data)
    if type(netId) ~= 'number' or type(plate) ~= 'string' then return end
    data = type(data) == 'table' and data or {}
    local fade = data.warp and not IsScreenFadedOut()
    if fade then
        DoScreenFadeOut(250)
        Wait(300)
    end
    local veh = waitForVehicle(netId, 10000)
    if veh then prepareVehicle(veh, plate, data.warp, cfgFor(data.cfg)) end
    if fade then
        Wait(200)
        DoScreenFadeIn(300)
    end
end)

-- ---------------------------------------------------------------------------
-- Test drive
-- ---------------------------------------------------------------------------
local testDrive = nil

function VShopC.InTestDrive() return testDrive ~= nil end

local function tdMessage(kind, key, arg)
    if kind == 'legacy' then
        if key == 'started' then return Lang:t('general.testdrive_timenoti', { testdrivetime = ('%g'):format((arg or 60) / 60) }) end
        return Lang:t('general.testdrive_complete')
    end
    local L = Config.StockLang
    if key == 'started' then return L.testdrive_started:format(arg) end
    if key == 'left' then return L.testdrive_left end
    return L.testdrive_ended
end

local function endTestDrive(reason, teleport)
    local td = testDrive
    if not td then return end
    testDrive = nil
    SendNUIMessage({ action = 'vsTestDrive', show = false })
    DoScreenFadeOut(300)
    Wait(350)
    local ped = PlayerPedId()
    if td.veh and DoesEntityExist(td.veh) then
        if GetVehiclePedIsIn(ped, false) == td.veh then TaskLeaveVehicle(ped, td.veh, 16) end
        SetEntityAsMissionEntity(td.veh, true, true)
        DeleteVehicle(td.veh)
    end
    TriggerServerEvent('qb-vehicleshop:server:testDriveEnd') -- the server deletes its copy too
    if teleport ~= false and td.prev then
        SetEntityCoords(ped, td.prev.x, td.prev.y, td.prev.z - 0.9, false, false, false, false)
    end
    Wait(300)
    DoScreenFadeIn(400)
    QBCore.Functions.Notify(tdMessage(td.kind, reason), 'primary')
end

local function watchTestDrive(veh, d)
    CreateThread(function()
        local outSince = nil
        local graceUntil = GetGameTimer() + 2000
        local leaveMs = (tonumber(d.leaveSeconds) or 3) * 1000
        local ret = d.returnCoords and vector3(d.returnCoords.x, d.returnCoords.y, d.returnCoords.z)
        while testDrive and testDrive.veh == veh do
            local now = GetGameTimer()
            local ped = PlayerPedId()
            if now >= testDrive.endsAt or not DoesEntityExist(veh) or IsEntityDead(veh) then
                endTestDrive('ended')
                break
            end
            if now > graceUntil and GetPedInVehicleSeat(veh, -1) ~= ped then
                outSince = outSince or now
                if now - outSince > leaveMs then
                    endTestDrive('left')
                    break
                end
            else
                outSince = nil
            end
            -- old showroom: driving back into the return spot ends it there
            if ret and now > graceUntil and #(GetEntityCoords(ped) - ret) < 4.0 then
                endTestDrive('ended', false)
                break
            end
            Wait(250)
        end
    end)
end

RegisterNetEvent('qb-vehicleshop:client:testDriveStart', function(netId, d)
    if testDrive or type(netId) ~= 'number' or type(d) ~= 'table' then return end
    local ped = PlayerPedId()
    testDrive = { prev = GetEntityCoords(ped), kind = d.kind, pending = true }
    DoScreenFadeOut(250)
    Wait(300)

    local veh = waitForVehicle(netId, 10000)
    if not veh or not testDrive then
        testDrive = nil
        TriggerServerEvent('qb-vehicleshop:server:testDriveEnd')
        DoScreenFadeIn(300)
        return
    end

    prepareVehicle(veh, d.plate or 'TESTDRIVE', true, cfgFor(d.cfg))
    local seconds = tonumber(d.seconds) or 60
    testDrive.veh = veh
    testDrive.pending = false
    testDrive.endsAt = GetGameTimer() + seconds * 1000
    SendNUIMessage({ action = 'vsTestDrive', show = true, seconds = seconds, label = d.label })
    Wait(300)
    DoScreenFadeIn(300)
    QBCore.Functions.Notify(tdMessage(d.kind, 'started', seconds), 'success')
    watchTestDrive(veh, d)
end)

RegisterNetEvent('qb-vehicleshop:client:testDriveStop', function()
    if testDrive and not testDrive.pending then endTestDrive('ended') end
end)

-- ---------------------------------------------------------------------------
-- NUI plumbing
-- ---------------------------------------------------------------------------
RegisterNUICallback('close', function(_, cb)
    VShopC.Focus(false)
    cb('ok')
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if VShopC.nuiFocus then SetNuiFocus(false, false) end
    if testDrive then
        if testDrive.veh and DoesEntityExist(testDrive.veh) then DeleteVehicle(testDrive.veh) end
        DoScreenFadeIn(0)
    end
end)
