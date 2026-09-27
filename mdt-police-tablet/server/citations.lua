--[[ server/citations.lua - Citations (traffic tickets) app: all employees issue/view; delete = author or Command ]]

local QBCore = MDT.QBCore
local CITATIONS_TABLE = 'police_citations'

CreateThread(function()
    exports.oxmysql:execute([[CREATE TABLE IF NOT EXISTS ]] .. CITATIONS_TABLE .. [[ (
        `id` INT NOT NULL AUTO_INCREMENT, `citizenid` VARCHAR(50) NOT NULL, `officer_name` VARCHAR(100) NOT NULL,
        `target_name` VARCHAR(100) NOT NULL, `violation` VARCHAR(255) NOT NULL, `fine_amount` INT NOT NULL DEFAULT 0,
        `plate` VARCHAR(20) DEFAULT NULL, `notes` VARCHAR(255) DEFAULT NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (`id`)) ]])
end)

local lastCitationAt = {}

local function SendCitations(src)
    exports.oxmysql:execute(
        'SELECT id, citizenid, officer_name, target_name, violation, fine_amount, plate, notes, created_at FROM ' ..
        CITATIONS_TABLE .. ' ORDER BY created_at DESC LIMIT 150',
        {}, function(rows) TriggerClientEvent('police:client:ReceiveCitations', src, rows or {}) end
    )
end

RegisterNetEvent('police:server:GetCitations', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsEmployee(Player) then return end
    SendCitations(src)
end)

RegisterNetEvent('police:server:IssueCitation', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsEmployee(Player) then return end
    if type(data) ~= 'table' then return end

    local citizenid = Player.PlayerData.citizenid
    local now = os.time()
    if lastCitationAt[citizenid] and (now - lastCitationAt[citizenid]) < 5 then
        TriggerClientEvent('QBCore:Notify', src, 'Please wait a moment before issuing another citation.', 'error')
        return
    end

    local targetName = tostring(data.targetName or ''):sub(1, 100):gsub('^%s+', ''):gsub('%s+$', '')
    local violation = tostring(data.violation or ''):sub(1, 255):gsub('^%s+', ''):gsub('%s+$', '')
    local fineAmount = math.max(0, math.floor(tonumber(data.fineAmount) or 0))
    local plate = tostring(data.plate or ''):sub(1, 20):upper():gsub('^%s+', ''):gsub('%s+$', '')
    local notes = tostring(data.notes or ''):sub(1, 255)

    if targetName == '' or violation == '' or fineAmount <= 0 then
        TriggerClientEvent('QBCore:Notify', src, 'Name, violation, and a fine amount are required.', 'error')
        return
    end

    lastCitationAt[citizenid] = now
    local charinfo = Player.PlayerData.charinfo
    local officerName = (charinfo and charinfo.firstname or 'Unknown') .. ' ' .. (charinfo and charinfo.lastname or '')

    exports.oxmysql:execute(
        'INSERT INTO ' .. CITATIONS_TABLE .. ' (citizenid, officer_name, target_name, violation, fine_amount, plate, notes) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { citizenid, officerName, targetName, violation, fineAmount, plate, notes },
        function()
            TriggerClientEvent('QBCore:Notify', src, 'Citation issued to ' .. targetName .. ' ($' .. fineAmount .. ').', 'success')
            SendCitations(src)
        end
    )
end)

RegisterNetEvent('police:server:DeleteCitation', function(citationId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsEmployee(Player) then return end
    citationId = tonumber(citationId)
    if not citationId then return end

    exports.oxmysql:execute('SELECT citizenid FROM ' .. CITATIONS_TABLE .. ' WHERE id = ?', { citationId }, function(res)
        if not (res and res[1]) then return end
        if not (res[1].citizenid == Player.PlayerData.citizenid or MDT.IsSeniorCommand(Player)) then
            TriggerClientEvent('QBCore:Notify', src, 'You are not authorized to delete this citation.', 'error')
            return
        end
        exports.oxmysql:execute('DELETE FROM ' .. CITATIONS_TABLE .. ' WHERE id = ?', { citationId }, function()
            SendCitations(src)
        end)
    end)
end)

AddEventHandler('playerDropped', function()
    local Player = QBCore.Functions.GetPlayer(source)
    if Player then lastCitationAt[Player.PlayerData.citizenid] = nil end
end)
