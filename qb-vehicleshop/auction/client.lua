--[[ auction/client.lua — auction display car, invite (YES/NO), admin form, top-right HUD ]]

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
        print(('[qb-vehicleshop auction] model "%s" does not exist — check config.lua'):format(model))
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
-- Delivery (showroom purchase + auction win): spawn owned car, give keys
-- ---------------------------------------------------------------------------

local function setFuel(veh)
    local res = Config.Auction.FuelResource
    if res and res ~= '' and GetResourceState(res) == 'started' then
        local ok = pcall(function() exports[res]:SetFuel(veh, 100.0) end)
        if ok then return end
    end
    SetVehicleFuelLevel(veh, 100.0)
end

RegisterNetEvent('qb-vehicleshop:auction:client:deliverVehicle', function(data)
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
            if Config.Auction.WarpIntoVehicle then TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1) end
            Config.Auction.GiveKeys(veh, data.plate)
            SetVehicleEngineOn(veh, true, true, false)
        end
        Wait(300)
        DoScreenFadeIn(300)
    end, data.model, vector4(data.spawn.x, data.spawn.y, data.spawn.z, data.spawn.w or 0.0), true)
end)

-- ---------------------------------------------------------------------------
-- NUI plumbing
-- ---------------------------------------------------------------------------

RegisterNUICallback('close', function(_, cb)
    VSC.Focus(false)
    cb('ok')
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and VSC.nuiFocus then SetNuiFocus(false, false) end
end)

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

    if dist < (Config.Auction.DisplayDistance or 90.0) then
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

RegisterNetEvent('qb-vehicleshop:auction:client:auctionState', function(state)
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

RegisterNetEvent('qb-vehicleshop:auction:client:auctionInvite', function(data)
    VSC.Focus(true)
    SendNUIMessage({ action = 'auctionInvite', data = data })
end)

RegisterNetEvent('qb-vehicleshop:auction:client:auctionInviteClose', function()
    SendNUIMessage({ action = 'auctionInviteClose' })
    if VSC.nuiFocus then VSC.Focus(false) end
end)

RegisterNUICallback('auctionRespond', function(data, cb)
    VSC.Focus(false)
    TriggerServerEvent('qb-vehicleshop:auction:server:auctionRespond', data.accept == true)
    cb('ok')
end)

-- ---------------------------------------------------------------------------
-- Admin form
-- ---------------------------------------------------------------------------

RegisterNetEvent('qb-vehicleshop:auction:client:auctionAdminForm', function()
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
    TriggerServerEvent('qb-vehicleshop:auction:server:auctionCreate', {
        model = data.model, startPrice = data.startPrice, increment = data.increment, location = data.location,
    })
    cb('ok')
end)

-- ---------------------------------------------------------------------------
-- Bid flash + result banner
-- ---------------------------------------------------------------------------

RegisterNetEvent('qb-vehicleshop:auction:client:auctionBid', function(bid)
    if not (isParticipant() or auction.adminId == myId) then
        local loc = location()
        if not loc or #(GetEntityCoords(PlayerPedId()) - loc.center) > (ACfg.Radius + 10.0) then return end
    end
    SendNUIMessage({ action = 'auctionBid', bid = bid, me = myId })
    PlaySoundFrontend(-1, 'ROBBERY_MONEY_TOTAL', 'HUD_FRONTEND_CUSTOM_SOUNDSET', true)
end)

RegisterNetEvent('qb-vehicleshop:auction:client:auctionResult', function(result)
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
    QBCore.Functions.TriggerCallback('qb-vehicleshop:auction:server:auctionState', function(state)
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
