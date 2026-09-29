--[[
    server/dashboard.lua
    Opening the tablet (item + job + suspension gate) and building the main
    data payload (roster, applications, treasury, alert state, EMS points).
]]

local QBCore = MDT.QBCore
local POINTS_KEY = (Config.Points and Config.Points.MetadataKey) or 'ambulancepoints'

local function pointsOf(metadata)
    if not (Config.Points and Config.Points.Enabled) then return nil end
    return tonumber(metadata and metadata[POINTS_KEY]) or 0
end

function MDT.SendBossData(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local isCommandStaff = MDT.IsSeniorCommand(Player)
    local isBossFlag = MDT.IsBoss(Player)
    local selfOnDuty = Player.PlayerData.job.onduty == true

    local employees = {}
    local addedCitizens = {}

    for _, v in pairs(QBCore.Functions.GetQBPlayers()) do
        if v and v.PlayerData.job.name == Config.JobName then
            local citizenid = v.PlayerData.citizenid
            if not addedCitizens[citizenid] then
                addedCitizens[citizenid] = true
                employees[#employees + 1] = {
                    name = MDT.GetName(v), citizenid = citizenid, cid = citizenid,
                    grade = v.PlayerData.job.grade, onduty = v.PlayerData.job.onduty,
                    suspended = MDT.IsSuspended(citizenid),
                    points = pointsOf(v.PlayerData.metadata),
                }
            end
        end
    end

    local function finalizePayload(offlineEmployees, applications, societyMoney)
        for _, emp in ipairs(offlineEmployees) do employees[#employees + 1] = emp end

        local activeCount = 0
        for _, emp in ipairs(employees) do
            if emp.onduty == true then activeCount = activeCount + 1 end
        end

        TriggerClientEvent('ems-mdt:client:OpenBossMenuUI', src, {
            selfName = MDT.GetName(Player),
            selfGrade = Player.PlayerData.job.grade.name or 'Paramedic',
            selfGradeLevel = Player.PlayerData.job.grade.level or 0,
            selfCitizenId = Player.PlayerData.citizenid, selfOnDuty = selfOnDuty,
            selfPoints = pointsOf(Player.PlayerData.metadata),
            isCommandStaff = isCommandStaff, isBoss = isBossFlag,
            minCommandGrade = MDT.MIN_COMMAND_GRADE,
            isLockdown = MDT.State.lockdown, alertLevel = MDT.State.alertLevel,
            money = isCommandStaff and societyMoney or nil,
            employees = employees, applications = isCommandStaff and (applications or {}) or {},
            onDutyCount = activeCount,
            selfServerId = src,
            selfCallsign = MDT.Hub.GetCallsign(Player),
            selfStatus = selfOnDuty and MDT.Hub.GetStatus(src) or 'off',
            canManageDispatch = MDT.Hub.CanManageDispatch(Player)
        })
    end

    -- Only offline players whose job is this department (JSON filter, not the whole table).
    exports.oxmysql:execute(
        "SELECT citizenid, charinfo, job, metadata FROM players WHERE JSON_UNQUOTE(JSON_EXTRACT(job, '$.name')) = ?",
        { Config.JobName },
        function(dbResult)
            local offlineEmployees = {}
            for _, v in pairs(dbResult or {}) do
                if not addedCitizens[v.citizenid] then
                    addedCitizens[v.citizenid] = true
                    local jobData = json.decode(v.job or '{}') or {}
                    if jobData.name == Config.JobName then
                        local ci = json.decode(v.charinfo or '{}') or {}
                        local meta = json.decode(v.metadata or '{}') or {}
                        offlineEmployees[#offlineEmployees + 1] = {
                            name = (ci.firstname or 'Unknown') .. ' ' .. (ci.lastname or ''),
                            citizenid = v.citizenid, cid = v.citizenid,
                            grade = jobData.grade or { name = 'Employee', level = 0 }, onduty = 'out',
                            suspended = MDT.IsSuspended(v.citizenid),
                            points = pointsOf(meta),
                        }
                    end
                end
            end

            if not isCommandStaff then
                finalizePayload(offlineEmployees, nil, nil)
                return
            end

            local societyMoney = MDT.GetSocietyMoney()
            exports.oxmysql:execute(
                'SELECT id, citizenid, applicant_name, applicant_age, experience, contact, status, created_at FROM ' ..
                MDT.Tables.Applications .. ' ORDER BY created_at DESC LIMIT ?',
                { Config.MaxApplicationsShown or 20 },
                function(apps) finalizePayload(offlineEmployees, apps or {}, societyMoney) end
            )
        end)
end

--- One gate for opening the tablet (command + inventory item).
local function HandleOpenMdt(src)
    local now = GetGameTimer()
    if MDT.Cooldowns.bossdata[src] and (now - MDT.Cooldowns.bossdata[src]) < MDT.BOSSDATA_COOLDOWN_MS then
        return
    end
    MDT.Cooldowns.bossdata[src] = now

    local Player = QBCore.Functions.GetPlayer(src)

    if not MDT.IsEmployee(Player) then
        if Player then
            TriggerClientEvent('QBCore:Notify', src, 'This device is for EMS personnel only.', 'error')
        end
        return
    end

    if MDT.IsSuspended(Player.PlayerData.citizenid) then
        TriggerClientEvent('QBCore:Notify', src, 'Your tablet access has been suspended by Command.', 'error')
        return
    end

    if not Player.Functions.GetItemByName(MDT.ITEM) then
        TriggerClientEvent('QBCore:Notify', src, 'You need the EMS tablet in your inventory to do that.', 'error')
        return
    end

    if Config.Hub.AutoClockIn and not Player.PlayerData.job.onduty then
        MDT.Hub.SetDuty(src, true)
    end

    MDT.SendBossData(src)
end

RegisterNetEvent('ems-mdt:server:GetBossData', function()
    HandleOpenMdt(source)
end)

QBCore.Functions.CreateUseableItem(MDT.ITEM, function(itemSource)
    HandleOpenMdt(itemSource)
end)
