--[[ client.lua — finance payments (always on) and the original qb-vehicleshop
     showroom (only when Config.OldShowroom = true).

     No PolyZone: one thread checks distances (slow when you're far, faster
     inside a shop). Menus are built when you open them instead of every
     second, and showroom cars only exist while you are near the shop. ]]

local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = {}

local function onLoaded() PlayerData = QBCore.Functions.GetPlayerData() or {} end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', onLoaded)
RegisterNetEvent('QBCore:Client:OnPlayerUnload', function() PlayerData = {} end)
RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job) PlayerData.job = job end)

CreateThread(function()
    Wait(1000)
    if LocalPlayer.state.isLoggedIn then onLoaded() end
end)

local function vehLabel(model)
    local v = QBCore.Shared.Vehicles[model]
    return v and v.name or model
end

-- ===========================================================================
-- Offers from other players (sell / gift / test drive) — accept or decline
-- ===========================================================================
RegisterNetEvent('qb-vehicleshop:client:offer', function(id, title, text)
    exports['qb-menu']:openMenu({
        { header = title, txt = text, icon = 'fa-solid fa-handshake', isMenuHeader = true },
        { header = Lang:t('offer.accept'), icon = 'fa-solid fa-check', params = { event = 'qb-vehicleshop:client:offerAnswer', args = { id = id, accept = true } } },
        { header = Lang:t('offer.decline'), icon = 'fa-solid fa-xmark', params = { event = 'qb-vehicleshop:client:offerAnswer', args = { id = id, accept = false } } },
    })
end)

RegisterNetEvent('qb-vehicleshop:client:offerAnswer', function(a)
    if type(a) == 'table' then TriggerServerEvent('qb-vehicleshop:server:offerResponse', a.id, a.accept == true) end
end)

-- ===========================================================================
-- Finance (pay off cars that were financed)
-- ===========================================================================
local financeMenu = {
    {
        header = Lang:t('menus.financed_header'),
        txt = Lang:t('menus.finance_txt'),
        icon = 'fa-solid fa-user-ninja',
        params = { event = 'qb-vehicleshop:client:getVehicles' }
    }
}

local financeSpots = {}
for _, shop in pairs(Config.Shops) do
    if shop.FinanceZone then financeSpots[#financeSpots + 1] = shop.FinanceZone end
end

CreateThread(function()
    if #financeSpots == 0 then return end
    local inside = false
    while true do
        local sleep = 2500
        if LocalPlayer.state.isLoggedIn then
            local pos = GetEntityCoords(PlayerPedId())
            local here = false
            for i = 1, #financeSpots do
                local d = #(pos - financeSpots[i])
                if d < 30.0 then sleep = 500 end
                if d < 1.5 then
                    here = true
                    break
                end
            end
            if here ~= inside then
                inside = here
                if here then exports['qb-menu']:showHeader(financeMenu) else exports['qb-menu']:closeMenu() end
            end
        end
        Wait(sleep)
    end
end)

RegisterNetEvent('qb-vehicleshop:client:getVehicles', function()
    QBCore.Functions.TriggerCallback('qb-vehicleshop:server:getVehicles', function(vehicles)
        local menu = {}
        for _, v in ipairs(vehicles or {}) do
            local plate = tostring(v.plate):upper()
            menu[#menu + 1] = {
                header = vehLabel(v.vehicle),
                txt = Lang:t('menus.veh_platetxt') .. plate,
                icon = 'fa-solid fa-car-side',
                params = {
                    event = 'qb-vehicleshop:client:getVehicleFinance',
                    args = { plate = v.plate, balance = v.balance, paymentsLeft = v.paymentsleft, paymentAmount = v.paymentamount }
                }
            }
        end
        if #menu > 0 then
            exports['qb-menu']:openMenu(menu)
        else
            QBCore.Functions.Notify(Lang:t('error.nofinanced'), 'error', 7500)
        end
    end)
end)

RegisterNetEvent('qb-vehicleshop:client:getVehicleFinance', function(data)
    if type(data) ~= 'table' then return end
    exports['qb-menu']:openMenu({
        { header = Lang:t('menus.goback_header'), params = { event = 'qb-vehicleshop:client:getVehicles' } },
        { isMenuHeader = true, icon = 'fa-solid fa-sack-dollar', header = Lang:t('menus.veh_finance_balance'), txt = Lang:t('menus.veh_finance_currency') .. VShared.Comma(data.balance) },
        { isMenuHeader = true, icon = 'fa-solid fa-hashtag', header = Lang:t('menus.veh_finance_total'), txt = tostring(data.paymentsLeft) },
        { isMenuHeader = true, icon = 'fa-solid fa-sack-dollar', header = Lang:t('menus.veh_finance_reccuring'), txt = Lang:t('menus.veh_finance_currency') .. VShared.Comma(data.paymentAmount) },
        { header = Lang:t('menus.veh_finance_pay'), icon = 'fa-solid fa-hand-holding-dollar', params = { event = 'qb-vehicleshop:client:financePayment', args = { plate = data.plate } } },
        { header = Lang:t('menus.veh_finance_payoff'), icon = 'fa-solid fa-hand-holding-dollar', params = { event = 'qb-vehicleshop:client:financePayoff', args = { plate = data.plate } } },
    })
end)

RegisterNetEvent('qb-vehicleshop:client:financePayment', function(data)
    if type(data) ~= 'table' then return end
    local dialog = exports['qb-input']:ShowInput({
        header = Lang:t('menus.veh_finance'),
        submitText = Lang:t('menus.veh_finance_pay'),
        inputs = { { type = 'number', isRequired = true, name = 'paymentAmount', text = Lang:t('menus.veh_finance_payment') } }
    })
    if dialog and dialog.paymentAmount then
        TriggerServerEvent('qb-vehicleshop:server:financePayment', data.plate, dialog.paymentAmount)
    end
end)

RegisterNetEvent('qb-vehicleshop:client:financePayoff', function(data)
    if type(data) == 'table' then TriggerServerEvent('qb-vehicleshop:server:financePaymentFull', data.plate) end
end)

-- ===========================================================================
-- Old showroom — everything below only runs with Config.OldShowroom = true
-- ===========================================================================
if not Config.OldShowroom then return end

local STREAM_DIST = 120.0 -- showroom cars exist only this close to the shop
local showroom = {}       -- [shop][slot] = model (the server decides)
local display = {}        -- [shop][slot] = { model, veh }
local catalogs = {}       -- [shop] = vehicles sold there (built once)
local insideShop, closestSlot = nil, nil
local headerShown = false
local showroomReady = false

local function canUseShop(shopName)
    local shop = Config.Shops[shopName]
    return shop and (shop.Job == 'none' or (PlayerData.job and PlayerData.job.name == shop.Job))
end

local vehHeaderMenu = {
    {
        header = Lang:t('menus.vehHeader_header'),
        txt = Lang:t('menus.vehHeader_txt'),
        icon = 'fa-solid fa-car',
        params = { event = 'qb-vehicleshop:client:showVehOptions' }
    }
}

local function act(action, shop, slot, extra)
    local args = { action = action, shop = shop, slot = slot }
    if extra then for k, v in pairs(extra) do args[k] = v end end
    return { event = 'qb-vehicleshop:client:legacyAction', args = args }
end

local function openVehicleMenu(shop, slot)
    shop, slot = shop or insideShop, slot or closestSlot
    if not shop or not slot or not canUseShop(shop) then return end
    local model = showroom[shop] and showroom[shop][slot]
    if not model then return end
    local v = QBCore.Shared.Vehicles[model] or {}
    local menu = {
        {
            isMenuHeader = true,
            icon = 'fa-solid fa-circle-info',
            header = ('%s %s - $%s'):format((v.brand or ''):upper(), (v.name or model):upper(), VShared.Comma(v.price)),
        }
    }
    if Config.Shops[shop].Type == 'managed' then
        menu[#menu + 1] = { header = Lang:t('menus.test_header'), txt = Lang:t('menus.managed_test_txt'), icon = 'fa-solid fa-user-plus', params = act('customTestDrive', shop, slot) }
        menu[#menu + 1] = { header = Lang:t('menus.managed_sell_header'), txt = Lang:t('menus.managed_sell_txt'), icon = 'fa-solid fa-cash-register', params = act('sell', shop, slot) }
        menu[#menu + 1] = { header = Lang:t('menus.finance_header'), txt = Lang:t('menus.managed_finance_txt'), icon = 'fa-solid fa-coins', params = act('sellFinance', shop, slot) }
    else
        menu[#menu + 1] = { header = Lang:t('menus.test_header'), txt = Lang:t('menus.freeuse_test_txt'), icon = 'fa-solid fa-car-on', params = act('testdrive', shop, slot) }
        menu[#menu + 1] = { header = Lang:t('menus.freeuse_buy_header'), txt = Lang:t('menus.freeuse_buy_txt'), icon = 'fa-solid fa-hand-holding-dollar', params = act('buy', shop, slot) }
        menu[#menu + 1] = { header = Lang:t('menus.finance_header'), txt = Lang:t('menus.freeuse_finance_txt'), icon = 'fa-solid fa-coins', params = act('finance', shop, slot) }
    end
    menu[#menu + 1] = { header = Lang:t('menus.swap_header'), txt = Lang:t('menus.swap_txt'), icon = 'fa-solid fa-arrow-rotate-left', params = act('swap', shop, slot) }
    exports['qb-menu']:openMenu(menu)
end

RegisterNetEvent('qb-vehicleshop:client:homeMenu', function() openVehicleMenu() end)
RegisterNetEvent('qb-vehicleshop:client:showVehOptions', function() openVehicleMenu() end)

-- --- swap menus (built from a per-shop list made once) ---------------------
local function catalog(shop)
    local list = catalogs[shop]
    if list then return list end
    list = {}
    for model, v in pairs(QBCore.Shared.Vehicles) do
        if VShared.SoldInShop(QBCore.Shared.Vehicles, model, shop) then
            list[#list + 1] = { model = model, name = v.name or model, brand = v.brand or '', category = v.category or 'other', price = v.price or 0 }
        end
    end
    catalogs[shop] = list
    return list
end

local function openVehicles(shop, slot, make, cat, oneCat)
    local back = oneCat
        and act(Config.FilterByMake and 'makes' or 'home', shop, slot)
        or act('cats', shop, slot, { make = make })
    local menu = { { header = Lang:t('menus.goback_header'), icon = 'fa-solid fa-angle-left', params = back } }
    for _, v in ipairs(catalog(shop)) do
        if v.category == cat and (not make or v.brand == make) then
            menu[#menu + 1] = {
                header = v.name,
                txt = Lang:t('menus.veh_price') .. VShared.Comma(v.price),
                icon = 'fa-solid fa-car-side',
                params = act('doSwap', shop, slot, { model = v.model }),
            }
        end
    end
    exports['qb-menu']:openMenu(menu, Config.SortAlphabetically, true)
end

local function openCategories(shop, slot, make)
    local cats, count, first = {}, 0, nil
    for _, v in ipairs(catalog(shop)) do
        if (not make or v.brand == make) and not cats[v.category] then
            cats[v.category] = true
            count = count + 1
            first = first or v.category
        end
    end
    if Config.HideCategorySelectForOne and count == 1 then return openVehicles(shop, slot, make, first, true) end
    local menu = {
        { header = Lang:t('menus.goback_header'), icon = 'fa-solid fa-angle-left', params = act(Config.FilterByMake and 'makes' or 'home', shop, slot) }
    }
    for cat in pairs(cats) do
        menu[#menu + 1] = { header = cat, icon = 'fa-solid fa-circle', params = act('vehicles', shop, slot, { make = make, cat = cat }) }
    end
    exports['qb-menu']:openMenu(menu, Config.SortAlphabetically, true)
end

local function openMakes(shop, slot)
    local makes = {}
    local menu = { { header = Lang:t('menus.goback_header'), icon = 'fa-solid fa-angle-left', params = act('home', shop, slot) } }
    for _, v in ipairs(catalog(shop)) do
        if not makes[v.brand] then
            makes[v.brand] = true
            menu[#menu + 1] = { header = v.brand, icon = 'fa-solid fa-circle', params = act('cats', shop, slot, { make = v.brand }) }
        end
    end
    exports['qb-menu']:openMenu(menu, Config.SortAlphabetically, true)
end

-- --- inputs ------------------------------------------------------------------
local function financeInput(model, withId)
    local v = QBCore.Shared.Vehicles[model] or {}
    local inputs = {
        { type = 'number', isRequired = true, name = 'downPayment', text = Lang:t('menus.financesubmit_downpayment') .. Config.MinimumDown .. '%' },
        { type = 'number', isRequired = true, name = 'paymentAmount', text = Lang:t('menus.financesubmit_totalpayment') .. Config.MaximumPayments },
    }
    if withId then inputs[3] = { type = 'number', isRequired = true, name = 'playerid', text = Lang:t('menus.submit_ID') } end
    local dialog = exports['qb-input']:ShowInput({
        header = ('%s %s - $%s'):format((v.brand or ''):upper(), (v.name or model):upper(), VShared.Comma(v.price)),
        submitText = Lang:t('menus.submit_text'),
        inputs = inputs,
    })
    if not dialog or not dialog.downPayment or not dialog.paymentAmount or (withId and not dialog.playerid) then return nil end
    return dialog
end

local function idInput(model)
    local dialog = exports['qb-input']:ShowInput({
        header = vehLabel(model),
        submitText = Lang:t('menus.submit_text'),
        inputs = { { text = Lang:t('menus.submit_ID'), name = 'playerid', type = 'number', isRequired = true } }
    })
    return dialog and dialog.playerid and dialog or nil
end

RegisterNetEvent('qb-vehicleshop:client:legacyAction', function(a)
    if type(a) ~= 'table' then return end
    local shop, slot = a.shop, a.slot
    local model = showroom[shop] and showroom[shop][slot]
    if not model then return end
    local action = a.action

    if action == 'home' then
        openVehicleMenu(shop, slot)
    elseif action == 'swap' or action == 'makes' then
        if Config.FilterByMake then openMakes(shop, slot) else openCategories(shop, slot) end
    elseif action == 'cats' then
        openCategories(shop, slot, a.make)
    elseif action == 'vehicles' then
        openVehicles(shop, slot, a.make, a.cat)
    elseif action == 'doSwap' then
        TriggerServerEvent('qb-vehicleshop:server:swapVehicle', shop, slot, a.model)
    elseif action == 'testdrive' then
        if VShopC.InTestDrive() then return QBCore.Functions.Notify(Lang:t('error.testdrive_alreadyin'), 'error') end
        TriggerServerEvent('qb-vehicleshop:server:testDrive', shop, slot)
    elseif action == 'buy' then
        TriggerServerEvent('qb-vehicleshop:server:buyShowroomVehicle', shop, slot)
    elseif action == 'finance' then
        local d = financeInput(model, false)
        if d then TriggerServerEvent('qb-vehicleshop:server:financeVehicle', shop, slot, d.downPayment, d.paymentAmount) end
    elseif action == 'customTestDrive' then
        local d = idInput(model)
        if d then TriggerServerEvent('qb-vehicleshop:server:customTestDrive', shop, slot, d.playerid) end
    elseif action == 'sell' then
        local d = idInput(model)
        if d then TriggerServerEvent('qb-vehicleshop:server:sellShowroomVehicle', shop, slot, d.playerid) end
    elseif action == 'sellFinance' then
        local d = financeInput(model, true)
        if d then TriggerServerEvent('qb-vehicleshop:server:sellfinanceVehicle', shop, slot, d.downPayment, d.paymentAmount, d.playerid) end
    end
end)

-- --- display cars (local, streamed by distance) -------------------------------
local function clearSlot(shop, slot)
    local list = display[shop]
    local entry = list and list[slot]
    if not entry then return end
    list[slot] = nil
    if entry.veh then
        if Config.UsingTarget and DoesEntityExist(entry.veh) then exports['qb-target']:RemoveTargetEntity(entry.veh) end
        VShopC.DeleteLocal(entry.veh)
    end
end

local function clearShop(shop)
    local list = display[shop]
    if not list then return end
    for slot in pairs(list) do clearSlot(shop, slot) end
    display[shop] = nil
end

local function spawnSlot(shop, slot)
    local model = showroom[shop] and showroom[shop][slot]
    if not model then return end
    display[shop] = display[shop] or {}
    if display[shop][slot] then return end
    local entry = { model = model }
    display[shop][slot] = entry -- placeholder while the model loads
    local veh = VShopC.SpawnDisplay(entry.model, Config.Shops[shop].ShowroomVehicles[slot].coords, 'BUY ME')
    if not (display[shop] and display[shop][slot] == entry) then -- removed / swapped while loading
        VShopC.DeleteLocal(veh)
        return
    end
    entry.veh = veh
    if veh and Config.UsingTarget then
        exports['qb-target']:AddTargetEntity(veh, {
            options = { {
                icon = 'fas fa-car',
                label = Lang:t('general.vehinteraction'),
                action = function() openVehicleMenu(shop, slot) end,
                canInteract = function() return canUseShop(shop) end,
            } },
            distance = 3.0
        })
    end
end

RegisterNetEvent('qb-vehicleshop:client:swapVehicle', function(shop, slot, model)
    if type(shop) ~= 'string' or not showroom[shop] or not showroom[shop][slot] or type(model) ~= 'string' then return end
    showroom[shop][slot] = model
    if display[shop] and display[shop][slot] then
        clearSlot(shop, slot)
        spawnSlot(shop, slot)
    end
end)

CreateThread(function()
    while not showroomReady do
        local p = promise.new()
        QBCore.Functions.TriggerCallback('qb-vehicleshop:server:getShowroom', function(s) p:resolve(s) end)
        local s = Citizen.Await(p)
        if type(s) == 'table' and next(s) then
            showroom = s
            showroomReady = true
        else
            Wait(5000)
        end
    end

    for _, shop in pairs(Config.Shops) do
        if shop.showBlip then VShopC.AddBlip(shop.Location, shop.blipSprite, shop.blipColor, 0.7, shop.ShopLabel) end
    end

    while true do
        local sleep = 1500
        local pos = GetEntityCoords(PlayerPedId())
        local found = nil
        for name, shop in pairs(Config.Shops) do
            local d = #(pos - shop.Location)
            if d < STREAM_DIST then
                for slot in ipairs(shop.ShowroomVehicles) do spawnSlot(name, slot) end
            elseif display[name] then
                clearShop(name)
            end
            if not found and d < 100.0 and VShared.InShop(name, pos, 3.0) then found = name end
        end

        if found ~= insideShop then
            insideShop, closestSlot = found, nil
            if headerShown then
                headerShown = false
                exports['qb-menu']:closeMenu()
            end
        end

        if insideShop then
            sleep = 500
            local shop = Config.Shops[insideShop]
            local best, bestD = nil, nil
            for slot, v in ipairs(shop.ShowroomVehicles) do
                local dx, dy = pos.x - v.coords.x, pos.y - v.coords.y
                local d2 = dx * dx + dy * dy
                if not bestD or d2 < bestD then best, bestD = slot, d2 end
            end
            closestSlot = best
            if not Config.UsingTarget and best then
                local c, half = shop.ShowroomVehicles[best].coords, (shop.Zone.size or 2.75) / 2
                local inBox = math.abs(pos.x - c.x) <= half and math.abs(pos.y - c.y) <= half and canUseShop(insideShop)
                if inBox ~= headerShown then
                    headerShown = inBox
                    if inBox then exports['qb-menu']:showHeader(vehHeaderMenu) else exports['qb-menu']:closeMenu() end
                end
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for shop in pairs(display) do clearShop(shop) end
end)
