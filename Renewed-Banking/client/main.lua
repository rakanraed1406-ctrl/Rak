local QBCore = exports['qb-core']:GetCoreObject()
local isVisible = false
local cardPickupReady = false

RegisterNetEvent('Renewed-Banking:client:cardPending', function(seconds)
    cardPickupReady = false
    QBCore.Functions.Notify(("Wait right there - your card will be ready in about %d seconds. Come back to the counter to collect it."):format(seconds), "primary", 8000)
end)

RegisterNetEvent('Renewed-Banking:client:cardReady', function()
    cardPickupReady = true
    QBCore.Functions.Notify("Your card is ready - go talk to the bank teller to take it.", "success", 7000)
end)

RegisterNetEvent('Renewed-Banking:client:collectCard', function()
    TriggerServerEvent('Renewed-Banking:server:collectCard')
    cardPickupReady = false
end)

local FullyLoaded = LocalPlayer.state.isLoggedIn

AddStateBagChangeHandler('isLoggedIn', nil, function(_, _, value)
    FullyLoaded = value
end)

local function nuiHandler(val)
    isVisible = val
    SetNuiFocus(val, val)
    if not val then
        TriggerServerEvent('Renewed-Banking:server:clearCardSession')
    end
end

-- Returns the physical cards currently in the player's own inventory.
local function getOwnCards()
    local PlayerData = QBCore.Functions.GetPlayerData()
    local cards = {}
    for _, item in pairs(PlayerData.items or {}) do
        if item and item.name == config.cardItem then
            cards[#cards+1] = item
        end
    end
    return cards
end




local currentIsAtm = false
local function openBankUI(isAtm)
    currentIsAtm = isAtm
    SendNUIMessage({action = "setLoading", status = true})
    nuiHandler(true)
    QBCore.Functions.TriggerCallback('Renewed-Banking:server:initalizeBanking', function(result)
        if not result then
            nuiHandler(false)
            QBCore.Functions.Notify(Lang:t("notify.loading_failed"), 'error', 7500)
            return
        end
        SetTimeout(1000, function()
            SendNUIMessage({
                action = "setVisible",
                status = isVisible,
                accounts = result,
                loading = false,
                atm = isAtm
            })
        end)
    end)
end

-- ATM + physical card ---------------------------------------------------
-- Prompts for the card's PIN (only if one is set) then opens the ATM
-- scoped to that specific card's linked account.
local function openAtmWithCard(item)
    local pin = ""
    if item.info and item.info.pin and item.info.pin ~= "" then
        local dialog = exports['qb-input']:ShowInput({
            header = "Enter Card PIN",
            submitText = "Confirm",
            inputs = {{ text = "4-digit PIN", name = "pin", type = "number", isRequired = true }}
        })
        if not dialog or not dialog.pin then return end
        pin = tostring(dialog.pin)
    end

    SendNUIMessage({action = "setLoading", status = true})
    nuiHandler(true)
    QBCore.Functions.TriggerCallback('Renewed-Banking:server:openAtmWithCard', function(result)
        if not result then
            nuiHandler(false)
            QBCore.Functions.Notify(Lang:t("notify.loading_failed"), 'error', 7500)
            return
        end
        currentIsAtm = true
        if result.restricted then
            QBCore.Functions.Notify("No PIN set on this card - withdraw only.", "primary", 6000)
        end
        SetTimeout(500, function()
            SendNUIMessage({
                action = "setVisible",
                status = isVisible,
                accounts = result.accounts,
                loading = false,
                atm = true
            })
        end)
    end, {slot = item.slot, pin = pin})
end

RegisterNetEvent('Renewed-Banking:client:useCardAtAtm', function(data)
    for _, item in ipairs(getOwnCards()) do
        if item.slot == data.slot then
            openAtmWithCard(item)
            return
        end
    end
end)

local function chooseCardAndOpenAtm()
    local cards = getOwnCards()
    if #cards == 0 then
        QBCore.Functions.Notify("You need a bank card on you to use the ATM.", "error")
        return
    elseif #cards == 1 then
        openAtmWithCard(cards[1])
        return
    end

    local menu = {{ isMenuHeader = true, header = "Choose a Card" }}
    for _, item in ipairs(cards) do
        menu[#menu+1] = {
            header = (item.info and item.info.holder) or "Bank Card",
            txt = (item.info and item.info.iban) or "",
            params = { event = 'Renewed-Banking:client:useCardAtAtm', args = { slot = item.slot } }
        }
    end
    exports['qb-menu']:openMenu(menu)
end

RegisterNetEvent("Renewed-Banking:client:openBankUI", function(data)
    if data.atm and #getOwnCards() == 0 then
        QBCore.Functions.Notify("You need a bank card on you to use the ATM.", "error")
        return
    end
    QBCore.Functions.TriggerCallback('qb-stopservices:server:servicescheck', function(istrue)
        if not istrue then
    local txt = data.atm and 'Opening ATM' or 'Opening Bank'
    TaskStartScenarioInPlace(PlayerPedId(), "PROP_HUMAN_ATM", 0, 1)
    QBCore.Functions.Progressbar('Renewed-Banking', txt, math.random(3000,5000), false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {}, {}, {}, function()
        if data.atm then
            chooseCardAndOpenAtm()
        else
            openBankUI(false)
        end
        Wait(500)
        ClearPedTasksImmediately(PlayerPedId())
    end, function()
        ClearPedTasksImmediately(PlayerPedId())
        QBCore.Functions.Notify('Cancelled...', 'error', 7500)
    end)
else
    QBCore.Functions.Notify("You cannot do this! Your services have been suspended by the police", "error")
end
end)
end)

RegisterNUICallback("closeInterface", function(_, cb)
    nuiHandler(false)
    cb("ok")
end)

RegisterNUICallback("closeCardPreview", function(_, cb)
    SetNuiFocus(false, false)
    cb("ok")
end)

RegisterNUICallback("requestCard", function(data, cb)
    if not currentIsAtm then
        QBCore.Functions.Notify("You can only request a new bank card from an ATM.", "error")
        cb(false)
        return
    end
    local pushingP = promise.new()
    QBCore.Functions.TriggerCallback("Renewed-Banking:server:requestCard", function(result)
        pushingP:resolve(result)
    end, data)
    cb(Citizen.Await(pushingP))
end)

RegisterCommand("closeBankUI", function() nuiHandler(false) end)

local bankActions = {"deposit", "withdraw", "transfer", "toggleFreeze", "openAccount", "closeAccount", "requestCardForAccount", "setCardPinTab", "replaceCardTab", "unloadCardTab"}
CreateThread(function ()
    for k=1, #bankActions do
        RegisterNUICallback(bankActions[k], function(data, cb)
            local pushingP = promise.new()
            QBCore.Functions.TriggerCallback("Renewed-Banking:server:"..bankActions[k], function(result)
                pushingP:resolve(result)
            end, data)
            local newTransaction = Citizen.Await(pushingP)
            cb(newTransaction)
        end)
    end

    exports['qb-target']:AddTargetModel(config.atms,{
        options = {{
            type = "client",
            event = "Renewed-Banking:client:openBankUI",
            icon = "fas fa-money-check",
            label = Lang:t("menu.view_bank"),
            entity = entity,
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
    for k=1, #config.peds do
        local model = joaat(config.peds[k].model)

        RequestModel(model)
        while not HasModelLoaded(model) do Wait(0) end

        local coords = config.peds[k].coords
        bankPeds[k] = CreatePed(0, model, coords.x, coords.y, coords.z-1, coords.w, false, false)

        TaskStartScenarioInPlace(bankPeds[k], 'PROP_HUMAN_STAND_IMPATIENT', 0, true)
        FreezeEntityPosition(bankPeds[k], true)
        SetEntityInvincible(bankPeds[k], true)
        SetBlockingOfNonTemporaryEvents(bankPeds[k], true)

        exports['qb-target']:AddTargetEntity(bankPeds[k], {
            options = {
                {
                    type = "client",
                    event = "Renewed-Banking:client:openBankUI",
                    icon = "fas fa-money-check",
                    label = Lang:t("menu.view_bank"),
                    entity = entity,
                    atm = false
                },
                {
                    type = "client",
                    event = "Renewed-Banking:client:accountManagmentMenu",
                    icon = "fas fa-money-check",
                    label = Lang:t("menu.manage_bank")
                },
                {
                    type = "client",
                    event = "Renewed-Banking:client:collectCard",
                    icon = "fas fa-credit-card",
                    label = "Take the Card",
                    canInteract = function() return cardPickupReady end
                }
            },
            distance = 2.0
        })


        blips[k] = AddBlipForCoord(coords.x, coords.y, coords.z-1, coords.w)
        SetBlipSprite(blips[k], 108)
        SetBlipDisplay(blips[k], 4)
        SetBlipScale  (blips[k], 0.50)
        SetBlipColour (blips[k], 4)
        SetBlipAsShortRange(blips[k], true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString("Bank")
        EndTextCommandSetBlipName(blips[k])
    end

    pedSpawned = true
end

local function deletePeds()
    if not pedSpawned then return end
    for k=1, #bankPeds do
        DeletePed(bankPeds[k])
        RemoveBlip(blips[k])
    end
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    Wait(100)
    createPeds()
    SendNUIMessage({
        action = "updateLocale",
        translations = Translations.ui,
    })
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    Wait(100)
    deletePeds()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
    	Wait(100)
        deletePeds()
    end
end)

AddEventHandler('onResourceStart', function(resource)
    if resource == GetCurrentResourceName() then
        Wait(100)
        if FullyLoaded then
            createPeds()
            SendNUIMessage({
                action = "updateLocale",
                translations = Translations.ui,
            })
        end
    end
end)

RegisterNetEvent("Renewed-Banking:client:sendNotification", function(msg)
    if not msg then return end
    SendNUIMessage({
        action = "notify",
        status = msg,
    })
end)

RegisterNetEvent('Renewed-Banking:client:accountManagmentMenu', function(data)
    local table = {
        {
            isMenuHeader = true,
            header = Lang:t("menu.bank_name")
        },
        {
            header = Lang:t("menu.create_account"),
            txt = Lang:t("menu.create_account_txt"),
            params = {
                event = 'Renewed-Banking:client:createAccountMenu'
            }
        },
        {
            header = Lang:t("menu.manage_account"),
            txt = Lang:t("menu.manage_account_txt"),
            params = {
                event = 'Renewed-Banking:client:viewAccountsMenu'
            }
        }
    }
    exports['qb-menu']:openMenu(table)
end)

RegisterNetEvent('Renewed-Banking:client:createAccountMenu', function(data)
    local dialog = exports['qb-input']:ShowInput({
        header = Lang:t("menu.bank_name"),
        submitText = Lang:t("menu.create_account"),
        inputs = {
            {
                text = Lang:t("menu.account_id"),
                name = "accountid",
                type = "text",
                isRequired = true
            }
        }
    })
    if dialog and dialog.accountid then
        dialog.accountid = dialog.accountid:lower():gsub("%s+", "")
        TriggerServerEvent("Renewed-Banking:server:createNewAccount", dialog.accountid)
    end
end)

RegisterNetEvent('Renewed-Banking:client:viewAccountsMenu', function(data)
    TriggerServerEvent("Renewed-Banking:server:getPlayerAccounts")
end)

RegisterNetEvent('Renewed-Banking:client:addAccountMember', function(data)
    local dialog = exports['qb-input']:ShowInput({
        header = Lang:t("menu.bank_name"),
        submitText = Lang:t("menu.add_account_member"),
        inputs = {
            {
                text = Lang:t("menu.citizen_id"),
                name = "accountid",
                type = "text",
                isRequired = true
            }
        }
    })
    if dialog and dialog.accountid then
        dialog.accountid = dialog.accountid:upper():gsub("%s+", "")
        TriggerServerEvent("Renewed-Banking:server:addAccountMember", data.account, dialog.accountid)
    end
end)

RegisterNetEvent('Renewed-Banking:client:changeAccountName', function(data)
    local dialog = exports['qb-input']:ShowInput({
        header = Lang:t("menu.bank_name"),
        submitText = Lang:t("menu.change_account_name"),
        inputs = {
            {
                text = Lang:t("menu.account_id"),
                name = "accountid",
                type = "text",
                isRequired = true
            }
        }
    })
    if dialog and dialog.accountid then
        dialog.accountid = dialog.accountid:lower():gsub("%s+", "")
        TriggerServerEvent("Renewed-Banking:server:changeAccountName", data.account, dialog.accountid)
    end
end)

-- Physical bank card item: using it from the inventory shows its own small
-- card preview (IBAN, holder, frozen state) instead of opening the full
-- bank NUI. All the data it needs already lives on the item itself, so this
-- doesn't need to touch the server at all.
RegisterNetEvent("Renewed-Banking:client:openCardUI", function(item)
    if not item or not item.info then return end

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "showCardPreview",
        card = {
            iban = item.info.iban,
            holder = item.info.holder,
            account = item.info.account,
            frozen = item.info.frozen == true,
            color = item.info.color or "blue"
        }
    })
end)
