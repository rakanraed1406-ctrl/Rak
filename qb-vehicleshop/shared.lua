--[[ shared.lua — small helpers used by both the client and the server.
     The shop zones are checked with this instead of PolyZone: one plain
     point-in-polygon test, and only when the player is already close. ]]

VShared = {}

local function bounds(shape)
    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
    for i = 1, #shape do
        local p = shape[i]
        if p.x < minX then minX = p.x end
        if p.x > maxX then maxX = p.x end
        if p.y < minY then minY = p.y end
        if p.y > maxY then maxY = p.y end
    end
    return { minX = minX, minY = minY, maxX = maxX, maxY = maxY }
end

for _, shop in pairs(Config.Shops or {}) do
    local zone = shop.Zone
    if zone and zone.Shape and #zone.Shape >= 3 then zone.bounds = bounds(zone.Shape) end
end

function VShared.PointInPoly(x, y, poly)
    local inside = false
    local j = #poly
    for i = 1, #poly do
        local a, b = poly[i], poly[j]
        if ((a.y > y) ~= (b.y > y)) and (x < (b.x - a.x) * (y - a.y) / (b.y - a.y) + a.x) then
            inside = not inside
        end
        j = i
    end
    return inside
end

--- Is `pos` inside the shop polygon? `zPad` loosens minZ / maxZ.
function VShared.InShop(shopName, pos, zPad)
    local shop = Config.Shops[shopName]
    local zone = shop and shop.Zone
    local b = zone and zone.bounds
    if not b or not pos then return false end
    if pos.x < b.minX or pos.x > b.maxX or pos.y < b.minY or pos.y > b.maxY then return false end
    zPad = zPad or 0.0
    if zone.minZ and pos.z < zone.minZ - zPad then return false end
    if zone.maxZ and pos.z > zone.maxZ + zPad then return false end
    return VShared.PointInPoly(pos.x, pos.y, zone.Shape)
end

--- Is `model` sold in `shopName` according to qb-core shared vehicles?
function VShared.SoldInShop(vehicles, model, shopName)
    local v = type(model) == 'string' and vehicles[model]
    if not v then return false end
    if type(v.shop) == 'table' then
        for _, s in pairs(v.shop) do
            if s == shopName then return true end
        end
        return false
    end
    return v.shop == shopName
end

function VShared.Comma(amount)
    local s = tostring(math.floor(tonumber(amount) or 0))
    local sign, digits = s:match('^(-?)(%d+)$')
    if not digits then return s end
    return sign .. digits:reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', '')
end
