--[[ server/recruitment.lua - job applications: submit (public), review (Command) ]]
local QBCore = MDT.QBCore

RegisterNetEvent('police:server:SubmitApplication', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    if Player.PlayerData.job.name == Config.JobName then
        TriggerClientEvent('QBCore:Notify', src, 'You are already employed by the police department.', 'error')
        return
    end

    if type(data) ~= 'table' then return end

    -- Never trust client input: coerce, trim, and length-cap everything before storing it.
    local name = tostring(data.name or ''):sub(1, 100):gsub('^%s+', ''):gsub('%s+$', '')
    local age = tonumber(data.age)
    local experience = tostring(data.experience or ''):sub(1, 500):gsub('^%s+', ''):gsub('%s+$', '')
    local contact = tostring(data.contact or 'N/A'):sub(1, 50)

    if name == '' or experience == '' or not age or age < 18 or age > 90 then
        TriggerClientEvent('QBCore:Notify', src, 'Invalid application data submitted.', 'error')
        return
    end

    local existing = exports.oxmysql:executeSync(
        'SELECT id FROM ' .. Config.ApplicationsTable .. ' WHERE citizenid = ? AND status = ? LIMIT 1',
        { Player.PlayerData.citizenid, 'Pending' }
    )
    if existing and existing[1] then
        TriggerClientEvent('QBCore:Notify', src, 'You already have a pending application awaiting review.', 'error')
        return
    end

    exports.oxmysql:execute(
        'INSERT INTO ' .. Config.ApplicationsTable .. ' (citizenid, applicant_name, applicant_age, experience, contact, status) VALUES (?, ?, ?, ?, ?, ?)',
        { Player.PlayerData.citizenid, name, age, experience, contact, 'Pending' }
    )

    TriggerClientEvent('QBCore:Notify', src, 'Your application has been submitted for review.', 'success')
    MDT.NotifyAllPolice('Police HQ: A new recruitment application has been submitted.', 'primary')
end)

RegisterNetEvent('police:server:RequestApplicationStatus', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    exports.oxmysql:execute(
        'SELECT status FROM ' .. Config.ApplicationsTable .. ' WHERE citizenid = ? ORDER BY created_at DESC LIMIT 1',
        { Player.PlayerData.citizenid },
        function(result)
            if result and result[1] then
                TriggerClientEvent('police:client:ReceiveApplicationStatus', src, result[1].status)
            else
                TriggerClientEvent('police:client:ReceiveApplicationStatus', src, nil)
            end
        end
    )
end)

RegisterNetEvent('police:server:HandleApplication', function(appId, actionType)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsSeniorCommand(Player) then return end -- Command staff (grade 9+) only

    appId = tonumber(appId)
    if not appId or (actionType ~= 'accept' and actionType ~= 'reject') then return end

    local newStatus = actionType == 'accept' and 'Accepted' or 'Rejected'

    exports.oxmysql:execute('SELECT citizenid, status FROM ' .. Config.ApplicationsTable .. ' WHERE id = ?', { appId }, function(result)
        if not (result and result[1]) then
            TriggerClientEvent('QBCore:Notify', src, 'Application not found.', 'error')
            return
        end

        exports.oxmysql:execute(
            'UPDATE ' .. Config.ApplicationsTable .. ' SET status = ?, reviewed_by = ? WHERE id = ?',
            { newStatus, Player.PlayerData.citizenid, appId }
        )

        local TargetPlayer = QBCore.Functions.GetPlayerByCitizenId(result[1].citizenid)
        if TargetPlayer then
            TriggerClientEvent(
                'QBCore:Notify',
                TargetPlayer.PlayerData.source,
                ('Your police application has been %s.'):format(newStatus:lower()),
                newStatus == 'Accepted' and 'success' or 'error'
            )
        end

        MDT.LogMdtAction(Player, 'Application ' .. newStatus, 'Application #' .. appId)

        MDT.SendBossData(src)
    end)
end)

-- ===================================================================
-- Reports (all employees — write and read; delete = author or Command)
-- ===================================================================
