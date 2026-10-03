local QBCore = exports['qb-core']:GetCoreObject()

-- This file is a leftover copy of qb-weapons server code. `Lang` belongs to qb-weapons and
-- does not exist in this resource: fall back to returning the key so these callbacks can't crash.
local Lang = Lang or { t = function(_, key) return key end }

-- Functions

local function IsWeaponBlocked(WeaponName)
    for _, name in pairs(Config.DurabilityBlockedWeapons) do
        if name == WeaponName then
            return true
        end
    end
    return false
end

local function HasAttachment(component, attachments)
    for k, v in pairs(attachments) do
        if v.component == component then
            return true, k
        end
    end
    return false, nil
end

local function GetAttachmentType(attachments)
    local attype = nil
    for _, v in pairs(attachments) do
        attype = v.type
    end
    return attype
end

-- Callback

QBCore.Functions.CreateCallback("weapons:server:GetConfig", function(_, cb)
    cb(Config.WeaponRepairPoints)
end)

QBCore.Functions.CreateCallback("weapon:server:GetWeaponAmmo", function(source, cb, WeaponData)
    local Player = QBCore.Functions.GetPlayer(source)
    local retval = 0
    if WeaponData and Player then
        local ItemData = Player.Functions.GetItemBySlot(WeaponData.slot)
        if ItemData then
            retval = ItemData.info.ammo and ItemData.info.ammo or 0
        end
    end
    cb(retval, WeaponData.name)
end)

QBCore.Functions.CreateCallback('weapons:server:RemoveAttachment', function(source, cb, AttachmentData, ItemData)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local Inventory = Player.PlayerData.items
    local AttachmentComponent = WeaponAttachments[ItemData.name:upper()][AttachmentData.attachment]

    if Inventory[ItemData.slot] and Inventory[ItemData.slot].info.attachments and next(Inventory[ItemData.slot].info.attachments) then
        local HasAttach, key = HasAttachment(AttachmentComponent.component, Inventory[ItemData.slot].info.attachments)
        if HasAttach then
            table.remove(Inventory[ItemData.slot].info.attachments, key)
            Player.Functions.SetInventory(Player.PlayerData.items, true)
            Player.Functions.AddItem(AttachmentComponent.item, 1)
            TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[AttachmentComponent.item], "add")
            TriggerClientEvent("QBCore:Notify", src, Lang:t('info.removed_attachment', { value = QBCore.Shared.Items[AttachmentComponent.item].label }), "error")
            cb(Inventory[ItemData.slot].info.attachments)
        else
            cb(false)
        end
    else
        cb(false)
    end
end)

QBCore.Functions.CreateCallback("weapons:server:RepairWeapon", function(source, cb, RepairPoint, data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local minute = 60 * 1000
    local Timeout = math.random(5 * minute, 10 * minute)
    local WeaponData = QBCore.Shared.Weapons[GetHashKey(data.name)]
    local WeaponClass = (QBCore.Shared.SplitStr(WeaponData.ammotype, "_")[2]):lower()

    local ItemSlot = Player.PlayerData.items[data.slot]

    if not ItemSlot then
        TriggerClientEvent('QBCore:Notify', src, Lang:t('error.no_weapon_in_hand'), "error")
        TriggerClientEvent('weapons:client:SetCurrentWeapon', src, {}, false)
        return cb(false)
    end

    if not ItemSlot.info.quality or ItemSlot.info.quality == 100 then
        TriggerClientEvent("QBCore:Notify", src, Lang:t('error.no_damage_on_weapon'), "error")
        return cb(false)
    end

    if not Player.Functions.RemoveMoney('cash', Config.WeaponRepairCosts[WeaponClass]) then
        return cb(false)
    end

    Config.WeaponRepairPoints[RepairPoint].IsRepairing = true
    Config.WeaponRepairPoints[RepairPoint].RepairingData = {
        CitizenId = Player.PlayerData.citizenid,
        WeaponData = ItemSlot,
        Ready = false,
    }
    Player.Functions.RemoveItem(data.name, 1, data.slot)
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[data.name], "remove")
    TriggerClientEvent("inventory:client:CheckWeapon", src, data.name)
    TriggerClientEvent('weapons:client:SyncRepairShops', -1, Config.WeaponRepairPoints[RepairPoint], RepairPoint)

    SetTimeout(Timeout, function()
        Config.WeaponRepairPoints[RepairPoint].IsRepairing = false
        Config.WeaponRepairPoints[RepairPoint].RepairingData.Ready = true
        TriggerClientEvent('weapons:client:SyncRepairShops', -1, Config.WeaponRepairPoints[RepairPoint], RepairPoint)
        TriggerEvent('qb-phone:server:sendNewMailToOffline', Player.PlayerData.citizenid, {
            sender = Lang:t('mail.sender'),
            subject = Lang:t('mail.subject'),
            message = Lang:t('mail.message', { value = WeaponData.label })
        })
        SetTimeout(7 * 60000, function()
            if Config.WeaponRepairPoints[RepairPoint].RepairingData.Ready then
                Config.WeaponRepairPoints[RepairPoint].IsRepairing = false
                Config.WeaponRepairPoints[RepairPoint].RepairingData = {}
                TriggerClientEvent('weapons:client:SyncRepairShops', -1, Config.WeaponRepairPoints[RepairPoint], RepairPoint)
            end
        end)
    end)

    cb(true)
end)

-- الأسلحة القابلة للرمي المدعومة (كانت سلسلة if/elseif مكررة)
local ThrowableItems = {
    weapon_snowball = true,
    weapon_pipebomb = true,
    weapon_molotov = true,
    weapon_stickybomb = true,
    weapon_grenade = true,
    weapon_bzgas = true,
    weapon_proxmine = true,
    weapon_ball = true,
    weapon_smokegrenade = true,
    weapon_flare = true,
}

QBCore.Functions.CreateCallback('prison:server:checkThrowable', function(source, cb, weapon)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb(false) end

    local weaponName = QBCore.Shared.Weapons[weapon] and QBCore.Shared.Weapons[weapon]["name"]
    if weaponName and ThrowableItems[weaponName] then
        Player.Functions.RemoveItem(weaponName, 1)
        return cb(true)
    end

    cb(false)
end)

-- Events

RegisterNetEvent("weapons:server:UpdateWeaponAmmo", function(CurrentWeaponData, amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Player and CurrentWeaponData then
        amount = tonumber(amount)
        if Player.PlayerData.items[CurrentWeaponData.slot] then
            Player.PlayerData.items[CurrentWeaponData.slot].info.ammo = amount
        end
        Player.Functions.SetInventory(Player.PlayerData.items, true)
    end
end)

RegisterNetEvent("weapons:server:TakeBackWeapon", function(k)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local itemdata = Config.WeaponRepairPoints[k].RepairingData.WeaponData
    itemdata.info.quality = 100
    Player.Functions.AddItem(itemdata.name, 1, false, itemdata.info)
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[itemdata.name], "add")
    Config.WeaponRepairPoints[k].IsRepairing = false
    Config.WeaponRepairPoints[k].RepairingData = {}
    TriggerClientEvent('weapons:client:SyncRepairShops', -1, Config.WeaponRepairPoints[k], k)
end)

RegisterNetEvent("weapons:server:SetWeaponQuality", function(data, hp)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local WeaponSlot = Player.PlayerData.items[data.slot]
    WeaponSlot.info.quality = hp
    Player.Functions.SetInventory(Player.PlayerData.items, true)
end)

RegisterNetEvent('weapons:server:UpdateWeaponQuality', function(data, RepeatAmount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local WeaponData = QBCore.Shared.Weapons[GetHashKey(data.name)]
    if not WeaponData then return end

    local WeaponSlot = Player.PlayerData.items[data.slot]
    local DecreaseAmount = Config.DurabilityMultiplier[data.name]

    if WeaponSlot and not IsWeaponBlocked(WeaponData.name) then
        WeaponSlot.info.quality = WeaponSlot.info.quality or 100

        for _ = 1, RepeatAmount, 1 do
            if WeaponSlot.info.quality - DecreaseAmount > 0 then
                WeaponSlot.info.quality = WeaponSlot.info.quality - DecreaseAmount
            else
                WeaponSlot.info.quality = 0
                TriggerClientEvent('inventory:client:UseWeapon', src, data, false)
                -- TriggerClientEvent('QBCore:Notify', src, Lang:t('error.weapon_broken_need_repair'), "error")
                break
            end
        end
    end

    Player.Functions.SetInventory(Player.PlayerData.items, true)
end)

RegisterNetEvent("weapons:server:EquipAttachment", function(ItemData, CurrentWeaponData, AttachmentData)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local Inventory = Player.PlayerData.items
    local GiveBackItem = nil
    local Slot = Inventory[CurrentWeaponData.slot]

    if not Slot then return end

    if Slot.info.attachments and next(Slot.info.attachments) then
        local currenttype = GetAttachmentType(Slot.info.attachments)
        local HasAttach, key = HasAttachment(AttachmentData.component, Slot.info.attachments)

        if HasAttach then
            TriggerClientEvent("QBCore:Notify", src, Lang:t('error.attachment_already_on_weapon', { value = QBCore.Shared.Items[AttachmentData.item].label }), "error", 3500)
            return
        end

        if AttachmentData.type ~= nil and currenttype == AttachmentData.type then
            for _, v in pairs(Slot.info.attachments) do
                if v.type and v.type == currenttype then
                    GiveBackItem = tostring(v.item):lower()
                    table.remove(Slot.info.attachments, key)
                    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[GiveBackItem], "add")
                end
            end
        end
    else
        Slot.info.attachments = {}
    end

    Slot.info.attachments[#Slot.info.attachments + 1] = {
        component = AttachmentData.component,
        label = QBCore.Shared.Items[AttachmentData.item].label,
        item = AttachmentData.item,
        type = AttachmentData.type,
    }

    TriggerClientEvent("addAttachment", src, AttachmentData.component)
    Player.Functions.SetInventory(Player.PlayerData.items, true)
    Player.Functions.RemoveItem(ItemData.name, 1)

    SetTimeout(1000, function()
        TriggerClientEvent('inventory:client:ItemBox', src, ItemData, "remove")
    end)

    if GiveBackItem then
        Player.Functions.AddItem(GiveBackItem, 1, false)
    end
end)

RegisterNetEvent('weapons:server:removeWeaponAmmoItem', function(item)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player or type(item) ~= 'table' or not item.name or not item.slot then return end
    Player.Functions.RemoveItem(item.name, 1, item.slot)
end)
