--[[ client/stock.lua — showroom display cars + qb-target "Buy" (no test drive) ]]

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
        store = Config.Stores[storeId] and Config.Stores[storeId].label or '',
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
                label = Config.Lang.buy_target:format(slot.label, VSC.FormatMoney(slot.price)),
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
                if not slot.sold and d < (Config.DisplayDistance or 90.0) then
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
        if Config.Show3DText then
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

RegisterNetEvent('rk-vehiclesales:client:stock', function(newStock) applyStock(newStock) end)

RegisterNetEvent('rk-vehiclesales:client:slotSold', function(storeId, slotId)
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
        TriggerServerEvent('rk-vehiclesales:server:buy', pendingBuy.storeId, pendingBuy.slotId)
    end
    pendingBuy = nil
    cb('ok')
end)

local function loadStock()
    QBCore.Functions.TriggerCallback('rk-vehiclesales:server:getStock', function(s) applyStock(s) end)
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', loadStock)
CreateThread(function()
    Wait(2000)
    if LocalPlayer.state.isLoggedIn then loadStock() end

    for storeId, store in pairs(Config.Stores) do
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
