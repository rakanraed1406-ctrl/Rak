local pending = nil

-- exports['qb-ui']:StartLockPickCircle(circles, seconds) -> true / false
-- circles = how many hits are needed (default 4)
-- seconds = speed value, same meaning as before (bigger = slower needle)
local function StartLockPickCircle(circles, seconds)
    if pending then return false end
    pending = promise.new()

    SetNuiFocus(true, false)
    SendNUIMessage({
        action = 'start',
        value = circles,
        time = seconds,
    })

    local result = Citizen.Await(pending)
    pending = nil
    SetNuiFocus(false, false)
    if not result then
        ClearPedTasks(PlayerPedId())
    end
    return result
end

local function finish(result)
    if pending then pending:resolve(result) end
end

RegisterNUICallback('fail', function(_, cb)
    cb('ok')
    finish(false)
end)

RegisterNUICallback('success', function(_, cb)
    cb('ok')
    finish(true)
end)

RegisterNetEvent('qb-lockpick:client:openLockpick', function(callback, circles)
    CreateThread(function()
        local result = StartLockPickCircle(circles)
        if callback then callback(result) end
    end)
end)

exports('StartLockPickCircle', StartLockPickCircle)
