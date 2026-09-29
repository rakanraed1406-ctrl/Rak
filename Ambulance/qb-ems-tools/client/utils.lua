QBCore = exports['qb-core']:GetCoreObject()
EMS = {}

function EMS.PlayerData()
    return QBCore.Functions.GetPlayerData() or {}
end

function EMS.IsMedic(needDuty)
    local job = EMS.PlayerData().job
    if not job or job.name ~= Config.Job then return false end
    if needDuty ~= false and Config.RequireDuty and not job.onduty then return false end
    return true
end

function EMS.Notify(msg, kind, time)
    QBCore.Functions.Notify(msg, kind or 'primary', time or 4000)
end

function EMS.HasItem(item)
    if QBCore.Functions.HasItem then return QBCore.Functions.HasItem(item) end
    for _, v in pairs(EMS.PlayerData().items or {}) do
        if v and v.name == item then return true end
    end
    return false
end

function EMS.LoadDict(dict)
    if HasAnimDictLoaded(dict) then return true end
    if not DoesAnimDictExist(dict) then return false end
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do Wait(10) end
    return HasAnimDictLoaded(dict)
end

-- First model of the list that exists in the game files (so a missing custom model
-- falls back to a vanilla one instead of spawning nothing).
function EMS.PickModel(models)
    if type(models) == 'string' then models = { models } end
    for _, m in ipairs(models or {}) do
        local hash = type(m) == 'number' and m or joaat(m)
        if IsModelInCdimage(hash) then return hash end
    end
    return nil
end

function EMS.LoadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) then return nil end
    RequestModel(hash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do Wait(10) end
    return HasModelLoaded(hash) and hash or nil
end

function EMS.PlayAnim(name, ped)
    local a = Config.Anims[name]
    if not a or not EMS.LoadDict(a.dict) then return nil end
    ped = ped or PlayerPedId()
    TaskPlayAnim(ped, a.dict, a.anim, 3.0, 3.0, -1, a.flag or 1, 0, false, false, false)
    return a
end

function EMS.StopAnim(a, ped)
    ped = ped or PlayerPedId()
    if a then StopAnimTask(ped, a.dict, a.anim, 1.0) end
end

-- Spawns a Config.Props entry: in the hand (bone) or on the ground next to the ped.
function EMS.SpawnProp(name, ped)
    local p = type(name) == 'table' and name or Config.Props[name]
    if not p then return nil end
    ped = ped or PlayerPedId()
    local hash = EMS.LoadModel(p.model)
    if not hash then return nil end
    local c = GetEntityCoords(ped)
    local obj = CreateObject(hash, c.x, c.y, c.z - 2.0, true, true, false)
    local off = p.offset or vector3(0.0, 0.0, 0.0)
    if p.ground then
        local pos = GetOffsetFromEntityInWorldCoords(ped, off.x, off.y, 0.0)
        SetEntityCoords(obj, pos.x, pos.y, pos.z, false, false, false, false)
        SetEntityHeading(obj, GetEntityHeading(ped) + (p.heading or 0.0))
        PlaceObjectOnGroundProperly(obj)
        FreezeEntityPosition(obj, true)
    else
        local rot = p.rotation or vector3(0.0, 0.0, 0.0)
        AttachEntityToEntity(obj, ped, GetPedBoneIndex(ped, p.bone or 57005), off.x, off.y, off.z, rot.x, rot.y, rot.z, true, true, false, true, 1, true)
    end
    SetEntityCollision(obj, false, false)
    SetModelAsNoLongerNeeded(hash)
    return obj
end

function EMS.DeleteProps(list)
    for _, obj in ipairs(list or {}) do
        if obj and DoesEntityExist(obj) then DeleteEntity(obj) end
    end
end

-- Closest other player (id, ped, distance) within maxDist.
function EMS.ClosestPlayer(maxDist, coords)
    local myPed = PlayerPedId()
    coords = coords or GetEntityCoords(myPed)
    local best, bestPed, bestDist = nil, nil, maxDist or 3.0
    for _, pid in ipairs(GetActivePlayers()) do
        if pid ~= PlayerId() then
            local ped = GetPlayerPed(pid)
            if ped ~= 0 and DoesEntityExist(ped) then
                local d = #(GetEntityCoords(ped) - coords)
                if d <= bestDist then best, bestPed, bestDist = pid, ped, d end
            end
        end
    end
    return best, bestPed, bestDist
end

function EMS.PlayerFromPed(ped)
    if not ped or ped == 0 or not IsPedAPlayer(ped) then return nil end
    local pid = NetworkGetPlayerIndexFromPed(ped)
    if pid == -1 then return nil end
    return pid
end

-- Progress bar that also works without qb-core's (falls back to ox_lib).
function EMS.Progress(label, time, cb)
    if QBCore.Functions.Progressbar then
        QBCore.Functions.Progressbar('ems_tool', label, time, false, true, {
            disableMovement = true, disableCarMovement = true, disableMouse = false, disableCombat = true,
        }, {}, {}, {}, function() cb(true) end, function() cb(false) end)
    else
        cb(lib.progressBar({ duration = time, label = label, canCancel = true, disable = { move = true, car = true, combat = true } }))
    end
end

function EMS.RequestControl(entity, timeout)
    if not DoesEntityExist(entity) then return false end
    if NetworkHasControlOfEntity(entity) then return true end
    NetworkRequestControlOfEntity(entity)
    local t = GetGameTimer() + (timeout or 1500)
    while not NetworkHasControlOfEntity(entity) and GetGameTimer() < t do
        Wait(20)
        NetworkRequestControlOfEntity(entity)
    end
    return NetworkHasControlOfEntity(entity)
end

function EMS.TriggerCallback(name, ...)
    local p = promise.new()
    QBCore.Functions.TriggerCallback(name, function(...) p:resolve({ ... }) end, ...)
    return table.unpack(Citizen.Await(p))
end

function EMS.HelpText(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, false, -1)
end
