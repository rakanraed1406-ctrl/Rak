local QBCore = exports['qb-core']:GetCoreObject()

local function isAllowed()
    local player = QBCore.Functions.GetPlayerData()
    return player and player.citizenid and Config.AllowedCitizens[player.citizenid] == true
end

CreateThread(function()
    RequestModel(Config.Bot.model)
    local timeout = GetGameTimer() + 10000
    while not HasModelLoaded(Config.Bot.model) do
        if GetGameTimer() > timeout then return print('[qb-militaryhelipad] pilot model did not load') end
        Wait(50)
    end

    local c = Config.Bot.coords
    local ped = CreatePed(4, Config.Bot.model, c.x, c.y, c.z - 1.0, c.w, false, true)
    SetModelAsNoLongerNeeded(Config.Bot.model)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)

    exports.interact:AddLocalEntityInteraction({
        entity = ped,
        name = 'helicopter_bot',
        id = 'helicopter_bot_interaction',
        distance = 3.0,
        options = {
            {
                label = 'Open Helicopter Menu',
                canInteract = isAllowed,
                action = function() OpenHeliMenu() end,
            }
        }
    })
end)

local function plateOf(vehicle)
    return (string.gsub(GetVehicleNumberPlateText(vehicle) or '', "^%s*(.-)%s*$", "%1"))
end

-- aircraft near the player (the server checks again before storing)
function OpenHeliMenu()
    local coords = GetEntityCoords(PlayerPedId())
    local nearbyHelis = {}
    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        local model = GetEntityModel(vehicle)
        if (IsThisModelAHeli(model) or IsThisModelAPlane(model)) and #(coords - GetEntityCoords(vehicle)) <= 35.0 then
            nearbyHelis[#nearbyHelis + 1] = {
                plate = plateOf(vehicle),
                model = string.lower(GetDisplayNameFromVehicleModel(model)),
            }
        end
    end

    QBCore.Functions.TriggerCallback('qb-militaryhelipad-byrko:server:GetOwnedHelicopters', function(ownedHelis)
        local shop = {}
        for i, h in ipairs(Config.Helicopters) do shop[i] = { model = h.model, label = h.label, price = h.price } end
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = "open",
            shopHelis = shop,
            ownedHelis = ownedHelis or {},
            nearbyHelis = nearbyHelis
        })
    end)
end

RegisterNUICallback('close', function(_, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('buyHeli', function(data, cb)
    SetNuiFocus(false, false)
    if type(data) == 'table' then TriggerServerEvent('qb-militaryhelipad-byrko:server:BuyHelicopter', data.model) end
    cb('ok')
end)

RegisterNUICallback('spawnOwnedHeli', function(data, cb)
    SetNuiFocus(false, false)
    if type(data) == 'table' then TriggerServerEvent('qb-militaryhelipad-byrko:server:SpawnOwnedHeli', data.plate) end
    cb('ok')
end)

-- the server finds the aircraft, checks it and deletes it
RegisterNUICallback('storeSpecificHeli', function(data, cb)
    SetNuiFocus(false, false)
    if type(data) == 'table' then TriggerServerEvent('qb-militaryhelipad-byrko:server:StoreHelicopter', data.plate) end
    cb('ok')
end)

-- the server spawned it: take control, warp in, keys
RegisterNetEvent('qb-militaryhelipad-byrko:client:TakeHelicopter', function(netId, plate)
    if type(netId) ~= 'number' or type(plate) ~= 'string' then return end
    local timeout = GetGameTimer() + 10000
    while not NetworkDoesNetworkIdExist(netId) do
        if GetGameTimer() > timeout then return end
        Wait(25)
    end
    local vehicle = NetToVeh(netId)
    while not DoesEntityExist(vehicle) do
        if GetGameTimer() > timeout then return end
        Wait(25)
        vehicle = NetToVeh(netId)
    end
    local ctl = GetGameTimer() + 1500
    while not NetworkHasControlOfEntity(vehicle) and GetGameTimer() < ctl do
        NetworkRequestControlOfEntity(vehicle)
        Wait(25)
    end
    SetVehicleNumberPlateText(vehicle, plate)
    local ped = PlayerPedId()
    local warp = GetGameTimer() + 3000
    while GetVehiclePedIsIn(ped, false) ~= vehicle and GetGameTimer() < warp do
        TaskWarpPedIntoVehicle(ped, vehicle, -1)
        Wait(100)
    end
    Config.GiveKeys(vehicle, plate)
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then SetNuiFocus(false, false) end
end)
