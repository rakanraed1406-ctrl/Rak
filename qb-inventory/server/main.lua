local QBCore = exports['qb-core']:GetCoreObject()

-- Containers kept in memory while the server runs (globals so decay.lua can use them)
Drops = {}
Trunks = {}
Gloveboxes = {}
Stashes = {}
local ShopItems = {}
local OpenInventories = {}   -- [src] = { kind = 'stash' | 'trunk' | 'glovebox' | 'drop' | 'otherplayer' | 'itemshop' | 'crafting' | 'attachment_crafting' | 'traphouse', id = any }
local PendingCraft = {}      -- [src] = craft validated by the server, waiting for the client progress bar

--#region Helpers

local function Log(category, title, color, message)
    TriggerEvent('qb-log:server:CreateLog', category, title, color, message)
end

local function PlayerLabel(src)
    local Player = QBCore.Functions.GetPlayer(src)
    local cid = Player and Player.PlayerData.citizenid or '?'
    return ('**%s** (citizenid: %s | id: %s)'):format(GetPlayerName(src) or '?', cid, src)
end

local function ItemInfo(name)
    if type(name) ~= 'string' then return nil end
    return QBCore.Shared.Items[name:lower()]
end

---Builds a full item table (label, image, weight...) from the shared items list
local function BuildItem(itemInfo, amount, slot, info, created)
    return {
        name = itemInfo.name,
        amount = amount,
        info = info or '',
        label = itemInfo.label,
        description = itemInfo.description or '',
        weight = itemInfo.weight,
        type = itemInfo.type,
        unique = itemInfo.unique,
        useable = itemInfo.useable,
        image = itemInfo.image,
        shouldClose = itemInfo.shouldClose,
        slot = slot,
        combinable = itemInfo.combinable,
        created = created,
    }
end

---Positive whole number or nil
local function ToAmount(value)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge then return nil end
    value = math.floor(value)
    if value < 1 then return nil end
    return value
end

---Splits "stash-house-12" into "stash", "house-12" (only the first dash)
local function ParseInventory(name)
    if name == nil then return nil end
    if type(name) == 'number' then return 'drop', name end
    name = tostring(name)
    if name == 'player' or name == 'hotbar' then return 'player' end
    if tonumber(name) then return 'drop', tonumber(name) end
    local kind, id = name:match('^([^%-]+)%-(.+)$')
    if kind then return kind, id end
    return name
end

local function Distance(src, coords)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return math.huge end
    return #(GetEntityCoords(ped) - vector3(coords.x, coords.y, coords.z))
end

local function PlayersDistance(a, b)
    local pa, pb = GetPlayerPed(a), GetPlayerPed(b)
    if not pa or pa == 0 or not pb or pb == 0 then return math.huge end
    return #(GetEntityCoords(pa) - GetEntityCoords(pb))
end

local function Trim(text)
    return (tostring(text or ''):gsub('^%s+', ''):gsub('%s+$', ''))
end

--#endregion

--#region Player inventory

---Loads the inventory for the player with the citizenid that is provided
function LoadInventory(source, citizenid)
    local inventory = MySQL.prepare.await('SELECT inventory FROM players WHERE citizenid = ?', { citizenid })
    local loadedInventory = {}
    local missingItems = {}

    if not inventory then return loadedInventory end

    local ok, decoded = pcall(json.decode, inventory)
    if not ok or type(decoded) ~= 'table' then return loadedInventory end

    for _, item in pairs(decoded) do
        if type(item) == 'table' and item.name and item.slot then
            local itemInfo = ItemInfo(item.name)
            if itemInfo then
                loadedInventory[item.slot] = BuildItem(itemInfo, item.amount, item.slot, item.info, item.created)
            else
                missingItems[#missingItems + 1] = item.name:lower()
            end
        end
    end

    if #missingItems > 0 then
        print(('The following items were removed for player %s as they no longer exist'):format(GetPlayerName(source) or citizenid))
        QBCore.Debug(missingItems)
    end

    return loadedInventory
end

exports('LoadInventory', LoadInventory)

---Saves the inventory for the player (or the PlayerData table when offline)
function SaveInventory(source, offline)
    local PlayerData
    if not offline then
        local Player = QBCore.Functions.GetPlayer(source)
        if not Player then return end
        PlayerData = Player.PlayerData
    else
        PlayerData = source
    end

    local items = PlayerData.items
    local ItemsJson = {}
    if items and next(items) then
        for slot, item in pairs(items) do
            if item then
                ItemsJson[#ItemsJson + 1] = {
                    name = item.name,
                    amount = item.amount,
                    info = item.info,
                    type = item.type,
                    slot = slot,
                    created = item.created,
                }
            end
        end
        MySQL.prepare('UPDATE players SET inventory = ? WHERE citizenid = ?', { json.encode(ItemsJson), PlayerData.citizenid })
    else
        MySQL.prepare('UPDATE players SET inventory = ? WHERE citizenid = ?', { '[]', PlayerData.citizenid })
    end
end

exports('SaveInventory', SaveInventory)

local function GetTotalWeight(items)
    local weight = 0
    if not items then return 0 end
    for _, item in pairs(items) do
        weight = weight + (tonumber(item.weight) or 0) * (tonumber(item.amount) or 0)
    end
    return tonumber(weight)
end

exports('GetTotalWeight', GetTotalWeight)

local function GetSlotsByItem(items, itemName)
    local slotsFound = {}
    if not items or type(itemName) ~= 'string' then return slotsFound end
    itemName = itemName:lower()
    for slot, item in pairs(items) do
        if item.name:lower() == itemName then
            slotsFound[#slotsFound + 1] = slot
        end
    end
    table.sort(slotsFound)
    return slotsFound
end

exports('GetSlotsByItem', GetSlotsByItem)

local function GetFirstSlotByItem(items, itemName)
    local slots = GetSlotsByItem(items, itemName)
    return slots[1] and tonumber(slots[1]) or nil
end

exports('GetFirstSlotByItem', GetFirstSlotByItem)

local function FirstFreeSlot(items, maxSlots)
    for i = 1, maxSlots do
        if items[i] == nil then return i end
    end
    return nil
end

---Add an item to the inventory of the player
---@return boolean success
function AddItem(source, item, amount, slot, info, created)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end

    local itemInfo = ItemInfo(item)
    if not itemInfo then
        if not Player.Offline then QBCore.Functions.Notify(source, Lang:t('notify.idne'), 'error') end
        return false
    end

    amount = ToAmount(amount) or 1
    local items = Player.PlayerData.items
    info = type(info) == 'table' and info or {}
    created = tonumber(created) or os.time()

    -- Item specific defaults
    if itemInfo.name == 'lockpick' or itemInfo.name == 'breaker' then
        info.uses = info.uses or 10
    elseif itemInfo.name == 'hacking_device' then
        if not info.exp then
            info.exp = os.time() + 259200
            if QBCore.Functions.TimeFormate then info.explable = QBCore.Functions.TimeFormate(info.exp) end
        end
    elseif itemInfo.name == 'syphoningkit' then
        info.gasamount = info.gasamount or 0
    end
    if itemInfo.type == 'weapon' then
        info.serie = info.serie or tostring(QBCore.Shared.RandomInt(2) .. QBCore.Shared.RandomStr(3) .. QBCore.Shared.RandomInt(1) .. QBCore.Shared.RandomStr(2) .. QBCore.Shared.RandomInt(3) .. QBCore.Shared.RandomStr(4))
        info.quality = info.quality or 100
        amount = 1
    end

    if GetTotalWeight(items) + itemInfo.weight * amount > Config.MaxInventoryWeight then
        if not Player.Offline then QBCore.Functions.Notify(source, Lang:t('notify.invfull'), 'error') end
        return false
    end

    slot = tonumber(slot)
    if slot and (slot < 1 or slot > Config.MaxInventorySlots) then slot = nil end
    local stackable = itemInfo.type == 'item' and not itemInfo.unique

    local targetSlot
    if slot and items[slot] then
        if stackable and items[slot].name:lower() == itemInfo.name then
            targetSlot = slot
        end
    elseif slot then
        targetSlot = slot
    end
    if not targetSlot and stackable and not slot then
        targetSlot = GetFirstSlotByItem(items, itemInfo.name)
    end
    if not targetSlot then
        targetSlot = FirstFreeSlot(items, Config.MaxInventorySlots)
    end
    if not targetSlot then
        if not Player.Offline then QBCore.Functions.Notify(source, Lang:t('notify.invfull'), 'error') end
        return false
    end

    if items[targetSlot] then
        items[targetSlot].amount = items[targetSlot].amount + amount
    else
        items[targetSlot] = BuildItem(itemInfo, amount, targetSlot, info, created)
    end
    Player.Functions.SetPlayerData('items', items)

    if Player.Offline then return true end
    if itemInfo.name == 'phone' then TriggerClientEvent('lb-phone:itemAdded', source) end
    Log('playerinventory', 'AddItem', 'green', ('%s got item: [slot:%s], itemname: %s, added amount: %s, new total amount: %s'):format(PlayerLabel(source), targetSlot, itemInfo.name, amount, items[targetSlot].amount))
    return true
end

exports('AddItem', AddItem)

---Remove an item from the inventory of the player
---@return boolean success
local function RemoveItem(source, item, amount, slot)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player or type(item) ~= 'string' then return false end

    amount = ToAmount(amount) or 1
    slot = tonumber(slot)
    local items = Player.PlayerData.items
    local name = item:lower()
    local removed = false

    if slot and items[slot] and items[slot].name:lower() == name then
        if items[slot].amount > amount then
            items[slot].amount = items[slot].amount - amount
            removed = true
        elseif items[slot].amount == amount then
            items[slot] = nil
            removed = true
        end
    else
        -- No (valid) slot: take it from every slot that holds the item
        local slots = GetSlotsByItem(items, name)
        local total = 0
        for _, s in ipairs(slots) do total = total + items[s].amount end
        if total >= amount then
            local left = amount
            for _, s in ipairs(slots) do
                if left <= 0 then break end
                if items[s].amount > left then
                    items[s].amount = items[s].amount - left
                    left = 0
                else
                    left = left - items[s].amount
                    items[s] = nil
                end
            end
            removed = true
        end
    end

    if not removed then return false end
    Player.Functions.SetPlayerData('items', items)

    if Player.Offline then return true end
    if name == 'phone' and not GetFirstSlotByItem(items, 'phone') then TriggerClientEvent('lb-phone:itemRemoved', source) end
    Log('playerinventory', 'RemoveItem', 'red', ('%s lost item: %s, removed amount: %s'):format(PlayerLabel(source), name, amount))
    return true
end

exports('RemoveItem', RemoveItem)

-- Only removes from the caller's own inventory.
RegisterNetEvent('inventory:RemoveItem', function(itemName, amount, slot)
    RemoveItem(source, itemName, amount, slot)
end)

local function GetItemBySlot(source, slot)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return nil end
    return Player.PlayerData.items[tonumber(slot)]
end

exports('GetItemBySlot', GetItemBySlot)

local function GetItemByName(source, item)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return nil end
    local slot = GetFirstSlotByItem(Player.PlayerData.items, tostring(item):lower())
    return slot and Player.PlayerData.items[slot] or nil
end

exports('GetItemByName', GetItemByName)

local function GetItemsByName(source, item)
    local Player = QBCore.Functions.GetPlayer(source)
    local items = {}
    if not Player then return items end
    for _, slot in ipairs(GetSlotsByItem(Player.PlayerData.items, tostring(item):lower())) do
        items[#items + 1] = Player.PlayerData.items[slot]
    end
    return items
end

exports('GetItemsByName', GetItemsByName)

local function ClearInventory(source, filterItems)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    local savedItemData = {}

    if filterItems then
        local list = type(filterItems) == 'string' and { filterItems } or filterItems
        if type(list) == 'table' then
            for _, name in ipairs(list) do
                for _, item in ipairs(GetItemsByName(source, name)) do
                    savedItemData[item.slot] = item
                end
            end
        end
    end

    Player.Functions.SetPlayerData('items', savedItemData)
    if Player.Offline then return end
    Log('playerinventory', 'ClearInventory', 'red', PlayerLabel(source) .. ' inventory cleared')
end

exports('ClearInventory', ClearInventory)

function SetInventory(source, items)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    Player.Functions.SetPlayerData('items', items)
end

exports('SetInventory', SetInventory)

local function SetItemData(source, itemName, key, val)
    if not itemName or not key then return false end
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end
    local item = GetItemByName(source, itemName)
    if not item then return false end
    item[key] = val
    Player.PlayerData.items[item.slot] = item
    Player.Functions.SetPlayerData('items', Player.PlayerData.items)
    return true
end

exports('SetItemData', SetItemData)

---Total amount of an item across all slots
local function CountItem(source, name)
    local total = 0
    for _, item in ipairs(GetItemsByName(source, name)) do total = total + item.amount end
    return total
end

local function HasItem(source, items, amount)
    if not QBCore.Functions.GetPlayer(source) then return false end
    if type(items) == 'string' then
        return CountItem(source, items) >= (tonumber(amount) or 1)
    end
    if type(items) ~= 'table' then return false end

    local isArray = table.type(items) == 'array'
    for k, v in pairs(items) do
        local name = isArray and v or k
        local need = isArray and (tonumber(amount) or 1) or (tonumber(amount) or tonumber(v) or 1)
        if CountItem(source, name) < need then return false end
    end
    return true
end

exports('HasItem', HasItem)

local function CreateUsableItem(itemName, data)
    QBCore.Functions.CreateUseableItem(itemName, data)
end

exports('CreateUsableItem', CreateUsableItem)

local function GetUsableItem(itemName)
    return QBCore.Functions.CanUseItem(itemName)
end

exports('GetUsableItem', GetUsableItem)

local function UseItem(itemName, ...)
    local itemData = GetUsableItem(itemName)
    local callback = type(itemData) == 'table' and (rawget(itemData, '__cfx_functionReference') and itemData or itemData.cb or itemData.callback) or type(itemData) == 'function' and itemData
    if not callback then return end
    callback(...)
end

exports('UseItem', UseItem)

--#endregion

--#region Containers (stash / trunk / glovebox / drop)

local BlockedFromSave = { ['Stash-None'] = true, ['Stash-Trash'] = true }

local function DecodeStoredItems(result)
    local items = {}
    if not result then return items end
    local ok, stored = pcall(json.decode, result)
    if not ok or type(stored) ~= 'table' then return items end
    for _, item in pairs(stored) do
        local itemInfo = type(item) == 'table' and ItemInfo(item.name)
        if itemInfo and item.slot then
            items[item.slot] = BuildItem(itemInfo, tonumber(item.amount) or 1, item.slot, item.info, item.created)
        end
    end
    return items
end

local function EncodeForSave(items)
    local list = {}
    for slot, item in pairs(items or {}) do
        list[#list + 1] = { name = item.name, amount = item.amount, info = item.info, type = item.type, slot = slot, created = item.created }
    end
    return json.encode(list)
end

local function StashTable(stashId)
    if stashId:find('Backpack_', 1, true) then return 'otherstashitems' end
    if stashId:find('Evidence_Box', 1, true) then return 'evidencebox' end
    return 'stashitems'
end

function GetStashItems(stashId)
    stashId = tostring(stashId)
    return DecodeStoredItems(MySQL.scalar.await(('SELECT items FROM %s WHERE stash = ?'):format(StashTable(stashId)), { stashId }))
end

---Writes a stash to the database (does not change who has it open)
function SaveStashItems(stashId, items)
    stashId = tostring(stashId)
    local label = Stashes[stashId] and Stashes[stashId].label or ('Stash-' .. stashId)
    if not items or BlockedFromSave[label] or BlockedFromSave[label:sub(1, 11)] then return end
    MySQL.insert(('INSERT INTO %s (stash, items) VALUES (:stash, :items) ON DUPLICATE KEY UPDATE items = :items'):format(StashTable(stashId)), {
        stash = stashId,
        items = EncodeForSave(items),
    })
end

function GetOwnedVehicleItems(plate)
    return DecodeStoredItems(MySQL.scalar.await('SELECT items FROM trunkitems WHERE plate = ?', { plate }))
end

function SaveOwnedVehicleItems(plate, items)
    if not items then return end
    MySQL.insert('INSERT INTO trunkitems (plate, items) VALUES (:plate, :items) ON DUPLICATE KEY UPDATE items = :items', {
        plate = plate,
        items = EncodeForSave(items),
    })
end

function GetOwnedVehicleGloveboxItems(plate)
    return DecodeStoredItems(MySQL.scalar.await('SELECT items FROM gloveboxitems WHERE plate = ?', { plate }))
end

function SaveOwnedGloveboxItems(plate, items)
    if not items then return end
    MySQL.insert('INSERT INTO gloveboxitems (plate, items) VALUES (:plate, :items) ON DUPLICATE KEY UPDATE items = :items', {
        plate = plate,
        items = EncodeForSave(items),
    })
end

local OwnedCache = {}
local function IsVehicleOwned(plate)
    local cached = OwnedCache[plate]
    if cached and os.time() - cached.time < 300 then return cached.owned end
    local owned = MySQL.scalar.await('SELECT 1 FROM player_vehicles WHERE plate = ?', { plate }) ~= nil
    OwnedCache[plate] = { owned = owned, time = os.time() }
    return owned
end

local function StoreWeight(store)
    return GetTotalWeight(store.items)
end

---Adds to a container's item table. Returns true when it fits.
local function AddToStore(store, slot, itemName, amount, info, created)
    local itemInfo = ItemInfo(itemName)
    if not itemInfo then return false end
    slot = tonumber(slot)
    local current = slot and store.items[slot]
    if current and current.name == itemInfo.name and not itemInfo.unique and itemInfo.type == 'item' then
        current.amount = current.amount + amount
        return true
    end
    if not slot or slot < 1 or slot > store.slots or current then
        slot = FirstFreeSlot(store.items, store.slots)
        if not slot then return false end
    end
    store.items[slot] = BuildItem(itemInfo, amount, slot, info, created)
    if store.isDrop then store.items[slot].id = store.id end
    return true
end

local function RemoveFromStore(store, slot, itemName, amount)
    local current = store.items[tonumber(slot)]
    if not current or current.name ~= itemName or current.amount < amount then return false end
    if current.amount > amount then
        current.amount = current.amount - amount
    else
        store.items[tonumber(slot)] = nil
    end
    return true
end

-- Kept for other resources/scripts that use them
function AddToGlovebox(plate, slot, otherslot, itemName, amount, info, created)
    if Gloveboxes[plate] then AddToStore(Gloveboxes[plate], slot, itemName, tonumber(amount) or 1, info, created) end
end

function RemoveFromTrunk(plate, slot, itemName, amount)
    if Trunks[plate] then RemoveFromStore(Trunks[plate], slot, itemName, tonumber(amount) or 1) end
end

local function SaveContainer(kind, id)
    if kind == 'stash' and Stashes[id] then
        SaveStashItems(id, Stashes[id].items)
    elseif kind == 'trunk' and Trunks[id] and IsVehicleOwned(id) then
        SaveOwnedVehicleItems(id, Trunks[id].items)
    elseif kind == 'glovebox' and Gloveboxes[id] and IsVehicleOwned(id) then
        SaveOwnedGloveboxItems(id, Gloveboxes[id].items)
    end
end

---Saves and unlocks whatever the player had open
local function ReleaseInventory(src)
    local open = OpenInventories[src]
    if not open then return end
    OpenInventories[src] = nil

    local stores = { stash = Stashes, trunk = Trunks, glovebox = Gloveboxes, drop = Drops }
    local store = stores[open.kind] and stores[open.kind][open.id]
    if store and store.isOpen == src then
        SaveContainer(open.kind, open.id)
        store.isOpen = false
        if open.kind == 'drop' and not next(store.items) then
            Drops[open.id] = nil
            TriggerClientEvent('inventory:client:RemoveDropItem', -1, open.id)
        end
    end
end

--#endregion

--#region Drops

local function CreateDropId()
    local id = math.random(10000, 99999)
    while Drops[id] do id = math.random(10000, 99999) end
    return id
end

local function DropCoordsFor(src)
    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    local heading = math.rad(GetEntityHeading(ped))
    return vector3(coords.x - math.sin(heading) * 0.6, coords.y + math.cos(heading) * 0.6, coords.z - 0.95)
end

local function NewDrop(src)
    local id = CreateDropId()
    Drops[id] = {
        id = id,
        isDrop = true,
        coords = DropCoordsFor(src),
        items = {},
        slots = Config.DropSlots,
        maxweight = Config.DropMaxWeight,
        createdTime = os.time(),
        label = 'Dropped-' .. id,
        isOpen = src,
    }
    return id
end

CreateThread(function()
    while true do
        Wait(60000)
        local now = os.time()
        for id, drop in pairs(Drops) do
            if not drop.isOpen and (now - drop.createdTime > Config.CleanupDropTime or not next(drop.items)) then
                Drops[id] = nil
                TriggerClientEvent('inventory:client:RemoveDropItem', -1, id)
            end
        end
    end
end)

--#endregion

--#region Player methods

local function AddPlayerMethods(src)
    QBCore.Functions.AddPlayerMethod(src, 'AddItem', function(item, amount, slot, info) return AddItem(src, item, amount, slot, info) end)
    QBCore.Functions.AddPlayerMethod(src, 'RemoveItem', function(item, amount, slot) return RemoveItem(src, item, amount, slot) end)
    QBCore.Functions.AddPlayerMethod(src, 'GetItemBySlot', function(slot) return GetItemBySlot(src, slot) end)
    QBCore.Functions.AddPlayerMethod(src, 'GetItemByName', function(item) return GetItemByName(src, item) end)
    QBCore.Functions.AddPlayerMethod(src, 'GetItemsByName', function(item) return GetItemsByName(src, item) end)
    QBCore.Functions.AddPlayerMethod(src, 'ClearInventory', function(filterItems) ClearInventory(src, filterItems) end)
    QBCore.Functions.AddPlayerMethod(src, 'SetInventory', function(items) SetInventory(src, items) end)
end

AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    AddPlayerMethods(Player.PlayerData.source)
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for src in pairs(QBCore.Functions.GetQBPlayers()) do
        AddPlayerMethods(src)
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    ReleaseInventory(src)
    PendingCraft[src] = nil
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for src in pairs(OpenInventories) do ReleaseInventory(src) end
end)

RegisterNetEvent('QBCore:Server:UpdateObject', function()
    if source ~= '' then return end
    QBCore = exports['qb-core']:GetCoreObject()
end)

--#endregion

--#region Opening

local function TrunkSize(class)
    return Config.TrunkSizes[tonumber(class)] or Config.TrunkSizes.default
end

---Finds a spawned vehicle by plate (needs OneSync). Returns entity or nil.
local function FindVehicleByPlate(plate)
    for _, vehicle in ipairs(GetAllVehicles()) do
        if Trim(GetVehicleNumberPlateText(vehicle)) == plate then return vehicle end
    end
    return nil
end

local function SendOpen(src, Player, secondInv)
    if ApplyDecay then
        ApplyDecay(Player.PlayerData.items)
        if secondInv and secondInv.inventory then ApplyDecay(secondInv.inventory) end
    end
    TriggerClientEvent('inventory:client:OpenInventory', src, {}, Player.PlayerData.items, secondInv)
end

local function OpenStore(src, stores, id, label, loader, size)
    local store = stores[id]
    if store and store.isOpen and store.isOpen ~= src then
        if QBCore.Functions.GetPlayer(store.isOpen) and OpenInventories[store.isOpen] and OpenInventories[store.isOpen].id == id then
            TriggerClientEvent('inventory:client:CheckOpenState', store.isOpen, label:match('^(%a+)'):lower(), id, store.label)
            return nil
        end
        store.isOpen = false
    end
    if not store then
        store = { items = loader and loader(id) or {} }
        stores[id] = store
    end
    store.id = id
    store.label = label
    store.slots = size.slots
    store.maxweight = size.maxweight
    store.isOpen = src
    return store
end

local function NoneInventory(label)
    return { name = 'none-inv', label = label, maxweight = 0, inventory = {}, slots = 0 }
end

RegisterNetEvent('inventory:server:OpenInventory', function(name, id, other)
    local src = source
    local busy = Player(src).state.inv_busy
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    if busy then
        return QBCore.Functions.Notify(src, Lang:t('notify.busy'), 'error')
    end

    ReleaseInventory(src)
    other = type(other) == 'table' and other or {}

    if not name or id == nil then
        return SendOpen(src, Player, nil)
    end

    local secondInv
    if name == 'stash' then
        id = tostring(id)
        local size = {
            slots = math.max(1, math.min(tonumber(other.slots) or 50, Config.MaxStashSlots)),
            maxweight = math.max(0, math.min(tonumber(other.maxweight) or 1000000, Config.MaxStashWeight)),
        }
        local store = OpenStore(src, Stashes, id, 'Stash-' .. id, GetStashItems, size)
        if store then
            secondInv = { name = 'stash-' .. id, label = store.label, maxweight = store.maxweight, slots = store.slots, inventory = store.items }
            OpenInventories[src] = { kind = 'stash', id = id }
        else
            secondInv = NoneInventory('Stash-None')
        end
    elseif name == 'trunk' then
        id = Trim(id)
        local isPolice = id:find('POL', 1, true) ~= nil
        local vehicle = FindVehicleByPlate(id)
        local allowed = true
        if vehicle then
            allowed = #(GetEntityCoords(vehicle) - GetEntityCoords(GetPlayerPed(src))) <= Config.TrunkDistance
        elseif IsVehicleOwned(id) then
            allowed = false -- owned vehicle that is not out in the world
        end
        if isPolice and not Config.PoliceJobs[Player.PlayerData.job.name] then allowed = false end

        local store = allowed and OpenStore(src, Trunks, id, 'Trunk-' .. id, function(plate)
            return IsVehicleOwned(plate) and GetOwnedVehicleItems(plate) or {}
        end, TrunkSize(other.class))
        if store then
            secondInv = { name = 'trunk-' .. id, label = store.label, maxweight = store.maxweight, slots = store.slots, inventory = store.items }
            OpenInventories[src] = { kind = 'trunk', id = id }
        else
            if not allowed then QBCore.Functions.Notify(src, Lang:t('notify.toofar'), 'error') end
            secondInv = NoneInventory('Trunk-None')
        end
    elseif name == 'glovebox' then
        id = Trim(id)
        local vehicle = GetVehiclePedIsIn(GetPlayerPed(src), false)
        local allowed = vehicle ~= 0 and Trim(GetVehicleNumberPlateText(vehicle)) == id
        local store = allowed and OpenStore(src, Gloveboxes, id, 'Glovebox-' .. id, function(plate)
            return IsVehicleOwned(plate) and GetOwnedVehicleGloveboxItems(plate) or {}
        end, Config.GloveboxSize)
        if store then
            secondInv = { name = 'glovebox-' .. id, label = store.label, maxweight = store.maxweight, slots = store.slots, inventory = store.items }
            OpenInventories[src] = { kind = 'glovebox', id = id }
        else
            secondInv = NoneInventory('Glovebox-None')
        end
    elseif name == 'shop' then
        if type(other.items) ~= 'table' then return SendOpen(src, Player, nil) end
        id = tostring(id)
        local items = {}
        for _, item in pairs(other.items) do
            local price = tonumber(item.price)
            if type(item) == 'table' and ItemInfo(item.name) and price and price >= 0 and tonumber(item.slot) then
                items[#items + 1] = item
            end
        end
        if id:find('^Vendingshop') then items = ValidVendingItems(items) end
        ShopItems[id] = { items = {} }
        local display, maxSlot = {}, 0
        for _, item in ipairs(items) do
            local itemInfo = ItemInfo(item.name)
            local slot = math.floor(tonumber(item.slot))
            ShopItems[id].items[slot] = item
            display[slot] = BuildItem(itemInfo, tonumber(item.amount) or 1, slot, item.info or '', nil)
            display[slot].price = tonumber(item.price)
            maxSlot = math.max(maxSlot, slot)
        end
        secondInv = { name = 'itemshop-' .. id, label = other.label or Lang:t('ui.shop'), maxweight = 900000, inventory = display, slots = maxSlot }
        OpenInventories[src] = { kind = 'itemshop', id = id }
    elseif name == 'traphouse' then
        secondInv = { name = 'traphouse-' .. id, label = other.label, maxweight = 900000, inventory = other.items or {}, slots = tonumber(other.slots) or 0 }
        OpenInventories[src] = { kind = 'traphouse', id = tostring(id) }
    elseif name == 'crafting' or name == 'attachment_crafting' then
        local list = name == 'crafting' and Config.CraftingItems or Config.AttachmentCrafting.items
        local rep = name == 'crafting' and 'craftingrep' or 'attachmentcraftingrep'
        local myRep = tonumber(Player.PlayerData.metadata[rep]) or 0
        local display, count = {}, 0
        for _, recipe in pairs(list) do
            local itemInfo = ItemInfo(recipe.name)
            if itemInfo and myRep >= (recipe.threshold or 0) then
                local costs = {}
                for costName, costAmount in pairs(recipe.costs) do
                    local costInfo = ItemInfo(costName)
                    costs[#costs + 1] = (costInfo and costInfo.label or costName) .. ': ' .. costAmount .. 'x'
                end
                display[recipe.slot] = BuildItem(itemInfo, tonumber(recipe.amount) or 1, recipe.slot, { costs = table.concat(costs, ', ') }, nil)
                count = math.max(count, recipe.slot)
            end
        end
        secondInv = { name = name, label = other.label or Lang:t('label.craft'), maxweight = 900000, inventory = display, slots = count }
        OpenInventories[src] = { kind = name, id = name }
    elseif name == 'otherplayer' then
        local targetId = tonumber(id)
        local OtherPlayer = targetId and QBCore.Functions.GetPlayer(targetId)
        if not OtherPlayer or targetId == src then return SendOpen(src, Player, nil) end
        if PlayersDistance(src, targetId) > Config.RobDistance then
            QBCore.Functions.Notify(src, Lang:t('notify.toofar'), 'error')
            return SendOpen(src, Player, nil)
        end
        local slots = Config.MaxInventorySlots - 1
        if Config.PoliceJobs[Player.PlayerData.job.name] and Player.PlayerData.job.onduty and Distance(src, Config.PoliceSearchLocation) < 20 then
            slots = Config.MaxInventorySlots
        end
        secondInv = { name = 'otherplayer-' .. targetId, label = 'Player-' .. targetId, maxweight = Config.MaxInventoryWeight, inventory = OtherPlayer.PlayerData.items, slots = slots }
        OpenInventories[src] = { kind = 'otherplayer', id = targetId }
        TriggerClientEvent('qb-inventory:client:closeinv', targetId)
    else -- drop
        local dropId = tonumber(id)
        local drop = dropId and Drops[dropId]
        if not Config.EnableDrops or not drop or Distance(src, drop.coords) > 3.0 then
            return SendOpen(src, Player, nil)
        end
        if drop.isOpen and drop.isOpen ~= src and QBCore.Functions.GetPlayer(drop.isOpen) then
            secondInv = NoneInventory('Dropped-None')
        else
            drop.isOpen = src
            drop.createdTime = os.time()
            secondInv = { name = dropId, label = drop.label, maxweight = drop.maxweight, inventory = drop.items, slots = drop.slots, coords = drop.coords }
            OpenInventories[src] = { kind = 'drop', id = dropId }
        end
    end

    SendOpen(src, Player, secondInv)
end)

RegisterNetEvent('inventory:server:SaveInventory', function()
    ReleaseInventory(source)
end)

-- Answer to CheckOpenState: the player confirms they no longer use the container.
RegisterNetEvent('inventory:server:SetIsOpenState', function(IsOpen, type, id)
    if IsOpen then return end
    local src = source
    local stores = { stash = Stashes, trunk = Trunks, glovebox = Gloveboxes, drop = Drops }
    local store = stores[type] and stores[type][id]
    if store and store.isOpen == src then
        if OpenInventories[src] and OpenInventories[src].id == id then
            ReleaseInventory(src)
        else
            store.isOpen = false
        end
    end
end)

--#endregion

--#region Moving items

---Returns a container for a move, or nil when the player may not touch it.
local function GetContainer(src, invName)
    local kind, id = ParseInventory(invName)
    if kind == 'player' then
        return { kind = 'player', src = src }
    end

    local open = OpenInventories[src]
    if kind == 'drop' then
        if not Config.EnableDrops then return nil end
        if open and open.kind ~= 'drop' then return nil end -- another container is open
        if id == 0 or not Drops[id] then
            -- Ground with no drop yet: a new drop is created on the first item
            if open and open.kind == 'drop' and Drops[open.id] then
                return { kind = 'drop', id = open.id, store = Drops[open.id] }
            end
            return { kind = 'newdrop' }
        end
        if not open or open.kind ~= 'drop' or open.id ~= id or Drops[id].isOpen ~= src then return nil end
        if Distance(src, Drops[id].coords) > 4.0 then return nil end
        return { kind = 'drop', id = id, store = Drops[id] }
    end

    if not open or open.kind ~= kind then return nil end
    if kind == 'crafting' or kind == 'attachment_crafting' then return { kind = kind, id = open.id } end

    if kind == 'otherplayer' then
        local targetId = tonumber(id)
        if open.id ~= targetId or not QBCore.Functions.GetPlayer(targetId) then return nil end
        if PlayersDistance(src, targetId) > Config.RobDistance + 1.0 then return nil end
        return { kind = 'otherplayer', src = targetId }
    end

    if tostring(open.id) ~= tostring(id) then return nil end
    local stores = { stash = Stashes, trunk = Trunks, glovebox = Gloveboxes }
    if stores[kind] then
        local store = stores[kind][open.id]
        if not store or store.isOpen ~= src then return nil end
        return { kind = kind, id = open.id, store = store }
    end
    if kind == 'traphouse' then return { kind = 'traphouse', id = open.id } end
    return { kind = kind, id = open.id }
end

local function CGet(c, slot)
    if c.kind == 'player' or c.kind == 'otherplayer' then return GetItemBySlot(c.src, slot) end
    if c.store then return c.store.items[slot] end
    if c.kind == 'traphouse' then return exports['qb-traphouse']:GetInventoryData(c.id, slot) end
end

local function CSlots(c)
    if c.kind == 'player' or c.kind == 'otherplayer' then return Config.MaxInventorySlots end
    if c.store then return c.store.slots end
    return 9999
end

local function CFreeWeight(c)
    if c.kind == 'player' or c.kind == 'otherplayer' then
        local P = QBCore.Functions.GetPlayer(c.src)
        return Config.MaxInventoryWeight - GetTotalWeight(P and P.PlayerData.items)
    end
    if c.store then return c.store.maxweight - StoreWeight(c.store) end
    return math.huge
end

local function CRemove(c, slot, name, amount)
    if c.kind == 'player' or c.kind == 'otherplayer' then return RemoveItem(c.src, name, amount, slot) end
    if c.store then return RemoveFromStore(c.store, slot, name, amount) end
    if c.kind == 'traphouse' then
        exports['qb-traphouse']:RemoveHouseItem(c.id, slot, name, amount)
        return true
    end
    return false
end

local function CAdd(c, src, slot, item, amount)
    if c.kind == 'player' or c.kind == 'otherplayer' then
        return AddItem(c.src, item.name, amount, slot, item.info, item.created)
    end
    if c.store then return AddToStore(c.store, slot, item.name, amount, item.info, item.created) end
    if c.kind == 'traphouse' then
        exports['qb-traphouse']:AddHouseItem(c.id, slot, item.name, amount, item.info, src)
        return true
    end
    return false
end

local function ContainerItems(c)
    if c.kind == 'otherplayer' then
        local P = QBCore.Functions.GetPlayer(c.src)
        return P and P.PlayerData.items or {}
    end
    if c.store then return c.store.items end
    return nil
end

local function ContainerName(c)
    if c.kind == 'drop' then return c.id end
    if c.kind == 'otherplayer' then return 'otherplayer-' .. c.src end
    return c.kind .. '-' .. tostring(c.id)
end

local function AfterLeavingPlayer(src, itemName)
    TriggerClientEvent('inventory:client:CheckWeapon', src, itemName)
    if itemName == 'radio' and not GetItemByName(src, 'radio') then
        TriggerClientEvent('Radio.Set', src, false)
    end
end

---Sends the true state back so the UI can never drift from the server
local function Refresh(src, other)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local otherName, otherItems
    if other and other.kind ~= 'player' then
        otherItems = ContainerItems(other)
        if otherItems then otherName = ContainerName(other) end
    end
    TriggerClientEvent('inventory:client:refresh', src, Player.PlayerData.items, otherName, otherItems)
end

local function BuyFromShop(src, Player, shopId, fromSlot, toSlot, amount)
    local shop = ShopItems[shopId]
    local itemData = shop and shop.items[fromSlot]
    local itemInfo = itemData and ItemInfo(itemData.name)
    if not itemInfo then return end

    if itemInfo.unique or itemInfo.type == 'weapon' then amount = 1 end
    if tonumber(itemData.amount) and amount > tonumber(itemData.amount) then amount = tonumber(itemData.amount) end
    if amount < 1 then return end
    if itemInfo.weight * amount > Config.MaxInventoryWeight - GetTotalWeight(Player.PlayerData.items) then
        return QBCore.Functions.Notify(src, Lang:t('notify.tooheavy'), 'error')
    end

    local price = tonumber(itemData.price) * amount
    local info = type(itemData.info) == 'table' and json.decode(json.encode(itemData.info)) or {}
    if itemInfo.type == 'weapon' then
        info.serie = tostring(QBCore.Shared.RandomInt(2) .. QBCore.Shared.RandomStr(3) .. QBCore.Shared.RandomInt(1) .. QBCore.Shared.RandomStr(2) .. QBCore.Shared.RandomInt(3) .. QBCore.Shared.RandomStr(4))
        info.quality = 100
    end
    local shopType = shopId:match('^([^_]+)') or shopId
    local bought = Lang:t('notify.bought')

    local function Pay(allowBank, reason)
        if Player.Functions.RemoveMoney('cash', price, reason) then return true end
        if allowBank and Player.PlayerData.money.bank >= price then
            return Player.Functions.RemoveMoney('bank', price, reason)
        end
        return false
    end

    if shopType == 'Dealer' then
        if Pay(false, 'dealer-item-bought') then
            AddItem(src, itemData.name, amount, toSlot, info)
            TriggerClientEvent('qb-drugs:client:updateDealerItems', src, itemData, amount)
            QBCore.Functions.Notify(src, itemInfo.label .. bought, 'success')
        else
            QBCore.Functions.Notify(src, Lang:t('notify.notencash'), 'error')
        end
    elseif shopType == 'toolsfactory' then
        QBCore.Functions.TriggerCallback('qb-toolsfactory:server:toolsfactoryinvecanbuy', src, function(CanBuy)
            if not CanBuy then return end
            if Pay(false, 'toolsfactory-bought-item') then
                AddItem(src, itemData.name, amount, toSlot, info)
                TriggerEvent('qb-toolsfactory:server:UpdateShopItems', itemData, amount)
                QBCore.Functions.Notify(src, itemInfo.label .. bought, 'success')
                Refresh(src, nil)
            else
                QBCore.Functions.Notify(src, Lang:t('notify.notencash'), 'error')
            end
        end, itemData, amount)
    elseif shopType == 'Pawnshop' then
        if Pay(false, 'pawnshop-bought-item') then
            AddItem(src, itemData.name, amount, toSlot, info)
            TriggerEvent('prx:pawnshop:update:sql', itemData, amount, itemData.id)
            QBCore.Functions.Notify(src, itemInfo.label .. bought, 'success')
        else
            QBCore.Functions.Notify(src, Lang:t('notify.notencash'), 'error')
        end
    else
        if Pay(true, 'itemshop-bought-item') then
            AddItem(src, itemData.name, amount, toSlot, info)
            if shopType == 'Itemshop' then
                TriggerClientEvent('qb-shops:client:UpdateShop', src, shopId:match('^[^_]+_(.+)$'), itemData, amount)
            end
            QBCore.Functions.Notify(src, itemInfo.label .. bought, 'success')
        else
            QBCore.Functions.Notify(src, Lang:t('notify.notencash'), 'error')
        end
    end
    Log('shops', 'Shop item bought', 'green', ('%s bought %sx %s for $%s'):format(PlayerLabel(src), amount, itemData.name, price))
end

local function StartCraft(src, Player, kind, fromSlot, toSlot, amount)
    local list = kind == 'crafting' and Config.CraftingItems or Config.AttachmentCrafting.items
    local rep = kind == 'crafting' and 'craftingrep' or 'attachmentcraftingrep'
    local recipe
    for _, r in pairs(list) do
        if r.slot == fromSlot then recipe = r break end
    end
    if not recipe or (tonumber(Player.PlayerData.metadata[rep]) or 0) < (recipe.threshold or 0) then return end
    for name, cost in pairs(recipe.costs) do
        if CountItem(src, name) < cost * amount then
            return QBCore.Functions.Notify(src, Lang:t('notify.noitem'), 'error')
        end
    end
    PendingCraft[src] = { kind = kind, name = recipe.name, costs = recipe.costs, amount = amount, toSlot = toSlot, points = recipe.points or 0, rep = rep, time = os.time() }
    local event = kind == 'crafting' and 'inventory:client:CraftItems' or 'inventory:client:CraftAttachment'
    TriggerClientEvent(event, src, recipe.name, recipe.costs, amount, toSlot, recipe.points)
end

RegisterNetEvent('inventory:server:SetInventoryData', function(fromInventory, toInventory, fromSlot, toSlot, fromAmount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    fromSlot, toSlot = tonumber(fromSlot), tonumber(toSlot)
    if not fromSlot or not toSlot or fromSlot < 1 or toSlot < 1 then return end
    fromSlot, toSlot = math.floor(fromSlot), math.floor(toSlot)

    local fromKind = ParseInventory(fromInventory)
    local toKind = ParseInventory(toInventory)

    -- Buying / crafting only go into the player's own inventory
    if fromKind == 'itemshop' or fromKind == 'crafting' or fromKind == 'attachment_crafting' then
        local from = GetContainer(src, fromInventory)
        local amount = ToAmount(fromAmount) or 1
        if from and toKind == 'player' then
            if fromKind == 'itemshop' then
                BuyFromShop(src, Player, from.id, fromSlot, toSlot, amount)
            else
                StartCraft(src, Player, fromKind, fromSlot, toSlot, amount)
            end
        end
        return Refresh(src, nil)
    end
    if toKind == 'itemshop' or toKind == 'crafting' or toKind == 'attachment_crafting' then
        return Refresh(src, GetContainer(src, fromInventory))
    end

    local from = GetContainer(src, fromInventory)
    local to = GetContainer(src, toInventory)
    if not from or not to or from.kind == 'newdrop' then return Refresh(src, from or to) end

    local fromItem = CGet(from, fromSlot)
    if not fromItem then return Refresh(src, from.kind ~= 'player' and from or to) end
    local amount = ToAmount(fromAmount) or fromItem.amount
    if amount > fromItem.amount then amount = fromItem.amount end
    local fromName = fromItem.name
    local moving = { name = fromName, info = fromItem.info, created = fromItem.created }

    -- Dropping on the ground with no bag there yet
    if to.kind == 'newdrop' then
        if from.kind ~= 'player' then return Refresh(src, from) end
        if not RemoveItem(src, fromName, amount, fromSlot) then return Refresh(src, nil) end
        local dropId = NewDrop(src)
        AddToStore(Drops[dropId], toSlot, fromName, amount, moving.info, moving.created)
        OpenInventories[src] = { kind = 'drop', id = dropId }
        AfterLeavingPlayer(src, fromName)
        TriggerClientEvent('inventory:client:AddDropItem', -1, dropId, src, Drops[dropId].coords)
        TriggerClientEvent('inventory:client:DropItemAnim', src)
        Log('drop', 'New Item Drop', 'red', ('%s dropped new item; name: %s, amount: %s'):format(PlayerLabel(src), fromName, amount))
        return Refresh(src, { kind = 'drop', id = dropId, store = Drops[dropId] })
    end

    if toSlot > CSlots(to) then return Refresh(src, to.kind ~= 'player' and to or from) end
    local sameContainer = from.kind == to.kind and (from.src or from.id) == (to.src or to.id)
    if sameContainer and fromSlot == toSlot then return Refresh(src, from) end

    local toItem = CGet(to, toSlot)
    local itemInfo = ItemInfo(fromName)
    local stacking = toItem and toItem.name == fromName and itemInfo and itemInfo.type == 'item' and not itemInfo.unique
    local swapping = toItem and not stacking
    if swapping and amount < fromItem.amount then
        return Refresh(src, from.kind ~= 'player' and from or to) -- a part of a stack can't be swapped with another item
    end

    -- Weight check before anything changes
    if not sameContainer and itemInfo then
        local toGets = itemInfo.weight * amount - (swapping and toItem.weight * toItem.amount or 0)
        local fromGets = swapping and (toItem.weight * toItem.amount - itemInfo.weight * amount) or 0
        if toGets > CFreeWeight(to) or fromGets > CFreeWeight(from) then
            QBCore.Functions.Notify(src, Lang:t('notify.tooheavy'), 'error')
            return Refresh(src, from.kind ~= 'player' and from or to)
        end
    end

    local back = swapping and { name = toItem.name, info = toItem.info, created = toItem.created, amount = toItem.amount } or nil

    if not CRemove(from, fromSlot, fromName, amount) then return Refresh(src, from.kind ~= 'player' and from or to) end
    if back and not CRemove(to, toSlot, back.name, back.amount) then
        CAdd(from, src, fromSlot, moving, amount)
        return Refresh(src, from.kind ~= 'player' and from or to)
    end

    if not CAdd(to, src, toSlot, moving, amount) then
        CAdd(from, src, fromSlot, moving, amount)
        if back then CAdd(to, src, toSlot, back, back.amount) end
        return Refresh(src, from.kind ~= 'player' and from or to)
    end
    if back then CAdd(from, src, fromSlot, back, back.amount) end

    -- Side effects
    if from.kind == 'player' and to.kind ~= 'player' then AfterLeavingPlayer(src, fromName) end
    if from.kind == 'otherplayer' then
        TriggerClientEvent('inventory:client:CheckWeapon', from.src, fromName)
        TriggerClientEvent('inventory:client:ItemBox', from.src, ItemInfo(fromName), 'remove', amount)
        TriggerClientEvent('inventory:client:ItemBox', src, ItemInfo(fromName), 'add', amount)
    elseif to.kind == 'otherplayer' then
        TriggerClientEvent('inventory:client:ItemBox', to.src, ItemInfo(fromName), 'add', amount)
        TriggerClientEvent('inventory:client:ItemBox', src, ItemInfo(fromName), 'remove', amount)
    end
    if from.kind == 'player' and to.kind == 'player' then
        TriggerClientEvent('inventory:client:CheckWeapon', src, fromName)
    end
    if to.kind == 'drop' or from.kind == 'drop' then
        local drop = to.kind == 'drop' and to.store or from.store
        drop.createdTime = os.time()
    end

    if not sameContainer then
        local category = (from.kind == 'otherplayer' or to.kind == 'otherplayer') and 'robbing' or (to.kind ~= 'player' and to.kind or from.kind)
        Log(category, 'Moved Item', 'orange', ('%s moved %sx %s from %s to %s'):format(PlayerLabel(src), amount, fromName, tostring(fromInventory), tostring(toInventory)))
    end

    Refresh(src, from.kind ~= 'player' and from or to)
end)

--#endregion

--#region Using / combining / crafting

local function IsBroken(item)
    local itemInfo = ItemInfo(item.name)
    return itemInfo and itemInfo.decay and type(item.info) == 'table' and tonumber(item.info.quality) and tonumber(item.info.quality) <= 0
end

local function UseFromSlot(src, slot)
    local itemData = GetItemBySlot(src, slot)
    if not itemData then return end
    local itemInfo = ItemInfo(itemData.name)
    if itemData.type == 'weapon' then
        local quality = type(itemData.info) == 'table' and tonumber(itemData.info.quality)
        TriggerClientEvent('inventory:client:UseWeapon', src, itemData, quality == nil or quality > 0)
        TriggerClientEvent('inventory:client:ItemBox', src, itemInfo, 'use')
    elseif itemData.useable then
        if IsBroken(itemData) then
            return QBCore.Functions.Notify(src, Lang:t('notify.broken'), 'error')
        end
        UseItem(itemData.name, src, itemData)
        TriggerClientEvent('inventory:client:ItemBox', src, itemInfo, 'use')
    end
end

RegisterNetEvent('inventory:server:UseItemSlot', function(slot)
    UseFromSlot(source, tonumber(slot))
end)

RegisterNetEvent('inventory:server:UseItem', function(inventory, item)
    if inventory ~= 'player' and inventory ~= 'hotbar' then return end
    if type(item) ~= 'table' then return end
    UseFromSlot(source, tonumber(item.slot))
end)

RegisterNetEvent('inventory:server:combineItem', function(item, fromItem, toItem)
    local src = source
    if type(fromItem) ~= 'string' or type(toItem) ~= 'string' then return end
    local fromData = GetItemByName(src, fromItem)
    local toData = GetItemByName(src, toItem)
    if not fromData or not toData then return end

    local recipe = ItemInfo(toData.name) and ItemInfo(toData.name).combinable
    if type(recipe) ~= 'table' or recipe.reward ~= item or type(recipe.accept) ~= 'table' then return end
    local accepted = false
    for _, name in pairs(recipe.accept) do
        if name == fromData.name then accepted = true break end
    end
    if not accepted then return end

    if RemoveItem(src, fromData.name, 1) and RemoveItem(src, toData.name, 1) then
        AddItem(src, item, 1)
        TriggerClientEvent('inventory:client:ItemBox', src, ItemInfo(item), 'add')
    end
end)

local function FinishCraft(src, kind)
    local craft = PendingCraft[src]
    PendingCraft[src] = nil
    if not craft or craft.kind ~= kind then return end
    local elapsed = os.time() - craft.time
    if elapsed > craft.amount * 6 + 10 or elapsed < craft.amount * 2 - 1 then return end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    for name, cost in pairs(craft.costs) do
        if CountItem(src, name) < cost * craft.amount then
            return QBCore.Functions.Notify(src, Lang:t('notify.noitem'), 'error')
        end
    end
    for name, cost in pairs(craft.costs) do
        RemoveItem(src, name, cost * craft.amount)
    end
    if AddItem(src, craft.name, craft.amount, craft.toSlot) then
        TriggerClientEvent('inventory:client:ItemBox', src, ItemInfo(craft.name), 'add', craft.amount)
    end
    Player.Functions.SetMetaData(craft.rep, (tonumber(Player.PlayerData.metadata[craft.rep]) or 0) + craft.points * craft.amount)
end

-- Arguments from the client are ignored: the server uses the craft it validated itself.
RegisterNetEvent('inventory:server:CraftItems', function()
    FinishCraft(source, 'crafting')
end)

RegisterNetEvent('inventory:server:CraftAttachment', function()
    FinishCraft(source, 'attachment_crafting')
end)

--#endregion

--#region Giving

QBCore.Functions.CreateCallback('qb-inventory:server:GetClosestPlayer', function(source, cb)
    local src = source
    local list = {}
    for _, player in pairs(QBCore.Functions.GetQBPlayers()) do
        local target = player.PlayerData.source
        if target ~= src and PlayersDistance(src, target) <= Config.GiveDistance then
            list[#list + 1] = {
                name = player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname,
                id = target,
            }
        end
    end
    cb(list)
end)

RegisterNetEvent('inventory:server:GiveItem', function(data)
    local src = source
    if type(data) ~= 'table' then return end
    local Player = QBCore.Functions.GetPlayer(src)
    local target = tonumber(data.playerId)
    local OtherPlayer = target and QBCore.Functions.GetPlayer(target)
    if not Player or not OtherPlayer then return QBCore.Functions.Notify(src, Lang:t('notify.pdne'), 'error') end
    if target == src then return QBCore.Functions.Notify(src, Lang:t('notify.gsitem'), 'error') end
    if PlayersDistance(src, target) > Config.GiveDistance then return QBCore.Functions.Notify(src, Lang:t('notify.tftgitem'), 'error') end

    local item = GetItemBySlot(src, tonumber(data.slot))
    if not item then return QBCore.Functions.Notify(src, Lang:t('notify.infound'), 'error') end
    if item.name ~= data.name then return QBCore.Functions.Notify(src, Lang:t('notify.iifound'), 'error') end

    local amount = tonumber(data.amount) or 0
    amount = math.floor(amount)
    if amount == 0 then amount = item.amount end
    if amount < 1 or amount > item.amount then return QBCore.Functions.Notify(src, Lang:t('notify.gitydhitt'), 'error') end

    if item.weight * amount > Config.MaxInventoryWeight - GetTotalWeight(OtherPlayer.PlayerData.items) then
        return QBCore.Functions.Notify(src, Lang:t('notify.gitinvfull'), 'error')
    end

    local info, created = item.info, item.created
    if not RemoveItem(src, item.name, amount, item.slot) then
        return QBCore.Functions.Notify(src, Lang:t('notify.gitydhei'), 'error')
    end
    if not AddItem(target, item.name, amount, false, info, created) then
        AddItem(src, item.name, amount, item.slot, info, created)
        QBCore.Functions.Notify(src, Lang:t('notify.gitinvfull'), 'error')
        return QBCore.Functions.Notify(target, Lang:t('notify.giymif'), 'error')
    end

    local senderName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    local targetName = OtherPlayer.PlayerData.charinfo.firstname .. ' ' .. OtherPlayer.PlayerData.charinfo.lastname
    TriggerClientEvent('inventory:client:ItemBox', target, ItemInfo(item.name), 'add', amount)
    TriggerClientEvent('inventory:client:ItemBox', src, ItemInfo(item.name), 'remove', amount)
    QBCore.Functions.Notify(target, Lang:t('notify.gitemrec') .. amount .. ' ' .. item.label .. Lang:t('notify.gitemfrom') .. senderName)
    QBCore.Functions.Notify(src, Lang:t('notify.gitemyg') .. targetName .. ' ' .. amount .. ' ' .. item.label .. '!')
    TriggerClientEvent('qb-inventory:client:giveAnim', src)
    TriggerClientEvent('qb-inventory:client:giveAnim', target)
    if item.type == 'weapon' then TriggerClientEvent('inventory:client:GiveItemRemoveWeapon', src) end
    AfterLeavingPlayer(src, item.name)
    Refresh(src, nil)
    Log('giveitemplayer', 'Give Item', 'green', ('%s gave %s item: %s amount: %s'):format(PlayerLabel(src), PlayerLabel(target), item.label, amount))
end)

--#endregion

--#region Misc events

-- Used by job scripts to fill a fresh (unowned) work vehicle's trunk
RegisterNetEvent('inventory:server:addTrunkItems', function(plate, items)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or type(plate) ~= 'string' or type(items) ~= 'table' then return end
    if not Config.TrunkItemJobs[Player.PlayerData.job.name] then return end
    plate = Trim(plate)
    if IsVehicleOwned(plate) or (Trunks[plate] and next(Trunks[plate].items)) then return end
    local size = Config.TrunkSizes.default
    local store = { items = {}, slots = size.slots, maxweight = size.maxweight, label = 'Trunk-' .. plate, isOpen = false }
    for _, item in pairs(items) do
        if type(item) == 'table' and ItemInfo(item.name) then
            AddToStore(store, item.slot, ItemInfo(item.name).name, ToAmount(item.amount) or 1, item.info, nil)
        end
    end
    Trunks[plate] = store
end)

-- Server-side only (other resources). Clients can not write stashes.
RegisterNetEvent('qb-inventory:server:SaveStashItems', function(stashId, items)
    if source ~= '' and tonumber(source) then return end
    SaveStashItems(stashId, items)
end)

RegisterNetEvent('inventory:server:snowball', function(action)
    local src = source
    if action == 'add' then
        AddItem(src, 'weapon_snowball')
    elseif action == 'remove' then
        RemoveItem(src, 'weapon_snowball')
    end
end)

--#endregion

--#region Callbacks

QBCore.Functions.CreateCallback('qb-inventory:server:GetStashItems', function(_, cb, stashId)
    cb(GetStashItems(tostring(stashId)))
end)

QBCore.Functions.CreateCallback('inventory:server:GetCurrentDrops', function(_, cb)
    local list = {}
    for id, drop in pairs(Drops) do
        list[#list + 1] = { id = id, coords = drop.coords }
    end
    cb(list)
end)

QBCore.Functions.CreateCallback('QBCore:HasItem', function(source, cb, items, amount)
    cb(HasItem(source, items, amount))
end)

--#endregion

--#region Commands

QBCore.Commands.Add('resetinv', 'Reset Inventory (Admin Only)', { { name = 'type', help = 'stash/trunk/glovebox' }, { name = 'id/plate', help = 'ID of stash or license plate' } }, true, function(source, args)
    local invType = tostring(args[1]):lower()
    table.remove(args, 1)
    local invId = table.concat(args, ' ')
    local stores = { trunk = Trunks, glovebox = Gloveboxes, stash = Stashes }
    if not stores[invType] then
        return QBCore.Functions.Notify(source, Lang:t('notify.navt'), 'error')
    end
    if stores[invType][invId] then
        stores[invType][invId].isOpen = false
    end
    for src, open in pairs(OpenInventories) do
        if open.kind == invType and tostring(open.id) == invId then OpenInventories[src] = nil end
    end
end, { 'god', 'admin', 'operator' })

QBCore.Commands.Add('rob', 'Rob Player', {}, false, function(source)
    TriggerClientEvent('police:client:RobPlayer', source)
end)

QBCore.Commands.Add('gg', 'Give An Item (Admin Only)', { { name = 'id', help = 'Player ID' }, { name = 'item', help = 'Name of the item (not a label)' }, { name = 'amount', help = 'Amount of items' } }, false, function(source, args)
    local id = tonumber(args[1])
    local Player = id and QBCore.Functions.GetPlayer(id)
    local amount = ToAmount(args[3]) or 1
    local itemData = ItemInfo(tostring(args[2]))
    if not Player then return QBCore.Functions.Notify(source, Lang:t('notify.pdne'), 'error') end
    if not itemData then return QBCore.Functions.Notify(source, Lang:t('notify.idne'), 'error') end

    local info = {}
    local charinfo = Player.PlayerData.charinfo
    if itemData.name == 'id_card' then
        info.citizenid = Player.PlayerData.citizenid
        info.firstname = charinfo.firstname
        info.lastname = charinfo.lastname
        info.birthdate = charinfo.birthdate
        info.gender = charinfo.gender
        info.nationality = charinfo.nationality
    elseif itemData.name == 'driver_license' then
        info.firstname = charinfo.firstname
        info.lastname = charinfo.lastname
        info.birthdate = charinfo.birthdate
        info.type = 'Class C Driver License'
    elseif itemData.type == 'weapon' then
        amount = 1
    elseif itemData.name == 'harness' then
        info.uses = 20
    elseif itemData.name == 'markedbills' then
        info.worth = math.random(5000, 10000)
    elseif itemData.name == 'labkey' and GetResourceState('qb-methlab') == 'started' then
        info.lab = exports['qb-methlab']:GenerateRandomLab()
    elseif itemData.name == 'moneybox' then
        info.money = math.random(10000, 15000)
    elseif itemData.name == 'jerrycan01' then
        info.gasamount = 20
    end

    if AddItem(id, itemData.name, amount, false, info) then
        QBCore.Functions.Notify(source, Lang:t('notify.yhg') .. GetPlayerName(id) .. ' ' .. amount .. ' ' .. itemData.name, 'success')
        TriggerClientEvent('inventory:client:ItemBox', id, itemData, 'add', amount)
        Log('giveitem', 'Item Spawned', 'green', ('**%s** spawned item to **%s** amount: **%s** item: **%s**'):format(GetPlayerName(source) or 'console', GetPlayerName(id), amount, itemData.label))
    else
        QBCore.Functions.Notify(source, Lang:t('notify.cgitem'), 'error')
    end
end, { 'god', 'admin', 'operator', 'staff', 'supervisor', 'trusted' })

QBCore.Commands.Add('randomitems', 'Give Random Items (God Only)', {}, false, function(source)
    local filteredItems = {}
    for _, item in pairs(QBCore.Shared.Items) do
        if item.type ~= 'weapon' then filteredItems[#filteredItems + 1] = item end
    end
    for _ = 1, 10 do
        local randitem = filteredItems[math.random(1, #filteredItems)]
        local amount = randitem.unique and 1 or math.random(1, 10)
        if AddItem(source, randitem.name, amount) then
            TriggerClientEvent('inventory:client:ItemBox', source, randitem, 'add', amount)
            Wait(500)
        end
    end
end, 'god')

QBCore.Commands.Add('clearinv', 'Clear Players Inventory (Admin Only)', { { name = 'id', help = 'Player ID' } }, false, function(source, args)
    local playerId = args[1] and args[1] ~= '' and tonumber(args[1]) or source
    if QBCore.Functions.GetPlayer(playerId) then
        ClearInventory(playerId)
    else
        QBCore.Functions.Notify(source, Lang:t('notify.pdne'), 'error')
    end
end, { 'god', 'admin', 'operator' })

--#endregion

--#region Vending validation

---Keeps only vending items that match the server config (name and price)
function ValidVendingItems(items)
    local allowed = {}
    for _, list in ipairs({ Config.VendingItem, Config.VendingSnaksItem }) do
        for _, item in pairs(list) do allowed[item.name] = tonumber(item.price) end
    end
    local out = {}
    for _, item in ipairs(items) do
        if allowed[item.name] and allowed[item.name] == tonumber(item.price) then
            out[#out + 1] = item
        end
    end
    return out
end

--#endregion
