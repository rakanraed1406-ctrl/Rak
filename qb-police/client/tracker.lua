local isTracking = false

RegisterNetEvent('police:client:starttracking', function()
    if isTracking then 
        QBCore.Functions.Notify('You are tracking some one please wait', 'error', 7500)
    else
        local input = lib.inputDialog('Phone Tracker', {
            { type = "input", label = "Phone #", placeholder = "0551234567" },
        })
        if input then
            if input[1] then 
                TriggerServerEvent('police:server:SendTrackerLocation', input[1])
            else
                QBCore.Functions.Notify('No CitizenID Found', "error")
            end
        end
    end
end)

RegisterNetEvent('police:client:DisableTr', function()
    isTracking = false
end)

RegisterNetEvent('police:client:TrackerMessage', function(coords)
    if isTracking then return end 
    isTracking = true 
    PlaySound(-1, "Lose_1st", "GTAO_FM_Events_Soundset", 0, 0, 1)
    local transG = 200
    local blip = AddBlipForRadius(coords.x, coords.y, coords.z, 150.0)
    SetBlipRotation(blip, 0)
    SetBlipColour(blip, 47)
    SetBlipAlpha(blip, transG)
    while transG ~= 0 do
        Wait(180 * 4)
        transG = transG - 1
        SetBlipAlpha(blip, transG)
        if transG == 0 then
            SetBlipSprite(blip, 2)
            RemoveBlip(blip)
            isTracking = false
            return
        end
    end
end)
