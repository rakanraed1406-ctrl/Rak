local QBCore = exports['qb-core']:GetCoreObject()
local isOpen = false
local cardPickupReady = false
local FullyLoaded = LocalPlayer.state.isLoggedIn

AddStateBagChangeHandler('isLoggedIn', nil, function(_, _, value)
    FullyLoaded = value
end)

local function sendLocale()
    SendNUIMessage({ action = 'updateLocale', translations = Translations.ui })
end

-- The ATM/bank animation plays while the UI is open and is stopped when it
-- closes. PROP_HUMAN_ATM is a looping scenario: ClearPedTasks alone often
-- leaves the ped stuck in it, so fall back to ClearPedTasksImmediately.
local usingScenario = false

local function startScenario()
    usingScenario = true
    TaskStartScenarioInPlace(PlayerPedId(), 'PROP_HUMAN_ATM', 0, true)
end

local function stopScenario()
    if not usingScenario then return end
    usingScenario = false
    local ped = PlayerPedId()
    ClearPedTasks(ped)
    CreateThread(function()
        Wait(1200)
        if not usingScenario and IsPedUsingAnyScenario(ped) then
            ClearPedTasksImmediately(ped)
        end
    end)
end

local function closeUI()
    stopScenario()
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    TriggerServerEvent('Renewed-Banking:server:closeSession')
end

-- Server callback wrapped in a promise with a timeout, so the NUI can never
-- get stuck on a loading spinner if the server doesn't answer.
local function awaitCallback(name, data)
    local p = promise.new()
    QBCore.Functions.TriggerCallback('Renewed-Banking:server:' .. name, function(result)
        p:resolve(result)
    end, data)
    SetTimeout(15000, function()
        if p.state == 0 then p:resolve(false) end
    end)
    return Citizen.Await(p)
end

-- Physical cards in the player's own inventory.
local function getOwnCards()
    local PlayerData = QBCore.Functions.GetPlayerData()
    local cards = {}
    for _, item in pairs(PlayerData.items or {}) do
        if item and item.name == config.cardItem and type(item.info) == 'table' and item.info.account then
            cards[#cards+1] = {
                slot = item.slot,
                iban = item.info.iban,
                holder = item.info.holder,
                color = item.info.color or 'blue',
                hasPin = item.info.hasPin == true or (item.info.pin ~= nil and item.info.pin ~= '')
            }
        end
    end
    table.sort(cards, function(a, b) return a.slot < b.slot end)
    return cards
end

local function servicesBlocked(cb)
    local check = config.servicesCheck
    if not check or not check.resource or GetResourceState(check.resource) ~= 'started' then
        return cb(false)
    end
    QBCore.Functions.TriggerCallback(check.callback, function(blocked) cb(blocked == true) end)
end

local function playOpenAnimation(label, onDone)
    startScenario()
    QBCore.Functions.Progressbar('Renewed-Banking', label, math.random(2000, 3500), false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {}, {}, {}, function()
        onDone()
    end, function()
        stopScenario()
        QBCore.Functions.Notify(Lang:t('menu.cancelled'), 'error', 5000)
    end)
end

local function openBank(tab)
    if isOpen then return end
    isOpen = true
    sendLocale()
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'setLoading', status = true })

    local result = awaitCallback('openBank')
    if not result or not isOpen then
        closeUI()
        if not result then QBCore.Functions.Notify(Lang:t('notify.loading_failed'), 'error', 7500) end
        return
    end
    SendNUIMessage({ action = 'open', mode = 'bank', tab = tab or 'dashboard', data = result })
end

local function openAtm()
    if isOpen then return end
    local cards = getOwnCards()
    if #cards == 0 then
        stopScenario()
        QBCore.Functions.Notify(Lang:t('menu.need_card'), 'error')
        return
    end
    isOpen = true
    sendLocale()
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'atmInsert', cards = cards })
end

RegisterNetEvent('Renewed-Banking:client:openBankUI', function(data)
    data = data or {}
    if isOpen then return end
    if data.atm and #getOwnCards() == 0 then
        QBCore.Functions.Notify(Lang:t('menu.need_card'), 'error')
        return
    end
    servicesBlocked(function(blocked)
        if blocked then
            QBCore.Functions.Notify(Lang:t('menu.services_suspended'), 'error')
            return
        end
        playOpenAnimation(data.atm and Lang:t('menu.opening_atm') or Lang:t('menu.opening_bank'), function()
            if data.atm then openAtm() else openBank(data.tab) end
        end)
    end)
end)

-- =========================================================================
-- NUI callbacks
-- =========================================================================

RegisterNUICallback('closeInterface', function(_, cb)
    closeUI()
    cb('ok')
end)

RegisterNUICallback('closeCardPreview', function(_, cb)
    if not isOpen then SetNuiFocus(false, false) end
    cb('ok')
end)

-- ATM: the card + PIN are chosen inside the NUI (no external popups).
RegisterNUICallback('atmInsertCard', function(data, cb)
    if not isOpen or type(data) ~= 'table' then return cb(false) end
    local result = awaitCallback('openAtmWithCard', {
        slot = tonumber(data.slot),
        pin = data.pin and tostring(data.pin) or nil
    })
    cb(result or { error = Lang:t('notify.loading_failed') })
end)

local bankActions = {
    'deposit', 'withdraw', 'transfer', 'toggleFreeze',
    'openAccount', 'closeAccount', 'createShared', 'renameAccount',
    'getMembers', 'addMember', 'removeMember',
    'requestCard', 'setCardPin', 'replaceCard', 'loadCard', 'unloadCard'
}

for _, action in ipairs(bankActions) do
    RegisterNUICallback(action, function(data, cb)
        if not isOpen then return cb(false) end
        cb(awaitCallback(action, type(data) == 'table' and data or {}) or false)
    end)
end

RegisterCommand('closeBankUI', function()
    closeUI()
    SendNUIMessage({ action = 'hideCardPreview' })
end, false)

-- =========================================================================
-- Card pickup
-- =========================================================================

RegisterNetEvent('Renewed-Banking:client:cardPending', function(seconds)
    cardPickupReady = false
    QBCore.Functions.Notify(Lang:t('menu.card_pending', {time = seconds}), 'primary', 8000)
end)

RegisterNetEvent('Renewed-Banking:client:cardReady', function()
    cardPickupReady = true
    QBCore.Functions.Notify(Lang:t('menu.card_ready'), 'success', 7000)
end)

RegisterNetEvent('Renewed-Banking:client:cardCollected', function()
    cardPickupReady = false
end)

RegisterNetEvent('Renewed-Banking:client:collectCard', function()
    TriggerServerEvent('Renewed-Banking:server:collectCard')
end)

-- =========================================================================
-- Targets, peds, blips
-- =========================================================================

CreateThread(function()
    exports['qb-target']:AddTargetModel(config.atms, {
        options = {{
            type = 'client',
            event = 'Renewed-Banking:client:openBankUI',
            icon = 'fas fa-credit-card',
            label = Lang:t('menu.use_atm'),
            atm = true
        }},
        distance = 1.5
    })
end)

local pedSpawned = false
local bankPeds = {}
local blips = {}

local function createPeds()
    if pedSpawned then return end
    pedSpawned = true
    for k, info in ipairs(config.peds) do
        local coords = info.coords
        local model = joaat(info.model)
        RequestModel(model)
        local timeout = GetGameTimer() + 5000
        while not HasModelLoaded(model) and GetGameTimer() < timeout do Wait(10) end

        if HasModelLoaded(model) then
            local ped = CreatePed(0, model, coords.x, coords.y, coords.z - 1, coords.w, false, false)
            TaskStartScenarioInPlace(ped, 'PROP_HUMAN_STAND_IMPATIENT', 0, true)
            FreezeEntityPosition(ped, true)
            SetEntityInvincible(ped, true)
            SetBlockingOfNonTemporaryEvents(ped, true)
            SetModelAsNoLongerNeeded(model)
            bankPeds[k] = ped

            exports['qb-target']:AddTargetEntity(ped, {
                options = {
                    {
                        type = 'client',
                        event = 'Renewed-Banking:client:openBankUI',
                        icon = 'fas fa-building-columns',
                        label = Lang:t('menu.view_bank'),
                        atm = false
                    },
                    {
                        type = 'client',
                        event = 'Renewed-Banking:client:openBankUI',
                        icon = 'fas fa-users-gear',
                        label = Lang:t('menu.manage_bank'),
                        atm = false,
                        tab = 'accounts'
                    },
                    {
                        type = 'client',
                        event = 'Renewed-Banking:client:collectCard',
                        icon = 'fas fa-credit-card',
                        label = Lang:t('menu.take_card'),
                        canInteract = function() return cardPickupReady end
                    }
                },
                distance = 2.0
            })
        end

        local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
        SetBlipSprite(blip, 108)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, 0.5)
        SetBlipColour(blip, 4)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(Lang:t('menu.blip'))
        EndTextCommandSetBlipName(blip)
        blips[k] = blip
    end
end

local function deletePeds()
    if not pedSpawned then return end
    for k, ped in pairs(bankPeds) do
        if DoesEntityExist(ped) then
            exports['qb-target']:RemoveTargetEntity(ped)
            DeletePed(ped)
        end
        bankPeds[k] = nil
    end
    for k, blip in pairs(blips) do
        RemoveBlip(blip)
        blips[k] = nil
    end
    pedSpawned = false
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    Wait(100)
    createPeds()
    sendLocale()
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    if isOpen then closeUI() end
    deletePeds()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if isOpen then SetNuiFocus(false, false) end
    if usingScenario then ClearPedTasksImmediately(PlayerPedId()) end
    deletePeds()
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    Wait(100)
    if FullyLoaded then
        createPeds()
        sendLocale()
    end
end)

RegisterNetEvent('Renewed-Banking:client:sendNotification', function(msg, kind)
    if not msg then return end
    if isOpen then
        SendNUIMessage({ action = 'notify', status = msg, kind = kind or 'error' })
    else
        QBCore.Functions.Notify(msg, kind == 'success' and 'success' or 'error', 5000)
    end
end)

-- Physical card item: using it from the inventory shows a card preview
-- (data comes from the server so frozen / deactivated status is live).
RegisterNetEvent('Renewed-Banking:client:openCardUI', function(card)
    if isOpen or type(card) ~= 'table' then return end
    sendLocale()
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'showCardPreview', card = card })
end)
