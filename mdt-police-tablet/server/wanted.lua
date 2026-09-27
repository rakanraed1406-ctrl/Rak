--[[
    server/wanted.lua
    "Most Wanted" board — a capped Top 10 list of the department's most
    dangerous outstanding criminals. Any employee can view it; only Command
    staff (grade 9+) can add or remove an entry.
]]

local QBCore = MDT.QBCore
local MAX_WANTED = 10
local DANGER_WEIGHT = { ['Low'] = 1, ['Medium'] = 2, ['High'] = 3, ['Extreme'] = 4 }

local function SendWantedList(src)
    exports.oxmysql:execute(
        'SELECT id, name, charges, danger_level, last_seen, reward, posted_by, created_at FROM ' .. MDT.Tables.Wanted ..
        ' ORDER BY created_at DESC LIMIT ' .. MAX_WANTED,
        {},
        function(rows)
            rows = rows or {}
            table.sort(rows, function(a, b)
                local wa = DANGER_WEIGHT[a.danger_level] or 0
                local wb = DANGER_WEIGHT[b.danger_level] or 0
                if wa == wb then return a.id > b.id end
                return wa > wb
            end)
            TriggerClientEvent('police:client:ReceiveWanted', src, rows)
        end
    )
end

RegisterNetEvent('police:server:GetWanted', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsEmployee(Player) then return end
    SendWantedList(src)
end)

RegisterNetEvent('police:server:AddWanted', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsSeniorCommand(Player) then return end
    if type(data) ~= 'table' then return end

    local name = tostring(data.name or ''):sub(1, 100):gsub('^%s+', ''):gsub('%s+$', '')
    local charges = tostring(data.charges or ''):sub(1, 500):gsub('^%s+', ''):gsub('%s+$', '')
    local dangerLevel = tostring(data.dangerLevel or 'Medium')
    if not DANGER_WEIGHT[dangerLevel] then dangerLevel = 'Medium' end
    local lastSeen = tostring(data.lastSeen or ''):sub(1, 150)
    local reward = math.max(0, math.floor(tonumber(data.reward) or 0))

    if name == '' or charges == '' then
        TriggerClientEvent('QBCore:Notify', src, 'A name and charges are required.', 'error')
        return
    end

    exports.oxmysql:execute('SELECT COUNT(*) AS cnt FROM ' .. MDT.Tables.Wanted, {}, function(countRes)
        local count = (countRes and countRes[1] and countRes[1].cnt) or 0
        if count >= MAX_WANTED then
            TriggerClientEvent('QBCore:Notify', src,
                'The Top ' .. MAX_WANTED .. ' list is full — remove an entry before adding a new one.', 'error')
            return
        end

        local charinfo = Player.PlayerData.charinfo
        local postedBy = (charinfo and charinfo.firstname or 'Command') .. ' ' .. (charinfo and charinfo.lastname or '')

        exports.oxmysql:execute(
            'INSERT INTO ' .. MDT.Tables.Wanted .. ' (name, charges, danger_level, last_seen, reward, posted_by, posted_by_cid) VALUES (?, ?, ?, ?, ?, ?, ?)',
            { name, charges, dangerLevel, lastSeen, reward, postedBy, Player.PlayerData.citizenid },
            function()
                TriggerClientEvent('QBCore:Notify', src, name .. ' added to the Most Wanted list.', 'success')
                MDT.NotifyAllPolice('Police HQ: ' .. name .. ' has been added to the Most Wanted list.', dangerLevel == 'Extreme' and 'error' or 'primary')

                if dangerLevel == 'Extreme' or dangerLevel == 'High' then
                    local ped = GetPlayerPed(src)
                    local coords = ped ~= 0 and GetEntityCoords(ped) or vector3(0.0, 0.0, 0.0)
                    MDT.SendDispatchCall('police', {
                        code = 'MOST-WANTED', title = 'Most Wanted: ' .. name .. ' (' .. dangerLevel .. ')',
                        priority = 'HIGH', description = charges,
                        coords = { x = coords.x, y = coords.y, z = coords.z }
                    })
                end

                MDT.LogMdtAction(Player, 'Added Most Wanted Entry', name .. ' [' .. dangerLevel .. ']')
                SendWantedList(src)
            end
        )
    end)
end)

RegisterNetEvent('police:server:RemoveWanted', function(wantedId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsSeniorCommand(Player) then return end

    wantedId = tonumber(wantedId)
    if not wantedId then return end

    exports.oxmysql:execute('SELECT name FROM ' .. MDT.Tables.Wanted .. ' WHERE id = ?', { wantedId }, function(res)
        local name = (res and res[1] and res[1].name) or ('Entry #' .. wantedId)
        exports.oxmysql:execute('DELETE FROM ' .. MDT.Tables.Wanted .. ' WHERE id = ?', { wantedId }, function()
            MDT.LogMdtAction(Player, 'Removed Most Wanted Entry', name)
            SendWantedList(src)
        end)
    end)
end)
