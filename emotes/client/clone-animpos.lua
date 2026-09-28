local clonePed = nil
local cloneCoords = nil
local cloneHeading = 0.0

RegisterNetEvent("cylex_animmenuv2:client:syncAnimpos", function(src, x, y, z)
    local player = GetPlayerFromServerId(src)
    local targetPed = GetPlayerPed(player)
    if player and targetPed and PlayerPedId() ~= targetPed then
        SetEntityCoords(targetPed, x, y, z, false, false, false, false)
    end
end)

function createClonePed(animation)
    if clonePed and DoesEntityExist(clonePed) then
        DeleteEntity(clonePed)
        clonePed = nil
    end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)

    cloneCoords = coords
    cloneHeading = heading

    clonePed = ClonePed(ped, heading, false, false)
    SetEntityAlpha(clonePed, 150, false)
    SetEntityCollision(clonePed, false, false)

    if animation and animation.dict then
        RequestAnimDict(animation.dict)
        while not HasAnimDictLoaded(animation.dict) do Wait(10) end
        TaskPlayAnim(clonePed, animation.dict, animation.anim, 8.0, -8.0, -1, 1, 0, false, false, false)
    end

    CreateThread(function()
        while clonePed and DoesEntityExist(clonePed) do
            Wait(0)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            if IsControlJustReleased(0, 191) then
                local newCoords = GetEntityCoords(clonePed)
                local newHeading = GetEntityHeading(clonePed)
                DeleteEntity(clonePed)
                clonePed = nil
                SetEntityCoords(ped, newCoords.x, newCoords.y, newCoords.z, false, false, false, false)
                SetEntityHeading(ped, newHeading)
                TriggerServerEvent("cylex_animmenuv2:server:animpos:syncAnimpos", -1, newCoords.x, newCoords.y, newCoords.z)
                break
            elseif IsControlJustReleased(0, 73) then
                DeleteEntity(clonePed)
                clonePed = nil
                break
            end
        end
    end)
end
