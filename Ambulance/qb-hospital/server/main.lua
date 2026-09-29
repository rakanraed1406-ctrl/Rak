local PlayerInjuries = {}
local PlayerWeaponWounds = {}
local QBCore = exports['qb-core']:GetCoreObject()

-- EMS tablet (mdt-ems-tablet) replaces cd_dispatch for every hospital alert.
local function EmsTabletActive()
	local cfg = Config.EmsTablet
	return cfg and cfg.Enabled and GetResourceState(cfg.Resource or 'mdt-ems-tablet') == 'started'
end

local function PatientRecovered(src, reason)
	if EmsTabletActive() then TriggerEvent('ems-mdt:server:PatientRecovered', src, reason) end
end
-- Events

-- Compatibility with txAdmin Menu's heal options.
-- This is an admin only server side event that will pass the target player id or -1.
AddEventHandler('txAdmin:events:healedPlayer', function(eventData)
	if GetInvokingResource() ~= "monitor" or type(eventData) ~= "table" or type(eventData.id) ~= "number" then
		return
	end

	TriggerClientEvent('hospital:client:Revive', eventData.id)
	TriggerClientEvent("hospital:client:HealInjuries", eventData.id, "full")
end)

-- RegisterNetEvent('hospital:server:SendToBed', function(bedId, isRevive)
-- 	local src = source
-- 	local Player = QBCore.Functions.GetPlayer(src)
-- 	TriggerClientEvent('hospital:client:SendToBed', src, bedId, Config.Locations["beds"][bedId], isRevive)
-- 	TriggerClientEvent('hospital:client:SetBed', -1, bedId, true)
-- 	Player.Functions.RemoveMoney("bank", Config.BillCost , "respawned-at-hospital")
-- 	TriggerEvent('qb-bossmenu:server:addAccountMoney', "ambulance", Config.BillCost)
-- 	TriggerClientEvent('hospital:client:SendBillEmail', src, Config.BillCost)
-- end)

RegisterNetEvent('hospital:server:SendToBed', function(bedId, isRevive, bill)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	TriggerClientEvent('hospital:client:SendToBed', src, bedId, Config.Locations["beds"][bedId], isRevive)
	TriggerClientEvent('hospital:client:SetBed', -1, bedId, true)
	if bill then 
		local current_time = os.time()
		local jaber = os.date("%d/%m/%Y %H:%M", current_time):gsub("0*(%d+)/0*(%d+)/", "%1/%2/") 
		if jaber >= Player.PlayerData.metadata["timerinsurance"] or Player.PlayerData.metadata["timerinsurance"] == "" then
			Player.Functions.RemoveMoney("bank", Config.BillCost , "respawned-at-hospital")
			TriggerEvent('qb-bossmenu:server:addAccountMoney', "ambulance", Config.BillCost)
			else
				Player.Functions.RemoveMoney("bank", Config.insurancepersent , "respawned-at-hospital")
				TriggerEvent('qb-bossmenu:server:addAccountMoney', "ambulance", Config.insurancepersent)
				TriggerEvent("jabertestcode")
		end
	end
end)

RegisterNetEvent('hospital:server:SendToBedsandy', function(bedId, isRevive, bill)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	TriggerClientEvent('hospital:client:SendToBedsandy', src, bedId, Config.Locations["bedssandy"][bedId], isRevive)
	TriggerClientEvent('hospital:client:SetBedsandy', -1, bedId, true)
	if bill then 
		local current_time = os.time()
		local jaber = os.date("%d/%m/%Y %H:%M", current_time):gsub("0*(%d+)/0*(%d+)/", "%1/%2/") 
		if jaber >= Player.PlayerData.metadata["timerinsurance"] or Player.PlayerData.metadata["timerinsurance"] == "" then
			Player.Functions.RemoveMoney("bank", Config.BillCost , "respawned-at-hospital")
			TriggerEvent('qb-bossmenu:server:addAccountMoney', "ambulance", Config.BillCost)
			else
				Player.Functions.RemoveMoney("bank", Config.insurancepersent , "respawned-at-hospital")
				TriggerEvent('qb-bossmenu:server:addAccountMoney', "ambulance", Config.insurancepersent)
				TriggerEvent("jabertestcode")
		end
	end
end)

RegisterNetEvent('hospital:server:RespawnAtHospital', function()
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	PatientRecovered(src, 'respawned')
	local current_time = os.time()
	local jaber = os.date("%d/%m/%Y %H:%M", current_time):gsub("0*(%d+)/0*(%d+)/", "%1/%2/") 
	for k, v in pairs(Config.Locations["beds"]) do
		if not v.taken then
			TriggerClientEvent('hospital:client:SendToBed', src, k, v, true)
			TriggerClientEvent('hospital:client:SetBed', -1, k, true)
			if Config.WipeInventoryOnRespawn then
				if jaber >= Player.PlayerData.metadata["timerinsurance"] or Player.PlayerData.metadata["timerinsurance"] == "" then
				Player.Functions.ClearInventory()
				MySQL.Async.execute('UPDATE players SET inventory = ? WHERE citizenid = ?', { json.encode({}), Player.PlayerData.citizenid })
				TriggerClientEvent('QBCore:Notify', src, Lang:t('error.possessions_taken'), 'error')
				else
					TriggerEvent("jabertestcode")
				end
			end
			if jaber >= Player.PlayerData.metadata["timerinsurance"] or Player.PlayerData.metadata["timerinsurance"] == "" then
			Player.Functions.RemoveMoney("bank", Config.BillCost, "respawned-at-hospital")
			TriggerEvent('qb-bossmenu:server:addAccountMoney', "ambulance", Config.BillCost)
			TriggerClientEvent('hospital:client:SendBillEmail', src, Config.BillCost)
			else
				Player.Functions.RemoveMoney("bank", Config.insurancepersent, "respawned-at-hospital")
				TriggerEvent('qb-bossmenu:server:addAccountMoney', "ambulance", Config.insurancepersent)
				TriggerClientEvent('hospital:client:SendBillEmail', src, Config.insurancepersent)
			end
			return
		end
	end
end)

RegisterNetEvent('hospital:server:ambulanceAlert', function(text, kind, info)
    local src = source
    if EmsTabletActive() then
        -- Dispatch call in the EMS tablet: red "No pulse" / yellow "Bleeding out", with injuries.
        TriggerEvent('ems-mdt:server:HospitalAlert', src, kind == 'dead' and 'dead' or 'down', type(info) == 'table' and info or {})
        return
    end
    -- Fallback (tablet not running): the old blip for every EMS / doctor.
    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
	TriggerClientEvent('hospital:client:ambulanceAlert', -1, coords, tostring(text or Lang:t('info.civ_down')):sub(1, 60))
end)

RegisterNetEvent('hospital:server:LeaveBed', function(id)
    TriggerClientEvent('hospital:client:SetBed', -1, id, false)
end)

RegisterNetEvent('hospital:server:SyncInjuries', function(data)
    local src = source
    PlayerInjuries[src] = data
end)

RegisterNetEvent('hospital:server:SetWeaponDamage', function(data)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	if Player then
		PlayerWeaponWounds[Player.PlayerData.source] = data
	end
end)

RegisterNetEvent('hospital:server:RestoreWeaponDamage', function()
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	PlayerWeaponWounds[Player.PlayerData.source] = nil
end)

RegisterNetEvent('hospital:server:SetDeathStatus', function(isDead)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	if Player then
		Player.Functions.SetMetaData("isdead", isDead)
		-- Got back up (revived by a medic / first aid / admin): their open "civilian down"
		-- call in the EMS tablet turns CONTAINED so units know.
		if not isDead then PatientRecovered(src, 'revived') end
	end
end)

RegisterNetEvent('hospital:server:SetMetaData', function()
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	local newHunger = Player.PlayerData.metadata['hunger'] + 10
	local newThirst = Player.PlayerData.metadata['thirst'] + 10
	if newHunger > 100 then
		newHunger = 100
	end
	if newThirst > 100 then
		newThirst = 100
	end
	Player.Functions.SetMetaData('thirst', newThirst)
	Player.Functions.SetMetaData('hunger', newHunger)
	TriggerClientEvent('hud:client:UpdateNeeds', src, newHunger, newThirst)
end)

RegisterNetEvent('hospital:server:SetLaststandStatus', function(bool)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	if Player then
		Player.Functions.SetMetaData("inlaststand", bool)
	end
end)

RegisterNetEvent('hospital:server:SetArmor', function(amount)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	if Player then
		Player.Functions.SetMetaData("armor", amount)
	end
end)

RegisterNetEvent('hospital:server:TreatWounds', function(playerId)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	local Patient = QBCore.Functions.GetPlayer(playerId)
	if Patient then
		if Player.PlayerData.job.name =="ambulance" then
			Player.Functions.RemoveItem('bandage', 1)
			TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items['bandage'], "remove")
			TriggerClientEvent("hospital:client:HealInjuries", Patient.PlayerData.source, "full")
		end
	end
end)

RegisterNetEvent('hospital:server:SetDoctor', function()
	local amount = 0
    local players = QBCore.Functions.GetQBPlayers()
    for k,v in pairs(players) do
        if v.PlayerData.job.name == 'ambulance' and v.PlayerData.job.onduty then
            amount = amount + 1
        end
	end
	TriggerClientEvent("hospital:client:SetDoctorCount", -1, amount)

end)

RegisterNetEvent('hospital:server:RevivePlayer', function(playerId, isOldMan, bool)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	local Patient = QBCore.Functions.GetPlayer(playerId)
	local oldMan = isOldMan or false
	if Patient then
		if oldMan then
			if Player.Functions.RemoveMoney("cash", 5000, "revived-player") then
				if bool then 
					Player.Functions.RemoveItem('firstaid', 1)
					TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items['firstaid'], "remove")
				end
				TriggerClientEvent('hospital:client:Revive', Patient.PlayerData.source)
			else
				TriggerClientEvent('QBCore:Notify', src, Lang:t('error.not_enough_money'), "error")
			end
		else
			if bool then 
				Player.Functions.RemoveItem('firstaid', 1)
				TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items['firstaid'], "remove")
			end
			TriggerClientEvent('hospital:client:Revive', Patient.PlayerData.source)
		end
	end
end)

RegisterNetEvent('hospital:server:SendDoctorAlert', function(street)
    local src = source
    if EmsTabletActive() then
        -- Blue "patient waiting at check-in" call in the EMS tablet (rate limited there).
        TriggerEvent('ems-mdt:server:HospitalAlert', src, 'checkin', { street = type(street) == 'string' and street or nil })
        return
    end
    for k,v in pairs(QBCore.Functions.GetQBPlayers()) do
        if v.PlayerData.job.name == 'ambulance' and v.PlayerData.job.onduty then
			TriggerClientEvent('QBCore:Notify', v.PlayerData.source, Lang:t('info.dr_needed'), 'info')
		end
	end
end)

RegisterNetEvent('hospital:server:UseFirstAid', function(targetId)
	local src = source
	local Target = QBCore.Functions.GetPlayer(targetId)
	if Target then
		TriggerClientEvent('hospital:client:CanHelp', targetId, src)
	end
end)

RegisterNetEvent('hospital:server:CanHelp', function(helperId, canHelp)
	local src = source
	if canHelp then
		TriggerClientEvent('hospital:client:HelpPerson', helperId, src)
	else
		TriggerClientEvent('QBCore:Notify', helperId, Lang:t('error.cant_help'), "error")
	end
end)

-- Live injuries for the EMS tablet (Patient Records → Current Condition).
-- exports['qb-hospital']:GetPatientStatus(serverId)
exports('GetPatientStatus', function(src)
	src = tonumber(src)
	if not src then return nil end
	local result = { limbs = {}, weapons = {} }
	local data = PlayerInjuries[src]
	if data then
		local bleed = tonumber(data.isBleeding) or 0
		if bleed > 0 and Config.BleedingStates[bleed] then result.bleeding = Config.BleedingStates[bleed].label end
		for _, limb in pairs(data.limbs or {}) do
			if limb.isDamaged then
				result.limbs[#result.limbs + 1] = { label = limb.label, state = Config.WoundStates[tonumber(limb.severity) or 0] or '' }
			end
		end
	end
	for _, weapon in pairs(PlayerWeaponWounds[src] or {}) do
		local info = QBCore.Shared.Weapons[weapon]
		result.weapons[#result.weapons + 1] = info and info.label or tostring(weapon)
	end
	return result
end)

AddEventHandler('playerDropped', function()
	local src = source
	PlayerInjuries[src] = nil
	PlayerWeaponWounds[src] = nil
end)

-- Callbacks

QBCore.Functions.CreateCallback('hospital:GetDoctors', function(source, cb)
	local amount = 0
    local players = QBCore.Functions.GetQBPlayers()
    for k,v in pairs(players) do
        if v.PlayerData.job.name == 'ambulance' and v.PlayerData.job.onduty then
			amount = amount + 1
		end
	end
	cb(amount)
end)

QBCore.Functions.CreateCallback('hospital:GetPlayerStatus', function(source, cb, playerId)
	local Player = QBCore.Functions.GetPlayer(playerId)
	local injuries = {}
	injuries["WEAPONWOUNDS"] = {}
	if Player then
		if PlayerInjuries[Player.PlayerData.source] then
			if (PlayerInjuries[Player.PlayerData.source].isBleeding > 0) then
				injuries["BLEED"] = PlayerInjuries[Player.PlayerData.source].isBleeding
			end
			for k, v in pairs(PlayerInjuries[Player.PlayerData.source].limbs) do
				if PlayerInjuries[Player.PlayerData.source].limbs[k].isDamaged then
					injuries[k] = PlayerInjuries[Player.PlayerData.source].limbs[k]
				end
			end
		end
		if PlayerWeaponWounds[Player.PlayerData.source] then
			for k, v in pairs(PlayerWeaponWounds[Player.PlayerData.source]) do
				injuries["WEAPONWOUNDS"][k] = v
			end
		end
	end
    cb(injuries)
end)

QBCore.Functions.CreateCallback('hospital:GetPlayerBleeding', function(source, cb)
	local src = source
	if PlayerInjuries[src] and PlayerInjuries[src].isBleeding then
		cb(PlayerInjuries[src].isBleeding)
	else
		cb(nil)
	end
end)

QBCore.Functions.CreateCallback('hospital:server:GetPlayerStatus', function(source, cb, playerId)
	local Player = QBCore.Functions.GetPlayer(playerId)
	if Player then 
		cb(Player.PlayerData.metadata['isdead'], Player.PlayerData.metadata['inlaststand'])
	else
		cb(nil)
	end
end)

local DocGrades = {
	[8] = true,
	[9] = true,
	[10] = true,
}

QBCore.Functions.CreateCallback('hospital:server:GetTotalDoc', function(source, cb)
	local total = QBCore.Functions.GetDutyCount('ambulance')
	local isBlock = false
	if total >= 2 then 
		isBlock = true
	end

	-- for k, v in pairs(QBCore.Functions.GetQBPlayers()) do 
	-- 	if v.PlayerData.job.name == 'ambulance' and v.PlayerData.job.onduty then
	-- 		if DocGrades[tonumber(v.PlayerData.job.grade.level)] then 
	-- 			isBlock = true
	-- 		end
    --     end
	-- end
	cb(isBlock)
end)

-- Commands

-- /997 + /997r are provided by the EMS tablet (mdt-ems-tablet) when Config.EmsTablet.Enabled.
-- These are the old versions, only used when the tablet integration is turned off.
if not (Config.EmsTablet and Config.EmsTablet.Enabled) then
    QBCore.Commands.Add('997', Lang:t('info.ems_report'), {{name = 'message', help = Lang:t('info.message_sent')}}, false, function(source, args)
    	local src = source
    	if args[1] then message = table.concat(args, " ") else message = Lang:t('info.civ_call') end
        local ped = GetPlayerPed(src)
        local coords = GetEntityCoords(ped)
    	local Player = QBCore.Functions.GetPlayer(src)
    	local name = ''..Player.PlayerData.charinfo.firstname..' '..Player.PlayerData.charinfo.lastname..''
    	TriggerClientEvent('hospital:client:ambulanceAlert', -1, coords, message, name, src)
    end)

    -- QBCore.Commands.Add('997r', 'Report anwer', {{name = 'id', help = 'Player ID'}, {name = 'report', help = 'report answer'}}, false, function(source, args)
    -- 	local src = source
    -- 	local Player = QBCore.Functions.GetPlayer(src)
    -- 	if Player.PlayerData.job.name == 'ambulance' then 
    -- 		if not args[1] then return end
    -- 		if not args[2] then then return end
    -- 		local TargetID = tonumber(args[1])
    -- 		local msg = table.concat(args, ' ')
    -- 		local Target = QBCore.Functions.GetPlayer(TargetID)
    -- 		if Target then
    -- 			TriggerClientEvent('chatMessage', Target.PlayerData.source, "997 ", 'warning', "Answer : "..message.."") 
    -- 			TriggerClientEvent('QBCore:Notify', src, 'Answer sent', "success")
    -- 		end
    -- 	end
    -- end)

    QBCore.Commands.Add('997r', 'Report anwer', {{name='id', help='Player'}, {name = 'message', help = 'Message to respond with'}}, false, function(source, args)
        local src = source
    	local Player = QBCore.Functions.GetPlayer(src)
        local playerId = tonumber(args[1])
    	if Player.PlayerData.job.name == 'ambulance' then 
    		table.remove(args, 1)
    		local msg = table.concat(args, ' ')
    		local OtherPlayer = QBCore.Functions.GetPlayer(playerId)
    		if msg == '' then return end
    		if not OtherPlayer then return TriggerClientEvent('QBCore:Notify', src, 'Player is not online', 'error') end
    		TriggerClientEvent('chatMessage', OtherPlayer.PlayerData.source, "997 ", 'warning', "Answer : "..msg.."") 
    		TriggerClientEvent('QBCore:Notify', src, 'Answer sent', "success")
    	end
    end)
end

-- QBCore.Commands.Add("status", Lang:t('info.check_health'), {}, false, function(source, args)
-- 	local src = source
-- 	local Player = QBCore.Functions.GetPlayer(src)
-- 	if Player.PlayerData.job.name == "ambulance" then
-- 		TriggerClientEvent("hospital:client:CheckStatus", src)
-- 	else
-- 		TriggerClientEvent('QBCore:Notify', src, Lang:t('error.not_ems'), "error")
-- 	end
-- end)

-- QBCore.Commands.Add("heal", Lang:t('info.heal_player'), {}, false, function(source, args)
-- 	local src = source
-- 	local Player = QBCore.Functions.GetPlayer(src)
-- 	if Player.PlayerData.job.name == "ambulance" then
-- 		TriggerClientEvent("hospital:client:TreatWounds", src)
-- 	else
-- 		TriggerClientEvent('QBCore:Notify', src, Lang:t('error.not_ems'), "error")
-- 	end
-- end)

-- QBCore.Commands.Add("revivep", Lang:t('info.revive_player'), {}, false, function(source, args)
-- 	local src = source
-- 	local Player = QBCore.Functions.GetPlayer(src)
-- 	if Player.PlayerData.job.name == "ambulance" then
-- 		TriggerClientEvent("hospital:client:RevivePlayer", src)
-- 	else
-- 		TriggerClientEvent('QBCore:Notify', src, Lang:t('error.not_ems'), "error")
-- 	end
-- end)

QBCore.Commands.Add("revive", Lang:t('info.revive_player_a'), {{name = "id", help = Lang:t('info.player_id')}}, false, function(source, args)
	local src = source
	if args[1] then
		local Player = QBCore.Functions.GetPlayer(tonumber(args[1]))
		if Player then
			TriggerClientEvent('hospital:client:Revive', Player.PlayerData.source)
			QBCore.Functions.CreateLog(
				"revive",
				"Admin Revive",
				"green",
				"**"..GetPlayerName(src) .. "** Just Revived **"..GetPlayerName(Player.PlayerData.source) .. "**",
				false
			)
		else
			TriggerClientEvent('QBCore:Notify', src, Lang:t('error.not_online'), "error")
		end
	else
		TriggerClientEvent('hospital:client:Revive', src)
		QBCore.Functions.CreateLog(
			"revive",
			"Admin Revive",
			"green",
			"**"..GetPlayerName(src) .. "** Just Revived Him Self",
			false
		)
	end
end, "admin")

QBCore.Commands.Add("reviveall", 'revive all players', {}, false, function(source, args)
	local src = source
	TriggerClientEvent('hospital:client:Revive', -1)
end, "god")

QBCore.Commands.Add("setpain", Lang:t('info.pain_level'), {{name = "id", help = Lang:t('info.player_id')}}, false, function(source, args)
	local src = source
	if args[1] then
		local Player = QBCore.Functions.GetPlayer(tonumber(args[1]))
		if Player then
			TriggerClientEvent('hospital:client:SetPain', Player.PlayerData.source)
		else
			TriggerClientEvent('QBCore:Notify', src, Lang:t('error.not_online'), "error")
		end
	else
		TriggerClientEvent('hospital:client:SetPain', src)
	end
end, "admin")

QBCore.Commands.Add("kill", Lang:t('info.kill'), {{name = "id", help = Lang:t('info.player_id')}}, false, function(source, args)
	local src = source
	if args[1] then
		local Player = QBCore.Functions.GetPlayer(tonumber(args[1]))
		if Player then
			TriggerClientEvent('hospital:client:KillPlayer', Player.PlayerData.source)
		else
			TriggerClientEvent('QBCore:Notify', src, Lang:t('error.not_online'), "error")
		end
	else
		TriggerClientEvent('hospital:client:KillPlayer', src)
	end
end, "admin")

QBCore.Commands.Add('arevive', Lang:t('info.heal_player_a'), {{name = 'id', help = Lang:t('info.player_id')}}, false, function(source, args)
	local src = source
	if args[1] then
		local Player = QBCore.Functions.GetPlayer(tonumber(args[1]))
		if Player then
			TriggerClientEvent('hospital:client:adminHeal', Player.PlayerData.source)
		else
			TriggerClientEvent('QBCore:Notify', src, Lang:t('error.not_online'), "error")
		end
	else
		TriggerClientEvent('hospital:client:adminHeal', src)
	end
end, {'god', 'admin'})

QBCore.Functions.CreateCallback('hospital:server:DispatchCheck', function(source, cb)
    local src = source
    local MyPlayer = QBCore.Functions.GetPlayer(src)
    local answer = true
    for k, v in pairs(QBCore.Functions.GetQBPlayers()) do
        if v.PlayerData.job.name == MyPlayer.PlayerData.job.name and v.PlayerData.metadata['ems']['dispatch'] then
            answer = false
        end
    end
    if answer then 
        MyPlayer.Functions.SetEmsPoints('dispatch', true)
    end
    cb(answer)
end)

RegisterNetEvent('hospital:ToggleDispatchoff', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    Player.Functions.SetEmsPoints('dispatch', false)
    QBCore.Functions.Notify(src, 'You left the dispatch', 7500)
end)

-- Items

QBCore.Functions.CreateUseableItem("ifaks", function(source, item)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	if Player.Functions.GetItemByName(item.name) ~= nil then
		TriggerClientEvent("hospital:client:UseIfaks", src)
	end
end)

QBCore.Functions.CreateUseableItem("bandage", function(source, item)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	if Player.Functions.GetItemByName(item.name) ~= nil then
		TriggerClientEvent("hospital:client:UseBandage", src)
	end
end)

QBCore.Functions.CreateUseableItem("painkillers", function(source, item)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	if Player.Functions.GetItemByName(item.name) ~= nil then
		TriggerClientEvent("hospital:client:UsePainkillers", src)
	end
end)

QBCore.Functions.CreateUseableItem("firstaid", function(source, item)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	if Player.Functions.GetItemByName(item.name) ~= nil then
		TriggerClientEvent("hospital:client:UseFirstAid", src)
	end
end)
