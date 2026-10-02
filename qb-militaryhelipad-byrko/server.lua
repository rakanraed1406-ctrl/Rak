local QBCore = exports['qb-core']:GetCoreObject()

QBCore.Functions.CreateCallback('qb-militaryhelipad-byrko:server:GetOwnedHelicopters', function(source, cb)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb({}) end

    local citizenid = Player.PlayerData.citizenid

    -- جلب الطائرات المخزنة فقط (stored = 1)
    MySQL.query('SELECT * FROM player_helicopters WHERE citizenid = ? AND stored = 1', {citizenid}, function(result)
        cb(result or {})
    end)
end)

RegisterNetEvent('qb-militaryhelipad-byrko:server:BuyHelicopter', function(modelName, price)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    if Player.Functions.RemoveMoney('cash', price) then
        local plate = "HELI" .. math.random(1000, 9999)
        local citizenid = Player.PlayerData.citizenid

        MySQL.insert('INSERT INTO player_helicopters (citizenid, vehicle, plate, stored) VALUES (?, ?, ?, ?)', 
        {citizenid, modelName, plate, 0}, function(id)
            if id then
                TriggerClientEvent('qb-militaryhelipad-byrko:client:SpawnHelicopter', src, modelName, plate)
                TriggerClientEvent('QBCore:Notify', src, 'Helicopter purchased and spawned successfully!', 'success')
            end
        end)
    else
        TriggerClientEvent('QBCore:Notify', src, 'Not enough cash!', 'error')
    end
end)

RegisterNetEvent('qb-militaryhelipad-byrko:server:SpawnOwnedHeli', function(plate, vehicleModel)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local citizenid = Player.PlayerData.citizenid

    -- التحقق الأمني لمنع التلاعب وتأكيد الملكية والحالة
    MySQL.query('SELECT * FROM player_helicopters WHERE plate = ? AND citizenid = ?', {plate, citizenid}, function(result)
        if result and result[1] then
            local heliData = result[1]
            
            -- منع إخراج طائرة وهي بالأصل خارج الكراج (stored = 0) لمنع تكريرها
            if heliData.stored == 0 then
                TriggerClientEvent('QBCore:Notify', src, 'This helicopter is already outside or destroyed!', 'error')
                return
            end

            MySQL.update('UPDATE player_helicopters SET stored = 0 WHERE plate = ?', {plate}, function(affected)
                if affected > 0 then
                    TriggerClientEvent('qb-militaryhelipad-byrko:client:SpawnHelicopter', src, vehicleModel, plate)
                    TriggerClientEvent('QBCore:Notify', src, 'Helicopter spawned from garage!', 'success')
                end
            end)
        else
            TriggerClientEvent('QBCore:Notify', src, 'You do not own this helicopter!', 'error')
        end
    end)
end)

RegisterNetEvent('qb-militaryhelipad-byrko:server:StoreHelicopter', function(plate)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local citizenid = Player.PlayerData.citizenid

    MySQL.query('SELECT * FROM player_helicopters WHERE plate = ? AND citizenid = ?', {plate, citizenid}, function(result)
        if result and result[1] then
            MySQL.update('UPDATE player_helicopters SET stored = 1 WHERE plate = ?', {plate}, function(affectedRows)
                if affectedRows and affectedRows > 0 then
                    TriggerClientEvent('QBCore:Notify', src, 'Helicopter stored in garage successfully!', 'success')
                end
            end)
        else
            -- قفل حماية إضافي لو اللوحة غير مطابقة
            TriggerClientEvent('QBCore:Notify', src, 'Action denied: Invalid helicopter ownership!', 'error')
        end
    end)
end)