local QBCore = Config.CoreExport()

local getLicense = function(source, type)
    local Player = QBCore.Functions.GetPlayer(source)
    local isHave = Player.PlayerData.metadata['licences'][type]
	if isHave then
		return ('<span class="text" style="color:green">%s</span>'):format(Config.DisplayTexts[type].have)
	else
		return ('<span class="text" style="color:gray">%s</span>'):format(Config.DisplayTexts[type].notHave)
	end
end

showDocument = function(source, type, imageUrl)
    local src = source
    local found = false
    local Player = QBCore.Functions.GetPlayer(src)
    local PlayerPed = GetPlayerPed(src)
    local PlayerCoords = GetEntityCoords(PlayerPed)
    local documentTable = Config.Documents[type]
    
    if documentTable then
        TriggerClientEvent("qb-document:client:animation", src)
        local playerInfo = {}
        if type == "id_card" then
            playerInfo = {
                ['firstname'] = Player.PlayerData.charinfo.firstname,
                ['lastname'] = Player.PlayerData.charinfo.lastname,
                ['nationality'] = Player.PlayerData.charinfo.nationality,
                ['sex'] = Player.PlayerData.charinfo.gender == 0 and Config.Texts['male'] or Config.Texts['female'],
                ['dob'] = Player.PlayerData.charinfo.birthdate,
            }
        elseif type == "id_drive" then
            playerInfo = {
                ['firstname'] = Player.PlayerData.charinfo.firstname,
                ['lastname'] = Player.PlayerData.charinfo.lastname,
                ['dob'] = Player.PlayerData.charinfo.birthdate,
                ['sex'] = Player.PlayerData.charinfo.gender == 0 and Config.Texts['male'] or Config.Texts['female'],
                ['drive_bike'] = getLicense(src, "drive_bike"),
                ['drive'] = getLicense(src, "drive"),
                ['drive_truck'] = getLicense(src, "drive_truck"),
            }
        elseif type == "id_lawyer" then
                playerInfo = {
                    ['firstname'] = Player.PlayerData.charinfo.firstname,
                    ['lastname'] = Player.PlayerData.charinfo.lastname,
                    ['nationality'] = Player.PlayerData.charinfo.nationality,
                    ['sex'] = Player.PlayerData.charinfo.gender == 0 and Config.Texts['male'] or Config.Texts['female'],
                    ['dob'] = Player.PlayerData.charinfo.birthdate,
                }
        elseif type == "id_fly" then
            playerInfo = {
                ['firstname'] = Player.PlayerData.charinfo.firstname,
                ['lastname'] = Player.PlayerData.charinfo.lastname,
                ['dob'] = Player.PlayerData.charinfo.birthdate,
                ['sex'] = Player.PlayerData.charinfo.gender == 0 and Config.Texts['male'] or Config.Texts['female'],
                ['flying_helicopter'] = getLicense(src, "flying_helicopter"),
                ['flying_plane'] = getLicense(src, "flying_plane"),
            }
        elseif type == "id_boat" then
            playerInfo = {
                ['firstname'] = Player.PlayerData.charinfo.firstname,
                ['lastname'] = Player.PlayerData.charinfo.lastname,
                ['dob'] = Player.PlayerData.charinfo.birthdate,
                ['sex'] = Player.PlayerData.charinfo.gender == 0 and Config.Texts['male'] or Config.Texts['female'],
                ['drive_boat'] = getLicense(src, "drive_boat"),
            }
        elseif type == "id_weapon" then
            playerInfo = {
                ['firstname'] = Player.PlayerData.charinfo.firstname,
                ['lastname'] = Player.PlayerData.charinfo.lastname,
                ['dob'] = Player.PlayerData.charinfo.birthdate,
                ['sex'] = Player.PlayerData.charinfo.gender == 0 and Config.Texts['male'] or Config.Texts['female'],
                ['weapon'] = getLicense(src, "weapon"),
            }
        elseif type == "id_law" then
            playerInfo = {
                ['firstname'] = Player.PlayerData.charinfo.firstname,
                ['lastname'] = Player.PlayerData.charinfo.lastname,
                ['dob'] = Player.PlayerData.charinfo.birthdate,
                ['sex'] = Player.PlayerData.charinfo.gender == 0 and Config.Texts['male'] or Config.Texts['female'],
                ['jaber'] = getLicense(src, "jaber"),
            }
        end
        TriggerClientEvent("qb-document:client:notify", src, Config.Texts["notify_title"], documentTable.notifyText, 2500, "fa fa-address-card", "success")
        local players = QBCore.Functions.GetQBPlayers()
        for k, v in pairs(players) do
            local TargetPed = GetPlayerPed(v.PlayerData.source)
            local dist = #(PlayerCoords - GetEntityCoords(TargetPed))
            if dist < 3.0 and PlayerPed ~= TargetPed then
                TriggerClientEvent('qb-document:client:send', v.PlayerData.source, type, playerInfo, imageUrl)
                found = true
                break
            end
        end
        if not found then 
            TriggerClientEvent('qb-document:client:send', src, type, playerInfo, imageUrl)
        end
    end
end

RegisterNetEvent("qb-document:show")
AddEventHandler("qb-document:show", function(type, imageUrl)
    showDocument(source, type, imageUrl)
end)

QBCore.Functions.CreateCallback('qb-document:getImage', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    local loaded_data = LoadResourceFile(GetCurrentResourceName(), "photos.json")
    local file_data = json.decode(loaded_data or "{}")
    if file_data[Player.PlayerData.citizenid] then
        cb(file_data[Player.PlayerData.citizenid])
    else
        cb(nil)
    end
end)

RegisterNetEvent("qb-document:saveMugshot")
AddEventHandler("qb-document:saveMugshot", function(imageUrl)
    local _source = source
    local Player = QBCore.Functions.GetPlayer(_source)
    if Config.MustMakePhoto and Config.PhotoPrice > 0 then
        local myMoney = Player.Functions.GetMoney('cash')
        if myMoney >= Config.PhotoPrice then
            local loaded_data = LoadResourceFile(GetCurrentResourceName(), "photos.json")
            local file_data = json.decode(loaded_data or '{}')
            file_data[Player.PlayerData.citizenid] = imageUrl
            SaveResourceFile(GetCurrentResourceName(), "photos.json", json.encode(file_data, {indent = true}), -1)
            Player.Functions.RemoveMoney('cash', Config.PhotoPrice, Config.Texts['document_pay_reason'])
            TriggerClientEvent("qb-document:client:notify", _source, Config.Texts["notify_title_photo"], (Config.Texts["you_paid_for_photo"]):format(Config.PhotoPrice), 4500, "fa-solid fa-camera", "success")
        else
            TriggerClientEvent("qb-document:client:notify", _source, Config.Texts["notify_title_photo"], Config.Texts["not_have_money"], 4500, "fa-solid fa-camera", "error")
        end
    else
        local loaded_data = LoadResourceFile(GetCurrentResourceName(), "photos.json")
        local file_data = json.decode(loaded_data or '{}')
        file_data[Player.PlayerData.citizenid] = imageUrl
        SaveResourceFile(GetCurrentResourceName(), "photos.json", json.encode(file_data, {indent = true}), -1)
        if Config.MustMakePhoto then
            TriggerClientEvent("qb-document:client:notify", _source, Config.Texts["notify_title_photo"], Config.Texts["you_do_photo"], 4500, "fa-solid fa-camera", "success")
        end
    end
end)

for k, v in pairs(Config.Documents) do
    if v.item then
        QBCore.Functions.CreateUseableItem(v.item, function(source, item)
            TriggerClientEvent("qb-document:showMyDocument", source, k)
        end)
    end
end
