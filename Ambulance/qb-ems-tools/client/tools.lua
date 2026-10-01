-- Field treatment tools: item use → pick target → animation + props → server applies.
local busy = false

local function TargetName(serverId)
    return ('Patient #%d'):format(serverId)
end

local function PerformTool(name, targetId)
    local tool = Config.Tools[name]
    if not tool or busy then return end
    local onPatient = targetId ~= nil
    local patientPed = nil
    if onPatient then
        local pid = GetPlayerFromServerId(targetId)
        patientPed = pid ~= -1 and GetPlayerPed(pid) or nil
        if not patientPed or #(GetEntityCoords(patientPed) - GetEntityCoords(PlayerPedId())) > Config.MaxTargetDistance then
            return EMS.Notify('The patient is too far away', 'error')
        end
    end

    local ok, err = EMS.TriggerCallback('ems-tools:server:StartTool', name, targetId or 0)
    if not ok then return EMS.Notify(err or 'You can\'t do that right now', 'error') end

    busy = true
    local ped = PlayerPedId()
    if patientPed then
        TaskTurnPedToFaceEntity(ped, patientPed, 700)
        Wait(700)
    end
    local props = {}
    for _, p in ipairs((onPatient and tool.props_patient or tool.props) or {}) do
        props[#props + 1] = EMS.SpawnProp(p, ped)
    end
    local animName = onPatient and tool.anim_patient or tool.anim
    local anim = EMS.PlayAnim(animName or 'kneel', ped)

    -- keep the looped animation going for the whole progress bar
    local running = true
    CreateThread(function()
        while running do
            if anim and not IsEntityPlayingAnim(ped, anim.dict, anim.anim, 3) then
                TaskPlayAnim(ped, anim.dict, anim.anim, 3.0, 3.0, -1, anim.flag or 1, 0, false, false, false)
            end
            Wait(300)
        end
    end)

    local label = onPatient and ('%s → %s'):format(tool.label, TargetName(targetId)) or tool.label
    EMS.Progress(label .. '...', tool.time, function(done)
        running = false
        EMS.DeleteProps(props)
        EMS.StopAnim(anim, ped)
        busy = false
        if done then
            TriggerServerEvent('ems-tools:server:FinishTool', name)
        else
            TriggerServerEvent('ems-tools:server:CancelTool')
            EMS.Notify('Canceled', 'error')
        end
    end)
end

-- Decides who the tool is used on.
function EMS.UseTool(name, forcedTarget)
    local tool = Config.Tools[name]
    if not tool then return end
    if busy then return EMS.Notify('You are already busy', 'error') end
    if forcedTarget then return PerformTool(name, forcedTarget) end
    if tool.use == 'self' then return PerformTool(name, nil) end

    local pid, _, dist = EMS.ClosestPlayer(Config.MaxTargetDistance)
    local targetId = pid and GetPlayerServerId(pid) or nil

    if tool.use == 'patient' then
        if not targetId then return EMS.Notify('No patient nearby', 'error') end
        return PerformTool(name, targetId)
    end

    -- 'any': ask when there is someone next to you
    if not targetId then return PerformTool(name, nil) end
    lib.registerContext({
        id = 'ems_tool_target',
        title = tool.label,
        options = {
            { title = 'Use on myself', icon = 'user', onSelect = function() PerformTool(name, nil) end },
            { title = ('Use on %s'):format(TargetName(targetId)), description = ('%.1f m away'):format(dist), icon = 'user-injured',
              onSelect = function() PerformTool(name, targetId) end },
        },
    })
    lib.showContext('ems_tool_target')
end

RegisterNetEvent('ems-tools:client:UseTool', function(name)
    EMS.UseTool(name)
end)

-- Treat menu for a patient (qb-target / radial): every tool you carry that works on a patient.
function EMS.OpenTreatMenu(targetId)
    if not targetId then
        local pid = EMS.ClosestPlayer(Config.MaxTargetDistance)
        targetId = pid and GetPlayerServerId(pid) or nil
    end
    if not targetId then return EMS.Notify('No patient nearby', 'error') end
    local medic = EMS.IsMedic()
    local options = {}
    for name, tool in pairs(Config.Tools) do
        if tool.use ~= 'self' and (medic or not tool.emsOnly) then
            local has = EMS.HasItem(name)
            options[#options + 1] = {
                title = tool.label,
                description = has and (tool.notify or '') or 'You don\'t carry this item',
                icon = 'kit-medical',
                disabled = not has,
                onSelect = function() EMS.UseTool(name, targetId) end,
            }
        end
    end
    table.sort(options, function(a, b)
        if a.disabled ~= b.disabled then return not a.disabled end
        return a.title < b.title
    end)
    if #options == 0 then return EMS.Notify('You have no medical tools', 'error') end
    lib.registerContext({ id = 'ems_treat_menu', title = ('Treat %s'):format(TargetName(targetId)), options = options })
    lib.showContext('ems_treat_menu')
end

RegisterNetEvent('ems-tools:client:TreatClosest', function() EMS.OpenTreatMenu() end)

-- CPR with a First Aid kit: anyone can bring a downed patient back (1-3 rounds depending on how bad it is).
function EMS.StartCPR(targetId)
    if busy then return end
    if not Config.CPR.Enabled then return end
    if not targetId then
        local pid = EMS.ClosestPlayer(2.5)
        targetId = pid and GetPlayerServerId(pid) or nil
    end
    if not targetId then return EMS.Notify('No patient nearby', 'error') end
    if Config.CPR.Item and not EMS.HasItem(Config.CPR.Item) then return EMS.Notify('You need a First Aid kit to do CPR', 'error') end
    local ok, err, rounds = EMS.TriggerCallback('ems-tools:server:StartCPR', targetId)
    if not ok then return EMS.Notify(err or 'CPR is not possible', 'error') end
    local label = 'Performing CPR...'
    if type(rounds) == 'table' then label = ('Performing CPR (%d/%d)...'):format(rounds.done + 1, rounds.required) end

    busy = true
    local ped = PlayerPedId()
    local pid = GetPlayerFromServerId(targetId)
    local patientPed = pid ~= -1 and GetPlayerPed(pid) or nil
    if patientPed then
        -- kneel at the patient's side
        local pos = GetOffsetFromEntityInWorldCoords(patientPed, -0.9, 0.0, 0.0)
        local myZ = GetEntityCoords(ped).z
        if math.abs(pos.z - myZ) < 1.5 then
            SetEntityCoordsNoOffset(ped, pos.x, pos.y, myZ, false, false, false)
        end
        TaskTurnPedToFaceEntity(ped, patientPed, 600)
        Wait(600)
    end
    local anim = EMS.PlayAnim('cpr', ped)
    local running = true
    CreateThread(function()
        while running do
            if anim and not IsEntityPlayingAnim(ped, anim.dict, anim.anim, 3) then
                TaskPlayAnim(ped, anim.dict, anim.anim, 3.0, 3.0, -1, anim.flag or 1, 0, false, false, false)
            end
            Wait(300)
        end
    end)
    EMS.Progress(label, Config.CPR.Time, function(done)
        running = false
        EMS.StopAnim(anim, ped)
        busy = false
        TriggerServerEvent(done and 'ems-tools:server:FinishCPR' or 'ems-tools:server:CancelTool')
        if not done then EMS.Notify('Canceled', 'error') end
    end)
end

RegisterNetEvent('ems-tools:client:CPRClosest', function() EMS.StartCPR() end)
