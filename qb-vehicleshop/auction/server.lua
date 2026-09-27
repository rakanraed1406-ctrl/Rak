--[[ server/auction.lua — admin car auctions

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
]]


local QBCore = exports['qb-core']:GetCoreObject()
local VS = {}

function VS.Notify(src, msg, kind, ms)
    TriggerClientEvent('QBCore:Notify', src, msg, kind or 'primary', ms or 5000)
end

function VS.IsAdmin(src)
    if src == 0 then return true end -- server console
    for _, group in ipairs(Config.Auction.AdminGroups or {}) do
        if QBCore.Functions.HasPermission(src, group) then return true end
    end
    return IsPlayerAceAllowed(src, 'command')
end

function VS.CharName(Player)
    local ci = Player and Player.PlayerData.charinfo or {}
    return ((ci.firstname or 'Unknown') .. ' ' .. (ci.lastname or '')):gsub('%s+$', '')
end

function VS.VehicleLabel(model)
    local v = QBCore.Shared.Vehicles[model]
    if v then
        local name = v.name or model
        if v.brand and v.brand ~= '' then return v.brand .. ' ' .. name end
        return name
    end
    return model
end

function VS.Money(Player)
    return Player.PlayerData.money[Config.Auction.MoneyType] or 0
end

function VS.DistanceTo(src, coords)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return math.huge end
    local p = GetEntityCoords(ped)
    return #(vector3(p.x, p.y, p.z) - vector3(coords.x, coords.y, coords.z))
end

-- Unique plate (8 chars like "AB12CD34"), checked against player_vehicles.
local charset = 'ABCDEFGHJKLMNPQRSTUVWXYZ'
local function randomPlate()
    local out = {}
    for i = 1, 8 do
        if i % 2 == 1 then
            local n = math.random(1, #charset)
            out[i] = charset:sub(n, n)
        else
            out[i] = tostring(math.random(0, 9))
        end
    end
    return table.concat(out)
end

function VS.GeneratePlate()
    for _ = 1, 25 do
        local plate = randomPlate()
        local taken = MySQL.scalar.await('SELECT 1 FROM player_vehicles WHERE plate = ?', { plate })
        if not taken then return plate end
    end
    return randomPlate()
end

--- Saves the vehicle to the player's garage table and tells their client to
--- spawn it at `spawn` and hand over the keys.
function VS.GiveVehicle(src, model, spawn, reason)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false end
    local plate = VS.GeneratePlate()

    MySQL.insert.await(
        'INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, garage, state) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        { Player.PlayerData.license, Player.PlayerData.citizenid, model, joaat(model), '{}', plate, Config.Auction.DefaultGarage, 0 }
    )

    TriggerClientEvent('qb-vehicleshop:auction:client:deliverVehicle', src, {
        model = model,
        plate = plate,
        spawn = { x = spawn.x, y = spawn.y, z = spawn.z, w = spawn.w },
    })

    TriggerEvent('qb-log:server:CreateLog', 'vehicleshop', reason or 'Vehicle Purchase', 'green',
        ('**%s** (%s) got **%s** [%s]'):format(GetPlayerName(src) or '?', Player.PlayerData.citizenid, model, plate))
    return plate
end

local ACfg = Config.Auction
local A = nil -- the one running auction (only one at a time)

local function now() return GetGameTimer() end

local function inZone(src)
    return A and VS.DistanceTo(src, A.location.center) <= ACfg.Radius
end

local function playersInZone()
    local list = {}
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if src ~= A.admin and QBCore.Functions.GetPlayer(src) and inZone(src) then
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
    for src in pairs(A.participants) do ids[#ids + 1] = src; n = n + 1 end
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
        accepted = A.state ~= 'running' and countAcceptedInZone() or n,
        needed = ACfg.MinParticipants,
        endsIn = A.endsAt and math.max(0, A.endsAt - t) or nil,
        soldIn = (A.state == 'running' and A.topBidder) and math.max(0, A.lastBidAt + ACfg.SoldAfter * 1000 - t) or nil,
        startsIn = A.startsAt and math.max(0, A.startsAt - t) or nil,
        soldAfter = ACfg.SoldAfter,
    }
end

local function broadcast()
    TriggerClientEvent('qb-vehicleshop:auction:client:auctionState', -1, publicState())
end

local function notifyAuction(msg, kind)
    if not A then return end
    local sent = {}
    local function send(src) if src and src > 0 and not sent[src] then sent[src] = true; VS.Notify(src, msg, kind, 7000) end end
    send(A.admin)
    for src in pairs(A.participants) do send(src) end
    for src in pairs(A.accepted) do send(src) end
end

local function removeBidItem(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local item = Player.Functions.GetItemByName(ACfg.BidItem)
    if item then
        Player.Functions.RemoveItem(ACfg.BidItem, item.amount or 1)
        if QBCore.Shared.Items[ACfg.BidItem] then
            TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[ACfg.BidItem], 'remove')
        end
    end
end

local function cleanup(reasonMsg, kind)
    if not A then return end
    if reasonMsg then notifyAuction(reasonMsg, kind) end
    for src in pairs(A.participants) do removeBidItem(src) end
    for src in pairs(A.invited) do TriggerClientEvent('qb-vehicleshop:auction:client:auctionInviteClose', src) end
    A = nil
    broadcast()
end

-- ---------------------------------------------------------------------------
-- Finish: walk bids from highest down until someone can actually pay.
-- ---------------------------------------------------------------------------

local function finish()
    if not A then return end
    local tried = {}
    for i = #A.bids, 1, -1 do
        local bid = A.bids[i]
        if not tried[bid.src] then
            tried[bid.src] = true
            local Player = QBCore.Functions.GetPlayer(bid.src)
            if Player and Player.PlayerData.citizenid == bid.citizenid
                and VS.Money(Player) >= bid.amount
                and Player.Functions.RemoveMoney(Config.Auction.MoneyType, bid.amount, 'vehicle-auction') then

                VS.GiveVehicle(bid.src, A.model, A.location.deliverySpawn, 'Auction Win')
                VS.Notify(bid.src, Config.AuctionLang.auction_won:format(A.label, bid.amount), 'success', 9000)
                local winMsg = Config.AuctionLang.auction_winner_all:format(bid.name, A.label, bid.amount)
                TriggerClientEvent('qb-vehicleshop:auction:client:auctionResult', -1, { label = A.label, winner = bid.name, amount = bid.amount, winnerId = bid.src })
                cleanup(winMsg, 'success')
                return
            end
        end
    end
    cleanup(Config.AuctionLang.auction_no_bids, 'error')
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
            if Player and Player.Functions.AddItem(ACfg.BidItem, 1) then
                A.participants[src] = VS.CharName(Player)
                TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[ACfg.BidItem], 'add')
            end
        end
    end
    A.endsAt = now() + ACfg.Duration * 1000
    notifyAuction(Config.AuctionLang.auction_started, 'success')
    broadcast()
end

local function tick()
    local t = now()

    if A.state == 'lobby' or A.state == 'countdown' then
        if t - A.createdAt > ACfg.LobbyTimeout * 1000 then
            return cleanup(Config.AuctionLang.auction_lobby_timeout, 'error')
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

        local ready = countAcceptedInZone() >= ACfg.MinParticipants
        if A.state == 'lobby' and ready and ACfg.AutoStart then
            A.state = 'countdown'
            A.startsAt = t + ACfg.StartCountdown * 1000
            notifyAuction(Config.AuctionLang.auction_ready:format(ACfg.StartCountdown), 'success')
            broadcast()
        elseif A.state == 'countdown' then
            if not ready then
                A.state = 'lobby'
                A.startsAt = nil
                broadcast()
            elseif t >= A.startsAt then
                startRunning()
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
        local lastBroadcast = 0
        while A and A.id == auctionId do
            tick()
            if A and A.id == auctionId and now() - lastBroadcast >= 1000 then
                lastBroadcast = now()
                broadcast()
            end
            Wait(250)
        end
    end)
end

-- ---------------------------------------------------------------------------
-- Admin
-- ---------------------------------------------------------------------------

local nextAuctionId = 1

QBCore.Commands.Add('auction', 'Create a vehicle auction (admin)', {}, false, function(source)
    if not VS.IsAdmin(source) then return VS.Notify(source, Config.AuctionLang.no_permission, 'error') end
    if A then return VS.Notify(source, Config.AuctionLang.auction_busy, 'error') end
    TriggerClientEvent('qb-vehicleshop:auction:client:auctionAdminForm', source)
end)

QBCore.Commands.Add('auctioncancel', 'Cancel the running vehicle auction (admin)', {}, false, function(source)
    if not VS.IsAdmin(source) then return VS.Notify(source, Config.AuctionLang.no_permission, 'error') end
    if not A then return VS.Notify(source, Config.AuctionLang.auction_not_running, 'error') end
    cleanup(Config.AuctionLang.auction_cancelled, 'error')
end)

QBCore.Commands.Add('auctionstart', 'Force-start the auction once enough players accepted (admin)', {}, false, function(source)
    if not VS.IsAdmin(source) then return VS.Notify(source, Config.AuctionLang.no_permission, 'error') end
    if not A or A.state == 'running' then return VS.Notify(source, Config.AuctionLang.auction_not_running, 'error') end
    if countAcceptedInZone() < ACfg.MinParticipants then
        return VS.Notify(source, Config.AuctionLang.auction_created:format(ACfg.MinParticipants), 'error')
    end
    startRunning()
end)

RegisterNetEvent('qb-vehicleshop:auction:server:auctionCreate', function(data)
    local src = source
    if not VS.IsAdmin(src) then return VS.Notify(src, Config.AuctionLang.no_permission, 'error') end
    if A then return VS.Notify(src, Config.AuctionLang.auction_busy, 'error') end
    if type(data) ~= 'table' then return end

    local model = tostring(data.model or ''):lower():gsub('[^%w_]', '')
    if model == '' or (ACfg.RequireSharedVehicle and not QBCore.Shared.Vehicles[model]) then
        return VS.Notify(src, Config.AuctionLang.auction_bad_model, 'error')
    end
    local startPrice = math.floor(tonumber(data.startPrice) or 0)
    if startPrice < ACfg.MinStartPrice then
        return VS.Notify(src, Config.AuctionLang.auction_bad_price:format(ACfg.MinStartPrice), 'error')
    end
    local increment = math.floor(tonumber(data.increment) or 0)
    if increment < ACfg.MinIncrement then
        return VS.Notify(src, Config.AuctionLang.auction_bad_increment:format(ACfg.MinIncrement), 'error')
    end
    local locIndex = math.floor(tonumber(data.location) or 0)
    local location = ACfg.Locations[locIndex]
    if not location then return end
    if not QBCore.Shared.Items[ACfg.BidItem] then
        return VS.Notify(src, Config.AuctionLang.auction_missing_item:format(ACfg.BidItem), 'error', 9000)
    end

    local Player = QBCore.Functions.GetPlayer(src)
    A = {
        id = nextAuctionId,
        state = 'lobby',
        admin = src,
        adminName = Player and VS.CharName(Player) or 'Admin',
        model = model,
        label = VS.VehicleLabel(model),
        startPrice = startPrice,
        increment = increment,
        price = startPrice,
        locIndex = locIndex,
        location = location,
        invited = {}, accepted = {}, participants = {},
        bids = {},
        createdAt = now(),
    }
    nextAuctionId = nextAuctionId + 1

    VS.Notify(src, Config.AuctionLang.auction_created:format(ACfg.MinParticipants), 'success', 8000)
    TriggerEvent('qb-log:server:CreateLog', 'vehicleshop', 'Auction Created', 'blue',
        ('**%s** started an auction: %s from $%s (+$%s) at %s'):format(GetPlayerName(src) or '?', model, startPrice, increment, location.label))
    broadcast()
    runLoop(A.id)
end)

-- ---------------------------------------------------------------------------
-- Players
-- ---------------------------------------------------------------------------

RegisterNetEvent('qb-vehicleshop:auction:server:auctionRespond', function(accept)
    local src = source
    if not A or A.state == 'running' or not A.invited[src] or src == A.admin then return end
    if accept == true then
        if not inZone(src) then return VS.Notify(src, Config.AuctionLang.auction_out_of_range, 'error') end
        A.accepted[src] = true
        VS.Notify(src, Config.AuctionLang.auction_joined, 'success')
    else
        A.accepted[src] = nil
    end
    broadcast()
end)

local function placeBid(src)
    if not A or A.state ~= 'running' then
        removeBidItem(src)
        return VS.Notify(src, Config.AuctionLang.auction_not_running, 'error')
    end
    if not A.participants[src] then return VS.Notify(src, Config.AuctionLang.auction_not_participant, 'error') end
    if not inZone(src) then return VS.Notify(src, Config.AuctionLang.auction_out_of_range, 'error') end
    if A.topBidder == src then return VS.Notify(src, Config.AuctionLang.auction_already_top, 'error') end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local amount = A.topBidder and (A.price + A.increment) or A.startPrice
    if VS.Money(Player) < amount then
        return VS.Notify(src, Config.AuctionLang.auction_cant_afford:format(amount), 'error')
    end

    A.price = amount
    A.topBidder = src
    A.topName = VS.CharName(Player)
    A.lastBidAt = now()
    A.bids[#A.bids + 1] = { src = src, citizenid = Player.PlayerData.citizenid, name = A.topName, amount = amount }

    VS.Notify(src, Config.AuctionLang.auction_bid_placed:format(amount), 'success', 3000)
    TriggerClientEvent('qb-vehicleshop:auction:client:auctionBid', -1, { name = A.topName, amount = amount, id = src })
    broadcast()
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
