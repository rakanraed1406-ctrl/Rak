Keys = {
    ['ESC'] = 322, ['F1'] = 288, ['F2'] = 289, ['F3'] = 170, ['F5'] = 166, ['F6'] = 167, ['F7'] = 168, ['F8'] = 169, ['F9'] = 56, ['F10'] = 57,
    ['~'] = 243, ['1'] = 157, ['2'] = 158, ['3'] = 160, ['4'] = 164, ['5'] = 165, ['6'] = 159, ['7'] = 161, ['8'] = 162, ['9'] = 163, ['-'] = 84, ['='] = 83, ['BACKSPACE'] = 177,
    ['TAB'] = 37, ['Q'] = 44, ['W'] = 32, ['E'] = 38, ['R'] = 45, ['T'] = 245, ['Y'] = 246, ['U'] = 303, ['P'] = 199, ['['] = 39, [']'] = 40, ['ENTER'] = 18,
    ['CAPS'] = 137, ['A'] = 34, ['S'] = 8, ['D'] = 9, ['F'] = 23, ['G'] = 47, ['H'] = 74, ['K'] = 311, ['L'] = 182,
    ['LEFTSHIFT'] = 21, ['Z'] = 20, ['X'] = 73, ['C'] = 26, ['V'] = 0, ['B'] = 29, ['N'] = 249, ['M'] = 244, [','] = 82, ['.'] = 81,
    ['LEFTCTRL'] = 36, ['LEFTALT'] = 19, ['SPACE'] = 22, ['RIGHTCTRL'] = 70,
    ['HOME'] = 213, ['PAGEUP'] = 10, ['PAGEDOWN'] = 11, ['DELETE'] = 178,
    ['LEFT'] = 174, ['RIGHT'] = 175, ['TOP'] = 27, ['DOWN'] = 173,
}

local printer_props = {}
local nearestPrinter = nil
local inPrinterUI = false
local isRefilling = false
local txdChanged = false
local duiObj = nil
local clipboard_prop = nil
local cancelled = false


Citizen.CreateThread(function()
    while true do
        Citizen.Wait(100)
        local pos = GetEntityCoords(PlayerPedId())
        for k, v in ipairs(Config.Printer) do
            if v.model ~= nil then
                if #(pos - v.coords) <= 50.0 then
                    if printer_props[k] == nil or not DoesEntityExist(printer_props[k]) then
                        printer_props[k] = SpawnPrinter(k)
                    end
                else
                    if printer_props[k] ~= nil and DoesEntityExist(printer_props[k]) then
                        DeleteEntity(printer_props[k])
                    end
                end
            end
        end
    end
end)

function SpawnPrinter(id)
    local data = Config.Printer[id]
    local pos = vector3(data.coords[1], data.coords[2], data.coords[3]+data.z_offset)
    LoadPropDict(data.model)
    local printer = CreateObject(GetHashKey(data.model), pos, false, false, false)
    SetEntityHeading(printer, data.heading)
    FreezeEntityPosition(printer, true)
    return printer
end


-- Code

AddEventHandler('onResourceStop', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then
        return
    end
    for k, v in pairs(printer_props) do
        DeleteEntity(v)
    end
end)


RegisterNetEvent('qb-printer:client:SyncPrinterStatus')
AddEventHandler('qb-printer:client:SyncPrinterStatus', function(data)
    Config.Printer = data
end)

RegisterNUICallback('CloseDocument', function()
    inPrinterUI = false
    SetNuiFocus(false, false)
    TriggerEvent('animations:client:EmoteCommandStart', {"c"})
end)

RegisterNUICallback('Invalid', function()
    SetNuiFocus(false, false)
    ShowNotification(Config.Locale["file_url_required"], "error")
    inPrinterUI = false
end)

RegisterNUICallback('EmptyName', function()
    SetNuiFocus(false, false)
    ShowNotification(Config.Locale["file_name"], "error")
    inPrinterUI = false
end)

RegisterNUICallback('PrintDocument', function(data)

    if tonumber(data.amount) > Config.MaxDocumentsToPrint then
        ShowNotification(Config.Locale["max_documents"], "error")
        inPrinterUI = false
        SetNuiFocus(false, false)
        return
    end
    SetNuiFocus(false, false)
    ClearPedTasks(PlayerPedId())
    if Config.RestrictMode then
        local match = false 
        for k, v in pairs(Config.AllowedChannels) do 
            if string.find(data.url, v) ~= nil then
                match = true
                break
            end 
        end
        if not match then
            ShowNotification(Config.Locale["wrong_image"], 'error')
            inPrinterUI = false
            return
        end
    end
    if nearestPrinter then
        if Config.Printer[nearestPrinter].count > 0 and Config.Printer[nearestPrinter].count >= tonumber(data.amount) then
            TriggerEvent("qb-printer:client:printDocument", data, nearestPrinter)
            inPrinterUI = false
            cancelled = false
        else
            ShowNotification(Config.Locale["not_enough_papers"], "error")
            inPrinterUI = false
        end
    else
        TriggerEvent("qb-printer:client:printDocument", data, nearestPrinter)
    end
    inPrinterUI = false
    cancelled = false
    SetNuiFocus(false, false)
end)

Citizen.CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        inRange = false

        if not inPrinterUI then
            for k, v in pairs(Config.Printer) do
                if v.show3dText then
                    if #(v.coords - pos) <= v.radius then
                        inRange = true
                        local papers = v.count
                        local capacity = v.capacity
                        DrawTextFunc(v.coords.x, v.coords.y, v.coords.z, v.count, v.capacity)
                        if IsControlJustPressed(0, Keys["K"]) then
                            local space = v.capacity - v.count 
                            local hasItem = lib.callback.await('qb-printer:checkItem', false)
                            if hasItem then
                                if space >= 20 then
                                    isRefilling = true
                                    TriggerEvent("qb-printer:client:refillPrinter", k)                    
                                    isRefilling = false
                                else
                                    ShowNotification(Config.Locale["not_enough_sheets"], "error")
                                end
                            else 
                                ShowNotification(Config.Locale["no_sheets"], 'error')
                            end
                        end
                    end
                end
            end
        end

        if DoesEntityExist(clipboard_prop) then
            inRange = true
            if IsControlJustPressed(0, Keys["X"]) then
                DeleteEntity(clipboard_prop)
                ClearPedTasks(PlayerPedId())
                if txdChanged then
                    DestroyDui(duiObj)
                    AddReplaceTexture('clipboard', 'white1', 'clipboard', 'white1')
                    txdChanged = false
                end
            end
        end

        if not inRange then
            Citizen.Wait(1000)
        end

        Citizen.Wait(3)
    end
end)

function createDocument(url, width, height)
    if DoesEntityExist(clipboard_prop) then
        DeleteEntity(clipboard_prop)
    end
    txdChanged = true
    local txd = CreateRuntimeTxd('doc_txd')
    duiObj = CreateDui(url, width, height)
    local dui = GetDuiHandle(duiObj)
    local tx = CreateRuntimeTextureFromDuiHandle(txd, "doc_png", dui)
    while not IsDuiAvailable(duiObj) do
        Citizen.Wait(0)
        if Config.Debug then
            print("Waiting for dui to be available")
        end
    end
    AddReplaceTexture('clipboard', 'white1', 'doc_txd', "doc_png")
    Wait(200)
    addClipBoard()
end

function addClipBoard()
    if Config.Debug then
        print("Adding clipboard")
    end
    LoadAnim("missfam4")
    TaskPlayAnim(PlayerPedId(), "missfam4", "base", 2.0, 2.0, -1, 51, 0, false, false, false)
    AddPropToPlayer('clipboard', 36029, 0.16, 0.08, 0.1, -130.0, -50.0, 0.0)
end

function AddPropToPlayer(prop1, bone, off1, off2, off3, rot1, rot2, rot3)
    local Player = PlayerPedId()
    local x,y,z = table.unpack(GetEntityCoords(Player))
  
    if not HasModelLoaded(prop1) then
      LoadPropDict(prop1)
    end
  
    clipboard_prop = CreateObject(GetHashKey(prop1), x, y, z+0.2,  true,  true, true)
    AttachEntityToEntity(clipboard_prop, Player, GetPedBoneIndex(Player, bone), off1, off2, off3, rot1, rot2, rot3, true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(prop1)
end

function AddPropToPlayerAndDelete(prop1, bone, off1, off2, off3, rot1, rot2, rot3)
    local Player = PlayerPedId()
    local x,y,z = table.unpack(GetEntityCoords(Player))
  
    if not HasModelLoaded(prop1) then
      LoadPropDict(prop1)
    end
  
    clipboard_prop = CreateObject(GetHashKey(prop1), x, y, z+0.2,  true,  true, true)
    AttachEntityToEntity(clipboard_prop, Player, GetPedBoneIndex(Player, bone), off1, off2, off3, rot1, rot2, rot3, true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(prop1)
    DeleteEntity(clipboard_prop)
end

function LoadAnim(dict)
    while not HasAnimDictLoaded(dict) do
      RequestAnimDict(dict)
      Wait(10)
    end
  end
  
function LoadPropDict(model)
    while not HasModelLoaded(GetHashKey(model)) do
        RequestModel(GetHashKey(model))
        Wait(10)
    end
end
