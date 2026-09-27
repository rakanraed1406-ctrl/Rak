--[[ server/stock.lua — random stock per restart. Each spot of each category
     rolls one random vehicle from that category's list. Buying removes it
     until the next restock (server restart, /restockcars, or the timer). ]]

VS.Stock = {} -- [storeId] = { [slotId] = { id, category, categoryLabel, model, label, price, coords, sold } }

local function warnMissingModels()
    for storeId, store in pairs(Config.Stores) do
        for catId, cat in pairs(store.categories) do
            for _, v in ipairs(cat.vehicles or {}) do
                if not QBCore.Shared.Vehicles[v.model] then
                    print(('^3[rk-vehiclesales] "%s" (%s/%s) is not in qb-core/shared/vehicles.lua — garages may not show it.^0')
                        :format(v.model, storeId, catId))
                end
            end
        end
    end
end

function VS.Restock()
    VS.Stock = {}
    for storeId, store in pairs(Config.Stores) do
        local slots = {}
        for catId, cat in pairs(store.categories) do
            local pool = cat.vehicles or {}
            local spots = cat.spots or (cat.spot and { cat.spot }) or {}
            if #pool > 0 then
                -- Shuffle so several spots of the same category don't repeat a car
                -- while there are still other cars in the list.
                local bag = {}
                for i, v in ipairs(pool) do bag[i] = v end
                for i = #bag, 2, -1 do
                    local j = math.random(1, i)
                    bag[i], bag[j] = bag[j], bag[i]
                end
                for i, spot in ipairs(spots) do
                    local v = bag[((i - 1) % #bag) + 1]
                    local slotId = catId .. '_' .. i
                    slots[slotId] = {
                        id = slotId,
                        category = catId,
                        categoryLabel = cat.label or catId,
                        model = v.model,
                        label = v.label or VS.VehicleLabel(v.model),
                        price = math.floor(tonumber(v.price) or 0),
                        coords = { x = spot.x, y = spot.y, z = spot.z, w = spot.w },
                        sold = false,
                    }
                end
            end
        end
        VS.Stock[storeId] = slots
    end
    TriggerClientEvent('rk-vehiclesales:client:stock', -1, VS.Stock)
end

CreateThread(function()
    math.randomseed(os.time())
    Wait(1000) -- let qb-core shared vehicles load
    warnMissingModels()
    VS.Restock()

    local minutes = tonumber(Config.RestockEveryMinutes) or 0
    if minutes > 0 then
        while true do
            Wait(minutes * 60000)
            VS.Restock()
            TriggerClientEvent('QBCore:Notify', -1, Config.Lang.restocked, 'primary')
        end
    end
end)

QBCore.Functions.CreateCallback('rk-vehiclesales:server:getStock', function(_, cb)
    cb(VS.Stock)
end)

QBCore.Commands.Add('restockcars', 'Re-roll every vehicle showroom (admin)', {}, false, function(source)
    if not VS.IsAdmin(source) then return VS.Notify(source, Config.Lang.no_permission, 'error') end
    VS.Restock()
    VS.Notify(source, Config.Lang.restocked, 'success')
end)

local buyCooldown = {}

RegisterNetEvent('rk-vehiclesales:server:buy', function(storeId, slotId)
    local src = source
    local now = GetGameTimer()
    if buyCooldown[src] and now - buyCooldown[src] < 2000 then return end
    buyCooldown[src] = now

    local Player = QBCore.Functions.GetPlayer(src)
    local store = Config.Stores[storeId]
    local slot = VS.Stock[storeId] and VS.Stock[storeId][slotId]
    if not Player or not store or not slot then return end

    if slot.sold then return VS.Notify(src, Config.Lang.already_sold, 'error') end
    if VS.DistanceTo(src, slot.coords) > (Config.BuyDistance or 8.0) then
        return VS.Notify(src, Config.Lang.too_far, 'error')
    end
    if VS.Money(Player) < slot.price then
        return VS.Notify(src, Config.Lang.not_enough_money:format(slot.price), 'error')
    end

    -- Mark sold + take the money in the same tick (no await in between), so
    -- two players clicking at once can never both buy the same car.
    if not Player.Functions.RemoveMoney(Config.MoneyType, slot.price, 'vehicle-showroom') then
        return VS.Notify(src, Config.Lang.not_enough_money:format(slot.price), 'error')
    end
    slot.sold = true
    TriggerClientEvent('rk-vehiclesales:client:slotSold', -1, storeId, slotId)

    VS.GiveVehicle(src, slot.model, store.deliverySpawn, 'Showroom Purchase')
    VS.Notify(src, Config.Lang.bought:format(slot.label, slot.price), 'success', 7000)
end)

AddEventHandler('playerDropped', function() buyCooldown[source] = nil end)
