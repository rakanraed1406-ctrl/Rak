-- Textures
Textures = { -- Do not change
    pin = 'pin',
    interact = 'interact',
    interactRed = 'interactRed',
    bg = 'bg',
    bgRed = 'bgRed'
}

Citizen.CreateThread(function()
	local txd = CreateRuntimeTxd('interactions_txd2')
	for _, v in pairs(Textures) do
		CreateRuntimeTextureFromImage(txd, tostring(v), "assets/" .. v .. ".png")
	end
end)

local isLoggedIn = LocalPlayer.state['isLoggedIn']
local Config = Config
local canContinue = true
local playerPed = PlayerPedId()
local playerCoords = GetEntityCoords(playerPed)
local lastCoords = playerCoords	
local nearbyDoors, closestDoor = {}, {}
local paused = false
local usingAdvanced = false
local doorData = {}

-- Functions
function Draw3DText(coords, str)
    local onScreen, worldX, worldY = World3dToScreen2d(coords.x, coords.y, coords.z)
	local camCoords = GetGameplayCamCoord()
	local scale = 200 / (GetGameplayCamFov() * #(camCoords - coords))
    if onScreen then
        SetTextScale(1.0, 0.5 * scale)
        SetTextFont(4)
        SetTextColour(255, 255, 255, 255)
        SetTextEdge(2, 0, 0, 0, 150)
		SetTextProportional(1)
		SetTextOutline()
		SetTextCentre(1)
        SetTextEntry("STRING")
        AddTextComponentString(str)
        DrawText(worldX, worldY)
    end
end

local function raycastWeapon()
    local offset = GetOffsetFromEntityInWorldCoords(GetCurrentPedWeaponEntityIndex(PlayerPedId()), 0, 0, -0.01)
    local direction = GetGameplayCamRot()
    direction = vec2(direction.x * math.pi / 180.0, direction.z * math.pi / 180.0)
    local num = math.abs(math.cos(direction.x))
    direction = vec3((-math.sin(direction.y) * num), (math.cos(direction.y) * num), math.sin(direction.x))
    local destination = vec3(offset.x + direction.x * 30, offset.y + direction.y * 30, offset.z + direction.z * 30)
	local hit, entityHit, result
    local rayHandle = StartShapeTestLosProbe(offset, destination, -1, PlayerPedId(), 0)
    repeat
        result, hit, _, _, entityHit = GetShapeTestResult(rayHandle)
        Wait(0)
    until result ~= 1
    if GetEntityType(entityHit) == 3 then return hit, entityHit else return false, 0 end
end

local function RotationToDirection(rotation)
	local adjustedRotation =
	{
		x = (math.pi / 180) * rotation.x,
		y = (math.pi / 180) * rotation.y,
		z = (math.pi / 180) * rotation.z
	}
	local direction =
	{
		x = -math.sin(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
		y = math.cos(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
		z = math.sin(adjustedRotation.x)
	}
	return direction
end

local function RayCastGamePlayCamera(distance)
    local cameraRotation = GetGameplayCamRot()
	local cameraCoord = GetGameplayCamCoord()
	local direction = RotationToDirection(cameraRotation)
	local destination =
	{
		x = cameraCoord.x + direction.x * distance,
		y = cameraCoord.y + direction.y * distance,
		z = cameraCoord.z + direction.z * distance
	}
	local _, hit, endCoords, _, _ = GetShapeTestResult(StartShapeTestRay(cameraCoord.x, cameraCoord.y, cameraCoord.z, destination.x, destination.y, destination.z, -1, PlayerPedId(), 0))
	return hit == 1, endCoords
end

local function setTextCoords(data)
    local minDimension, maxDimension = GetModelDimensions(data.objName or data.objHash)
    local dimensions = maxDimension - minDimension
    local dx, dy = tonumber(dimensions.x), tonumber(dimensions.y)
    if dy <= -1 or dy >= 1 then dx = dy end
    if data.fixText then
        return GetOffsetFromEntityInWorldCoords(data.object, dx / 2, 0, 0)
    else
        return GetOffsetFromEntityInWorldCoords(data.object, -dx / 2, 0, 0)
    end
end

local function getTextCoords(door)
	if door.setText then return door.textCoords end
	return setTextCoords(door)
end

local function round(value, numDecimalPlaces)
	if not numDecimalPlaces then return math.floor(value + 0.5) end
    local power = 10 ^ numDecimalPlaces
    return math.floor((value * power) + 0.5) / (power)
end

local function loadAnimDict(dict)
	RequestAnimDict(dict)
	while not HasAnimDictLoaded(dict) do
		Wait(0)
	end
end

local function playSound(door, src, enableSounds)
    if not Config.EnableSounds or not enableSounds then return end
	local origin
	if src and src ~= playerPed then src = NetworkGetEntityFromNetworkId(src) end
	if not src then origin = door.textCoords elseif src == playerPed then origin = playerCoords else origin = NetworkGetPlayerCoords(src) end
	local distance = #(playerCoords - origin)
	if distance < 10 then
		if not door.audioLock then
			if door.audioRemote then
				door.audioLock = {['file'] = 'button-remote.ogg', ['volume'] = 0.08}
				door.audioUnlock = {['file'] = 'button-remote.ogg', ['volume'] = 0.08}
			else
				door.audioLock = {['file'] = 'door-bolt-4.ogg', ['volume'] = 0.1}
				door.audioUnlock = {['file'] = 'door-bolt-4.ogg', ['volume'] = 0.1}
			end
		end
		local sfx_level = GetProfileSetting(300)
		local sound = door.locked and door.audioLock or door.audioUnlock
		SendNUIMessage({
			action = 'audio',
			audio = sound,
			distance = distance,
			sfx = sfx_level
		})
	end
end

local function doorAnim()
	if not Config.EnableAnimation then return end
	CreateThread(function()
		loadAnimDict("anim@heists@keycard@")
        TaskPlayAnim(PlayerPedId(), "anim@heists@keycard@", "exit", 8.0, 1.0, -1, 48, 0, 0, 0, 0)
        Wait(550)
        ClearPedTasks(PlayerPedId())
    end)
end

local function updateDoors(specificDoor)
	if #(playerCoords - lastCoords) > 30 then Wait(1000) end
    playerCoords = GetEntityCoords(PlayerPedId())
    for doorID, data in pairs(Config.DoorList) do
		if data.doors then
			if not data.doors[1].objCoords then
				local objName = data.doors[1].objName or "unknown"
				return print("door obj coords doesnt exist | " .. objName .. " | " .. doorID) 
			end
			if not data.doors[2].objCoords then
				local objName = data.doors[2].objName or "unknown"
				return print("door obj coords doesnt exist | " .. objName .. " | " .. doorID) 
			end
		else
			if not data.objCoords then
				local objName = data.objName or "unknown"
				return print("door obj coords doesnt exist | " .. objName .. " | " .. doorID) 
			end
		end
        if not specificDoor or doorID == specificDoor then
            if data.doors then
				if not data.doorType then data.doorType = 'double' end
                for k, v in pairs(data.doors) do
                    if #(playerCoords - v.objCoords) < 30 then
						if data.doorType == "doublesliding" then
							v.object = GetClosestObjectOfType(v.objCoords.x, v.objCoords.y, v.objCoords.z, 5.0, v.objName or v.objHash, false, false, false)
						else
							v.object = GetClosestObjectOfType(v.objCoords.x, v.objCoords.y, v.objCoords.z, 1.0, v.objName or v.objHash, false, false, false)
						end
                        if v.object and v.object ~= 0 then
                            v.doorHash = 'door_'..doorID..'_'..k
                            if not IsDoorRegisteredWithSystem(v.doorHash) then
								local objCoords = GetEntityCoords(v.object)
								local objHeading = GetEntityHeading(v.object)
								local hasHeading = v.objYaw or v.objHeading or false
								if v.objCoords ~= objCoords then v.objCoords = objCoords end -- Backwards compatibility fix
								if not hasHeading then
									v.objYaw = objHeading
								else
									if hasHeading ~= objHeading then -- Backwards compatibility fix
										v.objYaw = v.objYaw and objHeading or nil
										v.objHeading = v.objHeading and objHeading or nil
									end
								end
                                AddDoorToSystem(v.doorHash, v.objName or v.objHash, v.objCoords.x, v.objCoords.y, v.objCoords.z, false, false, false)
                                nearbyDoors[doorID] = true
                                if data.locked then
									DoorSystemSetDoorState(v.doorHash, 4, false, false)
									DoorSystemSetDoorState(v.doorHash, 1, false, false)
                                else
                                    DoorSystemSetDoorState(v.doorHash, 0, false, false)
                                end
                            end
                        end
                    elseif v.object then
						RemoveDoorFromSystem(v.doorHash)
						nearbyDoors[doorID] = nil
					end
                end
            elseif not data.doors then
				if not data.doorType then data.doorType = 'door' end
                if #(playerCoords - data.objCoords) < 30 then
                    if data.doorType == "sliding" or data.doorType == "garage" then
						data.object = GetClosestObjectOfType(data.objCoords.x, data.objCoords.y, data.objCoords.z, 5.0, data.objName or data.objHash, false, false, false)
					else
                        data.object = GetClosestObjectOfType(data.objCoords.x, data.objCoords.y, data.objCoords.z, 1.0, data.objName or data.objHash, false, false, false)
                    end
                    if data.object and data.object ~= 0 then
                        data.doorHash = 'door_'..doorID
                        if not IsDoorRegisteredWithSystem(data.doorHash) then
							local objCoords = GetEntityCoords(data.object)
							local objHeading = GetEntityHeading(data.object)
							local hasHeading = data.objYaw or data.objHeading or false
							if data.objCoords ~= objCoords then data.objCoords = objCoords end -- Backwards compatibility fix
							if not hasHeading then
								data.objYaw = objHeading
							else
								if hasHeading ~= objHeading then -- Backwards compatibility fix
									data.objYaw = data.objYaw and objHeading or nil
									data.objHeading = data.objHeading and objHeading or nil
								end
							end
							data.objCoords = GetEntityCoords(data.object)
                            AddDoorToSystem(data.doorHash, data.objName or data.objHash, data.objCoords.x, data.objCoords.y, data.objCoords.z, false, false, false)
                            nearbyDoors[doorID] = true
                            if data.locked then
                                DoorSystemSetDoorState(data.doorHash, 4, false, false)
								DoorSystemSetDoorState(data.doorHash, 1, false, false)
                            else
                                DoorSystemSetDoorState(data.doorHash, 0, false, false)
                            end
                        end
                    end
                elseif data.object then
					RemoveDoorFromSystem(data.doorHash)
					nearbyDoors[doorID] = nil
				end
            end
            -- set text coords
            if not data.setText and data.doors then
                for k, v in pairs(data.doors) do
                    if k == 1 and DoesEntityExist(v.object) then
                        data.textCoords = v.objCoords
                    elseif k == 2 and DoesEntityExist(v.object) and data.textCoords then
                        local textDistance = data.textCoords - v.objCoords
                        data.textCoords = data.textCoords - (textDistance / 2)
                        data.setText = true
                    end
                    if k == 2 and data.textCoords and (data.doorType == "sliding" or data.doorType == "garage") then
                        if GetEntityHeightAboveGround(v.object) < 1 then
                            data.textCoords = vec3(data.textCoords.x, data.textCoords.y, data.textCoords.z + 1.2)
                        end
                    end
                end
            elseif not data.setText and not data.doors and DoesEntityExist(data.object) then
                if data.doorType == "garage" then
                    data.textCoords = data.objCoords
                    data.setText = true
                else
                    data.textCoords = setTextCoords(data)
                    data.setText = true
                end
                if data.doorType == "sliding" or data.doorType == "garage" then
                    if GetEntityHeightAboveGround(data.object) < 1 then
                        data.textCoords = vec3(data.textCoords.x, data.textCoords.y, data.textCoords.z + 1.6)
                    end
                end
            end
        end
    end
    lastCoords = playerCoords
end

local function lockpickFinish(success)
	if success then
		Notify(Lang:t("notify.lockpick_success"), 'success', 2500)
		if closestDoor.data.doors then
			TaskTurnPedToFaceCoord(playerPed, closestDoor.data.doors[1].objCoords.x, closestDoor.data.doors[1].objCoords.y, closestDoor.data.doors[1].objCoords.z, 0)
		else
			TaskTurnPedToFaceCoord(playerPed, closestDoor.data.objCoords.x, closestDoor.data.objCoords.y, closestDoor.data.objCoords.z, 0)
		end
		Wait(300)
		local count = 0
		while GetIsTaskActive(playerPed, 225) do
			Wait(10)
			if count == 150 then break end
			count += 1
		end
		Wait(1800)
		TriggerServerEvent('qb-doorlock:server:updateState', closestDoor.id, false, false, true, false) -- Broadcast new state of the door to everyone
	else
		Notify(Lang:t("notify.lockpick_fail"), 'error', 2500)
		if math.random(1,100) <= 17 then
			if usingAdvanced then
				TriggerServerEvent("qb-doorlock:server:removeLockpick", "advancedlockpick")
			else
				TriggerServerEvent("qb-doorlock:server:removeLockpick", "lockpick")
			end
		end
	end
end

function SetupDoors()
	local p = promise.new()
	TriggerCallback('qb-doorlock:server:setupDoors', function(result)
		p:resolve(result)
	end)
	Config.DoorList = Citizen.Await(p)
end

-- Events
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
	TriggerCallback('qb-doorlock:server:setupDoors', function(result)
		Config.DoorList = result
		PlayerData = GetPlayerData()
		isLoggedIn = true
	end)
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
	isLoggedIn = false
	PlayerData = {}
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(val)
	PlayerData = val
end)

RegisterNetEvent('esx:playerLoaded', function()
	TriggerCallback('qb-doorlock:server:setupDoors', function(result)
		Config.DoorList = result
		PlayerData = GetPlayerData()
		isLoggedIn = true
	end)
end)

RegisterNetEvent('esx:playerDropped', function(playerId, reason)
	isLoggedIn = false
	PlayerData = {}
end)

RegisterNetEvent('qb-doorlock:client:setState', function(serverId, doorID, state, src, enableSounds, enableAnimation)
	if not Config.DoorList[doorID] then return end
	if enableAnimation == nil then enableAnimation = true end
	if enableSounds == nil then enableSounds = true end
	if serverId == GetPlayerServerId(PlayerId()) and enableAnimation then doorAnim() end
	Config.DoorList[doorID].locked = state
	updateDoors(doorID)
	local current = Config.DoorList[doorID]
	local locked = state
	while true do
		if current.doors then
			if not current.doorType then current.doorType = 'double' end
			for k, v in pairs(current.doors) do
				if not IsDoorRegisteredWithSystem(v.doorHash) then return end
				v.currentHeading = GetEntityHeading(v.object)
				v.doorState = DoorSystemGetDoorState(v.doorHash)
				if current.doorType == "doublesliding" then
					DoorSystemSetAutomaticRate(v.doorHash, v.doorRate or 1.0, false, false)
					if current.locked then
						DoorSystemSetDoorState(v.doorHash, 1, false, false)
						DoorSystemSetAutomaticDistance(v.doorHash, 0.0, false, false)
						if k == 2 then
							playSound(current, src, enableSounds)
							return
						end
					else
						DoorSystemSetDoorState(v.doorHash, 0, false, false)
						DoorSystemSetAutomaticDistance(v.doorHash, 30.0, false, false)
						if k == 2 then
							playSound(current, src, enableSounds)
							return
						end
					end
				elseif current.locked and v.doorState == 4 then
					DoorSystemSetDoorState(v.doorHash, 1, false, false)
					if current.doors[1].doorState == current.doors[2].doorState then
						playSound(current, src, enableSounds)
						return
					end
				elseif not current.locked then
					DoorSystemSetDoorState(v.doorHash, 0, false, false)
					if current.doors[1].doorState == current.doors[2].doorState then
						playSound(current, src, enableSounds)
						return
					end
				else
					if v.currentHeading and v.objYaw or v.objHeading then
						if round(v.currentHeading, 0) == round(v.objYaw or v.objHeading, 0) then
							DoorSystemSetDoorState(v.doorHash, 4, false, false)
						end
					end
				end
			end
		else
			if not IsDoorRegisteredWithSystem(current.doorHash) then return end
			if not current.doorType then current.doorType = 'door' end
			current.currentHeading = GetEntityHeading(current.object)
			current.doorState = DoorSystemGetDoorState(current.doorHash)
			if current.doorType == "sliding" or current.doorType == "garage" then
				DoorSystemSetAutomaticRate(current.doorHash, current.doorRate or 1.0, false, false)
				if current.locked then
					DoorSystemSetDoorState(current.doorHash, 1, false, false)
					DoorSystemSetAutomaticDistance(current.doorHash, 0.0, false, false)
					playSound(current, src, enableSounds)
					return
				else
					DoorSystemSetDoorState(current.doorHash, 0, false, false)
					DoorSystemSetAutomaticDistance(current.doorHash, 30.0, false, false)
					playSound(current, src, enableSounds)
					return
				end
			elseif current.locked and current.doorState == 4 then
				DoorSystemSetDoorState(current.doorHash, 1, false, false)
				playSound(current, src, enableSounds)
				return
			elseif not current.locked then
				DoorSystemSetDoorState(current.doorHash, 0, false, false)
				playSound(current, src, enableSounds)
				return
			else
				if round(current.currentHeading, 0) == round(current.objYaw or current.objHeading, 0) then
					DoorSystemSetDoorState(current.doorHash, 4, false, false)
				end
			end
		end
		Wait(0)
	end
end)

RegisterNetEvent('lockpicks:UseLockpick', function(isAdvanced)
	if CoreName == "qb-core" or CoreName == "qbx_core" then
		if not closestDoor.data or not next(closestDoor.data) or PlayerData.metadata['isdead'] or PlayerData.metadata['ishandcuffed'] or (not closestDoor.data.pickable and not closestDoor.data.lockpick) or not closestDoor.data.locked then return end
	end
	usingAdvanced = isAdvanced
	TriggerEvent('qb-lockpick:client:openLockpick', lockpickFinish)
end)

RegisterNetEvent('qb-doorlock:client:createNewSingleDoor', function()
	EntityViewEnabled = not EntityViewEnabled
	local heading, result, entityHit
	local entity, coords, model = 0, 0, 0
	if EntityViewEnabled then
		SendNUIMessage({action = "textUI", show = true})
		while true do
			DisablePlayerFiring(PlayerId(), true)
			if IsPlayerFreeAiming(PlayerId()) then
				result, entityHit = raycastWeapon()
				if result and entityHit ~= entity then
					SetEntityDrawOutline(entity, false)
					SetEntityDrawOutline(entityHit, true)
					entity = entityHit
					coords = GetEntityCoords(entity)
					model = GetEntityModel(entity)
					heading = GetEntityHeading(entity)
				end
				if entity and IsControlPressed(0, 24) then break end
			end
			if IsControlPressed(0, 202) then
				break
			end
			Wait(0)
		end
		EntityViewEnabled = false
		SendNUIMessage({action = "textUI", show = false})
		SetEntityDrawOutline(entity, false)
		if entity ~= 0 and entity ~= -1 then
			SendNUIMessage({action = "openCreateDoorMenu", type = "single", hash1 = model, netId = entity})
			SetNuiFocus(true, true)
			RemoveAllPedWeapons(PlayerPedId(), 0)
			ClearFocus()
			ClearPedTasksImmediatly(PlayerPedId())
			ClearPedDecorations(PlayerPedId())
			TaskClearLookAt(PlayerPedId())
		end
	else
		SetEntityDrawOutline(entity, false)
		SendNUIMessage({action = "textUI", show = false})
	end
end)

RegisterNetEvent('qb-doorlock:client:createNewDoubleDoor', function()
	EntityViewEnabled = not EntityViewEnabled
	local result, entityHit
	entitiesData, coordsData, headingData, modelsData = {0, 0}, {0, 0}, {0, 0}, {0, 0}
	if EntityViewEnabled then
		SendNUIMessage({action = "textUI", show = true})
		for i = 1, 2 do
			while true do
				if IsPlayerFreeAiming(PlayerId()) then
					result, entityHit = raycastWeapon()
					if result and entityHit ~= entitiesData[i] then
						SetEntityDrawOutline(entitiesData[i], false)
						SetEntityDrawOutline(entityHit, true)
						entitiesData[i] = entityHit
						coordsData[i] = GetEntityCoords(entitiesData[i])
						modelsData[i] = GetEntityModel(entitiesData[i])
						headingData[i] = GetEntityHeading(entitiesData[i])
					end
					if entitiesData[i] and IsControlPressed(0, 24) then
						break 
					end
				end
				if IsControlPressed(0, 202) then
					break
				end
				Wait(0)
			end
			Wait(200)
		end
		EntityViewEnabled = false
		SendNUIMessage({action = "textUI", show = false})
		SetEntityDrawOutline(entitiesData[1], false)
		SetEntityDrawOutline(entitiesData[2], false)
		if entitiesData[1] ~= 0 and entitiesData[1] ~= -1 and entitiesData[2] ~= 0 and entitiesData[2] ~= -1 then
			SendNUIMessage({action = "openCreateDoorMenu", type = "double", hash1 = modelsData[1], hash2 = modelsData[2]})
			SetNuiFocus(true, true)
			RemoveAllPedWeapons(PlayerPedId(), 0)
			ClearFocus()
			ClearPedTasksImmediatly(PlayerPedId())
			ClearPedDecorations(PlayerPedId())
			TaskClearLookAt(PlayerPedId())
		end
	else
		SetEntityDrawOutline(entitiesData[1], false)
		SetEntityDrawOutline(entitiesData[2], false)
		SendNUIMessage({action = "textUI", show = false})
	end
end)

local function raycastWeapon()
    local offset = GetOffsetFromEntityInWorldCoords(GetCurrentPedWeaponEntityIndex(playerPed), 0, 0, -0.01)
    local direction = GetGameplayCamRot()
    direction = vec2(direction.x * math.pi / 180.0, direction.z * math.pi / 180.0)
    local num = math.abs(math.cos(direction.x))
    direction = vec3((-math.sin(direction.y) * num), (math.cos(direction.y) * num), math.sin(direction.x))
    local destination = vec3(offset.x + direction.x * 30, offset.y + direction.y * 30, offset.z + direction.z * 30)
	local hit, entityHit, result
    local rayHandle = StartShapeTestLosProbe(offset, destination, -1, playerPed, 0)
    repeat
        result, hit, _, _, entityHit = GetShapeTestResult(rayHandle)
        Wait(0)
    until result ~= 1
    if GetEntityType(entityHit) == 3 then return hit, entityHit else return false, 0 end
end

local function RotationToDirection(rotation)
	local adjustedRotation =
	{
		x = (math.pi / 180) * rotation.x,
		y = (math.pi / 180) * rotation.y,
		z = (math.pi / 180) * rotation.z
	}
	local direction =
	{
		x = -math.sin(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
		y = math.cos(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
		z = math.sin(adjustedRotation.x)
	}
	return direction
end

RegisterNetEvent('qb-doorlock:client:newDoorAdded', function(data, id, creatorSrc)
	Config.DoorList[id] = data
	TriggerEvent('qb-doorlock:client:setState', creatorSrc, id, data.locked, false, true, true)
end)

-- Commands

RegisterCommand('toggledoorlock', function()
	togleDoorLockFunc(false)
end, false)

function togleDoorLockFunc(bypassCode)
	local playerCoords = GetEntityCoords(PlayerPedId())
	for k, v in pairs(nearbyDoors) do
		local doorData = Config.DoorList[k]
		if doorData then
			if doorData.textCoords == nil and doorData.objCoords == nil then
				print("There is a problem with door named " .. k)
			end
			if doorData.textCoords == nil then
				if doorData.objCoords then
					doorData.textCoords = vector3(doorData.objCoords.x, doorData.objCoords.y, doorData.objCoords.z)
				end
			end
			doorData.distance2 = #(playerCoords - vector3(doorData.textCoords.x, doorData.textCoords.y, doorData.textCoords.z))
			local dist = doorData.interactDistance or doorData.distance + 5.0 or 2.0
			if doorData.distance2 <= dist then
				if doorData.passCode and not bypassCode and doorData.locked then
					closestDoor = {distance = doorData.distance2, interactDistance = doorData.distance or doorData.interactDistance, id = k, data = doorData}
					local distanceCheck = closestDoor.distance > (closestDoor.data.distance or closestDoor.data.interactDistance)
					local unlockableCheck = (closestDoor.data.cantUnlock and closestDoor.data.locked)
					local busyCheck = false
					if CoreName == "qb-core" or CoreName == "qbx_core" then
						busyCheck = PlayerData.metadata['isdead'] or PlayerData.metadata['inlaststand'] or PlayerData.metadata['ishandcuffed']
					end
					if distanceCheck or unlockableCheck or busyCheck then return end
					local ignore = "'' '"
					local passCode = string.lower(doorData.passCode:gsub("["..ignore.."]+", ""))
					SetNuiFocus(true, true)
					SendNUIMessage({action = "openPassCodeMenu", passcode = passCode})
				else
					closestDoor = {distance = doorData.distance2, interactDistance = doorData.distance or doorData.interactDistance, id = k, data = doorData}
					if not closestDoor.data or not next(closestDoor.data) then return end
					local distanceCheck = closestDoor.distance > (closestDoor.data.distance or closestDoor.data.interactDistance)
					local unlockableCheck = (closestDoor.data.cantUnlock and closestDoor.data.locked)
					local busyCheck = false
					if CoreName == "qb-core" or CoreName == "qbx_core" then
						busyCheck = PlayerData.metadata['isdead'] or PlayerData.metadata['inlaststand'] or PlayerData.metadata['ishandcuffed']
					end
					if distanceCheck or unlockableCheck or busyCheck then return end
					playerPed = PlayerPedId()
					local veh = GetVehiclePedIsIn(playerPed)
					if veh then
						CreateThread(function()
							local siren = IsVehicleSirenOn(veh)
							for _ = 0, 100 do
								DisableControlAction(0, 86, true)
								SetHornEnabled(veh, false)
								if not siren then SetVehicleSiren(veh, false) end
								Citizen.Wait(0)
							end
							SetHornEnabled(veh, true)
						end)
					end
					local locked = not closestDoor.data.locked
					local src = false
					if closestDoor.data.audioRemote then src = NetworkGetNetworkIdFromEntity(playerPed) end
					TriggerServerEvent('qb-doorlock:server:updateState', closestDoor.id, locked, src, false, false, true, true) -- Broadcast new state of the door to everyone
				end
			else
				closestDoor = {}
			end
		end
	end
end

TriggerEvent("chat:removeSuggestion", "/toggledoorlock")
RegisterKeyMapping('toggledoorlock', Lang:t("general.keymapping_description"), 'keyboard', 'E')

RegisterCommand('remotetriggerdoor', function()
	local hit, raycastCoords = RayCastGamePlayCamera(Config.RemoteTriggerDistance)
	if not hit then return end

	local nearestDoor = nil
	for k in pairs(nearbyDoors) do
		local door = Config.DoorList[k]
		local canTrigger = door.remoteTrigger
		local distance = #(raycastCoords - getTextCoords(door))

		if canTrigger and (not nearestDoor or distance < nearestDoor.distance) and distance < math.max(door.distance,Config.RemoteTriggerMinDistance) then
			nearestDoor = {
				data = door,
				id = k,
				distance = distance
			}
		end
	end

	if not nearestDoor then return end

	local unlockableCheck = (nearestDoor.data.cantUnlock and nearestDoor.data.locked)
	local busyCheck = false
	if CoreName == "qb-core" or CoreName == "qbx_core" then
		busyCheck = PlayerData.metadata['isdead'] or PlayerData.metadata['inlaststand'] or PlayerData.metadata['ishandcuffed']
	end
	if unlockableCheck or busyCheck then return end

	playerPed = PlayerPedId()
	local veh = GetVehiclePedIsIn(playerPed)
	if veh then
		CreateThread(function()
			for _ = 0, 100 do
				DisableControlAction(0, 74, true)
				Wait(0)
			end
		end)
	end
	TriggerServerEvent('qb-doorlock:server:updateState', nearestDoor.id, not nearestDoor.data.locked, NetworkGetNetworkIdFromEntity(playerPed), false, false, true, true) -- Broadcast new state of the door to everyone
end, false)
TriggerEvent("chat:removeSuggestion", "/remotetriggerdoor")
RegisterKeyMapping('remotetriggerdoor', Lang:t("general.keymapping_remotetriggerdoor"), 'keyboard', 'H')

-- Threads
Citizen.CreateThread(function()
	while true do
		updateDoors()
		Citizen.Wait(1000)
	end
end)

local paused = false
Citizen.CreateThread(function()
	-- Functions
	if Config.PersistentDoorStates then Citizen.Wait(1000) SetupDoors() end -- Required for pulling in door states properly from live ensures
	updateDoors()
	if Config.UseTextUI then
		while true do
			local sleep = 100
			local playerCoords = GetEntityCoords(PlayerPedId())
			for k, v in pairs(nearbyDoors) do
				local doorData = Config.DoorList[k]
				if doorData then
					if doorData.doors then
						if doorData.textCoords == nil and doorData.doors[1].objCoords == nil then
							print("There is a problem with door named " .. k)
						end
						if doorData.textCoords == nil then
							if doorData.doors[1].objCoords then
								doorData.textCoords = vector3(doorData.doors[1].objCoords.x, doorData.doors[1].objCoords.y, doorData.doors[1].objCoords.z)
							end
						end
						doorData.distance2 = #(playerCoords - vector3(doorData.textCoords.x, doorData.textCoords.y, doorData.textCoords.z))
					else
						if doorData.textCoords == nil and doorData.objCoords == nil then
							print("There is a problem with door named " .. k)
						end
						if doorData.textCoords == nil then
							if doorData.objCoords then
								doorData.textCoords = vector3(doorData.objCoords.x, doorData.objCoords.y, doorData.objCoords.z)
							end
						end
						doorData.distance2 = #(playerCoords - vector3(doorData.textCoords.x, doorData.textCoords.y, doorData.textCoords.z))
					end
					doorData.svgDistance = doorData.svgDistance or doorData.distance + 5.0 or 7.0
					doorData.interactDist = doorData.interactDistance or doorData.distance or 2.0
					local onScreen, _x, _y = World3dToScreen2d(doorData.textCoords.x, doorData.textCoords.y, doorData.textCoords.z)
                    if onScreen then
						if doorData.distance2 <= doorData.svgDistance then
							sleep = 0
							if doorData.distance2 <= doorData.interactDist then
								-- Color, text
								local bg = 'bg'
								local interact = 'interact'
								local text = Lang:t("texts.unlocked")
								if doorData.locked == true then
									interact = 'interactRed'
									text = Lang:t("texts.locked")
									bg = 'bgRed'
								end
								-- Main Text
								local factor = (string.len(text)) / 370
								local width = 0.03 + factor
								-- Key Text
								local factor2 = (string.len("E")) / 370
								local width2 = 0.016 + factor2
								-- E
								SetScriptGfxAlignParams(0.0, 0.0, 0.0, 0.0)
								SetTextScale(0, 0.35)
								SetTextFont(2)
								SetTextColour(255, 255, 255, 255)
								BeginTextCommandDisplayText("STRING")
								SetTextCentre(true)
								SetTextJustification(0)
								-- AddTextComponentSubstringPlayerName("E")
								SetDrawOrigin(doorData.textCoords.x, doorData.textCoords.y, doorData.textCoords.z)
								EndTextCommandDisplayText(0.0, -0.0115)
								ResetScriptGfxAlign()
								SetScriptGfxAlignParams(0.0, 0.0, 0.0, 0.0)
								DrawSprite('interactions_txd2', interact, 0.0, 0.0, width2, 0.03133333333333333, 0.0, 255, 255, 255, 255)
								ResetScriptGfxAlign()
								ClearDrawOrigin()
							else
								SetScriptGfxAlignParams(0.0, 0.0, 0.0, 0.0)
								SetDrawOrigin(doorData.textCoords.x, doorData.textCoords.y, doorData.textCoords.z)
								-- DrawSprite('interactions_txd2', 'pin', 0, 0, 0.0125, 0.02333333333333333, 0, 255, 255, 255, 255)
								ResetScriptGfxAlign()
							end
						end
					end
				end
			end
			Citizen.Wait(sleep)
		end
	else
		while true do
			local sleep = 100
			local playerCoords = GetEntityCoords(PlayerPedId())
			for k, v in pairs(nearbyDoors) do
				local doorData = Config.DoorList[k]
				if doorData then
					if doorData.textCoords == nil and doorData.objCoords == nil then
						print("There is a problem with door named " .. k)
					end
					if doorData.textCoords == nil then
						if doorData.objCoords then
							doorData.textCoords = vector3(doorData.objCoords.x, doorData.objCoords.y, doorData.objCoords.z)
						end
					end
					doorData.distance2 = #(playerCoords - vector3(doorData.textCoords.x, doorData.textCoords.y, doorData.textCoords.z))
					doorData.svgDistance = doorData.svgDistance or doorData.distance + 5.0 or 7.0
					doorData.interactDist = doorData.interactDistance or doorData.distance or 2.0
					local onScreen, _x, _y = World3dToScreen2d(doorData.textCoords.x, doorData.textCoords.y, doorData.textCoords.z)
                    if onScreen then
						if doorData.distance2 <= doorData.svgDistance then
							sleep = 0
							if doorData.distance2 <= doorData.interactDist then
								local interact = 'interact'
								if doorData.locked == true then
									interact = 'interactRed'
								end
								-- E
								SetScriptGfxAlignParams(0.0, 0.0, 0.0, 0.0)
								SetDrawOrigin(doorData.textCoords.x, doorData.textCoords.y, doorData.textCoords.z)
								DrawSprite('interactions_txd2', interact, 0, 0, 0.0185, 0.03133333333333333, 0, 255, 255, 255, 255)
								ResetScriptGfxAlign()
							else
								SetScriptGfxAlignParams(0.0, 0.0, 0.0, 0.0)
								SetDrawOrigin(doorData.textCoords.x, doorData.textCoords.y, doorData.textCoords.z)
								-- DrawSprite('interactions_txd2', 'pin', 0, 0, 0.0125, 0.02333333333333333, 0, 255, 255, 255, 255)
								ResetScriptGfxAlign()
							end
						end
					end
				end
			end
			Citizen.Wait(sleep)
		end
	end
end)

RegisterNUICallback('callback', function(data)
	if data.action == "nuiFocus" then
		SetNuiFocus(false, false)
	elseif data.action == "createDoor" then
		local doorData = data.data
		local identifier = doorData.configfile .. '-' .. doorData.dooridentifier
		if doorData.configfile == '' then doorData.configfile = false end
		if doorData.job == '' then doorData.job = false doorData.allAuthorized = true end
		if doorData.gang == '' then doorData.gang = false end
		if doorData.cid == '' then doorData.cid = false end
		if doorData.item == '' then doorData.item = false end
		doorData.passCode = doorData.passCode
		if doorData.pickable ~= 'true' then doorData.pickable = nil end
		doorData.cantunlock = doorData.cantunlock
		doorData.locked = doorData.locked
		doorData.svgDistance = tonumber(doorData.svgDistance)
		doorData.interactDistance = tonumber(doorData.interactDistance)
		doorData.fixText = doorData.fixText
		if Config.DoorList[identifier] then
			Notify((Lang:t("notify.door_identifier_exists")):format(identifier), 'error')
			return
		end
		if doorData.doortype == 'door' or doorData.doortype == 'sliding' or doorData.doortype == 'garage' then
			local entity = doorData.netId --NetToObj(data.netId)
			local coords = GetEntityCoords(entity)
			local model = GetEntityModel(entity)
			if not model or model == 0 then Notify(Lang:t("notify.door_not_found"), 'error') return end
			local result = DoorSystemFindExistingDoor(coords.x, coords.y, coords.z, model)
			if result then Notify(Lang:t("notify.door_registered"), 'error') return end
			doorData.doorHash = 'door_' .. doorData.dooridentifier
			AddDoorToSystem(doorData.doorHash, model, coords, false, false, false)
			DoorSystemSetDoorState(doorData.doorHash, 4, false, false)
			RemoveDoorFromSystem(doorData.doorHash)
			doorData.entity = entity
			doorData.coords = coords
			doorData.model = model
			doorData.heading = heading
			TriggerServerEvent('qb-doorlock:server:saveNewDoor', doorData, false)
		else
			if not modelsData[1] or modelsData[1] == 0 or not modelsData[2] or modelsData[2] == 0 then Notify(Lang:t("error.door_not_found"), 'error') return end
			if entitiesData[1] == entitiesData[2] then Notify(Lang:t("notify.same_entity"), 'error') canContinue = true return end
			doorData.doorHash = {}
			for i = 1, 2 do
				local result = DoorSystemFindExistingDoor(coordsData[i].x, coordsData[i].y, coordsData[i].z, modelsData[i])
				if result then Notify(Lang:t("notify.door_registered"), 'error') canContinue = true return end
				doorData.doorHash[i] = 'door_'..doorData.dooridentifier..'_'..i
				AddDoorToSystem(doorData.doorHash[i], modelsData[i], coordsData[i], false, false, false)
            	DoorSystemSetDoorState(doorData.doorHash[i], 4, false, false)
				coordsData[i] = GetEntityCoords(entitiesData[i])
				headingData[i] = GetEntityHeading(entitiesData[i])
				RemoveDoorFromSystem(doorData.doorHash[i])
				doorData.entity = entitiesData
				doorData.coords = coordsData
				doorData.model = modelsData
				doorData.heading = headingData
			end
			TriggerServerEvent('qb-doorlock:server:saveNewDoor', doorData, true)
		end
	elseif data.action == "openDoor" then
		SetNuiFocus(false, false)
		togleDoorLockFunc(true)
	end
end)
