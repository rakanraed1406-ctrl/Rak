
local pauseMenuActive = false
local lastHudPayload  = {}
local lastVehPayload  = {}
local lastNavPayload  = {}
local hudLoaded       = false   -- cached playerLoaded(), refreshed by the slow loop below
local hudStarting     = false
local mainRunning     = false
local atan2           = math.atan2 or math.atan


-- Waypoint helpers for the street block
local function GetWaypointCoords()
    local waypointBlip = GetFirstBlipInfoId(8)
    if DoesBlipExist(waypointBlip) then
        return GetBlipInfoIdCoord(waypointBlip)
    end
    return nil
end

-- compass bearing from the player to the waypoint: 0 = north, 90 = east (clockwise)
local function GetWaypointCompassBearing(pedCoords, wp)
    local angle = math.deg(atan2(wp.y - pedCoords.y, wp.x - pedCoords.x))   -- 0 = east, counter-clockwise
    return math.floor((90 - angle) % 360 + 0.5) % 360
end

local function NativeFlag(v)
    return v == true or v == 1
end

-- compass is shown on foot too unless Config.Settings.Compass.onlyInVehicle
local compassVisible = false
local function CompassWanted()
    local c = Config.Settings.Compass
    if not hudLoaded or not c or not c.active then return false end
    if Koci.Client.HUD.data.compass.show == false then return false end
    if (c.onlyInVehicle or Koci.Client.HUD.data.compass.onlyInVehicle) and not Koci.Client.HUD.data.vehicle.inVehicle then
        return false
    end
    return true
end

-- config.lua values the NUI needs (also returned by the "hudReady" NUI callback)
function Koci.Client.HUD:GetNuiConfig()
    local bars = {}
    for name, opt in pairs(Config.Settings.StatusBars or {}) do
        bars[name] = (type(opt) == "table" and opt.active) and true or false
    end
    local ui = Config.Interface or {}
    return {
        action        = "config",
        bars          = bars,
        kmH           = Config.Settings.VehicleHUD.kmH ~= false,
        smooth        = ui.smoothAnimations ~= false,
        watermark     = ui.watermark ~= false,
        watermarkText = ui.watermarkText,
        clockSeconds  = ui.clockSeconds ~= false,
    }
end


function Koci.Client.HUD:Start()
    -- onResourceStart and OnPlayerLoaded can both call this; only one start may run
    if hudStarting then return end
    hudStarting = true
    CreateThread(function()
        while not playerLoaded() do Wait(500) end
        Wait(500)
        hudStarting = false
        hudLoaded   = true

        if not mainRunning then self:MainThick() end
        self.data.vehicle.kmH = Config.Settings.VehicleHUD.kmH
        SendNUIMessage(self:GetNuiConfig())

        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        if veh ~= 0 and not IsThisModelABicycle(GetEntityModel(veh)) then
            if not self.data.vehicle.inVehicle then
                self.data.vehicle.inVehicle  = true
                self.data.vehicle.entity     = veh
                self.data.vehicle.fuel.type  = self:CheckVehicleFuelType(GetEntityModel(veh))
                self:ActivateVehicleHud(veh)
            end
            DisplayRadar(true)
        else
            DisplayRadar(self.data.vehicle.miniMap.alwaysActive)
        end

        -- SetMiniMap في thread منفصل حتى لا تعطّل الكود
        CreateThread(function()
            self:SetMiniMap(self.data.vehicle.miniMap.style)
        end)

        -- show the HUD; the main loop sends the real values on its next tick
        self.data.isVisible = true
        lastHudPayload = {}
        SendNUIMessage({ action = "hud", show = true })
    end)
end

function Koci.Client.HUD:Toggle(state)
    if state == nil then
        self.data.isVisible = not self.data.isVisible
    else
        self.data.isVisible = state
    end
    if self.data.isVisible then
        -- no placeholder values (they used to flash full health); the main loop resends real ones
        lastHudPayload = {}
        SendNUIMessage({ action = "hud", show = true })
    else
        SendNUIMessage({ action = "hideHud", show = false })
    end
end

exports("ToggleVisible", function(state)
    Koci.Client.HUD:Toggle(state)
end)

--- ──────────────────────────────────────────────────────────
--  Minimap
-- ──────────────────────────────────────────────────────────
CreateThread(function()
    while true do
        hudLoaded = playerLoaded() and true or false
        SetRadarBigmapEnabled(false, false)
        SetRadarZoom(1000)
        -- minimap only in vehicles (unless alwaysActive / cinematic)
        if hudLoaded
            and not Koci.Client.HUD.data.vehicle.inVehicle
            and not Koci.Client.HUD.data.vehicle.miniMap.alwaysActive
            and not Koci.Client.HUD.data.isCinematicHudActive
            and GetVehiclePedIsIn(PlayerPedId(), false) == 0 then
            DisplayRadar(false)
        end
        Wait(500)
    end
end)

function Koci.Client.HUD:SetMiniMap(_type)
    Wait(500)
    local resX, resY = GetActiveScreenResolution()

    if _type == "square" then
        local mx    = -35.0  / resX
        local my    = -47.76 / resY
        local mw    = 314.5  / resX
        local mh    = 197.6  / resY
        local maskX = -35.0  / resX
        local maskY =   0.0  / resY
        local maskW = 245.8  / resX
        local maskH = 216.0  / resY
        local blurX = -35.0  / resX
        local blurY =  27.0  / resY
        local blurW = 503.0  / resX
        local blurH = 324.0  / resY

        RequestStreamedTextureDict("squaremap", false)
        while not HasStreamedTextureDictLoaded("squaremap") do Wait(150) end
        SetMinimapClipType(0)
        AddReplaceTexture("platform:/textures/graphics", "radarmasksm", "squaremap", "radarmasksm")
        AddReplaceTexture("platform:/textures/graphics", "radarmask1g", "squaremap", "radarmasksm")
        SetMinimapComponentPosition("minimap",      "L", "B", mx,    my,    mw,    mh)
        SetMinimapComponentPosition("minimap_mask", "L", "B", maskX, maskY, maskW, maskH)
        SetMinimapComponentPosition("minimap_blur", "L", "B", blurX, blurY, blurW, blurH)
        SetBlipAlpha(GetNorthRadarBlip(), 0)
        SetRadarBigmapEnabled(true, false)
        SetMinimapClipType(0)
        Wait(50)
        SetRadarBigmapEnabled(false, false)
        -- send minimap rect in actual pixels so NUI box matches exactly
        local sz      = GetSafeZoneSize()
        local szOffX  = (1.0 - sz) * resX * 0.5
        local szOffY  = (1.0 - sz) * resY * 0.5
        SendNUIMessage({
            action = "setMapFrame",
            x      = mx * resX + szOffX,
            y      = my * resY + szOffY,
            width  = mw * resX,
            height = mh * resY,
            resX   = resX,
            resY   = resY,
        })

    elseif _type == "circle" then
        local mx    = -19.2  / resX
        local my    = -32.4  / resY
        local mw    = 345.6  / resX
        local mh    = 278.6  / resY
        local maskX = 384.0  / resX
        local maskY =   0.0  / resY
        local maskW = 124.8  / resX
        local maskH = 216.0  / resY
        local blurX =   0.0  / resX
        local blurY =  16.2  / resY
        local blurW = 483.8  / resX
        local blurH = 365.0  / resY

        RequestStreamedTextureDict("circlemap", false)
        while not HasStreamedTextureDictLoaded("circlemap") do Wait(150) end
        SetMinimapClipType(1)
        AddReplaceTexture("platform:/textures/graphics", "radarmasksm", "circlemap", "radarmasksm")
        AddReplaceTexture("platform:/textures/graphics", "radarmask1g", "circlemap", "radarmasksm")
        SetMinimapComponentPosition("minimap",      "L", "B", mx,    my,    mw,    mh)
        SetMinimapComponentPosition("minimap_mask", "L", "B", maskX, maskY, maskW, maskH)
        SetMinimapComponentPosition("minimap_blur", "L", "B", blurX, blurY, blurW, blurH)
        SetBlipAlpha(GetNorthRadarBlip(), 0)
        SetMinimapClipType(1)
        SetRadarBigmapEnabled(true, false)
        Wait(50)
        SetRadarBigmapEnabled(false, false)
    end
end

-- ──────────────────────────────────────────────────────────
--  Main Thick (player stats loop)
-- ──────────────────────────────────────────────────────────
local lastClock       = {}

local function DeepEqual(a, b)
    if a == b then return true end
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return false end
    for k, v in pairs(a) do if not DeepEqual(v, b[k]) then return false end end
    for k in pairs(b)    do if a[k] == nil then return false end end
    return true
end

function Koci.Client.HUD:MainThick()
    mainRunning = true
    CreateThread(function()
        while playerLoaded() do
            local playerId   = PlayerId()
            local playerPedId = PlayerPedId()

            -- ── voice ──
            local radio = Koci.Client.HUD.data.bars.voice.radio or false
            local range = Koci.Client.HUD.data.bars.voice.range or 3.0
            local isTalking = false

            -- راديو له أولوية — لما يكون الراديو مفعل ما نبي يطلع تكلم عادي
            if radio then
                -- راديو نشط: أطفي isTalking كلياً
                isTalking = false
            else
                -- ما في راديو: اعتمد على event من pma-voice أو NetworkIsPlayerTalking
                isTalking = Koci.Client.HUD.data.bars.voice.isTalking
                            or NetworkIsPlayerTalking(playerId)
            end

            -- proximity range من pma-voice
            local prox = LocalPlayer.state["proximity"]
            if prox then
                if type(prox) == "number" then
                    range = prox
                elseif type(prox) == "table" and prox.distance then
                    range = prox.distance
                end
            end

            -- ── oxygen / stamina ──
            local inWater   = IsEntityInWater(playerPedId)
            local isRunning = IsPedSprinting(playerPedId) or IsPedRunning(playerPedId)
            local oxygenVal
            if inWater then
                -- تحت الماء: أكسجين (مثل الأصل)
                oxygenVal = math.min(math.floor(GetPlayerUnderwaterTimeRemaining(playerId) * 10.0 + 0.5), 100)
            else
                -- GetPlayerSprintStaminaRemaining ترجع:
                --   0   = ستامينا فل (واقف/راحد)
                --   100 = ستامينا فاضية (بعد ركض كثير)
                -- نعكسها عشان: 100=فل hex، 0=فاضي hex
                local rawStamina = GetPlayerSprintStaminaRemaining(playerId)
                oxygenVal = math.floor(100 - rawStamina + 0.5)
            end

            -- ── health / armor ──
            local maxHp    = GetEntityMaxHealth(playerPedId) - 100
            local health   = math.floor((GetEntityHealth(playerPedId) - 100) / (maxHp > 0 and maxHp or 100) * 100)
            health = math.max(0, math.min(100, health))
            local armor    = math.max(0, GetPedArmour(playerPedId))
            local dead     = IsEntityDead(playerPedId) or false



            -- ── pause ──
            local paused = IsPauseMenuActive()
            if paused and not pauseMenuActive then
                pauseMenuActive = true
                if self.data.isVisible then self:Toggle(false) end
            elseif not paused and pauseMenuActive then
                pauseMenuActive = false
                if not self.data.isVisible then self:Toggle(true) end
            end

            -- ── build payload ──
            local payload = {
                action     = "hud",
                show       = not paused,
                voice      = { talking = isTalking, range = range, radio = radio },
                health     = health,
                armor      = armor,
                playerDead = dead,
                hunger     = self.data.bars.hunger  or 100,
                thirst     = self.data.bars.thirst  or 100,
                stress     = self.data.bars.stress  or 0,
                oxygen     = { range = oxygenVal, inwater = inWater, running = isRunning },
            }

            if not DeepEqual(payload, lastHudPayload) then
                SendNUIMessage(payload)
                lastHudPayload = payload
            end

            -- ── vehicle ──
            local vehicle = GetVehiclePedIsIn(playerPedId, false)
            if Config.Settings.VehicleHUD.active then
                if vehicle ~= 0 and (not self.data.vehicle.inVehicle or vehicle ~= self.data.vehicle.entity) then
                    if not IsThisModelABicycle(GetEntityModel(vehicle)) then
                        lastVehPayload = {}
                        lastNavPayload = {}
                        self.data.vehicle.inVehicle    = true
                        self.data.vehicle.entity       = vehicle
                        self.data.vehicle.isSeatbeltOn = false  -- غير مربوط عند دخول السيارة
                        self.data.vehicle.fuel.type    = self:CheckVehicleFuelType(GetEntityModel(vehicle))
                        self:ActivateVehicleHud(vehicle)
                        -- نظهر الخريطة لما ندخل السيارة
                        if not self.data.isCinematicHudActive then
                            DisplayRadar(true)
                        end
                    end
                elseif vehicle == 0 and self.data.vehicle.inVehicle then
                    self.data.vehicle.inVehicle         = false
                    self.data.vehicle.entity            = nil
                    self.data.vehicle.isPassenger       = false
                    self.data.vehicle.show              = false
                    self.data.vehicle.isSeatbeltOn      = false  -- رجّع للافتراضي
                    self.data.vehicle.cruiseControlStatus = false
                    self.data.vehicle._lastEntitySpeed  = 0
                    lastVehPayload = {}
                    lastNavPayload = {}
                    -- نخفي الخريطة لما نطلع من السيارة
                    if not self.data.isCinematicHudActive then
                        DisplayRadar(false)
                    end
                    SendNUIMessage({ action = "vehHideHud", showveh = false })
                end
            end

            -- (accounts + clock handled in dedicated threads)

            Wait(200)
        end
        mainRunning = false
    end)
end

-- ──────────────────────────────────────────────────────────
--  Clock thread (runs every 30 s — no server round-trip)
-- ──────────────────────────────────────────────────────────
local monthNames = {
    "JANUARY","FEBRUARY","MARCH","APRIL","MAY","JUNE",
    "JULY","AUGUST","SEPTEMBER","OCTOBER","NOVEMBER","DECEMBER"
}

CreateThread(function()
    while true do
        if playerLoaded() then
            local offset = Config.ClockOffset or 0
            local rawH   = GetClockHours()
            local h      = (rawH + offset) % 24
            local m      = GetClockMinutes()
            local ampm   = h >= 12 and "PM" or "AM"
            local h12    = h % 12
            if h12 == 0 then h12 = 12 end

            local mon  = GetClockMonth()        -- 0-based in some builds, 1-based in others
            if mon == 0 then mon = 1 end        -- safety clamp
            local day  = GetClockDayOfMonth()
            local year = GetClockYear()

            local timeStr = string.format("%02d:%02d%s", h12, m, ampm)
            local dateStr = string.format("%s %d, %d",
                monthNames[math.max(1, math.min(12, mon))], day, year)

            if timeStr ~= lastClock.time or dateStr ~= lastClock.date then
                lastClock = { time = timeStr, date = dateStr }
                SendNUIMessage({ action = "SetClock", time = timeStr, date = dateStr })
            end
        end
        Wait(30000)
    end
end)

-- ──────────────────────────────────────────────────────────
--  Vehicle thick (speed / rpm / fuel)
-- ──────────────────────────────────────────────────────────
function Koci.Client.HUD:ActivateVehicleHud(veh)
    self.data.vehicle.show = true
    self:fVehicleInfoThick(veh)
    self:LowFuelThread(veh)
end

function Koci.Client.HUD:fVehicleInfoThick(vehicle)
    CreateThread(function()
        local maxGear = GetVehicleHighGear(vehicle)
        if not maxGear or maxGear < 1 then maxGear = 6 end
        while self.data.vehicle.inVehicle and self.data.vehicle.entity == vehicle and DoesEntityExist(vehicle) do
            local ped          = PlayerPedId()
            self.data.vehicle.isPassenger = GetPedInVehicleSeat(vehicle, -1) ~= ped

            local kmH          = self.data.vehicle.kmH
            local currentSpeed = GetEntitySpeed(vehicle)
            local speed        = math.floor(currentSpeed * (kmH and 3.6 or 2.237))

            self:SeatBeltLogic(vehicle, currentSpeed)

            local engineRunning = GetIsVehicleEngineRunning(vehicle)
            local rpm           = engineRunning and GetVehicleCurrentRpm(vehicle) or 0
            local gear          = engineRunning and GetVehicleCurrentGear(vehicle) or 0
            if gear == 0 then gear = "R" end

            local engineHealth = math.max(0, math.floor(GetVehicleEngineHealth(vehicle)))
            local _, lowBeam, highBeam = GetVehicleLightsState(vehicle)
            local lights = NativeFlag(highBeam) and 2 or NativeFlag(lowBeam) and 1 or 0

            -- aircraft?
            local vehClass   = GetVehicleClass(vehicle)
            local isAircraft = (vehClass == 15 or vehClass == 16)
            local altitude   = isAircraft and GetEntityCoords(ped).z or 0

            -- 0..100; rounded so an idling engine doesn't send a message every tick
            local rpmMat = math.max(0, math.floor((rpm * 10000 - 2001) / 80 + 0.5))

            local fuelLevel = tonumber(self:GetFuelExport()) or GetVehicleFuelLevel(vehicle)

            -- no belt warning where a belt can't be worn (bikes, boats, aircraft...)
            local beltWarning = not self.data.vehicle.isSeatbeltOn
                and not isAircraft
                and not Config.SeatBeltBlackListVehicles[vehClass]

            local payload = {
                action     = "vehHud",
                showveh    = true,
                speed      = speed,
                rpm        = rpmMat,
                gear       = gear,
                fuel       = math.floor(fuelLevel + 0.5),
                engineHp   = engineHealth,
                bodyHp     = math.max(0, math.floor(GetVehicleBodyHealth(vehicle))),
                seatbelt   = beltWarning,
                belted     = self.data.vehicle.isSeatbeltOn and true or false,
                cruise     = self.data.vehicle.cruiseControlStatus and true or false,
                electric   = self.data.vehicle.fuel.type == "electric",
                engineOn   = engineRunning and true or false,
                maxGear    = maxGear,
                locked     = GetVehicleDoorLockStatus(vehicle) > 1,
                lights     = lights,
                handbrake  = GetVehicleHandbrake(vehicle) and true or false,
                ind        = GetVehicleIndicatorLights(vehicle) or 0,
                isAircraft = isAircraft,
                altitude   = math.floor(altitude),
            }

            if not DeepEqual(payload, lastVehPayload) then
                SendNUIMessage(payload)
                lastVehPayload = payload
            end

            Wait(self.data.vehicle.thick.wait)
        end
    end)
end

-- ──────────────────────────────────────────────────────────
--  Navigation loop
-- ──────────────────────────────────────────────────────────
CreateThread(function()
    while true do
        local waitMs = 1000
        if hudLoaded and (Koci.Client.HUD.data.vehicle.inVehicle or compassVisible) then
            local ped       = PlayerPedId()
            local pedCoords = GetEntityCoords(ped)

            local currentStreetHash, intersectStreetHash = GetStreetNameAtCoord(pedCoords.x, pedCoords.y, pedCoords.z)
            local streetName = GetStreetNameFromHashKey(currentStreetHash)
            local crossing   = (intersectStreetHash and intersectStreetHash ~= 0) and GetStreetNameFromHashKey(intersectStreetHash) or ""
            if crossing == streetName then crossing = "" end
            local area       = GetLabelText(GetNameOfZone(pedCoords.x, pedCoords.y, pedCoords.z))

            -- نفس اختصارات Sx-HUD للأماكن الطويلة
            if area == "Fort Zancudo" then
                area = "Williamsburg"
            elseif area == "Downtown Vinewood" then
                area = "D.T Vinewood"
            elseif area == "Grand Senora Desert" then
                area = "G.S Desert"
            elseif area == "San Chianski Mountain Range" then
                area = "San Chianski FR"
            end

            local data = {
                action   = "updateNav",
                area     = area,
                street   = streetName,
                crossing = crossing,
                waydist  = -1,
            }

            local blipCoords = GetWaypointCoords()
            if blipCoords then
                -- km rounded to 10 m, bearing to 1°, so small wobbles don't resend
                local dist = #(vector2(pedCoords.x, pedCoords.y) - vector2(blipCoords.x, blipCoords.y)) / 1000
                data.waydist   = math.floor(dist * 100 + 0.5) / 100
                data.wpBearing = GetWaypointCompassBearing(pedCoords, blipCoords)
                waitMs = 600
            else
                waitMs = 1000
            end

            if not DeepEqual(data, lastNavPayload) then
                SendNUIMessage(data)
                lastNavPayload = data
            end
        end
        Wait(waitMs)
    end
end)

-- ──────────────────────────────────────────────────────────
--  Compass (top centre): camera heading, sent only when it changes by a degree
-- ──────────────────────────────────────────────────────────
CreateThread(function()
    local lastDeg = -1
    while true do
        local waitMs = 500
        local want = CompassWanted()
        if want ~= compassVisible then
            compassVisible = want
            lastDeg = -1
            lastNavPayload = {}
            SendNUIMessage({ action = "compassShow", show = want })
        end
        if want then
            local rot = GetGameplayCamRot(0)
            local deg = math.floor((360.0 - rot.z) % 360.0 + 0.5) % 360   -- 0 = north, clockwise
            if deg ~= lastDeg then
                lastDeg = deg
                SendNUIMessage({ action = "compass", h = deg })
            end
            waitMs = 100
        end
        Wait(waitMs)
    end
end)

-- ──────────────────────────────────────────────────────────
--  Accounts
-- ──────────────────────────────────────────────────────────
function Koci.Client.HUD:UpdateAccounts(serverId)
    if not Config.Settings.AccountHud.active then return end
    self.data.account.playerServerId = serverId
    local xPlayer = Koci.Client:GetPlayerData() or {}
    self.data.account.playerBalance.bank = (xPlayer.money and xPlayer.money["bank"]) or 0
    self.data.account.playerBalance.cash = (xPlayer.money and xPlayer.money["cash"]) or 0
end

-- ──────────────────────────────────────────────────────────
--  Fuel
-- ──────────────────────────────────────────────────────────
local FUEL_RESOURCES = { "ox_fuel", "cdn-fuel", "ps-fuel", "frkn-fuelstationv3" }
local fuelProvider, fuelProviderAt = false, nil

local function GetFuelProvider()
    local now = GetGameTimer()
    if not fuelProviderAt or now - fuelProviderAt > 10000 then
        fuelProviderAt = now
        fuelProvider = false
        for i = 1, #FUEL_RESOURCES do
            if Utils.Functions:hasResource(FUEL_RESOURCES[i]) then
                fuelProvider = FUEL_RESOURCES[i]
                break
            end
        end
    end
    return fuelProvider
end

function Koci.Client.HUD:GetFuelExport()
    local veh = self.data.vehicle.entity
    if not veh or not DoesEntityExist(veh) then return nil end

    local provider = GetFuelProvider()
    if provider == "ox_fuel" then
        local state = Entity(veh).state
        return state and state.fuel or nil
    elseif provider then
        return exports[provider]:GetFuel(veh)
    end
    return Utils.Functions:CustomFuelExport(veh)
end

-- ──────────────────────────────────────────────────────────
--  Vehicle helpers
-- ──────────────────────────────────────────────────────────
function Koci.Client.HUD:CheckVehicleFuelType(vehicle)
    for _, v in pairs(Config.ElectricVehicles) do
        if vehicle == GetHashKey(v) then return "electric" end
    end
    return "gasoline"
end

function Koci.Client.HUD:UpdateVehicleHud(data)
    if not data then return end
    if data.miniMap then
        if self.data.vehicle.miniMap.style ~= data.miniMap.style then
            self.data.vehicle.miniMap.style = data.miniMap.style
            self:SetMiniMap(data.miniMap.style)
        end
        if data.miniMap.alwaysActive ~= nil and self.data.vehicle.miniMap.alwaysActive ~= data.miniMap.alwaysActive then
            self.data.vehicle.miniMap.alwaysActive = data.miniMap.alwaysActive
            DisplayRadar(data.miniMap.alwaysActive)
        end
    end
    if data.speedoMeter and data.speedoMeter.fps ~= self.data.vehicle.speedoMeter.fps then
        self.data.vehicle.speedoMeter.fps = data.speedoMeter.fps
        local fps = data.speedoMeter.fps
        self.data.vehicle.thick.wait = fps == 60 and 100 or fps == 30 and 150 or 200
    end
end

function Koci.Client.HUD:UpdateCompassHud(data)
    if not data then return end
    if data.onlyInVehicle ~= nil then self.data.compass.onlyInVehicle = data.onlyInVehicle end
    if data.show          ~= nil then self.data.compass.show          = data.show          end
end

-- ──────────────────────────────────────────────────────────
--  Seatbelt
-- ──────────────────────────────────────────────────────────
function Koci.Client.HUD:ToggleSeatBelt(state)
    if not self.data.vehicle.inVehicle then return end
    local class = GetVehicleClass(self.data.vehicle.entity)
    if class == 8 or class == 13 or class == 14 then return end

    self.data.vehicle.isSeatbeltOn = not self.data.vehicle.isSeatbeltOn

    Koci.Client:SendNotify(
        self.data.vehicle.isSeatbeltOn and _t("notify.seatbeltOn") or _t("notify.seatbeltOff")
    )

    if self.data.vehicle.isSeatbeltOn then
        self:VehicleSeatBeltThick()
    end
end

function Koci.Client.HUD:VehicleSeatBeltThick()
    if not Config.Settings.Seatbelt.active then return end
    CreateThread(function()
        while self.data.vehicle.inVehicle and self.data.vehicle.isSeatbeltOn do
            DisableControlAction(0, 75, true)
            Wait(1)
        end
    end)
end

-- ──────────────────────────────────────────────────────────
--  Seatbelt eject logic
-- ──────────────────────────────────────────────────────────
function Koci.Client.HUD:EjectSeat()
    local ped    = PlayerPedId()
    local veh    = GetVehiclePedIsIn(ped, false)
    local coords = GetOffsetFromEntityInWorldCoords(veh, 1.0, 0.0, 1.0)
    SetEntityCoords(ped, coords.x, coords.y, coords.z, true, true, true, false)
    Wait(1)
    SetPedToRagdoll(ped, 1000, 1000, 0, false, false, false)
    SetEntityVelocity(ped,
        self.data.vehicle.previousVelocity.x,
        self.data.vehicle.previousVelocity.y,
        self.data.vehicle.previousVelocity.z)
end

function Koci.Client.HUD:SeatBeltLogic(vehicle, currentSpeed)
    if not Config.Settings.Seatbelt.active then return end
    if self.data.vehicle.inVehicle and not self.data.vehicle.isSeatbeltOn then
        local vehClass = GetVehicleClass(vehicle)
        if Config.SeatBeltBlackListVehicles[vehClass] or not Config.SeatBeltBlackListVehicles[vehClass] then
            self.data.vehicle.isSeatbeltOn = true
            return
        end

        local currentBodyHealth = GetVehicleBodyHealth(vehicle)
        local ped = PlayerPedId()
        local prevSpeed       = self.data.vehicle._lastEntitySpeed or 0
        local prevBodyHealth  = self.data.vehicle._lastBodyHealth  or 0
        SetPedConfigFlag(ped, 32, true)

        local isVehMovingFwd  = GetEntitySpeedVector(vehicle, true).y > 1.0
        local vehAcceleration = (prevSpeed - currentSpeed) / GetFrameTime()
        local speedIsBigger   = prevSpeed > (60 / 2.237)
        local reallyFast      = vehAcceleration > 981
        local frameBodyChange = prevBodyHealth - currentBodyHealth
        local isDamaged       = currentBodyHealth < 1000 and frameBodyChange > 18.0

        if isVehMovingFwd and speedIsBigger and reallyFast and isDamaged then
            self:EjectSeat()
        else
            self.data.vehicle.previousVelocity = GetEntityVelocity(vehicle)
        end
        self.data.vehicle._lastEntitySpeed = currentSpeed
        self.data.vehicle._lastBodyHealth  = currentBodyHealth
    end
end

-- ──────────────────────────────────────────────────────────
--  Cruise Control
-- ──────────────────────────────────────────────────────────
function Koci.Client.HUD:VehicleCruiseControlThick()
    if not Config.Settings.CruiseControl.active then return end
    local veh   = self.data.vehicle.entity
    local speed = GetEntitySpeed(veh)
    if self.data.vehicle.cruiseControlStatus then
        self.data.vehicle.cruiseControlStatus = false
        Koci.Client:SendNotify(_t("notify.cruiseControlOff"))
        return
    end
    if speed > 0 and GetVehicleCurrentGear(veh) > 0 then
        self.data.vehicle.cruiseControlStatus = true
        Koci.Client:SendNotify(_t("notify.cruiseControlOn"))
        CreateThread(function()
            while self.data.vehicle.inVehicle and speed > 0
                and not self.data.vehicle.isPassenger
                and self.data.vehicle.cruiseControlStatus do
                Wait(0)
                local turning = IsControlPressed(2, 76) or IsControlPressed(2, 63) or IsControlPressed(2, 64)
                if not turning and GetEntitySpeed(veh) < speed - 1.5 then
                    speed = 0; self.data.vehicle.cruiseControlStatus = false
                    Wait(2000); Koci.Client:SendNotify(_t("notify.cruiseControlOff")); break
                end
                if not turning and IsVehicleOnAllWheels(veh) and GetEntitySpeed(veh) < speed then
                    SetVehicleForwardSpeed(veh, speed)
                end
                if IsControlJustPressed(2, 72) then
                    speed = 0; self.data.vehicle.cruiseControlStatus = false
                    Wait(2000); Koci.Client:SendNotify(_t("notify.cruiseControlOff")); break
                end
            end
        end)
    end
end

-- ──────────────────────────────────────────────────────────
--  Low fuel notification
-- ──────────────────────────────────────────────────────────
function Koci.Client.HUD:LowFuelThread(vehicle)
    if not Config.Settings.VehicleHUD.lowFuelNotify then return end
    CreateThread(function()
        while self.data.vehicle.inVehicle and self.data.vehicle.entity == vehicle and DoesEntityExist(vehicle) do
            local ped = PlayerPedId()
            if playerLoaded() and IsPedInAnyVehicle(ped, false) then
                local fuel = self:GetFuelExport()
                if fuel and fuel <= 5 then
                    Koci.Client:SendNotify(_t("notify.low_fuel"), "error")
                    Wait(60000)
                end
            end
            Wait(10000)
        end
    end)
end

-- ──────────────────────────────────────────────────────────
--  Stress effects
-- ──────────────────────────────────────────────────────────
-- Removed stress effects loop

-- ──────────────────────────────────────────────────────────
--  Speed stress loop
-- ──────────────────────────────────────────────────────────
-- Removed speed stress loop

-- ──────────────────────────────────────────────────────────
--  Shooting stress loop
-- ──────────────────────────────────────────────────────────
-- Removed shooting stress loop

-- ──────────────────────────────────────────────────────────
--  Ammo display + HUD component hider
-- ──────────────────────────────────────────────────────────
local OxItems      = nil
local CurrentWeapon = nil

AddEventHandler("ox_inventory:currentWeapon", function(w)
    CurrentWeapon = w
end)

CreateThread(function()
    while GetResourceState("ox_inventory") ~= "started" do Wait(1000) end
    local ok, items = pcall(function() return exports.ox_inventory:Items() end)
    if ok and type(items) == "table" then OxItems = items end
end)

local reserveCache = { weapon = nil, clip = -1, value = 0, at = 0 }

local function GetOxReserve(weaponName, ammoItem, clip)
    local c, now = reserveCache, GetGameTimer()
    if c.weapon ~= weaponName or clip > c.clip or now - c.at > 1500 then
        c.weapon, c.at = weaponName, now
        c.value = exports.ox_inventory:Search("count", ammoItem) or 0
    end
    c.clip = clip
    return c.value
end

local function GetAmmoState()
    local ped = PlayerPedId()
    if not IsPedArmed(ped, 6) then return { show = false, clip = 0, reserve = 0 } end

    local weaponHash = GetSelectedPedWeapon(ped)
    local _, clip    = GetAmmoInClip(ped, weaponHash)

    if GetResourceState("ox_inventory") ~= "started" then
        local total = GetAmmoInPedWeapon(ped, weaponHash)
        return { show = true, clip = clip, reserve = math.max(0, total - clip) }
    end

    if not CurrentWeapon or not CurrentWeapon.name then
        return { show = true, clip = clip, reserve = 0 }
    end

    local itemData = OxItems and OxItems[CurrentWeapon.name] or nil
    if not itemData then return { show = true, clip = clip, reserve = 0 } end

    local ammoItem = itemData.ammoname or itemData.ammo or itemData.ammoName
    if not ammoItem or ammoItem == "" then return { show = true, clip = clip, reserve = 0 } end

    return { show = true, clip = clip, reserve = GetOxReserve(CurrentWeapon.name, ammoItem, clip) }
end



-- يخفي HUD الأصلي لـ GTA كل فريم حتى لا يظهر بين الفريمات
-- (the only per-frame loop: constant list, no table built per frame, no state-bag read per frame)
local HIDDEN_COMPONENTS = { 1, 2, 3, 4, 6, 7, 8, 9, 13, 20, 21 }   -- 21 = health/armour bars near minimap
CreateThread(function()
    local list, count = HIDDEN_COMPONENTS, #HIDDEN_COMPONENTS
    while true do
        if hudLoaded then
            for i = 1, count do HideHudComponentThisFrame(list[i]) end
            DisplayAmmoThisFrame(false)
        else
            HideHudComponentThisFrame(3)    -- CASH
            HideHudComponentThisFrame(4)    -- MP_CASH
            HideHudComponentThisFrame(13)   -- CASH_CHANGE
        end
        Wait(0)
    end
end)

CreateThread(function()
    local lastAmmo = {}
    while true do
        local waitMs = 400
        if hudLoaded then
            SetWeaponsNoAutoswap(true)

            local state = GetAmmoState()
            if lastAmmo.show ~= state.show or lastAmmo.clip ~= state.clip or lastAmmo.reserve ~= state.reserve then
                SendNUIMessage({ action = "updateAmmo", data = state })
                lastAmmo = state
            end
            waitMs = state.show and 150 or 280
        end
        Wait(waitMs)
    end
end)

-- ──────────────────────────────────────────────────────────
--  /hudt - show all HUD status boxes for 10 seconds
-- ──────────────────────────────────────────────────────────
local hudtToken = 0
RegisterCommand('hudt', function()
    hudtToken = hudtToken + 1
    local token = hudtToken

    SendNUIMessage({ action = 'showAllStats', show = true })

    CreateThread(function()
        Wait(10000)
        if token == hudtToken then
            SendNUIMessage({ action = 'showAllStats', show = false })
        end
    end)
end, false)

