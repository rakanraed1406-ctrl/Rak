--[[ client/main.lua — shared client helpers: NUI, display vehicles, delivery ]]

QBCore = exports['qb-core']:GetCoreObject()
VSC = { nuiFocus = false }

function VSC.Focus(state)
    VSC.nuiFocus = state
    SetNuiFocus(state, state)
end

function VSC.LoadModel(model)
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

--- Local (non-networked) showroom car: frozen, locked, can't be damaged.
function VSC.SpawnDisplay(model, c, plateText)
    local hash = VSC.LoadModel(model)
    if not hash then
        print(('[rk-vehiclesales] model "%s" does not exist — check config.lua'):format(model))
        return nil
    end
    local veh = CreateVehicle(hash, c.x, c.y, c.z, c.w or 0.0, false, false)
    SetModelAsNoLongerNeeded(hash)
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleOnGroundProperly(veh)
    FreezeEntityPosition(veh, true)
    SetEntityInvincible(veh, true)
    SetVehicleDoorsLocked(veh, 2)
    SetVehicleDirtLevel(veh, 0.0)
    SetVehicleNumberPlateText(veh, plateText or 'FORSALE')
    SetVehicleEngineOn(veh, false, true, true)
    SetEntityCanBeDamaged(veh, false)
    return veh
end

function VSC.DeleteLocal(veh)
    if veh and DoesEntityExist(veh) then
        SetEntityAsMissionEntity(veh, true, true)
        DeleteVehicle(veh)
    end
end

function VSC.Draw3DText(x, y, z, text)
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

function VSC.FormatMoney(n)
    local s = tostring(math.floor(tonumber(n) or 0))
    return (s:reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', ''))
end

-- ---------------------------------------------------------------------------
-- Delivery (showroom purchase + auction win): spawn owned car, give keys
-- ---------------------------------------------------------------------------

local function setFuel(veh)
    local res = Config.FuelResource
    if res and res ~= '' and GetResourceState(res) == 'started' then
        local ok = pcall(function() exports[res]:SetFuel(veh, 100.0) end)
        if ok then return end
    end
    SetVehicleFuelLevel(veh, 100.0)
end

RegisterNetEvent('rk-vehiclesales:client:deliverVehicle', function(data)
    if type(data) ~= 'table' or not data.model or not data.spawn then return end
    DoScreenFadeOut(250)
    Wait(300)
    QBCore.Functions.TriggerCallback('QBCore:Server:SpawnVehicle', function(netId)
        local veh = NetToVeh(netId)
        local timeout = GetGameTimer() + 5000
        while not DoesEntityExist(veh) and GetGameTimer() < timeout do
            Wait(10)
            veh = NetToVeh(netId)
        end
        if DoesEntityExist(veh) then
            SetVehicleNumberPlateText(veh, data.plate)
            SetEntityHeading(veh, data.spawn.w or 0.0)
            SetVehicleDirtLevel(veh, 0.0)
            setFuel(veh)
            if Config.WarpIntoVehicle then TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1) end
            Config.GiveKeys(veh, data.plate)
            SetVehicleEngineOn(veh, true, true, false)
        end
        Wait(300)
        DoScreenFadeIn(300)
    end, data.model, vector4(data.spawn.x, data.spawn.y, data.spawn.z, data.spawn.w or 0.0), true)
end)

RegisterNetEvent('rk-vehiclesales:client:printCoords', function()
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    local line = ('vector4(%.2f, %.2f, %.2f, %.1f)'):format(c.x, c.y, c.z, GetEntityHeading(ped))
    print(line)
    QBCore.Functions.Notify(line .. ' (F8)', 'primary', 8000)
end)

-- ---------------------------------------------------------------------------
-- NUI plumbing
-- ---------------------------------------------------------------------------

RegisterNUICallback('close', function(_, cb)
    VSC.Focus(false)
    cb('ok')
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and VSC.nuiFocus then SetNuiFocus(false, false) end
end)
