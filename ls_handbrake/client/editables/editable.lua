
-- Notifies the client to pull up the handbrake
-- Function gets called only once
function HandBrakeNotify()
    -- Disabled text help prompt per configuration
end

function PlayAnim(dict, anim, duration)
    -- local dict = "veh@driveby@first_person@passenger_rear_right_handed@smg"
    -- local anim = "outro_90r"

    -- local ped = PlayerPedId()
    -- RequestAnimDict(dict)
    -- while not HasAnimDictLoaded(dict) do
    --     Wait(0)
    -- end
    -- TaskPlayAnim(ped, dict, anim, 8.0, -8.0, duration or 1000, 0, 0, false, false, false)
end

--Integration with kiminaze vehicle clamp
function CanUseHandbrake(vehicle)
    if GetResourceState('VehicleClamp') == 'started' then
        local isAnyWheelClamped = exports["VehicleClamp"]:IsAnyWheelClamped(vehicle)

        if isAnyWheelClamped then
            return false
        end
    end

    if Config.handbrake_input.when_engine_off then
        if GetIsVehicleEngineRunning(vehicle) then
            return false
        end
    end

    return true
end