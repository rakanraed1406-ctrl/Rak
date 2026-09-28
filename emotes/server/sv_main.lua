-- Server-side event handlers for emotes resource

RegisterNetEvent("cylex_animmenuv2:server:sendAnimationInvite", function(targetId, animData)
    local src = source
    if targetId and targetId > 0 then
        TriggerClientEvent("cylex_animmenuv2:client:receiveAnimationInvite", targetId, src, animData)
    end
end)

RegisterNetEvent("cylex_animmenuv2:server:acceptAnimationInvite", function(targetId, animData)
    local src = source
    if targetId and targetId > 0 then
        TriggerClientEvent("cylex_animmenuv2:client:startSyncedAnimation", targetId, src, animData)
        TriggerClientEvent("cylex_animmenuv2:client:startSyncedAnimation", src, targetId, animData)
    end
end)

RegisterNetEvent("cylex_animmenuv2:server:animpos:syncAnimpos", function(targetId, x, y, z)
    local src = source
    if targetId == -1 then
        TriggerClientEvent("cylex_animmenuv2:client:syncAnimpos", -1, src, x, y, z)
    elseif targetId and targetId > 0 then
        TriggerClientEvent("cylex_animmenuv2:client:syncAnimpos", targetId, src, x, y, z)
    end
end)

RegisterNetEvent("cylex_animmenuv2:ptfx:sync", function(asset, name, offset, rot, scale)
    local src = source
    TriggerClientEvent("cylex_animmenuv2:ptfx:sync", -1, src, asset, name, offset, rot, scale)
end)
