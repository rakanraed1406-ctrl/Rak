--[[ server/recruitment.lua - EMS job applications: submit (public), review (Command) ]]
local QBCore = MDT.QBCore
local APPS = MDT.Tables.Applications

RegisterNetEvent('ems-mdt:server:SubmitApplication', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    if Player.PlayerData.job.name == Config.JobName then
        TriggerClientEvent('QBCore:Notify', src, 'You are already employed by EMS.', 'error')
        return
    end
    if type(data) ~= 'table' then return end

    local name = MDT.Clean(data.name, 100)
    local age = tonumber(data.age)
    local experience = MDT.Clean(data.experience, 500)
    local contact = MDT.Clean(data.contact or 'N/A', 50)

    if name == '' or experience == '' or not age or age < 18 or age > 90 then
        TriggerClientEvent('QBCore:Notify', src, 'Invalid application data submitted.', 'error')
        return
    end

    exports.oxmysql:execute('SELECT id FROM ' .. APPS .. ' WHERE citizenid = ? AND status = ? LIMIT 1',
        { Player.PlayerData.citizenid, 'Pending' }, function(existing)
        if existing and existing[1] then
            TriggerClientEvent('QBCore:Notify', src, 'You already have a pending application awaiting review.', 'error')
            return
        end

        exports.oxmysql:execute(
            'INSERT INTO ' .. APPS .. ' (citizenid, applicant_name, applicant_age, experience, contact, status) VALUES (?, ?, ?, ?, ?, ?)',
            { Player.PlayerData.citizenid, name, math.floor(age), experience, contact, 'Pending' },
            function()
                TriggerClientEvent('QBCore:Notify', src, 'Your EMS application has been submitted for review.', 'success')
                MDT.NotifyAllEms('EMS Command: A new recruitment application has been submitted.', 'primary')
            end
        )
    end)
end)

RegisterNetEvent('ems-mdt:server:RequestApplicationStatus', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    exports.oxmysql:execute('SELECT status FROM ' .. APPS .. ' WHERE citizenid = ? ORDER BY created_at DESC LIMIT 1',
        { Player.PlayerData.citizenid }, function(result)
        TriggerClientEvent('ems-mdt:client:ReceiveApplicationStatus', src, result and result[1] and result[1].status or nil)
    end)
end)

RegisterNetEvent('ems-mdt:server:HandleApplication', function(appId, actionType)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsSeniorCommand(Player) then return end

    appId = tonumber(appId)
    if not appId or (actionType ~= 'accept' and actionType ~= 'reject') then return end
    local newStatus = actionType == 'accept' and 'Accepted' or 'Rejected'

    exports.oxmysql:execute('SELECT citizenid FROM ' .. APPS .. ' WHERE id = ?', { appId }, function(result)
        if not (result and result[1]) then
            TriggerClientEvent('QBCore:Notify', src, 'Application not found.', 'error')
            return
        end

        exports.oxmysql:execute('UPDATE ' .. APPS .. ' SET status = ?, reviewed_by = ? WHERE id = ?',
            { newStatus, Player.PlayerData.citizenid, appId })

        local TargetPlayer = QBCore.Functions.GetPlayerByCitizenId(result[1].citizenid)
        if TargetPlayer then
            TriggerClientEvent('QBCore:Notify', TargetPlayer.PlayerData.source,
                ('Your EMS application has been %s.'):format(newStatus:lower()), newStatus == 'Accepted' and 'success' or 'error')
        end

        MDT.LogMdtAction(Player, 'Application ' .. newStatus, 'Application #' .. appId)
        MDT.SendBossData(src)
    end)
end)
