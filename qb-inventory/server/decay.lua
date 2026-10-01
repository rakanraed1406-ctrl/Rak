local QBCore = exports['qb-core']:GetCoreObject()
local DAY = 60 * 60 * 24 -- the item "decay" value in qb-core/shared/items.lua is the number of days an item lasts

---Quality (0-100) an item has left based on when it was created
function ConvertQuality(item)
    local itemInfo = item and item.name and QBCore.Shared.Items[item.name:lower()]
    local decay = itemInfo and tonumber(itemInfo.decay) or 0
    if decay <= 0 or not tonumber(item.created) then return 100 end
    local lifetime = DAY * decay
    local percent = 100 - math.ceil(((os.time() - item.created) / lifetime) * 100)
    return math.max(0, math.min(100, percent))
end

---Updates info.quality of every item that decays (in place, server memory only)
function ApplyDecay(items)
    if type(items) ~= 'table' then return items end
    for _, item in pairs(items) do
        local itemInfo = type(item) == 'table' and item.name and QBCore.Shared.Items[item.name:lower()]
        if itemInfo and tonumber(itemInfo.decay) and tonumber(itemInfo.decay) > 0 and item.created then
            if type(item.info) ~= 'table' then item.info = {} end
            local quality = ConvertQuality(item)
            if not item.info.quality or quality < item.info.quality then
                item.info.quality = quality
            end
        end
    end
    return items
end

-- Kept for compatibility. The client can no longer send an inventory to be saved:
-- the answer is built only from what the server already has.
QBCore.Functions.CreateCallback('inventory:server:ConvertQuality', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb({ inventory = {} }) end
    cb({ inventory = ApplyDecay(Player.PlayerData.items) })
end)
