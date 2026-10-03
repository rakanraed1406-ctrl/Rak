

-- ──────────────────────────────────────────────────────────
--  Resource start
-- ──────────────────────────────────────────────────────────
AddEventHandler("onResourceStart", function(resource)
    if resource ~= GetCurrentResourceName() then return end
    Wait(1000)
    Koci.Client.HUD:Start()
end)

SetRadioToStationName("OFF")
SetUserRadioControlEnabled(false)
-- ──────────────────────────────────────────────────────────
--  Resource stop — نظّف كل شي لما السكربت يوقف
-- ──────────────────────────────────────────────────────────
AddEventHandler("onResourceStop", function(resource)
    if resource ~= GetCurrentResourceName() then return end
    DisplayRadar(false)
    -- أرجع الـ minimap لموضعه الافتراضي
    SetMinimapComponentPosition("minimap",      "L", "B", 0.0, 0.0, 0.0, 0.0)
    SetMinimapComponentPosition("minimap_mask", "L", "B", 0.0, 0.0, 0.0, 0.0)
    SetMinimapComponentPosition("minimap_blur", "L", "B", 0.0, 0.0, 0.0, 0.0)
end)

-- ──────────────────────────────────────────────────────────
--  QB-Core player events
-- ──────────────────────────────────────────────────────────
RegisterNetEvent("QBCore:Client:OnPlayerLoaded", function()
    Wait(1000)
    Koci.Client.HUD:Start()
end)

RegisterNetEvent("QBCore:Client:OnPlayerUnload", function()
    Wait(500)
    Koci.Client.HUD:ResetVehicle()      -- logging out inside a car must not carry its UI to the next character
    Koci.Client.HUD:Toggle(false)
    DisplayRadar(false)
end)

RegisterNetEvent("QBCore:Player:SetPlayerData", function(data)
    if type(data) ~= "table" then return end
    local md = data.metadata or {}
    -- تحديث needs من metadata مباشرة
    if md.hunger  ~= nil then Koci.Client.HUD.data.bars.hunger  = md.hunger  end
    if md.thirst  ~= nil then Koci.Client.HUD.data.bars.thirst  = md.thirst  end
    if md.stress  ~= nil then Koci.Client.HUD.data.bars.stress  = md.stress  end
end)

-- ──────────────────────────────────────────────────────────
--  Server callback handler
-- ──────────────────────────────────────────────────────────
RegisterNetEvent("qb-hud:Client:HandleCallback", function(key, data)
    if Koci.Callbacks[key] then
        Koci.Callbacks[key](data)
        Koci.Callbacks[key] = nil
    end
end)

-- ──────────────────────────────────────────────────────────
--  HUD toggle from server
-- ──────────────────────────────────────────────────────────
RegisterNetEvent("qb-hud:Client:OpenHudSettings", function()
    SetNuiFocus(true, true)
    Koci.Client:SendReactMessage("setRouter", "settings")
end)

-- ──────────────────────────────────────────────────────────
--  Needs updates
-- ──────────────────────────────────────────────────────────
RegisterNetEvent("hud:client:UpdateNeeds", function(newHunger, newThirst)
    Koci.Client.HUD.data.bars.hunger = newHunger
    Koci.Client.HUD.data.bars.thirst = newThirst
end)

RegisterNetEvent("hud:client:UpdateStress", function(newStress)
    Koci.Client.HUD.data.bars.stress = newStress
end)

-- ──────────────────────────────────────────────────────────
--  Money popup
-- ──────────────────────────────────────────────────────────
RegisterNetEvent("hud:client:OnMoneyChange", function(moneyType, amount, bloom)
    local pd      = Koci.Client:GetPlayerData() or {}
    local money   = pd.money or {}
    local bankAmt = money[moneyType] or 0
    SendNUIMessage({
        action = 'money',
        money  = bloom,
        type   = moneyType,
        amount = math.floor(tonumber(amount)  or 0),
        bank   = math.floor(tonumber(bankAmt) or 0),
    })
end)

RegisterNetEvent("hud:client:ShowAccounts", function(moneyType, amount)
    SendNUIMessage({ action = 'money', money = 'cehckmoney', type = moneyType, bank = math.floor(tonumber(amount) or 0) })
end)

-- ──────────────────────────────────────────────────────────
--  Seatbelt (smallresources / qb-smallresources)
-- ──────────────────────────────────────────────────────────
RegisterNetEvent("seatbelt:client:ToggleSeatbelt", function()
    Koci.Client.HUD:ToggleSeatBelt()
end)

-- ──────────────────────────────────────────────────────────
--  Manual gear (hrsgears / 0r-hud compat)
-- ──────────────────────────────────────────────────────────
RegisterNetEvent("qb-hud:Client:SetManualGear", function(newGear)
    Koci.Client.HUD.data.vehicle.manualGear = newGear
end)

-- ──────────────────────────────────────────────────────────
--  PMA-Voice — دائماً مسجّل بغض النظر عن وقت تشغيل الريسورس
-- ──────────────────────────────────────────────────────────
AddEventHandler("pma-voice:playerTalkingChange", function(serverId, talking)
    -- بعض إصدارات pma-voice تبعث (isTalking) فقط بدون serverId
    if type(serverId) == "boolean" then
        Koci.Client.HUD.data.bars.voice.isTalking = serverId
        return
    end
    -- الإصدار العادي: (serverId, isTalking)
    if type(serverId) == "number" and serverId == GetPlayerServerId(PlayerId()) then
        Koci.Client.HUD.data.bars.voice.isTalking = talking and true or false
    end
end)

AddEventHandler("pma-voice:radioActive", function(data)
    if type(data) == "table" then
        Koci.Client.HUD.data.bars.voice.radio = (data.radioChannel ~= nil and data.radioChannel ~= false)
    else
        Koci.Client.HUD.data.bars.voice.radio = data and true or false
    end
end)

AddEventHandler("pma-voice:setTalkingMode", function(mode)
    if     mode == 1 then Koci.Client.HUD.data.bars.voice.range = 1.5
    elseif mode == 2 then Koci.Client.HUD.data.bars.voice.range = 3.0
    elseif mode == 3 then Koci.Client.HUD.data.bars.voice.range = 6.0
    else                  Koci.Client.HUD.data.bars.voice.range = 3.0 end
end)

-- qb-voice / saltychat fallbacks
AddEventHandler("qb-voice:setTalkingMode", function(mode)
    Koci.Client.HUD.data.bars.voice.range = mode
end)
AddEventHandler("qb-voice:radioActive", function(radioTalking)
    Koci.Client.HUD.data.bars.voice.radio = radioTalking
end)
AddEventHandler("SaltyChat_VoiceRangeChanged", function(range, index)
    Koci.Client.HUD.data.bars.voice.range = index
end)
AddEventHandler("SaltyChat_RadioTrafficStateChanged", function(pRx, pTx, sRx, sTx)
    Koci.Client.HUD.data.bars.voice.radio = pTx or sTx
end)

-- ──────────────────────────────────────────────────────────
--  NUI Callbacks
-- ──────────────────────────────────────────────────────────
-- the page asks for config.lua values once it has loaded
RegisterNUICallback("hudReady", function(_, cb)
    cb(Koci.Client.HUD:GetNuiConfig())
end)

RegisterNUICallback("OnHideSettingsMenu", function(_, cb)
    SetNuiFocus(false, false)
    cb(true)
end)

RegisterNUICallback("OnSettingsSaved", function(_, cb)
    Koci.Client:SendNotify(_t("hud.settings.saved"), "success")
    cb(true)
end)

RegisterNUICallback("OnVehicleHudChanged", function(data, cb)
    Koci.Client.HUD:UpdateVehicleHud(data.newVH)
    cb(true)
end)

RegisterNUICallback("OnCompassHudChanged", function(data, cb)
    Koci.Client.HUD:UpdateCompassHud(data.newCompass)
    cb(true)
end)

RegisterNUICallback("nui:setCinematicMode", function(data, cb)
    Koci.Client.HUD.data.isCinematicHudActive = data
    if data then
        DisplayRadar(false)
    else
        if Koci.Client.HUD.data.vehicle.miniMap.alwaysActive then
            DisplayRadar(true)
        elseif IsPedInAnyVehicle(PlayerPedId(), false) then
            DisplayRadar(true)
        end
    end
    cb(true)
end)

-- ──────────────────────────────────────────────────────────
--  Seatbelt / CruiseControl Commands
-- ──────────────────────────────────────────────────────────
if Config.Settings.Seatbelt.active then
    RegisterCommand("qb-hud:ToggleSeatbelt", function()
        Koci.Client.HUD:ToggleSeatBelt()
    end, false)
    RegisterKeyMapping("qb-hud:ToggleSeatbelt", _t("notify.seatbeltOn"), "keyboard", Config.Settings.Seatbelt.key)

    RegisterCommand("qb-hud:ToggleCruise", function()
        if Koci.Client.HUD.data.vehicle.inVehicle and not Koci.Client.HUD.data.vehicle.isPassenger then
            Koci.Client.HUD:VehicleCruiseControlThick()
        end
    end, false)
    RegisterKeyMapping("qb-hud:ToggleCruise", _t("notify.cruiseControlOn"), "keyboard", Config.Settings.CruiseControl.key)
end

-- ──────────────────────────────────────────────────────────
--  Chat commands
-- ──────────────────────────────────────────────────────────
RegisterCommand("cash", function()
    local pd   = Koci.Client:GetPlayerData() or {}
    local cash = (pd.money and pd.money["cash"]) or 0
    SendNUIMessage({ action = "money", money = "cehckmoney", type = "cash", bank = math.floor(cash) })
end, false)

RegisterCommand("bank", function()
    local pd   = Koci.Client:GetPlayerData() or {}
    local bank = (pd.money and pd.money["bank"]) or 0
    SendNUIMessage({ action = "money", money = "cehckmoney", type = "bank", bank = math.floor(bank) })
end, false)
