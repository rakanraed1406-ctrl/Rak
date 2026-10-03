--[[ client.lua — Jinxed Town Military Logistics

     Open from anywhere (interact, qb-target, ox_target, a key…):
         event = 'jt-logistics:open'                    -- the event name alone: the nearest shop you can open
         TriggerEvent('jt-logistics:open', 'cia')       -- or a specific shop
         exports['JT-MilitaryArmory']:Open('cia')
     Supply officer (the player has to be next to him; the server checks):
         event = 'jt-logistics:supplies'                -- receive weapons / items
         event = 'jt-logistics:store'                   -- store fleet vehicles parked nearby
     The shop can also come as { shop = 'cia' } / { args = 'cia' } (target option data).

     Fleet = garage: the display vehicle (locked, frozen) stands on its spot
     only while at least one unit is in the garage. Take units out from it
     with qb-target (the last one out → the display goes); bring them back by
     parking near the supply officer → "Store the vehicle" → it shows again.

     Idle cost: one distance check every 2 s. The display vehicles and NPCs
     only exist while you are near a shop; the NUI does nothing while closed. ]]

-- config.lua failed to load (a typo stops the whole file): say so once, clearly, instead of
-- erroring all over the place. Common one: vector4 needs exactly 4 numbers → vector4(x, y, z, heading)
if type(Config) ~= 'table' or type(Config.Shops) ~= 'table' or type(Config.Lang) ~= 'table' then
    print(('^1[%s] config.lua did not load — fix the error printed above it (check the commas in vector3 / vector4) and restart.^0'):format(GetCurrentResourceName()))
    return
end

local QBCore = exports['qb-core']:GetCoreObject()
local L = Config.Lang

local PlayerData = {}
local isOpen, openShop, introShown = false, nil, false
local pickup = nil            -- { shop, kind, pid } while the pickup / store dialog is open
local depot = {}              -- [shopId] = { [pid] = { g = in the garage, o = out } } (from the server)
local displays = {}           -- ["shop|pid"] = { veh } (local display vehicles)
local peds = {}               -- ["shop|kind"] = ped
local areas = {}              -- [shopId] = { center, radius }

-- ---------------------------------------------------------------------------
-- Player data (cached: qb-target calls canInteract a lot)
-- ---------------------------------------------------------------------------
local permCache = {}          -- [shopId] = { [action] = bool }, cleared whenever the player data changes
local function refreshPlayer() PlayerData = QBCore.Functions.GetPlayerData() or {} permCache = {} end
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function() refreshPlayer() end)
RegisterNetEvent('QBCore:Client:OnPlayerUnload', function() PlayerData = {} permCache = {} end)
RegisterNetEvent('QBCore:Player:SetPlayerData', function(pd) if type(pd) == 'table' then PlayerData = pd permCache = {} end end)
RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job) PlayerData.job = job permCache = {} end)
RegisterNetEvent('QBCore:Client:OnGangUpdate', function(gang) PlayerData.gang = gang permCache = {} end)

local function matches(rule)
    if type(rule) ~= 'table' or not PlayerData.citizenid then return false end
    if rule.citizenids and rule.citizenids[PlayerData.citizenid] then return true end
    local job = PlayerData.job
    if rule.jobs and job then
        local min = rule.jobs[job.name]
        local grade = job.grade and (job.grade.level or job.grade) or 0
        if min and (tonumber(grade) or 0) >= min and (not rule.onDuty or job.onduty) then return true end
    end
    local gang = PlayerData.gang
    if rule.gangs and gang then
        local min = rule.gangs[gang.name]
        local grade = gang.grade and (gang.grade.level or gang.grade) or 0
        if min and (tonumber(grade) or 0) >= min then return true end
    end
    return false
end

-- (only decides what the player sees; the server checks again)
local permCacheAt = 0
local function can(shopId, action)
    local now = GetGameTimer()
    if now - permCacheAt > 2000 then permCache, permCacheAt = {}, now end -- also expires on its own (framework forks)
    local cache = permCache[shopId]
    if not cache then cache = {} permCache[shopId] = cache end
    local key = action or 'open'
    local v = cache[key]
    if v == nil then
        local shop = Config.Shops[shopId]
        if not shop or not matches(shop.access) then v = false
        else
            local rule = action and shop.permissions and shop.permissions[action]
            v = rule == nil or matches(rule)
        end
        cache[key] = v
    end
    return v
end

-- Which shop an event / export means: 'cia', { shop = 'cia' } (qb-target / ox_target
-- option), { args = 'cia' } or { args = { shop = 'cia' } } (interact). nil = none given,
-- false = one was given but it isn't a shop.
local function shopArg(...)
    for i = 1, select('#', ...) do
        local v = select(i, ...)
        if type(v) == 'table' then
            v = v.shop or v.shopId or (type(v.args) == 'table' and (v.args.shop or v.args.shopId)) or v.args
        end
        if type(v) == 'string' then
            local shop = Config.Shops[v]
            return shop and shop.enabled ~= false and v or false
        end
    end
    return nil
end

-- no shop given: the nearest one the player can open (officer = by the supply officer)
local function nearestShop(officer)
    local pos = GetEntityCoords(PlayerPedId())
    local best, bestDist = nil, math.huge
    for id, shop in pairs(Config.Shops) do
        if shop.enabled ~= false and can(id) then
            local pts = officer and { shop.itemPed and shop.itemPed.coords }
                or { shop.openPed and shop.openPed.coords, shop.terminal and shop.terminal.coords, shop.itemPed and shop.itemPed.coords,
                     areas[id] and areas[id].center }
            local d = 1e9 -- a shop with no position still counts when it is the only one
            for _, c in pairs(pts) do d = math.min(d, #(pos - vector3(c.x, c.y, c.z))) end
            if not (officer and next(pts) == nil) and d < bestDist then best, bestDist = id, d end
        end
    end
    return best
end

local function resolveShop(officer, ...)
    local id = shopArg(...)
    if id == nil then id = nearestShop(officer) end
    return id or nil
end

-- ---------------------------------------------------------------------------
-- NUI
-- ---------------------------------------------------------------------------
local function open(...)
    if isOpen then return end
    local shopId = resolveShop(false, ...)
    if not shopId then return end
    QBCore.Functions.TriggerCallback('jt-logistics:server:open', function(data)
        if not data or isOpen then return end
        isOpen, openShop = true, shopId
        local intro = Config.IntroEveryOpen or not introShown
        introShown = true
        SetNuiFocus(true, true)
        SendNUIMessage({ action = 'open', data = data, intro = intro, introSeconds = Config.IntroSeconds or 3 })
    end, shopId)
end

RegisterNetEvent('jt-logistics:open', open)
exports('Open', open)

local function close()
    if not isOpen then return end
    isOpen, openShop, pickup = false, nil, nil
    SetNuiFocus(false, false)
    TriggerServerEvent('jt-logistics:server:close')
end

RegisterNUICallback('close', function(_, cb)
    close()
    cb('ok')
end)

RegisterNetEvent('jt-logistics:client:update', function(shopId, data)
    if isOpen and openShop == shopId and type(data) == 'table' then
        SendNUIMessage({ action = 'update', data = data })
    end
end)

RegisterNUICallback('checkout', function(data, cb)
    if not openShop or type(data) ~= 'table' then return cb({ ok = false }) end
    QBCore.Functions.TriggerCallback('jt-logistics:server:checkout', function(res) cb(res or { ok = false }) end, openShop, data.cart)
end)

RegisterNUICallback('deposit', function(data, cb)
    if not openShop or type(data) ~= 'table' then return cb({ ok = false }) end
    QBCore.Functions.TriggerCallback('jt-logistics:server:deposit', function(res) cb(res or { ok = false }) end, openShop, data.amount, data.from)
end)

-- "LOCATE" in the depot list → waypoint to where it is picked up
RegisterNUICallback('locate', function(data, cb)
    cb('ok')
    local shop = openShop and Config.Shops[openShop]
    if not shop or type(data) ~= 'table' then return end
    local target
    for _, p in ipairs(shop.products or {}) do
        if p.id == data.id then target = p.type == 'vehicle' and p.display or (shop.itemPed and shop.itemPed.coords) end
    end
    if target then
        SetNewWaypoint(target.x, target.y)
        QBCore.Functions.Notify('GPS', 'primary', 2000)
    end
end)

-- ---------------------------------------------------------------------------
-- Pickup dialog (from the display vehicle / the NPC)
-- ---------------------------------------------------------------------------
local function openPickup(shopId, kind, pid)
    if isOpen then return end
    QBCore.Functions.TriggerCallback('jt-logistics:server:pickupInfo', function(data)
        if not data or isOpen then return end
        isOpen, openShop, pickup = true, shopId, { shop = shopId, kind = kind, pid = pid }
        SetNuiFocus(true, true)
        SendNUIMessage({ action = 'pickup', data = data })
    end, shopId, kind, pid)
end

-- the supply officer: which fleet vehicles are parked around him
local function openStore(...)
    if isOpen then return end
    local shopId = resolveShop(true, ...)
    if not shopId then return end
    QBCore.Functions.TriggerCallback('jt-logistics:server:storeInfo', function(data)
        if not data or isOpen then return end
        isOpen, openShop, pickup = true, shopId, { shop = shopId, kind = 'store' }
        SetNuiFocus(true, true)
        SendNUIMessage({ action = 'pickup', data = data })
    end, shopId)
end

local function openSupplies(...)
    local shopId = resolveShop(true, ...)
    if shopId then openPickup(shopId, 'items') end
end

RegisterNetEvent('jt-logistics:supplies', openSupplies)
RegisterNetEvent('jt-logistics:store', openStore)
exports('OpenSupplies', openSupplies)
exports('OpenStore', openStore)

RegisterNUICallback('pickupConfirm', function(data, cb)
    local p = pickup
    if not p or type(data) ~= 'table' then return cb({ ok = false }) end
    if p.kind == 'store' then
        if type(data.ids) ~= 'table' then return cb({ ok = false }) end
        return QBCore.Functions.TriggerCallback('jt-logistics:server:storeVehicles', function(res) cb(res or { ok = false }) end, p.shop, data.ids)
    end
    if type(data.amounts) ~= 'table' then return cb({ ok = false }) end
    if p.kind == 'vehicle' then
        QBCore.Functions.TriggerCallback('jt-logistics:server:takeVehicles', function(res) cb(res or { ok = false }) end, p.shop, p.pid, data.amounts[p.pid])
    else
        QBCore.Functions.TriggerCallback('jt-logistics:server:takeItems', function(res) cb(res or { ok = false }) end, p.shop, data.amounts)
    end
end)

local function setFuel(veh)
    local res = Config.FuelResource
    if res and res ~= '' and GetResourceState(res) == 'started' then
        if pcall(function() exports[res]:SetFuel(veh, 100.0) end) then return end
    end
    SetVehicleFuelLevel(veh, 100.0)
end

-- the server spawned them on the pads: plate, fuel, keys
RegisterNetEvent('jt-logistics:client:tookVehicles', function(list)
    if type(list) ~= 'table' then return end
    for _, v in ipairs(list) do
        CreateThread(function()
            local timeout = GetGameTimer() + 10000
            while not NetworkDoesNetworkIdExist(v.netId) do
                if GetGameTimer() > timeout then return end
                Wait(50)
            end
            local veh = NetToVeh(v.netId)
            while not DoesEntityExist(veh) do
                if GetGameTimer() > timeout then return end
                Wait(50)
                veh = NetToVeh(v.netId)
            end
            local ctl = GetGameTimer() + 1500
            while not NetworkHasControlOfEntity(veh) and GetGameTimer() < ctl do
                NetworkRequestControlOfEntity(veh)
                Wait(50)
            end
            SetVehicleNumberPlateText(veh, v.plate)
            SetVehicleDirtLevel(veh, 0.0)
            setFuel(veh)
            if Config.GiveKeys then Config.GiveKeys(veh, v.plate) end -- normally the server gives them (Config.Keys)
        end)
    end
end)

-- For client-side anti-cheats / blacklists: the local display vehicles and the
-- fleet vehicles (that list is GlobalState: only the server can write it).
--     if exports['JT-MilitaryArmory']:IsLogisticsVehicle(veh) then return end
local displayOf -- set below
exports('IsLogisticsVehicle', function(entity)
    if type(entity) ~= 'number' or entity == 0 then return false end
    if displayOf(entity) then return true end
    if not NetworkGetEntityIsNetworked(entity) then return false end
    local fleet = GlobalState.jtLogisticsFleet
    return type(fleet) == 'table' and fleet[tostring(NetworkGetNetworkIdFromEntity(entity))] ~= nil
end)

-- ---------------------------------------------------------------------------
-- Display vehicles + NPCs (local, only near the shop)
-- ---------------------------------------------------------------------------
local function hasTarget() return GetResourceState('qb-target') == 'started' end

-- units in the garage (the display stands only while there is one)
local function inGarage(f)
    return type(f) == 'table' and tonumber(f.g) or 0
end

local anyOut = {}             -- [shopId] = true when some fleet vehicle is out (from the fleet updates)
local function fleetOut(shopId) return anyOut[shopId] == true end

local function setFleet(shopId, fleet)
    depot[shopId] = fleet
    local out = false
    for _, f in pairs(fleet) do
        if type(f) == 'table' and (tonumber(f.o) or 0) > 0 then out = true break end
    end
    anyOut[shopId] = out
end

local function loadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) then return nil end
    RequestModel(hash)
    local timeout = GetGameTimer() + 10000
    while not HasModelLoaded(hash) do
        if GetGameTimer() > timeout then return nil end
        Wait(20)
    end
    return hash
end

function displayOf(entity)
    for _, d in pairs(displays) do if d.veh == entity then return true end end
    return false
end

local function removeDisplay(key)
    local d = displays[key]
    if not d then return end
    displays[key] = nil
    if d.veh and DoesEntityExist(d.veh) then
        if hasTarget() then exports['qb-target']:RemoveTargetEntity(d.veh) end
        SetEntityAsMissionEntity(d.veh, true, true)
        DeleteVehicle(d.veh)
    end
end

local function spawnDisplay(shopId, p)
    local key = shopId .. '|' .. p.id
    if displays[key] then return end
    local entry = {}
    displays[key] = entry -- placeholder while the model loads
    local hash = loadModel(p.model)
    if not hash or displays[key] ~= entry then return end
    local c = p.display
    local veh = CreateVehicle(hash, c.x, c.y, c.z, c.w or 0.0, false, false)
    SetModelAsNoLongerNeeded(hash)
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleOnGroundProperly(veh)
    FreezeEntityPosition(veh, true)
    SetEntityInvincible(veh, true)
    SetEntityCanBeDamaged(veh, false)
    SetVehicleDoorsLocked(veh, 2)
    SetVehicleDirtLevel(veh, 0.0)
    SetVehicleNumberPlateText(veh, 'GARAGE')
    SetVehicleEngineOn(veh, false, true, true)
    entry.veh = veh
    if hasTarget() then
        exports['qb-target']:AddTargetEntity(veh, {
            options = { {
                icon = 'fas fa-warehouse',
                label = ('Garage — %s'):format(p.label or p.model),
                action = function() openPickup(shopId, 'vehicle', p.id) end,
                canInteract = function() return can(shopId, 'pickup') end,
            } },
            distance = 6.0,
        })
    end
end

local function removePed(key)
    local ped = peds[key]
    if not ped then return end
    peds[key] = nil
    if DoesEntityExist(ped) then
        if hasTarget() then exports['qb-target']:RemoveTargetEntity(ped) end
        DeletePed(ped)
    end
end

local function spawnPed(shopId, kind, cfg)
    local key = shopId .. '|' .. kind
    local cur = peds[key]
    if cur and cur ~= 0 and not DoesEntityExist(cur) then peds[key], cur = nil, nil end -- deleted by something else
    if cur or not cfg then return end
    peds[key] = 0 -- placeholder
    local hash = loadModel(cfg.model)
    if not hash or peds[key] ~= 0 then return end
    local c = cfg.coords
    local ped = CreatePed(4, hash, c.x, c.y, c.z - 1.0, c.w or 0.0, false, true)
    SetModelAsNoLongerNeeded(hash)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    TaskStartScenarioInPlace(ped, kind == 'item' and 'WORLD_HUMAN_CLIPBOARD' or 'WORLD_HUMAN_GUARD_STAND', 0, true)
    peds[key] = ped
    if not hasTarget() then return end
    local options
    if kind == 'item' then
        options = {
            { icon = 'fas fa-box-open', label = cfg.label or 'Receive supplies',
                action = function() openPickup(shopId, 'items') end,
                canInteract = function() return can(shopId, 'pickup') end },
            { icon = 'fas fa-warehouse', label = cfg.storeLabel or 'Store the vehicle',
                action = function() openStore(shopId) end,
                canInteract = function()
                    return (fleetOut(shopId) or (Config.Fleet and Config.Fleet.StoreAnyOfModel)) and can(shopId, 'pickup')
                end },
        }
    else
        options = { { icon = 'fas fa-helicopter', label = cfg.label or 'Military Logistics',
            action = function() open(shopId) end,
            canInteract = function() return can(shopId) end } }
    end
    exports['qb-target']:AddTargetEntity(ped, { options = options, distance = 3.0 })
end

local function shopArea(shopId, shop)
    local pts = {}
    for _, p in ipairs(shop.products or {}) do if p.type == 'vehicle' and p.display then pts[#pts + 1] = p.display end end
    if shop.itemPed then pts[#pts + 1] = shop.itemPed.coords end
    if shop.openPed then pts[#pts + 1] = shop.openPed.coords end
    if #pts == 0 then return nil end
    local x, y, z = 0.0, 0.0, 0.0
    for _, c in ipairs(pts) do x, y, z = x + c.x, y + c.y, z + c.z end
    local center = vector3(x / #pts, y / #pts, z / #pts)
    local radius = 0.0
    for _, c in ipairs(pts) do radius = math.max(radius, #(center - vector3(c.x, c.y, c.z))) end
    -- everything the loop needs, made once (no strings / vectors built every second)
    local list = {}
    for _, p in ipairs(shop.products or {}) do
        if p.type == 'vehicle' and p.display then
            list[#list + 1] = { p = p, key = shopId .. '|' .. p.id, pos = vector3(p.display.x, p.display.y, p.display.z) }
        end
    end
    return { center = center, radius = radius, displays = list, pedKeys = { shopId .. '|open', shopId .. '|item' } }
end

local function clearShop(shopId)
    local area = areas[shopId]
    if not area then return end
    for _, d in ipairs(area.displays) do removeDisplay(d.key) end
    for _, key in ipairs(area.pedKeys) do removePed(key) end
end

CreateThread(function()
    for id, shop in pairs(Config.Shops) do
        if shop.enabled ~= false then areas[id] = shopArea(id, shop) end
    end
    Wait(1500)
    refreshPlayer()
    QBCore.Functions.TriggerCallback('jt-logistics:server:displays', function(all)
        if type(all) ~= 'table' then return end
        for id, fleet in pairs(all) do
            if type(fleet) == 'table' then setFleet(id, fleet) if areas[id] then areas[id].dirty = true end end
        end
    end)

    local range = Config.DisplayDistance or 120.0
    for _, area in pairs(areas) do area.reach = area.radius + range end
    while true do
        local sleep = 2500
        local pos = GetEntityCoords(PlayerPedId())
        local now = GetGameTimer()
        for id, area in pairs(areas) do
            if #(pos - area.center) <= area.reach then
                sleep = 1000
                local last = area.lastPos
                if area.dirty or not last or #(pos - last) > 6.0 or now - (area.lastCheck or 0) > 15000 then
                    area.dirty, area.lastPos, area.lastCheck = false, pos, now
                    local shop = Config.Shops[id]
                    spawnPed(id, 'open', shop.openPed)
                    spawnPed(id, 'item', shop.itemPed)
                    local fleet = depot[id] or {}
                    for _, d in ipairs(area.displays) do
                        local cur = displays[d.key]
                        if cur and cur.veh and not DoesEntityExist(cur.veh) then displays[d.key] = nil cur = nil end -- deleted by something else
                        -- only while there is one in the garage to take out
                        local want = inGarage(fleet[d.p.id]) > 0 and #(pos - d.pos) <= range
                        if want and not cur then spawnDisplay(id, d.p)
                        elseif not want and cur then removeDisplay(d.key) end
                    end
                    area.live = true
                end
            elseif area.live then
                area.live, area.lastPos = false, nil
                clearShop(id)
            end
        end
        Wait(sleep)
    end
end)

RegisterNetEvent('jt-logistics:client:displays', function(shopId, fleet)
    if type(shopId) ~= 'string' or type(fleet) ~= 'table' then return end
    setFleet(shopId, fleet)
    if areas[shopId] then areas[shopId].dirty = true end
    for pid, f in pairs(fleet) do
        if inGarage(f) < 1 then removeDisplay(shopId .. '|' .. pid) end -- every unit is out (or lost)
    end
end)

RegisterNetEvent('jt-logistics:client:coords', function()
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    local line = ('vector4(%.2f, %.2f, %.2f, %.1f)'):format(c.x, c.y, c.z, GetEntityHeading(ped))
    print(line)
    QBCore.Functions.Notify(line .. ' (F8)', 'primary', 8000)
end)

-- ---------------------------------------------------------------------------
-- Photo studio (/logisticsphotos, admin): every vehicle from the same angle,
-- same light, same framing (Config.Photo).
--   * the vehicle is turned so the camera stands on the sun side (lit, not in
--     its own shadow), with a soft fill light from the camera;
--   * four lossless shots: with / without the vehicle, over two flat backdrops
--     of equal brightness but different colour (green / magenta). From those
--     the NUI works out how see-through each pixel is (triangulation matting),
--     so edges, glass and rotor discs keep no trace of the backdrop colour;
--   * the server saves html/img/vehicles/<model>.webp. Restart the resource after.
-- ---------------------------------------------------------------------------
local STUDIO = vector3(-1800.0, -4800.0, 900.0) -- over the ocean, nothing around
local BACKDROPS = { { 0, 170, 0 }, { 255, 0, 255 } } -- about the same luminance → same exposure
local studio = nil
local photoWaits = {}

local function screenshot()
    local p, settled = promise.new(), false
    local function finish(v) if not settled then settled = true p:resolve(v) end end
    -- PNG: JPEG/WebP blur colour at the edges (chroma subsampling) and break the matte
    exports['screenshot-basic']:requestScreenshot({ encoding = 'png' }, finish)
    SetTimeout(15000, function() finish(nil) end)
    return Citizen.Await(p)
end

RegisterNUICallback('photoResult', function(data, cb)
    cb('ok')
    local p = type(data) == 'table' and photoWaits[data.id]
    if p then
        photoWaits[data.id] = nil
        p:resolve(data.image)
    end
end)

local function normalize(v) local l = #v return vector3(v.x / l, v.y / l, v.z / l) end
local function cross(a, b) return vector3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x) end

local function drawStudio()
    local s = studio
    local f = normalize(s.target - s.camPos)
    local r = normalize(cross(f, vector3(0.0, 0.0, 1.0)))
    local u = cross(r, f)
    local c = s.target + f * (s.radius * 3.0)
    local k = s.radius * 25.0
    local a, b = c + r * k + u * k, c - r * k + u * k
    local d, e = c - r * k - u * k, c + r * k - u * k
    local col = BACKDROPS[s.backdrop or 1]
    for _, t in ipairs({ { a, b, d }, { a, d, e }, { d, b, a }, { e, d, a } }) do -- both windings
        DrawPoly(t[1].x, t[1].y, t[1].z, t[2].x, t[2].y, t[2].z, t[3].x, t[3].y, t[3].z, col[1], col[2], col[3], 255)
    end
    if s.fill > 0 then -- soft light from just above the camera
        local l = s.camPos + u * (s.radius * 0.5)
        DrawLightWithRange(l.x, l.y, l.z, 255, 250, 240, s.dist * 2.0, s.fill)
    end
end

local function shoot(model, index)
    local cfg = Config.Photo or {}
    local hash = loadModel(model)
    if not hash or not IsModelAVehicle(hash) then return nil end
    local yaw, pitch = math.rad(cfg.yaw or 35.0), math.rad(cfg.pitch or 12.0)
    -- turn the vehicle so the camera ends up on the sun side (cfg.sun = where the sun is)
    local heading = ((cfg.sun or 180.0) - (cfg.yaw or 35.0)) % 360.0
    local veh = CreateVehicle(hash, STUDIO.x, STUDIO.y, STUDIO.z, heading, false, false)
    SetModelAsNoLongerNeeded(hash)
    FreezeEntityPosition(veh, true)
    SetEntityRotation(veh, 0.0, 0.0, heading, 2, true)
    SetVehicleDirtLevel(veh, 0.0)
    SetVehicleEngineOn(veh, false, true, true)
    SetVehicleLights(veh, 1)
    if IsThisModelAPlane(hash) then ControlLandingGear(veh, 0) end -- wheels down

    local min, max = GetModelDimensions(hash)
    local cx, cy, cz = (min.x + max.x) / 2, (min.y + max.y) / 2, (min.z + max.z) / 2
    local radius = #(max - min) / 2
    local fov = cfg.fov or 28.0
    local dist = radius / math.sin(math.rad(fov / 2)) * 1.02
    -- the same direction for every vehicle: yaw from the nose (+ = its left side), pitch above
    local dir = vector3(-math.sin(yaw) * math.cos(pitch), math.cos(yaw) * math.cos(pitch), math.sin(pitch))
    local target = GetOffsetFromEntityInWorldCoords(veh, cx, cy, cz)
    local camPos = GetOffsetFromEntityInWorldCoords(veh, cx + dir.x * dist, cy + dir.y * dist, cz + dir.z * dist)
    local cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', camPos.x, camPos.y, camPos.z, 0.0, 0.0, 0.0, fov, false, 0)
    PointCamAtCoord(cam, target.x, target.y, target.z)
    SetCamUseShallowDofMode(cam, false)
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, true)
    SetFocusPosAndVel(target.x, target.y, target.z, 0.0, 0.0, 0.0)
    studio.target, studio.camPos, studio.radius, studio.dist = target, camPos, radius, dist
    studio.fill = (cfg.fill or 1.0) * 1.5

    -- with the vehicle on both backdrops, then the empty backdrops (same order back)
    studio.backdrop = 1
    Wait(2200) -- textures / LODs / exposure
    local a1 = screenshot()
    studio.backdrop = 2
    Wait(900)
    local a2 = screenshot()
    SetEntityVisible(veh, false, false)
    Wait(700)
    local b2 = screenshot()
    studio.backdrop = 1
    Wait(900)
    local b1 = screenshot()

    SetEntityAsMissionEntity(veh, true, true)
    DeleteVehicle(veh)
    RenderScriptCams(false, false, 0, true, true)
    DestroyCam(cam, false)
    studio.target = nil
    if not (a1 and a2 and b1 and b2) then return nil end

    local p = promise.new()
    photoWaits[index] = p
    SendNUIMessage({ action = 'photoProcess', id = index, a1 = a1, a2 = a2, b1 = b1, b2 = b2 })
    SetTimeout(30000, function() if photoWaits[index] then photoWaits[index] = nil p:resolve(nil) end end)
    return Citizen.Await(p)
end

RegisterNetEvent('jt-logistics:client:photos', function(models, token)
    if studio or type(models) ~= 'table' then return end
    if GetResourceState('screenshot-basic') ~= 'started' then return QBCore.Functions.Notify(L.photos_missing, 'error', 8000) end
    if isOpen then close() SendNUIMessage({ action = 'hide' }) end
    studio = { on = true, fill = 0, backdrop = 1 }
    QBCore.Functions.Notify(L.photos_start:format(#models), 'primary', 6000)

    CreateThread(function()
        while studio do
            HideHudAndRadarThisFrame()
            if studio.target then drawStudio() end
            Wait(0)
        end
    end)

    local cfg = Config.Photo or {}
    NetworkOverrideClockTime(cfg.hour or 12, 0, 0)
    SetWeatherTypeNowPersist('EXTRASUNNY')
    ClearTimecycleModifier()
    ClearExtraTimecycleModifier()
    DisplayRadar(false)
    local done = 0
    for i, model in ipairs(models) do
        local image = shoot(model, i)
        if image then
            TriggerLatentServerEvent('jt-logistics:server:savePhoto', 300000, token, model, image)
            done = done + 1
        else
            print(('[logistics] photo failed: %s'):format(model))
        end
    end
    studio = nil
    ClearFocus()
    NetworkClearClockTimeOverride()
    ClearOverrideWeather()
    ClearWeatherTypePersist()
    DisplayRadar(true)
    QBCore.Functions.Notify(L.photos_done:format(done), 'success', 12000)
end)

RegisterNetEvent('jt-logistics:client:photoSaved', function(model, ok)
    print(('[logistics] photo %s: %s'):format(model, ok and 'saved' or 'rejected'))
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if isOpen then SetNuiFocus(false, false) end
    for key in pairs(displays) do removeDisplay(key) end
    for key in pairs(peds) do removePed(key) end
    if studio then
        RenderScriptCams(false, false, 0, true, true)
        ClearFocus()
        DisplayRadar(true)
    end
end)
