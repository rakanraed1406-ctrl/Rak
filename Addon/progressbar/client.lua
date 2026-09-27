local Action = {
    name = "",
    duration = 0,
    label = "",
    Icon = "",
    useWhileDead = false,
    canCancel = true,
    disarm = true,
    controlDisables = {
        disableMovement = false,
        disableCarMovement = false,
        disableMouse = false,
        disableCombat = false,
    },
    animation = {
        animDict = nil,
        anim = nil,
        flags = 0,
        task = nil,
    },
    prop = {
        model = nil,
        bone = nil,
        coords = { x = 0.0, y = 0.0, z = 0.0 },
        rotation = { x = 0.0, y = 0.0, z = 0.0 },
    },
    propTwo = {
        model = nil,
        bone = nil,
        coords = { x = 0.0, y = 0.0, z = 0.0 },
        rotation = { x = 0.0, y = 0.0, z = 0.0 },
    },
}

local isDoingAction = false
local wasCancelled = false
local isAnim = false
local isProp = false
local isPropTwo = false
local prop_net = nil
local propTwo_net = nil
local runProgThread = false

local function notify(message, notifyType)
    TriggerEvent("QBCore:Notify", message, notifyType or "error")
end

local function normalizeVector(value)
    value = type(value) == "table" and value or {}
    return {
        x = tonumber(value.x) or 0.0,
        y = tonumber(value.y) or 0.0,
        z = tonumber(value.z) or 0.0,
    }
end

local function normalizeProp(prop)
    if prop == false or prop == nil then
        return nil
    end

    prop = type(prop) == "table" and prop or {}
    return {
        model = prop.model,
        bone = prop.bone or 60309,
        coords = normalizeVector(prop.coords),
        rotation = normalizeVector(prop.rotation),
    }
end

local function normalizeAction(action)
    action = type(action) == "table" and action or {}
    local controlDisables = type(action.controlDisables) == "table" and action.controlDisables or {}
    local animation = type(action.animation) == "table" and action.animation or {}

    return {
        name = tostring(action.name or ""),
        duration = math.max(tonumber(action.duration) or 0, 0),
        label = tostring(action.label or ""),
        Icon = tostring(action.Icon or action.icon or ""),
        useWhileDead = action.useWhileDead == true,
        canCancel = action.canCancel ~= false,
        disarm = action.disarm ~= false,
        controlDisables = {
            disableMovement = controlDisables.disableMovement == true,
            disableCarMovement = controlDisables.disableCarMovement == true,
            disableMouse = controlDisables.disableMouse == true,
            disableCombat = controlDisables.disableCombat == true,
        },
        animation = {
            animDict = animation.animDict,
            anim = animation.anim,
            flags = animation.flags or 1,
            task = animation.task,
        },
        prop = normalizeProp(action.prop),
        propTwo = normalizeProp(action.propTwo),
    }
end

local function loadAnimDict(dict)
    if not dict or dict == "" then return false end

    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() >= timeout then
            return false
        end
        Wait(10)
    end

    return true
end

local function loadModel(model)
    if not model then return nil end

    local modelHash = type(model) == "number" and model or GetHashKey(model)
    if not IsModelInCdimage(modelHash) or not IsModelValid(modelHash) then
        return nil
    end

    RequestModel(modelHash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(modelHash) do
        if GetGameTimer() >= timeout then
            return nil
        end
        Wait(10)
    end

    return modelHash
end

local function createAndAttachProp(propData)
    if not propData or not propData.model then return nil end

    local modelHash = loadModel(propData.model)
    if not modelHash then return nil end

    local ped = PlayerPedId()
    local pCoords = GetEntityCoords(ped)
    local object = CreateObject(modelHash, pCoords.x, pCoords.y, pCoords.z, true, true, true)
    SetModelAsNoLongerNeeded(modelHash)

    if not DoesEntityExist(object) then
        return nil
    end

    local netId = ObjToNet(object)
    SetNetworkIdExistsOnAllMachines(netId, true)
    NetworkSetNetworkIdDynamic(netId, true)
    SetNetworkIdCanMigrate(netId, false)

    AttachEntityToEntity(
        object,
        ped,
        GetPedBoneIndex(ped, propData.bone),
        propData.coords.x,
        propData.coords.y,
        propData.coords.z,
        propData.rotation.x,
        propData.rotation.y,
        propData.rotation.z,
        true,
        true,
        false,
        true,
        0,
        true
    )

    return netId
end

local function actionCleanup()
    local ped = PlayerPedId()

    if Action.animation then
        if Action.animation.task then
            ClearPedTasks(ped)
        elseif Action.animation.animDict and Action.animation.anim then
            StopAnimTask(ped, Action.animation.animDict, Action.animation.anim, 1.0)
            ClearPedSecondaryTask(ped)
        end
    end

    if prop_net then
        local object = NetToObj(prop_net)
        if DoesEntityExist(object) then
            DetachEntity(object, true, true)
            DeleteEntity(object)
        end
    end

    if propTwo_net then
        local object = NetToObj(propTwo_net)
        if DoesEntityExist(object) then
            DetachEntity(object, true, true)
            DeleteEntity(object)
        end
    end

    prop_net = nil
    propTwo_net = nil
    isAnim = false
    isProp = false
    isPropTwo = false
    runProgThread = false
end

local function disableActions()
    local disables = Action.controlDisables

    if disables.disableMouse then
        DisableControlAction(0, 1, true)
        DisableControlAction(0, 2, true)
        DisableControlAction(0, 106, true)
    end

    if disables.disableMovement then
        DisableControlAction(0, 30, true)
        DisableControlAction(0, 31, true)
        DisableControlAction(0, 21, true)
        DisableControlAction(0, 36, true)
        DisableControlAction(0, 75, true)
        DisableControlAction(27, 75, true)
    end

    if disables.disableCarMovement then
        DisableControlAction(0, 63, true)
        DisableControlAction(0, 64, true)
        DisableControlAction(0, 71, true)
        DisableControlAction(0, 72, true)
        DisableControlAction(0, 75, true)
    end

    if disables.disableCombat then
        DisablePlayerFiring(PlayerId(), true)
        DisableControlAction(0, 24, true)
        DisableControlAction(0, 25, true)
        DisableControlAction(1, 37, true)
        DisableControlAction(0, 47, true)
        DisableControlAction(0, 58, true)
        DisableControlAction(0, 140, true)
        DisableControlAction(0, 141, true)
        DisableControlAction(0, 142, true)
        DisableControlAction(0, 143, true)
        DisableControlAction(0, 263, true)
        DisableControlAction(0, 264, true)
        DisableControlAction(0, 257, true)
    end
end

local function actionStart()
    runProgThread = true
    LocalPlayer.state:set("inv_busy", true, true)

    CreateThread(function()
        while runProgThread do
            if isDoingAction then
                local ped = PlayerPedId()

                if Action.disarm then
                    DisablePlayerFiring(PlayerId(), true)
                end

                if not isAnim then
                    if Action.animation.task then
                        TaskStartScenarioInPlace(ped, Action.animation.task, 0, true)
                    elseif Action.animation.animDict and Action.animation.anim and loadAnimDict(Action.animation.animDict) then
                        TaskPlayAnim(
                            ped,
                            Action.animation.animDict,
                            Action.animation.anim,
                            3.0,
                            3.0,
                            -1,
                            Action.animation.flags,
                            0.0,
                            false,
                            false,
                            false
                        )
                    end
                    isAnim = true
                end

                if not isProp and Action.prop and Action.prop.model then
                    prop_net = createAndAttachProp(Action.prop)
                    isProp = true
                end

                if not isPropTwo and Action.propTwo and Action.propTwo.model then
                    propTwo_net = createAndAttachProp(Action.propTwo)
                    isPropTwo = true
                end

                disableActions()
            end
            Wait(0)
        end
    end)
end

local function cancelAction()
    if not isDoingAction then return end

    isDoingAction = false
    wasCancelled = true
    LocalPlayer.state:set("inv_busy", false, true)
    actionCleanup()

    SendNUIMessage({ action = "cancel" })
end

local function finishAction()
    if not isDoingAction then return end

    isDoingAction = false
    actionCleanup()
    LocalPlayer.state:set("inv_busy", false, true)
end

function Process(action, start, tick, finish)
    local ped = PlayerPedId()
    local nextAction = normalizeAction(action)

    if IsEntityDead(ped) and not nextAction.useWhileDead then
        notify("Can't do that action!", "error")
        return
    end

    if isDoingAction then
        notify("You are already doing something!", "error")
        return
    end

    Action = nextAction
    isDoingAction = true
    wasCancelled = false
    isAnim = false
    isProp = false
    isPropTwo = false

    actionStart()

    SendNUIMessage({
        action = "progress",
        duration = Action.duration,
        label = Action.label,
        Icon = Action.Icon,
    })

    CreateThread(function()
        if start then
            start()
        end

        while isDoingAction do
            Wait(1)

            if tick then
                tick()
            end

            if IsControlJustPressed(0, 200) and Action.canCancel then
                TriggerEvent("progressbar:client:cancel")
            end

            if IsEntityDead(PlayerPedId()) and not Action.useWhileDead then
                TriggerEvent("progressbar:client:cancel")
            end
        end

        if finish then
            finish(wasCancelled)
        end
    end)
end

function Progress(action, finish)
    Process(action, nil, nil, finish)
end

function ProgressWithStartEvent(action, start, finish)
    Process(action, start, nil, finish)
end

function ProgressWithTickEvent(action, tick, finish)
    Process(action, nil, tick, finish)
end

function ProgressWithStartAndTick(action, start, tick, finish)
    Process(action, start, tick, finish)
end

function isDoingSomething()
    return isDoingAction
end

RegisterNetEvent('progressbar:client:ToggleBusyness', function(value)
    isDoingAction = value == true
end)

RegisterNetEvent('progressbar:client:progress', function(action, finish)
    Process(action, nil, nil, finish)
end)

RegisterNetEvent('progressbar:client:ProgressWithStartEvent', function(action, start, finish)
    Process(action, start, nil, finish)
end)

RegisterNetEvent('progressbar:client:ProgressWithTickEvent', function(action, tick, finish)
    Process(action, nil, tick, finish)
end)

RegisterNetEvent('progressbar:client:ProgressWithStartAndTick', function(action, start, tick, finish)
    Process(action, start, tick, finish)
end)

RegisterNetEvent('progressbar:client:cancel', function()
    cancelAction()
end)

RegisterNUICallback('FinishAction', function(_, cb)
    finishAction()
    cb({ ok = true })
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    isDoingAction = false
    actionCleanup()
    LocalPlayer.state:set("inv_busy", false, true)
end)
