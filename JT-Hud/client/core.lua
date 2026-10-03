

Koci           = {}
Koci.Framework = Utils.Functions:GetFramework()
Koci.Utils     = Utils.Functions
Koci.Callbacks = {}

Koci.Client = {
    HUD = {
        data = {
            isVisible = true,
            bars = {
                voice = {
                    microphone = false,
                    radio      = false,
                    isTalking  = false,
                    range      = 1,
                },
                health   = nil,
                armor    = nil,
                hunger   = nil,
                thirst   = nil,
                oxygen   = nil,
                stamina  = nil,
                stress   = nil,
                terminal = nil,
                leaf     = nil,
            },
            vehicle = {
                thick          = { wait = 200 },
                entity         = nil,
                kmH            = Config.Settings.VehicleHUD.kmH,
                show           = false,
                isSeatbeltOn   = true,  -- افتراضي: غير مربوط
                isPassenger    = false,
                cruiseControlStatus = nil,
                inVehicle      = false,
                speed          = 0,
                _lastEntitySpeed  = 0,
                _lastBodyHealth   = 1000,
                engineHealth   = 1000,
                fuel = { level = 0, max_level = 0, type = nil },
                rpm            = 0,
                gear           = nil,
                miniMap        = { alwaysActive = false, style = "square" },
                speedoMeter    = { fps = nil },
                type           = 2,
                lightsOn       = false,
                manualMode     = false,
                manualGear     = "N",
                previousVelocity = vector3(0, 0, 0),
            },
            compass = {
                onlyInVehicle     = false,
                show              = Config.Settings.Compass.show,
                heading           = 0,
                lastCrossRoadCheck = -1,
                crossRoad = { street1 = nil, street2 = nil },
            },
            account = {
                playerServerId = -1,
                playerBalance  = { cash = 0, bank = 0 },
            },
            isCinematicHudActive = false,
        },
    }
}

-- ── ショートカット ──
function Koci.Client:SendReactMessage(action, data)
    SendNUIMessage({ action = action, data = data })
end

function Koci.Client:TriggerServerCallback(key, payload, func)
    if not func then func = function() end end
    Koci.Callbacks[key] = func
    TriggerServerEvent("qb-hud:Server:HandleCallback", key, payload)
end

function Koci.Client:GetPlayerData()
    return Koci.Framework.Functions.GetPlayerData()
end

function Koci.Client:SendNotify(title, notifyType, duration, icon, text)
    if Config.NotifyType == "qb_notify" then
        Koci.Framework.Functions.Notify(title, notifyType or "primary")
    else
        Utils.Functions:CustomNotify(nil, title, notifyType, text, duration, icon)
    end
end

-- ── framework init wait ──
CreateThread(function()
    while Koci.Framework == nil do
        Koci.Framework = Utils.Functions:GetFramework()
        Wait(100)
    end
end)

function playerLoaded()
    return LocalPlayer.state.isLoggedIn
end


