--[[
    server/hub.lua — the old sk1-hub "police menu", now living inside the MDT.
      * Roster of every online officer (callsign, rank, status, location, duty timer, panic flag)
      * Clock in / clock out from the tablet
      * Unit status: Active / Dispatch / Commander / Break
      * Callsign (saved to QBCore metadata, same key the Hub used)
      * PANIC (10-99) — creates a RED dispatch call + alarm for every eligible officer
      * Department chat (channels from Config.Hub.ChatChannels, history kept server-side)

    Traffic: ONE roster build every few seconds, sent only to on-duty officers
    and to officers who have the tablet open — instead of the Hub's old
    "every player re-broadcasts the whole roster every 1.5s" loop.
]]

local QBCore = MDT.QBCore

MDT.Hub = {
    members = {},  -- [source] = { callsign, status, dutyStart, panicUntil, street, vehicleType, transport, radio }
    sessions = {}, -- [source] = true while that officer has the tablet open
    chat = {},     -- [channelId] = { messages... }
    panicCooldown = {},
}

local VALID_STATUS = {}
for _, s in ipairs(Config.Dispatch.Statuses or { 'active', 'dispatch', 'commander', 'break' }) do VALID_STATUS[s] = true end

local VALID_CHANNEL = {}
for _, c in ipairs(Config.Hub.ChatChannels or {}) do
    VALID_CHANNEL[c.id] = true
    MDT.Hub.chat[c.id] = {}
end

local VEHICLE_TYPES = { person = true, car = true, bike = true, helicopter = true, plane = true, boat = true }
local PANIC_HIGHLIGHT_SECONDS = 45

local function memberState(src)
    local m = MDT.Hub.members[src]
    if not m then
        m = {}
        MDT.Hub.members[src] = m
    end
    return m
end

function MDT.Hub.GetCallsign(Player)
    local src = Player.PlayerData.source
    local m = MDT.Hub.members[src]
    local cs = (m and m.callsign) or (Player.PlayerData.metadata and Player.PlayerData.metadata.callsign)
    cs = tostring(cs or '')
    if cs == '' or cs == '0' or cs:upper() == 'NO CALLSIGN' then return 'NO TAG' end
    return cs
end

function MDT.Hub.GetStatus(src)
    local m = MDT.Hub.members[src]
    return m and m.status or 'active'
end

--- Dispatchers, commanders and senior command can manage the CAD.
function MDT.Hub.CanManageDispatch(Player)
    if not Player then return false end
    if MDT.IsSeniorCommand(Player) then return true end
    local status = MDT.Hub.GetStatus(Player.PlayerData.source)
    return status == 'dispatch' or status == 'commander'
end

--- Every online officer on this department, sorted by rank (cadets last).
function MDT.Hub.BuildRoster()
    local roster = {}
    local now = os.time()

    for _, v in pairs(QBCore.Functions.GetQBPlayers()) do
        if v and v.PlayerData.job.name == Config.JobName then
            local src = v.PlayerData.source
            local m = memberState(src)
            local onDuty = v.PlayerData.job.onduty == true

            -- Duty timer is lazily kept in sync with QBCore's duty flag, so it
            -- also works when duty is toggled from a duty board / other script.
            if onDuty and not m.dutyStart then m.dutyStart = now end
            if not onDuty then m.dutyStart = nil; m.status = nil end

            local coords
            if onDuty then
                local ped = GetPlayerPed(src)
                if ped and ped ~= 0 then
                    local c = GetEntityCoords(ped)
                    coords = { x = c.x, y = c.y, z = c.z }
                end
            end

            local grade = v.PlayerData.job.grade or {}
            local rankName = grade.name or 'Officer'

            roster[#roster + 1] = {
                id = src,
                citizenid = v.PlayerData.citizenid,
                name = MDT.GetName(v),
                callsign = MDT.Hub.GetCallsign(v),
                rank = rankName,
                rankLevel = tonumber(grade.level) or 0,
                isCadet = rankName:lower():find('cadet') ~= nil,
                duty = onDuty,
                status = onDuty and (m.status or 'active') or 'off',
                dutySeconds = (onDuty and m.dutyStart) and (now - m.dutyStart) or 0,
                radio = onDuty and m.radio or false,
                location = m.street or 'Los Santos',
                transport = m.transport or 'On foot',
                vehicleType = onDuty and (m.vehicleType or 'person') or 'person',
                coords = coords,
                isPanic = (m.panicUntil or 0) > now,
                suspended = MDT.IsSuspended(v.PlayerData.citizenid),
            }
        end
    end

    table.sort(roster, function(a, b)
        if a.isCadet ~= b.isCadet then return b.isCadet end
        if a.duty ~= b.duty then return a.duty end
        if a.rankLevel ~= b.rankLevel then return a.rankLevel > b.rankLevel end
        return a.name < b.name
    end)

    return roster
end

--- Push the roster to on-duty officers (for unit blips) + anyone with the tablet open.
function MDT.Hub.Broadcast()
    local roster = MDT.Hub.BuildRoster()
    for _, v in pairs(QBCore.Functions.GetQBPlayers()) do
        if v and v.PlayerData.job.name == Config.JobName then
            local src = v.PlayerData.source
            if v.PlayerData.job.onduty or MDT.Hub.sessions[src] then
                TriggerClientEvent('police:client:HubRoster', src, roster, src)
            end
        end
    end
end

CreateThread(function()
    while true do
        Wait(3000)
        MDT.Hub.Broadcast()
    end
end)

-- ---------------------------------------------------------------------------
-- Tablet session (open/close) — lets the server only stream full data to
-- officers who are actually looking at the tablet.
-- ---------------------------------------------------------------------------

RegisterNetEvent('police:server:MdtSession', function(isOpen)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsEmployee(Player) then return end
    MDT.Hub.sessions[src] = isOpen == true or nil
    if isOpen then
        TriggerClientEvent('police:client:HubRoster', src, MDT.Hub.BuildRoster(), src)
        TriggerClientEvent('police:client:HubChatHistory', src, MDT.Hub.chat)
        if MDT.Dispatch then MDT.Dispatch.SyncTo(src) end
    end
end)

RegisterNetEvent('police:server:HubPresence', function(data)
    local src = source
    if type(data) ~= 'table' then return end
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsEmployee(Player) then return end

    local m = memberState(src)
    if type(data.street) == 'string' then m.street = data.street:sub(1, 80) end
    if type(data.transport) == 'string' then m.transport = data.transport:sub(1, 30) end
    if VEHICLE_TYPES[data.vehicleType] then m.vehicleType = data.vehicleType end
    local radio = tonumber(data.radio)
    m.radio = (radio and radio > 0) and radio or false
end)

-- ---------------------------------------------------------------------------
-- Duty (clock in / out from the tablet)
-- ---------------------------------------------------------------------------

function MDT.Hub.SetDuty(src, onDuty)
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsEmployee(Player) then return end
    if MDT.IsSuspended(Player.PlayerData.citizenid) and onDuty then
        TriggerClientEvent('QBCore:Notify', src, 'Your MDT access has been suspended by Command.', 'error')
        return
    end

    Player.Functions.SetJobDuty(onDuty == true)
    local m = memberState(src)
    if onDuty then
        m.dutyStart = os.time()
        m.status = 'active'
        TriggerClientEvent('QBCore:Notify', src, 'Clocked in — you are now on duty.', 'success')
    else
        m.dutyStart = nil
        m.status = nil
        if MDT.Dispatch then MDT.Dispatch.DetachEverywhere(src) end
        TriggerClientEvent('QBCore:Notify', src, 'Clocked out — you are now off duty.', 'primary')
    end
    MDT.LogMdtAction(Player, onDuty and 'Clocked In' or 'Clocked Out', nil)
    TriggerClientEvent('police:client:HubDutyChanged', src, onDuty == true)
    MDT.Hub.Broadcast()
end

RegisterNetEvent('police:server:HubSetDuty', function(onDuty)
    MDT.Hub.SetDuty(source, onDuty == true)
end)

-- Kept for anything still calling the v7 Dashboard "Clock Out" event.
RegisterNetEvent('police:server:ClockOut', function()
    MDT.Hub.SetDuty(source, false)
end)

-- ---------------------------------------------------------------------------
-- Status / callsign
-- ---------------------------------------------------------------------------

RegisterNetEvent('police:server:HubSetStatus', function(status)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsEmployee(Player) or not Player.PlayerData.job.onduty then return end
    if not VALID_STATUS[status] then return end

    memberState(src).status = status
    TriggerClientEvent('police:client:HubStatusChanged', src, status)
    MDT.Hub.Broadcast()
    if MDT.Dispatch then MDT.Dispatch.SyncTo(src) end -- permissions in the CAD depend on status
end)

RegisterNetEvent('police:server:HubSetCallsign', function(callsign)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsEmployee(Player) then return end

    callsign = tostring(callsign or ''):gsub('^%s*(.-)%s*$', '%1'):sub(1, 12)
    if callsign == '' then
        TriggerClientEvent('QBCore:Notify', src, 'Callsign cannot be empty.', 'error')
        return
    end
    if not MDT.IsCleanText(callsign) or callsign:find('[<>"\']') then
        TriggerClientEvent('QBCore:Notify', src, 'Links, URLs and HTML are not allowed.', 'error')
        return
    end

    memberState(src).callsign = callsign
    Player.Functions.SetMetaData('callsign', callsign)
    TriggerClientEvent('QBCore:Notify', src, 'Callsign updated to ' .. callsign .. '.', 'success')
    MDT.Hub.Broadcast()
end)

-- ---------------------------------------------------------------------------
-- PANIC (10-99)
-- ---------------------------------------------------------------------------

RegisterNetEvent('police:server:HubPanic', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsEmployee(Player) then return end
    if not Player.PlayerData.job.onduty then
        TriggerClientEvent('QBCore:Notify', src, 'You must be on duty to use the panic button.', 'error')
        return
    end
    if Config.Dispatch.RequireItemForAlerts and not MDT.HasTablet(Player) then
        TriggerClientEvent('QBCore:Notify', src, 'You need your MDT tablet to send a panic alert.', 'error')
        return
    end

    local now = os.time()
    local last = MDT.Hub.panicCooldown[src]
    if last and (now - last) < (Config.Dispatch.PanicCooldown or 15) then
        TriggerClientEvent('QBCore:Notify', src, 'Panic already sent — wait a few seconds.', 'error')
        return
    end
    MDT.Hub.panicCooldown[src] = now

    local ped = GetPlayerPed(src)
    local c = ped ~= 0 and GetEntityCoords(ped) or vector3(0.0, 0.0, 0.0)
    local name = MDT.GetName(Player)
    local callsign = MDT.Hub.GetCallsign(Player)
    local street = type(data) == 'table' and type(data.street) == 'string' and data.street:sub(1, 80) or nil

    memberState(src).panicUntil = now + PANIC_HIGHLIGHT_SECONDS

    MDT.Dispatch.Create({
        code = '10-99',
        title = 'OFFICER PANIC — ' .. callsign,
        priority = 'high',
        street = street,
        description = ('Panic button activated by %s (%s). All available units respond!'):format(name, callsign),
        coords = { x = c.x, y = c.y, z = c.z },
        tags = {
            { icon = 'fa-user-shield', label = callsign .. ' · ' .. name },
            { icon = 'fa-triangle-exclamation', label = 'Officer in distress' },
        },
        units = { { source = src, role = 'Distress origin' } },
        origin = 'panic',
        panicSource = src,
    }, 'police')

    MDT.Dispatch.ForEachEligible(function(targetSrc)
        TriggerClientEvent('police:client:PanicAlert', targetSrc, {
            source = src, name = name, callsign = callsign, coords = { x = c.x, y = c.y, z = c.z }
        })
    end)

    MDT.LogMdtAction(Player, 'Officer Panic (10-99)', street or '')
    MDT.Hub.Broadcast()
end)

-- ---------------------------------------------------------------------------
-- Department chat
-- ---------------------------------------------------------------------------

RegisterNetEvent('police:server:HubChat', function(channel, text)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsEmployee(Player) or not Player.PlayerData.job.onduty then return end
    if not VALID_CHANNEL[channel] then return end
    if type(text) ~= 'string' then return end
    text = text:gsub('^%s*(.-)%s*$', '%1'):sub(1, 250)
    if text == '' then return end
    if not MDT.IsCleanText(text) then
        TriggerClientEvent('QBCore:Notify', src, 'Links, URLs and HTML are not allowed.', 'error')
        return
    end

    local msg = {
        senderId = src,
        citizenid = Player.PlayerData.citizenid,
        callsign = MDT.Hub.GetCallsign(Player),
        sender = MDT.GetName(Player),
        rank = Player.PlayerData.job.grade.name or 'Officer',
        text = text,
        time = os.date('%H:%M'),
    }

    local list = MDT.Hub.chat[channel]
    list[#list + 1] = msg
    while #list > (Config.Hub.ChatHistory or 60) do table.remove(list, 1) end

    for _, v in pairs(QBCore.Functions.GetQBPlayers()) do
        if v and v.PlayerData.job.name == Config.JobName then
            TriggerClientEvent('police:client:HubChatMessage', v.PlayerData.source, channel, msg)
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    MDT.Hub.members[src] = nil
    MDT.Hub.sessions[src] = nil
    MDT.Hub.panicCooldown[src] = nil
    if MDT.Dispatch then MDT.Dispatch.DetachEverywhere(src) end
end)
