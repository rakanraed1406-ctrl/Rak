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

local LeftRunning = {} -- [plate] = os.time() — صاحب المفتاح نزل وترك الموتر شغال

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
local function isNearPlate(src, plate, maxDist)
    local ped = GetPlayerPed(src)
    local inVeh = GetVehiclePedIsIn(ped, false)
    if inVeh ~= 0 and vehiclePlate(inVeh) == plate then return true end

    local pos = GetEntityCoords(ped)
    for _, veh in ipairs(GetAllVehicles()) do
        if vehiclePlate(veh) == plate and #(GetEntityCoords(veh) - pos) <= maxDist then
            return true
        end
    end
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

-- كانت ثغرة: أي واحد يقدر يعطي نفسه مفتاح أي سيارة. الحين لازم تكون السيارة حقه أو جنبه.
RegisterNetEvent('qb-vehiclekeys:server:AcquireVehicleKeys', function(plate)
    local src = source
    plate = trimPlate(plate)
    if not plate or HasKeys(src, plate) then
        if plate then TriggerClientEvent('qb-vehiclekeys:client:AddKeys', src, plate) end
        return
    end

    if ownsVehicle(src, plate) then return GiveKeys(src, plate) end

    -- السيارة يمكن توها انسوت ولسا ما وصلت للسيرفر → نحاول كم مرة
    CreateThread(function()
        for _ = 1, 10 do
            if GetPlayerPed(src) == 0 then return end
            if isNearPlate(src, plate, 8.0) then return GiveKeys(src, plate) end
            Wait(500)
        end
        print(('[qb-vehiclekeys] %s (%d) طلب مفتاح %s وهو مو جنبها'):format(GetPlayerName(src) or '?', src, plate))
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
    local veh = vehicleFromNet(vehNetId)
    if not veh or distanceTo(src, veh) > 10.0 then return end
    SetVehicleDoorsLocked(veh, state)
end)

-- نزلت وتركت الموتر شغال → المفتاح يبقى بالسيارة
RegisterNetEvent('qb-vehiclekeys:server:LeftVehicle', function(netId)
    local src = source
    local veh = vehicleFromNet(netId)
    if not veh then return end
    local plate = vehiclePlate(veh)
    if not plate or not HasKeys(src, plate) or distanceTo(src, veh) > 50.0 then return end

    if GetIsVehicleEngineRunning(veh) and GetPedInVehicleSeat(veh, -1) == 0 then
        LeftRunning[plate] = os.time()
    else
        LeftRunning[plate] = nil
    end
end)

-- ركب سواق بسيارة موترها شغال وما معه مفتاح → ياخذ المفتاح
QBCore.Functions.CreateCallback('qb-vehiclekeys:server:ClaimRunningVehicle', function(source, cb, netId)
    local src = source
    local Cfg = Config.RunningEngine
    if not Cfg.Enabled or not QBCore.Functions.GetPlayer(src) then return cb(false) end

    local veh = vehicleFromNet(netId)
    if not veh then return cb(false) end
    if GetPedInVehicleSeat(veh, -1) ~= GetPlayerPed(src) then return cb(false) end
    if not GetIsVehicleEngineRunning(veh) then return cb(false) end

    local plate = vehiclePlate(veh)
    if not plate then return cb(false) end
    if HasKeys(src, plate) then return cb(true) end

    local left = LeftRunning[plate]
    local ok = left ~= nil and (os.time() - left) <= Cfg.ExpireMinutes * 60
    if not ok and Cfg.IncludeNPCVehicles and not VehicleList[plate] then ok = true end
    if not ok then return cb(false) end

    if Cfg.RemoveOwnerKey and VehicleList[plate] then
        for _, Player in pairs(QBCore.Functions.GetQBPlayers()) do
            if VehicleList[plate][Player.PlayerData.citizenid] then RemoveKeys(Player.PlayerData.source, plate) end
        end
    end

    LeftRunning[plate] = nil
    GiveKeys(src, plate)
    TriggerClientEvent('QBCore:Notify', src, Lang:t('notify.running_keys'), 'success')
    cb(true)
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
