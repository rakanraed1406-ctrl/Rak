--[[
    server/_shared.lua — loaded FIRST. Shared MDT namespace: QBCore object,
    config-derived constants, cooldown tables, department state, permission
    helpers, logging (DB + curated Discord webhook), and dispatch calls
    (sk1-hub only). Other files:
      server/dashboard.lua - opening the MDT, main payload, clock out
      server/cameras.lua   - CCTV access
      server/personnel.lua - hire/fire/promote/demote/suspend + history
      server/treasury.lua  - department bank
      server/recruitment.lua - job applications
      server/reports.lua   - Reports app
      server/directives.lua - Directives app
      server/map.lua       - officer feed + tactical markers
      server/bodycam.lua   - qb-bodycam integration
      server/bolo.lua      - BOLO board
      server/vehicles.lua  - plate lookup
      server/tactical.lua  - lockdown / GPS toggle / Code 99
      server/dispatch.lua  - dispatch calls via sk1-hub only
      server/wanted.lua    - Most Wanted Top 10
]]

MDT = {}
MDT.QBCore = exports['qb-core']:GetCoreObject()
MDT.MIN_COMMAND_GRADE = Config.MinCommandGrade or 9

function MDT.SafeTableName(name, fallback)
    if type(name) == 'string' and name:match('^[%w_]+$') then return name end
    return fallback
end

MDT.Tables = {
    Reports = MDT.SafeTableName(Config.ReportsTable, 'police_reports'),
    Directives = MDT.SafeTableName(Config.DirectivesTable, 'police_directives'),
    Logs = MDT.SafeTableName(Config.MdtLogsTable, 'police_mdt_logs'),
    Bolos = MDT.SafeTableName(Config.BolosTable, 'police_bolos'),
    Vehicles = MDT.SafeTableName(Config.PlayerVehiclesTable, 'player_vehicles'),
    Suspended = 'police_suspended',
    Wanted = 'police_wanted'
}

MDT.ITEM = Config.MdtItem or 'mdt'

MDT.REPORT_TYPES = {
    ['General'] = true, ['Arrest'] = true, ['Incident'] = true,
    ['Traffic Stop'] = true, ['Investigation'] = true,
    ['Use of Force'] = true, ['Other'] = true
}
MDT.BOLO_PRIORITIES = { ['low'] = true, ['normal'] = true, ['high'] = true }

MDT.Cooldowns = {
    report = {}, directive = {}, bolo = {}, unitsAlert = {}, marker = {},
    bossdata = {}
}
MDT.COOLDOWN_SECONDS = {
    report = 8, directive = 5, bolo = 6, unitsAlert = 20,
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
    return MDT.IsEmployee(Player) and Player.PlayerData.job.grade.level >= MDT.MIN_COMMAND_GRADE
end

function MDT.IsSuspended(citizenid)
    return MDT.State.suspended[citizenid] == true
end

function MDT.NotifyAllPolice(message, notifyType)
    local players = MDT.QBCore.Functions.GetQBPlayers()
    for _, v in pairs(players) do
        if v and v.PlayerData.job.name == Config.JobName then
            TriggerClientEvent('QBCore:Notify', v.PlayerData.source, message, notifyType or 'primary', 5000)
        end
    end
end

-- Curated "important only" whitelist for the Discord webhook — everything
-- NOT in this list (opening/closing the tablet, filing reports, posting
-- BOLOs, viewing cameras, treasury moves) stays in the in-app DB log only.
MDT.DISCORD_ACTIONS = {
    ['Promoted Officer'] = 3066993, ['Demoted Officer'] = 15105570,
    ['Terminated Officer'] = 15158332, ['Hired Officer (Manual)'] = 3066993,
    ['Recruited Nearby Civilian'] = 3066993, ['Suspended Officer'] = 15158332,
    ['Lifted Suspension'] = 3066993, ['Toggled Facility Lockdown'] = 15105570,
    ['Requested Global Backup (Code 99)'] = 15158332,
    ['Sent Emergency Broadcast'] = 15158332, ['Changed Alert Level'] = 15105570,
    ['Sent All-Units Alert'] = 15105570, ['Added Most Wanted Entry'] = 15158332,
}

function MDT.SendDiscordLog(Player, action, details, color)
    local webhook = Config.DiscordWebhook
    if not webhook or webhook == '' then return end
    local charinfo = Player and Player.PlayerData.charinfo
    local name = Player and ((charinfo and charinfo.firstname or 'Unknown') .. ' ' .. (charinfo and charinfo.lastname or '')) or 'System'
    local citizenid = (Player and Player.PlayerData.citizenid) or 'N/A'

    local payload = {
        username = Config.DiscordWebhookName or 'MDT Log',
        avatar_url = (Config.DiscordWebhookAvatar ~= '' and Config.DiscordWebhookAvatar) or nil,
        embeds = {{
            title = action, description = tostring(details or '—'):sub(1, 1000), color = color or 3447003,
            fields = { { name = 'Officer', value = name, inline = true }, { name = 'Citizen ID', value = citizenid, inline = true } },
            footer = { text = 'Police MDT' }, timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
        }}
    }
    PerformHttpRequest(webhook, function() end, 'POST', json.encode(payload), { ['Content-Type'] = 'application/json' })
end

--- Writes to the in-app audit trail (Personnel History) and, for a curated
--- whitelist only, also pushes a Discord embed. Opening/closing the tablet
--- is never logged anywhere, by design.
function MDT.LogMdtAction(Player, action, details)
    if not Player then return end
    local charinfo = Player.PlayerData.charinfo
    local name = (charinfo and charinfo.firstname or 'Unknown') .. ' ' .. (charinfo and charinfo.lastname or '')
    exports.oxmysql:execute(
        'INSERT INTO ' .. MDT.Tables.Logs .. ' (citizenid, officer_name, action, details) VALUES (?, ?, ?, ?)',
        { Player.PlayerData.citizenid, name, tostring(action):sub(1, 100), tostring(details or ''):sub(1, 255) }
    )
    if MDT.DISCORD_ACTIONS[action] then
        MDT.SendDiscordLog(Player, action, details, MDT.DISCORD_ACTIONS[action])
    end
end

function MDT.GetSocietyMoney(jobName)
    local result = exports.oxmysql:executeSync('SELECT amount FROM police_funds WHERE job_name = ?', { jobName })
    if result and result[1] then return tonumber(result[1].amount) or 0 end
    exports.oxmysql:execute('INSERT IGNORE INTO police_funds (job_name, amount) VALUES (?, ?)', { jobName, 0 })
    return 0
end

function MDT.CheckCooldown(bucket, citizenid)
    local now = os.time()
    local last = MDT.Cooldowns[bucket][citizenid]
    local seconds = MDT.COOLDOWN_SECONDS[bucket] or 5
    if last and (now - last) < seconds then return false end
    MDT.Cooldowns[bucket][citizenid] = now
    return true
end

--- Sends a call through the configured dispatch resource — sk1-hub ONLY
--- (exports['sk1-hub']:CreateDispatchCall, per the files you sent). No
--- other dispatch script is used anywhere in this resource.
function MDT.SendDispatchCall(deptName, callData)
    local resourceName = Config.DispatchResource
    if not resourceName or resourceName == '' or GetResourceState(resourceName) ~= 'started' then return end
    local ok = pcall(function() exports[resourceName]:CreateDispatchCall(deptName, callData) end)
    if not ok then
        print(('[MDT] Failed to send a dispatch call via "%s" — check Config.DispatchResource.'):format(resourceName))
    end
end

CreateThread(function()
    exports.oxmysql:execute([[CREATE TABLE IF NOT EXISTS ]] .. MDT.Tables.Reports .. [[ (
        `id` INT NOT NULL AUTO_INCREMENT, `citizenid` VARCHAR(50) NOT NULL, `author_name` VARCHAR(100) NOT NULL,
        `report_type` VARCHAR(50) NOT NULL DEFAULT 'General', `title` VARCHAR(150) NOT NULL,
        `involved` VARCHAR(255) DEFAULT NULL, `details` TEXT NOT NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (`id`)) ]])

    exports.oxmysql:execute([[CREATE TABLE IF NOT EXISTS ]] .. MDT.Tables.Directives .. [[ (
        `id` INT NOT NULL AUTO_INCREMENT, `title` VARCHAR(150) NOT NULL, `body` TEXT NOT NULL,
        `priority` VARCHAR(20) NOT NULL DEFAULT 'normal', `posted_by` VARCHAR(100) NOT NULL,
        `posted_by_cid` VARCHAR(50) NOT NULL, `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`)) ]])

    exports.oxmysql:execute([[CREATE TABLE IF NOT EXISTS ]] .. MDT.Tables.Logs .. [[ (
        `id` INT NOT NULL AUTO_INCREMENT, `citizenid` VARCHAR(50) NOT NULL, `officer_name` VARCHAR(100) NOT NULL,
        `action` VARCHAR(100) NOT NULL, `details` VARCHAR(255) DEFAULT NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (`id`)) ]])

    exports.oxmysql:execute([[CREATE TABLE IF NOT EXISTS ]] .. MDT.Tables.Bolos .. [[ (
        `id` INT NOT NULL AUTO_INCREMENT, `citizenid` VARCHAR(50) NOT NULL, `author_name` VARCHAR(100) NOT NULL,
        `subject_name` VARCHAR(150) DEFAULT NULL, `subject_desc` VARCHAR(255) DEFAULT NULL,
        `vehicle_plate` VARCHAR(20) DEFAULT NULL, `reason` TEXT NOT NULL, `priority` VARCHAR(20) NOT NULL DEFAULT 'normal',
        `active` TINYINT(1) NOT NULL DEFAULT 1, `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`)) ]])

    exports.oxmysql:execute([[CREATE TABLE IF NOT EXISTS ]] .. MDT.Tables.Suspended .. [[ (
        `citizenid` VARCHAR(50) NOT NULL, `suspended_by` VARCHAR(100) NOT NULL, `reason` VARCHAR(255) DEFAULT NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (`citizenid`)) ]])

    exports.oxmysql:execute([[CREATE TABLE IF NOT EXISTS ]] .. MDT.Tables.Wanted .. [[ (
        `id` INT NOT NULL AUTO_INCREMENT, `name` VARCHAR(100) NOT NULL, `charges` VARCHAR(500) NOT NULL,
        `danger_level` VARCHAR(20) NOT NULL DEFAULT 'Medium', `last_seen` VARCHAR(150) DEFAULT NULL,
        `reward` INT NOT NULL DEFAULT 0, `posted_by` VARCHAR(100) NOT NULL, `posted_by_cid` VARCHAR(50) NOT NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (`id`)) ]])

    exports.oxmysql:execute('SELECT citizenid FROM ' .. MDT.Tables.Suspended, {}, function(rows)
        for _, row in pairs(rows or {}) do MDT.State.suspended[row.citizenid] = true end
    end)
end)

AddEventHandler('playerDropped', function()
    local src = source
    MDT.Cooldowns.bossdata[src] = nil
    local Player = MDT.QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local citizenid = Player.PlayerData.citizenid
    MDT.Cooldowns.report[citizenid] = nil
    MDT.Cooldowns.directive[citizenid] = nil
    MDT.Cooldowns.bolo[citizenid] = nil
    MDT.Cooldowns.unitsAlert[citizenid] = nil
    MDT.Cooldowns.marker[citizenid] = nil
end)
