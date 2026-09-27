--[[ server/personnel.lua - hire/fire/promote/demote (existing logic, unchanged) + suspend/history (new, appended by hand) ]]
local QBCore = MDT.QBCore

RegisterNetEvent('police:server:updateGrade', function(targetCitizenId, actionType)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsSeniorCommand(Player) then return end -- Command staff (grade 9+) only

    if type(targetCitizenId) ~= 'string' or (actionType ~= 'promote' and actionType ~= 'demote') then return end

    local bossGradeLevel = Player.PlayerData.job.grade.level
    local Target = QBCore.Functions.GetPlayerByCitizenId(targetCitizenId)

    exports.oxmysql:execute('SELECT job FROM players WHERE citizenid = ?', { targetCitizenId }, function(res)
        local targetJobData
        local targetGradeLevel = 0

        if Target then
            targetJobData = Target.PlayerData.job
            targetGradeLevel = targetJobData.grade.level
        elseif res and res[1] then
            targetJobData = json.decode(res[1].job)
            targetGradeLevel = targetJobData.grade.level or 0
        else
            TriggerClientEvent('QBCore:Notify', src, 'Employee record not found.', 'error')
            return
        end

        if targetJobData.name ~= Config.JobName then
            TriggerClientEvent('QBCore:Notify', src, 'That person is not a police employee.', 'error')
            return
        end

        if targetGradeLevel >= bossGradeLevel then
            TriggerClientEvent('QBCore:Notify', src, 'You cannot modify the rank of someone equal to or above your own rank.', 'error')
            return
        end

        local newGradeLevel = targetGradeLevel
        if actionType == 'promote' then
            newGradeLevel = newGradeLevel + 1
        else
            newGradeLevel = newGradeLevel - 1
        end

        if newGradeLevel < 0 then newGradeLevel = 0 end

        if newGradeLevel >= bossGradeLevel then
            TriggerClientEvent('QBCore:Notify', src, 'You cannot promote an employee to a rank equal to or above your own.', 'error')
            return
        end

        if not QBCore.Shared.Jobs[Config.JobName].grades[tostring(newGradeLevel)] then
            TriggerClientEvent('QBCore:Notify', src, 'That rank does not exist in the job configuration.', 'error')
            return
        end

        local newGradeName = QBCore.Shared.Jobs[Config.JobName].grades[tostring(newGradeLevel)].name

        if Target then
            Target.Functions.SetJob(Config.JobName, newGradeLevel)
            TriggerClientEvent('QBCore:Notify', Target.PlayerData.source, 'Your rank has been updated.', 'success')
        else
            targetJobData.grade = { level = newGradeLevel, name = newGradeName }
            exports.oxmysql:execute('UPDATE players SET job = ? WHERE citizenid = ?', { json.encode(targetJobData), targetCitizenId })
        end

        MDT.NotifyAllPolice('Police HQ: An officer\'s rank has been updated.', 'primary')
        MDT.LogMdtAction(Player, actionType == 'promote' and 'Promoted Officer' or 'Demoted Officer', targetCitizenId .. ' → grade ' .. newGradeLevel)
        MDT.SendBossData(src)
    end)
end)

RegisterNetEvent('police:server:fireEmployee', function(targetCitizenId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsSeniorCommand(Player) then return end -- Command staff (grade 9+) only

    if type(targetCitizenId) ~= 'string' then return end

    local bossGradeLevel = Player.PlayerData.job.grade.level

    exports.oxmysql:execute('SELECT job FROM players WHERE citizenid = ?', { targetCitizenId }, function(res)
        if not (res and res[1]) then
            TriggerClientEvent('QBCore:Notify', src, 'Employee record not found.', 'error')
            return
        end

        local targetJobData = json.decode(res[1].job)
        if targetJobData.name ~= Config.JobName then
            TriggerClientEvent('QBCore:Notify', src, 'That person is not a police employee.', 'error')
            return
        end

        local targetGradeLevel = targetJobData.grade.level or 0
        if targetGradeLevel >= bossGradeLevel then
            TriggerClientEvent('QBCore:Notify', src, 'You cannot terminate someone equal to or above your own rank.', 'error')
            return
        end

        local unemployedJob = {
            name = 'unemployed',
            label = 'Unemployed',
            payment = 0,
            onduty = true,
            isboss = false,
            grade = { level = 0, name = 'Unemployed' }
        }

        local Target = QBCore.Functions.GetPlayerByCitizenId(targetCitizenId)
        if Target then
            Target.Functions.SetJob('unemployed', 0)
            TriggerClientEvent('QBCore:Notify', Target.PlayerData.source, 'You have been terminated from the police department.', 'error')
        else
            exports.oxmysql:execute('UPDATE players SET job = ? WHERE citizenid = ?', { json.encode(unemployedJob), targetCitizenId })
        end

        MDT.NotifyAllPolice('Police HQ: An officer has been discharged from the department.', 'error')
        MDT.LogMdtAction(Player, 'Terminated Officer', targetCitizenId)
        MDT.SendBossData(src)
    end)
end)

RegisterNetEvent('police:server:HireByCitizenId', function(targetCitizenId, gradeLevel)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsSeniorCommand(Player) then return end -- Command staff (grade 9+) only

    if type(targetCitizenId) ~= 'string' then return end

    local bossGrade = Player.PlayerData.job.grade.level
    gradeLevel = tonumber(gradeLevel)

    if not gradeLevel or gradeLevel >= bossGrade then
        TriggerClientEvent('QBCore:Notify', src, 'Invalid rank, or a rank equal to/above your own.', 'error')
        return
    end

    if not QBCore.Shared.Jobs[Config.JobName].grades[tostring(gradeLevel)] then
        TriggerClientEvent('QBCore:Notify', src, 'That rank does not exist in the police department.', 'error')
        return
    end

    exports.oxmysql:execute('SELECT * FROM players WHERE citizenid = ?', { targetCitizenId }, function(result)
        if not (result and result[1]) then
            TriggerClientEvent('QBCore:Notify', src, 'That Citizen ID does not exist in the database.', 'error')
            return
        end

        local targetData = result[1]
        local charinfo = json.decode(targetData.charinfo or '{}')
        local targetName = (charinfo.firstname and charinfo.lastname) and (charinfo.firstname .. ' ' .. charinfo.lastname) or targetCitizenId

        local newJobData = {
            name = Config.JobName,
            label = QBCore.Shared.Jobs[Config.JobName].label,
            payment = QBCore.Shared.Jobs[Config.JobName].grades[tostring(gradeLevel)].payment or 50,
            onduty = true,
            isboss = false,
            grade = {
                level = gradeLevel,
                name = QBCore.Shared.Jobs[Config.JobName].grades[tostring(gradeLevel)].name
            }
        }

        local TargetPlayer = QBCore.Functions.GetPlayerByCitizenId(targetCitizenId)
        if TargetPlayer then
            TargetPlayer.Functions.SetJob(Config.JobName, gradeLevel)
            TriggerClientEvent('QBCore:Notify', TargetPlayer.PlayerData.source, 'You have been hired into the police department as: ' .. newJobData.grade.name, 'success')
        else
            exports.oxmysql:execute('UPDATE players SET job = ? WHERE citizenid = ?', { json.encode(newJobData), targetCitizenId })
        end

        MDT.NotifyAllPolice('Police HQ: A new employee (' .. targetName .. ') has joined the department.', 'success')
        MDT.LogMdtAction(Player, 'Hired Officer (Manual)', targetCitizenId .. ' → grade ' .. gradeLevel)
        MDT.SendBossData(src)
    end)
end)

--- Recruit the nearest civilian. The client only tells us WHO it thinks is nearest;
--- we independently verify the distance server-side before ever changing a job,
--- so a modified client claiming a far-away target simply gets rejected.
RegisterNetEvent('police:server:HireNearby', function(targetServerId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsSeniorCommand(Player) then return end -- Command staff (grade 9+) only

    targetServerId = tonumber(targetServerId)
    local TargetPlayer = targetServerId and QBCore.Functions.GetPlayer(targetServerId)
    if not TargetPlayer then
        TriggerClientEvent('QBCore:Notify', src, 'No valid nearby civilian was found.', 'error')
        return
    end

    if TargetPlayer.PlayerData.job.name == Config.JobName then
        TriggerClientEvent('QBCore:Notify', src, 'That person is already a member of the police department.', 'error')
        return
    end

    local bossPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(targetServerId)
    if bossPed == 0 or targetPed == 0 then return end

    local dist = #(GetEntityCoords(bossPed) - GetEntityCoords(targetPed))
    if dist > (Config.HireDistance + 1.0) then -- small buffer for network latency
        TriggerClientEvent('QBCore:Notify', src, 'That person is too far away to recruit.', 'error')
        return
    end

    TargetPlayer.Functions.SetJob(Config.JobName, 0)
    TriggerClientEvent('QBCore:Notify', TargetPlayer.PlayerData.source, 'You have been recruited into the police department.', 'success')
    MDT.NotifyAllPolice('Police HQ: A new recruit has joined the ranks.', 'success')
    MDT.LogMdtAction(Player, 'Recruited Nearby Civilian', 'Server ID ' .. tostring(targetServerId))
    MDT.SendBossData(src)
end)

-- ===================================================================
-- NEW: Suspension — a soft, reversible alternative to termination. Keeps
-- job/rank but the MDT refuses to open until Command lifts it. Persisted
-- so it survives a restart and applies even to an offline officer.
-- ===================================================================

RegisterNetEvent('police:server:ToggleSuspension', function(targetCitizenId, reason)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsSeniorCommand(Player) then return end
    if type(targetCitizenId) ~= 'string' then return end

    if MDT.IsSuspended(targetCitizenId) then
        exports.oxmysql:execute('DELETE FROM ' .. MDT.Tables.Suspended .. ' WHERE citizenid = ?', { targetCitizenId }, function()
            MDT.State.suspended[targetCitizenId] = nil
            MDT.NotifyAllPolice('Police HQ: An officer\'s MDT suspension has been lifted.', 'success')
            MDT.LogMdtAction(Player, 'Lifted Suspension', targetCitizenId)
            MDT.SendBossData(src)
        end)
        return
    end

    reason = tostring(reason or ''):sub(1, 255)
    local charinfo = Player.PlayerData.charinfo
    local byName = (charinfo and charinfo.firstname or 'Command') .. ' ' .. (charinfo and charinfo.lastname or '')

    exports.oxmysql:execute(
        'INSERT INTO ' .. MDT.Tables.Suspended .. ' (citizenid, suspended_by, reason) VALUES (?, ?, ?) ' ..
        'ON DUPLICATE KEY UPDATE suspended_by = VALUES(suspended_by), reason = VALUES(reason)',
        { targetCitizenId, byName, reason },
        function()
            MDT.State.suspended[targetCitizenId] = true
            MDT.NotifyAllPolice('Police HQ: An officer\'s MDT access has been suspended.', 'error')
            MDT.LogMdtAction(Player, 'Suspended Officer', targetCitizenId .. (reason ~= '' and (' — ' .. reason) or ''))
            MDT.SendBossData(src)

            local TargetPlayer = QBCore.Functions.GetPlayerByCitizenId(targetCitizenId)
            if TargetPlayer then
                TriggerClientEvent('QBCore:Notify', TargetPlayer.PlayerData.source, 'Your MDT access has been suspended by Command.', 'error')
                TriggerClientEvent('police:client:ForceCloseMdt', TargetPlayer.PlayerData.source, 'Your MDT access has been suspended.')
            end
        end
    )
end)

-- ===================================================================
-- NEW: Personnel history — recent HR-style actions from the audit log.
-- ===================================================================

local HISTORY_ACTIONS = {
    'Promoted Officer', 'Demoted Officer', 'Terminated Officer', 'Hired Officer (Manual)',
    'Recruited Nearby Civilian', 'Suspended Officer', 'Lifted Suspension',
    'Application Accepted', 'Application Rejected'
}

RegisterNetEvent('police:server:GetPersonnelHistory', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsSeniorCommand(Player) then return end

    local placeholders = {}
    for i = 1, #HISTORY_ACTIONS do placeholders[i] = '?' end

    exports.oxmysql:execute(
        'SELECT officer_name, action, details, created_at FROM ' .. MDT.Tables.Logs ..
        ' WHERE action IN (' .. table.concat(placeholders, ',') .. ') ORDER BY created_at DESC LIMIT 60',
        HISTORY_ACTIONS,
        function(rows)
            TriggerClientEvent('police:client:ReceivePersonnelHistory', src, rows or {})
        end
    )
end)
