local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = QBCore.Functions.GetPlayerData()

local inInventory = false
local opening = false
local isCrafting = false
local isHotbar = false
local showBlur = Config.Blur
local blurActive = false
local currentWeapon = nil
local stringsSent = false

local CurrentVehicle = nil   -- plate of the open trunk
local trunkEntity = nil
local CurrentGlovebox = nil
local CurrentStash = nil
local CurrentDrop = nil      -- closest drop id (within interact distance)
local activeAnim = nil       -- animation kept while the inventory is open

local Drops = {}             -- [id] = { coords = vector3, object = entity|nil }
local nearbyDrops = {}

--#region Helpers

local UI_KEYS = {
    'inventory', 'pockets', 'ground', 'trunk', 'glovebox', 'stash', 'shop', 'crafting', 'player', 'drop', 'search',
    'amount', 'all', 'use', 'give', 'split', 'attachments', 'combine', 'swap', 'cancel', 'close', 'weight', 'quality',
    'broken', 'price', 'costs', 'serial', 'ammo', 'durability', 'no_attachments', 'remove', 'give_to', 'no_players',
    'received', 'removed', 'used', 'required', 'take_money', 'cash', 'job', 'all_items', 'weapons', 'food', 'tools',
    'general', 'hint_move', 'hint_quick', 'hint_use', 'hint_menu', 'in_use',
    'personal', 'information', 'state_id', 'citizen_id', 'name',
}

local function UiStrings()
    local strings = {}
    for _, key in ipairs(UI_KEYS) do strings[key] = Lang:t('ui.' .. key) end
    return strings
end

local function IsLoggedIn()
    return PlayerData and PlayerData.citizenid ~= nil and PlayerData.metadata ~= nil
end

local function CanUseInventory()
    if not IsLoggedIn() then return false end
    local meta = PlayerData.metadata
    return not meta.isdead and not meta.inlaststand and not meta.ishandcuffed
        and not IsPauseMenuActive() and not LocalPlayer.state.inv_busy
        and not IsEntityDead(PlayerPedId())
end

---Loads an animation dictionary; returns false if it does not exist or takes too long
local function LoadAnimDict(dict, timeout)
    if HasAnimDictLoaded(dict) then return true end
    if not DoesAnimDictExist(dict) then return false end
    RequestAnimDict(dict)
    local deadline = GetGameTimer() + (timeout or 1000)
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > deadline then return false end
        Wait(10)
    end
    return true
end

local function PlayAnim(anim)
    if not anim or not anim.dict or not LoadAnimDict(anim.dict, 800) then return false end
    TaskPlayAnim(PlayerPedId(), anim.dict, anim.clip, 3.0, 3.0, -1, anim.flag or 48, 0, false, false, false)
    return true
end

local function StopAnim(anim)
    if anim and anim.dict then
        StopAnimTask(PlayerPedId(), anim.dict, anim.clip, 1.5)
    end
end

local function SetBlur(enabled)
    if enabled and not blurActive then
        blurActive = true
        TriggerScreenblurFadeIn(300)
    elseif not enabled and blurActive then
        blurActive = false
        TriggerScreenblurFadeOut(300)
    end
end

local function TrunkDoor(vehicle)
    return BackEngineVehicles[GetEntityModel(vehicle)] and 4 or 5
end

local function OpenTrunkDoor(vehicle)
    if vehicle and DoesEntityExist(vehicle) then
        SetVehicleDoorOpen(vehicle, TrunkDoor(vehicle), false, false)
    end
end

local function CloseTrunkDoor()
    if trunkEntity and DoesEntityExist(trunkEntity) then
        SetVehicleDoorShut(trunkEntity, TrunkDoor(trunkEntity), false)
    end
    trunkEntity = nil
end

local function FormatWeaponAttachments(itemdata)
    local attachments = {}
    local info = type(itemdata.info) == 'table' and itemdata.info or {}
    for _, v in pairs(info.attachments or {}) do
        local shared = QBCore.Shared.Items[v.item]
        attachments[#attachments + 1] = {
            attachment = v.item,
            label = v.label,
            image = shared and shared.image or (tostring(v.item) .. '.png'),
            component = v.component,
        }
    end
    return attachments
end

local function closeInventory()
    SendNUIMessage({ action = 'close' })
end

local function ToggleHotbar(toggle)
    if toggle then
        local items = PlayerData.items or {}
        SendNUIMessage({
            action = 'toggleHotbar',
            open = true,
            items = { [1] = items[1], [2] = items[2], [3] = items[3], [4] = items[4], [5] = items[5], [Config.MaxInventorySlots] = items[Config.MaxInventorySlots] },
            special = Config.MaxInventorySlots,
        })
    else
        SendNUIMessage({ action = 'toggleHotbar', open = false })
    end
end

---Closest vending machine and the item list it sells
local function GetClosestVending()
    local pos = GetEntityCoords(PlayerPedId())
    for _, model in ipairs(Config.VendingObjects) do
        if GetClosestObjectOfType(pos.x, pos.y, pos.z, 0.75, joaat(model), false, false, false) ~= 0 then
            return Config.VendingItem
        end
    end
    for _, model in ipairs(Config.VendingObjects2 or {}) do
        if GetClosestObjectOfType(pos.x, pos.y, pos.z, 0.75, joaat(model), false, false, false) ~= 0 then
            return Config.VendingSnaksItem
        end
    end
    return nil
end

local function OpenVending(items)
    TriggerServerEvent('inventory:server:OpenInventory', 'shop', 'Vendingshop_' .. math.random(1, 99), {
        label = Lang:t('menu.vending'),
        items = items,
        slots = #items,
    })
end

--#endregion

--#region HasItem (client)

---@param items string | string[] | table<string, number>
---@param amount? number
local function HasItem(items, amount)
    local inventory = PlayerData and PlayerData.items
    if not inventory then return false end
    local function count(name)
        local total = 0
        for _, item in pairs(inventory) do
            if item and item.name == name then total = total + item.amount end
        end
        return total
    end
    if type(items) == 'string' then
        return count(items) >= (amount or 1)
    end
    if type(items) ~= 'table' then return false end
    local isArray = table.type(items) == 'array'
    for k, v in pairs(items) do
        local name = isArray and v or k
        local need = isArray and (amount or 1) or (amount or v)
        if count(name) < need then return false end
    end
    return true
end

exports('HasItem', HasItem)

--#endregion

--#region Drops (only work when a drop is near)

local function DeleteDropObject(drop)
    if drop and drop.object then
        if Config.UseTarget and GetResourceState('qb-target') == 'started' then
            exports['qb-target']:RemoveTargetEntity(drop.object)
        end
        if DoesEntityExist(drop.object) then DeleteEntity(drop.object) end
        drop.object = nil
    end
end

local function SpawnDropObject(id, drop)
    local model = Config.ItemDropObject
    if not IsModelInCdimage(model) then return end
    RequestModel(model)
    local deadline = GetGameTimer() + 1000
    while not HasModelLoaded(model) do
        if GetGameTimer() > deadline then return end
        Wait(10)
    end
    if not Drops[id] then return end -- removed while loading
    local object = CreateObject(model, drop.coords.x, drop.coords.y, drop.coords.z, false, false, false)
    PlaceObjectOnGroundProperly(object)
    FreezeEntityPosition(object, true)
    SetEntityCollision(object, false, false)
    SetModelAsNoLongerNeeded(model)
    drop.object = object
    if Config.UseTarget and GetResourceState('qb-target') == 'started' then
        exports['qb-target']:AddTargetEntity(object, {
            options = { {
                icon = 'fas fa-sack',
                label = Lang:t('menu.o_bag'),
                action = function() TriggerServerEvent('inventory:server:OpenInventory', 'drop', id) end,
            } },
            distance = 2.0,
        })
    end
end

local function AddDrop(id, coords)
    if not id or not coords then return end
    Drops[id] = { coords = vector3(coords.x, coords.y, coords.z) }
end

local function RemoveDrop(id)
    DeleteDropObject(Drops[id])
    Drops[id] = nil
    if CurrentDrop == id then CurrentDrop = nil end
end

local function FetchDrops()
    QBCore.Functions.TriggerCallback('inventory:server:GetCurrentDrops', function(list)
        for id in pairs(Drops) do RemoveDrop(id) end
        for _, drop in ipairs(list or {}) do AddDrop(drop.id, drop.coords) end
    end)
end

-- Scan every second (no per-frame cost when there are no drops around)
CreateThread(function()
    while true do
        Wait(1000)
        if Config.EnableDrops and next(Drops) then
            local pos = GetEntityCoords(PlayerPedId())
            local closest, closestDist = nil, Config.DropInteractDistance
            local list = {}
            for id, drop in pairs(Drops) do
                local dist = #(pos - drop.coords)
                if dist <= Config.MaxDropViewDistance then
                    list[#list + 1] = drop
                    if Config.UseItemDrop and not drop.object then SpawnDropObject(id, drop) end
                elseif drop.object then
                    DeleteDropObject(drop)
                end
                if dist < closestDist then closest, closestDist = id, dist end
            end
            nearbyDrops = list
            CurrentDrop = closest
        else
            nearbyDrops = {}
            CurrentDrop = nil
        end
    end
end)

-- Markers are drawn only while a drop is in view and props are disabled
CreateThread(function()
    while true do
        if not Config.UseItemDrop and #nearbyDrops > 0 then
            for i = 1, #nearbyDrops do
                local c = nearbyDrops[i].coords
                DrawMarker(2, c.x, c.y, c.z + 0.2, 0.0, 0.0, 0.0, 0.0, 180.0, 0.0, 0.2, 0.2, 0.15, 22, 136, 255, 160, false, true, 2, false, nil, nil, false)
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

--#endregion

--#region Opening with an emote

local openToken = 0

local function FinishOpening()
    opening = false
end

---If the server never opens the inventory (busy, too far...), undo the emote and the trunk door
local function OpeningWatchdog()
    openToken = openToken + 1
    local token = openToken
    SetTimeout(3000, function()
        if token ~= openToken then return end
        FinishOpening()
        if not inInventory then
            if activeAnim then
                StopAnim(activeAnim)
                activeAnim = nil
            end
            CloseTrunkDoor()
        end
    end)
end

---Plays the short emote of `kind`, then runs `open` if the player can still use the inventory
local function OpenWithEmote(kind, open)
    local cfg = Config.OpenAnimation
    local anim = cfg and cfg.enabled and cfg[kind] or nil
    if not anim then
        open()
        return OpeningWatchdog()
    end

    opening = true
    local played = PlayAnim(anim)
    if played and kind == 'trunk' then activeAnim = anim end

    CreateThread(function()
        local finishAt = GetGameTimer() + (anim.delay or 0)
        while GetGameTimer() < finishAt do
            if not CanUseInventory() then
                if played then StopAnim(anim) end
                activeAnim = nil
                CloseTrunkDoor()
                CurrentVehicle, CurrentGlovebox = nil, nil
                return FinishOpening()
            end
            Wait(50)
        end
        if played and kind == 'player' then StopAnim(anim) end
        open()
        OpeningWatchdog()
    end)
end

local function TryOpenInventory()
    if opening or inInventory or isCrafting or not CanUseInventory() or IsNuiFocused() then return end
    local ped = PlayerPedId()

    -- Glovebox
    if IsPedInAnyVehicle(ped, false) then
        local vehicle = GetVehiclePedIsIn(ped, false)
        CurrentGlovebox = QBCore.Functions.GetPlate(vehicle)
        CurrentVehicle = nil
        return OpenWithEmote('glovebox', function()
            TriggerServerEvent('inventory:server:OpenInventory', 'glovebox', CurrentGlovebox)
        end)
    end

    -- Trunk
    local vehicle = QBCore.Functions.GetClosestVehicle()
    if vehicle and vehicle ~= 0 then
        local model = GetEntityModel(vehicle)
        local dimMin, dimMax = GetModelDimensions(model)
        local trunkPos = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, BackEngineVehicles[model] and dimMax.y or dimMin.y, 0.0)
        if #(GetEntityCoords(ped) - trunkPos) < 1.5 then
            if GetVehicleDoorLockStatus(vehicle) >= 2 then
                return QBCore.Functions.Notify(Lang:t('notify.vlocked'), 'error')
            end
            local class = GetVehicleClass(vehicle)
            if class == 13 then return end -- bicycles have no trunk
            CurrentVehicle = QBCore.Functions.GetPlate(vehicle)
            CurrentGlovebox = nil
            trunkEntity = vehicle
            OpenTrunkDoor(vehicle)
            return OpenWithEmote('trunk', function()
                TriggerServerEvent('inventory:server:OpenInventory', 'trunk', CurrentVehicle, { class = class })
            end)
        end
    end
    CurrentVehicle, CurrentGlovebox = nil, nil

    -- Bag on the ground
    if Config.EnableDrops and CurrentDrop then
        local dropId = CurrentDrop
        return OpenWithEmote('drop', function()
            TriggerServerEvent('inventory:server:OpenInventory', 'drop', dropId)
        end)
    end

    -- Vending machine
    if not Config.UseTarget then
        local vendingItems = GetClosestVending()
        if vendingItems then return OpenVending(vendingItems) end
    end

    -- Own pockets
    OpenWithEmote('player', function()
        TriggerServerEvent('inventory:server:OpenInventory')
    end)
end

--#endregion

--#region Events

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    LocalPlayer.state:set('inv_busy', false, true)
    PlayerData = QBCore.Functions.GetPlayerData()
    FetchDrops()
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    LocalPlayer.state:set('inv_busy', true, true)
    if inInventory then closeInventory() end
    PlayerData = {}
    for id in pairs(Drops) do RemoveDrop(id) end
end)

RegisterNetEvent('QBCore:Client:UpdateObject', function()
    QBCore = exports['qb-core']:GetCoreObject()
end)

local refreshQueued = false
RegisterNetEvent('QBCore:Player:SetPlayerData', function(val)
    PlayerData = val
    -- Items changed by another script while the inventory is open
    if inInventory and not refreshQueued then
        refreshQueued = true
        SetTimeout(60, function()
            refreshQueued = false
            if inInventory then
                SendNUIMessage({ action = 'refresh', inventory = PlayerData.items, cash = PlayerData.money and PlayerData.money.cash })
            end
        end)
    end
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    for _, drop in pairs(Drops) do DeleteDropObject(drop) end
    if inInventory then SetNuiFocus(false, false) end
    if blurActive then TriggerScreenblurFadeOut(0) end
end)

AddEventHandler('onClientResourceStart', function(name)
    if name ~= GetCurrentResourceName() then return end
    if IsLoggedIn() then FetchDrops() end
end)

RegisterNetEvent('qb-inventory:client:closeinv', function()
    closeInventory()
end)

RegisterNetEvent('qb-inventory:client:showBlur', function()
    showBlur = not showBlur
end)

RegisterNetEvent('inventory:client:CheckOpenState', function(type, id)
    local using = (type == 'stash' and CurrentStash == id) or (type == 'trunk' and CurrentVehicle == id)
        or (type == 'glovebox' and CurrentGlovebox == id)
    if not inInventory or not using then
        TriggerServerEvent('inventory:server:SetIsOpenState', false, type, id)
    end
end)

RegisterNetEvent('weapons:client:SetCurrentWeapon', function(data)
    CurrentWeaponData = data or {}
end)

RegisterNetEvent('inventory:client:ItemBox', function(itemData, type, amount)
    if not itemData then return end
    SendNUIMessage({ action = 'itemBox', item = itemData, type = type, itemAmount = amount or 1 })
end)

RegisterNetEvent('inventory:client:requiredItems', function(items, bool)
    local list = {}
    if bool then
        for _, item in pairs(items or {}) do
            local shared = QBCore.Shared.Items[item.name]
            list[#list + 1] = {
                item = item.name,
                label = shared and shared.label or item.name,
                image = item.image or (shared and shared.image),
            }
        end
    end
    SendNUIMessage({ action = 'requiredItem', items = list, toggle = bool })
end)

RegisterNetEvent('inventory:server:RobPlayer', function(TargetId)
    SendNUIMessage({ action = 'RobMoney', TargetId = TargetId })
end)

RegisterNetEvent('inventory:client:OpenInventory', function(PlayerAmmo, inventory, other)
    FinishOpening()
    openToken = openToken + 1
    if IsEntityDead(PlayerPedId()) or not IsLoggedIn() then return end

    ToggleHotbar(false)
    isHotbar = false
    if showBlur then SetBlur(true) end
    SetNuiFocus(true, true)

    if other and other.name == 'none-inv' and not other.slots then other = nil end
    local money = PlayerData.money or {}
    local charinfo = PlayerData.charinfo or {}
    SendNUIMessage({
        action = 'open',
        inventory = inventory,
        slots = Config.MaxInventorySlots,
        maxweight = Config.MaxInventoryWeight,
        other = other,
        Ammo = PlayerAmmo,
        maxammo = Config.MaximumAmmoValues,
        pid = GetPlayerServerId(PlayerId()),
        citizenid = PlayerData.citizenid,
        firstname = charinfo.firstname,
        lastname = charinfo.lastname,
        job = PlayerData.job and PlayerData.job.label,
        cash = money.cash or 0,
        drops = Config.EnableDrops,
        dropSlots = Config.DropSlots,
        dropMaxWeight = Config.DropMaxWeight,
        special = Config.MaxInventorySlots,
        side = Config.InventorySide,
        brandTag = Config.BrandTag,
        strings = not stringsSent and UiStrings() or nil,
    })
    stringsSent = true
    inInventory = true
end)

-- Server truth after every move: keeps the UI exact
RegisterNetEvent('inventory:client:refresh', function(items, otherName, otherItems)
    if not inInventory then return end
    SendNUIMessage({ action = 'refresh', inventory = items, otherName = otherName, other = otherItems })
end)

RegisterNetEvent('inventory:client:UpdatePlayerInventory', function(isError)
    if inInventory then
        SendNUIMessage({ action = 'refresh', inventory = PlayerData.items, error = isError })
    end
end)

local function CraftProgress(serverEvent, amount)
    local ped = PlayerPedId()
    closeInventory()
    isCrafting = true
    QBCore.Functions.Progressbar('repair_vehicle', Lang:t('progress.crafting'), math.random(2000, 5000) * math.max(1, tonumber(amount) or 1), false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {
        animDict = 'mini@repair',
        anim = 'fixing_a_player',
        flags = 16,
    }, {}, {}, function()
        StopAnimTask(ped, 'mini@repair', 'fixing_a_player', 1.0)
        TriggerServerEvent(serverEvent)
        isCrafting = false
    end, function()
        StopAnimTask(ped, 'mini@repair', 'fixing_a_player', 1.0)
        QBCore.Functions.Notify(Lang:t('notify.failed'), 'error')
        isCrafting = false
    end)
end

RegisterNetEvent('inventory:client:CraftItems', function(_, _, amount)
    CraftProgress('inventory:server:CraftItems', amount)
end)

RegisterNetEvent('inventory:client:CraftAttachment', function(_, _, amount)
    CraftProgress('inventory:server:CraftAttachment', amount)
end)

RegisterNetEvent('inventory:client:PickupSnowballs', function()
    local ped = PlayerPedId()
    if LoadAnimDict('anim@mp_snowball') then
        TaskPlayAnim(ped, 'anim@mp_snowball', 'pickup_snowball', 3.0, 3.0, -1, 0, 1, false, false, false)
    end
    QBCore.Functions.Progressbar('pickupsnowball', Lang:t('progress.snowballs'), 1500, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {}, {}, {}, function()
        ClearPedTasks(ped)
        TriggerServerEvent('inventory:server:snowball', 'add')
    end, function()
        ClearPedTasks(ped)
        QBCore.Functions.Notify(Lang:t('notify.canceled'), 'error')
    end)
end)

RegisterNetEvent('inventory:client:UseSnowball', function(amount)
    local ped = PlayerPedId()
    GiveWeaponToPed(ped, `weapon_snowball`, amount, false, false)
    SetPedAmmo(ped, `weapon_snowball`, amount)
    SetCurrentPedWeapon(ped, `weapon_snowball`, true)
end)

local Throwables = {
    weapon_stickybomb = true, weapon_pipebomb = true, weapon_smokegrenade = true, weapon_flare = true, weapon_proxmine = true,
    weapon_ball = true, weapon_molotov = true, weapon_grenade = true, weapon_bzgas = true,
}

RegisterNetEvent('inventory:client:UseWeapon', function(weaponData, shootbool)
    if type(weaponData) ~= 'table' or not weaponData.name then return end
    local ped = PlayerPedId()
    local weaponName = tostring(weaponData.name)
    local weaponHash = joaat(weaponName)
    local info = type(weaponData.info) == 'table' and weaponData.info or {}

    if currentWeapon == weaponName then
        SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
        Wait(1500)
        RemoveAllPedWeapons(ped, true)
        TriggerEvent('weapons:client:SetCurrentWeapon', nil, shootbool)
        currentWeapon = nil
    elseif Throwables[weaponName] then
        GiveWeaponToPed(ped, weaponHash, 1, false, false)
        SetPedAmmo(ped, weaponHash, 1)
        SetCurrentPedWeapon(ped, weaponHash, true)
        TriggerEvent('weapons:client:SetCurrentWeapon', weaponData, shootbool)
        currentWeapon = weaponName
    elseif weaponName == 'weapon_snowball' then
        GiveWeaponToPed(ped, weaponHash, 10, false, false)
        SetPedAmmo(ped, weaponHash, 10)
        SetCurrentPedWeapon(ped, weaponHash, true)
        TriggerServerEvent('inventory:server:snowball', 'remove')
        TriggerEvent('weapons:client:SetCurrentWeapon', weaponData, shootbool)
        currentWeapon = weaponName
    else
        TriggerEvent('weapons:client:SetCurrentWeapon', weaponData, shootbool)
        local ammo = tonumber(info.ammo) or 0
        if weaponName == 'weapon_fireextinguisher' then ammo = 4000 end
        GiveWeaponToPed(ped, weaponHash, ammo, false, false)
        SetPedAmmo(ped, weaponHash, ammo)
        SetCurrentPedWeapon(ped, weaponHash, true)
        for _, attachment in pairs(info.attachments or {}) do
            if attachment.component then
                GiveWeaponComponentToPed(ped, weaponHash, joaat(attachment.component))
            end
        end
        currentWeapon = weaponName
    end
end)

RegisterNetEvent('inventory:client:CheckWeapon', function(weaponName)
    if type(weaponName) ~= 'string' or currentWeapon ~= weaponName:lower() then return end
    -- Still has another copy of the same weapon? keep it out.
    if HasItem(weaponName:lower()) then return end
    local ped = PlayerPedId()
    TriggerEvent('weapons:ResetHolster')
    SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
    RemoveAllPedWeapons(ped, true)
    currentWeapon = nil
end)

RegisterNetEvent('inventory:client:AddDropItem', function(dropId, _, coords)
    AddDrop(dropId, coords)
end)

RegisterNetEvent('inventory:client:RemoveDropItem', function(dropId)
    RemoveDrop(dropId)
end)

RegisterNetEvent('inventory:client:DropItemAnim', function()
    local anim = { dict = 'pickup_object', clip = 'putdown_low', flag = 48 }
    PlayAnim(anim)
end)

RegisterNetEvent('inventory:client:SetCurrentStash', function(stash)
    CurrentStash = stash
end)

RegisterNetEvent('qb-inventory:client:giveAnim', function()
    if IsPedInAnyVehicle(PlayerPedId(), false) then return end
    PlayAnim({ dict = 'mp_common', clip = 'givetake1_b', flag = 48 })
end)

RegisterNetEvent('inventory:client:craftTarget', function()
    TriggerServerEvent('inventory:server:OpenInventory', 'crafting', math.random(1, 99), { label = Lang:t('label.craft') })
end)

RegisterNetEvent('inventory:client:attachmentCraftTarget', function()
    TriggerServerEvent('inventory:server:OpenInventory', 'attachment_crafting', math.random(1, 99), { label = Lang:t('label.a_craft') })
end)

RegisterNetEvent('inventory:client:GiveItemRemoveWeapon', function()
    if currentWeapon and not HasItem(currentWeapon) then
        SetCurrentPedWeapon(PlayerPedId(), `WEAPON_UNARMED`, true)
    end
end)

RegisterNetEvent('inventory:client:OpenTrash', function()
    local trashId = 'Trash' .. math.random(100000, 999999) .. math.random(100000, 999999)
    TriggerServerEvent('inventory:server:OpenInventory', 'stash', trashId, { maxweight = 200000, slots = 5 })
    TriggerEvent('inventory:client:SetCurrentStash', trashId)
end)

--#endregion

--#region Commands

RegisterCommand('closeinv', function()
    closeInventory()
end, false)

RegisterCommand('inventory', function()
    TryOpenInventory()
end, false)

RegisterKeyMapping('inventory', Lang:t('inf_mapping.opn_inv'), 'keyboard', 'TAB')

RegisterCommand('hotbar', function()
    if not CanUseInventory() then return end
    isHotbar = not isHotbar
    ToggleHotbar(isHotbar)
end, false)

RegisterKeyMapping('hotbar', Lang:t('inf_mapping.tog_slots'), 'keyboard', 'z')

for i = 1, 6 do
    RegisterCommand('slot' .. i, function()
        if inInventory or not CanUseInventory() then return end
        TriggerServerEvent('inventory:server:UseItemSlot', i == 6 and Config.MaxInventorySlots or i)
    end, false)
    RegisterKeyMapping('slot' .. i, Lang:t('inf_mapping.use_item') .. i, 'keyboard', tostring(i))
end

--#endregion

--#region NUI

RegisterNUICallback('RobMoney', function(data, cb)
    TriggerServerEvent('police:server:RobPlayer', data.TargetId)
    cb('ok')
end)

RegisterNUICallback('Notify', function(data, cb)
    QBCore.Functions.Notify(data.message, data.type)
    cb('ok')
end)

RegisterNUICallback('showBlur', function(_, cb)
    showBlur = not showBlur
    SetBlur(showBlur and inInventory)
    cb('ok')
end)

RegisterNUICallback('GetWeaponData', function(cData, cb)
    local item = type(cData.ItemData) == 'table' and cData.ItemData or {}
    cb({
        WeaponData = QBCore.Shared.Items[cData.weapon],
        AttachmentData = FormatWeaponAttachments(item),
    })
end)

RegisterNUICallback('RemoveAttachment', function(data, cb)
    local ped = PlayerPedId()
    if type(data.AttachmentData) ~= 'table' or type(data.WeaponData) ~= 'table' then return cb({}) end
    local WeaponData = QBCore.Shared.Items[data.WeaponData.name]
    local component = data.AttachmentData.component
    data.AttachmentData.attachment = tostring(data.AttachmentData.attachment):gsub('(.*).*_', '')
    QBCore.Functions.TriggerCallback('weapons:server:RemoveAttachment', function(NewAttachments)
        if component then
            RemoveWeaponComponentFromPed(ped, joaat(data.WeaponData.name), joaat(component))
        end
        if NewAttachments == false then return cb({}) end
        local attachments = {}
        for _, v in pairs(NewAttachments or {}) do
            local shared = QBCore.Shared.Items[v.item]
            attachments[#attachments + 1] = { attachment = v.item, label = v.label, image = shared and shared.image, component = v.component }
        end
        cb({ Attachments = attachments, WeaponData = WeaponData })
    end, data.AttachmentData, data.WeaponData)
end)

RegisterNUICallback('getCombineItem', function(data, cb)
    cb(QBCore.Shared.Items[data.item])
end)

RegisterNUICallback('CloseInventory', function(_, cb)
    cb('ok')
    if not inInventory then return end
    inInventory = false
    SetNuiFocus(false, false)
    SetBlur(false)
    if activeAnim then
        StopAnim(activeAnim)
        activeAnim = nil
    end
    CloseTrunkDoor()
    TriggerServerEvent('inventory:server:SaveInventory')
    CurrentVehicle, CurrentGlovebox, CurrentStash = nil, nil, nil
end)

RegisterNUICallback('UseItem', function(data, cb)
    TriggerServerEvent('inventory:server:UseItem', data.inventory, data.item)
    cb('ok')
end)

RegisterNUICallback('combineItem', function(data, cb)
    TriggerServerEvent('inventory:server:combineItem', data.reward, data.fromItem, data.toItem)
    cb('ok')
end)

RegisterNUICallback('combineWithAnim', function(data, cb)
    cb('ok')
    local combine = type(data.combineData) == 'table' and data.combineData or {}
    local anim = combine.anim or {}
    local ped = PlayerPedId()
    QBCore.Functions.Progressbar('combine_anim', anim.text or '', tonumber(anim.timeOut) or 3000, false, true, {
        disableMovement = false,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {
        animDict = anim.dict,
        anim = anim.lib,
        flags = 16,
    }, {}, {}, function()
        if anim.dict then StopAnimTask(ped, anim.dict, anim.lib, 1.0) end
        TriggerServerEvent('inventory:server:combineItem', combine.reward, data.requiredItem, data.usedItem)
    end, function()
        if anim.dict then StopAnimTask(ped, anim.dict, anim.lib, 1.0) end
        QBCore.Functions.Notify(Lang:t('notify.failed'), 'error')
    end)
end)

RegisterNUICallback('SetInventoryData', function(data, cb)
    TriggerServerEvent('inventory:server:SetInventoryData', data.fromInventory, data.toInventory, data.fromSlot, data.toSlot, data.fromAmount, data.toAmount)
    cb('ok')
end)

RegisterNUICallback('PlayDropSound', function(_, cb)
    PlaySoundFrontend(-1, 'CLICK_BACK', 'WEB_NAVIGATION_SOUNDS_PHONE', true)
    cb('ok')
end)

RegisterNUICallback('PlayDropFail', function(_, cb)
    PlaySoundFrontend(-1, 'Place_Prop_Fail', 'DLC_Dmod_Prop_Editor_Sounds', true)
    cb('ok')
end)

-- Nearby players for the "Give" window
RegisterNUICallback('GetNearbyPlayers', function(_, cb)
    QBCore.Functions.TriggerCallback('qb-inventory:server:GetClosestPlayer', function(list)
        cb(list or {})
    end)
end)

RegisterNUICallback('GiveItemTo', function(data, cb)
    if type(data) == 'table' and type(data.item) == 'table' then
        TriggerServerEvent('inventory:server:GiveItem', {
            playerId = tonumber(data.playerId),
            name = data.item.name,
            slot = data.item.slot,
            amount = tonumber(data.amount) or 0,
        })
    end
    cb('ok')
end)

-- Old flow (kept): returns the nearby players, the UI shows the list
RegisterNUICallback('GiveItem', function(_, cb)
    QBCore.Functions.TriggerCallback('qb-inventory:server:GetClosestPlayer', function(list)
        cb(list or {})
    end)
end)

--#endregion

--#region Trash bins

CreateThread(function()
    if not Config.EnableTrash then return end
    Wait(2000)
    if GetResourceState('interact') == 'started' then
        for k, model in ipairs(Config.TrashModels) do
            exports.interact:AddModelInteraction({
                model = model,
                offset = vec3(0.0, 0.0, 0.5),
                id = 'Trash' .. k,
                distance = 3.5,
                interactDst = 1.5,
                ignoreLos = false,
                options = { { label = Lang:t('menu.trash'), event = 'inventory:client:OpenTrash' } },
            })
        end
    elseif Config.UseTarget and GetResourceState('qb-target') == 'started' then
        exports['qb-target']:AddTargetModel(Config.TrashModels, {
            options = { { icon = 'fas fa-trash', label = Lang:t('menu.trash'), event = 'inventory:client:OpenTrash' } },
            distance = 1.5,
        })
    end
end)

--#endregion
