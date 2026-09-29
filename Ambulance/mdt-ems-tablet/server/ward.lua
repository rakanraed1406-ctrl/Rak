--[[
    server/ward.lua - Ward board: patients currently admitted / under care.
    Any medic can admit a patient or update their condition; discharge = the
    admitting medic or Command. A CRITICAL admission also pushes a red call so
    staff come to the hospital.
]]
local QBCore = MDT.QBCore

local function SendWard(src)
    exports.oxmysql:execute(
        'SELECT id, citizenid, author_name, patient_name, patient_cid, bed, diagnosis, severity, active, discharged_by, created_at FROM ' ..
        MDT.Tables.Ward .. ' ORDER BY active DESC, FIELD(severity, \'critical\', \'serious\', \'stable\'), created_at DESC LIMIT 100',
        {},
        function(rows) TriggerClientEvent('ems-mdt:client:ReceiveWard', src, rows or {}) end
    )
end

--- Pushes the fresh board to every medic that has the tablet open.
local function BroadcastWard(actor)
    for src in pairs(MDT.Hub.sessions) do SendWard(src) end
    if actor and not MDT.Hub.sessions[actor] then SendWard(actor) end
end

RegisterNetEvent('ems-mdt:server:GetWard', function()
    local src = source
    if not MDT.IsEmployee(QBCore.Functions.GetPlayer(src)) then return end
    SendWard(src)
end)

RegisterNetEvent('ems-mdt:server:AdmitPatient', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsEmployee(Player) or type(data) ~= 'table' then return end

    local patientName = MDT.Clean(data.patientName, 150)
    local patientCid = MDT.Clean(data.patientCid, 50):upper()
    local bed = MDT.Clean(data.bed, 30)
    local diagnosis = MDT.Clean(data.diagnosis, 500)
    local severity = tostring(data.severity or 'stable')
    if not MDT.WARD_CONDITIONS[severity] then severity = 'stable' end

    if patientName == '' or diagnosis == '' then
        TriggerClientEvent('QBCore:Notify', src, 'Patient name and diagnosis are required.', 'error')
        return
    end
    if not MDT.CheckCooldown('ward', Player.PlayerData.citizenid) then
        TriggerClientEvent('QBCore:Notify', src, 'Please wait a moment before admitting another patient.', 'error')
        return
    end

    exports.oxmysql:execute(
        'INSERT INTO ' .. MDT.Tables.Ward .. ' (citizenid, author_name, patient_name, patient_cid, bed, diagnosis, severity) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { Player.PlayerData.citizenid, MDT.GetName(Player), patientName, patientCid ~= '' and patientCid or nil,
          bed ~= '' and bed or nil, diagnosis, severity },
        function()
            TriggerClientEvent('QBCore:Notify', src, patientName .. ' admitted to the ward.', 'success')
            if severity == 'critical' then
                MDT.SendDispatchCall('ambulance', {
                    code = 'CRITICAL-PT', title = 'Critical Patient — ' .. patientName,
                    description = ('Critical patient admitted%s: %s. Medical staff needed at the hospital.'):format(bed ~= '' and (' (bed ' .. bed .. ')') or '', diagnosis),
                    coords = MDT.PedCoords(src), origin = 'ward',
                    tags = { { icon = 'fa-bed-pulse', label = bed ~= '' and ('Bed ' .. bed) or 'Ward' }, { icon = 'fa-user-doctor', label = MDT.GetName(Player) } }
                })
            end
            MDT.LogMdtAction(Player, 'Admitted Patient', patientName .. ' [' .. severity .. ']')
            BroadcastWard(src)
        end
    )
end)

RegisterNetEvent('ems-mdt:server:UpdateWardSeverity', function(entryId, severity)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsEmployee(Player) then return end
    entryId = tonumber(entryId)
    if not entryId or not MDT.WARD_CONDITIONS[severity] then return end

    exports.oxmysql:execute('UPDATE ' .. MDT.Tables.Ward .. ' SET severity = ? WHERE id = ? AND active = 1', { severity, entryId }, function()
        BroadcastWard(src)
    end)
end)

RegisterNetEvent('ems-mdt:server:DischargePatient', function(entryId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsEmployee(Player) then return end
    entryId = tonumber(entryId)
    if not entryId then return end

    exports.oxmysql:execute('SELECT citizenid, patient_name FROM ' .. MDT.Tables.Ward .. ' WHERE id = ?', { entryId }, function(res)
        if not (res and res[1]) then return end
        if not (res[1].citizenid == Player.PlayerData.citizenid or MDT.IsSeniorCommand(Player)) then
            TriggerClientEvent('QBCore:Notify', src, 'Only the admitting medic or Command can discharge this patient.', 'error')
            return
        end
        exports.oxmysql:execute('UPDATE ' .. MDT.Tables.Ward .. ' SET active = 0, discharged_by = ? WHERE id = ?',
            { MDT.GetName(Player), entryId }, function()
            MDT.LogMdtAction(Player, 'Discharged Patient', res[1].patient_name or ('Entry #' .. entryId))
            BroadcastWard(src)
        end)
    end)
end)
