-- Stretcher / wheelchair / trauma bag (client).
local KIND_CFG = { stretcher = Config.Stretcher, wheelchair = Config.Wheelchair, medbag = Config.MedBag }
local pushing = nil   -- { obj, kind, anim }
local onDevice = nil  -- { obj, netId, kind, anim }

function EMS.ModelHashes(kind)
    local list = {}
    for _, m in ipairs(KIND_CFG[kind].Models or {}) do list[#list + 1] = joaat(m) end
    return list
end

-- Only equipment placed through this script carries the state (map beds etc. don't).
local function EntState(entity, key)
    if not entity or entity == 0 or not DoesEntityExist(entity) or not NetworkGetEntityIsNetworked(entity) then return nil end
    return Entity(entity).state[key]
end

function EMS.KindOf(entity) return EntState(entity, 'emsTool') end
function EMS.OccupantOf(entity) return EntState(entity, 'emsOccupant') end

-- ── Placing ────────────────────────────────────────────────────────────────
RegisterNetEvent('ems-tools:client:Place', function(kind, token)
    local cfg = KIND_CFG[kind]
    local model = cfg and EMS.PickModel(cfg.Models)
    local hash = model and EMS.LoadModel(model)
    if not hash then
        EMS.Notify('This equipment model is missing on the server', 'error')
        return TriggerServerEvent('ems-tools:server:PlaceFailed', token)
    end
    local ped = PlayerPedId()
    if EMS.LoadDict('pickup_object') then
        TaskPlayAnim(ped, 'pickup_object', 'pickup_low', 8.0, -8.0, 1200, 0, 0, false, false, false)
        Wait(900)
    end
    local pos = GetOffsetFromEntityInWorldCoords(ped, 0.0, kind == 'medbag' and 0.7 or 1.4, 0.0)
    local obj = CreateObject(hash, pos.x, pos.y, pos.z, true, true, false)
    SetEntityHeading(obj, GetEntityHeading(ped) + (kind == 'stretcher' and 90.0 or 0.0))
    PlaceObjectOnGroundProperly(obj)
    SetModelAsNoLongerNeeded(hash)
    local t = GetGameTimer() + 3000
    while not NetworkGetEntityIsNetworked(obj) and GetGameTimer() < t do
        NetworkRegisterEntityAsNetworked(obj)
        Wait(10)
    end
    local netId = ObjToNet(obj)
    SetNetworkIdCanMigrate(netId, true)
    SetNetworkIdExistsOnAllMachines(netId, true)
    TriggerServerEvent('ems-tools:server:Placed', token, netId)
end)

-- ── Pushing ────────────────────────────────────────────────────────────────
local function GroundObject(obj)
    local c = GetEntityCoords(obj)
    local found, z = GetGroundZFor_3dCoord(c.x, c.y, c.z + 1.0, false)
    if found then SetEntityCoords(obj, c.x, c.y, z, false, false, false, false) end
    PlaceObjectOnGroundProperly(obj)
end

function EMS.StopPushing()
    if not pushing then return end
    local ped = PlayerPedId()
    local obj = pushing.obj
    EMS.StopAnim(pushing.anim, ped)
    pushing = nil
    if DoesEntityExist(obj) and IsEntityAttachedToEntity(obj, ped) then
        DetachEntity(obj, true, true)
        GroundObject(obj)
    end
end

function EMS.StartPushing(obj)
    local kind = EMS.KindOf(obj)
    if pushing or not kind or IsEntityAttached(obj) then return end
    if not EMS.RequestControl(obj) then return EMS.Notify('Someone else is holding it', 'error') end
    local ped = PlayerPedId()
    local cfg = KIND_CFG[kind]
    FreezeEntityPosition(obj, false)
    local bone = cfg.PushBone and GetPedBoneIndex(ped, cfg.PushBone) or 0
    AttachEntityToEntity(obj, ped, bone, cfg.PushOffset.x, cfg.PushOffset.y, cfg.PushOffset.z,
        cfg.PushRotation.x, cfg.PushRotation.y, cfg.PushRotation.z, false, false, true, false, 2, true)
    pushing = { obj = obj, kind = kind, anim = EMS.PlayAnim('push', ped) }
    CreateThread(function()
        while pushing and pushing.obj == obj do
            local p = PlayerPedId()
            DisableControlAction(0, 21, true) -- sprint
            DisableControlAction(0, 22, true) -- jump
            DisableControlAction(0, 23, true) -- enter vehicle
            DisableControlAction(0, 24, true) -- attack
            DisableControlAction(0, 25, true) -- aim
            EMS.HelpText('~INPUT_CONTEXT~ Release')
            if IsControlJustReleased(0, 38) or IsEntityDead(p) or IsPedRagdoll(p) or not DoesEntityExist(obj) then
                EMS.StopPushing()
                break
            end
            if pushing.anim and not IsEntityPlayingAnim(p, pushing.anim.dict, pushing.anim.anim, 3) then
                TaskPlayAnim(p, pushing.anim.dict, pushing.anim.anim, 3.0, 3.0, -1, pushing.anim.flag or 49, 0, false, false, false)
            end
            Wait(0)
        end
    end)
end

-- ── Ambulance loading ──────────────────────────────────────────────────────
local LOAD_MODELS = {}
for _, m in ipairs(Config.Stretcher.Vehicles or {}) do LOAD_MODELS[joaat(m)] = true end

function EMS.ClosestAmbulance(coords, maxDist)
    local best, bestDist = nil, maxDist or 6.0
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if LOAD_MODELS[GetEntityModel(veh)] or GetVehicleClass(veh) == 18 then
            local d = #(GetEntityCoords(veh) - coords)
            if d < bestDist then best, bestDist = veh, d end
        end
    end
    return best
end

function EMS.LoadStretcher(obj)
    if pushing and pushing.obj == obj then EMS.StopPushing() end
    local veh = EMS.ClosestAmbulance(GetEntityCoords(obj), 7.0)
    if not veh then return EMS.Notify('No ambulance close enough', 'error') end
    if not EMS.RequestControl(obj) then return end
    local c = Config.Stretcher
    for door = 2, 3 do SetVehicleDoorOpen(veh, door, false, false) end
    Wait(600)
    FreezeEntityPosition(obj, false)
    AttachEntityToEntity(obj, veh, 0, c.VehicleOffset.x, c.VehicleOffset.y, c.VehicleOffset.z,
        c.VehicleRotation.x, c.VehicleRotation.y, c.VehicleRotation.z, false, false, false, false, 2, true)
    SetTimeout(1500, function()
        if DoesEntityExist(veh) then for door = 2, 3 do SetVehicleDoorShut(veh, door, false) end end
    end)
end

function EMS.UnloadStretcher(obj)
    local veh = GetEntityAttachedTo(obj)
    if veh == 0 or not IsEntityAVehicle(veh) then return end
    if not EMS.RequestControl(obj) then return end
    for door = 2, 3 do SetVehicleDoorOpen(veh, door, false, false) end
    Wait(600)
    DetachEntity(obj, true, true)
    local pos = GetOffsetFromEntityInWorldCoords(veh, 0.0, -4.4, 0.0)
    SetEntityCoords(obj, pos.x, pos.y, pos.z, false, false, false, false)
    SetEntityHeading(obj, GetEntityHeading(veh) + 90.0)
    GroundObject(obj)
end

-- ── Patient on the stretcher / in the wheelchair ───────────────────────────
local function LeaveDevice(sendServer)
    if not onDevice then return end
    local ped = PlayerPedId()
    local dev = onDevice
    onDevice = nil
    EMS.StopAnim(dev.anim, ped)
    if IsEntityAttached(ped) then DetachEntity(ped, true, false) end
    if DoesEntityExist(dev.obj) then
        local pos = GetOffsetFromEntityInWorldCoords(dev.obj, dev.kind == 'stretcher' and 1.0 or 0.0, dev.kind == 'stretcher' and 0.0 or 0.9, 0.0)
        SetEntityCoords(ped, pos.x, pos.y, pos.z + 0.6, false, false, false, false) -- a bit above: the ped drops to the ground

    end
    if dev.escorted then TriggerEvent('hospital:client:isEscorted', false) end
    if sendServer then TriggerServerEvent('ems-tools:server:Detached', dev.netId) end
end

RegisterNetEvent('ems-tools:client:AttachTo', function(netId, kind)
    local t = GetGameTimer() + 3000
    while not NetworkDoesNetworkIdExist(netId) and GetGameTimer() < t do Wait(50) end
    local obj = NetToObj(netId)
    if not obj or obj == 0 then return TriggerServerEvent('ems-tools:server:Detached', netId) end
    if onDevice then LeaveDevice(false) end

    local ped = PlayerPedId()
    local cfg = KIND_CFG[kind]
    local state = EMS.LocalState()
    local off = kind == 'stretcher' and cfg.PatientOffset or cfg.SitOffset
    local rot = kind == 'stretcher' and cfg.PatientRotation or cfg.SitRotation
    ClearPedTasksImmediately(ped)
    AttachEntityToEntity(ped, obj, 0, off.x, off.y, off.z, rot.x, rot.y, rot.z, false, false, false, false, 2, true)

    onDevice = { obj = obj, netId = netId, kind = kind }
    if state.laststand then
        -- stops qb-hospital from forcing the "writhe" animation on the stretcher
        TriggerEvent('hospital:client:isEscorted', true)
        onDevice.escorted = true
    end
    local animName = kind == 'stretcher' and 'lie' or 'sit_chair'
    if not state.dead then onDevice.anim = EMS.PlayAnim(animName, ped) end

    CreateThread(function()
        while onDevice and onDevice.obj == obj do
            local p = PlayerPedId()
            local s = EMS.LocalState()
            if not DoesEntityExist(obj) or not IsEntityAttachedToEntity(p, obj) then
                LeaveDevice(true)
                break
            end
            if not s.dead and onDevice.anim and not IsEntityPlayingAnim(p, onDevice.anim.dict, onDevice.anim.anim, 3) then
                TaskPlayAnim(p, onDevice.anim.dict, onDevice.anim.anim, 3.0, 3.0, -1, onDevice.anim.flag or 1, 0, false, false, false)
            elseif not s.dead and not onDevice.anim then
                onDevice.anim = EMS.PlayAnim(animName, p)
            end
            if not s.dead and not s.laststand then
                EMS.HelpText('~INPUT_VEH_DUCK~ Get up')
                if IsControlJustReleased(0, 73) then
                    TriggerServerEvent('ems-tools:server:TakeOff', netId)
                end
            end
            Wait(0)
        end
    end)
end)

RegisterNetEvent('ems-tools:client:Detach', function(netId)
    if onDevice and onDevice.netId == netId then LeaveDevice(false) end
end)

-- Revived / respawned while lying on it: get off.
RegisterNetEvent('hospital:client:Revive', function()
    if onDevice and onDevice.kind == 'stretcher' then
        SetTimeout(500, function()
            if onDevice then TriggerServerEvent('ems-tools:server:TakeOff', onDevice.netId) end
        end)
    end
end)

-- ── Trauma bag ─────────────────────────────────────────────────────────────
RegisterNetEvent('ems-tools:client:OpenStash', function(stash, kind)
    if kind == 'ox' then
        exports.ox_inventory:openInventory('stash', stash)
    else
        TriggerServerEvent('inventory:server:OpenInventory', 'stash', stash, { maxweight = Config.MedBag.MaxWeight, slots = Config.MedBag.Slots })
        TriggerEvent('inventory:client:SetCurrentStash', stash)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    EMS.StopPushing()
    LeaveDevice(false)
end)
