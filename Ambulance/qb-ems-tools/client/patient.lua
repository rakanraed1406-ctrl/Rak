-- Patient side: props put on you by a medic (oxygen mask) and the CPR animation.
local patientProps = {}

local function LocalState()
    local ok, state = pcall(function() return exports[Config.HospitalResource]:GetLocalState() end)
    return ok and state or {}
end
EMS.LocalState = LocalState

RegisterNetEvent('ems-tools:client:PatientProp', function(prop)
    if type(prop) ~= 'table' or not prop.model then return end
    local key = prop.model
    if patientProps[key] and DoesEntityExist(patientProps[key]) then DeleteEntity(patientProps[key]) end
    local obj = EMS.SpawnProp(prop, PlayerPedId())
    if not obj then return end
    patientProps[key] = obj
    local duration = tonumber(prop.duration) or 30000
    SetTimeout(duration, function()
        if patientProps[key] == obj then
            if DoesEntityExist(obj) then DeleteEntity(obj) end
            patientProps[key] = nil
        end
    end)
end)

RegisterNetEvent('ems-tools:client:CPRPatient', function(time)
    local ped = PlayerPedId()
    local state = LocalState()
    if not state.laststand or IsPedInAnyVehicle(ped, false) then return end
    -- qb-hospital replays the "writhe" animation unless the patient is escorted
    TriggerEvent('hospital:client:isEscorted', true)
    local anim = EMS.PlayAnim('cpr_patient', ped)
    local endAt = GetGameTimer() + (tonumber(time) or 10000)
    CreateThread(function()
        while GetGameTimer() < endAt and LocalState().laststand do
            if anim and not IsEntityPlayingAnim(ped, anim.dict, anim.anim, 3) then
                TaskPlayAnim(ped, anim.dict, anim.anim, 3.0, 3.0, -1, anim.flag or 1, 0, false, false, false)
            end
            Wait(300)
        end
        EMS.StopAnim(anim, ped)
        TriggerEvent('hospital:client:isEscorted', false)
    end)
end)

RegisterNetEvent('ems-tools:client:Treated', function(text)
    if type(text) == 'string' and text ~= '' then EMS.Notify(text, 'success', 5000) end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, obj in pairs(patientProps) do
        if DoesEntityExist(obj) then DeleteEntity(obj) end
    end
end)
