local Promise = nil

RegisterNUICallback("gameFinished", function() 
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = "endGame"
    })
    Promise:resolve(true)
end)

RegisterNUICallback("failedGame", function()
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = "endGame"
    }) 
    Promise:resolve(false)
end)

exports('createGame', function(stages, maxFail) 
    SetNuiFocus(true, true)

    SendNUIMessage({
        action = "createGame",
        stages = stages,
        maxFail = maxFail
    })

    Promise = promise.new()

    local result = Citizen.Await(Promise)

    return result
end)
