--[[ common/server.lua — one copy of the helpers the finance/old showroom, the
     stock showroom and the auctions all need: notify, admin check, rate
     limits, money, plates, saving owned cars and spawning vehicles.

     Every vehicle the shop hands out is spawned HERE on the server. Clients
     never pick the model, the place or the plate, and they never send a
     network id back for the server to trust (the old test drive let any
     client delete any vehicle on the server that way). ]]

local QBCore = exports['qb-core']:GetCoreObject()
VShop = { QBCore = QBCore }

function VShop.Notify(src, msg, kind, ms)
    if not src or src <= 0 then
        if src == 0 and msg then print(('[qb-vehicleshop] %s'):format(msg)) end
        return
    end
    TriggerClientEvent('QBCore:Notify', src, msg, kind or 'primary', ms or 5000)
end

function VShop.IsAdmin(src, groups)
    if src == 0 then return true end -- server console
    for _, group in ipairs(groups or {}) do
        if QBCore.Functions.HasPermission(src, group) then return true end
    end
    return IsPlayerAceAllowed(src, 'command')
end

function VShop.CharName(Player)
    local ci = Player and Player.PlayerData.charinfo or {}
    return ((ci.firstname or 'Unknown') .. ' ' .. (ci.lastname or '')):gsub('%s+$', '')
end

function VShop.VehicleLabel(model)
    local v = QBCore.Shared.Vehicles[model]
    if v then
        local name = v.name or model
        if v.brand and v.brand ~= '' then return v.brand .. ' ' .. name end
        return name
    end
    return model
end

function VShop.DistanceTo(src, coords)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return math.huge end
    return #(GetEntityCoords(ped) - vector3(coords.x, coords.y, coords.z))
end

function VShop.DistanceBetween(a, b)
    local pa, pb = GetPlayerPed(a), GetPlayerPed(b)
    if not pa or pa == 0 or not pb or pb == 0 then return math.huge end
    return #(GetEntityCoords(pa) - GetEntityCoords(pb))
end

--- Whole positive number or nil (rejects nan, inf, decimals, negatives, strings like "1e309").
function VShop.PositiveInt(value, max)
    local n = tonumber(value)
    if not n or n ~= n or n == math.huge or n < 1 then return nil end
    n = math.floor(n)
    if max and n > max then return nil end
    return n
end

-- ---------------------------------------------------------------------------
-- Rate limits / per-player locks
-- ---------------------------------------------------------------------------
local cooldowns = {}
local locks = {}

--- true when `key` was not used by `src` within `ms` (and marks it used).
function VShop.Cooldown(src, key, ms)
    local now = GetGameTimer()
    local list = cooldowns[src]
    if not list then
        list = {}
        cooldowns[src] = list
    end
    local last = list[key]
    if last and now - last < ms then return false end
    list[key] = now
    return true
end

--- Serialises money flows that wait on the database (no double spending).
function VShop.Lock(src)
    if locks[src] then return false end
    locks[src] = true
    return true
end

function VShop.Unlock(src) locks[src] = nil end

--- Like Lock, but waits up to `ms` for another flow of this player to finish.
function VShop.WaitLock(src, ms)
    local timeout = GetGameTimer() + (ms or 3000)
    while not VShop.Lock(src) do
        if GetGameTimer() > timeout then return false end
        Wait(100)
    end
    return true
end

-- ---------------------------------------------------------------------------
-- Money
-- ---------------------------------------------------------------------------

--- Takes `amount` from `first` (then the other of cash/bank when allowed).
--- Checks the balance itself: qb-core lets bank go negative.
--- Returns the money type it was taken from, or nil.
function VShop.TakeMoney(Player, amount, first, reason, allowOther)
    amount = math.floor(tonumber(amount) or 0)
    first = first == 'cash' and 'cash' or 'bank'
    if amount <= 0 then return first end
    local order = { first }
    if allowOther then order[2] = first == 'cash' and 'bank' or 'cash' end
    for _, mt in ipairs(order) do
        if (Player.PlayerData.money[mt] or 0) >= amount and Player.Functions.RemoveMoney(mt, amount, reason) then
            return mt
        end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Plates / owned vehicles
-- ---------------------------------------------------------------------------
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

--- Unique 8 character plate like "AB12CD34", checked against player_vehicles.
function VShop.GeneratePlate()
    for _ = 1, 25 do
        local plate = randomPlate()
        if not MySQL.scalar.await('SELECT 1 FROM player_vehicles WHERE plate = ? LIMIT 1', { plate }) then
            return plate
        end
    end
    return randomPlate()
end

--- Saves an owned vehicle. `finance` = { balance, payment, payments, time } or nil.
--- Returns true when the row was written.
function VShop.InsertOwned(Player, model, plate, garage, finance)
    local pd = Player.PlayerData
    local ok, id
    if finance then
        ok, id = pcall(MySQL.insert.await,
            'INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, garage, state, balance, paymentamount, paymentsleft, financetime) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
            { pd.license, pd.citizenid, model, joaat(model), '{}', plate, garage or 'pillboxgarage', 0,
                finance.balance, finance.payment, finance.payments, finance.time })
    else
        ok, id = pcall(MySQL.insert.await,
            'INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, garage, state) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
            { pd.license, pd.citizenid, model, joaat(model), '{}', plate, garage or 'pillboxgarage', 0 })
    end
    if not ok then print(('^1[qb-vehicleshop] could not save %s for %s: %s^0'):format(model, pd.citizenid, tostring(id))) end
    return ok and id ~= nil
end

-- ---------------------------------------------------------------------------
-- Spawning (server side)
-- ---------------------------------------------------------------------------
local categoryTypes = {
    motorcycles = 'bike', cycles = 'bike', boats = 'boat', helicopters = 'heli',
    planes = 'plane', submarines = 'submarine', trailer = 'trailer', train = 'train', trains = 'train',
}

--- Vehicle type for CreateVehicleServerSetter, or nil when unknown (then the
--- RPC CreateVehicle is used, which works out the type on the client).
function VShop.VehicleType(model, explicit)
    if type(explicit) == 'string' and explicit ~= '' then return explicit end
    local v = QBCore.Shared.Vehicles[model]
    if not v then return nil end
    return v.type or categoryTypes[v.category] or 'automobile'
end

--- Creates a networked vehicle and waits (max 5s) for it to exist.
--- Returns entity, netId — or nil.
function VShop.SpawnVehicle(model, coords, plate, vehType)
    local hash = joaat(model)
    local x, y, z, w = coords.x, coords.y, coords.z, coords.w or 0.0
    local veh
    if vehType then
        veh = CreateVehicleServerSetter(hash, vehType, x, y, z, w)
    else
        veh = CreateVehicle(hash, x, y, z, w, true, true)
    end
    local timeout = GetGameTimer() + 5000
    while not veh or veh == 0 or not DoesEntityExist(veh) do
        if GetGameTimer() > timeout then
            if veh and veh ~= 0 and DoesEntityExist(veh) then DeleteEntity(veh) end
            print(('^3[qb-vehicleshop] could not spawn "%s" — is the model streamed?^0'):format(model))
            return nil
        end
        Wait(50)
    end
    if plate then SetVehicleNumberPlateText(veh, plate) end
    return veh, NetworkGetNetworkIdFromEntity(veh)
end

--- Spawns the car and hands it to `src` (plate, fuel, keys, warp).
--- opts = { warp = bool, cfg = 'stock' | 'auction' | nil, type = 'automobile' ... }
function VShop.HandVehicle(src, model, coords, plate, opts)
    opts = opts or {}
    local veh, netId = VShop.SpawnVehicle(model, coords, plate, VShop.VehicleType(model, opts.type))
    if not veh then return nil end
    TriggerClientEvent('qb-vehicleshop:client:takeVehicle', src, netId, plate, { warp = opts.warp == true, cfg = opts.cfg })
    return veh
end

--- Saves the car to the player and spawns it at `spawn`.
--- opts = { garage, finance, warp, cfg, type, reason }
--- Returns the plate, or nil when nothing was saved (caller refunds).
function VShop.GiveVehicle(src, Player, model, spawn, opts)
    opts = opts or {}
    local plate = VShop.GeneratePlate()
    if not VShop.InsertOwned(Player, model, plate, opts.garage, opts.finance) then return nil end

    if not VShop.HandVehicle(src, model, spawn, plate, opts) then
        -- it is paid and saved, so park it instead of leaving it "out"
        MySQL.update('UPDATE player_vehicles SET state = 1 WHERE plate = ?', { plate })
        VShop.Notify(src, Lang:t('error.spawn_failed_garage', { plate = plate }), 'error', 9000)
    end

    TriggerEvent('qb-log:server:CreateLog', 'vehicleshop', opts.reason or 'Vehicle Purchase', 'green',
        ('**%s** (%s) got **%s** [%s]'):format(GetPlayerName(src) or '?', Player.PlayerData.citizenid, model, plate))
    return plate
end

-- ---------------------------------------------------------------------------
-- Test drives (stock showroom + old showroom share this)
-- ---------------------------------------------------------------------------
local testDrives = {} -- [src] = { token, veh }

function VShop.InTestDrive(src) return testDrives[src] ~= nil end

--- Ends a test drive: deletes the car the SERVER spawned for this player.
function VShop.EndTestDrive(src, tellClient)
    local td = testDrives[src]
    if not td then return end
    testDrives[src] = nil
    if td.veh and DoesEntityExist(td.veh) then DeleteEntity(td.veh) end
    if tellClient then TriggerClientEvent('qb-vehicleshop:client:testDriveStop', src) end
end

--- info = { label, leaveSeconds, returnCoords, cfg, kind, type }
--- Returns true when the car was spawned and handed over.
function VShop.StartTestDrive(src, model, spawn, seconds, info)
    if testDrives[src] then return false end
    local token = {}
    testDrives[src] = { token = token } -- reserved before the spawn wait

    local plate = ('TEST%04d'):format(math.random(0, 9999))
    local veh, netId = VShop.SpawnVehicle(model, spawn, plate, VShop.VehicleType(model, info.type))

    local td = testDrives[src]
    if not td or td.token ~= token then -- player left while it spawned
        if veh and DoesEntityExist(veh) then DeleteEntity(veh) end
        return false
    end
    if not veh then
        testDrives[src] = nil
        return false
    end
    td.veh = veh

    TriggerClientEvent('qb-vehicleshop:client:testDriveStart', src, netId, {
        plate = plate,
        seconds = seconds,
        label = info.label,
        leaveSeconds = info.leaveSeconds or 3,
        returnCoords = info.returnCoords,
        cfg = info.cfg,
        kind = info.kind,
    })

    -- backstop: the server ends it even if the client never reports back
    SetTimeout((seconds + 10) * 1000, function()
        local cur = testDrives[src]
        if cur and cur.token == token then VShop.EndTestDrive(src, true) end
    end)
    return true
end

RegisterNetEvent('qb-vehicleshop:server:testDriveEnd', function()
    VShop.EndTestDrive(source, false)
end)

AddEventHandler('playerDropped', function()
    local src = source
    VShop.EndTestDrive(src, false)
    cooldowns[src] = nil
    locks[src] = nil
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for src in pairs(testDrives) do VShop.EndTestDrive(src, false) end
end)
