--[[═════════════════════════════════════════════════════════════════════
    تغيير سيارات البوتات (NPC) — مدني فقط
    إصلاحات:
    - `for veh in ipairs(...)` كان ياخذ الرقم مو السيارة → ما كان يبدل شي
    - SetEntityModel مو موجود باللعبة → صار نحذف السيارة ونسوي وحدة جديدة
      بنفس المكان والسرعة ونرجع البوت (والركاب) فيها ويكمل سواقته
    - ما نلمس سيارات السكربتات (Mission) ولا سيارة فيها لاعب
    - بس مالك السيارة بالشبكة يبدلها (ما يصير تكرار بين اللاعبين)
    - السيارة اللي تبدلت ما تتبدل مرة ثانية
═════════════════════════════════════════════════════════════════════════]]

local Cfg = Config.NpcVehicles
if not Cfg.Enabled then return end

local explicit, pool, skip = {}, nil, {}
local targets, badModels  = {}, {}
local disabled = false

local function buildLookup()
    explicit, pool, skip, targets = {}, nil, {}, {}

    for name, spec in pairs(Cfg.Models or {}) do
        explicit[joaat(name)] = spec
        if type(spec) == 'string' then targets[joaat(spec)] = true
        elseif type(spec) == 'table' then for _, n in ipairs(spec) do targets[joaat(n)] = true end end
    end

    for cls, on in pairs(Cfg.SkipClasses or {}) do
        if on then skip[cls] = true end
    end

    if type(Cfg.CivilianPool) == 'table' and #Cfg.CivilianPool > 0 then
        pool = Cfg.CivilianPool
        for _, n in ipairs(pool) do targets[joaat(n)] = true end
    end
end

local function pick(spec)
    if type(spec) == 'string' then return spec end
    if type(spec) ~= 'table' or #spec == 0 then return nil end
    return spec[math.random(#spec)]
end

local function occupants(veh)
    local list, hasPlayer = {}, false
    for seat = -1, GetVehicleMaxNumberOfPassengers(veh) - 1 do
        local p = GetPedInVehicleSeat(veh, seat)
        if p ~= 0 then
            if IsPedAPlayer(p) then hasPlayer = true end
            list[#list + 1] = { ped = p, seat = seat }
        end
    end
    return list, hasPlayer
end

local function isTarget(veh, myVeh)
    if veh == myVeh or not DoesEntityExist(veh) then return false end
    if targets[GetEntityModel(veh)] then return false end            -- تبدلت قبل
    if IsEntityAMissionEntity(veh) then return false end              -- سيارة سكربت
    if skip[GetVehicleClass(veh)] then return false end
    if not Utils.Owns(veh) then return false end

    local driver = GetPedInVehicleSeat(veh, -1)
    if driver == 0 or IsPedAPlayer(driver) or IsEntityDead(driver) or IsEntityAMissionEntity(driver) then
        return false
    end
    return true
end

local function loadModel(name)
    local hash = joaat(name)
    if badModels[hash] then return nil end
    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then
        badModels[hash] = true
        print(('[npc_vehicles] الموديل "%s" مو موجود — تأكد إن مورد السيارات شغال قبل هذا السكربت'):format(name))
        return nil
    end

    RequestModel(hash)
    local deadline = GetGameTimer() + Cfg.ModelTimeout
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(0) end
    if not HasModelLoaded(hash) then return nil end
    return hash
end

local function swapVehicle(veh, modelName)
    local hash = loadModel(modelName)
    if not hash then return false end
    if not DoesEntityExist(veh) or not Utils.Owns(veh) then
        SetModelAsNoLongerNeeded(hash)
        return false
    end

    local seats, hasPlayer = occupants(veh)
    if hasPlayer or #seats == 0 then SetModelAsNoLongerNeeded(hash) return false end

    local coords   = GetEntityCoords(veh)
    local heading  = GetEntityHeading(veh)
    local velocity = GetEntityVelocity(veh)

    -- نسوي الجديدة تحت الأرض أول، وإذا ما انسوت (sv_entityLockdown) نخلي القديمة مثل ما هي
    local newVeh = CreateVehicle(hash, coords.x, coords.y, coords.z - 50.0, heading, true, false)
    SetModelAsNoLongerNeeded(hash)
    if newVeh == 0 or not DoesEntityExist(newVeh) then
        disabled = true
        print('[npc_vehicles] السيرفر ما يسمح للكلاينت يسوي سيارات (sv_entityLockdown) — وقفنا التبديل')
        return false
    end
    FreezeEntityPosition(newVeh, true)
    SetEntityCollision(newVeh, false, false)

    for _, o in ipairs(seats) do
        SetEntityAsMissionEntity(o.ped, true, true)
        SetPedIntoVehicle(o.ped, newVeh, o.seat)
    end

    SetEntityAsMissionEntity(veh, true, true)
    DeleteVehicle(veh)

    SetEntityCoordsNoOffset(newVeh, coords.x, coords.y, coords.z, false, false, false)
    SetEntityHeading(newVeh, heading)
    SetEntityCollision(newVeh, true, true)
    FreezeEntityPosition(newVeh, false)
    SetVehicleOnGroundProperly(newVeh)
    SetVehicleEngineOn(newVeh, true, true, false)
    SetEntityVelocity(newVeh, velocity.x, velocity.y, velocity.z)

    for _, o in ipairs(seats) do
        if o.seat == -1 then
            TaskVehicleDriveWander(o.ped, newVeh, Cfg.DriveSpeed, 786603)
            SetPedKeepTask(o.ped, true)
        end
        SetPedAsNoLongerNeeded(o.ped)
    end
    SetVehicleHasBeenOwnedByPlayer(newVeh, false)
    SetEntityAsNoLongerNeeded(newVeh)

    Utils.Log('npc_vehicles: تبدلت سيارة بوت ←', modelName)
    return true
end

local function specFor(veh)
    local forced = explicit[GetEntityModel(veh)]
    if forced ~= nil then return forced or nil end   -- false = لا تلمسها
    return pool
end

local function sweepOnce(radius)
    if disabled then return 0 end
    local myVeh = cache.vehicle or 0
    local pos   = GetEntityCoords(cache.ped)
    radius      = tonumber(radius) or Cfg.Radius

    local done = 0
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if done >= Cfg.MaxPerTick or disabled then break end
        if isTarget(veh, myVeh) then
            local dist = #(GetEntityCoords(veh) - pos)
            if dist <= radius and (dist >= Cfg.MinDistance or not IsEntityOnScreen(veh)) then
                local target = pick(specFor(veh))
                if target and swapVehicle(veh, target) then done = done + 1 end
            end
        end
    end
    return done
end

CreateThread(function()
    buildLookup()
    while true do
        Wait(Cfg.RefreshInterval)
        sweepOnce()
    end
end)

RegisterCommand('npcvehnow', function()
    if not Config.Debug then return end
    buildLookup()
    print(('[npc_vehicles] تبدلت %d سيارة بوت حولك'):format(sweepOnce()))
end, false)
