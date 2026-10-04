local QBCore = exports['qb-core']:GetCoreObject()

-- Everything is decided by the server now (cops, items, doors, loot). This file only
-- plays the minigames / animations and keeps the doors in sync for every player.
-- The event names are the same as before, so your interact / target points still work.
local State = { doorsOpen = false, officeOpen = false, officeDoorsOpen = false, looted = {} }
local busy = false

local function Notify(msg, kind) QBCore.Functions.Notify(msg, kind or 'primary') end

local function TriggerCallback(name, ...)
    local p = promise.new()
    QBCore.Functions.TriggerCallback(name, function(...) p:resolve({ ... }) end, ...)
    return table.unpack(Citizen.Await(p))
end

local function LoadDict(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do Wait(10) end
    return HasAnimDictLoaded(dict)
end

-- ── Doors ─────────────────────────────────────────────────────────────────
local function ApplyDoors(list, open)
    for _, door in ipairs(list) do
        local obj = GetClosestObjectOfType(door.coords.x, door.coords.y, door.coords.z, 1.0, door.hash, false, false, false)
        if obj ~= 0 then FreezeEntityPosition(obj, not open) end
    end
end

local function ApplyAllDoors()
    ApplyDoors(Config.Doors, State.doorsOpen)
    ApplyDoors(Config.OfficeDoors, State.officeDoorsOpen or State.officeOpen)
end

RegisterNetEvent('a2-laundromat:client:SyncState', function(state)
    if type(state) ~= 'table' then return end
    State = state
    State.looted = State.looted or {}
    ApplyAllDoors()
end)

-- Doors get re-created when you come back to the area: keep re-applying while close.
CreateThread(function()
    local s = TriggerCallback('a2-laundromat:server:GetState')
    if s then State = s; State.looted = State.looted or {} end
    while true do
        local sleep = 3000
        if #(GetEntityCoords(PlayerPedId()) - Config.Location) < 80.0 then
            ApplyAllDoors()
            sleep = 1000
        end
        Wait(sleep)
    end
end)

-- kept for other scripts that trigger these
RegisterNetEvent('a2-script:client:unlockDoors', ApplyAllDoors)
RegisterNetEvent('a2-script:client:lockDoors', ApplyAllDoors)
RegisterNetEvent('a2-script:client:unlockDoors2222', ApplyAllDoors)
RegisterNetEvent('a2-script:client:lockDoors2222', ApplyAllDoors)

-- ── Minigames ──────────────────────────────────────────────────────────────
local MinigameResource = { lockpick = '2na_lockpick', untangle = 'minigames', words = 'skillchecks' }

local function Minigame(kind, cb)
    local res = MinigameResource[kind]
    if GetResourceState(res) ~= 'started' then
        Notify(('Minigame resource "%s" is not running'):format(res), 'error')
        return cb(false)
    end
    if kind == 'lockpick' then
        -- 2na_lockpick waits until the game is over and returns true / false
        local ok, success = pcall(function()
            return exports['2na_lockpick']:createGame(Config.Lockpick.Stages, Config.Lockpick.MaxFails)
        end)
        return cb(ok and success == true)
    end
    local ok = pcall(function()
        if kind == 'untangle' then
            exports['minigames']:startUntangleGame(30000, 5, cb)
        else
            exports['skillchecks']:startWordsGame(30000, 3, cb)
        end
    end)
    if not ok then cb(false) end
end

-- start check → minigame → animation + progress → server gives the result
local function Run(action, spot, opts)
    if busy then return end
    local ok, err = TriggerCallback('a2-laundromat:server:CanStart', action, spot)
    if not ok then
        if err then Notify(err, 'error') end
        return
    end
    busy = true
    Minigame(opts.game, function(success)
        if not success then
            busy = false
            TriggerServerEvent('a2-laundromat:server:Cancel')
            return Notify(opts.fail or 'You failed!', 'error')
        end
        if not opts.progress then
            busy = false
            return TriggerServerEvent('a2-laundromat:server:Finish', action, spot)
        end
        local ped = PlayerPedId()
        if LoadDict(opts.dict) then
            TaskPlayAnim(ped, opts.dict, opts.anim, 8.0, -8.0, -1, 1, 0, false, false, false)
        end
        QBCore.Functions.Progressbar('a2_laundromat', opts.progress, opts.time, false, true, {
            disableMovement = true, disableCarMovement = true, disableMouse = false, disableCombat = true,
        }, {}, {}, {}, function()
            ClearPedTasks(ped)
            busy = false
            TriggerServerEvent('a2-laundromat:server:Finish', action, spot)
        end, function()
            ClearPedTasks(ped)
            busy = false
            TriggerServerEvent('a2-laundromat:server:Cancel')
            Notify('Canceled', 'error')
        end)
    end)
end

-- Main doors (hacking device)
RegisterNetEvent('a2-script:client:attemptUnlockDoors', function()
    Run('hack', nil, {
        game = 'untangle', progress = 'Hacking...', time = Config.HackTime,
        dict = 'anim@scripted@heist@ig14_elevator_hack@male@', anim = 'hack_loop',
        fail = 'You failed the minigame and the doors remain locked!',
    })
end)

-- Office (laptop) — unlocks the safe
RegisterNetEvent('a2-script:client:attemptUnlockDoors222', function()
    Run('office', nil, {
        game = 'words', progress = 'Hacking...', time = Config.HackTime,
        dict = 'anim@heists@ornate_bank@hack_heels', anim = 'hack_loop',
        fail = 'You failed the minigame and the doors remain locked!',
    })
end)

-- Office door with a crowbar
RegisterNetEvent('a2-laundromat:server:roblaundromat1234', function()
    Run('officedoor', nil, { game = 'untangle' })
end)

-- Loot spots: a2-laundromat:server:roblaundromat, …roblaundromat1 … …roblaundromat13
for spot, loot in pairs(Config.Loot) do
    local event = spot == 0 and 'a2-laundromat:server:roblaundromat' or ('a2-laundromat:server:roblaundromat' .. spot)
    RegisterNetEvent(event, function()
        if loot.office then
            Run('loot', spot, {
                game = 'untangle', progress = 'Opening the safe...', time = Config.SmashTime,
                dict = 'veh@break_in@0h@p_m_one@', anim = 'low_force_entry_ds',
            })
        else
            Run('loot', spot, {
                game = 'lockpick', progress = 'Smashing...', time = Config.SmashTime,
                dict = 'veh@break_in@0h@p_m_one@', anim = 'low_force_entry_ds',
            })
        end
    end)
end
