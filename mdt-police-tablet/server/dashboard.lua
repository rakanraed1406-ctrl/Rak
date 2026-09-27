--[[
    server/dashboard.lua
    Opening the MDT (item + job + duty + suspension gate) and building the
    main data payload (roster, applications, treasury, alert state).
]]

local QBCore = MDT.QBCore

function MDT.SendBossData(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local isCommandStaff = MDT.IsSeniorCommand(Player)
    local isBossFlag = MDT.IsBoss(Player)
    local charinfo = Player.PlayerData.charinfo
    local selfName = (charinfo and charinfo.firstname or '') .. ' ' .. (charinfo and charinfo.lastname or '')
    local selfGrade = Player.PlayerData.job.grade.name or 'Officer'
    local selfGradeLevel = Player.PlayerData.job.grade.level or 0
    local selfCitizenId = Player.PlayerData.citizenid
    local selfOnDuty = Player.PlayerData.job.onduty == true

    local employees = {}
    local addedCitizens = {}

    local players = QBCore.Functions.GetQBPlayers()
    for _, v in pairs(players) do
        if v and v.PlayerData.job.name == Config.JobName then
            local citizenid = v.PlayerData.citizenid
            if not addedCitizens[citizenid] then
                addedCitizens[citizenid] = true
                local ci = v.PlayerData.charinfo
                local fullname = (ci and ci.firstname or 'Unknown') .. ' ' .. (ci and ci.lastname or '')

                table.insert(employees, {
                    name = fullname, citizenid = citizenid, cid = citizenid,
                    grade = v.PlayerData.job.grade, onduty = v.PlayerData.job.onduty,
                    suspended = MDT.IsSuspended(citizenid)
                })
            end
        end
    end

    local function finalizePayload(offlineEmployees, applications, societyMoney)
        for _, emp in ipairs(offlineEmployees) do
            table.insert(employees, emp)
        end

        local activeCount = 0
        for _, emp in ipairs(employees) do
            local isOut = (emp.onduty == 'out' or emp.onduty == false)
            if not isOut then activeCount = activeCount + 1 end
        end

        TriggerClientEvent('police:client:OpenBossMenuUI', src, {
            selfName = selfName, selfGrade = selfGrade, selfGradeLevel = selfGradeLevel,
            selfCitizenId = selfCitizenId, selfOnDuty = selfOnDuty,
            isCommandStaff = isCommandStaff, isBoss = isBossFlag,
            minCommandGrade = MDT.MIN_COMMAND_GRADE,
            isLockdown = MDT.State.lockdown, alertLevel = MDT.State.alertLevel,
            money = isCommandStaff and societyMoney or nil,
            employees = employees, applications = isCommandStaff and (applications or {}) or {},
            onDutyCount = activeCount
        })
    end

    -- PERF: only pull offline players whose job is actually this department,
    -- via a JSON_EXTRACT filter, instead of loading the entire `players`
    -- table (which used to run on every single tablet open/refresh).
    exports.oxmysql:execute(
        "SELECT citizenid, charinfo, job FROM players WHERE JSON_EXTRACT(job, '$.name') = ?",
        { Config.JobName },
        function(dbResult)
        local offlineEmployees = {}

        if dbResult then
            for _, v in pairs(dbResult) do
                if not addedCitizens[v.citizenid] then
                    addedCitizens[v.citizenid] = true
                    local jobData = json.decode(v.job or '{}')

                    if jobData.name == Config.JobName then
                        local ci = json.decode(v.charinfo or '{}')
                        local fullname = (ci.firstname or 'Unknown') .. ' ' .. (ci.lastname or '')

                        table.insert(offlineEmployees, {
                            name = fullname, citizenid = v.citizenid, cid = v.citizenid,
                            grade = jobData.grade or { name = 'Employee', level = 0 }, onduty = 'out',
                            suspended = MDT.IsSuspended(v.citizenid)
                        })
                    end
                end
            end
        end

        if not isCommandStaff then
            finalizePayload(offlineEmployees, nil, nil)
            return
        end

        local societyMoney = MDT.GetSocietyMoney(Config.JobName)

        exports.oxmysql:execute(
            'SELECT id, citizenid, applicant_name, applicant_age, experience, contact, status, created_at FROM ' ..
            Config.ApplicationsTable .. ' ORDER BY created_at DESC LIMIT ?',
            { Config.MaxApplicationsShown },
            function(apps)
                finalizePayload(offlineEmployees, apps or {}, societyMoney)
            end
        )
    end)
end

--- Shared gate for opening the MDT (both /mdt and the inventory item route
--- through this — one place decides who's allowed in).
local function HandleOpenMdt(src)
    local now = GetGameTimer()
    if MDT.Cooldowns.bossdata[src] and (now - MDT.Cooldowns.bossdata[src]) < MDT.BOSSDATA_COOLDOWN_MS then
        return
    end
    MDT.Cooldowns.bossdata[src] = now

    local Player = QBCore.Functions.GetPlayer(src)

    if not MDT.IsEmployee(Player) then
        if Player then
            TriggerClientEvent('QBCore:Notify', src, 'You are not authorized to access this device.', 'error')
        end
        return
    end

    if MDT.IsSuspended(Player.PlayerData.citizenid) then
        TriggerClientEvent('QBCore:Notify', src, 'Your MDT access has been suspended by Command.', 'error')
        return
    end

    if not Player.Functions.GetItemByName(MDT.ITEM) then
        TriggerClientEvent('QBCore:Notify', src, 'You need the MDT tablet in your inventory to do that.', 'error')
        return
    end

    -- Convenience "clock in": using the tablet while off-duty clocks you on
    -- automatically instead of refusing — only ever turns duty ON.
    if not Player.PlayerData.job.onduty then
        Player.Functions.SetJobDuty(true)
        TriggerClientEvent('QBCore:Notify', src, 'Clocked in for duty.', 'success')
    end

    -- NOTE: opening/closing the tablet is intentionally never logged
    -- (in-app or Discord) — only the actions inside it that matter.
    MDT.SendBossData(src)
end

RegisterNetEvent('police:server:GetBossData', function()
    HandleOpenMdt(source)
end)

QBCore.Functions.CreateUseableItem(MDT.ITEM, function(itemSource)
    HandleOpenMdt(itemSource)
end)

--- Dashboard "Clock Out" button. Clocking IN is automatic (see above).
RegisterNetEvent('police:server:ClockOut', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsEmployee(Player) then return end

    Player.Functions.SetJobDuty(false)
    TriggerClientEvent('QBCore:Notify', src, 'You are now off duty.', 'primary')
end)
