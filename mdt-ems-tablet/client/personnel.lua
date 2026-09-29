--[[ client/personnel.lua - personnel management, EMS points, recruitment review ]]

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
    TriggerServerEvent('ems-mdt:server:HireNearby', targetServerId)
    cb('ok')
end)

RegisterNUICallback('hireByCitizenId', function(data, cb)
    TriggerServerEvent('ems-mdt:server:HireByCitizenId', data.citizenid, data.grade)
    cb('ok')
end)

RegisterNUICallback('updateGrade', function(data, cb)
    TriggerServerEvent('ems-mdt:server:updateGrade', data.citizenid, data.type)
    cb('ok')
end)

RegisterNUICallback('fireEmployee', function(data, cb)
    TriggerServerEvent('ems-mdt:server:fireEmployee', data.citizenid)
    cb('ok')
end)

-- ===================================================================
-- Recruitment applications (Command staff review)
-- ===================================================================

RegisterNUICallback('handleApplication', function(data, cb)
    TriggerServerEvent('ems-mdt:server:HandleApplication', data.appId, data.actionType)
    cb('ok')
end)

RegisterNUICallback('changePoints', function(data, cb)
    TriggerServerEvent('ems-mdt:server:ChangePoints', data.citizenid, data.mode, data.amount)
    cb('ok')
end)

RegisterNUICallback('toggleSuspension', function(data, cb)
    TriggerServerEvent('ems-mdt:server:ToggleSuspension', data.citizenid, data.reason)
    cb('ok')
end)

RegisterNUICallback('getPersonnelHistory', function(_, cb)
    TriggerServerEvent('ems-mdt:server:GetPersonnelHistory')
    cb('ok')
end)

RegisterNetEvent('ems-mdt:client:ReceivePersonnelHistory', function(history)
    SendNUIMessage({ action = 'personnelHistory', history = history })
end)
