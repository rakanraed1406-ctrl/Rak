-- qb-target options: on players (examine / treat / CPR / stretcher / wheelchair)
-- and on the placed equipment.
local function ServerIdOf(entity)
    local pid = EMS.PlayerFromPed(entity)
    return pid and GetPlayerServerId(pid) or nil
end

local function DownState(entity)
    local sid = ServerIdOf(entity)
    return sid and Player(sid).state.emsDown or nil
end

local cache = {}
local function ClosestFree(kind, coords, maxDist)
    -- qb-target asks this every frame while you aim at a player: cache it briefly
    local c = cache[kind]
    if c and GetGameTimer() - c.at < 500 and #(c.coords - coords) < 0.5 then return c.obj end
    local models = {}
    for _, h in ipairs(EMS.ModelHashes(kind)) do models[h] = true end
    local best, bestDist = nil, maxDist or 4.0
    for _, obj in ipairs(GetGamePool('CObject')) do
        if models[GetEntityModel(obj)] and EMS.KindOf(obj) == kind and not EMS.OccupantOf(obj) then
            local d = #(GetEntityCoords(obj) - coords)
            if d < bestDist and not IsEntityAttachedToAnyVehicle(obj) then best, bestDist = obj, d end
        end
    end
    cache[kind] = { at = GetGameTimer(), coords = coords, obj = best }
    return best
end

CreateThread(function()
    exports['qb-target']:AddGlobalPlayer({
        options = {
            {
                icon = 'fas fa-heart-pulse', label = 'Examine (vitals monitor)',
                canInteract = function() return EMS.IsMedic() and (not Config.Monitor.RequireItemForTarget or EMS.HasItem(Config.Monitor.Item)) end,
                action = function(entity) EMS.OpenMonitor(ServerIdOf(entity)) end,
            },
            {
                icon = 'fas fa-kit-medical', label = 'Treat patient',
                canInteract = function() return EMS.IsMedic() end,
                action = function(entity) EMS.OpenTreatMenu(ServerIdOf(entity)) end,
            },
            {
                icon = 'fas fa-hand-holding-medical', label = 'Perform CPR (First Aid kit)',
                canInteract = function(entity)
                    local down = DownState(entity)
                    return Config.CPR.Enabled and (down == 'laststand' or (down == 'dead' and Config.CPR.AllowNoPulse))
                        and (not Config.CPR.Item or EMS.HasItem(Config.CPR.Item))
                end,
                action = function(entity) EMS.StartCPR(ServerIdOf(entity)) end,
            },
            {
                icon = 'fas fa-bed-pulse', label = 'Put on stretcher',
                canInteract = function(entity)
                    return EMS.IsMedic() and not IsEntityAttached(entity) and ClosestFree('stretcher', GetEntityCoords(entity), 4.0) ~= nil
                end,
                action = function(entity)
                    local obj = ClosestFree('stretcher', GetEntityCoords(entity), 4.0)
                    if obj then TriggerServerEvent('ems-tools:server:PutOn', ObjToNet(obj), ServerIdOf(entity)) end
                end,
            },
            {
                icon = 'fas fa-wheelchair', label = 'Put in wheelchair',
                canInteract = function(entity)
                    return EMS.IsMedic() and DownState(entity) ~= 'dead' and not IsEntityAttached(entity)
                        and ClosestFree('wheelchair', GetEntityCoords(entity), 4.0) ~= nil
                end,
                action = function(entity)
                    local obj = ClosestFree('wheelchair', GetEntityCoords(entity), 4.0)
                    if obj then TriggerServerEvent('ems-tools:server:PutOn', ObjToNet(obj), ServerIdOf(entity)) end
                end,
            },
        },
        distance = 2.5,
    })

    exports['qb-target']:AddTargetModel(EMS.ModelHashes('stretcher'), {
        options = {
            {
                icon = 'fas fa-person-walking', label = 'Push stretcher',
                canInteract = function(entity) return EMS.IsMedic() and EMS.KindOf(entity) == 'stretcher' and not IsEntityAttached(entity) end,
                action = function(entity) EMS.StartPushing(entity) end,
            },
            {
                icon = 'fas fa-truck-medical', label = 'Load into ambulance',
                canInteract = function(entity)
                    return EMS.IsMedic() and EMS.KindOf(entity) == 'stretcher' and not IsEntityAttachedToAnyVehicle(entity)
                        and EMS.ClosestAmbulance(GetEntityCoords(entity), 7.0) ~= nil
                end,
                action = function(entity) EMS.LoadStretcher(entity) end,
            },
            {
                icon = 'fas fa-arrow-right-from-bracket', label = 'Unload from ambulance',
                canInteract = function(entity) return EMS.IsMedic() and EMS.KindOf(entity) == 'stretcher' and IsEntityAttachedToAnyVehicle(entity) end,
                action = function(entity) EMS.UnloadStretcher(entity) end,
            },
            {
                icon = 'fas fa-user-minus', label = 'Take patient off',
                canInteract = function(entity) return EMS.IsMedic() and EMS.OccupantOf(entity) ~= nil end,
                action = function(entity) TriggerServerEvent('ems-tools:server:TakeOff', ObjToNet(entity)) end,
            },
            {
                icon = 'fas fa-box', label = 'Fold stretcher',
                canInteract = function(entity) return EMS.IsMedic() and EMS.KindOf(entity) == 'stretcher' and not EMS.OccupantOf(entity) and not IsEntityAttached(entity) end,
                action = function(entity) TriggerServerEvent('ems-tools:server:Pickup', ObjToNet(entity)) end,
            },
        },
        distance = 2.5,
    })

    exports['qb-target']:AddTargetModel(EMS.ModelHashes('wheelchair'), {
        options = {
            {
                icon = 'fas fa-chair', label = 'Sit down',
                canInteract = function(entity) return EMS.KindOf(entity) == 'wheelchair' and not EMS.OccupantOf(entity) and not IsEntityAttached(entity) end,
                action = function(entity) TriggerServerEvent('ems-tools:server:Sit', ObjToNet(entity)) end,
            },
            {
                icon = 'fas fa-person-walking', label = 'Push wheelchair',
                canInteract = function(entity) return EMS.KindOf(entity) == 'wheelchair' and not IsEntityAttached(entity) end,
                action = function(entity) EMS.StartPushing(entity) end,
            },
            {
                icon = 'fas fa-user-minus', label = 'Help patient up',
                canInteract = function(entity) return EMS.IsMedic() and EMS.OccupantOf(entity) ~= nil end,
                action = function(entity) TriggerServerEvent('ems-tools:server:TakeOff', ObjToNet(entity)) end,
            },
            {
                icon = 'fas fa-box', label = 'Fold wheelchair',
                canInteract = function(entity) return EMS.KindOf(entity) == 'wheelchair' and not EMS.OccupantOf(entity) and not IsEntityAttached(entity) end,
                action = function(entity) TriggerServerEvent('ems-tools:server:Pickup', ObjToNet(entity)) end,
            },
        },
        distance = 2.0,
    })

    exports['qb-target']:AddTargetModel(EMS.ModelHashes('medbag'), {
        options = {
            {
                icon = 'fas fa-briefcase-medical', label = 'Open trauma bag',
                canInteract = function(entity) return EMS.IsMedic() and EMS.KindOf(entity) == 'medbag' end,
                action = function(entity) TriggerServerEvent('ems-tools:server:OpenBag', ObjToNet(entity)) end,
            },
            {
                icon = 'fas fa-hand', label = 'Pick up trauma bag',
                canInteract = function(entity) return EMS.IsMedic() and EMS.KindOf(entity) == 'medbag' end,
                action = function(entity) TriggerServerEvent('ems-tools:server:Pickup', ObjToNet(entity)) end,
            },
        },
        distance = 2.0,
    })
end)
