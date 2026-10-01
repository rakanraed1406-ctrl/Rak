-- Server-side event handlers for emotes resource

local invites = {} -- [target] = { [sender] = animId }

local function near(a, b, maxDist)
    local pa, pb = GetPlayerPed(a), GetPlayerPed(b)
    if not pa or pa == 0 or not pb or pb == 0 then return false end
    return #(GetEntityCoords(pa) - GetEntityCoords(pb)) <= maxDist
end

-- Shared emote invite: remembered so only a real invite can be accepted.
RegisterNetEvent("cylex_animmenuv2:server:sendAnimationInvite", function(targetId, animId)
    local src = source
    targetId = tonumber(targetId)
    if not targetId or targetId == src or type(animId) ~= "string" then return end
    if not GetPlayerName(targetId) or not near(src, targetId, 5.0) then return end
    invites[targetId] = invites[targetId] or {}
    invites[targetId][src] = animId
    TriggerClientEvent("cylex_animmenuv2:client:receiveAnimationInvite", targetId, src, animId)
    SetTimeout(12000, function()
        if invites[targetId] and invites[targetId][src] == animId then invites[targetId][src] = nil end
    end)
end)

RegisterNetEvent("cylex_animmenuv2:server:acceptAnimationInvite", function(senderId, animId)
    local src = source
    senderId = tonumber(senderId)
    local pending = invites[src] and invites[src][senderId]
    if not pending or pending ~= animId then return end
    invites[src][senderId] = nil
    if not near(src, senderId, 5.0) then return end
    TriggerClientEvent("cylex_animmenuv2:client:startSyncedAnimation", senderId, src, animId, "sender")
    TriggerClientEvent("cylex_animmenuv2:client:startSyncedAnimation", src, senderId, animId, "receiver")
end)

AddEventHandler("playerDropped", function()
    invites[source] = nil
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
