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

--[[
    Field treatment log (qb-ems-tools / qb-hospital revives).
    Every tool a medic uses on a patient is collected, and once the medic has been
    done with that patient for a few minutes it is filed as one "Treatment" report,
    so it shows up in Patient Records without anyone typing it.
      exports['mdt-ems-tablet']:LogFieldTreatment(medicSrc, patientSrc, 'Tourniquet')
]]
local FIELD_FLUSH_SECONDS = 180
local fieldLogs = {} -- ["medicCid:patientCid"] = { ... }

local function FlushFieldLog(key)
    local log = fieldLogs[key]
    fieldLogs[key] = nil
    if not log or #log.lines == 0 then return end
    local details = ('Field treatment by %s (automatic log)\n\n%s'):format(log.medicName, table.concat(log.lines, '\n'))
    exports.oxmysql:execute(
        'INSERT INTO ' .. MDT.Tables.Reports .. ' (citizenid, author_name, report_type, title, patient_name, patient_cid, involved, details) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        { log.medicCid, log.medicName, 'Treatment', ('Field treatment — %s'):format(log.patientName):sub(1, 150),
          log.patientName, log.patientCid, '', details:sub(1, 2000) }
    )
end

local function LogFieldTreatment(medicSrc, patientSrc, text)
    local Medic = QBCore.Functions.GetPlayer(tonumber(medicSrc) or -1)
    local Patient = QBCore.Functions.GetPlayer(tonumber(patientSrc) or -1)
    if not MDT.IsEmployee(Medic) or not Patient then return end
    local key = Medic.PlayerData.citizenid .. ':' .. Patient.PlayerData.citizenid
    local log = fieldLogs[key]
    if not log then
        log = {
            medicSrc = Medic.PlayerData.source, patientSrc = Patient.PlayerData.source,
            medicCid = Medic.PlayerData.citizenid, medicName = MDT.GetName(Medic),
            patientCid = Patient.PlayerData.citizenid, patientName = MDT.GetName(Patient),
            lines = {},
        }
        fieldLogs[key] = log
    end
    if #log.lines < 40 then
        log.lines[#log.lines + 1] = ('[%s] %s'):format(os.date('%H:%M'), MDT.Clean(text, 120))
    end
    log.lastAt = os.time()
end
exports('LogFieldTreatment', LogFieldTreatment)

CreateThread(function()
    while true do
        Wait(30000)
        local now = os.time()
        for key, log in pairs(fieldLogs) do
            if now - (log.lastAt or now) >= FIELD_FLUSH_SECONDS then FlushFieldLog(key) end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    for key, log in pairs(fieldLogs) do
        if log.medicSrc == src or log.patientSrc == src then FlushFieldLog(key) end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for key in pairs(fieldLogs) do FlushFieldLog(key) end
end)
