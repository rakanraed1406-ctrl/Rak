local QBCore = exports[Rc2store.Core]:GetCoreObject()
QBCore.Commands.Add(Rc2store.CheckPointsCommand, 'Check your ambulance points', {}, false, function(source, args)
    local xPlayer = QBCore.Functions.GetPlayer(source)
    if xPlayer.PlayerData.job.name == 'ambulance' then
        TriggerClientEvent('QBCore:Notify', source, 'ambulance Points: ' .. xPlayer.PlayerData.metadata['ambulancepoints'],
            'success', 7000)
    else
        TriggerClientEvent('QBCore:Notify', source, 'You Cant use that',
            'error', 7000)
    end
end)
QBCore.Commands.Add(Rc2store.emsmenucommand, 'Manage EMS points', {}, false, function(source, args)
    local xPlayer = QBCore.Functions.GetPlayer(source)
    if xPlayer.PlayerData.job.name == 'ambulance' and xPlayer.PlayerData.job.isboss then
        TriggerClientEvent('qb-emspoints:client:openmenu', source)
    else
        TriggerClientEvent('QBCore:Notify', source, '  you cant do this',
            'error', 7000)
    end
end)
-- The client only says "my shift timer ticked". The server decides how much (config)
-- and how often (Rc2store.Minutes) — before, any player could send any amount.
local lastAward = {}
RegisterNetEvent('qb-ambulance:addpoints', function()
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer or xPlayer.PlayerData.job.name ~= 'ambulance' or not xPlayer.PlayerData.job.onduty then return end

    local now = os.time()
    if lastAward[src] and now - lastAward[src] < (Rc2store.Minutes * 60) - 30 then return end
    lastAward[src] = now

    local amt = tonumber(Rc2store.Points) or 1
    xPlayer.Functions.SetMetaData('ambulancepoints', (tonumber(xPlayer.PlayerData.metadata['ambulancepoints']) or 0) + amt)
    TriggerClientEvent('QBCore:Notify', src, 'You received : ' .. amt .. " ambulance point", 'success', 7000)
end)

AddEventHandler('playerDropped', function() lastAward[source] = nil end)

-- Boss-only (same rule as the /xpmenu command).
local function IsEmsBoss(src)
    local p = QBCore.Functions.GetPlayer(src)
    return p and p.PlayerData.job.name == 'ambulance' and p.PlayerData.job.isboss
end
RegisterNetEvent('qb-ambulance:giveppoints', function(id, amt)
    local src = source
    amt = math.floor(tonumber(amt) or 0)
    if not IsEmsBoss(src) or amt <= 0 or amt > 1000 then return end
    local p = QBCore.Functions.GetPlayerByCitizenId(tostring(id))
    if p then
        p.Functions.SetMetaData('ambulancepoints', (tonumber(p.PlayerData.metadata['ambulancepoints']) or 0) + amt)
        TriggerClientEvent('QBCore:Notify', p.PlayerData.source, 'You received : ' .. amt .. " ambulance points",
            'success', 7000)
    end
end)
RegisterNetEvent('qb-ambulance:rmvppoints', function(id, amt)
    local src = source
    amt = math.floor(tonumber(amt) or 0)
    if not IsEmsBoss(src) or amt <= 0 then return end
    local p = QBCore.Functions.GetPlayerByCitizenId(tostring(id))
    if not p then return end
    local current = tonumber(p.PlayerData.metadata['ambulancepoints']) or 0
    if current - amt < 0 then
        return TriggerClientEvent('QBCore:Notify', src, "Oh Oh be careful for the player points",
            'error', 7000)
    end
    if p then
        p.Functions.SetMetaData('ambulancepoints', current - amt)
        TriggerClientEvent('QBCore:Notify', p.PlayerData.source, amt .. " ambulance points was removed from u",
            'success', 7000)
    end
end)
RegisterNetEvent('qb-ambulance:rmvallppp', function(id)
    if not IsEmsBoss(source) then return end
    local p = QBCore.Functions.GetPlayerByCitizenId(tostring(id))
    if p then
        p.Functions.SetMetaData('ambulancepoints', 0)
    end
end)
QBCore.Functions.CreateCallback('qb-playermanagement:server:getambulanceofficers', function(source, cb, args)
    local players = {}
    if not IsEmsBoss(source) then return cb(players) end
    for k, v in pairs(QBCore.Functions.GetQBPlayers()) do
        if v.PlayerData.job.name == 'ambulance' then
            table.insert(players, {
                firstname = v.PlayerData.charinfo.firstname,
                lastname = v.PlayerData.charinfo.lastname,
                job = v.PlayerData.job.name,
                grade = v.PlayerData.job.grade.name,
                cid = v.PlayerData.citizenid,
                ppoints = v.PlayerData.metadata['ambulancepoints'] or 0,
                playerid = v.PlayerData.source

            })
        end
    end
    cb(players)
end)

