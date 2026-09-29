--[[ server/directives.lua - all medics read; posting = Command only ]]
local QBCore = MDT.QBCore

local function SendDirectives(src)
    exports.oxmysql:execute(
        'SELECT id, title, body, priority, posted_by, created_at FROM ' .. MDT.Tables.Directives .. ' ORDER BY created_at DESC LIMIT 100',
        {},
        function(rows) TriggerClientEvent('ems-mdt:client:ReceiveDirectives', src, rows or {}) end
    )
end

RegisterNetEvent('ems-mdt:server:GetDirectives', function()
    local src = source
    if not MDT.IsEmployee(QBCore.Functions.GetPlayer(src)) then return end
    SendDirectives(src)
end)

RegisterNetEvent('ems-mdt:server:PostDirective', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsSeniorCommand(Player) or type(data) ~= 'table' then return end

    local title = MDT.Clean(data.title, 150)
    local body = MDT.Clean(data.body, 2000)
    local priority = tostring(data.priority or 'normal')
    if priority ~= 'normal' and priority ~= 'important' and priority ~= 'urgent' then priority = 'normal' end

    if title == '' or body == '' then
        TriggerClientEvent('QBCore:Notify', src, 'A title and directive body are required.', 'error')
        return
    end
    if not MDT.CheckCooldown('directive', Player.PlayerData.citizenid) then
        TriggerClientEvent('QBCore:Notify', src, 'Please wait a moment before publishing another directive.', 'error')
        return
    end

    local postedBy = MDT.GetName(Player) .. ' (' .. (Player.PlayerData.job.grade.name or 'Command') .. ')'

    exports.oxmysql:execute(
        'INSERT INTO ' .. MDT.Tables.Directives .. ' (title, body, priority, posted_by, posted_by_cid) VALUES (?, ?, ?, ?, ?)',
        { title, body, priority, postedBy, Player.PlayerData.citizenid },
        function()
            TriggerClientEvent('QBCore:Notify', src, 'Directive published to the department.', 'success')
            MDT.NotifyAllEms('EMS Command: A new directive has been posted — check the tablet.', priority == 'urgent' and 'error' or 'primary')
            if priority == 'urgent' then
                MDT.SendDispatchCall('ambulance', {
                    code = 'DIRECTIVE', title = 'Urgent Directive', priority = 'high',
                    description = title, coords = MDT.PedCoords(src), origin = 'command'
                })
            end
            MDT.LogMdtAction(Player, 'Published Directive', title .. ' [' .. priority .. ']')
            SendDirectives(src)
        end
    )
end)

RegisterNetEvent('ems-mdt:server:DeleteDirective', function(directiveId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsSeniorCommand(Player) then return end
    directiveId = tonumber(directiveId)
    if not directiveId then return end

    exports.oxmysql:execute('SELECT title FROM ' .. MDT.Tables.Directives .. ' WHERE id = ?', { directiveId }, function(res)
        local title = (res and res[1] and res[1].title) or ('Directive #' .. directiveId)
        exports.oxmysql:execute('DELETE FROM ' .. MDT.Tables.Directives .. ' WHERE id = ?', { directiveId }, function()
            MDT.LogMdtAction(Player, 'Deleted Directive', title)
            SendDirectives(src)
        end)
    end)
end)
