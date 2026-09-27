Config = {}

-- ███████ ██████   █████  ███    ███ ███████ ██     ██  ██████  ██████  ██   ██ 
-- ██      ██   ██ ██   ██ ████  ████ ██      ██     ██ ██    ██ ██   ██ ██  ██  
-- █████   ██████  ███████ ██ ████ ██ █████   ██  █  ██ ██    ██ ██████  █████   
-- ██      ██   ██ ██   ██ ██  ██  ██ ██      ██ ███ ██ ██    ██ ██   ██ ██  ██  
-- ██      ██   ██ ██   ██ ██      ██ ███████  ███ ███   ██████  ██   ██ ██   ██


Config = {
    webhook = "",
}

Config.Core = "QBCore" -- ESX or QBCore
Config.CoreFolderName = "qb-core"  -- es_extended || qb-core

Config.PlayerLoadedEvent = " QBCore:Client:OnPlayerLoaded" -- esx:playerLoaded || QBCore:Client:OnPlayerLoaded
Config.PlayerUnloadEvent = "QBCore:Client:OnPlayerUnload" -- esx:onPlayerLogout || QBCore:Client:OnPlayerUnload     


Config.Inventory = "qb" -- ox || qb || qsv2 || qs

Config.ShowHelpNotification = false
Config.DrawText = false

-- Target supports only qb-target / qtarget or ox-target
Config.TargetPrinters = true -- Set to true if you want to see the printers in the world (this wont take the paper count and people can print unlimited documents without refilling)
Config.MaxDocumentsToPrint = 10 -- Maximum number of documents that can be printed at a time

Config.Debug = false

Config.Printer = {
    [1] = {coords = vector3(321.51, -575.5, 43.27), heading = 342.79, model = "v_med_cor_photocopy", z_offset = -1.0, count = 20, capacity = 100, radius = 2.0, show3dText = true},
    [2] = {coords = vector3(-531.84, -179.25, 38.23), heading = 295.0, model = "v_med_cor_photocopy", z_offset = -1.0, count = 20, capacity = 100, radius = 2.0, show3dText = true},
    -- [3] = {coords = vector3(452.69, -972.0, 35.09), heading = 0.52, model = "v_med_cor_photocopy", z_offset = -1.0, count = 20, capacity = 100, radius = 2.0, show3dText = true},
    -- [4] = {coords = vector3(471.45, -984.29, 30.69), heading = 87.42, model = "v_med_cor_photocopy", z_offset = -1.0, count = 20, capacity = 100, radius = 2.0, show3dText = true},
    [3] = {coords = vector3(-281.14, 290.26, 89.89), heading = 265.25, model = "v_med_cor_photocopy", z_offset = -1.0, count = 20, capacity = 100, radius = 2.0, show3dText = true},
    [4] = {coords = vector3(-582.69, -212.04, 38.23), heading = 32.88, model = "v_med_cor_photocopy", z_offset = -1.0, count = 20, capacity = 100, radius = 2.0, show3dText = true},
    [5] = {coords = vector3(-682.03, 337.31, 83.08), heading = 263.19, model = "v_med_cor_photocopy", z_offset = -0.9, count = 50, capacity = 100, radius = 2.0, show3dText = true}, 
    [6] = {coords = vector3(-246.71, 208.47, 92.09), heading = 271.33, model = "v_med_cor_photocopy", z_offset = -0.9, count = 50, capacity = 100, radius = 2.0, show3dText = true}, 
}
-- Add new coord and heading 
-- model (spawn machine prop name, should be nil if you dont want to spawn the prop)
-- some props name that you can use - "prop_printer_01", "prop_printer_02", "v_res_printer", "v_ret_gc_print"
-- capacity (Maximum number of A4 sheets machine can carry)
-- count (Initial count of A4 sheets in printer, when resource start)
-- z_offset to align prop vertically (perfect placement to ground), else set z_offset = 0.0

--[[
    * Notify Config
    * Set only one to true 
    * Config.QBCoreNotify - Uses default QBCore notify system
    * Config.okokNotify - Uses OkOkNotify system
    * Config.pNotify - Uses pNotify system

    * Config.pNotifyLayout - set layout of where the notification will show. Check the layouts below. 
    * Layouts:
                top
                topLeft
                topCenter
                topRight
                center
                centerLeft
                centerRight
                bottom
                bottomLeft
                bottomCenter
                bottomRight
    
    * Config.OkOkNotifyTitle - Title to show on okokNotify
]]--

Config.okokNotify = false -- Set to true if you are using base OKOK notify system
Config.pNotify = false -- Set to true if you are using base  pNotify system
Config.mythicNotify = true -- Set to true if you are using mythic notify system

Config.pNotifyLayout = "centerRight" --more options can be found in pNotify Readme. Make sure you put the right layout name.
Config.OkOkNotifyTitle = "HP Printer" --Title that displays on okoknotify


--Format of Config.Locale
--[[
    * name = label
    * Do not alter the name (for eg. ["invalid_url"] -> do not change this)
    * change the label (for eg. "Invalid URL!" can be changed to whatever you want.)
]]--

Config.Locale = {
    ["invalid_url"] = "Invalid URL!",
    ["file_url_required"] = "File URL required",
    ["file_name"] = "File Name required",
    ["not_enough_sheets"] = "Not have enough space for more A4 Sheets",
    ["no_sheets"] = "You do not have A4 Sheets!",
    ["refilling"] = "Refilling A4 Sheets",
    ["printing"] = "Printing Document",
    ["paper_count"] = "Paper Count",
    ["refill"] = "~r~K~w~ - Refill",
    ["use"] = '~g~E~w~ - Use',
    ["wrong_image"] = "Image not present in the right discord channel",
    ["not_enough_papers"] = "Printer doesnt have enough papers",
    ["max_documents"] = "You can only print max "..Config.MaxDocumentsToPrint.." at a time"
}

Config.RestrictMode = false --set to to true if you want to restrict people from using any images and use only the images from Allowed Channels

Config.AllowedChannels = { --Allowed Discord channels for PNG upload
    "https://cdn.discordapp.com/attachments/909905066671108136",  -- the number after "attachments/" is the channel id, to get that, just right click on the channel and copy id (for now this is the teasers channel on my discord)
}
