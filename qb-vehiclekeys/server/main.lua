-----------------------
----   Variables   ----
-----------------------
local QBCore = exports['qb-core']:GetCoreObject()
local VehicleList = {}

-----------------------
----   Threads     ----
-----------------------

-----------------------
----   Helpers     ----
-----------------------

local PulledOut = {} -- [netId] = { src = لاعب نزّل السواق, t = os.time() }

local function trimPlate(plate)
    if type(plate) ~= 'string' then return nil end
    plate = plate:gsub('^%s*(.-)%s*$', '%1')
    if plate == '' then return nil end
    return plate
end

local function vehiclePlate(veh)
    return trimPlate(GetVehicleNumberPlateText(veh))
end

local function vehicleFromNet(netId)
    netId = tonumber(netId)
    if not netId then return nil end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then return nil end
    return veh
end

local function distanceTo(src, entity)
    return #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(entity))
end

-- فيه سيارة بهاللوحة جنب اللاعب (أو هو راكبها)؟
local function sameHash(a, b)
    return (a & 0xFFFFFFFF) == (b & 0xFFFFFFFF)
end

-- مفاتيح الوظيفة (Config.SharedKeys) — نتحقق منها بالسيرفر مو بالكلاينت
local function jobSharedKeys(src, veh)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false end
    local job = Player.PlayerData.job
    local cfg = job and Config.SharedKeys[job.name]
    if not cfg or (cfg.requireOnduty and not job.onduty) then return false end
    local model = GetEntityModel(veh)
    for _, name in ipairs(cfg.vehicles) do
        if sameHash(joaat(name), model) then return true end
    end
    return false
end

local function isNoLockVehicle(veh)
    if Entity(veh).state.ignoreLocks then return true end
    local model = GetEntityModel(veh)
    for _, name in ipairs(Config.NoLockVehicles) do
        if sameHash(joaat(name), model) then return true end
    end
    return false
end

local function hasLockpick(src)
    if GetResourceState('ox_inventory') == 'started' then
        local ok, count = pcall(function()
            return exports.ox_inventory:Search(src, 'count', { 'lockpick', 'advancedlockpick' })
        end)
        if ok and type(count) == 'table' then return (count.lockpick or 0) + (count.advancedlockpick or 0) > 0 end
    end
    local Player = QBCore.Functions.GetPlayer(src)
    return Player ~= nil and (Player.Functions.GetItemByName('lockpick') ~= nil or Player.Functions.GetItemByName('advancedlockpick') ~= nil)
end

-- يقدر ياخذ مفتاح هذي اللوحة؟ (راكبها، أو جنب سيارة بوت/جثة، أو سيارة وظيفته)
local function canAcquireNear(src, plate)
    local ped = GetPlayerPed(src)
    local inVeh = GetVehiclePedIsIn(ped, false)
    if inVeh ~= 0 and vehiclePlate(inVeh) == plate then return true end

    local pos = GetEntityCoords(ped)
    for _, veh in ipairs(GetAllVehicles()) do
        if vehiclePlate(veh) == plate and #(GetEntityCoords(veh) - pos) <= 8.0 then
            local driver = GetPedInVehicleSeat(veh, -1)
            if driver ~= 0 and not IsPedAPlayer(driver) then return true end
            if jobSharedKeys(src, veh) then return true end
        end
    end
    return false
end

-- سجل محاولات الغش (Config.Security)
local strikes = {}
local function abuse(src, reason)
    local now = os.time()
    local st = strikes[src]
    if not st or now - st.since > 60 then st = { count = 0, since = now } strikes[src] = st end
    st.count = st.count + 1

    local ids = {}
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if id:find('^license:') or id:find('^discord:') then ids[#ids + 1] = id end
    end
    print(('^1[qb-vehiclekeys][anti-cheat]^7 %s (%d) %s — %s [%d/%d]'):format(
        GetPlayerName(src) or '?', src, reason, table.concat(ids, ' '), st.count, Config.Security.MaxStrikes))

    if Config.Security.KickOnAbuse and st.count >= Config.Security.MaxStrikes then
        DropPlayer(src, 'qb-vehiclekeys: محاولة غش')
    end
end

local lastCall = {}
local function rateLimited(src, key, ms)
    local k = src .. ':' .. key
    local now = GetGameTimer()
    if lastCall[k] and now - lastCall[k] < ms then return true end
    lastCall[k] = now
    return false
end

local function ownsVehicle(src, plate)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false end
    local ok, row = pcall(MySQL.scalar.await, 'SELECT 1 FROM player_vehicles WHERE plate = ? AND citizenid = ?', { plate, Player.PlayerData.citizenid })
    return ok and row ~= nil
end

-----------------------
---- Server Events ----
-----------------------

-- Event to give keys. receiver can either be a single id, or a table of ids.
RegisterNetEvent('qb-vehiclekeys:server:GiveVehicleKeys', function(receiver, plate)
    local giver = source
    plate = trimPlate(plate)
    if not plate then return end

    if HasKeys(giver, plate) then
        TriggerClientEvent('QBCore:Notify', giver, Lang:t("notify.vgkeys"), 'success')
        local list = type(receiver) == 'table' and receiver or { receiver }
        if #list > 8 then return abuse(giver, 'أعطى مفاتيح لقائمة كبيرة') end
        for _, r in ipairs(list) do
            r = tonumber(r)
            -- كان: GiveKeys(receiver[r]) → يعطي الشخص الغلط. والحين لازم يكون قريب
            if r and r ~= giver and GetPlayerPed(r) ~= 0 and #(GetEntityCoords(GetPlayerPed(giver)) - GetEntityCoords(GetPlayerPed(r))) <= 10.0 then
                GiveKeys(r, plate)
            end
        end
    else
        TriggerClientEvent('QBCore:Notify', giver, Lang:t("notify.ydhk"), "error")
    end
end)

-- كانت ثغرة: أي واحد يقدر يعطي نفسه مفتاح أي سيارة (حتى بس لو واقف جنبها).
-- الحين: السيارة حقه بالداتابيس، أو راكبها، أو جنب سيارة بوت/جثة بوت، أو سيارة وظيفته.
local acquirePending = {}
RegisterNetEvent('qb-vehiclekeys:server:AcquireVehicleKeys', function(plate)
    local src = source
    plate = trimPlate(plate)
    if not plate then return end
    if HasKeys(src, plate) then return TriggerClientEvent('qb-vehiclekeys:client:AddKeys', src, plate) end
    if acquirePending[src] then return end
    acquirePending[src] = true

    CreateThread(function()
        if ownsVehicle(src, plate) then
            acquirePending[src] = nil
            return GiveKeys(src, plate)
        end
        -- السيارة يمكن توها انسوت ولسا ما وصلت للسيرفر → نحاول كم مرة
        for _ = 1, 10 do
            if GetPlayerPed(src) == 0 then break end
            if canAcquireNear(src, plate) then
                acquirePending[src] = nil
                return GiveKeys(src, plate)
            end
            Wait(500)
        end
        acquirePending[src] = nil
        abuse(src, ('طلب مفتاح %s وهو مو راكبها'):format(plate))
    end)
end)

RegisterNetEvent('qb-vehiclekeys:server:breakLockpick', function(itemName)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    if not (itemName == "lockpick" or itemName == "advancedlockpick") then return end
    if Player.Functions.RemoveItem(itemName, 1) then
        TriggerClientEvent("inventory:client:ItemBox", source, QBCore.Shared.Items[itemName], "remove")
    end
end)

-- كانت ثغرة: أي واحد يفتح أي سيارة بالسيرفر. الحين لازم يكون جنبها
RegisterNetEvent('qb-vehiclekeys:server:setVehLockState', function(vehNetId, state)
    local src = source
    state = tonumber(state)
    if state ~= 1 and state ~= 2 then return end
    if rateLimited(src, 'lock', 300) then return end
    local veh = vehicleFromNet(vehNetId)
    if not veh or distanceTo(src, veh) > 10.0 then return end

    local plate = vehiclePlate(veh)
    local allowed = (plate and HasKeys(src, plate)) or jobSharedKeys(src, veh) or (state == 1 and isNoLockVehicle(veh))
    if not allowed and state == 1 then
        local driver = GetPedInVehicleSeat(veh, -1)
        if driver ~= 0 and not IsPedAPlayer(driver) then
            allowed = true                                    -- سيارة بوت (جثة السواق)
        elseif distanceTo(src, veh) <= 4.0 and hasLockpick(src) then
            allowed = true                                    -- قفال
        end
    end
    if not allowed then
        return abuse(src, ('حاول %s سيارة مو له (%s)'):format(state == 2 and 'يقفل' or 'يفتح', plate or '?'))
    end

    SetVehicleDoorsLocked(veh, state)
    -- حالة القفل للكل (محد يفتح الباب لو مقفلة حتى لو صار تأخير بالشبكة)
    Entity(veh).state:set('vehLocked', state == 2, true)
end)

-- قعدت سواق وما معك مفتاح → ياخذك المفتاح إذا:
--   1) الموتر شغال والأبواب مفتوحة
--   2) سيارة بوت طلعت مفتوحة (50/50) ونزّلت السواق
--   3) أنت اللي نزّلت السواق بالتعليق على F
QBCore.Functions.CreateCallback('qb-vehiclekeys:server:ClaimRunningVehicle', function(source, cb, netId)
    local src = source
    if not QBCore.Functions.GetPlayer(src) then return cb(false) end

    local veh = vehicleFromNet(netId)
    if not veh then return cb(false) end
    if GetPedInVehicleSeat(veh, -1) ~= GetPlayerPed(src) then return cb(false) end

    local plate = vehiclePlate(veh)
    if not plate then return cb(false) end
    if HasKeys(src, plate) then return cb(true) end

    local locked = GetVehicleDoorLockStatus(veh) >= 2 or Entity(veh).state.vehLocked == true
    local npcUnlocked = Config.NpcCarjack.Enabled and Entity(veh).state.npcLock == 'unlocked'
    local pull = PulledOut[NetworkGetNetworkIdFromEntity(veh)]
    local pulled = pull ~= nil and pull.src == src and os.time() - pull.t <= 30
    local running = Config.RunningEngine.Enabled and not locked and GetIsVehicleEngineRunning(veh)

    if not (npcUnlocked or pulled or running) then return cb(false) end

    if Config.RunningEngine.RemoveOwnerKey and VehicleList[plate] then
        for _, Player in pairs(QBCore.Functions.GetQBPlayers()) do
            if VehicleList[plate][Player.PlayerData.citizenid] then RemoveKeys(Player.PlayerData.source, plate) end
        end
    end

    PulledOut[NetworkGetNetworkIdFromEntity(veh)] = nil
    GiveKeys(src, plate)
    if running and not npcUnlocked and not pulled then
        TriggerClientEvent('QBCore:Notify', src, Lang:t('notify.running_keys'), 'success')
    end
    cb(true)
end)

-- سيارة بوت: القرعة من السيرفر (الكلاينت ما يختار) — مرة وحدة لكل سيارة
QBCore.Functions.CreateCallback('qb-vehiclekeys:server:NpcLockRoll', function(source, cb, netId)
    local src = source
    if not Config.NpcCarjack.Enabled or rateLimited(src, 'npcroll', 500) then return cb(nil) end

    local veh = vehicleFromNet(netId)
    if not veh or distanceTo(src, veh) > 15.0 then return cb(nil) end

    local driver = GetPedInVehicleSeat(veh, -1)
    if driver == 0 or IsPedAPlayer(driver) then return cb(nil) end

    local state = Entity(veh).state.npcLock
    if not state then
        state = (math.random() < Config.NpcCarjack.UnlockedChance) and 'unlocked' or 'locked'
        Entity(veh).state:set('npcLock', state, true)
    end
    SetVehicleDoorsLocked(veh, state == 'locked' and 2 or 1)
    cb(state)
end)

-- تعلّق على F عند باب لاعب سايق → ينزل (لو الباب مفتوح)
local pullCooldown = {}
RegisterNetEvent('qb-vehiclekeys:server:PullOutDriver', function(netId)
    local src = source
    if not Config.PullOut.Enabled then return end

    local now = GetGameTimer()
    if pullCooldown[src] and now - pullCooldown[src] < 3000 then return end
    pullCooldown[src] = now

    local veh = vehicleFromNet(netId)
    if not veh then return end
    if GetEntityHealth(GetPlayerPed(src)) <= 0 then return end
    if GetVehiclePedIsIn(GetPlayerPed(src), false) ~= 0 then return end
    if distanceTo(src, veh) > 4.0 then return end
    if GetVehicleDoorLockStatus(veh) >= 2 then return end
    if #GetEntityVelocity(veh) * 3.6 > Config.PullOut.MaxSpeed + 2.0 then return end

    if Entity(veh).state.vehLocked == true then return end

    local driver = GetPedInVehicleSeat(veh, -1)
    if driver == 0 or not IsPedAPlayer(driver) then return end
    local target = NetworkGetEntityOwner(driver)
    if not target or target == src then return end

    PulledOut[NetworkGetNetworkIdFromEntity(veh)] = { src = src, t = os.time() }
    TriggerClientEvent('qb-vehiclekeys:client:PulledOut', target, netId)
    TriggerClientEvent('qb-vehiclekeys:client:PullOutGo', src, netId)
end)

AddEventHandler('playerDropped', function()
    local src = source
    pullCooldown[src], strikes[src], acquirePending[src] = nil, nil, nil
    for k in pairs(lastCall) do
        if k:find('^' .. src .. ':') then lastCall[k] = nil end
    end
end)

QBCore.Functions.CreateCallback('qb-vehiclekeys:server:GetVehicleKeys', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb({}) end
    local citizenid = Player.PlayerData.citizenid
    local keysList = {}
    for plate, citizenids in pairs(VehicleList) do
        if citizenids[citizenid] then
            keysList[plate] = true
        end
    end
    cb(keysList)
end)

QBCore.Functions.CreateCallback('qb-vehiclekeys:server:GetClosestPlayer', function(source, cb)
    local src = source
    local ClosestPlayer = {}
    local myCoords = GetEntityCoords(GetPlayerPed(src))
    for _, player in pairs(QBCore.Functions.GetQBPlayers()) do
        local id = player.PlayerData.source
        if id ~= src and #(myCoords - GetEntityCoords(GetPlayerPed(id))) <= 2 then
            ClosestPlayer[#ClosestPlayer + 1] = {
                name = player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname,
                id = id,
            }
        end
    end
    cb(ClosestPlayer)
end)

-----------------------
----   Functions   ----
-----------------------

function GiveKeys(id, plate)
    plate = trimPlate(plate)
    local Player = id and QBCore.Functions.GetPlayer(id)
    if not plate or not Player then return end
    local citizenid = Player.PlayerData.citizenid

    if not VehicleList[plate] then VehicleList[plate] = {} end
    VehicleList[plate][citizenid] = true

    TriggerClientEvent('QBCore:Notify', id, Lang:t("notify.vgetkeys"))
    TriggerClientEvent('qb-vehiclekeys:client:AddKeys', id, plate)
end

function RemoveKeys(id, plate)
    plate = trimPlate(plate)
    local Player = id and QBCore.Functions.GetPlayer(id)
    if not plate or not Player then return end
    local citizenid = Player.PlayerData.citizenid

    if VehicleList[plate] then
        VehicleList[plate][citizenid] = nil
    end

    TriggerClientEvent('qb-vehiclekeys:client:RemoveKeys', id, plate)
end

function HasKeys(id, plate)
    plate = trimPlate(plate)
    local Player = id and QBCore.Functions.GetPlayer(id)
    if not plate or not Player then return false end
    return VehicleList[plate] ~= nil and VehicleList[plate][Player.PlayerData.citizenid] == true
end

exports('GiveKeys', GiveKeys)
exports('RemoveKeys', RemoveKeys)
exports('HasKeys', HasKeys)

-- QBCore.Commands.Add("givekeys", Lang:t("addcom.givekeys"), {{name = Lang:t("addcom.givekeys_id"), help = Lang:t("addcom.givekeys_id_help")}}, false, function(source, args)
-- 	local src = source
--     TriggerClientEvent('qb-vehiclekeys:client:GiveKeys', src, tonumber(args[1]))
-- end)

-- QBCore.Commands.Add("addkeys", Lang:t("addcom.addkeys"), {{name = Lang:t("addcom.addkeys_id"), help = Lang:t("addcom.addkeys_id_help")}, {name = Lang:t("addcom.addkeys_plate"), help = Lang:t("addcom.addkeys_plate_help")}}, true, function(source, args)
-- 	local src = source
--     if not args[1] or not args[2] then
--         TriggerClientEvent('QBCore:Notify', src, Lang:t("notify.fpid"))
--         return
--     end
--     GiveKeys(tonumber(args[1]), args[2])
-- end, 'admin')

-- QBCore.Commands.Add("removekeys", Lang:t("addcom.rkeys"), {{name = Lang:t("addcom.rkeys_id"), help = Lang:t("addcom.rkeys_id_help")}, {name = Lang:t("addcom.rkeys_plate"), help = Lang:t("addcom.rkeys_plate_help")}}, true, function(source, args)
-- 	local src = source
--     if not args[1] or not args[2] then
--         TriggerClientEvent('QBCore:Notify', src, Lang:t("notify.fpid"))
--         return
--     end
--     RemoveKeys(tonumber(args[1]), args[2])
-- end, 'admin')
