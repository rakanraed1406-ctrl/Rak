-- Stretcher / wheelchair / trauma bag. The item leaves the inventory when it is
-- placed and only comes back when someone folds it up again (no duplicates), and
-- the server tracks who is lying / sitting on what.
local Placed = {}   -- [netId] = { kind, owner, item, info }
local Pending = {}  -- [token] = { src, kind, item, info }
local nextToken = 0

local KINDS = {
    stretcher = { cfg = Config.Stretcher, medicOnly = true, label = 'stretcher' },
    wheelchair = { cfg = Config.Wheelchair, medicOnly = false, label = 'wheelchair' },
    medbag = { cfg = Config.MedBag, medicOnly = true, label = 'trauma bag' },
}

local function Notify(src, msg, kind) TriggerClientEvent('QBCore:Notify', src, msg, kind or 'primary', 5000) end

local function EntityFromNet(netId)
    netId = tonumber(netId)
    if not netId then return 0 end
    local ent = NetworkGetEntityFromNetworkId(netId)
    return (ent and DoesEntityExist(ent)) and ent or 0
end

local function NearEntity(src, ent, dist)
    local ped = GetPlayerPed(src)
    if ped == 0 or ent == 0 then return false end
    return #(GetEntityCoords(ped) - GetEntityCoords(ent)) <= dist
end

local function CountPlaced(src)
    local n = 0
    for _, p in pairs(Placed) do if p.owner == src then n = n + 1 end end
    for _, p in pairs(Pending) do if p.src == src then n = n + 1 end end
    return n
end

local function GiveBack(src, item, info)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false end
    if Player.Functions.AddItem(item, 1, false, info) then
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[item], 'add')
        return true
    end
    return false
end

local function SetOccupant(ent, src)
    Entity(ent).state:set('emsOccupant', src, true)
end

local function Occupant(ent)
    return Entity(ent).state.emsOccupant
end

for kind, def in pairs(KINDS) do
    QBCore.Functions.CreateUseableItem(def.cfg.Item, function(source, item)
        local src = source
        local Player = QBCore.Functions.GetPlayer(src)
        if not Player then return end
        if def.medicOnly and not EMSServer.IsMedic(Player) then
            return Notify(src, 'Only on-duty paramedics can use the ' .. def.label, 'error')
        end
        local ped = GetPlayerPed(src)
        if ped == 0 or GetVehiclePedIsIn(ped, false) ~= 0 then return Notify(src, 'Get out of the vehicle first', 'error') end
        if CountPlaced(src) >= Config.MaxPlacedPerPlayer then
            return Notify(src, 'You already placed too much equipment — fold something up first', 'error')
        end
        local info = type(item.info) == 'table' and item.info or {}
        if kind == 'medbag' and not info.bagId then
            info.bagId = ('%s%d'):format(Player.PlayerData.citizenid, os.time() % 1000000)
        end
        if not Player.Functions.RemoveItem(def.cfg.Item, 1, item.slot) then return end
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[def.cfg.Item], 'remove')

        nextToken = nextToken + 1
        local token = nextToken
        Pending[token] = { src = src, kind = kind, item = def.cfg.Item, info = info }
        TriggerClientEvent('ems-tools:client:Place', src, kind, token)
        -- the client never confirmed (crash, model missing...): give the item back
        SetTimeout(20000, function()
            local p = Pending[token]
            if p then
                Pending[token] = nil
                GiveBack(p.src, p.item, p.info)
            end
        end)
    end)
end

RegisterNetEvent('ems-tools:server:PlaceFailed', function(token)
    local src = source
    local p = Pending[token]
    if not p or p.src ~= src then return end
    Pending[token] = nil
    GiveBack(src, p.item, p.info)
end)

RegisterNetEvent('ems-tools:server:Placed', function(token, netId)
    local src = source
    netId = tonumber(netId)
    if not netId then return end
    local p = Pending[token]
    if not p or p.src ~= src then return end
    Pending[token] = nil
    local ent = 0
    for _ = 1, 20 do
        ent = EntityFromNet(netId)
        if ent ~= 0 then break end
        Wait(100)
    end
    -- must be a NEW object of the right model (a client could send the netId of any
    -- entity — e.g. someone's car — and then "fold" it to delete it)
    local validModel = false
    if ent ~= 0 and GetEntityType(ent) == 3 then
        -- compare as unsigned 32-bit (server natives and joaat can differ in sign)
        local model = GetEntityModel(ent) % 4294967296
        for _, m in ipairs(KINDS[p.kind].cfg.Models or {}) do
            if GetHashKey(m) % 4294967296 == model then validModel = true break end
        end
    end
    if ent == 0 or not validModel or Placed[netId] or not NearEntity(src, ent, 6.0) then
        GiveBack(src, p.item, p.info)
        return
    end
    Placed[netId] = { kind = p.kind, owner = src, item = p.item, info = p.info }
    Entity(ent).state:set('emsTool', p.kind, true)
    SetOccupant(ent, nil)
    if p.kind == 'medbag' and GetResourceState('ox_inventory') == 'started' then
        pcall(function()
            exports.ox_inventory:RegisterStash('emsbag_' .. p.info.bagId, 'Trauma Bag', Config.MedBag.Slots, Config.MedBag.MaxWeight)
        end)
    end
end)

RegisterNetEvent('ems-tools:server:Pickup', function(netId)
    local src = source
    local p = Placed[netId]
    local ent = EntityFromNet(netId)
    if not p or ent == 0 then return end
    local Player = QBCore.Functions.GetPlayer(src)
    if KINDS[p.kind].medicOnly and not EMSServer.IsMedic(Player) then return end
    if not NearEntity(src, ent, 4.0) then return end
    if Occupant(ent) then return Notify(src, 'Someone is still on it', 'error') end
    Placed[netId] = nil
    DeleteEntity(ent)
    if not GiveBack(src, p.item, p.info) then
        Notify(src, 'Your pockets are full', 'error')
    end
end)

-- Medic puts a patient on the stretcher / in the wheelchair.
RegisterNetEvent('ems-tools:server:PutOn', function(netId, targetId)
    local src = source
    targetId = tonumber(targetId)
    local p = Placed[netId]
    local ent = EntityFromNet(netId)
    if not p or ent == 0 or (p.kind ~= 'stretcher' and p.kind ~= 'wheelchair') then return end
    if not EMSServer.IsMedic(QBCore.Functions.GetPlayer(src)) then return end
    local Target = targetId and QBCore.Functions.GetPlayer(targetId)
    if not Target or targetId == src then return end
    if Occupant(ent) then return Notify(src, 'It is already in use', 'error') end
    if not NearEntity(src, ent, 5.0) or not NearEntity(targetId, ent, 5.0) then return Notify(src, 'Bring it closer to the patient', 'error') end
    if p.kind == 'wheelchair' and Target.PlayerData.metadata.isdead then return Notify(src, 'Use a stretcher for this patient', 'error') end
    SetOccupant(ent, targetId)
    TriggerClientEvent('ems-tools:client:AttachTo', targetId, netId, p.kind)
    EMSServer.Log(src, targetId, p.kind == 'stretcher' and 'Placed on stretcher' or 'Placed in wheelchair')
end)

-- Anyone can sit in a free wheelchair.
RegisterNetEvent('ems-tools:server:Sit', function(netId)
    local src = source
    local p = Placed[netId]
    local ent = EntityFromNet(netId)
    if not p or ent == 0 or p.kind ~= 'wheelchair' or Occupant(ent) then return end
    if not NearEntity(src, ent, 3.0) then return end
    SetOccupant(ent, src)
    TriggerClientEvent('ems-tools:client:AttachTo', src, netId, p.kind)
end)

-- Medic takes the patient off, or the patient gets off by themselves.
RegisterNetEvent('ems-tools:server:TakeOff', function(netId)
    local src = source
    local ent = EntityFromNet(netId)
    if ent == 0 then return end
    local occ = Occupant(ent)
    if not occ then return end
    if occ ~= src then
        if not EMSServer.IsMedic(QBCore.Functions.GetPlayer(src)) or not NearEntity(src, ent, 5.0) then return end
    end
    SetOccupant(ent, nil)
    TriggerClientEvent('ems-tools:client:Detach', occ, netId)
end)

-- The patient's client lost the attachment (object deleted, teleport...).
RegisterNetEvent('ems-tools:server:Detached', function(netId)
    local ent = EntityFromNet(netId)
    if ent ~= 0 and Occupant(ent) == source then SetOccupant(ent, nil) end
end)

-- Trauma bag stash.
RegisterNetEvent('ems-tools:server:OpenBag', function(netId)
    local src = source
    local p = Placed[netId]
    local ent = EntityFromNet(netId)
    if not p or ent == 0 or p.kind ~= 'medbag' then return end
    if not EMSServer.IsMedic(QBCore.Functions.GetPlayer(src)) or not NearEntity(src, ent, 3.0) then return end
    local stash = 'emsbag_' .. p.info.bagId
    if GetResourceState('ox_inventory') == 'started' then
        TriggerClientEvent('ems-tools:client:OpenStash', src, stash, 'ox')
        return
    end
    -- qb-inventory v2 opens stashes from the server
    local ok = pcall(function()
        exports['qb-inventory']:OpenInventory(src, stash, { maxweight = Config.MedBag.MaxWeight, slots = Config.MedBag.Slots, label = 'Trauma Bag' })
    end)
    if not ok then TriggerClientEvent('ems-tools:client:OpenStash', src, stash, 'qb') end
end)

AddEventHandler('playerDropped', function()
    local src = source
    for netId, p in pairs(Placed) do
        local ent = EntityFromNet(netId)
        if ent ~= 0 and Occupant(ent) == src then SetOccupant(ent, nil) end
        if p.owner == src then p.owner = nil end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for netId in pairs(Placed) do
        local ent = EntityFromNet(netId)
        if ent ~= 0 then DeleteEntity(ent) end
    end
end)

-- Other clients need to know who is down (CPR option on qb-target).
local function SetDownState(src, value)
    local P = Player(src)
    if P and P.state then P.state:set('emsDown', value, true) end
end
RegisterNetEvent('hospital:server:SetLaststandStatus', function(bool)
    local src = source
    SetDownState(src, bool and 'laststand' or (Player(src).state.emsDown == 'dead' and 'dead' or nil))
end)
RegisterNetEvent('hospital:server:SetDeathStatus', function(isDead)
    local src = source
    if isDead then SetDownState(src, 'dead') elseif Player(src).state.emsDown == 'dead' then SetDownState(src, nil) end
end)
