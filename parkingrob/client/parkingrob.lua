-- =========================================================================
-- parkingrob (client) - settings
-- The buyer ped location is set in server/parkingrob.lua (Config.Buyer).
-- =========================================================================
local Config = {}

-- Parking meter props.
Config.MeterModels = {
    -1940238623,
    2108567945,
}

-- Only used to show "you need a lockpick" right away; the server checks it.
Config.LockpickItems = { 'lockpick', 'advancedlockpick' }

-- Called when a robbery triggers a police alert. Change it to your
-- dispatch script if you use one (ps-dispatch, cd_dispatch, ...).
Config.Dispatch = function(coords)
    TriggerServerEvent('police:server:policeAlert', 'Parking meter being broken into')
end

local QBCore = exports['qb-core']:GetCoreObject()
local robbing = false
local cooldowns = {} -- meterKey -> GetGameTimer() when it can be robbed again

local ANIM_DICT, ANIM_NAME = 'anim@gangops@facility@servers@', 'hotwire'

local function meterKey(c)
    return ('%.1f:%.1f:%.1f'):format(c.x, c.y, c.z)
end

local function meterOnCooldown(entity)
    local untilTime = cooldowns[meterKey(GetEntityCoords(entity))]
    return untilTime ~= nil and GetGameTimer() < untilTime
end

local function hasLockpick()
    for _, item in pairs(QBCore.Functions.GetPlayerData().items or {}) do
        for _, name in ipairs(Config.LockpickItems) do
            if item and item.name == name then return true end
        end
    end
    return false
end

RegisterNetEvent('parkingrob:client:meterCooldown', function(key, seconds)
    cooldowns[key] = GetGameTimer() + seconds * 1000
end)

RegisterNetEvent('parkingrob:client:allCooldowns', function(list)
    for key, seconds in pairs(list or {}) do
        cooldowns[key] = GetGameTimer() + seconds * 1000
    end
end)

-- =========================================================================
-- Robbing a meter
-- =========================================================================

local function stopRobAnim()
    StopAnimTask(PlayerPedId(), ANIM_DICT, ANIM_NAME, 1.0)
    robbing = false
end

local function robMeter(entity)
    if robbing then return end
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then return end
    if not hasLockpick() then
        return QBCore.Functions.Notify('You need a lockpick.', 'error')
    end
    if meterOnCooldown(entity) then
        return QBCore.Functions.Notify('This meter has already been emptied.', 'error')
    end

    robbing = true
    local coords = GetEntityCoords(entity)
    QBCore.Functions.TriggerCallback('parkingrob:server:start', function(res)
        if not res or res.error then
            robbing = false
            if res and res.error then QBCore.Functions.Notify(res.error, 'error') end
            return
        end

        TaskTurnPedToFaceEntity(ped, entity, 800)
        Wait(800)

        if res.alert then
            SetTimeout(math.random(2000, 6000), function() Config.Dispatch(coords) end)
        end

        QBCore.Functions.Progressbar('parkingrob', 'Picking the meter lock...', res.duration, false, true, {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true,
        }, {
            animDict = ANIM_DICT,
            anim = ANIM_NAME,
            flags = 16,
        }, {}, {}, function()
            stopRobAnim()
            TriggerServerEvent('parkingrob:server:finish')
        end, function()
            stopRobAnim()
            TriggerServerEvent('parkingrob:server:cancel')
            QBCore.Functions.Notify('Cancelled.', 'error')
        end)
    end, coords)
end

CreateThread(function()
    exports['qb-target']:AddTargetModel(Config.MeterModels, {
        options = {
            {
                icon = 'fa-solid fa-square-parking',
                label = 'Rob parking meter',
                action = function(entity) robMeter(entity) end,
                canInteract = function(entity)
                    return not robbing and not meterOnCooldown(entity)
                end,
            },
        },
        distance = 1.5
    })
end)

-- =========================================================================
-- Coin buyer
-- =========================================================================

local buyerPed, buyerBlip

local function trendText(trend)
    if not trend or trend == 0 then return '' end
    return trend > 0 and (' (up %d%%)'):format(trend) or (' (down %d%%)'):format(-trend)
end

RegisterNetEvent('parkingrob:client:prices', function()
    QBCore.Functions.TriggerCallback('parkingrob:server:market', function(market)
        if not market then return end
        local lines = {}
        for _, c in ipairs(market.coins) do
            lines[#lines+1] = ('%s: $%d%s'):format(c.label, c.price, trendText(c.trend))
        end
        QBCore.Functions.Notify("Today's prices - " .. table.concat(lines, ' | '), 'primary', 9000)
    end)
end)

RegisterNetEvent('parkingrob:client:sell', function()
    QBCore.Functions.TriggerCallback('parkingrob:server:market', function(market)
        if not market then return end

        local options, owned = {}, {}
        for _, c in ipairs(market.coins) do
            if c.have > 0 then
                options[#options+1] = {
                    value = c.id,
                    text = ('%s - $%d each%s (you have %d)'):format(c.label, c.price, trendText(c.trend), c.have)
                }
                owned[#owned+1] = ('%d %s'):format(c.have, c.label)
            end
        end
        if #options == 0 then
            return QBCore.Functions.Notify("You don't have any coins to sell.", 'error')
        end

        local dialog = exports['qb-input']:ShowInput({
            header = 'Coin Buyer',
            submitText = 'Sell',
            inputs = {
                {
                    text = 'Coin',
                    name = 'coin',
                    type = 'radio',
                    options = options,
                    default = options[1].value,
                },
                {
                    text = ('Amount (you have %s)'):format(table.concat(owned, ', ')),
                    name = 'amount',
                    type = 'number',
                    isRequired = true,
                },
            },
        })
        if not dialog or not dialog.coin then return end

        local amount = math.floor(tonumber(dialog.amount) or 0)
        if amount < 1 then
            return QBCore.Functions.Notify('Invalid amount.', 'error')
        end
        TriggerServerEvent('parkingrob:server:sell', dialog.coin, amount)
    end)
end)

local function spawnBuyer(b)
    if buyerPed and DoesEntityExist(buyerPed) then return end
    local model = joaat(b.model)
    RequestModel(model)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do Wait(10) end
    if not HasModelLoaded(model) then
        print(('^1[parkingrob] could not load buyer model %s^0'):format(b.model))
        return
    end

    buyerPed = CreatePed(0, model, b.coords.x, b.coords.y, b.coords.z - 1.0, b.coords.w, false, false)
    SetModelAsNoLongerNeeded(model)
    FreezeEntityPosition(buyerPed, true)
    SetEntityInvincible(buyerPed, true)
    SetBlockingOfNonTemporaryEvents(buyerPed, true)
    if b.scenario then TaskStartScenarioInPlace(buyerPed, b.scenario, 0, true) end

    exports['qb-target']:AddTargetEntity(buyerPed, {
        options = {
            { type = 'client', event = 'parkingrob:client:sell', icon = 'fa-solid fa-coins', label = 'Sell coins' },
            { type = 'client', event = 'parkingrob:client:prices', icon = 'fa-solid fa-chart-line', label = "Today's prices" },
        },
        distance = 2.0
    })

    if b.blip and b.blip.enabled then
        buyerBlip = AddBlipForCoord(b.coords.x, b.coords.y, b.coords.z)
        SetBlipSprite(buyerBlip, b.blip.sprite)
        SetBlipColour(buyerBlip, b.blip.color)
        SetBlipScale(buyerBlip, b.blip.scale)
        SetBlipAsShortRange(buyerBlip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(b.blip.label)
        EndTextCommandSetBlipName(buyerBlip)
    end
end

local function removeBuyer()
    if buyerPed and DoesEntityExist(buyerPed) then
        exports['qb-target']:RemoveTargetEntity(buyerPed)
        DeletePed(buyerPed)
    end
    if buyerBlip then RemoveBlip(buyerBlip) end
    buyerPed, buyerBlip = nil, nil
end

local function onLoaded()
    QBCore.Functions.TriggerCallback('parkingrob:server:buyerInfo', function(buyer)
        if buyer then spawnBuyer(buyer) end
    end)
    TriggerServerEvent('parkingrob:server:syncCooldowns')
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', onLoaded)
RegisterNetEvent('QBCore:Client:OnPlayerUnload', removeBuyer)

AddEventHandler('onResourceStart', function(resource)
    if resource == GetCurrentResourceName() and LocalPlayer.state.isLoggedIn then onLoaded() end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    removeBuyer()
    if robbing then StopAnimTask(PlayerPedId(), ANIM_DICT, ANIM_NAME, 1.0) end
end)
