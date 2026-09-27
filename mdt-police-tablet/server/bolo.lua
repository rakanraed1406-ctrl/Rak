--[[ server/bolo.lua - all employees post/view; delete = author or Command (dispatch push appended by hand) ]]
local QBCore = MDT.QBCore

local function SendBolos(src)
    exports.oxmysql:execute(
        'SELECT id, citizenid, author_name, subject_name, subject_desc, vehicle_plate, reason, priority, active, created_at FROM ' ..
        MDT.Tables.Bolos .. ' ORDER BY active DESC, created_at DESC LIMIT 100',
        {},
        function(rows)
            TriggerClientEvent('police:client:ReceiveBolos', src, rows or {})
        end
    )
end

RegisterNetEvent('police:server:GetBolos', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsEmployee(Player) then return end
    SendBolos(src)
end)

RegisterNetEvent('police:server:SubmitBolo', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsEmployee(Player) then return end
    if type(data) ~= 'table' then return end

    local citizenid = Player.PlayerData.citizenid
    local now = os.time()
    if MDT.Cooldowns.bolo[citizenid] and (now - MDT.Cooldowns.bolo[citizenid]) < BOLO_COOLDOWN then
        TriggerClientEvent('QBCore:Notify', src, 'Please wait a moment before posting another BOLO.', 'error')
        return
    end

    local subjectName = tostring(data.subjectName or ''):sub(1, 150):gsub('^%s+', ''):gsub('%s+$', '')
    local subjectDesc = tostring(data.subjectDesc or ''):sub(1, 255)
    local plate = tostring(data.vehiclePlate or ''):sub(1, 20):upper():gsub('^%s+', ''):gsub('%s+$', '')
    local reason = tostring(data.reason or ''):sub(1, 500):gsub('^%s+', ''):gsub('%s+$', '')
    local priority = tostring(data.priority or 'normal')
    if not MDT.BOLO_PRIORITIES[priority] then priority = 'normal' end

    if reason == '' or (subjectName == '' and plate == '') then
        TriggerClientEvent('QBCore:Notify', src, 'A reason plus at least a subject name or plate is required.', 'error')
        return
    end

    MDT.Cooldowns.bolo[citizenid] = now

    local charinfo = Player.PlayerData.charinfo
    local authorName = (charinfo and charinfo.firstname or 'Unknown') .. ' ' .. (charinfo and charinfo.lastname or '')

    exports.oxmysql:execute(
        'INSERT INTO ' .. MDT.Tables.Bolos .. ' (citizenid, author_name, subject_name, subject_desc, vehicle_plate, reason, priority) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { citizenid, authorName, subjectName, subjectDesc, plate, reason, priority },
        function()
            TriggerClientEvent('QBCore:Notify', src, 'BOLO posted to the department.', 'success')
            MDT.NotifyAllPolice('Police HQ: A new BOLO has been issued — check the MDT.', priority == 'high' and 'error' or 'primary')

            -- High-priority BOLOs also push a real dispatch call via sk1-hub.
            if priority == 'high' then
                local ped = GetPlayerPed(src)
                local coords = ped ~= 0 and GetEntityCoords(ped) or vector3(0.0, 0.0, 0.0)
                MDT.SendDispatchCall('police', {
                    code = 'BOLO', title = 'BOLO Issued', priority = 'HIGH',
                    description = (subjectName ~= '' and subjectName or plate) .. ' — ' .. reason,
                    coords = { x = coords.x, y = coords.y, z = coords.z },
                    tags = plate ~= '' and { { icon = 'fa-car', label = plate } } or nil
                })
            end
            MDT.LogMdtAction(Player, 'Posted BOLO', (subjectName ~= '' and subjectName or plate))
            SendBolos(src)
        end
    )
end)

RegisterNetEvent('police:server:ClearBolo', function(boloId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsEmployee(Player) then return end

    boloId = tonumber(boloId)
    if not boloId then return end

    exports.oxmysql:execute('SELECT citizenid, subject_name, vehicle_plate FROM ' .. MDT.Tables.Bolos .. ' WHERE id = ?', { boloId }, function(res)
        if not (res and res[1]) then return end

        local isAuthor = res[1].citizenid == Player.PlayerData.citizenid
        if not (isAuthor or MDT.IsSeniorCommand(Player)) then
            TriggerClientEvent('QBCore:Notify', src, 'You are not authorized to clear this BOLO.', 'error')
            return
        end

        exports.oxmysql:execute('UPDATE ' .. MDT.Tables.Bolos .. ' SET active = 0 WHERE id = ?', { boloId }, function()
            MDT.LogMdtAction(Player, 'Cleared BOLO', res[1].subject_name or res[1].vehicle_plate or ('BOLO #' .. boloId))
            SendBolos(src)
        end)
    end)
end)

-- ===================================================================
-- Vehicle lookup (read-only, all employees) — plate search against the
-- standard qb-core vehicle ownership table. Never exposes anything beyond
-- what's already visible on a real plate/registration check.
-- ===================================================================
