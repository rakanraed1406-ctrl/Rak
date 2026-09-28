PtfxAsset = nil
PtfxName = nil
Ptfx1 = 0.0
Ptfx2 = 0.0
Ptfx3 = 0.0
PtfxScale = 1.0
PtfxNoProp = false

RegisterNetEvent("cylex_animmenuv2:ptfx:sync", function(src, asset, name, offset, rot, scale)
    local player = GetPlayerFromServerId(src)
    local ped = GetPlayerPed(player)
    if player and ped and ped ~= PlayerPedId() then
        if not HasNamedPtfxAssetLoaded(asset) then
            RequestNamedPtfxAsset(asset)
            while not HasNamedPtfxAssetLoaded(asset) do Wait(10) end
        end
        UseParticleFxAssetNextCall(asset)
        StartParticleFxLoopedOnEntity(name, ped, offset.x, offset.y, offset.z, rot.x, rot.y, rot.z, scale, false, false, false)
    end
end)

RegisterNetEvent("cylex_animmenuv2:ptfx:syncProp", function(netId, asset, name, offset, rot, scale)
    if NetworkDoesNetworkIdExist(netId) then
        local propObj = NetToObj(netId)
        if DoesEntityExist(propObj) then
            if not HasNamedPtfxAssetLoaded(asset) then
                RequestNamedPtfxAsset(asset)
                while not HasNamedPtfxAssetLoaded(asset) do Wait(10) end
            end
            UseParticleFxAssetNextCall(asset)
            StartParticleFxLoopedOnEntity(name, propObj, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, scale or 1.0, false, false, false)
        end
    end
end)
