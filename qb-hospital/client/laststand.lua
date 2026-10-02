Laststand = Laststand or {}
Laststand.ReviveInterval = Config.ReviveInterval
Laststand.MinimumRevive = Config.MinimumRevive
InLaststand = false
LaststandTime = 0
lastStandDict = "combat@damage@writhe"
lastStandAnim = "writhe_loop"
isEscorted = false
local isEscorting = false

-- Functions

local function GetClosestPlayer()
    local closestPlayers = QBCore.Functions.GetPlayersFromCoords()
    local closestDistance = -1
    local closestPlayer = -1
    local coords = GetEntityCoords(PlayerPedId())

    for i=1, #closestPlayers, 1 do
        if closestPlayers[i] ~= PlayerId() then
            local pos = GetEntityCoords(GetPlayerPed(closestPlayers[i]))
            local distance = #(pos - coords)

            if closestDistance == -1 or closestDistance > distance then
                closestPlayer = closestPlayers[i]
                closestDistance = distance
            end
        end
	end

	return closestPlayer, closestDistance
end

local function LoadAnimation(dict)
    while not HasAnimDictLoaded(dict) do
        RequestAnimDict(dict)
        Wait(100)
    end
end

function SetLaststand(bool, killid, killerWeapon)
    local ped = PlayerPedId()
    if bool then
        Wait(1000)
        local pos = GetEntityCoords(ped)
        local heading = GetEntityHeading(ped)

        while GetEntitySpeed(ped) > 0.5 or IsPedRagdoll(ped) do
            Wait(10)
        end

        TriggerServerEvent("InteractSound_SV:PlayOnSource", "demo", 0.1)

        LaststandTime = Laststand.ReviveInterval

        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped) then
            local veh = GetVehiclePedIsIn(ped)
            local vehseats = GetVehicleModelNumberOfSeats(GetEntityModel(veh))
            for i = -1, vehseats do
                local occupant = GetPedInVehicleSeat(veh, i)
                if occupant == ped then
                    NetworkResurrectLocalPlayer(pos.x, pos.y, pos.z + 0.5, heading, true, false)
                    SetPedIntoVehicle(ped, veh, i)
                end
            end
        else
            NetworkResurrectLocalPlayer(pos.x, pos.y, pos.z + 0.5, heading, true, false)
        end		
		
        SetEntityHealth(ped, 150)

        if IsPedInAnyVehicle(ped, false) then
            LoadAnimation("veh@low@front_ps@idle_duck")
            TaskPlayAnim(ped, "veh@low@front_ps@idle_duck", "sit", 1.0, 8.0, -1, 1, -1, false, false, false)
        else
            LoadAnimation(lastStandDict)
            TaskPlayAnim(ped, lastStandDict, lastStandAnim, 1.0, 8.0, -1, 1, -1, false, false, false)
        end

        InLaststand = true

        -- TriggerServerEvent('hospital:server:ambulanceAlert', Lang:t('info.civ_down'))
        -- EMSAlert('Civilian Down')

        CreateThread(function()
            while InLaststand do
                ped = PlayerPedId()
                player = PlayerId()
                if LaststandTime - 1 > Laststand.MinimumRevive then
                    LaststandTime = LaststandTime - 1
                    Config.DeathTime = LaststandTime
                elseif LaststandTime - 1 <= Laststand.MinimumRevive and LaststandTime - 1 ~= 0 then
                    LaststandTime = LaststandTime - 1
                    Config.DeathTime = LaststandTime
                elseif LaststandTime - 1 <= 0 then
                    QBCore.Functions.Notify(Lang:t('error.bled_out'), "error")
                    SetLaststand(false)
                    local killerId = NetworkGetPlayerIndexFromPed(killid)
                    local killerName = killerId ~= -1 and GetPlayerName(killerId) .. " " .. "("..GetPlayerServerId(killerId)..")" or Lang:t('info.self_death')
                    local weaponLabel = Lang:t('info.wep_unknown')
                    local weaponName = Lang:t('info.wep_unknown')
                    local weaponItem = QBCore.Shared.Weapons[killerWeapon]
                    if weaponItem then
                        weaponLabel = weaponItem.label
                        weaponName = weaponItem.name
                    end
                    TriggerServerEvent("qb-hospital:sv:sendkilllog", GetPlayerServerId(killerId), GetPlayerServerId(player), weaponLabel, weaponName)
                    -- TriggerServerEvent("qb-log:server:CreateLog", 
                    --     "death", 
                    --     Lang:t('logs.death_log_title', {playername = GetPlayerName(player), playerid = GetPlayerServerId(player)}), 
                    --     "red", 
                    --     Lang:t('logs.death_log_message', {
                    --         killername = killerName, playername = GetPlayerName(player), weaponlabel = weaponLabel, weaponname = weaponName
                    --     })
                    -- )
                    deathTime = 0
                    OnDeath()
                    DeathTimer()
                end
                Wait(1000)
            end
        end)
    else
        TaskPlayAnim(ped, lastStandDict, "exit", 1.0, 8.0, -1, 1, -1, false, false, false)
        InLaststand = false
        LaststandTime = 0
    end
    TriggerServerEvent("hospital:server:SetLaststandStatus", bool)
end

-- Events

RegisterNetEvent('hospital:client:SetEscortingState', function(bool)
    isEscorting = bool
end)

RegisterNetEvent('hospital:client:isEscorted', function(bool)
    isEscorted = bool
end)

-- The First Aid kit is used for CPR now (qb-ems-tools).
