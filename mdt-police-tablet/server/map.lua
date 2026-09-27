--[[ server/map.lua - live on-duty officer feed + calibration (tactical markers appended by hand) ]]
local QBCore = MDT.QBCore

RegisterNetEvent('police:server:RequestMapOfficers', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsEmployee(Player) then return end

    local officers = {}
    local players = QBCore.Functions.GetQBPlayers()
    for _, v in pairs(players) do
        if v and v.PlayerData.job.name == Config.JobName and v.PlayerData.job.onduty then
            local ped = GetPlayerPed(v.PlayerData.source)
            if ped ~= 0 then
                local coords = GetEntityCoords(ped)
                local charinfo = v.PlayerData.charinfo
                table.insert(officers, {
                    serverId = v.PlayerData.source,
                    citizenid = v.PlayerData.citizenid,
                    name = (charinfo and charinfo.firstname or 'Officer') .. ' ' .. (charinfo and charinfo.lastname or ''),
                    gradeLevel = v.PlayerData.job.grade.level or 0,
                    gradeName = v.PlayerData.job.grade.name or 'Officer',
                    coords = { x = coords.x, y = coords.y, z = coords.z },
                    heading = GetEntityHeading(ped)
                })
            end
        end
    end

    TriggerClientEvent('police:client:UpdateMapOfficers', src, officers)
end)

--- Prints the requesting officer's exact world coordinates to the server
--- console so the department (server owner) can calibrate Config.MapWorldBounds
--- against known landmarks. Boss-gated purely because it's an installation/
--- setup tool, not something rank-and-file officers need day to day.
RegisterNetEvent('police:server:LogMapCalibration', function(coords)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsBoss(Player) then return end
    if type(coords) ~= 'table' then return end

    local x = tonumber(coords.x) or 0.0
    local y = tonumber(coords.y) or 0.0
    local z = tonumber(coords.z) or 0.0
    print(('[MDT MAP CALIBRATION] %s is standing at vector3(%.2f, %.2f, %.2f)'):format(
        Player.PlayerData.charinfo.firstname or 'Officer', x, y, z))
    TriggerClientEvent('QBCore:Notify', src, ('Coords logged to server console: %.1f, %.1f, %.1f'):format(x, y, z), 'primary')
end)

-- ===================================================================
-- Tactical markers — a shared live whiteboard on top of the map. Any
-- on-duty employee can drop a labeled pin; clearing = author or Command.
-- Kept in memory on purpose — this is working tactical data, not a
-- permanent record.
-- ===================================================================

local MAX_MARKERS = 200

local function BroadcastMarkersToPolice()
    local players = QBCore.Functions.GetQBPlayers()
    for _, v in pairs(players) do
        if v and v.PlayerData.job.name == Config.JobName then
            TriggerClientEvent('police:client:MapMarkersUpdated', v.PlayerData.source, MDT.MapMarkers)
        end
    end
end

RegisterNetEvent('police:server:RequestMapMarkers', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsEmployee(Player) then return end
    TriggerClientEvent('police:client:MapMarkersUpdated', src, MDT.MapMarkers)
end)

RegisterNetEvent('police:server:AddMapMarker', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsEmployee(Player) then return end
    if type(data) ~= 'table' then return end

    local citizenid = Player.PlayerData.citizenid
    if not MDT.CheckCooldown('marker', citizenid) then return end

    local x, y = tonumber(data.x), tonumber(data.y)
    if not x or not y or x < 0 or x > 1 or y < 0 or y > 1 then return end

    local charinfo = Player.PlayerData.charinfo
    local authorName = (charinfo and charinfo.firstname or 'Officer') .. ' ' .. (charinfo and charinfo.lastname or '')
    local color = tostring(data.color or '#3b9dfb'):sub(1, 16)
    if not color:match('^#%x%x%x%x%x%x$') then color = '#3b9dfb' end

    local marker = {
        id = MDT.NextMarkerId, kind = 'pin', citizenid = citizenid, author = authorName,
        color = color, x = x, y = y, label = tostring(data.label or ''):sub(1, 60)
    }

    MDT.NextMarkerId = MDT.NextMarkerId + 1
    table.insert(MDT.MapMarkers, marker)
    while #MDT.MapMarkers > MAX_MARKERS do table.remove(MDT.MapMarkers, 1) end

    BroadcastMarkersToPolice()
end)

RegisterNetEvent('police:server:ClearMapMarker', function(markerId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsEmployee(Player) then return end

    for i, marker in ipairs(MDT.MapMarkers) do
        if marker.id == markerId then
            if marker.citizenid == Player.PlayerData.citizenid or MDT.IsSeniorCommand(Player) then
                table.remove(MDT.MapMarkers, i)
                BroadcastMarkersToPolice()
            end
            return
        end
    end
end)

RegisterNetEvent('police:server:ClearAllMapMarkers', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsSeniorCommand(Player) then return end

    MDT.MapMarkers = {}
    MDT.LogMdtAction(Player, 'Cleared Tactical Map Board', nil)
    BroadcastMarkersToPolice()
end)
