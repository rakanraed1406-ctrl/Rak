function LoadPropDict(model)
    if not model then return false end
    local modelHash = type(model) == "number" and model or GetHashKey(model)
    if not IsModelInCdimage(modelHash) then return false end
    RequestModel(modelHash)
    local timer = GetGameTimer() + 5000
    while not HasModelLoaded(modelHash) do
        if GetGameTimer() > timer then
            return false
        end
        Wait(10)
    end
    return true
end

RegisterNetEvent("cylex_animmenuv2:client:receiveAnimationInvite", function(src, animData)
    if not animData then return end
    local targetServerId = src
    local animLabel = animData.label or "Synced Emote"

    if sendNotification then
        sendNotification({
            timeout = 10,
            title = "Emote Invite",
            text = "Player [" .. tostring(targetServerId) .. "] invited you to " .. animLabel,
            type = "invite",
            anim = animData
        })
    end
end)

RegisterNetEvent("cylex_animmenuv2:client:startSyncedAnimation", function(targetServerId, animData)
    if animData and onAnimTriggered then
        onAnimTriggered(animData)
    end
end)
