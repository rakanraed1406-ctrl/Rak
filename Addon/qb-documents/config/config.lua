Config = {}

Config.CoreExport = function()
    return exports['qb-core']:GetCoreObject()
end

Config.Notification = function(title, msg, time, icon, type)
    if type == "success" then
        QBCore.Functions.Notify(msg, "success", 5000)
    elseif type == "error" then
        QBCore.Functions.Notify(msg, "error", 5000)
    end
end

-- Config.Interact = {
--     Enabled = true,
--     Open = function(key, msg)
--         --exports["interact"]:Open(key, msg)
--         exports['qb-ui']:DrawText(msg)
--     end,
--     Close = function()
--         --exports["interact"]:Close()
--         exports['qb-ui']:HideText()
--     end
-- }
Config.timeout = 9000
Config.MustMakePhoto = true
Config.PhotoPrice = 250

Config.UseMarker = false
if Config.UseMarker then
    Config.Marker = {
        markerId = 1,
        coords = vector3(-233.22, -915.27, 32.31),--vector3(-544.03, -197.28, 38.23)
        size = vec(1.0, 1.0, 1.0),
        color = {60, 120, 250, 121},
        rotate = true
    }
end

Config.DisplayTexts = {
    ["drive_bike"] = {
        have = "A",
        notHave = "A"
    },
    ["drive"] = {
        have = "B",
        notHave = "B",
    },
    ["drive_truck"] = {
        have = "C",
        notHave = "C",
    },
    ["drive_boat"] = {
        have = "YES",
        notHave = "NO",
    },
    ["flying_helicopter"] = {
        have = "Helicopter",
        notHave = "Helicopter",
    },
    ["flying_plane"] = {
        have = "Plane",
        notHave = "Plane",
    },
    ["weapon"] = {
        have = "YES",
        notHave = "NO",
    },
    ["jaber"] = {
        have = "YES",
        notHave = "NO",
    }
}

Config.Documents = {
    ["id_card"] = {
        item = 'id_card', -- nil if you want to use e.g. via trigger, if you want to use as an item set "itemname"
        color = "#ff5f03f1",
        header = "ID CARD",
        icon = "person", -- https://fonts.google.com/icons
        notifyText = "You showed the id card.",
    },
    ["id_drive"] = {
        item = 'driver_license',
        color = "#ff5f03f1",
        header = "DRIVE LICENSE",
        icon = "directions_car",
        notifyText = "You showed the driving license.",
    },
    ["id_boat"] = {
        item = nil,
        color = "#ff5f03f1",
        header = "BOAT LICENSE",
        icon = "directions_boat",
        notifyText = "You showed the boat license.",
    },
    ["id_weapon"] = {
        item = 'weaponlicense',
        color = "#ff5f03f1",
        header = "WEAPON LICENSE",
        icon = "crisis_alert",
        notifyText = "You showed the weapon license.",
    },
    ["id_law"] = {
        item = 'lawyerpass',
        color = "#ff5f03f1",
        header = "LAW LICENSE",
        icon = "Gavel",
        notifyText = "You showed the LAW license.",
    },
}

Config.Texts = {
    ["notify_title"] = "DOCUMENTS",
    ["notify_title_photo"] = "PHOTO",
    ["no_have_photo"] = "You do not have an picture to the document. You have to make them first.",
    ["you_paid_for_photo"] = "You paid %s$ to take a photo for documents",
    ["document_pay_reason"] = "صور للوثائق",
    ["you_do_photo"] = "You took a picture for your documents.",
    ["not_have_money"] = "You don't have enough money to take a picture.",
    ['interact_free_photo'] = "TAKE A PHOTO",
    ["male"] = 'male',
    ["female"] = 'female',
}
