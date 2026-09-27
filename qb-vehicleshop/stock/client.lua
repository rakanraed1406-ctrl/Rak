--[[ stock/client.lua — stock showroom display cars + qb-target "Buy" (no test drive) ]]

local QBCore = exports['qb-core']:GetCoreObject()
local VSC = { nuiFocus = false }

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
        print(('[qb-vehicleshop stock] model "%s" does not exist — check config.lua'):format(model))
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
-- Delivery (showroom purchase): spawn owned car, give keys
-- ---------------------------------------------------------------------------

local function setFuel(veh)
    local res = Config.Stock.FuelResource
    if res and res ~= '' and GetResourceState(res) == 'started' then
        local ok = pcall(function() exports[res]:SetFuel(veh, 100.0) end)
        if ok then return end
    end
    SetVehicleFuelLevel(veh, 100.0)
end

RegisterNetEvent('qb-vehicleshop:stock:client:deliverVehicle', function(data)
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
            if Config.Stock.WarpIntoVehicle then TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1) end
            Config.Stock.GiveKeys(veh, data.plate)
            SetVehicleEngineOn(veh, true, true, false)
        end
        Wait(300)
        DoScreenFadeIn(300)
    end, data.model, vector4(data.spawn.x, data.spawn.y, data.spawn.z, data.spawn.w or 0.0), true)
end)

RegisterNetEvent('qb-vehicleshop:stock:client:printCoords', function()
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    local line = ('vector4(%.2f, %.2f, %.2f, %.1f)'):format(c.x, c.y, c.z, GetEntityHeading(ped))
    print(line)
    QBCore.Functions.Notify(line .. ' (F8)', 'primary', 8000)
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and VSC.nuiFocus then SetNuiFocus(false, false) end
end)

local stock = {}        -- same shape as server VS.Stock
local spawned = {}      -- ["store|slot"] = vehicle handle
local blips = {}
local pendingBuy = nil  -- { storeId, slotId } while the confirm dialog is open

local function key(storeId, slotId) return storeId .. '|' .. slotId end

local function despawn(k)
    local veh = spawned[k]
    if veh then
        if DoesEntityExist(veh) then exports['qb-target']:RemoveTargetEntity(veh) end
        VSC.DeleteLocal(veh)
        spawned[k] = nil
    end
end

local function despawnAll()
    for k in pairs(spawned) do despawn(k) end
end

local function openConfirm(storeId, slotId)
    local slot = stock[storeId] and stock[storeId][slotId]
    if not slot or slot.sold then return end
    pendingBuy = { storeId = storeId, slotId = slotId }
    VSC.Focus(true)
    SendNUIMessage({
        action = 'buyConfirm',
        vehicle = { label = slot.label, model = slot.model, price = slot.price, category = slot.categoryLabel },
        store = Config.Stock.Stores[storeId] and Config.Stock.Stores[storeId].label or '',
    })
end

local function spawnSlot(storeId, slot)
    local k = key(storeId, slot.id)
    if spawned[k] or slot.sold then return end
    local veh = VSC.SpawnDisplay(slot.model, slot.coords, 'FORSALE')
    if not veh then return end
    spawned[k] = veh
    exports['qb-target']:AddTargetEntity(veh, {
        options = {
            {
                icon = 'fas fa-dollar-sign',
                label = Config.StockLang.buy_target:format(slot.label, VSC.FormatMoney(slot.price)),
                action = function() openConfirm(storeId, slot.id) end,
            },
        },
        distance = 3.0,
    })
end

-- Stream display cars in/out by distance (only nearby players render them).
CreateThread(function()
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        for storeId, slots in pairs(stock) do
            for slotId, slot in pairs(slots) do
                local k = key(storeId, slotId)
                local d = #(pos - vector3(slot.coords.x, slot.coords.y, slot.coords.z))
                if not slot.sold and d < (Config.Stock.DisplayDistance or 90.0) then
                    if not spawned[k] then spawnSlot(storeId, slot) end
                elseif spawned[k] then
                    despawn(k)
                end
            end
        end
        Wait(1000)
    end
end)

-- Price text above the cars.
CreateThread(function()
    while true do
        local sleep = 1000
        if Config.Stock.Show3DText then
            local pos = GetEntityCoords(PlayerPedId())
            for storeId, slots in pairs(stock) do
                for slotId, slot in pairs(slots) do
                    if not slot.sold and spawned[key(storeId, slotId)] then
                        local d = #(pos - vector3(slot.coords.x, slot.coords.y, slot.coords.z))
                        if d < 10.0 then
                            sleep = 0
                            VSC.Draw3DText(slot.coords.x, slot.coords.y, slot.coords.z + 1.4,
                                ('~b~%s~s~ · %s~n~~g~$%s'):format(slot.categoryLabel, slot.label, VSC.FormatMoney(slot.price)))
                        end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

local function applyStock(newStock)
    despawnAll()
    stock = newStock or {}
end

RegisterNetEvent('qb-vehicleshop:stock:client:stock', function(newStock) applyStock(newStock) end)

RegisterNetEvent('qb-vehicleshop:stock:client:slotSold', function(storeId, slotId)
    local slot = stock[storeId] and stock[storeId][slotId]
    if slot then slot.sold = true end
    despawn(key(storeId, slotId))
    if pendingBuy and pendingBuy.storeId == storeId and pendingBuy.slotId == slotId then
        pendingBuy = nil
        VSC.Focus(false)
        SendNUIMessage({ action = 'closeAll' })
    end
end)

RegisterNUICallback('buyConfirm', function(data, cb)
    VSC.Focus(false)
    if data.confirm and pendingBuy then
        TriggerServerEvent('qb-vehicleshop:stock:server:buy', pendingBuy.storeId, pendingBuy.slotId)
    end
    pendingBuy = nil
    cb('ok')
end)

local function loadStock()
    QBCore.Functions.TriggerCallback('qb-vehicleshop:stock:server:getStock', function(s) applyStock(s) end)
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', loadStock)
CreateThread(function()
    Wait(2000)
    if LocalPlayer.state.isLoggedIn then loadStock() end

    for storeId, store in pairs(Config.Stock.Stores) do
        local b = store.blip
        if b and b.enabled ~= false and b.coords then
            local blip = AddBlipForCoord(b.coords.x, b.coords.y, b.coords.z)
            SetBlipSprite(blip, b.sprite or 326)
            SetBlipColour(blip, b.color or 3)
            SetBlipScale(blip, b.scale or 0.75)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(store.label or storeId)
            EndTextCommandSetBlipName(blip)
            blips[#blips + 1] = blip
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    despawnAll()
    for _, b in ipairs(blips) do RemoveBlip(b) end
end)
