--[[ server/reports.lua - Medical reports (patient care reports). All medics write/read; delete = author or Command ]]
local QBCore = MDT.QBCore

local function SendReports(src)
    exports.oxmysql:execute(
        'SELECT id, citizenid, author_name, report_type, title, patient_name, patient_cid, involved, details, created_at FROM ' ..
        MDT.Tables.Reports .. ' ORDER BY created_at DESC LIMIT 150',
        {},
        function(rows) TriggerClientEvent('ems-mdt:client:ReceiveReports', src, rows or {}) end
    )
end

RegisterNetEvent('ems-mdt:server:GetReports', function()
    local src = source
    if not MDT.IsEmployee(QBCore.Functions.GetPlayer(src)) then return end
    SendReports(src)
end)

RegisterNetEvent('ems-mdt:server:SubmitReport', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsEmployee(Player) or type(data) ~= 'table' then return end

    local title = MDT.Clean(data.title, 150)
    local reportType = MDT.Clean(data.reportType, 50)
    if not MDT.REPORT_TYPES[reportType] then reportType = 'Treatment' end
    local patientName = MDT.Clean(data.patientName, 100)
    local patientCid = MDT.Clean(data.patientCid, 50):upper()
    local involved = MDT.Clean(data.involved, 255)
    local details = MDT.Clean(data.details, 2000)

    if title == '' or details == '' then
        TriggerClientEvent('QBCore:Notify', src, 'A title and report details are required.', 'error')
        return
    end
    if not MDT.CheckCooldown('report', Player.PlayerData.citizenid) then
        TriggerClientEvent('QBCore:Notify', src, 'Please wait a moment before filing another report.', 'error')
        return
    end

    exports.oxmysql:execute(
        'INSERT INTO ' .. MDT.Tables.Reports .. ' (citizenid, author_name, report_type, title, patient_name, patient_cid, involved, details) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        { Player.PlayerData.citizenid, MDT.GetName(Player), reportType, title,
          patientName ~= '' and patientName or nil, patientCid ~= '' and patientCid or nil, involved, details },
        function()
            TriggerClientEvent('QBCore:Notify', src, 'Medical report filed.', 'success')
            MDT.LogMdtAction(Player, 'Filed Medical Report', title)
            SendReports(src)
        end
    )
end)

RegisterNetEvent('ems-mdt:server:DeleteReport', function(reportId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsEmployee(Player) then return end
    reportId = tonumber(reportId)
    if not reportId then return end

    exports.oxmysql:execute('SELECT citizenid, title FROM ' .. MDT.Tables.Reports .. ' WHERE id = ?', { reportId }, function(res)
        if not (res and res[1]) then return end
        if not (res[1].citizenid == Player.PlayerData.citizenid or MDT.IsSeniorCommand(Player)) then
            TriggerClientEvent('QBCore:Notify', src, 'You are not authorized to delete this report.', 'error')
            return
        end
        exports.oxmysql:execute('DELETE FROM ' .. MDT.Tables.Reports .. ' WHERE id = ?', { reportId }, function()
            MDT.LogMdtAction(Player, 'Deleted Medical Report', res[1].title or ('Report #' .. reportId))
            SendReports(src)
        end)
    end)
end)
