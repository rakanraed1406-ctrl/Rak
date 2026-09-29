--[[ server/reports.lua - all employees write/read; delete = author or Command ]]
local QBCore = MDT.QBCore

local function SendReports(src)
    exports.oxmysql:execute(
        'SELECT id, citizenid, author_name, report_type, title, involved, details, created_at FROM ' ..
        MDT.Tables.Reports .. ' ORDER BY created_at DESC LIMIT 150',
        {},
        function(rows)
            TriggerClientEvent('police:client:ReceiveReports', src, rows or {})
        end
    )
end

RegisterNetEvent('police:server:GetReports', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsEmployee(Player) then return end
    SendReports(src)
end)

RegisterNetEvent('police:server:SubmitReport', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsEmployee(Player) then return end
    if type(data) ~= 'table' then return end

    local citizenid = Player.PlayerData.citizenid
    local now = os.time()
    if MDT.Cooldowns.report[citizenid] and (now - MDT.Cooldowns.report[citizenid]) < MDT.COOLDOWN_SECONDS.report then
        TriggerClientEvent('QBCore:Notify', src, 'Please wait a moment before filing another report.', 'error')
        return
    end

    local title = tostring(data.title or ''):sub(1, 150):gsub('^%s+', ''):gsub('%s+$', '')
    local reportType = tostring(data.reportType or 'General'):sub(1, 50)
    if not MDT.REPORT_TYPES[reportType] then reportType = 'General' end
    local involved = tostring(data.involved or ''):sub(1, 255)
    local details = tostring(data.details or ''):sub(1, 2000):gsub('^%s+', ''):gsub('%s+$', '')

    if title == '' or details == '' then
        TriggerClientEvent('QBCore:Notify', src, 'A title and report details are required.', 'error')
        return
    end

    MDT.Cooldowns.report[citizenid] = now

    local charinfo = Player.PlayerData.charinfo
    local authorName = (charinfo and charinfo.firstname or 'Unknown') .. ' ' .. (charinfo and charinfo.lastname or '')

    exports.oxmysql:execute(
        'INSERT INTO ' .. MDT.Tables.Reports .. ' (citizenid, author_name, report_type, title, involved, details) VALUES (?, ?, ?, ?, ?, ?)',
        { Player.PlayerData.citizenid, authorName, reportType, title, involved, details },
        function()
            TriggerClientEvent('QBCore:Notify', src, 'Report filed successfully.', 'success')
            MDT.LogMdtAction(Player, 'Filed Report', title)
            SendReports(src)
        end
    )
end)

RegisterNetEvent('police:server:DeleteReport', function(reportId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsEmployee(Player) then return end

    reportId = tonumber(reportId)
    if not reportId then return end

    exports.oxmysql:execute('SELECT citizenid, title FROM ' .. MDT.Tables.Reports .. ' WHERE id = ?', { reportId }, function(res)
        if not (res and res[1]) then return end

        local isAuthor = res[1].citizenid == Player.PlayerData.citizenid
        if not (isAuthor or MDT.IsSeniorCommand(Player)) then
            TriggerClientEvent('QBCore:Notify', src, 'You are not authorized to delete this report.', 'error')
            return
        end

        exports.oxmysql:execute('DELETE FROM ' .. MDT.Tables.Reports .. ' WHERE id = ?', { reportId }, function()
            MDT.LogMdtAction(Player, 'Deleted Report', res[1].title or ('Report #' .. reportId))
            SendReports(src)
        end)
    end)
end)

-- ===================================================================
-- Directives / Circulars (all employees read; posting = Command only)
-- ===================================================================
