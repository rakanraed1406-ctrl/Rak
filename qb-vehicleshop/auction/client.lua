--[[ auction/client.lua — auction display car, invite (YES/NO), admin form, top-right HUD.
     Nothing runs while there is no auction: the watcher thread starts when
     one becomes active and stops when it ends. ]]

local QBCore = exports['qb-core']:GetCoreObject()
local ACfg = Config.Auction

local auction = { active = false }
local recvAt = 0          -- GetGameTimer() when `auction` arrived (timers are relative)
local displayVeh = nil
local displayFor = nil    -- auction id the display car belongs to
local watching = false
local displayLoading = false
local hudShown = false
local myId = GetPlayerServerId(PlayerId())

local function location()
    return auction.active and ACfg.Locations[auction.locIndex] or nil
end

local function isParticipant()
    for _, id in ipairs(auction.participants or {}) do
        if id == myId then return true end
    end
    return false
end

local function clearDisplay()
    VShopC.DeleteLocal(displayVeh)
    displayVeh, displayFor = nil, nil
end

-- the server sends "ms left" values; age them before handing them to the UI
local function aged(ms)
    if ms == nil then return nil end
    return math.max(0, ms - (GetGameTimer() - recvAt))
end

local function hudState()
    local a = {}
    for k, v in pairs(auction) do a[k] = v end
    a.endsIn, a.soldIn, a.startsIn = aged(auction.endsIn), aged(auction.soldIn), aged(auction.startsIn)
    return a
end

-- Keep the display car + HUD in step with the server state.
local function refresh()
    local loc = location()
    if not loc then
        clearDisplay()
        if hudShown then
            hudShown = false
            SendNUIMessage({ action = 'auctionHud', show = false })
        end
        return
    end

    local dist = #(GetEntityCoords(PlayerPedId()) - loc.center)

    if dist < (ACfg.DisplayDistance or 90.0) then
        if not displayLoading and (displayFor ~= auction.id or not displayVeh or not DoesEntityExist(displayVeh)) then
            clearDisplay()
            displayLoading = true
            local id = auction.id
            local veh = VShopC.SpawnDisplay(auction.model, loc.vehicleSpawn, 'AUCTION')
            displayLoading = false
            if auction.active and auction.id == id and not displayVeh then
                displayVeh, displayFor = veh, id
            else
                VShopC.DeleteLocal(veh) -- the auction changed while the model loaded
            end
        end
    elseif displayVeh then
        clearDisplay()
    end

    -- HUD: participants + the admin always, spectators while near the zone.
    local participant = isParticipant()
    local radius = auction.radius or ACfg.Radius
    local show = participant or auction.adminId == myId or dist <= radius + 10.0
    if not show and not hudShown then return end -- far away spectator: nothing to send
    hudShown = show
    SendNUIMessage({
        action = 'auctionHud',
        show = show,
        auction = hudState(),
        me = myId,
        participant = participant,
        inZone = dist <= radius,
        itemName = ACfg.BidItem,
    })
end

-- Position-based bits (display car streaming, zone flag, name tag) while an auction runs.
local function startWatcher()
    if watching then return end
    watching = true
    CreateThread(function()
        local lastRefresh = 0
        while auction.active do
            local sleep = 1000
            local loc = location()
            local t = GetGameTimer()
            if t - lastRefresh >= 1500 then
                lastRefresh = t
                refresh()
            end
            if loc and displayVeh and #(GetEntityCoords(PlayerPedId()) - loc.center) < 25.0 then
                sleep = 0
                local v = loc.vehicleSpawn
                local line2 = auction.state == 'running'
                    and ('~g~$%s~s~ · %s'):format(VShopC.FormatMoney(auction.price), auction.topName or '—')
                    or ('~y~%s/%s~s~'):format(auction.accepted or 0, auction.needed or ACfg.MinParticipants)
                VShopC.Draw3DText(v.x, v.y, v.z + 1.6, ('~o~AUCTION~s~ · %s~n~%s'):format(auction.label or '', line2))
            end
            Wait(sleep)
        end
        watching = false
        refresh() -- hides the HUD / removes the car
    end)
end

local function setState(state)
    myId = GetPlayerServerId(PlayerId())
    auction = type(state) == 'table' and state or { active = false }
    recvAt = GetGameTimer()
    refresh()
    if auction.active then startWatcher() end
end

RegisterNetEvent('qb-vehicleshop:auction:client:auctionState', setState)

-- ---------------------------------------------------------------------------
-- Invite (YES / NO)
-- ---------------------------------------------------------------------------

RegisterNetEvent('qb-vehicleshop:auction:client:auctionInvite', function(data)
    VShopC.Focus(true)
    SendNUIMessage({ action = 'auctionInvite', data = data })
end)

RegisterNetEvent('qb-vehicleshop:auction:client:auctionInviteClose', function()
    SendNUIMessage({ action = 'auctionInviteClose' })
    if VShopC.nuiFocus then VShopC.Focus(false) end
end)

RegisterNUICallback('auctionRespond', function(data, cb)
    VShopC.Focus(false)
    TriggerServerEvent('qb-vehicleshop:auction:server:auctionRespond', type(data) == 'table' and data.accept == true)
    cb('ok')
end)

-- ---------------------------------------------------------------------------
-- Admin form
-- ---------------------------------------------------------------------------

RegisterNetEvent('qb-vehicleshop:auction:client:auctionAdminForm', function()
    local locations = {}
    for i, loc in ipairs(ACfg.Locations) do locations[i] = { index = i, label = loc.label } end
    VShopC.Focus(true)
    SendNUIMessage({
        action = 'auctionAdmin',
        locations = locations,
        minStart = ACfg.MinStartPrice,
        minIncrement = ACfg.MinIncrement,
        minParticipants = ACfg.MinParticipants,
        duration = ACfg.Duration,
        soldAfter = ACfg.SoldAfter,
    })
end)

RegisterNUICallback('auctionCreate', function(data, cb)
    VShopC.Focus(false)
    if type(data) == 'table' then
        TriggerServerEvent('qb-vehicleshop:auction:server:auctionCreate', {
            model = data.model, startPrice = data.startPrice, increment = data.increment, location = data.location,
        })
    end
    cb('ok')
end)

-- ---------------------------------------------------------------------------
-- Bid flash + result banner
-- ---------------------------------------------------------------------------

local function nearAuction(extra)
    local loc = location()
    return loc and #(GetEntityCoords(PlayerPedId()) - loc.center) <= ACfg.Radius + extra
end

RegisterNetEvent('qb-vehicleshop:auction:client:auctionBid', function(bid)
    if type(bid) ~= 'table' then return end
    if not (isParticipant() or auction.adminId == myId or nearAuction(10.0)) then return end
    SendNUIMessage({ action = 'auctionBid', bid = bid, me = myId })
    PlaySoundFrontend(-1, 'ROBBERY_MONEY_TOTAL', 'HUD_FRONTEND_CUSTOM_SOUNDSET', true)
end)

RegisterNetEvent('qb-vehicleshop:auction:client:auctionResult', function(result)
    if type(result) ~= 'table' then return end
    if isParticipant() or auction.adminId == myId or nearAuction(30.0) then
        SendNUIMessage({ action = 'auctionResult', result = result, me = myId })
        if result.winnerId == myId then
            PlaySoundFrontend(-1, 'MEDAL_GOLD', 'HUD_AWARDS', true)
        end
    end
end)

local function syncState()
    QBCore.Functions.TriggerCallback('qb-vehicleshop:auction:server:auctionState', setState)
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', syncState)
CreateThread(function()
    Wait(2500)
    if LocalPlayer.state.isLoggedIn then syncState() end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then clearDisplay() end
end)
