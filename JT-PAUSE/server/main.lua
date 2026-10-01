local QBCore = exports['qb-core']:GetCoreObject()
local RESOURCE = GetCurrentResourceName()
local UPDATES_FILE = 'updates.json'
local L = GetLocale()

-- ════════════════════════════════════════════════════════════
--  Helpers
-- ════════════════════════════════════════════════════════════
local function IsAdmin(src)
    if type(Config.AdminAce) == 'string' and IsPlayerAceAllowed(src, Config.AdminAce) then
        return true
    end
    for permission, enabled in pairs(Config.AdminPermissions) do
        if enabled and QBCore.Functions.HasPermission(src, permission) then
            return true
        end
    end
    return false
end

-- Trims, strips control characters and cuts a string to `max` characters (UTF-8 safe).
local function CleanText(value, max)
    if type(value) ~= 'string' and type(value) ~= 'number' then return nil end
    local text = tostring(value):gsub('%c', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    if text == '' then return nil end
    local ok, length = pcall(utf8.len, text)
    if not ok or not length then return nil end
    if length > max then
        text = text:sub(1, utf8.offset(text, max + 1) - 1)
    end
    return text
end

local function CleanList(list, maxItems, maxLength)
    local out = {}
    if type(list) ~= 'table' then return out end
    for _, line in ipairs(list) do
        local text = CleanText(line, maxLength)
        if text then
            out[#out + 1] = text
            if #out >= maxItems then break end
        end
    end
    return out
end

-- ════════════════════════════════════════════════════════════
--  Updates storage (read from disk once, kept in memory)
-- ════════════════════════════════════════════════════════════
local Updates = { list = {}, revision = 1 }
local idCounter = 0

local function NewUpdateId()
    idCounter = idCounter + 1
    return ('u%d%02d'):format(os.time(), idCounter % 100)
end

local function SaveUpdates()
    SaveResourceFile(RESOURCE, UPDATES_FILE, json.encode(Updates.list, { indent = true }), -1)
end

local function LoadUpdates()
    local raw = LoadResourceFile(RESOURCE, UPDATES_FILE)
    local ok, decoded = pcall(json.decode, raw or '[]')
    if not ok or type(decoded) ~= 'table' then
        if raw and raw ~= '' then
            print(('^3[%s]^7 %s is not valid JSON, starting with an empty changelog.'):format(RESOURCE, UPDATES_FILE))
        end
        decoded = {}
    end

    local list, changed = {}, false
    for _, entry in ipairs(decoded) do
        if type(entry) == 'table' and entry.version and entry.title then
            if not entry.id then
                entry.id = NewUpdateId()
                changed = true
            end
            list[#list + 1] = {
                id = tostring(entry.id),
                version = tostring(entry.version),
                title = tostring(entry.title),
                date = entry.date and tostring(entry.date) or '',
                added = CleanList(entry.added, 50, 300),
                removed = CleanList(entry.removed, 50, 300),
            }
        end
    end

    Updates.list = list
    if changed then SaveUpdates() end
end

local function BumpRevision()
    Updates.revision = Updates.revision + 1
    TriggerClientEvent('jt-pause:client:updatesChanged', -1, Updates.revision)
end

LoadUpdates()

-- ════════════════════════════════════════════════════════════
--  Server status (cached so many players opening the menu stays cheap)
-- ════════════════════════════════════════════════════════════
local statusCache = { time = -math.huge, data = nil }
local maxPlayers = GetConvarInt('sv_maxclients', 48)

local function IsJob(job, names, types)
    return names[job.name] == true or (job.type ~= nil and types[job.type] == true)
end

local function GetStatus()
    local now = GetGameTimer()
    if statusCache.data and now - statusCache.time < Config.StatusCacheTime then
        return statusCache.data
    end

    local police, ems = 0, 0
    for _, player in pairs(QBCore.Functions.GetQBPlayers()) do
        local job = player and player.PlayerData and player.PlayerData.job
        if job and job.name and (job.onduty or Config.CountOffDuty) then
            if IsJob(job, Config.PoliceJobs, Config.PoliceJobTypes) then
                police = police + 1
            elseif IsJob(job, Config.EMSJobs, Config.EMSJobTypes) then
                ems = ems + 1
            end
        end
    end

    local robberies = {}
    for _, robbery in ipairs(Config.Robberies) do
        robberies[robbery.id] = police >= (tonumber(robbery.minPolice) or 0)
    end

    statusCache.time = now
    statusCache.data = {
        players = #GetPlayers(),
        maxPlayers = maxPlayers,
        police = { active = police > 0, count = Config.ShowServiceCounts and police or nil },
        ems = { active = ems > 0, count = Config.ShowServiceCounts and ems or nil },
        robberies = robberies,
    }
    return statusCache.data
end

QBCore.Functions.CreateCallback('jt-pause:server:getData', function(source, cb, knownRevision)
    local status = GetStatus()
    local response = {
        players = status.players,
        maxPlayers = status.maxPlayers,
        police = status.police,
        ems = status.ems,
        robberies = status.robberies,
        isAdmin = IsAdmin(source),
        revision = Updates.revision,
    }
    -- The changelog is only sent when the client does not have the latest copy.
    if knownRevision ~= Updates.revision then
        response.updates = Updates.list
    end
    cb(response)
end)

-- ════════════════════════════════════════════════════════════
--  Admin: publish / delete updates
-- ════════════════════════════════════════════════════════════
local function Result(src, ok, key)
    TriggerClientEvent('jt-pause:client:result', src, ok, key)
end

QBCore.Commands.Add(Config.UpdateCommand, L.cmd_update_help, {}, false, function(source)
    if IsAdmin(source) then
        TriggerClientEvent('jt-pause:client:openPublish', source)
    else
        TriggerClientEvent('QBCore:Notify', source, L.no_permission, 'error')
    end
end, 'admin')

RegisterNetEvent('jt-pause:server:publishUpdate', function(payload)
    local src = source
    if not IsAdmin(src) then
        print(('^1[%s]^7 %s (%s) tried to publish an update without permission.'):format(RESOURCE, GetPlayerName(src) or '?', src))
        return Result(src, false, 'no_permission')
    end
    if type(payload) ~= 'table' then return end

    local version = CleanText(payload.version, 24)
    local title = CleanText(payload.title, 80)
    if not version or not title then return Result(src, false, 'required') end

    table.insert(Updates.list, 1, {
        id = NewUpdateId(),
        version = version,
        title = title,
        date = os.date('%Y-%m-%d'),
        added = CleanList(payload.added, 30, 200),
        removed = CleanList(payload.removed, 30, 200),
    })
    while #Updates.list > Config.MaxUpdates do
        table.remove(Updates.list)
    end

    SaveUpdates()
    BumpRevision()
    Result(src, true, 'toast_published')
end)

RegisterNetEvent('jt-pause:server:deleteUpdate', function(id)
    local src = source
    if not IsAdmin(src) then return Result(src, false, 'no_permission') end
    if type(id) ~= 'string' then return end

    for index, entry in ipairs(Updates.list) do
        if entry.id == id then
            table.remove(Updates.list, index)
            SaveUpdates()
            BumpRevision()
            return Result(src, true, 'toast_deleted')
        end
    end
end)

-- ════════════════════════════════════════════════════════════
--  Quit
-- ════════════════════════════════════════════════════════════
RegisterNetEvent('jt-pause:server:quit', function()
    DropPlayer(source, Config.QuitMessage)
end)

-- ════════════════════════════════════════════════════════════
--  Stop other pause menus so two never open together
-- ════════════════════════════════════════════════════════════
local conflicting = {}
for _, name in ipairs(Config.ConflictingResources or {}) do
    if name ~= RESOURCE then conflicting[name] = true end
end

local function StopConflicting(name)
    if not conflicting[name] then return end
    local state = GetResourceState(name)
    if state == 'started' or state == 'starting' then
        print(('^3[%s]^7 Stopping %s so two pause menus do not open together.'):format(RESOURCE, name))
        StopResource(name)
    end
end

CreateThread(function()
    for name in pairs(conflicting) do StopConflicting(name) end
end)

AddEventHandler('onResourceStart', function(name)
    if conflicting[name] then
        SetTimeout(0, function() StopConflicting(name) end)
    end
end)
