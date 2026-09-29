--[[
    server/_shared.lua — loaded FIRST. Shared EMS MDT namespace: QBCore object,
    config-derived constants, cooldowns, department state, permission helpers,
    logging (DB + curated Discord webhook), treasury, dispatch entry point.
      server/dashboard.lua   - opening the tablet, main payload
      server/cameras.lua     - hospital CCTV access
      server/personnel.lua   - hire/fire/promote/demote/suspend/history + EMS points
      server/treasury.lua    - department bank
      server/recruitment.lua - job applications
      server/reports.lua     - Medical reports (patient care reports)
      server/directives.lua  - Directives / protocols from Command
      server/map.lua         - live medic feed + map pins
      server/ward.lua        - Ward board (admitted patients)
      server/patients.lua    - Patient records (search, medical notes, live condition)
      server/billing.lua     - Medical bills
      server/tactical.lua    - GPS tracking / hospital lockdown / MCI all-units
      server/hub.lua         - Hub (roster, duty, callsign, status, panic, chat)
      server/dispatch.lua    - Dispatch / CAD (calls, priorities, notifications, /997)
      server/alerts.lua      - automatic alerts (crashes) + hospital (qb-hospital) alerts
]]

MDT = {}
MDT.QBCore = exports['qb-core']:GetCoreObject()
MDT.MIN_COMMAND_GRADE = Config.MinCommandGrade or 9
MDT.RESOURCE = GetCurrentResourceName()

function MDT.SafeTableName(name, fallback)
    if type(name) == 'string' and name:match('^[%w_]+$') then return name end
    return fallback
end

local T = Config.Tables or {}
MDT.Tables = {
    Reports = MDT.SafeTableName(T.Reports, 'ems_reports'),
    Directives = MDT.SafeTableName(T.Directives, 'ems_directives'),
    Logs = MDT.SafeTableName(T.Logs, 'ems_mdt_logs'),
    Ward = MDT.SafeTableName(T.Ward, 'ems_ward_board'),
    Suspended = MDT.SafeTableName(T.Suspended, 'ems_suspended'),
    Patients = MDT.SafeTableName(T.Patients, 'ems_patients'),
    Bills = MDT.SafeTableName(T.Bills, 'ems_bills'),
    Funds = MDT.SafeTableName(T.Funds, 'ems_funds'),
    Applications = MDT.SafeTableName(T.Applications, 'ems_applications'),
}

MDT.ITEM = Config.MdtItem or 'ems_tablet'

MDT.REPORT_TYPES = {
    ['Treatment'] = true, ['Revive'] = true, ['Transport'] = true, ['Surgery'] = true,
    ['Check-up'] = true, ['Death'] = true, ['Mass Casualty'] = true, ['Other'] = true
}
MDT.WARD_CONDITIONS = { ['stable'] = true, ['serious'] = true, ['critical'] = true }

MDT.Cooldowns = {
    report = {}, directive = {}, ward = {}, unitsAlert = {}, marker = {}, bill = {}, notes = {},
    search = {}, mci = {}, bossdata = {}
}
MDT.COOLDOWN_SECONDS = {
    report = 8, directive = 5, ward = 4, unitsAlert = 20, bill = 5, notes = 3, search = 1, mci = 30,
    marker = (Config.MapMarkerCooldownMs or 1000) / 1000
}
MDT.BOSSDATA_COOLDOWN_MS = 1200

MDT.State = { lockdown = false, alertLevel = 'green', suspended = {} }
MDT.MapMarkers = {}
MDT.NextMarkerId = 1

function MDT.IsEmployee(Player)
    return Player ~= nil and Player.PlayerData.job.name == Config.JobName
end

function MDT.IsBoss(Player)
    return Player ~= nil and Player.PlayerData.job.name == Config.JobName and Player.PlayerData.job.isboss == true
end

function MDT.IsSeniorCommand(Player)
    return MDT.IsEmployee(Player) and (tonumber(Player.PlayerData.job.grade.level) or 0) >= MDT.MIN_COMMAND_GRADE
end

function MDT.IsSuspended(citizenid)
    return MDT.State.suspended[citizenid] == true
end

function MDT.NotifyAllEms(message, notifyType)
    for _, v in pairs(MDT.QBCore.Functions.GetQBPlayers()) do
        if v and v.PlayerData.job.name == Config.JobName then
            TriggerClientEvent('QBCore:Notify', v.PlayerData.source, message, notifyType or 'primary', 5000)
        end
    end
end

-- Curated "important only" whitelist for the Discord webhook.
MDT.DISCORD_ACTIONS = {
    ['Promoted Medic'] = 3066993, ['Demoted Medic'] = 15105570,
    ['Terminated Medic'] = 15158332, ['Hired Medic (Manual)'] = 3066993,
    ['Recruited Nearby Civilian'] = 3066993, ['Suspended Medic'] = 15158332,
    ['Lifted Suspension'] = 3066993, ['Toggled Hospital Lockdown'] = 15105570,
    ['Declared Mass Casualty (MCI)'] = 15158332,
    ['Sent Emergency Broadcast'] = 15158332, ['Changed Alert Level'] = 15105570,
    ['Sent All-Units Alert'] = 15105570, ['Medic Panic (10-99)'] = 15158332,
    ['Changed EMS Points'] = 3447003, ['Treasury Withdrawal'] = 15105570,
}

function MDT.SendDiscordLog(Player, action, details, color)
    local webhook = Config.DiscordWebhook
    if not webhook or webhook == '' then return end
    local name = Player and MDT.GetName(Player) or 'System'
    local citizenid = (Player and Player.PlayerData.citizenid) or 'N/A'

    local payload = {
        username = Config.DiscordWebhookName or 'EMS MDT Log',
        avatar_url = (Config.DiscordWebhookAvatar ~= '' and Config.DiscordWebhookAvatar) or nil,
        embeds = {{
            title = action, description = tostring(details or '—'):sub(1, 1000), color = color or 3447003,
            fields = { { name = 'Medic', value = name, inline = true }, { name = 'Citizen ID', value = citizenid, inline = true } },
            footer = { text = 'EMS MDT' }, timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
        }}
    }
    PerformHttpRequest(webhook, function() end, 'POST', json.encode(payload), { ['Content-Type'] = 'application/json' })
end

--- In-app audit trail (Personnel History) + Discord for the curated list.
function MDT.LogMdtAction(Player, action, details)
    if not Player then return end
    exports.oxmysql:execute(
        'INSERT INTO ' .. MDT.Tables.Logs .. ' (citizenid, medic_name, action, details) VALUES (?, ?, ?, ?)',
        { Player.PlayerData.citizenid, MDT.GetName(Player), tostring(action):sub(1, 100), tostring(details or ''):sub(1, 255) }
    )
    if MDT.DISCORD_ACTIONS[action] then
        MDT.SendDiscordLog(Player, action, details, MDT.DISCORD_ACTIONS[action])
    end
end

-- ---------------------------------------------------------------------------
-- Treasury (own table, same idea as the police tablet)
-- ---------------------------------------------------------------------------

function MDT.GetSocietyMoney()
    local result = exports.oxmysql:executeSync('SELECT amount FROM ' .. MDT.Tables.Funds .. ' WHERE job_name = ?', { Config.JobName })
    if result and result[1] then return tonumber(result[1].amount) or 0 end
    exports.oxmysql:execute('INSERT IGNORE INTO ' .. MDT.Tables.Funds .. ' (job_name, amount) VALUES (?, ?)', { Config.JobName, 0 })
    return 0
end

function MDT.AddSocietyMoney(amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return end
    exports.oxmysql:execute(
        'INSERT INTO ' .. MDT.Tables.Funds .. ' (job_name, amount) VALUES (?, ?) ON DUPLICATE KEY UPDATE amount = amount + VALUES(amount)',
        { Config.JobName, amount })
end

function MDT.CheckCooldown(bucket, citizenid)
    local now = os.time()
    local last = MDT.Cooldowns[bucket][citizenid]
    local seconds = MDT.COOLDOWN_SECONDS[bucket] or 5
    if last and (now - last) < seconds then return false end
    MDT.Cooldowns[bucket][citizenid] = now
    return true
end

--- Sends a call through the built-in dispatch (server/dispatch.lua).
function MDT.SendDispatchCall(deptName, callData)
    if MDT.Dispatch and MDT.Dispatch.Create then
        return MDT.Dispatch.Create(callData, deptName)
    end
end

function MDT.GetName(Player)
    local ci = Player and Player.PlayerData.charinfo
    return ((ci and ci.firstname or 'Unknown') .. ' ' .. (ci and ci.lastname or '')):gsub('%s+$', '')
end

function MDT.HasTablet(Player)
    return Player ~= nil and Player.Functions.GetItemByName(MDT.ITEM) ~= nil
end

function MDT.IsCleanText(text)
    if type(text) ~= 'string' then return false end
    local lower = text:lower()
    for _, pattern in ipairs((Config.Hub and Config.Hub.BlockedPatterns) or {}) do
        if lower:find(pattern) then return false end
    end
    return true
end

--- Trim + cap a client string. Returns '' for non-strings.
function MDT.Clean(value, max)
    if type(value) ~= 'string' and type(value) ~= 'number' then return '' end
    return (tostring(value):sub(1, max or 255):gsub('^%s+', ''):gsub('%s+$', ''))
end

function MDT.PedCoords(src)
    local ped = GetPlayerPed(src)
    local c = (ped and ped ~= 0) and GetEntityCoords(ped) or vector3(0.0, 0.0, 0.0)
    return { x = c.x, y = c.y, z = c.z }
end

CreateThread(function()
    local q = exports.oxmysql

    q:execute([[CREATE TABLE IF NOT EXISTS ]] .. MDT.Tables.Reports .. [[ (
        `id` INT NOT NULL AUTO_INCREMENT, `citizenid` VARCHAR(50) NOT NULL, `author_name` VARCHAR(100) NOT NULL,
        `report_type` VARCHAR(50) NOT NULL DEFAULT 'Treatment', `title` VARCHAR(150) NOT NULL,
        `patient_name` VARCHAR(100) DEFAULT NULL, `patient_cid` VARCHAR(50) DEFAULT NULL,
        `involved` VARCHAR(255) DEFAULT NULL, `details` TEXT NOT NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (`id`), KEY `patient_cid` (`patient_cid`)) ]])

    q:execute([[CREATE TABLE IF NOT EXISTS ]] .. MDT.Tables.Directives .. [[ (
        `id` INT NOT NULL AUTO_INCREMENT, `title` VARCHAR(150) NOT NULL, `body` TEXT NOT NULL,
        `priority` VARCHAR(20) NOT NULL DEFAULT 'normal', `posted_by` VARCHAR(100) NOT NULL,
        `posted_by_cid` VARCHAR(50) NOT NULL, `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`)) ]])

    q:execute([[CREATE TABLE IF NOT EXISTS ]] .. MDT.Tables.Logs .. [[ (
        `id` INT NOT NULL AUTO_INCREMENT, `citizenid` VARCHAR(50) NOT NULL, `medic_name` VARCHAR(100) NOT NULL,
        `action` VARCHAR(100) NOT NULL, `details` VARCHAR(255) DEFAULT NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (`id`)) ]])

    q:execute([[CREATE TABLE IF NOT EXISTS ]] .. MDT.Tables.Ward .. [[ (
        `id` INT NOT NULL AUTO_INCREMENT, `citizenid` VARCHAR(50) NOT NULL, `author_name` VARCHAR(100) NOT NULL,
        `patient_name` VARCHAR(150) NOT NULL, `patient_cid` VARCHAR(50) DEFAULT NULL, `bed` VARCHAR(30) DEFAULT NULL,
        `diagnosis` VARCHAR(500) NOT NULL, `severity` VARCHAR(20) NOT NULL DEFAULT 'stable',
        `active` TINYINT(1) NOT NULL DEFAULT 1, `discharged_by` VARCHAR(100) DEFAULT NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (`id`)) ]])

    q:execute([[CREATE TABLE IF NOT EXISTS ]] .. MDT.Tables.Suspended .. [[ (
        `citizenid` VARCHAR(50) NOT NULL, `suspended_by` VARCHAR(100) NOT NULL, `reason` VARCHAR(255) DEFAULT NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (`citizenid`)) ]])

    q:execute([[CREATE TABLE IF NOT EXISTS ]] .. MDT.Tables.Patients .. [[ (
        `citizenid` VARCHAR(50) NOT NULL, `allergies` VARCHAR(500) DEFAULT NULL, `conditions` VARCHAR(500) DEFAULT NULL,
        `medications` VARCHAR(500) DEFAULT NULL, `notes` TEXT DEFAULT NULL, `updated_by` VARCHAR(100) DEFAULT NULL,
        `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, PRIMARY KEY (`citizenid`)) ]])

    q:execute([[CREATE TABLE IF NOT EXISTS ]] .. MDT.Tables.Bills .. [[ (
        `id` INT NOT NULL AUTO_INCREMENT, `citizenid` VARCHAR(50) NOT NULL, `medic_name` VARCHAR(100) NOT NULL,
        `patient_name` VARCHAR(100) NOT NULL, `patient_cid` VARCHAR(50) DEFAULT NULL, `treatment` VARCHAR(255) NOT NULL,
        `amount` INT NOT NULL DEFAULT 0, `paid` TINYINT(1) NOT NULL DEFAULT 0, `notes` VARCHAR(255) DEFAULT NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (`id`)) ]])

    q:execute([[CREATE TABLE IF NOT EXISTS ]] .. MDT.Tables.Funds .. [[ (
        `job_name` VARCHAR(50) NOT NULL, `amount` INT NOT NULL DEFAULT 0, PRIMARY KEY (`job_name`)) ]])

    q:execute([[CREATE TABLE IF NOT EXISTS ]] .. MDT.Tables.Applications .. [[ (
        `id` INT NOT NULL AUTO_INCREMENT, `citizenid` VARCHAR(50) NOT NULL, `applicant_name` VARCHAR(100) NOT NULL,
        `applicant_age` INT NOT NULL DEFAULT 18, `experience` VARCHAR(500) NOT NULL, `contact` VARCHAR(50) DEFAULT NULL,
        `status` VARCHAR(20) NOT NULL DEFAULT 'Pending', `reviewed_by` VARCHAR(50) DEFAULT NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (`id`)) ]])

    q:execute('SELECT citizenid FROM ' .. MDT.Tables.Suspended, {}, function(rows)
        for _, row in pairs(rows or {}) do MDT.State.suspended[row.citizenid] = true end
    end)
end)

AddEventHandler('playerDropped', function()
    local src = source
    MDT.Cooldowns.bossdata[src] = nil
    local Player = MDT.QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local citizenid = Player.PlayerData.citizenid
    for bucket, list in pairs(MDT.Cooldowns) do
        if bucket ~= 'bossdata' then list[citizenid] = nil end
    end
end)
