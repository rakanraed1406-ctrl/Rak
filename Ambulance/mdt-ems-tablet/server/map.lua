--[[ server/map.lua - live on-duty medic feed, calibration helper, shared map pins ]]
local QBCore = MDT.QBCore

RegisterNetEvent('ems-mdt:server:RequestMapOfficers', function()
    local src = source
    if not MDT.IsEmployee(QBCore.Functions.GetPlayer(src)) then return end

    local medics = {}
    for _, v in pairs(QBCore.Functions.GetQBPlayers()) do
        if v and v.PlayerData.job.name == Config.JobName and v.PlayerData.job.onduty then
            local ped = GetPlayerPed(v.PlayerData.source)
            if ped ~= 0 then
                local coords = GetEntityCoords(ped)
                medics[#medics + 1] = {
                    serverId = v.PlayerData.source,
                    citizenid = v.PlayerData.citizenid,
                    name = MDT.GetName(v),
                    callsign = MDT.Hub.GetCallsign(v),
                    gradeLevel = v.PlayerData.job.grade.level or 0,
                    gradeName = v.PlayerData.job.grade.name or 'Paramedic',
                    coords = { x = coords.x, y = coords.y, z = coords.z },
                    heading = GetEntityHeading(ped)
                }
            end
        end
    end

    TriggerClientEvent('ems-mdt:client:UpdateMapOfficers', src, medics)
end)

--- Boss-only setup helper: prints your exact coords to the server console
--- (for calibrating Config.MapWorldBounds or placing CCTV cameras).
RegisterNetEvent('ems-mdt:server:LogMapCalibration', function(coords)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsBoss(Player) or type(coords) ~= 'table' then return end
    local x, y, z = tonumber(coords.x) or 0.0, tonumber(coords.y) or 0.0, tonumber(coords.z) or 0.0
    print(('[EMS MDT MAP CALIBRATION] %s is standing at vector3(%.2f, %.2f, %.2f)'):format(MDT.GetName(Player), x, y, z))
    TriggerClientEvent('QBCore:Notify', src, ('Coords logged to server console: %.1f, %.1f, %.1f'):format(x, y, z), 'primary')
end)

-- ---------------------------------------------------------------------------
-- Shared map pins (in memory on purpose — working data, not a record)
-- ---------------------------------------------------------------------------

local MAX_MARKERS = 200
local DEFAULT_PIN = '#19c3b1'

local function BroadcastMarkers()
    for _, v in pairs(QBCore.Functions.GetQBPlayers()) do
        if v and v.PlayerData.job.name == Config.JobName then
            TriggerClientEvent('ems-mdt:client:MapMarkersUpdated', v.PlayerData.source, MDT.MapMarkers)
        end
    end
end

RegisterNetEvent('ems-mdt:server:RequestMapMarkers', function()
    local src = source
    if not MDT.IsEmployee(QBCore.Functions.GetPlayer(src)) then return end
    TriggerClientEvent('ems-mdt:client:MapMarkersUpdated', src, MDT.MapMarkers)
end)

RegisterNetEvent('ems-mdt:server:AddMapMarker', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsEmployee(Player) or type(data) ~= 'table' then return end
    if not MDT.CheckCooldown('marker', Player.PlayerData.citizenid) then return end

    local x, y = tonumber(data.x), tonumber(data.y)
    if not x or not y or x < 0 or x > 1 or y < 0 or y > 1 then return end

    local color = tostring(data.color or DEFAULT_PIN):sub(1, 16)
    if not color:match('^#%x%x%x%x%x%x$') then color = DEFAULT_PIN end
    local label = MDT.Clean(data.label, 60)
    if label ~= '' and not MDT.IsCleanText(label) then label = '' end

    MDT.MapMarkers[#MDT.MapMarkers + 1] = {
        id = MDT.NextMarkerId, kind = 'pin', citizenid = Player.PlayerData.citizenid, author = MDT.GetName(Player),
        color = color, x = x, y = y, label = label
    }
    MDT.NextMarkerId = MDT.NextMarkerId + 1
    while #MDT.MapMarkers > MAX_MARKERS do table.remove(MDT.MapMarkers, 1) end

    BroadcastMarkers()
end)

RegisterNetEvent('ems-mdt:server:ClearMapMarker', function(markerId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsEmployee(Player) then return end

    for i, marker in ipairs(MDT.MapMarkers) do
        if marker.id == markerId then
            if marker.citizenid == Player.PlayerData.citizenid or MDT.IsSeniorCommand(Player) then
                table.remove(MDT.MapMarkers, i)
                BroadcastMarkers()
            end
            return
        end
    end
end)

RegisterNetEvent('ems-mdt:server:ClearAllMapMarkers', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsSeniorCommand(Player) then return end
    MDT.MapMarkers = {}
    MDT.LogMdtAction(Player, 'Cleared Map Board', nil)
    BroadcastMarkers()
end)
