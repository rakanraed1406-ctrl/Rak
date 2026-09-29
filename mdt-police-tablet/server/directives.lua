--[[ server/directives.lua - all employees read; posting = Command only ]]
local QBCore = MDT.QBCore

local function SendDirectives(src)
    exports.oxmysql:execute(
        'SELECT id, title, body, priority, posted_by, created_at FROM ' ..
        MDT.Tables.Directives .. ' ORDER BY created_at DESC LIMIT 100',
        {},
        function(rows)
            TriggerClientEvent('police:client:ReceiveDirectives', src, rows or {})
        end
    )
end

RegisterNetEvent('police:server:GetDirectives', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsEmployee(Player) then return end
    SendDirectives(src)
end)

RegisterNetEvent('police:server:PostDirective', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsSeniorCommand(Player) then return end -- Command staff (grade 9+) only
    if type(data) ~= 'table' then return end

    local citizenid = Player.PlayerData.citizenid
    local now = os.time()
    if MDT.Cooldowns.directive[citizenid] and (now - MDT.Cooldowns.directive[citizenid]) < MDT.COOLDOWN_SECONDS.directive then
        TriggerClientEvent('QBCore:Notify', src, 'Please wait a moment before publishing another directive.', 'error')
        return
    end

    local title = tostring(data.title or ''):sub(1, 150):gsub('^%s+', ''):gsub('%s+$', '')
    local body = tostring(data.body or ''):sub(1, 2000):gsub('^%s+', ''):gsub('%s+$', '')
    local priority = tostring(data.priority or 'normal')
    if priority ~= 'normal' and priority ~= 'important' and priority ~= 'urgent' then priority = 'normal' end

    if title == '' or body == '' then
        TriggerClientEvent('QBCore:Notify', src, 'A title and directive body are required.', 'error')
        return
    end

    MDT.Cooldowns.directive[citizenid] = now

    local charinfo = Player.PlayerData.charinfo
    local postedBy = (charinfo and charinfo.firstname or 'Command') .. ' ' .. (charinfo and charinfo.lastname or '') ..
        ' (' .. Player.PlayerData.job.grade.name .. ')'

    exports.oxmysql:execute(
        'INSERT INTO ' .. MDT.Tables.Directives .. ' (title, body, priority, posted_by, posted_by_cid) VALUES (?, ?, ?, ?, ?)',
        { title, body, priority, postedBy, Player.PlayerData.citizenid },
        function()
            TriggerClientEvent('QBCore:Notify', src, 'Directive published to the department.', 'success')
            MDT.NotifyAllPolice('Police HQ: A new directive has been posted — check the MDT.', priority == 'urgent' and 'error' or 'primary')

            if priority == 'urgent' then
                local ped = GetPlayerPed(src)
                local coords = ped ~= 0 and GetEntityCoords(ped) or vector3(0.0, 0.0, 0.0)
                MDT.SendDispatchCall('police', {
                    code = 'DIRECTIVE', title = 'Urgent Directive', priority = 'HIGH',
                    description = title, coords = { x = coords.x, y = coords.y, z = coords.z }
                })
            end
            MDT.LogMdtAction(Player, 'Published Directive', title .. ' [' .. priority .. ']')
            SendDirectives(src)
        end
    )
end)

RegisterNetEvent('police:server:DeleteDirective', function(directiveId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsSeniorCommand(Player) then return end -- Command staff (grade 9+) only

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

-- ===================================================================
-- Tactical Map app (new) — live on-duty positions rendered inside the NUI
-- itself (separate from the old in-world GPS blips below, which are left
-- untouched). Any on-duty employee can VIEW the map; only Command staff can
-- act on a pinned officer (promote/demote/fire), and every action still goes
-- through the exact same IsSeniorCommand-gated events used by the Personnel
-- app — the map is just another front-end for them, not a new trust path.
-- ===================================================================
