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

-- Beds are tracked on the server now (before, only clients knew which bed was
-- taken, so every respawn went to bed 1 and a Sandy bed freed the wrong bed).
-- Insurance expiry is stored as "d/m/YYYY HH:MM". It used to be compared as
-- plain text ("10/1" < "9/1") and crashed when the metadata was missing,
-- which could block the respawn completely.
function HospitalInsuranceExpiry(Player)
	local expiry = Player and Player.PlayerData.metadata and Player.PlayerData.metadata["timerinsurance"]
	if type(expiry) ~= 'string' or expiry == '' then return nil end
	local d, m, y, hh, mm = expiry:match('^(%d+)/(%d+)/(%d+)%s+(%d+):(%d+)')
	if not d then return nil end
	return os.time({ day = tonumber(d), month = tonumber(m), year = tonumber(y), hour = tonumber(hh), min = tonumber(mm) })
end

function HospitalHasInsurance(Player)
	local ts = HospitalInsuranceExpiry(Player)
	return ts ~= nil and ts > os.time()
end

-- Respawn without insurance: everything goes except Config.KeepItemsOnRespawn.
-- (the old code also wrote an empty inventory straight to the database, which
-- deleted the kept items too and could be overwritten by the next player save)
function WipeInventory(src, Player)
	local keep = Config.KeepItemsOnRespawn or {}
	if GetResourceState('ox_inventory') == 'started' then
		exports.ox_inventory:ClearInventory(src, keep)
		return
	end
	if #keep == 0 then
		Player.Functions.ClearInventory()
		return
	end
	local keepSet = {}
	for _, name in ipairs(keep) do keepSet[name] = true end
	local kept = {}
	for slot, item in pairs(Player.PlayerData.items or {}) do
		if item and keepSet[item.name] then kept[slot] = item end
	end
	Player.Functions.SetInventory(kept)
end

-- Price shown on the death screen (same rule as the respawn bill).
QBCore.Functions.CreateCallback('hospital:server:GetRespawnCost', function(source, cb)
	local Player = QBCore.Functions.GetPlayer(source)
	local insured = HospitalHasInsurance(Player)
	cb(insured and Config.insurancepersent or Config.BillCost, insured)
end)

local BedOwners = { beds = {}, bedssandy = {} } -- [list][bedId] = source
local BED_EVENT = { beds = 'hospital:client:SetBed', bedssandy = 'hospital:client:SetBedsandy' }

local function SetBedTaken(list, id, src)
	local bed = Config.Locations[list] and Config.Locations[list][id]
	if not bed then return end
	BedOwners[list][id] = src
	bed.taken = src ~= nil
	TriggerClientEvent(BED_EVENT[list], -1, id, src ~= nil)
end

local function FreeBedsOf(src)
	for list, owners in pairs(BedOwners) do
		for id, owner in pairs(owners) do
			if owner == src then SetBedTaken(list, id, nil) end
		end
	end
end

local function FreeBed(list)
	for k in pairs(Config.Locations[list] or {}) do
		local owner = BedOwners[list][k]
		if not owner or not QBCore.Functions.GetPlayer(owner) then return k end
	end
	return next(Config.Locations[list] or {}) -- all full: share the first bed rather than leave the player stuck
end

local function IsEms(Player)
	return Player ~= nil and Player.PlayerData.job.name == 'ambulance'
end

-- simple per-player rate limit: Throttle('alert', src, 30) → false if called again within 30 s
local throttles = {}
local function Throttle(name, src, seconds)
	throttles[name] = throttles[name] or {}
	local now = os.time()
	local last = throttles[name][src]
	if last and now - last < seconds then return false end
	throttles[name][src] = now
	return true
end

local function IsDown(Player)
	local meta = Player and Player.PlayerData.metadata or {}
	return meta["isdead"] == true or meta["inlaststand"] == true
end

-- server-side distance check (OneSync): stops remote revives / heals from across the map
local function IsNear(src, target, maxDist)
	local a, b = GetPlayerPed(src), GetPlayerPed(target)
	if a == 0 or b == 0 then return false end
	return #(GetEntityCoords(a) - GetEntityCoords(b)) <= (maxDist or 5.0)
end

local function NearBed(src, bed)
	local ped = GetPlayerPed(src)
	if ped == 0 or not bed then return false end
	local c = bed.coords
	return #(GetEntityCoords(ped) - vector3(c.x, c.y, c.z)) <= (Config.CheckInDistance or 60.0)
end

-- Self check-in is closed while enough medics are on duty (they treat you instead).
local function CheckInBlocked()
	return QBCore.Functions.GetDutyCount('ambulance') >= (Config.CheckInBlockDoctors or 2)
end

-- Bill for a hospital treatment (insured = cheaper).
local function ChargeHospitalBill(Player)
	local cost = HospitalHasInsurance(Player) and Config.insurancepersent or Config.BillCost
	Player.Functions.RemoveMoney("bank", cost, "respawned-at-hospital")
	TriggerEvent('qb-bossmenu:server:addAccountMoney', "ambulance", cost)
end

-- Food & water back to full after an admin heal (done here: the client used to send
-- QBCore:Server:SetMetaData itself, an event that lets a client set any metadata).
local function RefillNeeds(src)
	local Player = QBCore.Functions.GetPlayer(src)
	if not Player then return end
	Player.Functions.SetMetaData('hunger', 100)
	Player.Functions.SetMetaData('thirst', 100)
	TriggerClientEvent('hud:client:UpdateNeeds', src, 100, 100)
end

local function AdminName(src)
	return src == 0 and 'Console' or (GetPlayerName(src) or ('ID ' .. tostring(src)))
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

local function SendToBed(src, list, bedId, isRevive, clientEvent)
	isRevive = isRevive == true
	local Player = QBCore.Functions.GetPlayer(src)
	bedId = tonumber(bedId)
	local bed = bedId and Config.Locations[list][bedId]
	if not Player or not bed then return end
	-- You have to actually be at the hospital (was: any client could teleport into a bed / get a free heal).
	if not NearBed(src, bed) then return end
	-- a downed player could "lie in bed" to teleport away from where they fell
	if not isRevive and IsDown(Player) then return end
	-- bed already used by another online player
	local owner = BedOwners[list][bedId]
	if owner and owner ~= src and QBCore.Functions.GetPlayer(owner) then
		TriggerClientEvent('QBCore:Notify', src, Lang:t('error.beds_taken'), 'error')
		return
	end
	if isRevive and CheckInBlocked() then
		TriggerClientEvent('QBCore:Notify', src, Lang:t('error.checkin_blocked'), 'error')
		return
	end
	FreeBedsOf(src)
	TriggerClientEvent(clientEvent, src, bedId, bed, isRevive)
	SetBedTaken(list, bedId, src)
	-- A check-in treatment is always billed (the client used to decide that with a "bill" flag).
	if isRevive then ChargeHospitalBill(Player) end
end

RegisterNetEvent('hospital:server:SendToBed', function(bedId, isRevive)
	SendToBed(source, 'beds', bedId, isRevive, 'hospital:client:SendToBed')
end)

RegisterNetEvent('hospital:server:SendToBedsandy', function(bedId, isRevive)
	SendToBed(source, 'bedssandy', bedId, isRevive, 'hospital:client:SendToBedsandy')
end)

RegisterNetEvent('hospital:server:RespawnAtHospital', function()
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	if not Player then return end
	-- only a dead player can respawn (not while still bleeding out), and only once (no double bill / free heal)
	if not Player.PlayerData.metadata["isdead"] then return end
	for _, owners in pairs(BedOwners) do
		for _, owner in pairs(owners) do
			if owner == src then return end
		end
	end
	PatientRecovered(src, 'respawned')

	local k = FreeBed("beds")
	if not k then return end
	local insured = HospitalHasInsurance(Player)
	TriggerClientEvent('hospital:client:SendToBed', src, k, Config.Locations["beds"][k], true)
	SetBedTaken('beds', k, src)

	if Config.WipeInventoryOnRespawn and not insured then
		WipeInventory(src, Player)
		TriggerClientEvent('QBCore:Notify', src, Lang:t('error.possessions_taken'), 'error', 7000)
	elseif Config.WipeInventoryOnRespawn then
		TriggerClientEvent('QBCore:Notify', src, Lang:t('success.insurance_kept'), 'success', 7000)
	end
	local cost = insured and Config.insurancepersent or Config.BillCost
	Player.Functions.RemoveMoney("bank", cost, "respawned-at-hospital")
	TriggerEvent('qb-bossmenu:server:addAccountMoney', "ambulance", cost)
	TriggerClientEvent('hospital:client:SendBillEmail', src, cost)
end)

RegisterNetEvent('hospital:server:ambulanceAlert', function(text, kind, info)
    local src = source
    -- only a player who is really down can call for help, and not more than every 20 s
    if not IsDown(QBCore.Functions.GetPlayer(src)) or not Throttle('alert_' .. (kind == 'dead' and 'dead' or 'down'), src, 20) then return end
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

RegisterNetEvent('hospital:server:LeaveBed', function()
    FreeBedsOf(source) -- frees the bed this player really had (Pillbox or Sandy)
end)

-- Only keep what the hospital knows about (the client could send anything: huge tables,
-- strings instead of numbers... which crashed the status callbacks).
local function CleanInjuries(data)
	local clean = { limbs = {}, isBleeding = 0, onPainKillers = data.onPainKillers == true }
	local bleed = math.floor(tonumber(data.isBleeding) or 0)
	clean.isBleeding = math.max(0, math.min(4, bleed))
	for part in pairs(Config.BoneIndexes) do
		local limb = type(data.limbs) == 'table' and data.limbs[part]
		if part ~= 'NONE' and type(limb) == 'table' then
			local severity = math.max(0, math.min(4, math.floor(tonumber(limb.severity) or 0)))
			clean.limbs[part] = {
				label = tostring(limb.label or part):sub(1, 40),
				isDamaged = limb.isDamaged == true and severity > 0,
				severity = severity,
				causeLimp = limb.causeLimp == true,
			}
		end
	end
	return clean
end

RegisterNetEvent('hospital:server:SyncInjuries', function(data)
    if type(data) ~= 'table' then return end
    PlayerInjuries[source] = CleanInjuries(data)
end)

RegisterNetEvent('hospital:server:SetWeaponDamage', function(data)
	local src = source
	if type(data) ~= 'table' or not QBCore.Functions.GetPlayer(src) then return end
	local clean = {}
	for _, weapon in ipairs(data) do
		if #clean >= 15 then break end
		if type(weapon) == 'string' and QBCore.Shared.Weapons[weapon] then clean[#clean + 1] = weapon end
	end
	PlayerWeaponWounds[src] = clean
end)

RegisterNetEvent('hospital:server:RestoreWeaponDamage', function()
	PlayerWeaponWounds[source] = nil
end)

RegisterNetEvent('hospital:server:SetDeathStatus', function(isDead)
	local src = source
	isDead = isDead == true
	local Player = QBCore.Functions.GetPlayer(src)
	if Player then
		Player.Functions.SetMetaData("isdead", isDead)
		-- Got back up (revived by a medic / first aid / admin): their open "civilian down"
		-- call in the EMS tablet turns CONTAINED so units know.
		if not isDead then PatientRecovered(src, 'revived') end
	end
end)

local lastNeedsRefill = {}
RegisterNetEvent('hospital:server:SetMetaData', function()
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	if not Player then return end
	-- only after a heal/revive, not spammable for free food & water
	if lastNeedsRefill[src] and os.time() - lastNeedsRefill[src] < 30 then return end
	lastNeedsRefill[src] = os.time()
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
	bool = bool == true
	local Player = QBCore.Functions.GetPlayer(src)
	if Player then
		Player.Functions.SetMetaData("inlaststand", bool)
	end
end)

RegisterNetEvent('hospital:server:SetArmor', function(amount)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	if not Player then return end
	-- was: any value from the client was saved (free 100 armor after relog)
	amount = math.floor(tonumber(amount) or 0)
	local ped = GetPlayerPed(src)
	local real = ped ~= 0 and GetPedArmour(ped) or 0
	Player.Functions.SetMetaData("armor", math.max(0, math.min(amount, real, 100)))
end)

RegisterNetEvent('hospital:server:TreatWounds', function(playerId)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	playerId = tonumber(playerId)
	local Patient = playerId and QBCore.Functions.GetPlayer(playerId)
	if not Patient or not IsEms(Player) or not IsNear(src, playerId, 5.0) then return end
	if Player.Functions.RemoveItem('bandage', 1) then
		TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items['bandage'], "remove")
		TriggerClientEvent("hospital:client:HealInjuries", Patient.PlayerData.source, "full")
	else
		TriggerClientEvent('QBCore:Notify', src, Lang:t('error.no_bandage'), "error")
	end
end)

RegisterNetEvent('hospital:server:SetDoctor', function()
	if not Throttle('setdoctor', source, 2) then return end
	local amount = 0
    local players = QBCore.Functions.GetQBPlayers()
    for k,v in pairs(players) do
        if v.PlayerData.job.name == 'ambulance' and v.PlayerData.job.onduty then
            amount = amount + 1
        end
	end
	TriggerClientEvent("hospital:client:SetDoctorCount", -1, amount)

end)

-- Medic revive with the defibrillator (patient with no pulse). Checked here: before,
-- any client could revive anybody from anywhere.
-- A patient who is still bleeding out is brought back with CPR + a First Aid kit
-- (qb-ems-tools) — the old instant first-aid revive is gone.
RegisterNetEvent('hospital:server:RevivePlayer', function(playerId, isOldMan)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	playerId = tonumber(playerId)
	local Patient = playerId and QBCore.Functions.GetPlayer(playerId)
	if not Player or not Patient or playerId == src then return end
	if not IsNear(src, playerId, 5.0) then return end
	if not Patient.PlayerData.metadata["isdead"] then return end
	if not IsEms(Player) or not Player.Functions.GetItemByName('defibrillator') then
		TriggerClientEvent('QBCore:Notify', src, Lang:t('error.no_defib'), "error")
		return
	end
	-- paid revive: only charged once we know the revive can happen
	if isOldMan and not Player.Functions.RemoveMoney("cash", 5000, "revived-player") then
		TriggerClientEvent('QBCore:Notify', src, Lang:t('error.not_enough_money'), "error")
		return
	end
	TriggerClientEvent('hospital:client:Revive', Patient.PlayerData.source)
	TriggerEvent('hospital:server:PatientRevivedBy', src, Patient.PlayerData.source, 'defib')
end)

RegisterNetEvent('hospital:server:SendDoctorAlert', function(street)
    local src = source
    if not Throttle('checkin', src, 30) then return end
    if EmsTabletActive() then
        -- Blue "patient waiting at check-in" call in the EMS tablet (rate limited there).
        TriggerEvent('ems-mdt:server:HospitalAlert', src, 'checkin', { street = type(street) == 'string' and street:sub(1, 60) or nil })
        return
    end
    for k,v in pairs(QBCore.Functions.GetQBPlayers()) do
        if v.PlayerData.job.name == 'ambulance' and v.PlayerData.job.onduty then
			TriggerClientEvent('QBCore:Notify', v.PlayerData.source, Lang:t('info.dr_needed'), 'info')
		end
	end
end)

-- Live injuries for the EMS tablet (Patient Records → Current Condition).
-- exports['qb-hospital']:GetPatientStatus(serverId)
exports('GetPatientStatus', function(src)
	src = tonumber(src)
	if not src then return nil end
	local result = { limbs = {}, weapons = {}, bleedLevel = 0 }
	local data = PlayerInjuries[src]
	if data then
		local bleed = tonumber(data.isBleeding) or 0
		result.bleedLevel = bleed
		result.painkillers = data.onPainKillers == true
		if bleed > 0 and Config.BleedingStates[bleed] then result.bleeding = Config.BleedingStates[bleed].label end
		for part, limb in pairs(data.limbs or {}) do
			if type(limb) == 'table' and limb.isDamaged then
				local severity = tonumber(limb.severity) or 0
				result.limbs[#result.limbs + 1] = { part = part, label = limb.label, severity = severity, state = Config.WoundStates[severity] or '' }
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
	lastNeedsRefill[src] = nil
	for _, t in pairs(throttles) do t[src] = nil end
	FreeBedsOf(src)
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
	playerId = tonumber(playerId)
	-- medics, or someone standing next to the patient (was: anyone, from anywhere)
	if not playerId or (not IsEms(QBCore.Functions.GetPlayer(source)) and not IsNear(source, playerId, 10.0)) then return cb({ WEAPONWOUNDS = {} }) end
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
	playerId = tonumber(playerId)
	if not playerId or not IsNear(source, playerId, 10.0) then return cb(nil) end
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
	local isBlock = CheckInBlocked()

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
    	local Player = QBCore.Functions.GetPlayer(src)
    	if not Player then return end
    	-- goes to every player: one call every 30 s, short text
    	if not Throttle('997', src, 30) then
    		return TriggerClientEvent('QBCore:Notify', src, 'Please wait before sending another call', 'error')
    	end
    	local message = args[1] and table.concat(args, " "):sub(1, 150) or Lang:t('info.civ_call')
        local coords = GetEntityCoords(GetPlayerPed(src))
    	local name = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
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
    	if IsEms(Player) and playerId then
    		table.remove(args, 1)
    		local msg = table.concat(args, ' '):sub(1, 150)
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
				"**" .. AdminName(src) .. "** Just Revived **" .. AdminName(Player.PlayerData.source) .. "**",
				false
			)
		else
			TriggerClientEvent('QBCore:Notify', src, Lang:t('error.not_online'), "error")
		end
	elseif src ~= 0 then
		TriggerClientEvent('hospital:client:Revive', src)
		QBCore.Functions.CreateLog(
			"revive",
			"Admin Revive",
			"green",
			"**" .. AdminName(src) .. "** Just Revived Him Self",
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
	elseif src ~= 0 then
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
	elseif src ~= 0 then
		TriggerClientEvent('hospital:client:KillPlayer', src)
	end
end, "admin")

QBCore.Commands.Add('arevive', Lang:t('info.heal_player_a'), {{name = 'id', help = Lang:t('info.player_id')}}, false, function(source, args)
	local src = source
	if args[1] then
		local Player = QBCore.Functions.GetPlayer(tonumber(args[1]))
		if Player then
			TriggerClientEvent('hospital:client:adminHeal', Player.PlayerData.source)
			RefillNeeds(Player.PlayerData.source)
		else
			TriggerClientEvent('QBCore:Notify', src, Lang:t('error.not_online'), "error")
		end
	elseif src ~= 0 then
		TriggerClientEvent('hospital:client:adminHeal', src)
		RefillNeeds(src)
	end
end, {'god', 'admin'})

-- metadata.ems can be missing on characters made before it was added (crashed before)
local function SetDispatch(Player, value)
	if Player.Functions.SetEmsPoints then
		Player.Functions.SetEmsPoints('dispatch', value)
	else
		local ems = Player.PlayerData.metadata['ems'] or {}
		ems.dispatch = value
		Player.Functions.SetMetaData('ems', ems)
	end
end

QBCore.Functions.CreateCallback('hospital:server:DispatchCheck', function(source, cb)
    local MyPlayer = QBCore.Functions.GetPlayer(source)
    if not IsEms(MyPlayer) then return cb(false) end
    for _, v in pairs(QBCore.Functions.GetQBPlayers()) do
        if v.PlayerData.job.name == MyPlayer.PlayerData.job.name and (v.PlayerData.metadata['ems'] or {})['dispatch'] then
            return cb(false)
        end
    end
    SetDispatch(MyPlayer, true)
    cb(true)
end)

RegisterNetEvent('hospital:ToggleDispatchoff', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    SetDispatch(Player, false)
    TriggerClientEvent('QBCore:Notify', src, 'You left the dispatch', 'primary', 7500)
end)

-- Items
-- Self-use items: the item is only taken when the progress bar finishes. The client
-- used to remove it itself with QBCore:Server:RemoveItem (gone in new qb-core, so the
-- items were never used up — or, on old cores, any client could delete any item).
local SELF_USE = { ifaks = 'hospital:client:UseIfaks', bandage = 'hospital:client:UseBandage', painkillers = 'hospital:client:UsePainkillers' }
local pendingUse = {} -- [src] = { item = name, at = os.time() }

for name, clientEvent in pairs(SELF_USE) do
	QBCore.Functions.CreateUseableItem(name, function(source, item)
		local Player = QBCore.Functions.GetPlayer(source)
		if Player and Player.Functions.GetItemByName(item.name) then
			pendingUse[source] = { item = name, at = os.time() }
			TriggerClientEvent(clientEvent, source)
		end
	end)
end

RegisterNetEvent('hospital:server:ConsumeItem', function(name)
	local src = source
	local pending = pendingUse[src]
	pendingUse[src] = nil
	if not pending or pending.item ~= name or os.time() - pending.at > 30 then return end
	local Player = QBCore.Functions.GetPlayer(src)
	if Player and Player.Functions.RemoveItem(name, 1) then
		TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[name], "remove")
	end
end)

AddEventHandler('playerDropped', function() pendingUse[source] = nil end)

-- "firstaid" is used by qb-ems-tools: it is the kit needed for CPR (1-3 rounds by severity).
