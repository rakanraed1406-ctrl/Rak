local isNormalAnimPosActive = false

function clearNormalAnimpos()
    isNormalAnimPosActive = false
    local ped = PlayerPedId()
    SetEntityAlpha(ped, 255, false)
end

function startNormalAnimpos(animation)
    local ped = PlayerPedId()
    if not ped or not animation then return end

    isNormalAnimPosActive = true
    local startCoords = GetEntityCoords(ped)

    CreateThread(function()
        while isNormalAnimPosActive do
            Wait(0)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)

            if IsControlJustReleased(0, 191) then
                local newCoords = GetEntityCoords(ped)
                SetEntityAlpha(ped, 255, false)
                TriggerServerEvent("cylex_animmenuv2:server:animpos:syncAnimpos", -1, newCoords.x, newCoords.y, newCoords.z)
                clearNormalAnimpos()
                break
            elseif IsControlJustReleased(0, 73) then
                if Config and Config.AnimPos and Config.AnimPos.TeleportBackOnCancel then
                    SetEntityCoords(ped, startCoords.x, startCoords.y, startCoords.z, false, false, false, false)
                end
                clearNormalAnimpos()
                return
            end
        end
    end)
end
