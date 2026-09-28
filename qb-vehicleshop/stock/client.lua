--[[ stock/client.lua — stock showroom display cars, the showroom card (top
     right, E buy / G test drive), qb-target options and the test drive. ]]

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
local requestTestDrive -- defined with the test drive below

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
    local options = {
        {
            icon = 'fas fa-dollar-sign',
            label = Config.StockLang.buy_target:format(slot.label, VSC.FormatMoney(slot.price)),
            action = function() openConfirm(storeId, slot.id) end,
        },
    }
    local td = Config.Stock.TestDrive
    if td and td.Enabled then
        options[#options + 1] = {
            icon = 'fas fa-car-side',
            label = Config.StockLang.testdrive_target:format(VSC.FormatMoney(td.Price or 0)),
            action = function() requestTestDrive(storeId, slot.id) end,
        }
    end
    exports['qb-target']:AddTargetEntity(veh, { options = options, distance = 3.0 })
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

-- Optional old 3D text above the cars (Config.Stock.Show3DText).
CreateThread(function()
    while true do
        local sleep = 1500
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

-- ---------------------------------------------------------------------------
-- Showroom card (top right) — E buy, G test drive
-- ---------------------------------------------------------------------------
local testDrive = nil   -- active test drive (below)
local cardKey = nil     -- "store|slot" shown on the card, nil = hidden
local statCache = {}    -- measured stats per model hash

local function measuredStats(model)
    local hash = joaat(model)
    local s = statCache[hash]
    if not s then
        local unit = (Config.Stock.Card.SpeedUnit == 'mph') and 2.236936 or 3.6
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

local function wallet()
    local money = (QBCore.Functions.GetPlayerData() or {}).money or {}
    return money.bank or 0, money.cash or 0
end

local function canAfford(price)
    local bank, cash = wallet()
    local mt = Config.Stock.MoneyType
    return ((mt == 'cash') and cash or bank) >= price
end

local function showCard(storeId, slotId)
    local slot = stock[storeId] and stock[storeId][slotId]
    if not slot then return end
    local m = measuredStats(slot.model)
    local o = slot.stats or {}
    local bank, cash = wallet()
    local td = Config.Stock.TestDrive or {}
    cardKey = key(storeId, slotId)
    SendNUIMessage({
        action = 'vsCard',
        show = true,
        data = {
            label = slot.label,
            category = slot.categoryLabel,
            seats = m.seats,
            price = slot.price,
            bank = bank,
            cash = cash,
            canAfford = canAfford(slot.price),
            unit = Config.Stock.Card.SpeedUnit == 'mph' and 'MPH' or 'KM/H',
            stats = {
                speed = o.speed or m.speed,
                acceleration = o.acceleration or m.acceleration,
                braking = o.braking or m.braking,
                handling = o.handling or m.handling,
            },
            max = Config.Stock.Card.StatMax,
            testDrive = { enabled = td.Enabled == true, price = td.Price or 0 },
        },
    })
end

local function hideCard()
    if not cardKey then return end
    cardKey = nil
    SendNUIMessage({ action = 'vsCard', show = false })
end

CreateThread(function()
    local lastMoney = 0
    while true do
        local sleep = 750
        local card = Config.Stock.Card
        local ped = PlayerPedId()
        if card and card.Enabled and not testDrive and not VSC.nuiFocus and not IsPedInAnyVehicle(ped, false) then
            local pos = GetEntityCoords(ped)
            local bestStore, bestSlot, bestD
            for storeId, slots in pairs(stock) do
                for slotId, slot in pairs(slots) do
                    if not slot.sold and spawned[key(storeId, slotId)] then
                        local d = #(pos - vector3(slot.coords.x, slot.coords.y, slot.coords.z))
                        if d < (card.Distance or 4.5) and (not bestD or d < bestD) then
                            bestStore, bestSlot, bestD = storeId, slotId, d
                        end
                    end
                end
            end
            if bestStore then
                sleep = 0
                if cardKey ~= key(bestStore, bestSlot) then showCard(bestStore, bestSlot) end

                -- keep the money on the card fresh (once a second)
                local now = GetGameTimer()
                if now - lastMoney > 1000 then
                    lastMoney = now
                    local slot = stock[bestStore][bestSlot]
                    local bank, cash = wallet()
                    SendNUIMessage({ action = 'vsCardMoney', bank = bank, cash = cash, canAfford = canAfford(slot.price) })
                end

                DisableControlAction(0, card.KeyTestDrive or 47, true)
                if IsControlJustPressed(0, card.KeyBuy or 38) then
                    local slot = stock[bestStore][bestSlot]
                    if canAfford(slot.price) then
                        hideCard()
                        openConfirm(bestStore, bestSlot)
                    else
                        SendNUIMessage({ action = 'vsCardDeny' })
                        QBCore.Functions.Notify(Config.StockLang.insufficient, 'error')
                    end
                elseif IsDisabledControlJustPressed(0, card.KeyTestDrive or 47) then
                    requestTestDrive(bestStore, bestSlot)
                end
            else
                hideCard()
            end
        else
            hideCard()
        end
        Wait(sleep)
    end
end)

-- ---------------------------------------------------------------------------
-- Test drive
-- ---------------------------------------------------------------------------
function requestTestDrive(storeId, slotId)
    if testDrive then return QBCore.Functions.Notify(Config.StockLang.testdrive_busy, 'error') end
    local td = Config.Stock.TestDrive
    if not td or not td.Enabled then return QBCore.Functions.Notify(Config.StockLang.testdrive_off, 'error') end
    SendNUIMessage({ action = 'vsCardPress', key = 'test' })
    TriggerServerEvent('qb-vehicleshop:stock:server:testDrive', storeId, slotId)
end

local function endTestDrive(msgKey)
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
    TriggerServerEvent('qb-vehicleshop:stock:server:testDriveEnd') -- server deletes it too
    SetEntityCoords(ped, td.prev.x, td.prev.y, td.prev.z - 0.9, false, false, false, false)
    Wait(300)
    DoScreenFadeIn(400)
    QBCore.Functions.Notify(Config.StockLang[msgKey or 'testdrive_ended'], 'primary')
end

RegisterNetEvent('qb-vehicleshop:stock:client:startTestDrive', function(d)
    if testDrive or type(d) ~= 'table' or not d.model or not d.spawn then return end
    hideCard()
    local ped = PlayerPedId()
    testDrive = { prev = GetEntityCoords(ped), pending = true }
    DoScreenFadeOut(250)
    Wait(300)
    QBCore.Functions.TriggerCallback('QBCore:Server:SpawnVehicle', function(netId)
        local veh = NetToVeh(netId)
        local timeout = GetGameTimer() + 5000
        while not DoesEntityExist(veh) and GetGameTimer() < timeout do
            Wait(10)
            veh = NetToVeh(netId)
        end
        if not DoesEntityExist(veh) then
            testDrive = nil
            TriggerServerEvent('qb-vehicleshop:stock:server:testDriveFailed')
            DoScreenFadeIn(300)
            return
        end

        local plate = ('TEST%04d'):format(math.random(0, 9999))
        SetVehicleNumberPlateText(veh, plate)
        SetEntityHeading(veh, d.spawn.w or 0.0)
        SetVehicleDirtLevel(veh, 0.0)
        setFuel(veh)
        TaskWarpPedIntoVehicle(ped, veh, -1)
        Config.Stock.GiveKeys(veh, plate)
        SetVehicleEngineOn(veh, true, true, false)

        testDrive.veh = veh
        testDrive.pending = false
        testDrive.endsAt = GetGameTimer() + d.seconds * 1000
        TriggerServerEvent('qb-vehicleshop:stock:server:testDriveSpawned', netId)
        SendNUIMessage({ action = 'vsTestDrive', show = true, seconds = d.seconds, label = d.label })
        Wait(300)
        DoScreenFadeIn(300)
        QBCore.Functions.Notify(Config.StockLang.testdrive_started:format(d.seconds), 'success')

        -- watch the test drive (4x a second is plenty)
        CreateThread(function()
            local outSince = nil
            local graceUntil = GetGameTimer() + 2000
            while testDrive and testDrive.veh == veh do
                local now = GetGameTimer()
                if now >= testDrive.endsAt then endTestDrive('testdrive_ended') break end
                if not DoesEntityExist(veh) or IsEntityDead(veh) then endTestDrive('testdrive_ended') break end
                if now > graceUntil and GetPedInVehicleSeat(veh, -1) ~= PlayerPedId() then
                    outSince = outSince or now
                    if now - outSince > (d.leaveSeconds or 3) * 1000 then endTestDrive('testdrive_left') break end
                else
                    outSince = nil
                end
                Wait(250)
            end
        end)
    end, d.model, vector4(d.spawn.x, d.spawn.y, d.spawn.z, d.spawn.w or 0.0), true)
end)

RegisterNetEvent('qb-vehicleshop:stock:client:forceEndTestDrive', function()
    if testDrive and not testDrive.pending then endTestDrive('testdrive_ended') end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() or not testDrive then return end
    if testDrive.veh and DoesEntityExist(testDrive.veh) then DeleteVehicle(testDrive.veh) end
    DoScreenFadeIn(0)
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
