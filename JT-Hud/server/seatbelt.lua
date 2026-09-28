
local QBCore = exports['qb-core']:GetCoreObject()

-- ════════════════════════════════════════════════════════════
--              HARNESS USABLE ITEM
-- ════════════════════════════════════════════════════════════

QBCore.Functions.CreateUseableItem("harness", function(source, item)
    TriggerClientEvent("seatbelt:client:UseHarness", source, item)
end)

-- ════════════════════════════════════════════════════════════
--              HARNESS EVENTS
-- ════════════════════════════════════════════════════════════

RegisterNetEvent('equip:harness', function(item)
    -- Triggered when player attaches harness. Can be used for logging or syncing.
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    TriggerClientEvent('QBCore:Notify', src, 'Race harness attached!', 'success', 1500)
end)

RegisterNetEvent('seatbelt:DoHarnessDamage', function(hp, item)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not item or not item.slot then return end
    
    local slot = item.slot
    local currentItem = Player.Functions.GetItemBySlot(slot)
    if not currentItem then return end
    
    local newHp = tonumber(hp) or 0
    if newHp <= 0 then
        Player.Functions.RemoveItem('harness', 1, slot)
        TriggerClientEvent('QBCore:Notify', src, 'Your race harness snapped!', 'error')
    else
        currentItem.info.uses = newHp
        Player.Functions.SetItemData(item.name, slot, currentItem)
    end
end)
