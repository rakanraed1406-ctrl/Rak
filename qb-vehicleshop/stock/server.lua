--[[ stock/server.lua — random stock showroom for qb-vehicleshop.
     Each spot of each category rolls one random vehicle per restart (/restockcars,
     optional timer). Buying removes it until the next restock.
     Purchases and test drives are spawned by the server (common/server.lua). ]]

local QBCore = VShop.QBCore
local SCfg, SLang = Config.Stock, Config.StockLang

local VS = { Stock = {} } -- [storeId] = { [slotId] = { id, category, categoryLabel, model, label, price, coords, sold, stats, type } }

-- Admin helper: prints your coords as a vector4 so filling the config is easy.
QBCore.Commands.Add('vscoords', 'Print your position as vector4 (vehicle sales setup)', {}, false, function(source)
    if not VShop.IsAdmin(source, SCfg.AdminGroups) then return VShop.Notify(source, SLang.no_permission, 'error') end
    TriggerClientEvent('qb-vehicleshop:stock:client:printCoords', source)
end)

local function checkConfig()
    for storeId, store in pairs(SCfg.Stores) do
        for catId, cat in pairs(store.categories) do
            for _, v in ipairs(cat.vehicles or {}) do
                if not QBCore.Shared.Vehicles[v.model] then
                    print(('^3[qb-vehicleshop stock] "%s" (%s/%s) is not in qb-core/shared/vehicles.lua — garages may not show it.^0')
                        :format(v.model, storeId, catId))
                end
                if (tonumber(v.price) or 0) <= 0 then
                    print(('^1[qb-vehicleshop stock] "%s" (%s/%s) has no price — it will not be put on sale.^0'):format(v.model, storeId, catId))
                end
            end
        end
    end
end

local function statOverride(v)
    local byModel = (SCfg.VehicleStats or {})[v.model] or {}
    local out, any = {}, false
    for _, k in ipairs({ 'speed', 'acceleration', 'braking', 'handling' }) do
        local val = tonumber(v[k]) or tonumber(byModel[k])
        if val then
            out[k] = val
            any = true
        end
    end
    return any and out or nil
end

function VS.Restock()
    local fresh = {}
    for storeId, store in pairs(SCfg.Stores) do
        local slots = {}
        for catId, cat in pairs(store.categories) do
            -- only cars with a real price can be sold
            local bag = {}
            for _, v in ipairs(cat.vehicles or {}) do
                if v.model and (tonumber(v.price) or 0) > 0 then bag[#bag + 1] = v end
            end
            local spots = cat.spots or (cat.spot and { cat.spot }) or {}
            if #bag > 0 then
                -- shuffle so several spots of the same category don't repeat a car
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
                        label = v.label or VShop.VehicleLabel(v.model),
                        price = math.floor(tonumber(v.price)),
                        coords = { x = spot.x, y = spot.y, z = spot.z, w = spot.w },
                        sold = false,
                        -- your own numbers (car entry wins over VehicleStats);
                        -- anything left out is measured by the client from the game
                        stats = statOverride(v),
                        type = v.type, -- optional: 'automobile', 'bike', ... (for server spawning)
                    }
                end
            end
        end
        fresh[storeId] = slots
    end
    VS.Stock = fresh
    TriggerClientEvent('qb-vehicleshop:stock:client:stock', -1, VS.Stock)
end

CreateThread(function()
    Wait(1000) -- let qb-core shared vehicles load
    checkConfig()
    VS.Restock()

    local minutes = tonumber(SCfg.RestockEveryMinutes) or 0
    if minutes > 0 then
        while true do
            Wait(minutes * 60000)
            VS.Restock()
            TriggerClientEvent('QBCore:Notify', -1, SLang.restocked, 'primary')
        end
    end
end)

QBCore.Functions.CreateCallback('qb-vehicleshop:stock:server:getStock', function(_, cb)
    cb(VS.Stock)
end)

QBCore.Commands.Add('restockcars', 'Re-roll every vehicle showroom (admin)', {}, false, function(source)
    if not VShop.IsAdmin(source, SCfg.AdminGroups) then return VShop.Notify(source, SLang.no_permission, 'error') end
    VS.Restock()
    VShop.Notify(source, SLang.restocked, 'success')
end)

--- The slot the player is standing at, or nil (+ a message).
local function slotFor(src, storeId, slotId)
    if type(storeId) ~= 'string' or type(slotId) ~= 'string' then return nil end
    local store = SCfg.Stores[storeId]
    local slot = VS.Stock[storeId] and VS.Stock[storeId][slotId]
    if not store or not slot then return nil end
    if slot.sold then
        VShop.Notify(src, SLang.already_sold, 'error')
        return nil
    end
    if VShop.DistanceTo(src, slot.coords) > (SCfg.BuyDistance or 8.0) then
        VShop.Notify(src, SLang.too_far, 'error')
        return nil
    end
    return store, slot
end

RegisterNetEvent('qb-vehicleshop:stock:server:buy', function(storeId, slotId)
    local src = source
    if not VShop.Cooldown(src, 'stockBuy', 2000) or not VShop.Lock(src) then return end

    local ok, err = pcall(function()
        local Player = QBCore.Functions.GetPlayer(src)
        local store, slot = slotFor(src, storeId, slotId)
        if not Player or not slot then return end

        -- Mark sold + take the money in the same tick (no await in between),
        -- so two players clicking at once can never both buy the same car.
        local paid = VShop.TakeMoney(Player, slot.price, SCfg.MoneyType, 'vehicle-showroom', false)
        if not paid then return VShop.Notify(src, SLang.not_enough_money:format(VShared.Comma(slot.price)), 'error') end
        slot.sold = true

        local plate = VShop.GiveVehicle(src, Player, slot.model, store.deliverySpawn, {
            garage = SCfg.DefaultGarage, warp = SCfg.WarpIntoVehicle, cfg = 'stock', type = slot.type, reason = 'Showroom Purchase',
        })
        if not plate then
            -- could not save it: give everything back
            slot.sold = false
            Player.Functions.AddMoney(paid, slot.price, 'vehicle-showroom-refund')
            return VShop.Notify(src, Lang:t('error.purchase_failed'), 'error')
        end
        TriggerClientEvent('qb-vehicleshop:stock:client:slotSold', -1, storeId, slotId)
        VShop.Notify(src, SLang.bought:format(slot.label, VShared.Comma(slot.price)), 'success', 7000)
    end)
    VShop.Unlock(src)
    if not ok then print(('^1[qb-vehicleshop stock] %s^0'):format(err)) end
end)

-- For other scripts / debugging: current showroom stock.
exports('GetStock', function() return VS.Stock end)

-- ---------------------------------------------------------------------------
-- Test drive (G on the showroom card)
-- ---------------------------------------------------------------------------
RegisterNetEvent('qb-vehicleshop:stock:server:testDrive', function(storeId, slotId)
    local src = source
    local cfg = SCfg.TestDrive or {}
    if not cfg.Enabled then return VShop.Notify(src, SLang.testdrive_off, 'error') end
    if not VShop.Cooldown(src, 'stockTestDrive', 3000) then return end
    if VShop.InTestDrive(src) then return VShop.Notify(src, SLang.testdrive_busy, 'error') end

    local Player = QBCore.Functions.GetPlayer(src)
    local store, slot = slotFor(src, storeId, slotId)
    if not Player or not slot then return end

    local price = math.max(0, math.floor(tonumber(cfg.Price) or 0))
    local paidWith = VShop.TakeMoney(Player, price, cfg.MoneyType or 'cash', 'vehicle-testdrive', true)
    if not paidWith then return VShop.Notify(src, SLang.testdrive_money:format(VShared.Comma(price)), 'error') end

    local seconds = math.max(10, math.floor(tonumber(cfg.Seconds) or 60))
    local started = VShop.StartTestDrive(src, slot.model, store.testDriveSpawn or store.deliverySpawn, seconds, {
        label = slot.label,
        leaveSeconds = tonumber(cfg.LeaveSeconds) or 3,
        cfg = 'stock',
        kind = 'stock',
        type = slot.type,
    })
    if not started then
        -- the server could not spawn it, so this refund can't be abused from the client
        if price > 0 then Player.Functions.AddMoney(paidWith, price, 'vehicle-testdrive-refund') end
        VShop.Notify(src, SLang.testdrive_failed, 'error')
    end
end)
