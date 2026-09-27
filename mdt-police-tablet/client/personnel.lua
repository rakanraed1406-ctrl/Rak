--[[ client/personnel.lua - personnel management + recruitment review (suspend/history appended by hand) ]]

local QBCore = MDTClient.QBCore

local function GetNearestPlayerServerId()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local closestId, closestDist = nil, Config.HireDistance

    for _, playerId in ipairs(GetActivePlayers()) do
        local targetPed = GetPlayerPed(playerId)
        if targetPed ~= playerPed then
            local dist = #(playerCoords - GetEntityCoords(targetPed))
            if dist <= closestDist then
                closestDist = dist
                closestId = GetPlayerServerId(playerId)
            end
        end
    end

    return closestId
end

RegisterNUICallback('hireNearby', function(_, cb)
    local targetServerId = GetNearestPlayerServerId()
    if not targetServerId then
        QBCore.Functions.Notify('No civilian is close enough to recruit.', 'error')
        cb('ok')
        return
    end
    TriggerServerEvent('police:server:HireNearby', targetServerId)
    cb('ok')
end)

RegisterNUICallback('hireByCitizenId', function(data, cb)
    TriggerServerEvent('police:server:HireByCitizenId', data.citizenid, data.grade)
    cb('ok')
end)

RegisterNUICallback('updateGrade', function(data, cb)
    TriggerServerEvent('police:server:updateGrade', data.citizenid, data.type)
    cb('ok')
end)

RegisterNUICallback('fireEmployee', function(data, cb)
    TriggerServerEvent('police:server:fireEmployee', data.citizenid)
    cb('ok')
end)

-- ===================================================================
-- Recruitment applications (Command staff review)
-- ===================================================================

RegisterNUICallback('handleApplication', function(data, cb)
    TriggerServerEvent('police:server:HandleApplication', data.appId, data.actionType)
    cb('ok')
end)

-- ===================================================================
-- Reports app
-- ===================================================================

RegisterNUICallback('toggleSuspension', function(data, cb)
    TriggerServerEvent('police:server:ToggleSuspension', data.citizenid, data.reason)
    cb('ok')
end)

RegisterNUICallback('getPersonnelHistory', function(_, cb)
    TriggerServerEvent('police:server:GetPersonnelHistory')
    cb('ok')
end)

RegisterNetEvent('police:client:ReceivePersonnelHistory', function(history)
    SendNUIMessage({ action = 'personnelHistory', history = history })
end)
