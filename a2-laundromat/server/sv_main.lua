local QBCore = exports['qb-core']:GetCoreObject()

-- One robbery for the whole server. The old version kept everything on the client:
-- anyone could fire the loot events without breaking in, the "only once" check reset
-- on reconnect, and the doors only opened for the robber (police couldn't get in).
local State = {
    doorsOpen = false,        -- main doors hacked (hacking device)
    officeOpen = false,       -- office hacked (laptop) → safe can be opened
    officeDoorsOpen = false,  -- office door forced with a crowbar
    looted = {},              -- [spot] = true
    resetAt = 0,
}
local Pending = {} -- [src] = { action, spot, at, time }

local ACTIONS = {
    hack = { time = Config.HackTime },
    office = { time = Config.HackTime },
    officedoor = { time = 0 },
    loot = { time = Config.SmashTime },
}

local function Notify(src, msg, kind) TriggerClientEvent('QBCore:Notify', src, msg, kind or 'primary') end

local function PublicState()
    return { doorsOpen = State.doorsOpen, officeOpen = State.officeOpen, officeDoorsOpen = State.officeDoorsOpen, looted = State.looted }
end

local function Broadcast()
    TriggerClientEvent('a2-laundromat:client:SyncState', -1, PublicState())
end

local function CopCount()
    local jobs = {}
    for _, j in ipairs(Config.PoliceJobs) do jobs[j] = true end
    local n = 0
    for _, p in pairs(QBCore.Functions.GetQBPlayers()) do
        local job = p.PlayerData.job
        if job and (jobs[job.name] or job.type == 'leo') and job.onduty then n = n + 1 end
    end
    return n
end

local function NearLaundromat(src)
    local ped = GetPlayerPed(src)
    return ped ~= 0 and #(GetEntityCoords(ped) - Config.Location) <= Config.Radius
end

local function HasItem(Player, name)
    return Player.Functions.GetItemByName(name) ~= nil
end

local function Reset()
    State.doorsOpen, State.officeOpen, State.officeDoorsOpen = false, false, false
    State.looted, State.resetAt = {}, 0
    Broadcast()
end

local function Dispatch(src)
    local ped = GetPlayerPed(src)
    local coords = ped ~= 0 and GetEntityCoords(ped) or Config.Location
    -- police tablet (mdt-police-tablet) — also covers scripts that still listen to cd_dispatch
    TriggerEvent('mdt:server:CreateDispatchCall', {
        code = '10-111', title = 'Laundromat Robbery', priority = 'high',
        description = 'Alarm triggered: the laundromat doors were hacked', coords = coords,
        tags = { { icon = 'fa-shirt', label = 'Laundromat' } },
    }, 'police')
end

-- Checks before the minigame starts.
QBCore.Functions.CreateCallback('a2-laundromat:server:CanStart', function(src, cb, action, spot)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not ACTIONS[action] then return cb(false) end
    if not NearLaundromat(src) then return cb(false, 'You are too far away') end
    if CopCount() < Config.MinimumHouseRobberyPolice then return cb(false, 'Not enough cops on duty!') end

    if action == 'hack' then
        if State.doorsOpen then return cb(false, 'The doors are already open — the laundromat was robbed recently') end
        if not HasItem(Player, Config.Items.Hack) then return cb(false, 'You do not have a hacking device!') end
    elseif action == 'office' then
        if not State.doorsOpen then return cb(false, 'You must unlock the doors first!') end
        if State.officeOpen then return cb(false, 'The office is already open') end
        if not HasItem(Player, Config.Items.Laptop) then return cb(false, 'You do not have a hacking laptop!') end
    elseif action == 'officedoor' then
        if not State.doorsOpen then return cb(false, 'You must unlock the doors first!') end
        if State.officeDoorsOpen then return cb(false, 'This door is already open') end
        if not HasItem(Player, Config.Items.Crowbar) then return cb(false, 'You do not have a crowbar!') end
    elseif action == 'loot' then
        spot = tonumber(spot)
        local loot = spot and Config.Loot[spot]
        if not loot then return cb(false) end
        if not State.doorsOpen then return cb(false, 'You must unlock the doors first!') end
        if loot.office and not State.officeOpen then return cb(false, 'Hack the office first!') end
        if State.looted[spot] then return cb(false, 'Someone already emptied this') end
        if not HasItem(Player, Config.Items.Crowbar) then return cb(false, 'You do not have a crowbar!') end
    end

    Pending[src] = { action = action, spot = spot, at = GetGameTimer() }
    cb(true)
end)

RegisterNetEvent('a2-laundromat:server:Cancel', function()
    Pending[source] = nil
end)

RegisterNetEvent('a2-laundromat:server:Finish', function(action, spot)
    local src = source
    local p = Pending[src]
    Pending[src] = nil
    if not p or p.action ~= action or (action == 'loot' and p.spot ~= tonumber(spot)) then return end
    if GetGameTimer() - p.at < (ACTIONS[action].time or 0) * 0.8 then return end -- progress bar skipped
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not NearLaundromat(src) then return end

    if action == 'hack' then
        if State.doorsOpen then return end
        if not Player.Functions.RemoveItem(Config.Items.Hack, 1) then return end
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[Config.Items.Hack], 'remove')
        State.doorsOpen = true
        State.resetAt = os.time() + Config.CooldownMinutes * 60
        Broadcast()
        Dispatch(src)
        Notify(src, 'Both doors are unlocked — the police are on their way!', 'success')
    elseif action == 'office' then
        if not State.doorsOpen or State.officeOpen then return end
        if not Player.Functions.RemoveItem(Config.Items.Laptop, 1) then return end
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[Config.Items.Laptop], 'remove')
        State.officeOpen, State.officeDoorsOpen = true, true
        Broadcast()
        Notify(src, 'The office is unlocked!', 'success')
    elseif action == 'officedoor' then
        if not State.doorsOpen then return end
        State.officeDoorsOpen = true
        Broadcast()
        Notify(src, 'The door is open!', 'success')
    elseif action == 'loot' then
        spot = tonumber(spot)
        local loot = Config.Loot[spot]
        if not loot or State.looted[spot] or not State.doorsOpen or (loot.office and not State.officeOpen) then return end
        State.looted[spot] = true
        Broadcast()
        if Player.Functions.AddItem(loot.item, loot.amount) then
            TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[loot.item], 'add')
            local label = QBCore.Shared.Items[loot.item] and QBCore.Shared.Items[loot.item].label or loot.item
            Notify(src, ('You received %dx %s'):format(loot.amount, label), 'success')
        else
            State.looted[spot] = nil -- inventory full: leave it for later
            Broadcast()
            Notify(src, 'Your pockets are full', 'error')
        end
    end
end)

QBCore.Functions.CreateCallback('a2-laundromat:server:GetState', function(_, cb)
    cb(PublicState())
end)

-- Lock everything again after the cooldown.
CreateThread(function()
    while true do
        Wait(30000)
        if State.doorsOpen and State.resetAt > 0 and os.time() >= State.resetAt then Reset() end
    end
end)

AddEventHandler('playerDropped', function() Pending[source] = nil end)

-- Admin: /resetlaundromat
QBCore.Commands.Add('resetlaundromat', 'Reset the laundromat robbery (lock the doors)', {}, false, function(src)
    Reset()
    Notify(src, 'Laundromat reset', 'success')
end, 'admin')
