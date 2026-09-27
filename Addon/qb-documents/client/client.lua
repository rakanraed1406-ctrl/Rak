QBCore = Config.CoreExport()
local isDocumentOpened = false

Citizen.CreateThread(function()
    local inRange = false
    local isShowed = false
    while Config.UseMarker and Config.MustMakePhoto do
        sleep = 1500
        inRange = false
        local myPed = PlayerPedId()
        local myCoords = GetEntityCoords(myPed)
        local distance = #(Config.Marker.coords - myCoords)
        if distance < 10.0 then
            sleep = 1
            --DrawMarker(Config.Marker.markerId, Config.Marker.coords, 0, 0, 0, 0, 0, 0, Config.Marker.size, Config.Marker.color[1], Config.Marker.color[2], Config.Marker.color[3], Config.Marker.color[4], false, false, false, Config.Marker.rotate, false, false, false)
        end
        if distance < 1.25 then
            if IsControlJustPressed(0, 38) then
                inRange = false
                TriggerEvent("qb-documents:doPhoto")
            end
        end
        if inRange and not isShowed then
            if Config.PhotoPrice > 0 then
                Config.Interact.Open("E", Config.Texts["interact_paid_photo"])
            else
                Config.Interact.Open("E", Config.Texts["interact_free_photo"])
            end
            isShowed = true
        elseif not inRange and isShowed then
            Config.Interact.Close()
            isShowed = false
        end
        Citizen.Wait(1)
    end
end)

RegisterNetEvent("qb-documents:doPhoto")
AddEventHandler("qb-documents:doPhoto", function()
    local mugshotBase = exports.MugShotBase64:GetMugShotBase64(PlayerPedId(), false)
    TriggerServerEvent("qb-document:saveMugshot", mugshotBase)
end)

RegisterNetEvent("qb-document:showMyDocument")
AddEventHandler("qb-document:showMyDocument", function(type)
    QBCore.Functions.TriggerCallback("qb-document:getImage", function(url)
        if url then
            TriggerServerEvent("qb-document:show", type, url)
        else
            if Config.MustMakePhoto then
                Config.Notification(Config.Texts["notify_title"], Config.Texts["no_have_photo"], 2500, "fa fa-address-card", "error")
            else
                local mugshotBase = exports.MugShotBase64:GetMugShotBase64(PlayerPedId(), false)
                TriggerServerEvent("qb-document:saveMugshot", mugshotBase)
                while mugshotBase do
                    QBCore.Functions.TriggerCallback("qb-document:getImage", function(url)
                        if url then
                            TriggerServerEvent("qb-document:show", type, url)
                        end
                    end)
                    break
                end
            end
        end
    end)
end)


-- RegisterNetEvent("qb-document:client:send")
-- AddEventHandler("qb-document:client:send", function(type, documentInfos, imageUrl)
--     if not isDocumentOpened then
--         isDocumentOpened = true
--         SendNUIMessage({
--             action = 'open',
--             documentInfos = documentInfos,
--             documentOptions = Config.Documents[type],
--             type = type,
--             playerImage = imageUrl,
--         })
--         while isDocumentOpened do
--             Citizen.Wait(1)
--             Citizen.Wait(Config.timeout)
--                 isDocumentOpened = false
--                 SendNUIMessage({action = 'close'})
--         end
--     end
-- end)

RegisterNetEvent("qb-document:client:send")
AddEventHandler("qb-document:client:send", function(type, documentInfos, imageUrl)
    if not isDocumentOpened then
        isDocumentOpened = true
        exports['qb-ui']:DrawText9("Stop Showing Your Card")
        SendNUIMessage({
            action = 'open',
            documentInfos = documentInfos,
            documentOptions = Config.Documents[type],
            type = type,
            playerImage = imageUrl,
        })
        while isDocumentOpened do
            Citizen.Wait(1)
            if IsControlJustPressed(0, 23) then
                isDocumentOpened = false
                exports['qb-ui']:HideText()
                TriggerEvent('animations:client:EmoteCommandStart', {"c"})
                SendNUIMessage({action = 'close'})
        end
    end
end
end)

RegisterNetEvent("qb-document:client:notify")
AddEventHandler("qb-document:client:notify", function(title, msg, time, icon, type)
    Config.Notification(title, msg, time, icon, type)
end)

RegisterNetEvent('qb-document:client:animation', function()
    TriggerEvent('animations:client:EmoteCommandStart', {"idcardshow"})
    idcard = CreateObject(`p_ld_id_card_01`, 1.0, 1.0, 1.0, 1, 1, 0)
    AttachEntityToEntity(idcard, ped, GetPedBoneIndex(ped, 18905),0.167,0.059,0.07,220.0,-54.0,20.00, 1, 0, 0, 0, 2, 1)
end)

function loadAnimDict(dict)
    while (not HasAnimDictLoaded(dict)) do
        RequestAnimDict(dict)
        Wait(5)
    end
end
