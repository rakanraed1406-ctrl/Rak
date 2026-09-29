--[[ server/personnel.lua - hire/fire/promote/demote/suspend/history + EMS points (qb-emspoints metadata) ]]
local QBCore = MDT.QBCore

local function jobGrades()
    local job = QBCore.Shared.Jobs[Config.JobName]
    return job and job.grades or {}
end

RegisterNetEvent('ems-mdt:server:updateGrade', function(targetCitizenId, actionType)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsSeniorCommand(Player) then return end
    if type(targetCitizenId) ~= 'string' or (actionType ~= 'promote' and actionType ~= 'demote') then return end

    local bossGradeLevel = Player.PlayerData.job.grade.level
    local Target = QBCore.Functions.GetPlayerByCitizenId(targetCitizenId)

    exports.oxmysql:execute('SELECT job FROM players WHERE citizenid = ?', { targetCitizenId }, function(res)
        local targetJobData
        if Target then
            targetJobData = Target.PlayerData.job
        elseif res and res[1] then
            targetJobData = json.decode(res[1].job)
        else
            TriggerClientEvent('QBCore:Notify', src, 'Employee record not found.', 'error')
            return
        end
        local targetGradeLevel = tonumber(targetJobData.grade and targetJobData.grade.level) or 0

        if targetJobData.name ~= Config.JobName then
            TriggerClientEvent('QBCore:Notify', src, 'That person is not an EMS employee.', 'error')
            return
        end
        if targetGradeLevel >= bossGradeLevel then
            TriggerClientEvent('QBCore:Notify', src, 'You cannot modify the rank of someone equal to or above your own rank.', 'error')
            return
        end

        local newGradeLevel = math.max(0, targetGradeLevel + (actionType == 'promote' and 1 or -1))
        if newGradeLevel >= bossGradeLevel then
            TriggerClientEvent('QBCore:Notify', src, 'You cannot promote someone to a rank equal to or above your own.', 'error')
            return
        end
        local gradeInfo = jobGrades()[tostring(newGradeLevel)]
        if not gradeInfo then
            TriggerClientEvent('QBCore:Notify', src, 'That rank does not exist in the job configuration.', 'error')
            return
        end

        if Target then
            Target.Functions.SetJob(Config.JobName, newGradeLevel)
            TriggerClientEvent('QBCore:Notify', Target.PlayerData.source, 'Your rank has been updated.', 'success')
        else
            targetJobData.grade = { level = newGradeLevel, name = gradeInfo.name }
            exports.oxmysql:execute('UPDATE players SET job = ? WHERE citizenid = ?', { json.encode(targetJobData), targetCitizenId })
        end

        MDT.NotifyAllEms('EMS Command: A medic\'s rank has been updated.', 'primary')
        MDT.LogMdtAction(Player, actionType == 'promote' and 'Promoted Medic' or 'Demoted Medic', targetCitizenId .. ' → grade ' .. newGradeLevel)
        MDT.SendBossData(src)
    end)
end)

RegisterNetEvent('ems-mdt:server:fireEmployee', function(targetCitizenId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsSeniorCommand(Player) then return end
    if type(targetCitizenId) ~= 'string' then return end

    local bossGradeLevel = Player.PlayerData.job.grade.level

    exports.oxmysql:execute('SELECT job FROM players WHERE citizenid = ?', { targetCitizenId }, function(res)
        if not (res and res[1]) then
            TriggerClientEvent('QBCore:Notify', src, 'Employee record not found.', 'error')
            return
        end

        local targetJobData = json.decode(res[1].job) or {}
        if targetJobData.name ~= Config.JobName then
            TriggerClientEvent('QBCore:Notify', src, 'That person is not an EMS employee.', 'error')
            return
        end
        if (tonumber(targetJobData.grade and targetJobData.grade.level) or 0) >= bossGradeLevel then
            TriggerClientEvent('QBCore:Notify', src, 'You cannot terminate someone equal to or above your own rank.', 'error')
            return
        end

        local Target = QBCore.Functions.GetPlayerByCitizenId(targetCitizenId)
        if Target then
            Target.Functions.SetJob('unemployed', 0)
            TriggerClientEvent('QBCore:Notify', Target.PlayerData.source, 'You have been terminated from EMS.', 'error')
        else
            exports.oxmysql:execute('UPDATE players SET job = ? WHERE citizenid = ?', { json.encode({
                name = 'unemployed', label = 'Unemployed', payment = 0, onduty = true, isboss = false,
                grade = { level = 0, name = 'Unemployed' }
            }), targetCitizenId })
        end

        MDT.NotifyAllEms('EMS Command: A medic has been discharged from the department.', 'error')
        MDT.LogMdtAction(Player, 'Terminated Medic', targetCitizenId)
        MDT.SendBossData(src)
    end)
end)

RegisterNetEvent('ems-mdt:server:HireByCitizenId', function(targetCitizenId, gradeLevel)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsSeniorCommand(Player) then return end
    if type(targetCitizenId) ~= 'string' then return end

    gradeLevel = tonumber(gradeLevel)
    if not gradeLevel or gradeLevel < 0 or gradeLevel >= Player.PlayerData.job.grade.level then
        TriggerClientEvent('QBCore:Notify', src, 'Invalid rank, or a rank equal to/above your own.', 'error')
        return
    end
    local gradeInfo = jobGrades()[tostring(gradeLevel)]
    if not gradeInfo then
        TriggerClientEvent('QBCore:Notify', src, 'That rank does not exist in EMS.', 'error')
        return
    end

    exports.oxmysql:execute('SELECT charinfo FROM players WHERE citizenid = ?', { targetCitizenId }, function(result)
        if not (result and result[1]) then
            TriggerClientEvent('QBCore:Notify', src, 'That Citizen ID does not exist in the database.', 'error')
            return
        end

        local charinfo = json.decode(result[1].charinfo or '{}') or {}
        local targetName = (charinfo.firstname and charinfo.lastname) and (charinfo.firstname .. ' ' .. charinfo.lastname) or targetCitizenId

        local TargetPlayer = QBCore.Functions.GetPlayerByCitizenId(targetCitizenId)
        if TargetPlayer then
            TargetPlayer.Functions.SetJob(Config.JobName, gradeLevel)
            TriggerClientEvent('QBCore:Notify', TargetPlayer.PlayerData.source, 'You have been hired into EMS as: ' .. gradeInfo.name, 'success')
        else
            exports.oxmysql:execute('UPDATE players SET job = ? WHERE citizenid = ?', { json.encode({
                name = Config.JobName,
                label = QBCore.Shared.Jobs[Config.JobName].label,
                payment = gradeInfo.payment or 50,
                onduty = true, isboss = false,
                grade = { level = gradeLevel, name = gradeInfo.name }
            }), targetCitizenId })
        end

        MDT.NotifyAllEms('EMS Command: A new medic (' .. targetName .. ') has joined the department.', 'success')
        MDT.LogMdtAction(Player, 'Hired Medic (Manual)', targetCitizenId .. ' → grade ' .. gradeLevel)
        MDT.SendBossData(src)
    end)
end)

--- Recruit the nearest civilian — distance re-checked on the server.
RegisterNetEvent('ems-mdt:server:HireNearby', function(targetServerId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsSeniorCommand(Player) then return end

    targetServerId = tonumber(targetServerId)
    local TargetPlayer = targetServerId and QBCore.Functions.GetPlayer(targetServerId)
    if not TargetPlayer or targetServerId == src then
        TriggerClientEvent('QBCore:Notify', src, 'No valid nearby civilian was found.', 'error')
        return
    end
    if TargetPlayer.PlayerData.job.name == Config.JobName then
        TriggerClientEvent('QBCore:Notify', src, 'That person is already a member of EMS.', 'error')
        return
    end

    local bossPed, targetPed = GetPlayerPed(src), GetPlayerPed(targetServerId)
    if bossPed == 0 or targetPed == 0 then return end
    if #(GetEntityCoords(bossPed) - GetEntityCoords(targetPed)) > (Config.HireDistance + 1.0) then
        TriggerClientEvent('QBCore:Notify', src, 'That person is too far away to recruit.', 'error')
        return
    end

    TargetPlayer.Functions.SetJob(Config.JobName, 0)
    TriggerClientEvent('QBCore:Notify', TargetPlayer.PlayerData.source, 'You have been recruited into EMS.', 'success')
    MDT.NotifyAllEms('EMS Command: A new recruit has joined the team.', 'success')
    MDT.LogMdtAction(Player, 'Recruited Nearby Civilian', 'Server ID ' .. tostring(targetServerId))
    MDT.SendBossData(src)
end)

-- ---------------------------------------------------------------------------
-- Suspension (keeps job/rank, blocks the tablet until lifted)
-- ---------------------------------------------------------------------------

RegisterNetEvent('ems-mdt:server:ToggleSuspension', function(targetCitizenId, reason)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsSeniorCommand(Player) then return end
    if type(targetCitizenId) ~= 'string' then return end
    if targetCitizenId == Player.PlayerData.citizenid then
        TriggerClientEvent('QBCore:Notify', src, 'You cannot suspend yourself.', 'error')
        return
    end

    if MDT.IsSuspended(targetCitizenId) then
        exports.oxmysql:execute('DELETE FROM ' .. MDT.Tables.Suspended .. ' WHERE citizenid = ?', { targetCitizenId }, function()
            MDT.State.suspended[targetCitizenId] = nil
            MDT.NotifyAllEms('EMS Command: A medic\'s tablet suspension has been lifted.', 'success')
            MDT.LogMdtAction(Player, 'Lifted Suspension', targetCitizenId)
            MDT.SendBossData(src)
        end)
        return
    end

    reason = tostring(reason or ''):sub(1, 255)
    exports.oxmysql:execute(
        'INSERT INTO ' .. MDT.Tables.Suspended .. ' (citizenid, suspended_by, reason) VALUES (?, ?, ?) ' ..
        'ON DUPLICATE KEY UPDATE suspended_by = VALUES(suspended_by), reason = VALUES(reason)',
        { targetCitizenId, MDT.GetName(Player), reason },
        function()
            MDT.State.suspended[targetCitizenId] = true
            MDT.NotifyAllEms('EMS Command: A medic\'s tablet access has been suspended.', 'error')
            MDT.LogMdtAction(Player, 'Suspended Medic', targetCitizenId .. (reason ~= '' and (' — ' .. reason) or ''))
            MDT.SendBossData(src)

            local TargetPlayer = QBCore.Functions.GetPlayerByCitizenId(targetCitizenId)
            if TargetPlayer then
                TriggerClientEvent('ems-mdt:client:ForceCloseMdt', TargetPlayer.PlayerData.source, 'Your tablet access has been suspended.')
            end
        end
    )
end)

-- ---------------------------------------------------------------------------
-- EMS points (same metadata key qb-emspoints uses) — Command only
-- ---------------------------------------------------------------------------

local POINTS_KEY = (Config.Points and Config.Points.MetadataKey) or 'ambulancepoints'

local function applyPoints(targetCitizenId, mode, amount, cb)
    local Target = QBCore.Functions.GetPlayerByCitizenId(targetCitizenId)
    if Target then
        if Target.PlayerData.job.name ~= Config.JobName then return cb(false, 'That person is not an EMS employee.') end
        local current = tonumber(Target.PlayerData.metadata[POINTS_KEY]) or 0
        local new = mode == 'reset' and 0 or math.max(0, current + (mode == 'add' and amount or -amount))
        Target.Functions.SetMetaData(POINTS_KEY, new)
        TriggerClientEvent('QBCore:Notify', Target.PlayerData.source, ('EMS points: %d → %d'):format(current, new), mode == 'add' and 'success' or 'primary')
        return cb(true, new)
    end

    exports.oxmysql:execute('SELECT job, metadata FROM players WHERE citizenid = ?', { targetCitizenId }, function(res)
        if not (res and res[1]) then return cb(false, 'Employee record not found.') end
        local job = json.decode(res[1].job or '{}') or {}
        if job.name ~= Config.JobName then return cb(false, 'That person is not an EMS employee.') end
        local meta = json.decode(res[1].metadata or '{}') or {}
        local current = tonumber(meta[POINTS_KEY]) or 0
        local new = mode == 'reset' and 0 or math.max(0, current + (mode == 'add' and amount or -amount))
        meta[POINTS_KEY] = new
        exports.oxmysql:execute('UPDATE players SET metadata = ? WHERE citizenid = ?', { json.encode(meta), targetCitizenId }, function()
            cb(true, new)
        end)
    end)
end

RegisterNetEvent('ems-mdt:server:ChangePoints', function(targetCitizenId, mode, amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not (Config.Points and Config.Points.Enabled) or not MDT.IsSeniorCommand(Player) then return end
    if type(targetCitizenId) ~= 'string' or (mode ~= 'add' and mode ~= 'remove' and mode ~= 'reset') then return end
    if targetCitizenId == Player.PlayerData.citizenid then
        TriggerClientEvent('QBCore:Notify', src, 'You cannot change your own points.', 'error')
        return
    end

    amount = math.floor(tonumber(amount) or 0)
    if mode ~= 'reset' and (amount <= 0 or amount > (Config.Points.MaxPerAction or 100)) then
        TriggerClientEvent('QBCore:Notify', src, ('Enter an amount between 1 and %d.'):format(Config.Points.MaxPerAction or 100), 'error')
        return
    end

    applyPoints(targetCitizenId, mode, amount, function(ok, result)
        if not ok then
            TriggerClientEvent('QBCore:Notify', src, result, 'error')
            return
        end
        TriggerClientEvent('QBCore:Notify', src, ('Points updated — %s now has %d.'):format(targetCitizenId, result), 'success')
        MDT.LogMdtAction(Player, 'Changed EMS Points', ('%s %s %s → %d'):format(targetCitizenId, mode, mode == 'reset' and '' or amount, result))
        MDT.SendBossData(src)
    end)
end)

-- ---------------------------------------------------------------------------
-- Personnel history (HR actions from the audit log)
-- ---------------------------------------------------------------------------

local HISTORY_ACTIONS = {
    'Promoted Medic', 'Demoted Medic', 'Terminated Medic', 'Hired Medic (Manual)',
    'Recruited Nearby Civilian', 'Suspended Medic', 'Lifted Suspension',
    'Application Accepted', 'Application Rejected', 'Changed EMS Points'
}

RegisterNetEvent('ems-mdt:server:GetPersonnelHistory', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsSeniorCommand(Player) then return end

    local placeholders = {}
    for i = 1, #HISTORY_ACTIONS do placeholders[i] = '?' end

    exports.oxmysql:execute(
        'SELECT medic_name, action, details, created_at FROM ' .. MDT.Tables.Logs ..
        ' WHERE action IN (' .. table.concat(placeholders, ',') .. ') ORDER BY created_at DESC LIMIT 60',
        HISTORY_ACTIONS,
        function(rows)
            TriggerClientEvent('ems-mdt:client:ReceivePersonnelHistory', src, rows or {})
        end
    )
end)
