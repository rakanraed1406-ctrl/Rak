local QBCore = exports['qb-core']:GetCoreObject()

local uiOpen = false
local travelling = false
local current = nil      -- { building = index, floor = index, side = 1 | 2 } of the open panel
local interactIds = {}   -- interact ids we registered (removed on stop)
local targetZones = {}   -- qb-target zone names we registered
local keyPoints = {}     -- points for the built-in "[E]" mode

-- =========================================================================
-- Access (item / job)
-- =========================================================================

local function hasItem(name)
    for _, item in pairs(QBCore.Functions.GetPlayerData().items or {}) do
        if item and item.name == name then return true end
    end
    return false
end

local function canUseFloor(building, floor)
    if floor.item and not hasItem(floor.item) then return false end
    if floor.jobs then
        local PlayerData = QBCore.Functions.GetPlayerData()
        for _, group in ipairs({ PlayerData.job, PlayerData.gang }) do
            local minGrade = group and floor.jobs[group.name]
            if minGrade and (group.grade and group.grade.level or 0) >= minGrade then return true end
        end
        return false
    end
    return true
end

-- =========================================================================
-- UI
-- =========================================================================

local function closeUI()
    uiOpen = false
    current = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function openElevator(buildingIndex, floorIndex, side)
    if uiOpen or travelling then return end
    if IsPedInAnyVehicle(PlayerPedId(), false) then return end

    local building = Config.Elevators[buildingIndex]
    if not building then return end
    if building.item and not hasItem(building.item) then
        local label = QBCore.Shared.Items[building.item] and QBCore.Shared.Items[building.item].label or building.item
        return QBCore.Functions.Notify(('You need a %s to use this elevator.'):format(label), 'error')
    end

    local floors = {}
    for i, f in pairs(building.floor) do
        floors[#floors+1] = {
            index = i,
            floor = tostring(f.floor or i),
            name = f.name or ('Floor ' .. i),
            current = i == floorIndex,
            locked = f.disabled == true or not canUseFloor(building, f),
        }
    end

    current = { building = buildingIndex, floor = floorIndex, side = side }
    uiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', building = building.name, floors = floors })
end

RegisterNUICallback('close', function(_, cb)
    cb('ok')
    closeUI()
end)

local function travel(buildingIndex, from, side, destIndex)
    local building = Config.Elevators[buildingIndex]
    local dest = building and building.floor[destIndex]
    if not dest or destIndex == from or dest.disabled or not canUseFloor(building, dest) then return end

    -- arrive on the same side you entered from (target2 = the other door)
    local point = (side == 2 and dest.target2) and dest.target2 or dest.target
    local coords = point and point.playercoords
    if not coords then return end

    travelling = true
    local ped = PlayerPedId()
    QBCore.Functions.Progressbar('qb_elevator', 'Waiting for the elevator...', building.waittime or 3000, false, false, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {
        animDict = 'anim@apt_trans@elevator',
        anim = 'elev_1',
        flags = 16,
    }, {}, {}, function()
        StopAnimTask(ped, 'anim@apt_trans@elevator', 'elev_1', 1.0)
        DoScreenFadeOut(600)
        while not IsScreenFadedOut() do Wait(10) end

        RequestCollisionAtCoord(coords.x, coords.y, coords.z)
        SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
        SetEntityHeading(ped, coords.w or 0.0)
        local timeout = GetGameTimer() + 3000
        while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < timeout do Wait(10) end

        Wait(400)
        DoScreenFadeIn(800)
        travelling = false
    end, function()
        StopAnimTask(ped, 'anim@apt_trans@elevator', 'elev_1', 1.0)
        travelling = false
    end)
end

-- The UI sends the floor index it picked. We answer right away (the old
-- script never called cb here, which froze the UI) and then move.
RegisterNUICallback('goTo', function(data, cb)
    cb('ok')
    local open = current
    closeUI()
    local dest = type(data) == 'table' and tonumber(data.floor)
    if open and dest then travel(open.building, open.floor, open.side, dest) end
end)

-- =========================================================================
-- Interaction points (interact / qb-target / built-in key)
-- =========================================================================

local function eachPoint(fn)
    for b, building in pairs(Config.Elevators) do
        for f, floor in pairs(building.floor) do
            if floor.target and floor.target.coords then fn(b, f, 1, floor.target, building) end
            if floor.target2 and floor.target2.coords then fn(b, f, 2, floor.target2, building) end
        end
    end
end

local function resolveMode()
    local mode = Config.Interaction or 'auto'
    if mode ~= 'auto' then return mode end
    if GetResourceState('interact') == 'started' then return 'interact' end
    if GetResourceState('qb-target') == 'started' then return 'qb-target' end
    return 'key'
end

RegisterNetEvent('qb-elevator:client:open', function(data)
    if type(data) == 'table' then openElevator(data.building, data.floorIndex, data.side) end
end)

local function setupInteract()
    eachPoint(function(b, f, side, point, building)
        local id = ('qb_elevator_%d_%d_%d'):format(b, f, side) -- unique per point
        interactIds[#interactIds+1] = id
        exports.interact:AddInteraction({
            coords = vector3(point.coords.x, point.coords.y, point.coords.z),
            distance = 4.0,
            interactDst = 1.5,
            id = id,
            name = id,
            options = {
                {
                    label = 'Elevator',
                    icon = 'fas fa-chevron-circle-up',
                    action = function() openElevator(b, f, side) end,
                },
            },
        })
    end)
end

local function setupTarget()
    eachPoint(function(b, f, side, point, building)
        local name = ('qb_elevator_%d_%d_%d'):format(b, f, side)
        local z = point.coords.z
        local minZ, maxZ = point.minZ, point.maxZ
        -- some config zones don't contain their own point (e.g. LSPD floors) -> fix them
        if not minZ or not maxZ or z < minZ or z > maxZ then
            minZ, maxZ = z - 1.5, z + 1.5
        end
        targetZones[#targetZones+1] = name
        exports['qb-target']:AddBoxZone(name, vector3(point.coords.x, point.coords.y, z), point.l1 or 1.0, point.l2 or 1.0, {
            name = name,
            heading = point.heading or 0.0,
            debugPoly = Config.Debug,
            minZ = minZ,
            maxZ = maxZ,
        }, {
            options = {
                {
                    type = 'client',
                    event = 'qb-elevator:client:open',
                    icon = 'fas fa-chevron-circle-up',
                    label = ('Elevator - %s'):format(building.name),
                    building = b,
                    floorIndex = f,
                    side = side,
                },
            },
            distance = 2.0,
        })
    end)
end

local function drawText3D(x, y, z, text)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextColour(255, 255, 255, 215)
    SetTextCentre(true)
    SetTextEntry('STRING')
    AddTextComponentString(text)
    SetDrawOrigin(x, y, z, 0)
    DrawText(0.0, 0.0)
    ClearDrawOrigin()
end

local function setupKey()
    eachPoint(function(b, f, side, point)
        keyPoints[#keyPoints+1] = { b = b, f = f, side = side, coords = vector3(point.coords.x, point.coords.y, point.coords.z) }
    end)
    CreateThread(function()
        while true do
            local sleep = 750
            if not uiOpen and not travelling then
                local pcoords = GetEntityCoords(PlayerPedId())
                for _, p in ipairs(keyPoints) do
                    local dist = #(pcoords - p.coords)
                    if dist < 6.0 then sleep = 0 end
                    if dist < 1.5 then
                        drawText3D(p.coords.x, p.coords.y, p.coords.z + 0.3, '[E] Elevator')
                        if IsControlJustReleased(0, 38) then openElevator(p.b, p.f, p.side) end
                        break
                    end
                end
            end
            Wait(sleep)
        end
    end)
end

CreateThread(function()
    local mode = resolveMode()
    if mode == 'interact' then setupInteract()
    elseif mode == 'qb-target' then setupTarget()
    else setupKey() end
    if Config.Debug then print(('[qb-elevator] interaction mode: %s'):format(mode)) end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if uiOpen then SetNuiFocus(false, false) end
    for _, id in ipairs(interactIds) do pcall(function() exports.interact:RemoveInteraction(id) end) end
    for _, name in ipairs(targetZones) do pcall(function() exports['qb-target']:RemoveZone(name) end) end
end)
