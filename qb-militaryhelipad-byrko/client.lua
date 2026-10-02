local QBCore = exports['qb-core']:GetCoreObject()

CreateThread(function()
    RequestModel(Config.Bot.model)
    while not HasModelLoaded(Config.Bot.model) do Wait(1) end
    
    local ped = CreatePed(4, Config.Bot.model, Config.Bot.coords.x, Config.Bot.coords.y, Config.Bot.coords.z - 1.0, Config.Bot.coords.w, false, true)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)

    exports.interact:AddLocalEntityInteraction({
        entity = ped,
        name = 'helicopter_bot',
        id = 'helicopter_bot_interaction',
        distance = 3.0,
        options = {
            {
                label = 'Open Helicopter Menu',
                canInteract = function()
                    local player = QBCore.Functions.GetPlayerData()
                    if not player or not player.citizenid then return false end
                    return Config.AllowedCitizens[player.citizenid] == true
                end,
                action = function()
                    OpenHeliMenu()
                end,
            }
        }
    })
end)

-- دالة جمع الطائرات القريبة وإرسالها للـ NUI
function OpenHeliMenu()
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local nearbyHelis = {}

    local vehicles = GetGamePool('CVehicle')
    for _, vehicle in ipairs(vehicles) do
        local vehCoords = GetEntityCoords(vehicle)
        if #(coords - vehCoords) <= 35.0 then
            local plate = GetVehicleNumberPlateText(vehicle)
            if plate then
                plate = string.gsub(plate, "^%s*(.-)%s*$", "%1")
                local modelHash = GetEntityModel(vehicle)
                local displayName = GetDisplayNameFromVehicleModel(modelHash)
                
                table.insert(nearbyHelis, {
                    plate = plate,
                    model = string.lower(displayName),
                    entity = vehicle
                })
            end
        end
    end

    QBCore.Functions.TriggerCallback('qb-militaryhelipad-byrko:server:GetOwnedHelicopters', function(ownedHelis)
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = "open",
            shopHelis = Config.Helicopters,
            ownedHelis = ownedHelis,
            nearbyHelis = nearbyHelis
        })
    end)
end

RegisterNUICallback('close', function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('buyHeli', function(data, cb)
    SetNuiFocus(false, false)
    TriggerServerEvent('qb-militaryhelipad-byrko:server:BuyHelicopter', data.model, data.price)
    cb('ok')
end)

RegisterNUICallback('spawnOwnedHeli', function(data, cb)
    SetNuiFocus(false, false)
    TriggerServerEvent('qb-militaryhelipad-byrko:server:SpawnOwnedHeli', data.plate, data.vehicle)
    cb('ok')
end)

RegisterNUICallback('storeSpecificHeli', function(data, cb)
    SetNuiFocus(false, false)
    local plate = data.plate
    
    local vehicles = GetGamePool('CVehicle')
    local foundVehicle = nil
    for _, vehicle in ipairs(vehicles) do
        local vPlate = GetVehicleNumberPlateText(vehicle)
        if vPlate then
            vPlate = string.gsub(vPlate, "^%s*(.-)%s*$", "%1")
            if vPlate == plate then
                foundVehicle = vehicle
                break
            end
        end
    end

    if foundVehicle and DoesEntityExist(foundVehicle) then
        DeleteEntity(foundVehicle)
    end

    TriggerServerEvent('qb-militaryhelipad-byrko:server:StoreHelicopter', plate)
    cb('ok')
end)

-- فحص المهابط واختيار أول مهبط فارغ وغير مزدحم قريب من اللاعب
function GetAvailableSpawnPoint()
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    
    -- ترتيب النقاط حسب الأقرب للاعب أولاً
    local sortedPoints = {}
    for _, point in ipairs(Config.SpawnPoints) do
        local dist = #(coords - vector3(point.x, point.y, point.z))
        table.insert(sortedPoints, {point = point, dist = dist})
    end
    table.sort(sortedPoints, function(a, b) return a.dist < b.dist end)

    -- فحص كل نقطة هل هي مزدحمة أم لا (نطاق 4 أمتار)
    for _, item in ipairs(sortedPoints) do
        local point = item.point
        local isOccupied = false
        local vehicles = GetGamePool('CVehicle')
        for _, vehicle in ipairs(vehicles) do
            local vehCoords = GetEntityCoords(vehicle)
            if #(vector3(point.x, point.y, point.z) - vehCoords) < 4.0 then
                isOccupied = true
                break
            end
        end
        if not isOccupied then
            return point -- تم العثور على نقطة فارغة
        end
    end

    return nil -- جميع النقاط مزدحمة
end

RegisterNetEvent('qb-militaryhelipad-byrko:client:SpawnHelicopter', function(modelName, plate)
    local spawnPoint = GetAvailableSpawnPoint()
    if not spawnPoint then
        TriggerEvent('QBCore:Notify', 'All helipads are currently occupied!', 'error')
        -- إعادة ضبط حالة الطائرة في السيرفر إلى مخزنة لكي لا تتعطل قاعدة البيانات
        TriggerServerEvent('qb-militaryhelipad-byrko:server:StoreHelicopter', plate)
        return
    end

    local modelHash = GetHashKey(modelName)
    RequestModel(modelHash)
    while not HasModelLoaded(modelHash) do Wait(1) end

    local vehicle = CreateVehicle(modelHash, spawnPoint.x, spawnPoint.y, spawnPoint.z, spawnPoint.w, true, true)
    SetVehicleNumberPlateText(vehicle, plate)
    TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)
    SetModelAsNoLongerNeeded(modelHash)

    TriggerEvent('qb-vehiclekeys:client:AddKeys', plate)
end)