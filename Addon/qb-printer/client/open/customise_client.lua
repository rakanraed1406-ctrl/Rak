QBCore, ESX = nil, nil
if Config.Core == "QBCore" then
	QBCore = exports[Config.CoreFolderName]:GetCoreObject()
	Citizen.CreateThread(function()
		while QBCore == nil do
			TriggerEvent(Config.Core..':GetObject', function(obj) QBCore = obj end)
			Citizen.Wait(200)
		end
	end)
elseif Config.Core == "ESX" then
	ESX = exports[Config.CoreFolderName]:getSharedObject()
end

CreateThread(function()
    if Config.Inventory == "ox" then
        exports.ox_inventory:displayMetadata({
            documentname = "Document Name"
        })
    end
end)

RegisterNetEvent(Config.PlayerLoadedEvent)
AddEventHandler(Config.PlayerLoadedEvent, function()
    TriggerServerEvent('qb-printer:server:GetPrinterData')
    AddPropToPlayerAndDelete('clipboard', 36029, 0.16, 0.08, 0.1, -130.0, -50.0, 0.0)
end)

AddEventHandler("onResourceStart", function(name)
    if GetCurrentResourceName() ~= name then
        return
    end
    Wait(100)
    TriggerServerEvent('qb-printer:server:GetPrinterData')
    AddPropToPlayerAndDelete('clipboard', 36029, 0.16, 0.08, 0.1, -130.0, -50.0, 0.0)
end)

RegisterNetEvent("qb-printer:client:printDocument")
AddEventHandler("qb-printer:client:printDocument", function(data, nearestPrinter)
    TriggerServerEvent('InteractSound_SV:PlayWithinDistance', 2.0, 'printer', 0.2)
    if lib.progressCircle({
        duration = 5000,
        label = Config.Locale["printing"],
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
        },
        position= 'bottom',
        anim = {
            dict = "random@shop_tattoo",
            clip =  "_idle_a"
        },
    }) then 
        TriggerServerEvent('qb-printer:server:printDocument', data, nearestPrinter) -- do not touch this event, needs to be triggered if progressbar is complete
    else 
        ShowNotification("Cancelled")
    end
end)

RegisterNetEvent("qb-printer:client:refillPrinter")
AddEventHandler("qb-printer:client:refillPrinter", function(k)
    if lib.progressCircle({
        duration = 5000,
        label = Config.Locale["refilling"],
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
        },
        position= 'bottom',
        anim = {
            dict = "random@shop_tattoo",
            clip =  "_idle_a"
        },
    }) then 
        TriggerServerEvent('qb-printer:server:refillPrinter', k) -- do not touch this event, needs to be triggered if progressbar is complete
    else 
        ShowNotification("Cancelled")
    end
end)

--event to trigger when item is used (since linden inventory has useItem event, just triggered that)
-- this event is triggered from server file

RegisterNetEvent("linden_inventory:useItem")
AddEventHandler("linden_inventory:useItem", function(ItemData)
    if ItemData.name == "printerdocument" then
        local ped = PlayerPedId()
        local DocumentUrl = ItemData.metadata.url ~= nil and ItemData.metadata.url or false
        local width = ItemData.metadata.width ~= nil and ItemData.metadata.width or 1920
        local height = ItemData.metadata.height ~= nil and ItemData.metadata.height or 1080
        ClearPedTasks(PlayerPedId())
        createDocument(DocumentUrl, width, height)
    end
end)


RegisterNetEvent("qb-printer:client:usePrinterDoc")
AddEventHandler("qb-printer:client:usePrinterDoc", function(ItemData)
    if ItemData.name == "printerdocument" then
        local ped = PlayerPedId()
        local DocumentUrl = ItemData.info.url ~= nil and ItemData.info.url or false
        local width = ItemData.info.width ~= nil and ItemData.info.width or 1920
        local height = ItemData.info.height ~= nil and ItemData.info.height or 1080
        ClearPedTasks(PlayerPedId())
        createDocument(DocumentUrl, width, height)
    end
end)

RegisterNetEvent("printer:showDocument")
AddEventHandler("printer:showDocument", function(ItemData)
    local ped = PlayerPedId()
    local DocumentUrl = ItemData.metadata.url ~= nil and ItemData.metadata.url or false
    local width = ItemData.metadata.width ~= nil and ItemData.metadata.width or 1920
    local height = ItemData.metadata.height ~= nil and ItemData.metadata.height or 1080
    ClearPedTasks(PlayerPedId())
    createDocument(DocumentUrl, width, height)
end)

function useDocument(data, itemInfo)
    TriggerEvent("printer:showDocument", itemInfo)
end

exports('useDocument', useDocument)

--for notifications

function ShowNotification(msg, type)

    if Config.Core == "QBCore" then
        QBCore.Functions.Notify(msg, type)
    elseif Config.Core == "ESX" then
        ESX.ShowNotification(msg)
    elseif Config.okokNotify then
		exports['okokNotify']:Alert(Config.OkOkNotifyTitle, msg, 5000, type)
	elseif Config.pNotify then
		exports.pNotify:SendNotification({text = msg, type = type,layout = Config.pNotifyLayout, timeout = 5000})
	elseif Config.mythicNotify then
		TriggerEvent('mythic_notify:client:SendAlert', {type = type, text = msg, length = 2500})
	end
end


function DrawText3Ds(x, y, z, text)
	local onScreen,_x,_y=World3dToScreen2d(x,y,z)
    local px,py,pz=table.unpack(GetGameplayCamCoords())
    
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(1)
    AddTextComponentString(text)
    DrawText(_x,_y)
    local factor = (string.len(text)) / 370
    DrawRect(_x,_y+0.0125, 0.015+ factor, 0.03, 41, 11, 41, 68)
end

function DrawTextFunc(x, y, z, papers, capacity)
    if x ~= nil and y ~= nil and z ~= nil and papers ~= nil and capacity ~= nil then
        if Config.ShowHelpNotification then
            ESX.ShowHelpNotification(Config.Locale["use"].." \n"..Config.Locale["paper_count"].." - ["..papers.."/"..capacity.."]    \n".. Config.Locale["refill"] )
        elseif Config.DrawText then
            DrawText3Ds(x, y , z+0.2, "~b~"..Config.Locale["paper_count"].."~w~ - ["..papers.."/"..capacity.."]   | ".. Config.Locale["refill"])
            DrawText3Ds(x, y , z, Config.Locale["use"])
        end
    end
end

-- used to open the printer ui using target or any other script (USAGE : exports['qb-printer']:OpenPrinterUI() )
function OpenPrinterUI()
     if not exports['qb-inventory']:HasItem("a4sheets", 1) then QBCore.Functions.Notify("You dont have Sheets", "error") return end
    TriggerEvent('animations:client:EmoteCommandStart', {"type4"})
    inPrinterUI = true
    SendNUIMessage({
        action = "start"
    })
    SetNuiFocus(true, true)
end

exports('OpenPrinterUI', OpenPrinterUI)


if Config.TargetPrinters then
    CreateThread(function()
        local PrinterModels = {
            'prop_printer_01',
            'prop_printer_02',
            -- 'v_res_printer',
            -- 'v_ret_gc_print',
            "v_med_cor_photocopy"
        }
        exports['qb-target']:AddTargetModel(PrinterModels, {
            options = {
                {
                    action = function()
                        OpenPrinterUI()
                    end,
                    type = 'client',
                    icon = "fa-solid fa-print",
                    label = "Use Printer",
                },
            },
            distance = 1.5,
        })
    end)
end
