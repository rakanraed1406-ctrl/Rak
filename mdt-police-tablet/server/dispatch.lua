--[[
    server/dispatch.lua — built-in dispatch / CAD (replaces sk1-hub).

    Priorities (3 tiers, each with its own colour + sound on the client):
        low    = سهل    (BLUE)
        medium = متوسط  (YELLOW)
        high   = صعب    (RED)

    Notifications go to every officer that is on duty AND has the MDT item in
    their inventory (both configurable in Config.Dispatch), even while the
    tablet is closed.

    Entry points:
        MDT.Dispatch.Create(data, dept)                    -- server Lua
        exports['<this resource>']:CreateDispatchCall(dept, data)
        exports['sk1-hub']:CreateDispatchCall(dept, data)   -- compatibility shim
        TriggerServerEvent('sk1-hub:server:createCall', dept, data) / client export
        /911 /919 commands, and the legacy cd_dispatch / ps-dispatch / qb events
]]

local QBCore = MDT.QBCore
local DCfg = Config.Dispatch or {}

MDT.Dispatch = {
    calls = {},   -- [id] = call
    history = {}, -- closed calls, newest first
    nextId = 1001,
}
local D = MDT.Dispatch

local IGNORED_DEPARTMENTS = { ambulance = true, ems = true, doctor = true, fire = true, paramedic = true }
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
    if t:find('shot') or t:find('panic') or t:find('officer down') or t:find('robbery') or t:find('hostage') then
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

--- Officers that should get dispatch notifications (duty + tablet item, per config).
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
    return call -- calls hold no secrets; kept as a hook in case you want to strip fields
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

--- Sends the whole CAD state to one officer (only if they have the tablet open).
function D.SyncTo(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsEmployee(Player) then return end
    TriggerClientEvent('police:client:DispatchSync', src, {
        calls = sortedActive(),
        history = D.history,
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
        TriggerClientEvent('police:client:DispatchCount', src, count)
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
    local id = 'C' .. D.nextId
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
        TriggerClientEvent('police:client:DispatchNotify', src, publicCall(call), os.time())
    end)
    D.Broadcast()
    return id
end

-- ---------------------------------------------------------------------------
-- Officer actions (any on-duty officer)
-- ---------------------------------------------------------------------------

local function onDutyEmployee(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsEmployee(Player) or not Player.PlayerData.job.onduty then return nil end
    return Player
end

RegisterNetEvent('police:server:DispatchRespond', function(callId)
    local src = source
    local Player = onDutyEmployee(src)
    local call = Player and D.calls[callId]
    if not call then return end

    if not findUnit(call, src) then
        local entry = unitEntry(src, #call.units == 0 and 'Primary unit' or 'Awaiting role')
        if entry then call.units[#call.units + 1] = entry end
    end
    if call.status == 'pending' then call.status = 'active' end
    touch(call)
    D.Broadcast()
end)

RegisterNetEvent('police:server:DispatchDetach', function(callId)
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
        TriggerClientEvent('QBCore:Notify', src, 'Take Dispatch (or Commander) in the Command Hub to manage calls.', 'error')
        return nil
    end
    return Player
end

RegisterNetEvent('police:server:DispatchUpdate', function(data)
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
        TriggerClientEvent('QBCore:Notify', src, 'Take Dispatch (or Commander) in the Command Hub to manage calls.', 'error')
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
                        TriggerClientEvent('police:client:DispatchAssigned', s, publicCall(call), MDT.GetName(Player))
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

RegisterNetEvent('police:server:DispatchCreateManual', function(data)
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

    local coords = coordsOf(data.coords)
    if not coords then
        local ped = GetPlayerPed(src)
        local c = ped ~= 0 and GetEntityCoords(ped) or vector3(0.0, 0.0, 0.0)
        coords = { x = c.x, y = c.y, z = c.z }
    end

    D.Create({
        code = clean(data.code, 20, '10-00'),
        title = title,
        description = clean(data.description, 400, title),
        street = clean(data.street, 80, nil),
        priority = PRIORITY_RANK[data.priority] and data.priority or 'medium',
        coords = coords,
        origin = 'dispatcher',
        createdBy = MDT.GetName(Player),
        tags = { { icon = 'fa-headset', label = 'Dispatcher: ' .. MDT.Hub.GetCallsign(Player) } },
    }, 'police')
    MDT.LogMdtAction(Player, 'Created Dispatch Call', title)
end)

RegisterNetEvent('police:server:DispatchRequestSync', function()
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
-- Command features that used to be the whole "Dispatch" app
-- (alert level / emergency broadcast / all-units alert)
-- ---------------------------------------------------------------------------

local function playerCoords(src)
    local ped = GetPlayerPed(src)
    local c = ped ~= 0 and GetEntityCoords(ped) or vector3(0.0, 0.0, 0.0)
    return { x = c.x, y = c.y, z = c.z }
end

RegisterNetEvent('police:server:BroadcastEmergencyAlert', function(message)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsBoss(Player) then return end
    if type(message) ~= 'string' or message:gsub('%s+', '') == '' then return end
    message = message:sub(1, 250)

    D.Create({
        code = 'BROADCAST', title = 'Command Broadcast', priority = 'high',
        description = message, coords = playerCoords(src), origin = 'command',
        tags = { { icon = 'fa-shield', label = MDT.GetName(Player) } }
    }, 'police')

    MDT.LogMdtAction(Player, 'Sent Emergency Broadcast', message)
end)

RegisterNetEvent('police:server:SetAlertLevel', function(level)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsBoss(Player) then return end
    if level ~= 'green' and level ~= 'yellow' and level ~= 'red' then return end

    MDT.State.alertLevel = level

    D.Create({
        code = 'ALERT-LEVEL', title = 'Department Alert Level: CODE ' .. level:upper(),
        priority = level == 'red' and 'high' or (level == 'yellow' and 'medium' or 'low'),
        description = 'Department alert level has been changed to CODE ' .. level:upper() .. '.',
        coords = playerCoords(src), origin = 'command'
    }, 'police')

    for _, v in pairs(QBCore.Functions.GetQBPlayers()) do
        if v and v.PlayerData.job.name == Config.JobName then
            TriggerClientEvent('police:client:AlertLevelChanged', v.PlayerData.source, level)
        end
    end

    MDT.LogMdtAction(Player, 'Changed Alert Level', level)
end)

RegisterNetEvent('police:server:SendUnitsAlert', function(message)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsEmployee(Player) then return end
    if type(message) ~= 'string' or message:gsub('%s+', '') == '' then return end
    if not MDT.IsCleanText(message) then return end
    message = message:sub(1, 200)

    if not MDT.CheckCooldown('unitsAlert', Player.PlayerData.citizenid) then
        TriggerClientEvent('QBCore:Notify', src, 'Please wait before sending another all-units alert.', 'error')
        return
    end

    D.Create({
        code = 'ALL-UNITS', title = 'All Units — ' .. MDT.Hub.GetCallsign(Player), priority = 'low',
        description = message, coords = playerCoords(src), origin = 'officer',
        tags = { { icon = 'fa-bullhorn', label = MDT.GetName(Player) } }
    }, 'police')

    MDT.LogMdtAction(Player, 'Sent All-Units Alert', message)
end)

-- ---------------------------------------------------------------------------
-- Exports + sk1-hub compatibility
-- ---------------------------------------------------------------------------

local function exportCreate(dept, data)
    -- Accept both (dept, data) like sk1-hub and (data) alone.
    if type(dept) == 'table' and data == nil then data, dept = dept, 'police' end
    return D.Create(data, dept)
end

exports('CreateDispatchCall', exportCreate)
exports('GetActiveCalls', function() return sortedActive() end)

-- Same thing as an event, so other SERVER scripts don't need to know this
-- resource's folder name:  TriggerEvent('mdt:server:CreateDispatchCall', data)
AddEventHandler('mdt:server:CreateDispatchCall', function(data, dept)
    exportCreate(dept or 'police', data)
end)

if DCfg.Sk1HubCompat then
    AddEventHandler('__cfx_export_sk1-hub_CreateDispatchCall', function(setCB) setCB(exportCreate) end)
end

-- Client-side creators (client export / legacy event) — rate limited.
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
    return D.Create(data, dept)
end

RegisterNetEvent('police:server:ClientDispatchCall', function(dept, data) clientCreate(source, dept, data) end)
RegisterNetEvent('sk1-hub:server:createCall', function(dept, data) clientCreate(source, dept, data) end)

AddEventHandler('playerDropped', function() clientCallCooldown[source] = nil end)

-- ---------------------------------------------------------------------------
-- 911 / 919 citizen calls
-- ---------------------------------------------------------------------------

local function handle911(source, args)
    local message = table.concat(args or {}, ' ')
    if message:gsub('%s+', '') == '' then
        TriggerClientEvent('QBCore:Notify', source, 'Usage: /911 [what is happening]', 'error')
        return
    end
    if not MDT.IsCleanText(message) then
        TriggerClientEvent('QBCore:Notify', source, 'Links, URLs and HTML are not allowed.', 'error')
        return
    end

    local Player = QBCore.Functions.GetPlayer(source)
    local callerName = Player and MDT.GetName(Player) or 'Anonymous'
    local phone = Player and Player.PlayerData.charinfo and Player.PlayerData.charinfo.phone or 'Hidden'

    clientCallCooldown[source] = nil
    local callId = clientCreate(source, 'police', {
        code = '911-CALL',
        title = 'Citizen Emergency Call (911)',
        description = message:sub(1, 300),
        origin = '911',
        tags = { { icon = 'fa-user', label = callerName }, { icon = 'fa-phone', label = tostring(phone) } },
    })
    if callId then
        D.calls[callId].callerSource = source
        TriggerClientEvent('police:client:Request911Street', source, callId)
    end
    TriggerClientEvent('QBCore:Notify', source, 'Your 911 call has been sent to the police.', 'success')
end

for _, cmd in ipairs(DCfg.Commands911 or { '911' }) do
    QBCore.Commands.Add(cmd, 'Send an emergency call to the police', { { name = 'message', help = 'What is happening?' } }, false, handle911)
end

-- The caller's client answers with its street name so the 911 call has a real address.
RegisterNetEvent('police:server:Update911Street', function(callId, street)
    local src = source
    local call = D.calls[callId]
    if not call or call.callerSource ~= src or type(street) ~= 'string' then return end
    if call.street ~= 'Unknown location' then return end
    call.street = clean(street, 80, call.street)
    D.Broadcast()
end)

-- ---------------------------------------------------------------------------
-- Legacy dispatch events (what sk1-hub used to catch)
-- ---------------------------------------------------------------------------

if DCfg.LegacyEvents ~= false then
    local function hasEms(list)
        if type(list) ~= 'table' then return false end
        for k, v in pairs(list) do
            if v == 'ambulance' or v == 'ems' or k == 'ambulance' or k == 'ems' then return true end
        end
        return false
    end

    RegisterNetEvent('cd_dispatch:AddNotification', function(data)
        if type(data) ~= 'table' or hasEms(data.job_table) then return end
        local title = data.title or 'Police Alert'
        clientCreate(source, 'police', {
            code = title:match('10%-%d+') or '10-90', title = title,
            priority = (data.flash == 1 or data.flash == true) and 'high' or 'medium',
            street = data.street, description = data.message or title, coords = data.coords,
            tags = { { icon = 'fa-shield-halved', label = title } }
        })
    end)

    RegisterNetEvent('cd_dispatch:pdalerts:Gunshots', function(data, weaponName, inVehicle)
        if type(data) ~= 'table' then return end
        local tags = { { icon = 'fa-gun', label = tostring(weaponName or 'Gunfire'), isWeapon = true } }
        if inVehicle and data.vehicle_label then tags[#tags + 1] = { icon = 'fa-car', label = data.vehicle_label } end
        if inVehicle and data.vehicle_plate then tags[#tags + 1] = { icon = 'fa-id-card', label = data.vehicle_plate } end
        clientCreate(source, 'police', {
            code = inVehicle and '10-60' or '10-11', title = inVehicle and 'Vehicle Shots Fired' or 'Shots Fired',
            street = data.street, coords = data.coords, tags = tags,
            description = 'Gunfire reported near ' .. tostring(data.street or 'the area') .. '.'
        })
    end)

    RegisterNetEvent('cd_dispatch:pdalerts:Stolencar', function(data)
        if type(data) ~= 'table' then return end
        clientCreate(source, 'police', {
            code = '10-35', title = 'Stolen Vehicle', street = data.street, coords = data.coords,
            description = 'A vehicle theft has been reported.',
            tags = { { icon = 'fa-car', label = data.vehicle_label or 'Vehicle' }, { icon = 'fa-id-card', label = data.vehicle_plate or 'Plate' } }
        })
    end)

    RegisterNetEvent('police:server:gunshotAlert', function(street, coords, inVehicle)
        clientCreate(source, 'police', {
            code = inVehicle and '10-60' or '10-11', title = inVehicle and 'Vehicle Shots Fired' or 'Shots Fired',
            street = street, coords = coords, description = 'Gunfire reported near ' .. tostring(street or 'the area') .. '.',
            tags = { { icon = 'fa-gun', label = 'Gunfire', isWeapon = true } }
        })
    end)

    RegisterNetEvent('ps-dispatch:server:notify', function(data)
        if type(data) ~= 'table' or hasEms(data.jobs) then return end
        local tags = {}
        if data.weapon then tags[#tags + 1] = { icon = 'fa-gun', label = data.weapon, isWeapon = true } end
        if data.vehicle then tags[#tags + 1] = { icon = 'fa-car', label = data.vehicle } end
        if data.plate then tags[#tags + 1] = { icon = 'fa-id-card', label = data.plate } end
        clientCreate(source, 'police', {
            code = data.code or '10-90', title = data.message or 'Police Alert', priority = data.priority,
            street = data.street, description = data.message, coords = data.coords, tags = tags
        })
    end)

    RegisterNetEvent('qb-dispatch:server:NewAlert', function(data)
        if type(data) ~= 'table' or hasEms(data.jobs) then return end
        clientCreate(source, 'police', {
            code = data.code or '10-90', title = data.callname or 'Incident Alert',
            description = (data.info and data.info[1] and data.info[1].label) or data.callname,
            coords = data.coords
        })
    end)

    RegisterNetEvent('police:server:policeAlert', function(text)
        clientCreate(source, 'police', { code = '10-90', title = 'Police Alert', description = text, priority = 'high' })
    end)
end
