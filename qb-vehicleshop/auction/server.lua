--[[ auction/server.lua — admin car auctions

  1. Admin: /auction → form (vehicle model, start price ≥ MinStartPrice,
     increment, location). The car spawns at the location for everyone to see.
  2. LOBBY: once MinParticipants players (not the admin) are inside the hidden
     radius, everyone in the radius gets a YES / NO invite. Players who walk in
     later get it too. When MinParticipants have said YES and are still in the
     radius → short countdown → auction starts.
  3. RUNNING: each participant gets Config.Auction.BidItem. Using it (while in
     the radius) bids: first bid = start price, then + increment each time.
     Top-right HUD shows the car, price, top bidder and timers.
     Nobody out-bids for SoldAfter seconds → top bidder wins.
     Duration runs out → top bidder wins.
  4. END: winner pays, car goes to their garage table, spawns at the delivery
     point with keys. Bid items are removed from everyone.

  Network: the state is sent to clients when something changes (+ a sync every
  15s). Timers count down on the client, so there is no per-second broadcast.
]]

local QBCore = VShop.QBCore
local ACfg, ALang = Config.Auction, Config.AuctionLang

local A = nil -- the one running auction (only one at a time)

local function now() return GetGameTimer() end

local function inZone(src)
    return A and VShop.DistanceTo(src, A.location.center) <= ACfg.Radius
end

local function playersInZone()
    local list = {}
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if src and src ~= A.admin and inZone(src) and QBCore.Functions.GetPlayer(src) then
            list[#list + 1] = src
        end
    end
    return list
end

local function countAcceptedInZone()
    local n = 0
    for src in pairs(A.accepted) do
        if inZone(src) then n = n + 1 end
    end
    return n
end

local function publicState()
    if not A then return { active = false } end
    local t = now()
    local ids, n = {}, 0
    for src in pairs(A.participants) do
        ids[#ids + 1] = src
        n = n + 1
    end
    return {
        active = true,
        id = A.id,
        state = A.state,
        model = A.model,
        label = A.label,
        locIndex = A.locIndex,
        radius = ACfg.Radius,
        startPrice = A.startPrice,
        increment = A.increment,
        price = A.price,
        nextBid = A.topBidder and (A.price + A.increment) or A.startPrice,
        topId = A.topBidder,
        topName = A.topName,
        bidCount = #A.bids,
        adminId = A.admin,
        participants = ids,
        participantCount = n,
        accepted = A.state ~= 'running' and A.acceptedInZone or n,
        needed = ACfg.MinParticipants,
        endsIn = A.endsAt and math.max(0, A.endsAt - t) or nil,
        soldIn = (A.state == 'running' and A.topBidder) and math.max(0, A.lastBidAt + ACfg.SoldAfter * 1000 - t) or nil,
        startsIn = A.startsAt and math.max(0, A.startsAt - t) or nil,
        soldAfter = ACfg.SoldAfter,
    }
end

local lastSig, lastSent = nil, 0

--- Sends the state when it changed (or `force`, or every 15s to correct drift).
local function broadcast(force)
    local sig = 'none'
    if A then
        sig = table.concat({ A.id, A.state, A.price, A.topBidder or 0, #A.bids, A.acceptedInZone or 0,
            A.participantCount or 0, A.startsAt or 0, A.admin }, '|')
    end
    local t = now()
    if not force and sig == lastSig and t - lastSent < 15000 then return end
    lastSig, lastSent = sig, t
    TriggerClientEvent('qb-vehicleshop:auction:client:auctionState', -1, publicState())
end

local function notifyAuction(msg, kind)
    if not A then return end
    local sent = {}
    local function send(src)
        if src and src > 0 and not sent[src] then
            sent[src] = true
            VShop.Notify(src, msg, kind, 7000)
        end
    end
    send(A.admin)
    for src in pairs(A.participants) do send(src) end
    for src in pairs(A.accepted) do send(src) end
end

-- Inventory helpers. Newer qb-core moved the item functions (GetItemByName,
-- AddItem, RemoveItem...) out of Player.Functions into qb-inventory, so use
-- the inventory resource when it is there and fall back to the old API.
local function started(name) return GetResourceState(name) == 'started' end

local function itemExists(name)
    if QBCore.Shared.Items[name] then return true end
    if started('ox_inventory') then
        local ok, item = pcall(function() return exports.ox_inventory:Items(name) end)
        return ok and item ~= nil
    end
    return false
end

local function itemCount(src, name)
    if started('ox_inventory') then
        local ok, n = pcall(function() return exports.ox_inventory:GetItemCount(src, name) end)
        return ok and tonumber(n) or 0
    end
    if started('qb-inventory') then
        local ok, n = pcall(function() return exports['qb-inventory']:GetItemCount(src, name) end)
        if ok and n then return tonumber(n) or 0 end
    end
    local Player = QBCore.Functions.GetPlayer(src)
    if Player and Player.Functions.GetItemByName then
        local item = Player.Functions.GetItemByName(name)
        return item and (item.amount or item.count or 1) or 0
    end
    return 0
end

local function addItem(src, name, amount)
    if started('ox_inventory') then
        local ok, res = pcall(function() return exports.ox_inventory:AddItem(src, name, amount) end)
        return ok and res and true or false
    end
    if started('qb-inventory') then
        local ok, res = pcall(function() return exports['qb-inventory']:AddItem(src, name, amount, false, false, 'qb-vehicleshop:auction') end)
        if ok then return res and true or false end
    end
    local Player = QBCore.Functions.GetPlayer(src)
    return (Player and Player.Functions.AddItem and Player.Functions.AddItem(name, amount)) and true or false
end

local function removeItem(src, name, amount)
    if started('ox_inventory') then
        local ok, res = pcall(function() return exports.ox_inventory:RemoveItem(src, name, amount) end)
        return ok and res and true or false
    end
    if started('qb-inventory') then
        local ok, res = pcall(function() return exports['qb-inventory']:RemoveItem(src, name, amount, false, 'qb-vehicleshop:auction') end)
        if ok then return res and true or false end
    end
    local Player = QBCore.Functions.GetPlayer(src)
    return (Player and Player.Functions.RemoveItem and Player.Functions.RemoveItem(name, amount)) and true or false
end

local function removeBidItem(src)
    local count = itemCount(src, ACfg.BidItem)
    if count > 0 and removeItem(src, ACfg.BidItem, count) and QBCore.Shared.Items[ACfg.BidItem] then
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[ACfg.BidItem], 'remove')
    end
end

local function cleanup(reasonMsg, kind)
    if not A then return end
    if reasonMsg then notifyAuction(reasonMsg, kind) end
    local old = A
    A = nil
    for src in pairs(old.participants) do removeBidItem(src) end
    for src in pairs(old.invited) do TriggerClientEvent('qb-vehicleshop:auction:client:auctionInviteClose', src) end
    broadcast(true)
end

-- ---------------------------------------------------------------------------
-- Finish: walk bids from highest down until someone can actually pay.
-- ---------------------------------------------------------------------------

local function finish()
    if not A or A.finishing then return end
    A.finishing = true
    local auction = A
    local tried = {}
    for i = #auction.bids, 1, -1 do
        local bid = auction.bids[i]
        if not tried[bid.src] then
            tried[bid.src] = true
            local Player = QBCore.Functions.GetPlayer(bid.src)
            if Player and Player.PlayerData.citizenid == bid.citizenid and VShop.WaitLock(bid.src, 3000) then
                local ok, plate = pcall(function()
                    local paid = VShop.TakeMoney(Player, bid.amount, ACfg.MoneyType, 'vehicle-auction', false)
                    if not paid then return nil end
                    local p = VShop.GiveVehicle(bid.src, Player, auction.model, auction.location.deliverySpawn, {
                        garage = ACfg.DefaultGarage, warp = ACfg.WarpIntoVehicle, cfg = 'auction', reason = 'Auction Win',
                    })
                    if not p then Player.Functions.AddMoney(paid, bid.amount, 'vehicle-auction-refund') end
                    return p
                end)
                VShop.Unlock(bid.src)
                if not ok then print(('^1[qb-vehicleshop auction] %s^0'):format(plate)) plate = nil end
                if plate then
                    VShop.Notify(bid.src, ALang.auction_won:format(auction.label, VShared.Comma(bid.amount)), 'success', 9000)
                    local winMsg = ALang.auction_winner_all:format(bid.name, auction.label, VShared.Comma(bid.amount))
                    TriggerClientEvent('qb-vehicleshop:auction:client:auctionResult', -1, { label = auction.label, winner = bid.name, amount = bid.amount, winnerId = bid.src })
                    if A == auction then cleanup(winMsg, 'success') end -- (unless cancelled meanwhile)
                    return
                end
            end
        end
    end
    if A == auction then cleanup(ALang.auction_no_bids, 'error') end
end

-- ---------------------------------------------------------------------------
-- Main loop
-- ---------------------------------------------------------------------------

local function startRunning()
    A.state = 'running'
    A.startsAt = nil
    for src in pairs(A.accepted) do
        if inZone(src) then
            local Player = QBCore.Functions.GetPlayer(src)
            if Player and addItem(src, ACfg.BidItem, 1) then
                A.participants[src] = { name = VShop.CharName(Player), cid = Player.PlayerData.citizenid }
                A.participantCount = (A.participantCount or 0) + 1
                if QBCore.Shared.Items[ACfg.BidItem] then
                    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[ACfg.BidItem], 'add')
                end
            end
        end
    end
    A.endsAt = now() + ACfg.Duration * 1000
    notifyAuction(ALang.auction_started, 'success')
    broadcast(true)
end

local function tick()
    local t = now()

    if A.state == 'lobby' or A.state == 'countdown' then
        if t - A.createdAt > ACfg.LobbyTimeout * 1000 then
            return cleanup(ALang.auction_lobby_timeout, 'error')
        end

        local zone = playersInZone()
        -- Invites go out once enough people are standing in the radius
        -- (and keep going out to anyone who walks in after that).
        if #zone >= ACfg.MinParticipants or next(A.accepted) then
            for _, src in ipairs(zone) do
                if not A.invited[src] then
                    A.invited[src] = true
                    TriggerClientEvent('qb-vehicleshop:auction:client:auctionInvite', src, {
                        label = A.label, startPrice = A.startPrice, increment = A.increment,
                        timeout = ACfg.InviteTimeout,
                    })
                end
            end
        end

        A.acceptedInZone = countAcceptedInZone()
        local ready = A.acceptedInZone >= ACfg.MinParticipants
        if A.state == 'lobby' and ready and ACfg.AutoStart then
            A.state = 'countdown'
            A.startsAt = t + ACfg.StartCountdown * 1000
            notifyAuction(ALang.auction_ready:format(ACfg.StartCountdown), 'success')
        elseif A.state == 'countdown' then
            if not ready then
                A.state = 'lobby'
                A.startsAt = nil
            elseif t >= A.startsAt then
                return startRunning()
            end
        end
        return
    end

    if A.state == 'running' then
        if A.topBidder and t - A.lastBidAt >= ACfg.SoldAfter * 1000 then return finish() end
        if t >= A.endsAt then return finish() end
    end
end

local function runLoop(auctionId)
    CreateThread(function()
        while A and A.id == auctionId do
            tick()
            if A and A.id == auctionId then broadcast(false) end
            -- the lobby scans every player's position, so it runs slower
            Wait((A and A.state == 'lobby') and 1000 or 250)
        end
    end)
end

-- ---------------------------------------------------------------------------
-- Admin
-- ---------------------------------------------------------------------------

local nextAuctionId = 1

QBCore.Commands.Add('auction', 'Create a vehicle auction (admin)', {}, false, function(source)
    if not VShop.IsAdmin(source, ACfg.AdminGroups) then return VShop.Notify(source, ALang.no_permission, 'error') end
    if A then return VShop.Notify(source, ALang.auction_busy, 'error') end
    TriggerClientEvent('qb-vehicleshop:auction:client:auctionAdminForm', source)
end)

QBCore.Commands.Add('auctioncancel', 'Cancel the running vehicle auction (admin)', {}, false, function(source)
    if not VShop.IsAdmin(source, ACfg.AdminGroups) then return VShop.Notify(source, ALang.no_permission, 'error') end
    if not A then return VShop.Notify(source, ALang.auction_not_running, 'error') end
    cleanup(ALang.auction_cancelled, 'error')
end)

QBCore.Commands.Add('auctionstart', 'Force-start the auction once enough players accepted (admin)', {}, false, function(source)
    if not VShop.IsAdmin(source, ACfg.AdminGroups) then return VShop.Notify(source, ALang.no_permission, 'error') end
    if not A or A.state == 'running' then return VShop.Notify(source, ALang.auction_not_running, 'error') end
    if countAcceptedInZone() < ACfg.MinParticipants then
        return VShop.Notify(source, ALang.auction_created:format(ACfg.MinParticipants), 'error')
    end
    startRunning()
end)

RegisterNetEvent('qb-vehicleshop:auction:server:auctionCreate', function(data)
    local src = source
    if not VShop.IsAdmin(src, ACfg.AdminGroups) then return VShop.Notify(src, ALang.no_permission, 'error') end
    if A then return VShop.Notify(src, ALang.auction_busy, 'error') end
    if type(data) ~= 'table' then return end

    local model = tostring(data.model or ''):lower():gsub('[^%w_]', ''):sub(1, 40)
    if model == '' or (ACfg.RequireSharedVehicle and not QBCore.Shared.Vehicles[model]) then
        return VShop.Notify(src, ALang.auction_bad_model, 'error')
    end
    local startPrice = VShop.PositiveInt(data.startPrice, 2000000000)
    if not startPrice or startPrice < ACfg.MinStartPrice then
        return VShop.Notify(src, ALang.auction_bad_price:format(ACfg.MinStartPrice), 'error')
    end
    local increment = VShop.PositiveInt(data.increment, 2000000000)
    if not increment or increment < ACfg.MinIncrement then
        return VShop.Notify(src, ALang.auction_bad_increment:format(ACfg.MinIncrement), 'error')
    end
    local locIndex = math.tointeger(tonumber(data.location))
    local location = locIndex and ACfg.Locations[locIndex]
    if not location then return end
    if not itemExists(ACfg.BidItem) then
        return VShop.Notify(src, ALang.auction_missing_item:format(ACfg.BidItem), 'error', 9000)
    end

    local Player = QBCore.Functions.GetPlayer(src)
    A = {
        id = nextAuctionId,
        state = 'lobby',
        admin = src,
        adminName = Player and VShop.CharName(Player) or 'Admin',
        model = model,
        label = VShop.VehicleLabel(model),
        startPrice = startPrice,
        increment = increment,
        price = startPrice,
        locIndex = locIndex,
        location = location,
        invited = {}, accepted = {}, participants = {},
        participantCount = 0, acceptedInZone = 0,
        bids = {},
        createdAt = now(),
    }
    nextAuctionId = nextAuctionId + 1

    VShop.Notify(src, ALang.auction_created:format(ACfg.MinParticipants), 'success', 8000)
    TriggerEvent('qb-log:server:CreateLog', 'vehicleshop', 'Auction Created', 'blue',
        ('**%s** started an auction: %s from $%s (+$%s) at %s'):format(GetPlayerName(src) or '?', model, startPrice, increment, location.label))
    broadcast(true)
    runLoop(A.id)
end)

-- ---------------------------------------------------------------------------
-- Players
-- ---------------------------------------------------------------------------

RegisterNetEvent('qb-vehicleshop:auction:server:auctionRespond', function(accept)
    local src = source
    if not A or A.state == 'running' or not A.invited[src] or src == A.admin then return end
    if not VShop.Cooldown(src, 'auctionRespond', 500) then return end
    if accept == true then
        if not inZone(src) then return VShop.Notify(src, ALang.auction_out_of_range, 'error') end
        A.accepted[src] = true
        VShop.Notify(src, ALang.auction_joined, 'success')
    else
        A.accepted[src] = nil
    end
    A.acceptedInZone = countAcceptedInZone()
    broadcast(false)
end)

local function placeBid(src)
    if not A or A.state ~= 'running' then
        removeBidItem(src)
        return VShop.Notify(src, ALang.auction_not_running, 'error')
    end
    if not VShop.Cooldown(src, 'auctionBid', 400) then return end
    local p = A.participants[src]
    local Player = QBCore.Functions.GetPlayer(src)
    if not p or not Player or Player.PlayerData.citizenid ~= p.cid then
        return VShop.Notify(src, ALang.auction_not_participant, 'error')
    end
    if not inZone(src) then return VShop.Notify(src, ALang.auction_out_of_range, 'error') end
    if A.topBidder == src then return VShop.Notify(src, ALang.auction_already_top, 'error') end

    local amount = A.topBidder and (A.price + A.increment) or A.startPrice
    if (Player.PlayerData.money[ACfg.MoneyType] or 0) < amount then
        return VShop.Notify(src, ALang.auction_cant_afford:format(VShared.Comma(amount)), 'error')
    end

    A.price = amount
    A.topBidder = src
    A.topName = p.name
    A.lastBidAt = now()
    A.bids[#A.bids + 1] = { src = src, citizenid = p.cid, name = p.name, amount = amount }

    VShop.Notify(src, ALang.auction_bid_placed:format(VShared.Comma(amount)), 'success', 3000)
    TriggerClientEvent('qb-vehicleshop:auction:client:auctionBid', -1, { name = p.name, amount = amount, id = src })
    broadcast(true)
end

CreateThread(function()
    QBCore.Functions.CreateUseableItem(ACfg.BidItem, function(source)
        placeBid(source)
    end)
end)

QBCore.Functions.CreateCallback('qb-vehicleshop:auction:server:auctionState', function(_, cb)
    cb(publicState())
end)

-- A player who logs in holding a leftover paddle (crash / disconnect mid auction) loses it.
AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    local src = Player and Player.PlayerData and Player.PlayerData.source
    if src and not (A and A.participants[src]) then removeBidItem(src) end
end)

AddEventHandler('playerDropped', function()
    local src = source
    if not A then return end
    A.accepted[src] = nil
    A.invited[src] = nil
    if src == A.admin then
        -- The auction keeps going without its creator; bids/win still work.
        A.admin = 0
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and A then
        for src in pairs(A.participants) do removeBidItem(src) end
    end
end)
