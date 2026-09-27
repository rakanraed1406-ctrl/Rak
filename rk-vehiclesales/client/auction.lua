--[[ client/auction.lua — auction display car, invite (YES/NO), admin form, top-right HUD ]]

local ACfg = Config.Auction
local auction = { active = false }
local displayVeh = nil
local displayFor = nil -- auction id the display car belongs to
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
    VSC.DeleteLocal(displayVeh)
    displayVeh, displayFor = nil, nil
end

-- Keep the display car + HUD in step with the server state.
local function refresh()
    local loc = location()
    if not loc then
        clearDisplay()
        SendNUIMessage({ action = 'auctionHud', show = false })
        return
    end

    local pos = GetEntityCoords(PlayerPedId())
    local dist = #(pos - loc.center)

    if dist < (Config.DisplayDistance or 90.0) then
        if displayFor ~= auction.id or not displayVeh or not DoesEntityExist(displayVeh) then
            clearDisplay()
            displayVeh = VSC.SpawnDisplay(auction.model, loc.vehicleSpawn, 'AUCTION')
            displayFor = auction.id
        end
    elseif displayVeh then
        clearDisplay()
    end

    -- HUD: participants + the admin always, spectators while near the zone.
    local show = isParticipant() or auction.adminId == myId or dist <= (auction.radius or ACfg.Radius) + 10.0
    SendNUIMessage({
        action = 'auctionHud',
        show = show,
        auction = auction,
        me = myId,
        participant = isParticipant(),
        inZone = dist <= (auction.radius or ACfg.Radius),
        itemName = ACfg.BidItem,
    })
end

RegisterNetEvent('rk-vehiclesales:client:auctionState', function(state)
    myId = GetPlayerServerId(PlayerId())
    auction = state or { active = false }
    refresh()
end)

-- Position-based bits (display car streaming, zone flag) between server pushes.
CreateThread(function()
    while true do
        Wait(1500)
        if auction.active then refresh() end
    end
end)

-- Name tag over the auction car.
CreateThread(function()
    while true do
        local sleep = 1000
        local loc = location()
        if loc and displayVeh then
            local pos = GetEntityCoords(PlayerPedId())
            if #(pos - loc.center) < 25.0 then
                sleep = 0
                local v = loc.vehicleSpawn
                local line2 = auction.state == 'running'
                    and ('~g~$%s~s~ · %s'):format(VSC.FormatMoney(auction.price), auction.topName or '—')
                    or ('~y~%s/%s~s~'):format(auction.accepted or 0, auction.needed or ACfg.MinParticipants)
                VSC.Draw3DText(v.x, v.y, v.z + 1.6, ('~o~AUCTION~s~ · %s~n~%s'):format(auction.label or '', line2))
            end
        end
        Wait(sleep)
    end
end)

-- ---------------------------------------------------------------------------
-- Invite (YES / NO)
-- ---------------------------------------------------------------------------

RegisterNetEvent('rk-vehiclesales:client:auctionInvite', function(data)
    VSC.Focus(true)
    SendNUIMessage({ action = 'auctionInvite', data = data })
end)

RegisterNetEvent('rk-vehiclesales:client:auctionInviteClose', function()
    SendNUIMessage({ action = 'auctionInviteClose' })
    if VSC.nuiFocus then VSC.Focus(false) end
end)

RegisterNUICallback('auctionRespond', function(data, cb)
    VSC.Focus(false)
    TriggerServerEvent('rk-vehiclesales:server:auctionRespond', data.accept == true)
    cb('ok')
end)

-- ---------------------------------------------------------------------------
-- Admin form
-- ---------------------------------------------------------------------------

RegisterNetEvent('rk-vehiclesales:client:auctionAdminForm', function()
    local locations = {}
    for i, loc in ipairs(ACfg.Locations) do locations[i] = { index = i, label = loc.label } end
    VSC.Focus(true)
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
    VSC.Focus(false)
    TriggerServerEvent('rk-vehiclesales:server:auctionCreate', {
        model = data.model, startPrice = data.startPrice, increment = data.increment, location = data.location,
    })
    cb('ok')
end)

-- ---------------------------------------------------------------------------
-- Bid flash + result banner
-- ---------------------------------------------------------------------------

RegisterNetEvent('rk-vehiclesales:client:auctionBid', function(bid)
    if not (isParticipant() or auction.adminId == myId) then
        local loc = location()
        if not loc or #(GetEntityCoords(PlayerPedId()) - loc.center) > (ACfg.Radius + 10.0) then return end
    end
    SendNUIMessage({ action = 'auctionBid', bid = bid, me = myId })
    PlaySoundFrontend(-1, 'ROBBERY_MONEY_TOTAL', 'HUD_FRONTEND_CUSTOM_SOUNDSET', true)
end)

RegisterNetEvent('rk-vehiclesales:client:auctionResult', function(result)
    local loc = location()
    local near = loc and #(GetEntityCoords(PlayerPedId()) - loc.center) <= ACfg.Radius + 30.0
    if isParticipant() or auction.adminId == myId or near then
        SendNUIMessage({ action = 'auctionResult', result = result, me = myId })
        if result and result.winnerId == myId then
            PlaySoundFrontend(-1, 'MEDAL_GOLD', 'HUD_AWARDS', true)
        end
    end
end)

local function syncState()
    QBCore.Functions.TriggerCallback('rk-vehiclesales:server:auctionState', function(state)
        myId = GetPlayerServerId(PlayerId())
        auction = state or { active = false }
        refresh()
    end)
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', syncState)
CreateThread(function()
    Wait(2500)
    if LocalPlayer.state.isLoggedIn then syncState() end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then clearDisplay() end
end)
