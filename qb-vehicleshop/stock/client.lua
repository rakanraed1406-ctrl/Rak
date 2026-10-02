--[[ stock/client.lua — stock showroom display cars, the showroom card (top
     right, E buy / G test drive) and the qb-target options.

     Cost when you are away from a showroom: one distance check per store
     every second. The per-frame key loop only runs while the card is shown.
     Money on the card updates from qb-core's player-data event (no polling). ]]

local QBCore = exports['qb-core']:GetCoreObject()
local SCfg, SLang = Config.Stock, Config.StockLang
local Card = SCfg.Card or {}

local stock = {}         -- same shape as the server's VS.Stock (+ slot.pos)
local areas = {}         -- [storeId] = { center, radius } worked out from the spots
local spawned = {}       -- ["store|slot"] = { veh } (empty table while loading)
local nearStores = nil   -- stores close enough for the card, nil = none
local pendingBuy = nil   -- { storeId, slotId } while the confirm dialog is open
local cardKey, cardPrice = nil, 0
local money = { bank = 0, cash = 0 }
local statCache = {}     -- measured stats per model hash
local blips = {}

local function key(storeId, slotId) return storeId .. '|' .. slotId end

local function hasTarget() return GetResourceState('qb-target') == 'started' end

-- ---------------------------------------------------------------------------
-- Display cars
-- ---------------------------------------------------------------------------
local function despawn(k)
    local e = spawned[k]
    if not e then return end
    spawned[k] = nil
    if e.veh then
        if DoesEntityExist(e.veh) and hasTarget() then exports['qb-target']:RemoveTargetEntity(e.veh) end
        VShopC.DeleteLocal(e.veh)
    end
end

local function despawnAll()
    for k in pairs(spawned) do despawn(k) end
end

local function openConfirm(storeId, slotId)
    local slot = stock[storeId] and stock[storeId][slotId]
    if not slot or slot.sold then return end
    pendingBuy = { storeId = storeId, slotId = slotId }
    VShopC.Focus(true)
    SendNUIMessage({
        action = 'buyConfirm',
        vehicle = { label = slot.label, model = slot.model, price = slot.price, category = slot.categoryLabel },
        store = SCfg.Stores[storeId] and SCfg.Stores[storeId].label or '',
    })
end

local function requestTestDrive(storeId, slotId)
    if VShopC.InTestDrive() then return QBCore.Functions.Notify(SLang.testdrive_busy, 'error') end
    local td = SCfg.TestDrive
    if not td or not td.Enabled then return QBCore.Functions.Notify(SLang.testdrive_off, 'error') end
    SendNUIMessage({ action = 'vsCardPress', key = 'test' })
    TriggerServerEvent('qb-vehicleshop:stock:server:testDrive', storeId, slotId)
end

local function spawnSlot(storeId, slot)
    local k = key(storeId, slot.id)
    if spawned[k] or slot.sold then return end
    local entry = {}
    spawned[k] = entry -- placeholder while the model loads
    local veh = VShopC.SpawnDisplay(slot.model, slot.coords, 'FORSALE')
    if spawned[k] ~= entry then -- sold / restocked while loading
        VShopC.DeleteLocal(veh)
        return
    end
    if not veh then return end -- broken model: keep the placeholder, don't retry every second
    entry.veh = veh

    if not hasTarget() then return end
    local options = {
        {
            icon = 'fas fa-dollar-sign',
            label = SLang.buy_target:format(slot.label, VShopC.FormatMoney(slot.price)),
            action = function() openConfirm(storeId, slot.id) end,
        },
    }
    local td = SCfg.TestDrive
    if td and td.Enabled then
        options[#options + 1] = {
            icon = 'fas fa-car-side',
            label = SLang.testdrive_target:format(VShopC.FormatMoney(td.Price or 0)),
            action = function() requestTestDrive(storeId, slot.id) end,
        }
    end
    exports['qb-target']:AddTargetEntity(veh, { options = options, distance = 3.0 })
end

local function applyStock(newStock)
    despawnAll()
    stock = type(newStock) == 'table' and newStock or {}
    areas = {}
    for storeId, slots in pairs(stock) do
        local sx, sy, sz, n = 0.0, 0.0, 0.0, 0
        for _, slot in pairs(slots) do
            slot.pos = vector3(slot.coords.x, slot.coords.y, slot.coords.z)
            sx, sy, sz, n = sx + slot.pos.x, sy + slot.pos.y, sz + slot.pos.z, n + 1
        end
        if n > 0 then
            local center = vector3(sx / n, sy / n, sz / n)
            local radius = 0.0
            for _, slot in pairs(slots) do radius = math.max(radius, #(slot.pos - center)) end
            areas[storeId] = { center = center, radius = radius }
        end
    end
end

-- Stream display cars in/out by distance and note which stores are close.
CreateThread(function()
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        local dd = SCfg.DisplayDistance or 90.0
        local near, any = {}, false
        for storeId, slots in pairs(stock) do
            local area = areas[storeId]
            local d = area and #(pos - area.center) or math.huge
            if area and d <= dd + area.radius then
                for slotId, slot in pairs(slots) do
                    if not slot.sold and #(pos - slot.pos) < dd then
                        spawnSlot(storeId, slot)
                    elseif spawned[key(storeId, slotId)] then
                        despawn(key(storeId, slotId))
                    end
                end
                if d <= area.radius + 15.0 then
                    near[storeId] = true
                    any = true
                end
            else
                for slotId in pairs(slots) do
                    if spawned[key(storeId, slotId)] then despawn(key(storeId, slotId)) end
                end
            end
        end
        nearStores = any and near or nil
        Wait(any and 500 or 1000)
    end
end)

-- Optional old 3D text above the cars (Config.Stock.Show3DText) — no thread when off.
if SCfg.Show3DText then
    CreateThread(function()
        while true do
            local sleep = 1000
            if nearStores then
                local pos = GetEntityCoords(PlayerPedId())
                for storeId in pairs(nearStores) do
                    for slotId, slot in pairs(stock[storeId] or {}) do
                        local e = spawned[key(storeId, slotId)]
                        if not slot.sold and e and e.veh and #(pos - slot.pos) < 10.0 then
                            sleep = 0
                            VShopC.Draw3DText(slot.pos.x, slot.pos.y, slot.pos.z + 1.4,
                                ('~b~%s~s~ · %s~n~~g~$%s'):format(slot.categoryLabel, slot.label, VShopC.FormatMoney(slot.price)))
                        end
                    end
                end
            end
            Wait(sleep)
        end
    end)
end

-- ---------------------------------------------------------------------------
-- Showroom card (top right) — E buy, G test drive
-- ---------------------------------------------------------------------------
local function measuredStats(model)
    local hash = joaat(model)
    local s = statCache[hash]
    if not s then
        local unit = (Card.SpeedUnit == 'mph') and 2.236936 or 3.6
        s = {
            speed = GetVehicleModelEstimatedMaxSpeed(hash) * unit,
            acceleration = GetVehicleModelAcceleration(hash),
            braking = GetVehicleModelMaxBraking(hash),
            handling = GetVehicleModelMaxTraction(hash),
            seats = GetVehicleModelNumberOfSeats(hash),
        }
        statCache[hash] = s
    end
    return s
end

local function setMoney(pd)
    local m = type(pd) == 'table' and pd.money
    if type(m) == 'table' then
        money.bank = tonumber(m.bank) or 0
        money.cash = tonumber(m.cash) or 0
    end
end

local function canAfford(price)
    return ((SCfg.MoneyType == 'cash') and money.cash or money.bank) >= price
end

-- everything the card needs about the player's money for this price
local function moneyInfo(price)
    local have = (SCfg.MoneyType == 'cash') and money.cash or money.bank
    local tdPrice = (SCfg.TestDrive or {}).Price or 0
    return {
        bank = money.bank,
        cash = money.cash,
        canAfford = have >= price,
        need = math.max(0, price - have),
        -- the test drive pays from cash, or bank if cash isn't enough (server does the same)
        testAfford = money.cash >= tdPrice or money.bank >= tdPrice,
    }
end

local function showCard(storeId, slotId)
    local slot = stock[storeId] and stock[storeId][slotId]
    if not slot then return end
    local m = measuredStats(slot.model)
    local o = slot.stats or {}
    local mi = moneyInfo(slot.price)
    local td = SCfg.TestDrive or {}
    cardKey, cardPrice = key(storeId, slotId), slot.price
    SendNUIMessage({
        action = 'vsCard',
        show = true,
        data = {
            label = slot.label,
            category = slot.categoryLabel,
            seats = m.seats,
            price = slot.price,
            bank = mi.bank,
            cash = mi.cash,
            canAfford = mi.canAfford,
            need = mi.need,
            testAfford = mi.testAfford,
            unit = Card.SpeedUnit == 'mph' and 'MPH' or 'KM/H',
            stats = {
                speed = o.speed or m.speed,
                acceleration = o.acceleration or m.acceleration,
                braking = o.braking or m.braking,
                handling = o.handling or m.handling,
            },
            max = Card.StatMax,
            testDrive = { enabled = td.Enabled == true, price = td.Price or 0 },
        },
    })
end

local function hideCard()
    if not cardKey then return end
    cardKey = nil
    SendNUIMessage({ action = 'vsCard', show = false })
end

-- money changed (qb-core pushes the player data) → refresh the card
RegisterNetEvent('QBCore:Player:SetPlayerData', function(pd)
    setMoney(pd)
    if cardKey then
        local mi = moneyInfo(cardPrice)
        mi.action = 'vsCardMoney'
        SendNUIMessage(mi)
    end
end)

if Card.Enabled then
    CreateThread(function()
        local keyBuy, keyTest = Card.KeyBuy or 38, Card.KeyTestDrive or 47
        local cardDist = Card.Distance or 4.5
        while true do
            local sleep = 750
            local stores = nearStores
            local ped = PlayerPedId()
            if stores and not VShopC.InTestDrive() and not VShopC.nuiFocus and not IsPedInAnyVehicle(ped, false) then
                sleep = 250
                local pos = GetEntityCoords(ped)
                local bestStore, bestSlot, bestD
                for storeId in pairs(stores) do
                    for slotId, slot in pairs(stock[storeId] or {}) do
                        local e = spawned[key(storeId, slotId)]
                        if not slot.sold and e and e.veh then
                            local d = #(pos - slot.pos)
                            if d < cardDist and (not bestD or d < bestD) then
                                bestStore, bestSlot, bestD = storeId, slotId, d
                            end
                        end
                    end
                end

                if bestStore then
                    if cardKey ~= key(bestStore, bestSlot) then showCard(bestStore, bestSlot) end
                    -- read the keys every frame for 250 ms, then look for the closest car again
                    local untilT = GetGameTimer() + 250
                    repeat
                        DisableControlAction(0, keyTest, true)
                        if IsControlJustPressed(0, keyBuy) then
                            local slot = stock[bestStore] and stock[bestStore][bestSlot]
                            if slot and not slot.sold then
                                if canAfford(slot.price) then
                                    hideCard()
                                    openConfirm(bestStore, bestSlot)
                                else
                                    SendNUIMessage({ action = 'vsCardDeny' })
                                    QBCore.Functions.Notify(SLang.insufficient, 'error')
                                end
                            end
                            break
                        elseif IsDisabledControlJustPressed(0, keyTest) then
                            requestTestDrive(bestStore, bestSlot)
                            break
                        end
                        Wait(0)
                    until GetGameTimer() >= untilT
                    sleep = 0
                else
                    hideCard()
                end
            else
                hideCard()
            end
            Wait(sleep)
        end
    end)
end

-- ---------------------------------------------------------------------------
-- Server events / NUI
-- ---------------------------------------------------------------------------
RegisterNetEvent('qb-vehicleshop:stock:client:stock', function(newStock) applyStock(newStock) end)

RegisterNetEvent('qb-vehicleshop:stock:client:slotSold', function(storeId, slotId)
    local slot = stock[storeId] and stock[storeId][slotId]
    if slot then slot.sold = true end
    despawn(key(storeId, slotId))
    if cardKey == key(storeId, slotId) then hideCard() end
    if pendingBuy and pendingBuy.storeId == storeId and pendingBuy.slotId == slotId then
        pendingBuy = nil
        VShopC.Focus(false)
        SendNUIMessage({ action = 'closeAll' })
    end
end)

RegisterNetEvent('qb-vehicleshop:stock:client:printCoords', function()
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    local line = ('vector4(%.2f, %.2f, %.2f, %.1f)'):format(c.x, c.y, c.z, GetEntityHeading(ped))
    print(line)
    QBCore.Functions.Notify(line .. ' (F8)', 'primary', 8000)
end)

RegisterNUICallback('buyConfirm', function(data, cb)
    VShopC.Focus(false)
    if type(data) == 'table' and data.confirm and pendingBuy then
        TriggerServerEvent('qb-vehicleshop:stock:server:buy', pendingBuy.storeId, pendingBuy.slotId)
    end
    pendingBuy = nil
    cb('ok')
end)

local function loadStock()
    setMoney(QBCore.Functions.GetPlayerData())
    QBCore.Functions.TriggerCallback('qb-vehicleshop:stock:server:getStock', function(s) applyStock(s) end)
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', loadStock)

CreateThread(function()
    for storeId, store in pairs(SCfg.Stores) do
        local b = store.blip
        if b and b.enabled ~= false and b.coords then
            blips[#blips + 1] = VShopC.AddBlip(b.coords, b.sprite or 326, b.color or 3, b.scale or 0.75, store.label or storeId)
        end
    end
    Wait(2000)
    if LocalPlayer.state.isLoggedIn then loadStock() end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    despawnAll()
    for _, b in ipairs(blips) do RemoveBlip(b) end
end)
