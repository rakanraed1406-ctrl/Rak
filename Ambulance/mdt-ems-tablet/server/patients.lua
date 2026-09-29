--[[
    server/patients.lua - Patient records.
      * Search citizens (name / citizen ID / phone)
      * Profile: identity, blood type, insurance (qb-hospital metadata), live condition
        + current injuries (qb-hospital export) when the patient is in the city
      * Medical notes (allergies, conditions, medications, notes) — any medic edits
      * Treatment history (medical reports, bills, ward stays)
]]
local QBCore = MDT.QBCore

local function decode(str)
    if type(str) == 'table' then return str end
    local ok, res = pcall(json.decode, str or '{}')
    return (ok and type(res) == 'table') and res or {}
end

local function insuranceInfo(meta)
    local expiry = meta and meta.timerinsurance
    if type(expiry) ~= 'string' or expiry == '' then return { active = false } end
    -- qb-hospital stores the expiry as "d/m/YYYY HH:MM" (server local time).
    local d, m, y, hh, mm = expiry:match('^(%d+)/(%d+)/(%d+)%s+(%d+):(%d+)')
    if d then
        local ts = os.time({ day = tonumber(d), month = tonumber(m), year = tonumber(y), hour = tonumber(hh), min = tonumber(mm) })
        return { active = ts > os.time(), expires = expiry }
    end
    return { active = false, expires = expiry }
end

local function liveStatus(citizenid)
    local Target = QBCore.Functions.GetPlayerByCitizenId(citizenid)
    if not Target then return nil end
    local meta = Target.PlayerData.metadata or {}
    local status = {
        online = true,
        serverId = Target.PlayerData.source,
        dead = meta.isdead == true,
        laststand = meta.inlaststand == true,
    }
    local res = Config.HospitalResource
    if res and res ~= '' and GetResourceState(res) == 'started' then
        local ok, injuries = pcall(function() return exports[res]:GetPatientStatus(Target.PlayerData.source) end)
        if ok and type(injuries) == 'table' then status.injuries = injuries end
    end
    return status
end

RegisterNetEvent('ems-mdt:server:SearchPatients', function(query)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsEmployee(Player) then return end
    query = MDT.Clean(query, 40)
    if #query < 2 then
        TriggerClientEvent('QBCore:Notify', src, 'Type at least 2 characters to search.', 'error')
        return
    end
    if not MDT.CheckCooldown('search', Player.PlayerData.citizenid) then return end

    local like = '%' .. query:gsub('[%%_\\]', '\\%0') .. '%'
    local first, last = query:match('^(%S+)%s+(%S+)')

    local sql = [[SELECT citizenid, charinfo, metadata FROM players WHERE citizenid = ?
        OR JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname')) LIKE ?
        OR JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname')) LIKE ?
        OR JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.phone')) LIKE ?]]
    local params = { query:upper(), like, like, like }
    if first and last then
        sql = sql .. [[ OR (JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname')) LIKE ? AND JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname')) LIKE ?)]]
        params[#params + 1] = first .. '%'
        params[#params + 1] = last .. '%'
    end
    sql = sql .. ' LIMIT 15'

    exports.oxmysql:execute(sql, params, function(rows)
        local results = {}
        for _, row in ipairs(rows or {}) do
            local ci = decode(row.charinfo)
            local meta = decode(row.metadata)
            results[#results + 1] = {
                citizenid = row.citizenid,
                name = (ci.firstname or 'Unknown') .. ' ' .. (ci.lastname or ''),
                dob = ci.birthdate, gender = (tonumber(ci.gender) == 1) and 'Female' or 'Male',
                bloodtype = meta.bloodtype,
                online = QBCore.Functions.GetPlayerByCitizenId(row.citizenid) ~= nil,
            }
        end
        TriggerClientEvent('ems-mdt:client:PatientSearchResults', src, query, results)
    end)
end)

local function SendProfile(src, citizenid)
    exports.oxmysql:execute('SELECT citizenid, charinfo, metadata FROM players WHERE citizenid = ? LIMIT 1', { citizenid }, function(rows)
        local row = rows and rows[1]
        if not row then
            TriggerClientEvent('QBCore:Notify', src, 'Patient not found.', 'error')
            return
        end

        -- Online players: live metadata beats the last DB save.
        local Target = QBCore.Functions.GetPlayerByCitizenId(citizenid)
        local ci = Target and Target.PlayerData.charinfo or decode(row.charinfo)
        local meta = Target and Target.PlayerData.metadata or decode(row.metadata)

        local profile = {
            citizenid = citizenid,
            name = (ci.firstname or 'Unknown') .. ' ' .. (ci.lastname or ''),
            dob = ci.birthdate, gender = (tonumber(ci.gender) == 1) and 'Female' or 'Male',
            nationality = ci.nationality, phone = ci.phone,
            bloodtype = meta.bloodtype,
            insurance = insuranceInfo(meta),
            live = liveStatus(citizenid),
        }

        local P = MDT.Tables
        exports.oxmysql:execute('SELECT allergies, conditions, medications, notes, updated_by, updated_at FROM ' .. P.Patients .. ' WHERE citizenid = ?', { citizenid }, function(notes)
            profile.medical = notes and notes[1] or {}
            exports.oxmysql:execute('SELECT id, report_type, title, author_name, created_at FROM ' .. P.Reports .. ' WHERE patient_cid = ? ORDER BY created_at DESC LIMIT 15', { citizenid }, function(reports)
                profile.reports = reports or {}
                exports.oxmysql:execute('SELECT id, treatment, amount, paid, medic_name, created_at FROM ' .. P.Bills .. ' WHERE patient_cid = ? ORDER BY created_at DESC LIMIT 15', { citizenid }, function(bills)
                    profile.bills = bills or {}
                    exports.oxmysql:execute('SELECT id, bed, diagnosis, severity, active, author_name, created_at FROM ' .. P.Ward .. ' WHERE patient_cid = ? ORDER BY created_at DESC LIMIT 10', { citizenid }, function(ward)
                        profile.ward = ward or {}
                        TriggerClientEvent('ems-mdt:client:PatientProfile', src, profile)
                    end)
                end)
            end)
        end)
    end)
end

RegisterNetEvent('ems-mdt:server:GetPatientProfile', function(citizenid)
    local src = source
    if not MDT.IsEmployee(QBCore.Functions.GetPlayer(src)) then return end
    citizenid = MDT.Clean(citizenid, 50)
    if citizenid == '' then return end
    SendProfile(src, citizenid)
end)

RegisterNetEvent('ems-mdt:server:SavePatientNotes', function(citizenid, data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsEmployee(Player) or type(data) ~= 'table' then return end
    citizenid = MDT.Clean(citizenid, 50)
    if citizenid == '' then return end
    if not MDT.CheckCooldown('notes', Player.PlayerData.citizenid) then
        TriggerClientEvent('QBCore:Notify', src, 'Please wait a moment before saving again.', 'error')
        return
    end

    local allergies = MDT.Clean(data.allergies, 500)
    local conditions = MDT.Clean(data.conditions, 500)
    local medications = MDT.Clean(data.medications, 500)
    local notes = MDT.Clean(data.notes, 2000)

    exports.oxmysql:execute('SELECT 1 FROM players WHERE citizenid = ? LIMIT 1', { citizenid }, function(exists)
        if not (exists and exists[1]) then return end
        exports.oxmysql:execute(
            'INSERT INTO ' .. MDT.Tables.Patients .. ' (citizenid, allergies, conditions, medications, notes, updated_by) VALUES (?, ?, ?, ?, ?, ?) ' ..
            'ON DUPLICATE KEY UPDATE allergies = VALUES(allergies), conditions = VALUES(conditions), medications = VALUES(medications), notes = VALUES(notes), updated_by = VALUES(updated_by)',
            { citizenid, allergies, conditions, medications, notes, MDT.GetName(Player) },
            function()
                TriggerClientEvent('QBCore:Notify', src, 'Medical record saved.', 'success')
                MDT.LogMdtAction(Player, 'Updated Medical Record', citizenid)
                SendProfile(src, citizenid)
            end
        )
    end)
end)

--- Patients within a few metres of the medic (for quick "who is this" / billing).
RegisterNetEvent('ems-mdt:server:NearbyPatients', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsEmployee(Player) then return end
    local myPed = GetPlayerPed(src)
    if myPed == 0 then return end
    local myCoords = GetEntityCoords(myPed)

    local list = {}
    for _, v in pairs(QBCore.Functions.GetQBPlayers()) do
        local tsrc = v.PlayerData.source
        if tsrc ~= src then
            local ped = GetPlayerPed(tsrc)
            if ped ~= 0 and #(GetEntityCoords(ped) - myCoords) <= 6.0 then
                list[#list + 1] = {
                    serverId = tsrc, citizenid = v.PlayerData.citizenid, name = MDT.GetName(v),
                    dead = v.PlayerData.metadata.isdead == true, laststand = v.PlayerData.metadata.inlaststand == true,
                }
            end
        end
    end
    TriggerClientEvent('ems-mdt:client:NearbyPatients', src, list)
end)
