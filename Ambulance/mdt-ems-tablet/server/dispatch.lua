--[[
    server/dispatch.lua — EMS dispatch / CAD (same engine as the police tablet).

    Priorities (3 tiers, each with its own colour + sound on the client):
        low    = سهل    (BLUE)
        medium = متوسط  (YELLOW)
        high   = صعب    (RED)

    Notifications go to every medic that is on duty AND has the EMS tablet in
    their inventory (both configurable in Config.Dispatch), even while the
    tablet is closed.

    Entry points:
        MDT.Dispatch.Create(data, dept)                          -- server Lua
        exports['mdt-ems-tablet']:CreateDispatchCall('ambulance', data)
        TriggerEvent('ems-mdt:server:CreateDispatchCall', data)   -- server, no folder name needed
        TriggerEvent('ems-mdt:client:CreateDispatchCall', data)   -- client
        /997 /911ems /997a commands (+ /997r reply), qb-hospital alerts,
        and EMS-targeted cd_dispatch / ps-dispatch / qb-dispatch events
]]

local QBCore = MDT.QBCore
local DCfg = Config.Dispatch or {}

MDT.Dispatch = {
    calls = {},   -- [id] = call
    history = {}, -- closed calls, newest first
    nextId = 1001,
}
local D = MDT.Dispatch

-- Calls explicitly addressed to a police department are not ours (the police MDT takes them).
local IGNORED_DEPARTMENTS = { police = true, sheriff = true, bcso = true, sasp = true, lspd = true, state = true, trooper = true }
local EMS_JOBS = { ambulance = true, ems = true, doctor = true, fire = true, paramedic = true, medical = true, [Config.JobName] = true }
local VALID_STATUS = { pending = true, active = true, contained = true, closed = true }
local VALID_ROLE = {}
for _, r in ipairs(DCfg.UnitRoles or {}) do VALID_ROLE[r] = true end

local PRIORITY_RANK = { high = 3, medium = 2, low = 1 }

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function clean(str, max, fallback)
    if type(str) ~= 'string' and type(str) ~= 'number' then return fallback end
    str = tostring(str):gsub('[<>]', ''):gsub('^%s*(.-)%s*$', '%1')
    if str == '' then return fallback end
    return str:sub(1, max or 120)
end

--- Maps anything scripts throw at us (HIGH/NORMAL/LOW, 1/2/3, red/yellow/blue…)
--- onto low / medium / high. Config.Dispatch.CodePriority always wins.
function D.NormalizePriority(priority, code, title)
    local byCode = code and (DCfg.CodePriority or {})[tostring(code):upper()]
    if byCode and PRIORITY_RANK[byCode] then return byCode end

    if type(priority) == 'number' then
        if priority <= 1 then return 'high' elseif priority == 2 then return 'medium' else return 'low' end
    end
    if type(priority) == 'string' then
        local p = priority:lower()
        if p == 'high' or p == 'urgent' or p == 'red' or p == 'critical' or p == 'panic' or p == 'hard' then return 'high' end
        if p == 'medium' or p == 'normal' or p == 'yellow' or p == 'moderate' or p == 'important' then return 'medium' end
        if p == 'low' or p == 'blue' or p == 'info' or p == 'minor' or p == 'easy' then return 'low' end
    end

    local t = tostring(title or ''):lower()
    if t:find('pulse') or t:find('unconscious') or t:find('panic') or t:find('cardiac') or t:find('mass casualty')
        or t:find('shot') or t:find('died') or t:find('dead') or t:find('critical') then
        return 'high'
    end
    return 'medium'
end

local function coordsOf(c)
    if type(c) == 'vector3' or type(c) == 'vector4' then return { x = c.x + 0.0, y = c.y + 0.0, z = c.z + 0.0 } end
    if type(c) == 'table' and tonumber(c.x) and tonumber(c.y) then
        return { x = tonumber(c.x) + 0.0, y = tonumber(c.y) + 0.0, z = (tonumber(c.z) or 0.0) + 0.0 }
    end
    return nil
end

local function unitEntry(src, role)
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsEmployee(Player) then return nil end
    return {
        source = src,
        citizenid = Player.PlayerData.citizenid,
        callsign = MDT.Hub.GetCallsign(Player),
        name = MDT.GetName(Player),
        role = (role and VALID_ROLE[role]) and role or (role or 'Awaiting role'),
    }
end

local function findUnit(call, src)
    for i, u in ipairs(call.units) do
        if u.source == src then return i, u end
    end
end

--- Medics that should get dispatch notifications (duty + tablet item, per config).
function D.IsEligible(Player)
    if not MDT.IsEmployee(Player) then return false end
    if DCfg.RequireDutyForAlerts ~= false and not Player.PlayerData.job.onduty then return false end
    if DCfg.RequireItemForAlerts ~= false and not MDT.HasTablet(Player) then return false end
    if MDT.IsSuspended(Player.PlayerData.citizenid) then return false end
    return true
end

function D.ForEachEligible(fn)
    for _, v in pairs(QBCore.Functions.GetQBPlayers()) do
        if v and D.IsEligible(v) then fn(v.PlayerData.source, v) end
    end
end

local function publicCall(call)
    if not call.callerSource and not call.patientSource then return call end
    local copy = {}
    for k, v in pairs(call) do copy[k] = v end
    copy.callerSource = nil  -- keeps anonymous callers anonymous
    copy.patientSource = nil
    return copy
end

local function sortedActive()
    local list = {}
    for _, c in pairs(D.calls) do list[#list + 1] = publicCall(c) end
    table.sort(list, function(a, b)
        local pa, pb = PRIORITY_RANK[a.priority] or 0, PRIORITY_RANK[b.priority] or 0
        if pa ~= pb then return pa > pb end
        return a.createdAt > b.createdAt
    end)
    return list
end

--- Sends the whole CAD state to one medic (only if they have the tablet open).
function D.SyncTo(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsEmployee(Player) then return end
    TriggerClientEvent('ems-mdt:client:DispatchSync', src, {
        calls = sortedActive(),
        history = (function()
            local list = {}
            for i, c in ipairs(D.history) do list[i] = publicCall(c) end
            return list
        end)(),
        serverTime = os.time(),
        canManage = MDT.Hub.CanManageDispatch(Player),
        roles = DCfg.UnitRoles or {},
    })
end

function D.Broadcast()
    for src in pairs(MDT.Hub.sessions) do D.SyncTo(src) end
    -- Everyone eligible also gets a light count so the dock badge / HUD stays right.
    local count = 0
    for _ in pairs(D.calls) do count = count + 1 end
    D.ForEachEligible(function(src)
        TriggerClientEvent('ems-mdt:client:DispatchCount', src, count)
    end)
end

local function touch(call) call.updatedAt = os.time() end

local function archive(call, closedBy)
    call.status = 'closed'
    call.closedAt = os.time()
    call.closedBy = closedBy
    D.calls[call.id] = nil
    table.insert(D.history, 1, call)
    while #D.history > (DCfg.MaxHistory or 40) do table.remove(D.history) end
end

-- ---------------------------------------------------------------------------
-- Create
-- ---------------------------------------------------------------------------

function D.Create(data, dept)
    if type(data) ~= 'table' then return nil end
    if type(dept) == 'string' and IGNORED_DEPARTMENTS[dept:lower()] then return nil end

    local code = clean(data.code, 20, '10-00'):upper()
    local title = clean(data.title or data.message, 90, 'Dispatch Alert')
    local id = tostring(DCfg.CallPrefix or 'E'):sub(1, 3) .. D.nextId
    D.nextId = D.nextId + 1

    local tags = {}
    if type(data.tags) == 'table' then
        for i, t in ipairs(data.tags) do
            if i > 8 then break end
            if type(t) == 'table' and t.label then
                tags[#tags + 1] = {
                    icon = clean(t.icon, 40, 'fa-circle-info'):gsub('[^%w%-]', ''),
                    label = clean(t.label, 60, ''),
                    danger = t.isWeapon == true or t.danger == true,
                }
            end
        end
    end

    local now = os.time()
    local call = {
        id = id,
        code = code,
        title = title,
        description = clean(data.description or data.message, 400, title),
        street = clean(data.street, 80, 'Unknown location'),
        coords = coordsOf(data.coords),
        priority = D.NormalizePriority(data.priority, code, title),
        tags = tags,
        caseNumber = ('#%s-%06d'):format(os.date('%y%m'), math.random(0, 999999)),
        status = 'pending',
        units = {},
        supervisor = nil,
        channel = tonumber(data.channel) or nil,
        origin = clean(data.origin, 20, 'system'),
        createdBy = clean(data.createdBy, 60, nil),
        callerSource = tonumber(data.callerSource), -- never sent to clients (see publicCall)
        patientSource = tonumber(data.patientSource), -- qb-hospital patient (server only, see publicCall)
        canReply = data.callerSource ~= nil,
        createdAt = now,
        updatedAt = now,
    }

    if type(data.units) == 'table' then
        for _, u in ipairs(data.units) do
            local entry = u.source and unitEntry(u.source, u.role)
            if entry then call.units[#call.units + 1] = entry end
        end
        if #call.units > 0 then call.status = 'active' end
    end

    D.calls[id] = call

    D.ForEachEligible(function(src)
        TriggerClientEvent('ems-mdt:client:DispatchNotify', src, publicCall(call), os.time())
    end)
    D.Broadcast()
    return id
end

-- ---------------------------------------------------------------------------
-- Medic actions (any on-duty medic)
-- ---------------------------------------------------------------------------

local function onDutyEmployee(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsEmployee(Player) or not Player.PlayerData.job.onduty then return nil end
    return Player
end

RegisterNetEvent('ems-mdt:server:DispatchRespond', function(callId)
    local src = source
    local Player = onDutyEmployee(src)
    local call = Player and D.calls[callId]
    if not call then return end

    if not findUnit(call, src) then
        local entry = unitEntry(src, #call.units == 0 and 'Lead paramedic' or 'Awaiting role')
        if entry then call.units[#call.units + 1] = entry end
    end
    if call.status == 'pending' then call.status = 'active' end
    touch(call)
    D.Broadcast()
end)

RegisterNetEvent('ems-mdt:server:DispatchDetach', function(callId)
    local src = source
    local call = onDutyEmployee(src) and D.calls[callId]
    if not call then return end
    local idx = findUnit(call, src)
    if idx then table.remove(call.units, idx) end
    if call.supervisor == src then call.supervisor = nil end
    touch(call)
    D.Broadcast()
end)

function D.DetachEverywhere(src)
    local changed = false
    for _, call in pairs(D.calls) do
        local idx = findUnit(call, src)
        if idx then table.remove(call.units, idx); changed = true end
        if call.supervisor == src then call.supervisor = nil; changed = true end
    end
    if changed then D.Broadcast() end
end

-- ---------------------------------------------------------------------------
-- Dispatcher / command actions
-- ---------------------------------------------------------------------------

local function manager(src)
    local Player = onDutyEmployee(src)
    if not Player then return nil end
    if not MDT.Hub.CanManageDispatch(Player) then
        TriggerClientEvent('QBCore:Notify', src, 'Take Dispatch (or Supervisor) in the EMS Hub to manage calls.', 'error')
        return nil
    end
    return Player
end

RegisterNetEvent('ems-mdt:server:DispatchUpdate', function(data)
    local src = source
    if type(data) ~= 'table' then return end
    local call = D.calls[data.callId]
    if not call then return end

    -- The call's own supervisor may change status even without dispatch rights.
    local Player = onDutyEmployee(src)
    if not Player then return end
    local isManager = MDT.Hub.CanManageDispatch(Player)
    local isSupervisor = call.supervisor == src
    if not isManager and not (isSupervisor and data.field == 'status') then
        TriggerClientEvent('QBCore:Notify', src, 'Take Dispatch (or Supervisor) in the EMS Hub to manage calls.', 'error')
        return
    end

    local field, value = data.field, data.value
    if field == 'status' then
        if not VALID_STATUS[value] then return end
        if value == 'closed' then
            archive(call, MDT.GetName(Player))
        else
            call.status = value
        end
    elseif field == 'priority' then
        if not PRIORITY_RANK[value] then return end
        call.priority = value
    elseif field == 'supervisor' then
        local sup = tonumber(value)
        call.supervisor = (sup and findUnit(call, sup)) and sup or nil
    elseif field == 'channel' then
        local ch = tonumber(value)
        call.channel = (ch and ch > 0 and ch < 1000) and math.floor(ch) or nil
    elseif field == 'role' then
        local idx, unit = findUnit(call, tonumber(data.unit))
        if not unit or not VALID_ROLE[value] then return end
        unit.role = value
    elseif field == 'units' then
        if type(value) ~= 'table' then return end
        local newUnits, keep = {}, {}
        for _, u in ipairs(call.units) do keep[u.source] = u end
        for i, s in ipairs(value) do
            if i > 16 then break end
            s = tonumber(s)
            if s then
                if keep[s] then
                    newUnits[#newUnits + 1] = keep[s]
                else
                    local target = onDutyEmployee(s)
                    local entry = target and unitEntry(s, 'Awaiting role')
                    if entry then
                        newUnits[#newUnits + 1] = entry
                        TriggerClientEvent('ems-mdt:client:DispatchAssigned', s, publicCall(call), MDT.GetName(Player))
                    end
                end
            end
        end
        call.units = newUnits
        if call.supervisor and not findUnit(call, call.supervisor) then call.supervisor = nil end
        if #newUnits > 0 and call.status == 'pending' then call.status = 'active' end
    else
        return
    end

    touch(call)
    D.Broadcast()
end)

RegisterNetEvent('ems-mdt:server:DispatchCreateManual', function(data)
    local src = source
    local Player = manager(src)
    if not Player or type(data) ~= 'table' then return end
    if not MDT.CheckCooldown('unitsAlert', Player.PlayerData.citizenid) then
        TriggerClientEvent('QBCore:Notify', src, 'Please wait a few seconds before creating another call.', 'error')
        return
    end

    local title = clean(data.title, 90, nil)
    if not title or not MDT.IsCleanText(title) or not MDT.IsCleanText(tostring(data.description or '')) then
        TriggerClientEvent('QBCore:Notify', src, 'Enter a valid title (no links / HTML).', 'error')
        return
    end

    D.Create({
        code = clean(data.code, 20, '10-52'),
        title = title,
        description = clean(data.description, 400, title),
        street = clean(data.street, 80, nil),
        priority = PRIORITY_RANK[data.priority] and data.priority or 'medium',
        coords = coordsOf(data.coords) or MDT.PedCoords(src),
        origin = 'dispatcher',
        createdBy = MDT.GetName(Player),
        tags = { { icon = 'fa-headset', label = 'Dispatcher: ' .. MDT.Hub.GetCallsign(Player) } },
    }, 'ambulance')
    MDT.LogMdtAction(Player, 'Created Dispatch Call', title)
end)

RegisterNetEvent('ems-mdt:server:DispatchRequestSync', function()
    D.SyncTo(source)
end)

-- Auto-close stale calls so the CAD doesn't fill up with forgotten ones.
CreateThread(function()
    while true do
        Wait(60000)
        local minutes = tonumber(DCfg.AutoCloseMinutes) or 0
        if minutes > 0 then
            local cutoff = os.time() - minutes * 60
            local changed = false
            for _, call in pairs(D.calls) do
                if call.updatedAt < cutoff then
                    archive(call, 'Auto-closed')
                    changed = true
                end
            end
            if changed then D.Broadcast() end
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Command features (hospital alert level / emergency broadcast / all-units)
-- ---------------------------------------------------------------------------

RegisterNetEvent('ems-mdt:server:BroadcastEmergencyAlert', function(message)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsBoss(Player) then return end
    if type(message) ~= 'string' or message:gsub('%s+', '') == '' or not MDT.IsCleanText(message) then return end
    message = message:sub(1, 250)

    D.Create({
        code = 'BROADCAST', title = 'EMS Command Broadcast', priority = 'high',
        description = message, coords = MDT.PedCoords(src), origin = 'command',
        tags = { { icon = 'fa-star-of-life', label = MDT.GetName(Player) } }
    }, 'ambulance')

    MDT.LogMdtAction(Player, 'Sent Emergency Broadcast', message)
end)

local LEVEL_TEXT = {
    green = 'Normal operations',
    yellow = 'High patient load — non-urgent calls may wait',
    red = 'Mass casualty / hospital at capacity — all hands',
}

RegisterNetEvent('ems-mdt:server:SetAlertLevel', function(level)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsBoss(Player) then return end
    if not LEVEL_TEXT[level] then return end

    MDT.State.alertLevel = level

    D.Create({
        code = 'ALERT-LEVEL', title = 'Hospital Alert Level: CODE ' .. level:upper(),
        priority = level == 'red' and 'high' or (level == 'yellow' and 'medium' or 'low'),
        description = 'Hospital alert level changed to CODE ' .. level:upper() .. ' — ' .. LEVEL_TEXT[level] .. '.',
        coords = MDT.PedCoords(src), origin = 'command'
    }, 'ambulance')

    for _, v in pairs(QBCore.Functions.GetQBPlayers()) do
        if v and v.PlayerData.job.name == Config.JobName then
            TriggerClientEvent('ems-mdt:client:AlertLevelChanged', v.PlayerData.source, level)
        end
    end

    MDT.LogMdtAction(Player, 'Changed Alert Level', level)
end)

RegisterNetEvent('ems-mdt:server:SendUnitsAlert', function(message)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsEmployee(Player) or not Player.PlayerData.job.onduty then return end
    if type(message) ~= 'string' or message:gsub('%s+', '') == '' then return end
    if not MDT.IsCleanText(message) then return end
    message = message:sub(1, 200)

    if not MDT.CheckCooldown('unitsAlert', Player.PlayerData.citizenid) then
        TriggerClientEvent('QBCore:Notify', src, 'Please wait before sending another all-units alert.', 'error')
        return
    end

    D.Create({
        code = 'ALL-UNITS', title = 'All Units — ' .. MDT.Hub.GetCallsign(Player), priority = 'low',
        description = message, coords = MDT.PedCoords(src), origin = 'medic',
        tags = { { icon = 'fa-bullhorn', label = MDT.GetName(Player) } }
    }, 'ambulance')

    MDT.LogMdtAction(Player, 'Sent All-Units Alert', message)
end)

-- ---------------------------------------------------------------------------
-- Exports / events for other resources
-- ---------------------------------------------------------------------------

local function exportCreate(dept, data)
    -- Accept both (dept, data) and (data) alone.
    if type(dept) == 'table' and data == nil then data, dept = dept, 'ambulance' end
    return D.Create(data, dept)
end

exports('CreateDispatchCall', exportCreate)
exports('GetActiveCalls', function() return sortedActive() end)

-- Server scripts:  TriggerEvent('ems-mdt:server:CreateDispatchCall', { code = '10-52', title = '...', coords = ... })
AddEventHandler('ems-mdt:server:CreateDispatchCall', function(data, dept)
    exportCreate(dept or 'ambulance', data)
end)

-- Client-side creators (client export / legacy events) — rate limited, coords from the server.
local clientCallCooldown = {}
local function clientCreate(src, dept, data)
    if type(data) ~= 'table' then return end
    local now = GetGameTimer()
    if clientCallCooldown[src] and now - clientCallCooldown[src] < 3000 then return end
    clientCallCooldown[src] = now

    local ped = (tonumber(src) or 0) > 0 and GetPlayerPed(src) or 0
    if not coordsOf(data.coords) and ped ~= 0 then
        local c = GetEntityCoords(ped)
        data.coords = { x = c.x, y = c.y, z = c.z }
    end
    data.callerSource = nil -- only the /997 commands may set a caller (reply channel)
    return D.Create(data, dept)
end
MDT.Dispatch.ClientCreate = clientCreate

RegisterNetEvent('ems-mdt:server:ClientDispatchCall', function(dept, data) clientCreate(source, dept, data) end)

AddEventHandler('playerDropped', function() clientCallCooldown[source] = nil end)

-- ---------------------------------------------------------------------------
-- /997 citizen medical calls (+ anonymous) and /997r replies
-- ---------------------------------------------------------------------------

local function handle997(src, args, anonymous)
    local message = table.concat(args or {}, ' ')
    if message:gsub('%s+', '') == '' then
        TriggerClientEvent('QBCore:Notify', src, 'Usage: /' .. ((DCfg.Commands911 or { '997' })[1]) .. ' [what is the medical emergency?]', 'error')
        return
    end
    if not MDT.IsCleanText(message) then
        TriggerClientEvent('QBCore:Notify', src, 'Links, URLs and HTML are not allowed.', 'error')
        return
    end

    local Player = QBCore.Functions.GetPlayer(src)
    local tags
    if anonymous then
        tags = { { icon = 'fa-user-secret', label = 'Anonymous caller' } }
    else
        local callerName = Player and MDT.GetName(Player) or 'Unknown'
        local phone = Player and Player.PlayerData.charinfo and Player.PlayerData.charinfo.phone or 'Hidden'
        tags = { { icon = 'fa-user', label = callerName }, { icon = 'fa-phone', label = tostring(phone) }, { icon = 'fa-hashtag', label = 'ID ' .. src } }
    end

    clientCallCooldown[src] = nil
    local ped = GetPlayerPed(src)
    local c = ped ~= 0 and GetEntityCoords(ped) or nil
    local callId = D.Create({
        code = anonymous and '997-ANON' or '997-CALL',
        title = anonymous and 'Anonymous Medical Call (997)' or 'Medical Emergency Call (997)',
        description = message:sub(1, 300),
        coords = c and { x = c.x, y = c.y, z = c.z } or nil,
        origin = '997',
        tags = tags,
        callerSource = src,
    }, 'ambulance')
    if callId then
        TriggerClientEvent('ems-mdt:client:Request911Street', src, callId)
        TriggerClientEvent('QBCore:Notify', src,
            ('Your %s call (%s) has been sent to EMS.'):format(anonymous and 'anonymous' or '997', callId), 'success', 7000)
    end
end

for _, cmd in ipairs(DCfg.Commands911 or { '997' }) do
    QBCore.Commands.Add(cmd, 'Call EMS (medical emergency)', { { name = 'message', help = 'What is the medical emergency?' } }, false,
        function(source, args) handle997(source, args, false) end)
end
for _, cmd in ipairs(DCfg.CommandsAnonymous or {}) do
    QBCore.Commands.Add(cmd, 'Anonymous call to EMS', { { name = 'message', help = 'What is the medical emergency?' } }, false,
        function(source, args) handle997(source, args, true) end)
end

-- Medic replies to a caller: /997r E1001 message   (or /997r [player id] message, like qb-hospital's old /997r)
if DCfg.ReplyCommand and DCfg.ReplyCommand ~= '' then
    QBCore.Commands.Add(DCfg.ReplyCommand, 'Reply to a 997 caller', {
        { name = 'call', help = 'Call ID (e.g. E1001) or player ID' }, { name = 'message', help = 'Your reply' },
    }, true, function(source, args)
        local Player = QBCore.Functions.GetPlayer(source)
        if not MDT.IsEmployee(Player) then
            TriggerClientEvent('QBCore:Notify', source, 'Only EMS can reply to 997 calls.', 'error')
            return
        end
        local key = tostring(args[1] or ''):upper()
        local call = D.calls[key]
        if not call then
            for _, h in ipairs(D.history) do if h.id == key then call = h break end end
        end

        local target, label
        if call and call.callerSource then
            target, label = call.callerSource, key
        elseif tonumber(key) and QBCore.Functions.GetPlayer(tonumber(key)) then
            target, label = tonumber(key), '997'
        else
            TriggerClientEvent('QBCore:Notify', source, 'No 997 caller found for ' .. key, 'error')
            return
        end

        local text = table.concat(args, ' ', 2):sub(1, 200)
        if text:gsub('%s+', '') == '' or not MDT.IsCleanText(text) then return end
        if not QBCore.Functions.GetPlayer(target) then
            TriggerClientEvent('QBCore:Notify', source, 'The caller is no longer in the city.', 'error')
            return
        end
        local from = ('EMS %s'):format(MDT.Hub.GetCallsign(Player))
        TriggerClientEvent('QBCore:Notify', target, ('[%s] %s: %s'):format(label, from, text), 'primary', 12000)
        TriggerClientEvent('chat:addMessage', target, { color = { 225, 29, 72 }, args = { from .. ' (' .. label .. ')', text } })
        TriggerClientEvent('QBCore:Notify', source, 'Reply sent to the caller of ' .. label, 'success')
        MDT.LogMdtAction(Player, 'Replied to 997 Caller', label .. ': ' .. text)
    end)
end

-- The caller's client answers with its street name so the 997 call has a real address.
RegisterNetEvent('ems-mdt:server:Update911Street', function(callId, street)
    local src = source
    local call = D.calls[callId]
    if not call or call.callerSource ~= src or type(street) ~= 'string' then return end
    if call.street ~= 'Unknown location' then return end
    call.street = clean(street, 80, call.street)
    D.Broadcast()
end)

-- ---------------------------------------------------------------------------
-- Legacy dispatch events — only the ones addressed to EMS (the police MDT
-- takes the police ones). cd_dispatch itself is no longer needed for EMS.
-- ---------------------------------------------------------------------------

if DCfg.LegacyEvents ~= false then
    local function forEms(list)
        if type(list) ~= 'table' then return false end
        for k, v in pairs(list) do
            if (type(v) == 'string' and EMS_JOBS[v:lower()]) or (type(k) == 'string' and EMS_JOBS[k:lower()]) then return true end
        end
        return false
    end

    -- exports['cd_dispatch']:GetPlayerInfo() + TriggerServerEvent('cd_dispatch:AddNotification', { job_table = { 'ambulance' }, ... })
    RegisterNetEvent('cd_dispatch:AddNotification', function(data)
        if type(data) ~= 'table' or not forEms(data.job_table) then return end
        local title = tostring(data.title or 'Medical Alert')
        local code = title:match('10%-%d+') or '10-52'
        -- "10-69 - Civilan Down" → "Civilan Down"
        local cleanTitle = title:gsub('^%s*10%-%d+%s*[-–:]?%s*', '')
        if cleanTitle == '' then cleanTitle = title end
        clientCreate(source, 'ambulance', {
            code = code, title = cleanTitle,
            priority = (data.flash == 1 or data.flash == true) and 'high' or nil,
            street = data.street, description = data.message or title, coords = data.coords,
            tags = { { icon = 'fa-truck-medical', label = cleanTitle } }
        })
    end)

    RegisterNetEvent('ps-dispatch:server:notify', function(data)
        if type(data) ~= 'table' or not forEms(data.jobs) then return end
        local tags = {}
        if data.name then tags[#tags + 1] = { icon = 'fa-user', label = tostring(data.name) } end
        if data.vehicle then tags[#tags + 1] = { icon = 'fa-car', label = data.vehicle } end
        clientCreate(source, 'ambulance', {
            code = data.code or '10-52', title = data.message or 'Medical Alert', priority = data.priority,
            street = data.street, description = data.message, coords = data.coords, tags = tags
        })
    end)

    RegisterNetEvent('qb-dispatch:server:NewAlert', function(data)
        if type(data) ~= 'table' or not forEms(data.jobs) then return end
        clientCreate(source, 'ambulance', {
            code = data.code or '10-52', title = data.callname or 'Medical Alert',
            description = (data.info and data.info[1] and data.info[1].label) or data.callname,
            coords = data.coords
        })
    end)
end
