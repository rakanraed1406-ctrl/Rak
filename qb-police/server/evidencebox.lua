local QBCore = exports['qb-core']:GetCoreObject()

local function CreateCaseID()
    local UniqueFound = false
    local CaseID = nil
    while not UniqueFound do
        CaseID = tostring(QBCore.Shared.RandomStr(5) .. QBCore.Shared.RandomInt(5)):upper()
        local query = '%' .. CaseID .. '%'
        local result = MySQL.prepare.await('SELECT COUNT(*) as count FROM evidencebox WHERE stash LIKE ?', { query })
        if result == 0 then
            UniqueFound = true
        end
    end
    return CaseID
end

local function GetVecData(citizenid)
    if not citizenid then return false end 
    local PlayerData = MySQL.Sync.prepare('SELECT * FROM players where citizenid = ?', {citizenid})
    if PlayerData then
        PlayerData.money = json.decode(PlayerData.money)
        PlayerData.job = json.decode(PlayerData.job)
        PlayerData.position = json.decode(PlayerData.position)
        PlayerData.metadata = json.decode(PlayerData.metadata)
        PlayerData.charinfo = json.decode(PlayerData.charinfo)

        return PlayerData
    end
end

QBCore.Functions.CreateUseableItem("evidencebox", function(source, item)
	local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end 
    if Player.PlayerData.job.name == 'police' then 
        local Items = Player.PlayerData.items
        if not item then return end 
        if not Items then return end 
        if not Items[item.slot] then return end
        if item.info and item.info.caseid then 
            TriggerClientEvent('police:client:boxinteractions', source, item, Player.PlayerData.job.grade.level)
        else
            TriggerClientEvent('police:client:createbox', source, item.slot)
        end
    end
end)

RegisterNetEvent('police:server:createbox', function(data)
    if not data then return end 
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local Target = QBCore.Functions.GetPlayerByCitizenId(data.citizenid)
    if not Player then return end 
    if Target then 
        local Items = Player.PlayerData.items
        if not Items then return end 
        if not Items[data.slot] then return end
        if Items[data.slot].slot ~= data.slot then return end
        local timeTable = os.date('*t')
        Items[data.slot].info = {
            caseid = CreateCaseID(),
            officer = ''..Player.PlayerData.charinfo.firstname..' '..Player.PlayerData.charinfo.lastname..'',
            date = timeTable['day'] .. '/' .. timeTable['month'] .. '/' .. timeTable['year'] .. ' ' .. timeTable['hour'] .. ':' .. timeTable['min'],
            vecName = ''..Target.PlayerData.charinfo.firstname..' '..Target.PlayerData.charinfo.lastname..'',
            vecCid = Target.PlayerData.citizenid,
        }
        exports['qb-inventory']:SetInventory(src, Items)
    else
        Target = GetVecData(data.citizenid)
        if not Target then 
            return QBCore.Functions.Notify(src, 'Wrong citizenid', 'error', 7500)
        end
        local Items = Player.PlayerData.items
        if not Items then return end 
        if not Items[data.slot] then return end
        if Items[data.slot].slot ~= data.slot then return end
        local timeTable = os.date('*t')
        Items[data.slot].info = {
            caseid = CreateCaseID(),
            officer = ''..Player.PlayerData.charinfo.firstname..' '..Player.PlayerData.charinfo.lastname..'',
            date = timeTable['day'] .. '/' .. timeTable['month'] .. '/' .. timeTable['year'] .. ' ' .. timeTable['hour'] .. ':' .. timeTable['min'],
            vecName = ''..Target.charinfo.firstname..' '..Target.charinfo.lastname..'',
            vecCid = Target.citizenid,
        }
        exports['qb-inventory']:SetInventory(src, Items)
        QBCore.Functions.Notify(src, 'Evidence box created', 'success', 7500)
    end
end)

RegisterNetEvent('police:server:deleteBox', function(item)
    if not item then return end 
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local Items = Player.PlayerData.items
    if not Player then return end 
    if not Items then return end 
    if not Items[item.slot] then return end
    if not item.info or not item.info.caseid then return end 
    local stashId = 'Evidence_Box '..item.info.caseid
    local id = MySQL.scalar.await('SELECT id FROM evidencebox WHERE stash = ?', {stashId})
    if id then 
        MySQL.Async.execute('DELETE FROM evidencebox WHERE id = ?',{id})
    end
    Player.Functions.RemoveItem('evidencebox', 1, item.slot)
    QBCore.Functions.Notify(src, 'Evidence box have been destroyed', 'success', 7500)
end)
