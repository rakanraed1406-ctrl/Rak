-----------------------
----   Variables   ----
-----------------------
local QBCore = exports['qb-core']:GetCoreObject()
local KeysList = {}

local isTakingKeys = false
local runningClaims = {}   -- [vehicle] = 'pending' | 'granted' | 'denied'

-----------------------
----   Threads     ----
-----------------------
-- كل شي هنا يشتغل على الأحداث (زر F / ركبت سيارة) — وأنت ماشي ما فيه أي لوب شغال

local npcPending = {}      -- [vehicle] = true  (سيارة بوت طلعت مفتوحة)
local fHeld = false
local inVehicleSession = false

local function isImmune(veh)
    local model = GetEntityModel(veh)
    for _, name in ipairs(Config.ImmuneVehicles) do
        if model == joaat(name) then return true end
    end
    return false
end

local function applyPedFlags()
    -- ما أحد يسحبك من سيارتك بضغطة F (Config.PlayersCanBeDraggedOut)
    if not Config.PlayersCanBeDraggedOut then SetPedCanBeDraggedOut(PlayerPedId(), false) end
end

local function waitTryingToEnter(ped, ms)
    local deadline = GetGameTimer() + ms
    while GetGameTimer() < deadline do
        local veh = GetVehiclePedIsTryingToEnter(ped)
        if veh ~= 0 then return veh end
        Wait(50)
    end
    return 0
end

local function closestDrivenVehicle(ped, maxDist)
    local pos = GetEntityCoords(ped)
    local best, bestDist = 0, maxDist
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        local d = #(GetEntityCoords(veh) - pos)
        if d < bestDist then
            local driver = GetPedInVehicleSeat(veh, -1)
            if driver ~= 0 and driver ~= ped then best, bestDist = veh, d end
        end
    end
    return best
end

-- مقفلة؟ (حالة القفل من السيرفر + حالة اللعبة)
local function isLocked(veh)
    return GetVehicleDoorLockStatus(veh) >= 2
end

-- السواق البوت ميت: تاخذ المفتاح من جثته
local function takeKeysFromBody(veh, plate)
    if isTakingKeys then return end
    isTakingKeys = true
    TriggerServerEvent('qb-vehiclekeys:server:setVehLockState', NetworkGetNetworkIdFromEntity(veh), 1)
    QBCore.Functions.Progressbar("steal_keys", Lang:t("progress.takekeys"), 2500, false, false, {
        disableMovement = false,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true
    }, {}, {}, {}, function()
        TriggerServerEvent('qb-vehiclekeys:server:AcquireVehicleKeys', plate)
        isTakingKeys = false
    end, function()
        isTakingKeys = false
    end)
end

-- البوت يشرد بسيارته
local function npcFlee(driver, veh)
    if not NetworkHasControlOfEntity(driver) then NetworkRequestControlOfEntity(driver) end
    SetBlockingOfNonTemporaryEvents(driver, true)
    SetDriverAbility(driver, 1.0)
    SetDriverAggressiveness(driver, 1.0)
    TaskVehicleMissionPedTarget(driver, veh, PlayerPedId(), 8, Config.NpcCarjack.FleeSpeed, 786468, 1000.0, 10.0, true)
    SetPedKeepTask(driver, true)
    StartVehicleHorn(veh, 1500, `HELDDOWN`, false)
end

-- ينتظر لين شخصيتك تحاول تفتح الباب وتستسلم (أنيميشن الباب المقفل حق قراند)
local function waitGaveUp(ped, veh, ms)
    local deadline = GetGameTimer() + ms
    while GetGameTimer() < deadline do
        if GetVehiclePedIsTryingToEnter(ped) ~= veh then return true end
        Wait(100)
    end
    return false
end

local npcBusy = {}
local gunpointVehicles = {}   -- [vehicle] = true  (رفعت السلاح على سواقها)

-- سيارة بوت بالشارع: 50% مفتوحة (تنزله وتاخذ المفتاح) / 50% مقفلة (تحاول تفتح الباب → Locked → يشرد)
-- القرعة من السيرفر (الكلاينت ما يقدر يغش ويخليها مفتوحة دايم)
local function handleNpcVehicle(ped, veh, driver, seat)
    local plate = QBCore.Functions.GetPlate(veh)
    if HasKeys(plate) then return end

    if IsEntityDead(driver) then return takeKeysFromBody(veh, plate) end
    if not Config.NpcCarjack.Enabled or IsEntityAMissionEntity(veh) or npcBusy[veh] then return end
    npcBusy[veh] = true

    -- نقفلها عندك لين توصل النتيجة: لو وصلت الباب قبلها تحاول تفتحه مثل قراند
    if Entity(veh).state.npcLock ~= 'unlocked' then SetVehicleDoorsLocked(veh, 2) end

    local state, done = nil, false
    QBCore.Functions.TriggerCallback('qb-vehiclekeys:server:NpcLockRoll', function(result)
        state, done = result, true
    end, NetworkGetNetworkIdFromEntity(veh))
    local deadline = GetGameTimer() + 3000
    while not done and GetGameTimer() < deadline do Wait(0) end

    if state == 'locked' then
        -- تحاول تفتح الباب (لو ما بديت تركب نخليك تروح للباب)
        if GetVehiclePedIsTryingToEnter(ped) ~= veh then TaskEnterVehicle(ped, veh, 4000, -1, 2.0, 1, 0) Wait(300) end
        waitGaveUp(ped, veh, 6000)
        QBCore.Functions.Notify(Lang:t('notify.npc_locked'), 'error')

        if Config.NpcCarjack.AlarmOnLocked then
            SetVehicleAlarm(veh, true)
            SetVehicleAlarmTimeLeft(veh, 8000)
            StartVehicleAlarm(veh)
        end

        Wait(Config.NpcCarjack.FleeDelay)
        if DoesEntityExist(veh) and DoesEntityExist(driver) and not IsEntityDead(driver)
            and GetPedInVehicleSeat(veh, -1) == driver and not gunpointVehicles[veh] then
            npcFlee(driver, veh)
        end
    elseif state == 'unlocked' then
        SetVehicleDoorsLocked(veh, 1)
        npcPending[veh] = true
        -- مفتوحة: تروح لباب السواق وتنزّله (حتى لو ضغطت من جهة الراكب)
        if Config.NpcCarjack.DriverOnly and (seat ~= -1 or GetVehiclePedIsTryingToEnter(ped) ~= veh) then
            ClearPedTasks(ped)
            TaskEnterVehicle(ped, veh, 10000, -1, 2.0, 8, 0)
        end
    else
        SetVehicleDoorsLocked(veh, 1) -- السيرفر ما رد: نرجعها مثل ما كانت
    end
    npcBusy[veh] = nil
end

-- زر F: سيارات البوتات (50/50) + سيارة مقفلة (Locked). سيارات اللاعبين = ركوب عادي مثل قراند
RegisterCommand('+vehkeys_f', function()
    fHeld = true
    local ped = PlayerPedId()
    if not LocalPlayer.state.isLoggedIn or IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) then return end

    CreateThread(function()
        local veh = waitTryingToEnter(ped, 400)
        local seat = veh ~= 0 and GetSeatPedIsTryingToEnter(ped) or nil   -- nil = ما بدأت تركب
        -- بوت يمشي شوي وقراند ما بدأ يركّبك: لو معلّق على F ناخذ أقرب سيارة
        if veh == 0 and Config.NpcCarjack.Enabled and fHeld then
            veh = closestDrivenVehicle(ped, 3.5)
            if veh ~= 0 and IsPedAPlayer(GetPedInVehicleSeat(veh, -1)) then veh = 0 end
        end
        if veh == 0 or isBlacklistedVehicle(veh) then return end

        local driver = GetPedInVehicleSeat(veh, -1)
        if driver == ped then return end

        -- بوت سايق: 50/50 (يتعامل مع القفل بنفسه)
        if driver ~= 0 and not IsPedAPlayer(driver) then
            if not isImmune(veh) then handleNpcVehicle(ped, veh, driver, seat) end
            return
        end

        -- مقفلة (قفلها صاحبها): شخصيتك تحاول تفتح الباب مثل قراند → Locked
        if seat ~= nil and isLocked(veh) then
            if GetVehiclePedIsTryingToEnter(ped) == veh then waitGaveUp(ped, veh, 6000) end
            QBCore.Functions.Notify(Lang:t('notify.veh_locked'), 'error')
        end
    end)
end, false)

RegisterCommand('-vehkeys_f', function()
    fHeld = false
end, false)

RegisterKeyMapping('+vehkeys_f', 'Vehicle: enter', 'keyboard', 'F')

-- وأنت داخل سيارة بس: المفتاح / إطفاء الموتر لو ما عندك مفتاح / تبليغ لما تنزل
local function startVehicleSession()
    if inVehicleSession then return end
    inVehicleSession = true

    CreateThread(function()
        while true do
            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, false)
            if veh == 0 then break end

            local sleep = 1000
            if GetPedInVehicleSeat(veh, -1) == ped then
                local plate = QBCore.Functions.GetPlate(veh)
                -- معك المفتاح = ما فيه شي نسويه (فحص كل ثانية بس)
                sleep = HasKeys(plate) and 1000 or 500
                if sleep == 500 and not isBlacklistedVehicle(veh) and not AreKeysJobShared(veh) then
                    if ClaimRunningVehicle(veh) then
                        sleep = 100
                    else
                        SetVehicleEngineOn(veh, false, false, true)
                    end
                end
            end
            Wait(sleep)
        end

        runningClaims, npcPending = {}, {}
        inVehicleSession = false
    end)
end

AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkPlayerEnteredVehicle' or args[1] ~= PlayerId() then return end
    applyPedFlags()

    -- ركبت سيارة مقفلة بدون مفتاح (تأخير شبكة/غش) → تنزل
    local veh = args[2]
    if veh and veh ~= 0 and Entity(veh).state.vehLocked == true and GetVehicleDoorLockStatus(veh) >= 2
        and not HasKeys(QBCore.Functions.GetPlate(veh)) and not AreKeysJobShared(veh) then
        TaskLeaveVehicle(PlayerPedId(), veh, 16)
        return QBCore.Functions.Notify(Lang:t('notify.veh_locked'), 'error')
    end

    startVehicleSession()
end)

CreateThread(function()
    Wait(1000)
    applyPedFlags()
    if IsPedInAnyVehicle(PlayerPedId(), false) then startVehicleSession() end
end)

-----------------------
----   Gunpoint    ----
-----------------------
-- ترفع السلاح على بوت سايق: ما يشرد — يوقف، ينزل رافع يدينه، والسيارة تنفتح (حتى لو مقفلة)
-- واركب وخذ المفتاح. يشتغل بس وأنت ماسك كلك يمين (استهلاك صفر غير كذا)

local aimHeld = false

local function requestControl(entity)
    if NetworkHasControlOfEntity(entity) then return true end
    NetworkRequestControlOfEntity(entity)
    local deadline = GetGameTimer() + 1000
    while not NetworkHasControlOfEntity(entity) and GetGameTimer() < deadline do Wait(0) end
    return NetworkHasControlOfEntity(entity)
end

local function npcOccupants(veh)
    local list = {}
    for seat = -1, GetVehicleMaxNumberOfPassengers(veh) - 1 do
        local p = GetPedInVehicleSeat(veh, seat)
        if p ~= 0 and not IsPedAPlayer(p) and not IsEntityDead(p) then list[#list + 1] = p end
    end
    return list
end

local function gunpoint(veh, driver)
    if gunpointVehicles[veh] then return end
    gunpointVehicles[veh] = true
    local me = PlayerPedId()

    -- يتجمّد من الخوف بدل ما يشرد (ردة فعل قراند الأصلية)
    for _, occ in ipairs(npcOccupants(veh)) do
        requestControl(occ)
        SetBlockingOfNonTemporaryEvents(occ, true)
    end
    TaskVehicleTempAction(driver, veh, 27, 3000)  -- فرامل

    local approved, done = false, false
    QBCore.Functions.TriggerCallback('qb-vehiclekeys:server:Gunpoint', function(ok)
        approved, done = ok, true
    end, NetworkGetNetworkIdFromEntity(veh))
    local deadline = GetGameTimer() + 3000
    while not done and GetGameTimer() < deadline do Wait(0) end

    if not approved then
        for _, occ in ipairs(npcOccupants(veh)) do SetBlockingOfNonTemporaryEvents(occ, false) end
        gunpointVehicles[veh] = nil
        return
    end

    deadline = GetGameTimer() + 3000
    while GetEntitySpeed(veh) > 1.0 and GetGameTimer() < deadline do Wait(100) end

    SetVehicleDoorsLocked(veh, 1)
    npcPending[veh] = true

    for _, occ in ipairs(npcOccupants(veh)) do
        CreateThread(function()
            ClearPedTasks(occ)
            TaskLeaveVehicle(occ, veh, 256)   -- ينزل ويخلي الباب مفتوح
            local t = GetGameTimer() + 4000
            while IsPedInAnyVehicle(occ, false) and GetGameTimer() < t do Wait(100) end
            TaskHandsUp(occ, Config.Gunpoint.HandsUpTime, me, -1, true)
            SetPedKeepTask(occ, true)
            Wait(Config.Gunpoint.HandsUpTime)
            if DoesEntityExist(occ) and not IsEntityDead(occ) then
                SetBlockingOfNonTemporaryEvents(occ, false)
                if Config.Gunpoint.FleeOnFoot then TaskReactAndFleePed(occ, PlayerPedId()) end
                SetPedAsNoLongerNeeded(occ)
            end
        end)
    end
end

local function aimTarget()
    local aiming, target = GetEntityPlayerIsFreeAimingAt(PlayerId())
    if not aiming or not target or target == 0 or not DoesEntityExist(target) then return nil end

    local veh, driver
    if IsEntityAVehicle(target) then
        veh, driver = target, GetPedInVehicleSeat(target, -1)
    elseif IsEntityAPed(target) and IsPedInAnyVehicle(target, false) then
        veh = GetVehiclePedIsIn(target, false)
        driver = GetPedInVehicleSeat(veh, -1)
    end
    if not veh or not driver or driver == 0 or IsPedAPlayer(driver) or IsEntityDead(driver) then return nil end
    if IsEntityAMissionEntity(veh) or isImmune(veh) or isBlacklistedVehicle(veh) then return nil end
    if gunpointVehicles[veh] or HasKeys(QBCore.Functions.GetPlate(veh)) then return nil end
    if #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(veh)) > Config.Gunpoint.Distance then return nil end
    if GetEntitySpeed(veh) * 3.6 > Config.Gunpoint.MaxSpeed then return nil end
    return veh, driver
end

if Config.Gunpoint.Enabled then
    RegisterCommand('+vehkeys_aim', function()
        aimHeld = true
        local ped = PlayerPedId()
        if not LocalPlayer.state.isLoggedIn or IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) then return end
        if GetSelectedPedWeapon(ped) == `WEAPON_UNARMED` or IsBlacklistedWeapon() then return end

        CreateThread(function()
            while aimHeld do
                local veh, driver = aimTarget()
                if veh then gunpoint(veh, driver) end
                Wait(100)
            end
        end)
    end, false)
    RegisterCommand('-vehkeys_aim', function() aimHeld = false end, false)
    RegisterKeyMapping('+vehkeys_aim', 'Vehicle: gunpoint NPC driver (aim)', 'MOUSE_BUTTON', 'MOUSE_RIGHT')
end

function isBlacklistedVehicle(vehicle)
    local isBlacklisted = false
    for _,v in ipairs(Config.NoLockVehicles) do
        if GetHashKey(v) == GetEntityModel(vehicle) then
            isBlacklisted = true
            break;
        end
    end
    if Entity(vehicle).state.ignoreLocks or GetVehicleClass(vehicle) == 13 then isBlacklisted = true end
    return isBlacklisted
end

-----------------------
---- Client Events ----
-----------------------

RegisterKeyMapping('togglelocks', Lang:t("info.tlock"), 'keyboard', 'L')
RegisterCommand('togglelocks', function()
    ToggleVehicleLocks(GetVehicle())
end)

RegisterKeyMapping('engine', Lang:t("info.engine"), 'keyboard', 'G')
RegisterCommand('engine', function()
    TriggerEvent("qb-vehiclekeys:client:ToggleEngine")
end)

AddEventHandler('onResourceStart', function(resourceName)
	if resourceName == GetCurrentResourceName() and QBCore.Functions.GetPlayerData() ~= {} then
		GetKeys()
	end
end)

-- Handles state right when the player selects their character and location.
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    GetKeys()
end)

-- Resets state on logout, in case of character change.
RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    KeysList = {}
end)

RegisterNetEvent('qb-vehiclekeys:client:AddKeys', function(plate)
    KeysList[plate] = true

    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        local vehicle = GetVehiclePedIsIn(ped)
        local vehicleplate = QBCore.Functions.GetPlate(vehicle)

        -- يرجّع التشغيل التلقائي، بس ما يطفي موتر شغال (مثل لما تاخذ مفتاح سيارة موترها شغال)
        if plate == vehicleplate and not GetIsVehicleEngineRunning(vehicle) then
            SetVehicleEngineOn(vehicle, false, false, false)
        end
    end
end)

RegisterNetEvent('qb-vehiclekeys:client:RemoveKeys', function(plate)
    KeysList[plate] = nil
end)

RegisterNetEvent('qb-vehiclekeys:client:ToggleEngine', function()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)

    if vehicle ~= 0 then
        if GetPedInVehicleSeat(vehicle, -1) ~= ped then return end   -- الراكب ما يطفي موتر السواق
    else
        -- برا السيارة: بس سيارتك الأخيرة وإذا كنت قريب منها
        vehicle = GetVehiclePedIsIn(ped, true)
        if vehicle == 0 or not DoesEntityExist(vehicle) or (Config.Engine.RemoteDistance or 0) <= 0 then return end
        if GetPedInVehicleSeat(vehicle, -1) ~= 0 then return end
        if #(GetEntityCoords(ped) - GetEntityCoords(vehicle)) > Config.Engine.RemoteDistance then return end
    end

    if not HasKeys(QBCore.Functions.GetPlate(vehicle)) then return end

    if GetIsVehicleEngineRunning(vehicle) then
        local blocked, msg = EngineOffBlocked(vehicle)
        if blocked then
            if msg then QBCore.Functions.Notify(msg, 'error') end
            return
        end
        SetVehicleEngineOn(vehicle, false, false, true)
    else
        SetVehicleEngineOn(vehicle, true, false, true)
    end
end)

RegisterNetEvent('qb-vehiclekeys:client:GiveKeys', function(id)
    local targetVehicle = GetVehicle()

    if targetVehicle then
        local targetPlate = QBCore.Functions.GetPlate(targetVehicle)
        if HasKeys(targetPlate) then
            if id and type(id) == "number" then -- Give keys to specific ID
                GiveKeys(id, targetPlate)
            else
                if IsPedSittingInVehicle(PlayerPedId(), targetVehicle) then -- Give keys to everyone in vehicle
                    local otherOccupants = GetOtherPlayersInVehicle(targetVehicle)
                    for p=1,#otherOccupants do
                        TriggerServerEvent('qb-vehiclekeys:server:GiveVehicleKeys', GetPlayerServerId(NetworkGetPlayerIndexFromPed(otherOccupants[p])), targetPlate)
                    end
                else -- Give keys to closest player
                    GiveKeys(GetPlayerServerId(QBCore.Functions.GetClosestPlayer()), targetPlate)
                end
            end
        else
            QBCore.Functions.Notify(Lang:t("notify.ydhk"), 'error')
        end
    end
end)

RegisterNetEvent('vehiclekeys:client:GiveKeys', function(id)
    local targetVehicle = GetVehicle()
    if targetVehicle then
        local targetPlate = QBCore.Functions.GetPlate(targetVehicle)
        if HasKeys(targetPlate) then
            QBCore.Functions.TriggerCallback('qb-vehiclekeys:server:GetClosestPlayer', function(ClosestPlayer)
                if #ClosestPlayer > 0 then 
                    local menu = {}
                    for k, v in pairs(ClosestPlayer) do 
                        menu[#menu + 1] = {
                            header = "Give Key To:",
                            txt = "ID: "..v.id.."",
                            params = {
                                isServer = false,
                                event = "vehiclekeys:client:GiveKeysChosed",
                                args = {
                                    playerId = v.id,
                                    targetPlate = targetPlate,
                                }
                            }
                        }
                    end
                    if #menu <= 0 then 
                        return 
                    end
                    exports['qb-menu']:openMenu(menu)
                else
                    QBCore.Functions.Notify(Lang:t("notify.ydhk"), 'error')
                end
            end)
        else
            QBCore.Functions.Notify(Lang:t("notify.ydhk"), 'error')
        end
    end
end)

RegisterNetEvent('vehiclekeys:client:GiveKeysChosed', function(data)
    GiveKeys(data.playerId, data.targetPlate)
end)


RegisterNetEvent('lockpicks:UseLockpick', function(isAdvanced, slot)
    LockpickDoor(isAdvanced, slot)
end)


-- Backwards Compatibility ONLY -- Remove at some point --
RegisterNetEvent('vehiclekeys:client:SetOwner', function(plate)
    TriggerServerEvent('qb-vehiclekeys:server:AcquireVehicleKeys', plate)
end)
-- Backwards Compatibility ONLY -- Remove at some point --

-----------------------
----   Functions   ----
-----------------------

function GiveKeys(id, plate)
    local distance = #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(GetPlayerPed(GetPlayerFromServerId(id))))
    if distance < 1.5 then
        TriggerServerEvent('qb-vehiclekeys:server:GiveVehicleKeys', id, plate)
    else
        QBCore.Functions.Notify(Lang:t("notify.nonear"),'error')
    end
end

function GetKeys()
    QBCore.Functions.TriggerCallback('qb-vehiclekeys:server:GetVehicleKeys', function(keysList)
        KeysList = keysList
    end)
end

function HasKeys(plate)
    return KeysList[plate]
end
exports('HasKeys', HasKeys)

-----------------------
----  Engine rules ----
-----------------------

local G_CONTROLS = { 47, 58, 113 }

local function gKeyDown()
    for _, c in ipairs(G_CONTROLS) do
        if IsControlPressed(0, c) or IsDisabledControlPressed(0, c)
            or IsControlJustPressed(0, c) or IsDisabledControlJustPressed(0, c) then
            return true
        end
    end
    return false
end

local function isAircraft(vehicle)
    local model = GetEntityModel(vehicle)
    return IsThisModelAPlane(model) or IsThisModelAHeli(model)
end

-- يرجّع: ممنوع؟ ، الرسالة (nil = بدون رسالة)
function EngineOffBlocked(vehicle)
    local gKey = gKeyDown()
    local aircraft = isAircraft(vehicle)

    -- بالطيارة زر G = الكفرات، ما نطفي الموتر ولا نزعجه برسالة
    if gKey and aircraft and Config.Engine.DisableKeyInAircraft then return true, nil end
    -- زر G مستخدم لشي ثاني (مثل الرد على بلاغ بالتابلت)
    if gKey and LocalPlayer.state.gKeyBusy then return true, Lang:t('notify.engine_gbusy') end
    if aircraft and IsEntityInAir(vehicle) then return true, Lang:t('notify.engine_air') end
    if GetEntitySpeed(vehicle) * 3.6 >= Config.Engine.MaxOffSpeed then
        return true, Lang:t('notify.engine_speed', { speed = Config.Engine.MaxOffSpeed })
    end
    return false, nil
end

-----------------------
---- Running engine ----
-----------------------

-- ركبت سواق بسيارة موترها شغال وما عندك مفتاحها: نطلب المفتاح من السيرفر.
-- يرجّع true = خل الموتر شغال (الطلب ماشي أو انقبل)
-- تجيك المفاتيح لما تقعد سواق إذا (والسيرفر يتأكد):
--   1) الموتر شغال والأبواب مفتوحة
--   2) سيارة بوت طلعت مفتوحة (50/50 أو رفعت السلاح) ونزلته
function ClaimRunningVehicle(vehicle)
    local npcUnlocked = Entity(vehicle).state.npcLock == 'unlocked'
    local running = Config.RunningEngine.Enabled and GetIsVehicleEngineRunning(vehicle) and not isLocked(vehicle)
    if not npcUnlocked and not running then return false end

    local claim = runningClaims[vehicle]
    if claim == 'pending' or claim == 'granted' then return true end
    if claim == 'denied' then return false end
    if not NetworkGetEntityIsNetworked(vehicle) then return false end

    runningClaims[vehicle] = 'pending'
    CreateThread(function()
        Wait(750) -- نعطي السيرفر وقت يشوفك بكرسي السواق
        if GetPedInVehicleSeat(vehicle, -1) ~= PlayerPedId() then
            runningClaims[vehicle] = nil
            return
        end
        QBCore.Functions.TriggerCallback('qb-vehiclekeys:server:ClaimRunningVehicle', function(ok)
            if runningClaims[vehicle] == 'pending' then
                runningClaims[vehicle] = ok and 'granted' or 'denied'
            end
        end, NetworkGetNetworkIdFromEntity(vehicle))
    end)
    SetTimeout(6000, function()
        if runningClaims[vehicle] == 'pending' then runningClaims[vehicle] = 'denied' end
    end)
    return true
end

function loadAnimDict(dict)
    while (not HasAnimDictLoaded(dict)) do
        RequestAnimDict(dict)
        Wait(0)
    end
end

function GetVehicleInDirection(coordFromOffset, coordToOffset)
    local ped = PlayerPedId()
    local coordFrom = GetOffsetFromEntityInWorldCoords(ped, coordFromOffset.x, coordFromOffset.y, coordFromOffset.z)
    local coordTo = GetOffsetFromEntityInWorldCoords(ped, coordToOffset.x, coordToOffset.y, coordToOffset.z)

    local rayHandle = CastRayPointToPoint(coordFrom.x, coordFrom.y, coordFrom.z, coordTo.x, coordTo.y, coordTo.z, 10, PlayerPedId(), 0)
    local _, _, _, _, vehicle = GetShapeTestResult(rayHandle)
    return vehicle
end

-- If in vehicle returns that, otherwise tries 3 different raycasts to get the vehicle they are facing.
-- Raycasts picture: https://i.imgur.com/FRED0kV.png
function GetVehicle()
    local vehicle = GetVehiclePedIsIn(PlayerPedId())

    local RaycastOffsetTable = {
        { ['fromOffset'] = vector3(0.0, 0.0, 0.0), ['toOffset'] = vector3(0.0, 20.0, -10.0) }, -- Waist to ground 45 degree angle
        { ['fromOffset'] = vector3(0.0, 0.0, 0.7), ['toOffset'] = vector3(0.0, 10.0, -10.0) }, -- Head to ground 30 degree angle
        { ['fromOffset'] = vector3(0.0, 0.0, 0.7), ['toOffset'] = vector3(0.0, 10.0, -20.0) }, -- Head to ground 15 degree angle
    }

    local count = 0
    while vehicle == 0 and count < #RaycastOffsetTable do
        count = count + 1
        vehicle = GetVehicleInDirection(RaycastOffsetTable[count]['fromOffset'], RaycastOffsetTable[count]['toOffset'])
    end

    if not IsEntityAVehicle(vehicle) then vehicle = nil end
    return vehicle
end

function AreKeysJobShared(veh)
    local vehName = GetDisplayNameFromVehicleModel(GetEntityModel(veh))
    local vehPlate = QBCore.Functions.GetPlate(veh) -- كان بدون قص المسافات → يطلب المفتاح كل 100ms
    local jobName = QBCore.Functions.GetPlayerData().job.name
    local onDuty = QBCore.Functions.GetPlayerData().job.onduty
    for job, v in pairs(Config.SharedKeys) do
        if job == jobName then
	    if Config.SharedKeys[job].requireOnduty and not onDuty then return false end
	    for _, vehicle in pairs(v.vehicles) do
	        if string.upper(vehicle) == string.upper(vehName) then
		    if not HasKeys(vehPlate) then
		        TriggerServerEvent("qb-vehiclekeys:server:AcquireVehicleKeys", vehPlate)
		    end
		    return true
	        end
            end
        end
    end
    return false
end

function ToggleVehicleLocks(veh)
    if veh then
        if not isBlacklistedVehicle(veh) then
            if HasKeys(QBCore.Functions.GetPlate(veh)) or AreKeysJobShared(veh) then
                local ped = PlayerPedId()
                local vehLockStatus = GetVehicleDoorLockStatus(veh)

                loadAnimDict("anim@mp_player_intmenu@key_fob@")
                TaskPlayAnim(ped, 'anim@mp_player_intmenu@key_fob@', 'fob_click', 3.0, 3.0, -1, 49, 0, false, false, false)

                TriggerServerEvent("InteractSound_SV:PlayWithinDistance", 5, "lock", 0.3)

                NetworkRequestControlOfEntity(veh)
                if vehLockStatus <= 1 then
                    TriggerServerEvent('qb-vehiclekeys:server:setVehLockState', NetworkGetNetworkIdFromEntity(veh), 2)
                    QBCore.Functions.Notify(Lang:t("notify.vlock"), "primary")
                else
                    TriggerServerEvent('qb-vehiclekeys:server:setVehLockState', NetworkGetNetworkIdFromEntity(veh), 1)
                    QBCore.Functions.Notify(Lang:t("notify.vunlock"), "success")
                end

                SetVehicleLights(veh, 2)
                Wait(250)
                SetVehicleLights(veh, 1)
                Wait(200)
                SetVehicleLights(veh, 0)
                Wait(300)
                ClearPedTasks(ped)
            else
                QBCore.Functions.Notify(Lang:t("notify.ydhk"), 'error')
            end
        else
            TriggerServerEvent('qb-vehiclekeys:server:setVehLockState', NetworkGetNetworkIdFromEntity(veh), 1)
        end
    end
end

function GetOtherPlayersInVehicle(vehicle)
    local otherPeds = {}
    for seat=-1,GetVehicleModelNumberOfSeats(GetEntityModel(vehicle))-2 do
        local pedInSeat = GetPedInVehicleSeat(vehicle, seat)
        if IsPedAPlayer(pedInSeat) and pedInSeat ~= PlayerPedId() then
            otherPeds[#otherPeds+1] = pedInSeat
        end
    end
    return otherPeds
end

function GetPedsInVehicle(vehicle)
    local otherPeds = {}
    for seat=-1,GetVehicleModelNumberOfSeats(GetEntityModel(vehicle))-2 do
        local pedInSeat = GetPedInVehicleSeat(vehicle, seat)
        if not IsPedAPlayer(pedInSeat) and pedInSeat ~= 0 then
            otherPeds[#otherPeds+1] = pedInSeat
        end
    end
    return otherPeds
end

function IsBlacklistedWeapon()
    local weapon = GetSelectedPedWeapon(PlayerPedId())
    if weapon ~= nil then
        for _, v in pairs(Config.NoCarjackWeapons) do
            if weapon == GetHashKey(v) then
                return true
            end
        end
    end
    return false
end

function LockpickDoor(isAdvanced, slot)
    if not slot then return end
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local vehicle = QBCore.Functions.GetClosestVehicle()

    if vehicle == nil or vehicle == 0 then return end
    if HasKeys(QBCore.Functions.GetPlate(vehicle)) then return end
    if #(pos - GetEntityCoords(vehicle)) > 2.5 then return end
    if GetVehicleDoorLockStatus(vehicle) <= 0 then return end

    if vehicle ~= 0 then 

        SetVehicleAlarm(vehicle, true)
        SetVehicleAlarmTimeLeft(vehicle, 6000)
        TriggerServerEvent('smallresources:server:lockPickHealth', slot)
        -- local success = exports['qb-ui']:StartLockPickCircle(circles, seconds, success)
        local ok, success = pcall(function() return exports["2na_lockpick"]:createGame(3, 1) end)
        if not ok then
            return Config.LockPickDoorEvent() -- 2na_lockpick مو موجود → qb-lockpick
        end
        if success then
            SetVehicleAlarm(vehicle, false)
            LockpickFinishCallback(success)
        end
    end
end

function LockpickFinishCallback(success)
    local vehicle = QBCore.Functions.GetClosestVehicle()
    TriggerServerEvent('hud:server:GainStress', math.random(3, 6))
    if not success or not vehicle or vehicle == 0 then return end

    -- السيرفر يتأكد إن القفال معك وأنك جنبها (سواق = مفتاح، برا = تنفتح)
    TriggerServerEvent('qb-vehiclekeys:server:LockpickSuccess', NetworkGetNetworkIdFromEntity(vehicle))
    if GetPedInVehicleSeat(vehicle, -1) ~= PlayerPedId() then
        QBCore.Functions.Notify(Lang:t("notify.vlockpick"), 'success')
    end
end
