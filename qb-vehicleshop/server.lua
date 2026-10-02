--[[ server.lua — finance payments, /transfervehicle and the original
     qb-vehicleshop showroom (Config.OldShowroom = true).

     Nothing here trusts what the client sends: the plate is looked up with
     the player's own citizenid, balances / prices come from the database or
     qb-core shared vehicles, shop actions need the player inside the shop
     (and the job for managed shops), and selling something to another
     player needs that player to accept first. ]]

local QBCore = VShop.QBCore

local function round(x) return math.floor(x + 0.5) end

local function modelPrice(model)
    local v = type(model) == 'string' and QBCore.Shared.Vehicles[model]
    local price = v and math.floor(tonumber(v.price) or 0)
    if not price or price <= 0 then return nil end
    return price
end

-- ===========================================================================
-- Finance timer — counts down only while the player is online
-- ===========================================================================
local online = {} -- [src] = { cid, since }

local function startTimer(src, cid)
    if src and cid then online[src] = { cid = cid, since = os.time() } end
end

local function stopTimer(src)
    local t = online[src]
    if not t then return end
    online[src] = nil
    local minutes = math.floor((os.time() - t.since) / 60)
    if minutes < 1 then return end
    -- one query instead of SELECT * + one UPDATE per vehicle
    MySQL.update('UPDATE player_vehicles SET financetime = GREATEST(financetime - ?, 0) WHERE citizenid = ? AND balance > 0',
        { minutes, t.cid })
end

local pendingRepo = {} -- [citizenid] = true while the warning runs

local function checkFinance(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local cid = Player.PlayerData.citizenid
    if pendingRepo[cid] then return end
    local due = MySQL.scalar.await('SELECT COUNT(*) FROM player_vehicles WHERE citizenid = ? AND balance > 0 AND financetime < 1', { cid })
    if not due or due < 1 then return end

    pendingRepo[cid] = true
    VShop.Notify(src, Lang:t('general.paymentduein', { time = Config.PaymentWarning }), 'primary', 10000)
    SetTimeout(Config.PaymentWarning * 60000, function()
        pendingRepo[cid] = nil
        local rows = MySQL.query.await('SELECT plate FROM player_vehicles WHERE citizenid = ? AND balance > 0 AND financetime < 1', { cid }) or {}
        if #rows == 0 then return end
        MySQL.update.await('DELETE FROM player_vehicles WHERE citizenid = ? AND balance > 0 AND financetime < 1', { cid })
        -- MySQL.update('UPDATE player_vehicles SET citizenid = ? WHERE citizenid = ? AND balance > 0 AND financetime < 1', { 'REPO-' .. cid, cid }) -- use this instead if you don't want them deleted
        local now = QBCore.Functions.GetPlayerByCitizenId(cid)
        for _, v in ipairs(rows) do
            TriggerEvent('qb-log:server:CreateLog', 'vehicleshop', 'Repossessed', 'red', ('%s lost %s (unpaid finance)'):format(cid, v.plate))
            if now then VShop.Notify(now.PlayerData.source, Lang:t('error.repossessed', { plate = v.plate }), 'error', 10000) end
        end
    end)
end

AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    local src = Player and Player.PlayerData and Player.PlayerData.source
    if not src then return end
    startTimer(src, Player.PlayerData.citizenid)
    CreateThread(function() checkFinance(src) end)
end)

AddEventHandler('QBCore:Server:OnPlayerUnload', function(src) stopTimer(src) end)

-- players already online when the resource (re)starts
CreateThread(function()
    local ok, players = pcall(QBCore.Functions.GetQBPlayers)
    if not ok or type(players) ~= 'table' then return end
    for src, Player in pairs(players) do
        if Player and Player.PlayerData then startTimer(tonumber(src) or Player.PlayerData.source, Player.PlayerData.citizenid) end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for src in pairs(online) do stopTimer(src) end
end)

-- ===========================================================================
-- Finance payments
-- ===========================================================================
local function financeRow(cid, plate)
    return MySQL.single.await('SELECT plate, balance, paymentamount, paymentsleft FROM player_vehicles WHERE plate = ? AND citizenid = ? LIMIT 1',
        { plate, cid })
end

local function validPlate(plate)
    return type(plate) == 'string' and #plate > 0 and #plate <= 15
end

--- Runs `fn` with the player's money lock held; errors are logged, never left locked.
local function locked(src, fn, ...)
    if not VShop.Lock(src) then return end
    local ok, err = pcall(fn, ...)
    VShop.Unlock(src)
    if not ok then print(('^1[qb-vehicleshop] %s^0'):format(err)) end
end

QBCore.Functions.CreateCallback('qb-vehicleshop:server:getVehicles', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player or not VShop.Cooldown(source, 'getVehicles', 500) then return cb({}) end
    cb(MySQL.query.await('SELECT plate, vehicle, balance, paymentamount, paymentsleft FROM player_vehicles WHERE citizenid = ? AND balance > 0',
        { Player.PlayerData.citizenid }) or {})
end)

RegisterNetEvent('qb-vehicleshop:server:financePayment', function(plate, amount)
    local src = source
    if not validPlate(plate) or not VShop.Cooldown(src, 'finance', 1500) then return end
    amount = VShop.PositiveInt(amount)
    if not amount then return VShop.Notify(src, Lang:t('error.invalid_amount'), 'error') end

    locked(src, function()
        local Player = QBCore.Functions.GetPlayer(src)
        if not Player then return end
        local row = financeRow(Player.PlayerData.citizenid, plate)
        if not row or row.balance <= 0 then return VShop.Notify(src, Lang:t('error.alreadypaid'), 'error') end
        if amount > row.balance then return VShop.Notify(src, Lang:t('error.overpaid'), 'error') end
        local minPayment = math.min(row.paymentamount, row.balance)
        if amount < minPayment then
            return VShop.Notify(src, Lang:t('error.minimumallowed') .. VShared.Comma(minPayment), 'error')
        end
        if not VShop.TakeMoney(Player, amount, 'cash', 'financed vehicle', true) then
            return VShop.Notify(src, Lang:t('error.notenoughmoney'), 'error')
        end

        local newBalance = row.balance - amount
        if newBalance <= 0 then
            MySQL.update.await('UPDATE player_vehicles SET balance = 0, paymentamount = 0, paymentsleft = 0, financetime = 0 WHERE plate = ?', { plate })
        else
            local left = math.max(row.paymentsleft - 1, 1)
            MySQL.update.await('UPDATE player_vehicles SET balance = ?, paymentamount = ?, paymentsleft = ?, financetime = ? WHERE plate = ?',
                { newBalance, math.ceil(newBalance / left), left, Config.PaymentInterval * 60, plate })
        end
        VShop.Notify(src, Lang:t('success.payment_made', { amount = VShared.Comma(amount) }), 'success')
    end)
end)

RegisterNetEvent('qb-vehicleshop:server:financePaymentFull', function(plate)
    local src = source
    if not validPlate(plate) or not VShop.Cooldown(src, 'finance', 1500) then return end

    locked(src, function()
        local Player = QBCore.Functions.GetPlayer(src)
        if not Player then return end
        local row = financeRow(Player.PlayerData.citizenid, plate)
        if not row or row.balance <= 0 then return VShop.Notify(src, Lang:t('error.alreadypaid'), 'error') end
        if not VShop.TakeMoney(Player, row.balance, 'cash', 'paid off vehicle', true) then
            return VShop.Notify(src, Lang:t('error.notenoughmoney'), 'error')
        end
        MySQL.update.await('UPDATE player_vehicles SET balance = 0, paymentamount = 0, paymentsleft = 0, financetime = 0 WHERE plate = ?', { plate })
        VShop.Notify(src, Lang:t('success.payment_made', { amount = VShared.Comma(row.balance) }), 'success')
    end)
end)

-- ===========================================================================
-- Offers — the other player has to accept (sales, gifts, test drives)
-- ===========================================================================
local offers = {}        -- [targetSrc] = { id, kind, from, expires, data }
local offerSeq = 0
local offerHandlers = {} -- [kind] = function(targetSrc, offer)

local function sendOffer(target, from, kind, data, title, text)
    local cur = offers[target]
    if cur and cur.expires > os.time() then return false end
    offerSeq = offerSeq + 1
    offers[target] = { id = offerSeq, kind = kind, from = from, data = data, expires = os.time() + 30 }
    TriggerClientEvent('qb-vehicleshop:client:offer', target, offerSeq, title, text)
    return true
end

RegisterNetEvent('qb-vehicleshop:server:offerResponse', function(id, accept)
    local src = source
    local o = offers[src]
    if not o or o.id ~= id then return end
    offers[src] = nil
    if os.time() > o.expires then return VShop.Notify(src, Lang:t('error.offer_expired'), 'error') end
    if accept ~= true then return VShop.Notify(o.from, Lang:t('error.offer_declined'), 'error') end
    local handler = offerHandlers[o.kind]
    if handler then locked(src, handler, src, o) end
end)

AddEventHandler('playerDropped', function()
    local src = source
    offers[src] = nil
    stopTimer(src)
end)

-- ===========================================================================
-- /transfervehicle — gift or sell the car you sit in (buyer must accept)
-- ===========================================================================
QBCore.Commands.Add('transfervehicle', Lang:t('general.command_transfervehicle'),
    { { name = 'ID', help = Lang:t('general.command_transfervehicle_help') }, { name = 'amount', help = Lang:t('general.command_transfervehicle_amount') } },
    false, function(source, args)
        local src = source
        if src <= 0 or not VShop.Cooldown(src, 'transfer', 3000) then return end
        local buyerId = tonumber(args[1])
        local amount = 0
        if args[2] and args[2] ~= '' then
            amount = VShop.PositiveInt(args[2], 1000000000)
            if not amount then return VShop.Notify(src, Lang:t('error.invalid_amount'), 'error') end
        end
        if not buyerId or buyerId == src then return VShop.Notify(src, Lang:t('error.Invalid_ID'), 'error') end
        local buyer = QBCore.Functions.GetPlayer(buyerId)
        local Player = QBCore.Functions.GetPlayer(src)
        if not buyer or not Player then return VShop.Notify(src, Lang:t('error.buyerinfo'), 'error') end

        local vehicle = GetVehiclePedIsIn(GetPlayerPed(src), false)
        if vehicle == 0 then return VShop.Notify(src, Lang:t('error.notinveh'), 'error') end
        local plate = QBCore.Shared.Trim(GetVehicleNumberPlateText(vehicle) or '')
        if not validPlate(plate) then return VShop.Notify(src, Lang:t('error.vehinfo'), 'error') end
        if VShop.DistanceBetween(src, buyerId) > 5.0 then return VShop.Notify(src, Lang:t('error.playertoofar'), 'error') end

        local row = MySQL.single.await('SELECT citizenid, balance FROM player_vehicles WHERE plate = ? LIMIT 1', { plate })
        if not row or row.citizenid ~= Player.PlayerData.citizenid then return VShop.Notify(src, Lang:t('error.notown'), 'error') end
        if Config.PreventFinanceSelling and row.balance > 0 then return VShop.Notify(src, Lang:t('error.financed'), 'error') end

        local name = VShop.CharName(Player)
        local text = amount > 0
            and Lang:t('offer.transfer_sell', { name = name, plate = plate, amount = VShared.Comma(amount) })
            or Lang:t('offer.transfer_gift', { name = name, plate = plate })
        local data = { sellerCid = Player.PlayerData.citizenid, plate = plate, amount = amount }
        if not sendOffer(buyerId, src, 'transfer', data, Lang:t('offer.title_transfer'), text) then
            return VShop.Notify(src, Lang:t('error.offer_pending'), 'error')
        end
        VShop.Notify(src, Lang:t('success.offer_sent'), 'primary')
    end)

function offerHandlers.transfer(buyerSrc, o)
    local d = o.data
    local seller = QBCore.Functions.GetPlayer(o.from)
    local buyer = QBCore.Functions.GetPlayer(buyerSrc)
    if not seller or not buyer or seller.PlayerData.citizenid ~= d.sellerCid then
        return VShop.Notify(buyerSrc, Lang:t('error.offer_invalid'), 'error')
    end
    if VShop.DistanceBetween(o.from, buyerSrc) > 6.0 then
        return VShop.Notify(buyerSrc, Lang:t('error.playertoofar'), 'error')
    end
    local row = MySQL.single.await('SELECT citizenid, balance FROM player_vehicles WHERE plate = ? LIMIT 1', { d.plate })
    if not row or row.citizenid ~= d.sellerCid or (Config.PreventFinanceSelling and row.balance > 0) then
        return VShop.Notify(buyerSrc, Lang:t('error.offer_invalid'), 'error')
    end

    local paidWith
    if d.amount > 0 then
        paidWith = VShop.TakeMoney(buyer, d.amount, 'cash', 'transferred vehicle', true)
        if not paidWith then
            VShop.Notify(o.from, Lang:t('error.buyertoopoor'), 'error')
            return VShop.Notify(buyerSrc, Lang:t('error.notenoughmoney'), 'error')
        end
    end

    -- only moves if the seller still owns it right now
    local changed = MySQL.update.await('UPDATE player_vehicles SET citizenid = ?, license = ? WHERE plate = ? AND citizenid = ?',
        { buyer.PlayerData.citizenid, buyer.PlayerData.license, d.plate, d.sellerCid })
    if not changed or changed < 1 then
        if paidWith then buyer.Functions.AddMoney(paidWith, d.amount, 'transferred vehicle refund') end
        return VShop.Notify(buyerSrc, Lang:t('error.offer_invalid'), 'error')
    end

    if paidWith then
        seller.Functions.AddMoney(paidWith, d.amount, 'transferred vehicle')
        VShop.Notify(o.from, Lang:t('success.soldfor') .. VShared.Comma(d.amount), 'success')
        VShop.Notify(buyerSrc, Lang:t('success.boughtfor') .. VShared.Comma(d.amount), 'success')
    else
        VShop.Notify(o.from, Lang:t('success.gifted'), 'success')
        VShop.Notify(buyerSrc, Lang:t('success.received_gift'), 'success')
    end
    TriggerClientEvent('vehiclekeys:client:SetOwner', buyerSrc, d.plate)
    TriggerEvent('qb-log:server:CreateLog', 'vehicleshop', 'Vehicle Transfer', 'blue',
        ('%s -> %s [%s] for $%s'):format(d.sellerCid, buyer.PlayerData.citizenid, d.plate, d.amount))
end

-- ===========================================================================
-- Old showroom (Config.OldShowroom = true). The server keeps which car is on
-- each spot, so the client only ever sends a shop name + spot number.
-- ===========================================================================
local showroom = {} -- [shop][slot] = model
for name, shop in pairs(Config.Shops) do
    showroom[name] = {}
    for i, v in ipairs(shop.ShowroomVehicles or {}) do showroom[name][i] = v.defaultVehicle end
end

QBCore.Functions.CreateCallback('qb-vehicleshop:server:getShowroom', function(_, cb)
    cb(Config.OldShowroom and showroom or {})
end)

--- Player standing in the shop with the right job. Returns Player, shop, slot, model.
local function shopContext(src, shopName, slot, needType, silent)
    if not Config.OldShowroom or type(shopName) ~= 'string' then return nil end
    local shop = Config.Shops[shopName]
    slot = math.tointeger(tonumber(slot))
    if not shop or not slot or not showroom[shopName][slot] then return nil end
    if needType and shop.Type ~= needType then return nil end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return nil end
    if shop.Job and shop.Job ~= 'none' and Player.PlayerData.job.name ~= shop.Job then return nil end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not VShared.InShop(shopName, GetEntityCoords(ped), 3.0) then
        if not silent then VShop.Notify(src, Lang:t('error.not_in_shop'), 'error') end
        return nil
    end
    return Player, shop, slot, showroom[shopName][slot]
end

local function financeTerms(price, down, payments)
    down, payments = VShop.PositiveInt(down), VShop.PositiveInt(payments)
    if not down or not payments then return nil, 'error.invalid_amount' end
    if down > price then return nil, 'error.notworth' end
    if down < round(Config.MinimumDown / 100 * price) then return nil, 'error.downtoosmall' end
    if payments > Config.MaximumPayments then return nil, 'error.exceededmax' end
    local balance = price - down
    if balance <= 0 then return { down = down } end -- paid in full
    return { down = down, balance = balance, payment = math.ceil(balance / payments), payments = payments, time = Config.PaymentInterval * 60 }
end

local function dbFinance(terms)
    if not terms or not terms.balance then return nil end
    return { balance = terms.balance, payment = terms.payment, payments = terms.payments, time = terms.time }
end

RegisterNetEvent('qb-vehicleshop:server:swapVehicle', function(shopName, slot, model)
    local src = source
    if not VShop.Cooldown(src, 'swap', 2000) then return end -- every swap respawns a car for everyone
    local Player, _, slotId, current = shopContext(src, shopName, slot)
    if not Player or current == model then return end
    if not VShared.SoldInShop(QBCore.Shared.Vehicles, model, shopName) or not modelPrice(model) then return end
    showroom[shopName][slotId] = model
    TriggerClientEvent('qb-vehicleshop:client:swapVehicle', -1, shopName, slotId, model)
    SetTimeout(1000, function() TriggerClientEvent('qb-vehicleshop:client:homeMenu', src) end)
end)

-- free-use: test drive the car on the spot you stand at
RegisterNetEvent('qb-vehicleshop:server:testDrive', function(shopName, slot)
    local src = source
    if not VShop.Cooldown(src, 'testdrive', 3000) then return end
    local Player, shop, _, model = shopContext(src, shopName, slot, 'free-use')
    if not Player then return end
    if VShop.InTestDrive(src) then return VShop.Notify(src, Lang:t('error.testdrive_alreadyin'), 'error') end
    local seconds = math.max(10, math.floor((tonumber(shop.TestDriveTimeLimit) or 0.5) * 60))
    if not VShop.StartTestDrive(src, model, shop.TestDriveSpawn, seconds, { label = VShop.VehicleLabel(model), kind = 'legacy' }) then
        VShop.Notify(src, Lang:t('error.spawn_failed'), 'error')
    end
end)

-- free-use: buy outright
RegisterNetEvent('qb-vehicleshop:server:buyShowroomVehicle', function(shopName, slot)
    local src = source
    if not VShop.Cooldown(src, 'buy', 3000) then return end
    locked(src, function()
        local Player, shop, _, model = shopContext(src, shopName, slot, 'free-use')
        local price = Player and modelPrice(model)
        if not price then return end
        local paid = VShop.TakeMoney(Player, price, 'cash', 'vehicle-bought-in-showroom', true)
        if not paid then return VShop.Notify(src, Lang:t('error.notenoughmoney'), 'error') end
        if not VShop.GiveVehicle(src, Player, model, shop.VehicleSpawn, { warp = true, reason = 'Showroom Purchase' }) then
            Player.Functions.AddMoney(paid, price, 'vehicle-purchase-refund')
            return VShop.Notify(src, Lang:t('error.purchase_failed'), 'error')
        end
        VShop.Notify(src, Lang:t('success.purchased'), 'success')
    end)
end)

-- free-use: finance
RegisterNetEvent('qb-vehicleshop:server:financeVehicle', function(shopName, slot, downPayment, paymentAmount)
    local src = source
    if not VShop.Cooldown(src, 'buy', 3000) then return end
    locked(src, function()
        local Player, shop, _, model = shopContext(src, shopName, slot, 'free-use')
        local price = Player and modelPrice(model)
        if not price then return end
        local terms, err = financeTerms(price, downPayment, paymentAmount)
        if not terms then return VShop.Notify(src, Lang:t(err), 'error') end
        local paid = VShop.TakeMoney(Player, terms.down, 'cash', 'vehicle-bought-in-showroom', true)
        if not paid then return VShop.Notify(src, Lang:t('error.notenoughmoney'), 'error') end
        if not VShop.GiveVehicle(src, Player, model, shop.VehicleSpawn, { warp = true, finance = dbFinance(terms), reason = 'Showroom Finance' }) then
            Player.Functions.AddMoney(paid, terms.down, 'vehicle-purchase-refund')
            return VShop.Notify(src, Lang:t('error.purchase_failed'), 'error')
        end
        VShop.Notify(src, Lang:t('success.purchased'), 'success')
    end)
end)

-- managed: the employee offers something to a customer standing next to them
local function managedOffer(src, shopName, slot, playerId, kind, terms)
    local Player, shop, _, model = shopContext(src, shopName, slot, 'managed')
    local price = Player and modelPrice(model)
    if not price then return end
    local target = tonumber(playerId)
    if not target or target == src or not QBCore.Functions.GetPlayer(target) then
        return VShop.Notify(src, Lang:t('error.Invalid_ID'), 'error')
    end
    if VShop.DistanceBetween(src, target) > 3.0 then return VShop.Notify(src, Lang:t('error.playertoofar'), 'error') end

    local name, label = VShop.CharName(Player), VShop.VehicleLabel(model)
    local text, title
    if kind == 'testdrive' then
        if VShop.InTestDrive(target) then return VShop.Notify(src, Lang:t('error.testdrive_alreadyin'), 'error') end
        title, text = Lang:t('offer.title_sale'), Lang:t('offer.testdrive', { name = name, vehicle = label })
    elseif terms and terms.balance then
        title, text = Lang:t('offer.title_sale'), Lang:t('offer.sale_finance', {
            name = name, vehicle = label, down = VShared.Comma(terms.down), payments = terms.payments, payment = VShared.Comma(terms.payment) })
    else
        title, text = Lang:t('offer.title_sale'), Lang:t('offer.sale', { name = name, vehicle = label, amount = VShared.Comma(terms and terms.down or price) })
    end
    local data = { sellerCid = Player.PlayerData.citizenid, shop = shopName, model = model, price = price, terms = terms }
    if not sendOffer(target, src, kind, data, title, text) then return VShop.Notify(src, Lang:t('error.offer_pending'), 'error') end
    VShop.Notify(src, Lang:t('success.offer_sent'), 'primary')
end

RegisterNetEvent('qb-vehicleshop:server:customTestDrive', function(shopName, slot, playerId)
    local src = source
    if not VShop.Cooldown(src, 'offer', 3000) then return end
    managedOffer(src, shopName, slot, playerId, 'testdrive')
end)

RegisterNetEvent('qb-vehicleshop:server:sellShowroomVehicle', function(shopName, slot, playerId)
    local src = source
    if not VShop.Cooldown(src, 'offer', 3000) then return end
    managedOffer(src, shopName, slot, playerId, 'dealerSale')
end)

RegisterNetEvent('qb-vehicleshop:server:sellfinanceVehicle', function(shopName, slot, downPayment, paymentAmount, playerId)
    local src = source
    if not VShop.Cooldown(src, 'offer', 3000) then return end
    local model = Config.OldShowroom and type(shopName) == 'string' and showroom[shopName] and showroom[shopName][tonumber(slot)]
    local price = modelPrice(model)
    if not price then return end
    local terms, err = financeTerms(price, downPayment, paymentAmount)
    if not terms then return VShop.Notify(src, Lang:t(err), 'error') end
    managedOffer(src, shopName, slot, playerId, 'dealerSale', terms)
end)

--- The employee who made the offer is still on the job, in the shop, next to the customer.
local function sellerStillValid(o, customerSrc)
    local seller = QBCore.Functions.GetPlayer(o.from)
    local shop = Config.Shops[o.data.shop]
    if not seller or seller.PlayerData.citizenid ~= o.data.sellerCid or not shop then return nil end
    if shop.Job ~= 'none' and seller.PlayerData.job.name ~= shop.Job then return nil end
    if not VShared.InShop(o.data.shop, GetEntityCoords(GetPlayerPed(o.from)), 3.0) then return nil end
    if VShop.DistanceBetween(o.from, customerSrc) > 6.0 then return nil end
    return seller, shop
end

function offerHandlers.testdrive(buyerSrc, o)
    local _, shop = sellerStillValid(o, buyerSrc)
    if not shop then return VShop.Notify(buyerSrc, Lang:t('error.offer_invalid'), 'error') end
    if VShop.InTestDrive(buyerSrc) then return VShop.Notify(buyerSrc, Lang:t('error.testdrive_alreadyin'), 'error') end
    local seconds = math.max(10, math.floor((tonumber(shop.TestDriveTimeLimit) or 0.5) * 60))
    if not VShop.StartTestDrive(buyerSrc, o.data.model, shop.TestDriveSpawn, seconds,
            { label = VShop.VehicleLabel(o.data.model), kind = 'legacy', returnCoords = shop.ReturnLocation }) then
        VShop.Notify(buyerSrc, Lang:t('error.spawn_failed'), 'error')
    end
end

function offerHandlers.dealerSale(buyerSrc, o)
    local d = o.data
    local seller, shop = sellerStillValid(o, buyerSrc)
    local buyer = QBCore.Functions.GetPlayer(buyerSrc)
    if not seller or not buyer then return VShop.Notify(buyerSrc, Lang:t('error.offer_invalid'), 'error') end

    local terms = d.terms
    local pay = terms and terms.down or d.price
    local paid = VShop.TakeMoney(buyer, pay, 'cash', 'vehicle-bought-in-showroom', true)
    if not paid then
        VShop.Notify(o.from, Lang:t('error.notenoughmoney'), 'error')
        return VShop.Notify(buyerSrc, Lang:t('error.notenoughmoney'), 'error')
    end
    if not VShop.GiveVehicle(buyerSrc, buyer, d.model, shop.VehicleSpawn, { warp = true, finance = dbFinance(terms), reason = 'Dealer Sale' }) then
        buyer.Functions.AddMoney(paid, pay, 'vehicle-purchase-refund')
        return VShop.Notify(buyerSrc, Lang:t('error.purchase_failed'), 'error')
    end

    -- financed: the society gets what was actually paid now (it used to get
    -- the full price for a 10% down payment — free money with a repo loop)
    local financed = terms and terms.balance
    local commission = round(d.price * (financed and Config.FinanceCommission or Config.Commission))
    if commission > 0 then seller.Functions.AddMoney('bank', commission, 'vehicle sale commission') end
    local jobName = seller.PlayerData.job.name
    if not pcall(function() exports['qb-banking']:AddMoney(jobName, pay, 'Vehicle sale') end) then
        print('^3[qb-vehicleshop] qb-banking:AddMoney failed — society not paid^0')
    end
    VShop.Notify(o.from, Lang:t('success.earned_commission', { amount = VShared.Comma(commission) }), 'success')
    VShop.Notify(buyerSrc, Lang:t('success.purchased'), 'success')
end
