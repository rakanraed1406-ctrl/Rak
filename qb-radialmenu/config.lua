local DutyVehicles = {}
HasHandCuffs = false

Config = Config or {}

-- false = the wheel uses its own sound set (html/js/RadialMenu.js, WheelSfx in html/ui.html).
-- true  = also play the old GTA "NAV" frontend sound on open/close/select.
Config.GameSounds = false

Config.Keys = {["F1"] = 288}
Config.Locale = "en"
Config.Menu = {}
Config.isPlayerDead = function()
    return exports['qb-hospital']:isPlayerDead()
end


Config.Menu[#Config.Menu + 1] = {
    id = "citizen",
    displayName = "Citizen",
    icon = "#citizen-action",
    enableMenu = function()
        if not Config.isPlayerDead() then
            return true
        end
    end,
    subMenus = {"citizen:escort",'citizen:steal', 'citizen:givecash',"citizen:contact", 'citizen:vehicle:getout', 'citizen:vehicle:getin', 'citizen:Kidnap'}
}


-- Config.Menu[#Config.Menu + 1] = {
--     id = "Clothing-Menu",
--     displayName = "Clothing",
--     icon = "#global-kleren",
--     close = true,
--     functiontype = "client",
--     functionName = "veh:options",
--     enableMenu = function()
--         if not Config.isPlayerDead() then
--             return true
--         end
--     end,
--     subMenus = {
--         "clothes:Hat",
--         "clothes:Mask",
--         "clothes:Shirt",
--         "clothes:Pants",
--         "clothes:Gloves",
--         "clothes:Glasses",
--         "clothes:Shoes",
--     }
-- }

Config.Menu[#Config.Menu + 1] = {
    id = "blip",
    displayName = "Blips",
    icon = "#blips",
    enableMenu = function()
        if not Config.isPlayerDead() then
            return true
        end
    end,
    subMenus = {"blips:tattooshop", 'blips:barbershop','blips:gas', 'blips:clothing', 'blips:bennys'}
}


-- Config.Menu[#Config.Menu + 1] = {
--     id = "animations",
--     displayName = "Walkstyles",
--     icon = "#walking",
--     enableMenu = function()
--         if not Config.isPlayerDead() then
--             return true
--         end
--     end,
--     subMenus = { "animations:brave", "animations:hurry", "animations:business", "animations:tipsy", "animations:injured","animations:tough", "animations:default", "animations:hobo", "animations:money", "animations:swagger", "animations:shady", "animations:maneater", "animations:chichi", "animations:sassy", "animations:sad", "animations:posh", "animations:alien" }
-- }

Config.Menu[#Config.Menu + 1] = {
    id = "emotemenu",
    displayName = "Emote Menu",
    icon = "#general-emotes2",
    close = true,
    functiontype = "client",
    functionName = "emotes:openMenu",
    enableMenu = function()
        if not Config.isPlayerDead() then
            return true
        end
    end
}

-- Config.Menu[#Config.Menu + 1] = {
--     id = "expressions",
--     displayName = "Expressions",
--     icon = "#expressions",
--     enableMenu = function()
--         if not Config.isPlayerDead() then
--             return true
--         end
--     end,
--     subMenus = {"expressions:normal", "expressions:drunk", "expressions:angry", "expressions:dumb",
--                 "expressions:electrocuted", "expressions:grumpy", "expressions:happy", "expressions:injured",
--                 "expressions:joyful", "expressions:mouthbreather", "expressions:oneeye", "expressions:shocked",
--                 "expressions:sleeping", "expressions:smug", "expressions:speculative", "expressions:stressed",
--                 "expressions:sulking", "expressions:weird", "expressions:weird2"}
-- }

-- Config.Menu[#Config.Menu + 1] = {
--     id = "Clothing-Menu",
--     displayName = "Clothing",
--     icon = "#global-kleren",
--     close = true,
--     functiontype = "client",
--     functionName = "veh:options",
--     enableMenu = function()
--         if not Config.isPlayerDead() then
--             return true
--         end
--     end,
--     subMenus = {"clothes:Hat", "clothes:Mask", "clothes:Shirt", "clothes:Pants", "clothes:Gloves", "clothes:Glasses",
--                 "clothes:Shoes"}
-- }

Config.Menu[#Config.Menu + 1] = {
    id = "animations",
    displayName = "Walkstyles",
    icon = "#walking",
    enableMenu = function()
        if not Config.isPlayerDead() then
            return true
        end
    end,
    subMenus = {"animations:brave", "animations:hurry", "animations:business", "animations:tipsy", "animations:injured",
                "animations:tough", "animations:default", "animations:hobo", "animations:money", "animations:swagger",
                "animations:shady", "animations:maneater", "animations:chichi", "animations:sassy", "animations:sad",
                "animations:posh", "animations:alien"}
}

-- Config.Menu[#Config.Menu + 1] = {
--     id = "emotemenu",
--     displayName = "Emote Menu",
--     icon = "#walking",
--     close = true,
--     functiontype = "client",
--     functionName = "emotemenu:nurmal",
--     enableMenu = function()
--         if not Config.isPlayerDead() then
--             return true
--         end
--     end,
-- }

Config.Menu[#Config.Menu + 1] = {
    id = "luxury",
    displayName = "Luxury",
    icon = "#taxi-action",
    close = true,
    functiontype = "client",
    functionName = "qb-gjgj:client:OpenMenu",
    enableMenu = function()
        local PlayerData = QBCore.Functions.GetPlayerData()
        if not Config.isPlayerDead() and PlayerData.company.name == 'luxury' and (PlayerData.company.isboss or PlayerData.company.isowner) and exports['qb-gjgj']:isInShop() then
            return true
        end
    end,
}

Config.Menu[#Config.Menu + 1] = {
    id = "garage",
    displayName = "Parking",
    icon = "#garages-parking",
    close = true,
    functiontype = "client",
    functionName = "qb-garages:client:OpenGarageMenu",
    enableMenu = function()
        if not Config.isPlayerDead() then
            if exports['qb-garages']:GetIsInGarage() then
                return true
            end
        end
    end,
    -- subMenus = {"garage:putin", "garage:getout"}
}
Config.Menu[#Config.Menu + 1] = {
    id = "bennys",
    displayName = "Preview vehicle",
    icon = "#citizen-action-vehicle",
    close = true,
    functiontype = "client",
    functionName = "qb-mechanic:client:Preview:Menu",
    enableMenu = function()
        if not Config.isPlayerDead() then
            if exports['qb-mechanic']:GetisInShop() then
                return true
            end
        end
    end,
}
Config.Menu[#Config.Menu + 1] = {
    id = "police",
    displayName = "Police",
    icon = "#police",
    enableMenu = function()
        if not Config.isPlayerDead() and (QBCore.Functions.GetPlayerData().job.name == 'police' or QBCore.Functions.GetPlayerData().job.name == 'sheriff') and QBCore.Functions.GetPlayerData().job.onduty then
            return true
        end
    end,
    subMenus = {"police:search","police:bill", "police:jail","police:plate",'police:obj',"police:tablet"}
}

Config.Menu[#Config.Menu + 1] = {
    id = "police",
    displayName = "Dispatch Settings",
    icon = "#police-dispatch",
    enableMenu = function()
        return (not Config.isPlayerDead() and (QBCore.Functions.GetPlayerData().job.name == "police" or QBCore.Functions.GetPlayerData().job.name == "ambulance") and QBCore.Functions.GetPlayerData().job.onduty)
    end,
    subMenus = {"Dispatch:Open","Dispatch:Large","Dispatch:Resize"}
}

Config.Menu[#Config.Menu + 1] = {
    id = "taxi",
    displayName = "Taxi",
    icon = "#taxi-togglemeter",
    enableMenu = function()
        if not Config.isPlayerDead() and QBCore.Functions.GetPlayerData().job.name == 'taxi' and QBCore.Functions.GetPlayerData().job.onduty then
            return true
        end
    end,
    subMenus = {"taxi:togglemeter", "taxi:start", "taxi:npcmission"}
}
Config.Menu[#Config.Menu + 1] = {
    id = "tow-menu",
    displayName = "Towing",
    icon = "#mechanic-flatbed",
    enableMenu = function()
        if not Config.isPlayerDead() and QBCore.Functions.GetPlayerData().job.name == 'tow' then
            return true
        end
    end,
    subMenus = {"tow:npc", "tow:townpc", "tow:civ", 'tow:locaton'}
}
Config.Menu[#Config.Menu + 1] = {
    id = "police",
    displayName = "Radio",
    icon = "#police-radio",
    enableMenu = function()
        if not Config.isPlayerDead() and (QBCore.Functions.GetPlayerData().job.name == 'police' or QBCore.Functions.GetPlayerData().job.name == 'sheriff' or QBCore.Functions.GetPlayerData().job.name == 'ambulance') and QBCore.Functions.GetPlayerData().job.onduty then
            return true
        end
    end,
    subMenus = {"police:radio:one", "police:radio:two", "police:radio:three", "police:radio:four", "police:radio:five", "police:radio:6", "police:radio:7", "police:radio:8", "police:radio:9", "police:radio:10"}
}
Config.Menu[#Config.Menu + 1] = {
    id = "anchor",
    displayName = "Anchor",
    icon = "#citizen-action-garage",
    close = true,
    functiontype = "client",
    functionName = "qb-radialmenu:Anchor",
    enableMenu = function()
        if not Config.isPlayerDead() then
            local currVeh = GetVehiclePedIsIn(PlayerPedId(), false)
            if currVeh ~= 0 then
                local vehModel = GetEntityModel(currVeh)
                if vehModel ~= nil and vehModel ~= 0 then
                    if DoesEntityExist(currVeh) then
                        if IsThisModelABoat(vehModel) or IsThisModelAJetski(vehModel) or IsThisModelAnAmphibiousCar(vehModel) or IsThisModelAnAmphibiousQuadbike(vehModel) then
                            return true
                        end
                    end
                end
            end
        end
    end,
}
Config.Menu[#Config.Menu + 1] = {
    id = "police",
    displayName = "Pick Up",
    icon = "#person-icon",
    close = true,
    functiontype = "client",
    functionName = "qb-radialmenu:client:OfficerBackup",
    enableMenu = function()
        if not Config.isPlayerDead() and (QBCore.Functions.GetPlayerData().job.name == 'police' or QBCore.Functions.GetPlayerData().job.name == 'sheriff' or QBCore.Functions.GetPlayerData().job.name == 'ambilance') then
            return true
        end
    end,
}
Config.Menu[#Config.Menu + 1] = {
    id = "ambulance",
    displayName = "EMS",
    icon = "#ambulance-action",
    enableMenu = function()
        if not Config.isPlayerDead() and (QBCore.Functions.GetPlayerData().job.name == 'ambulance' and QBCore.Functions.GetPlayerData().job.onduty) then
            return true
        end
    end,
    subMenus = {"ambulance:heal", "ambulance:revive", "ambulance:depot"}
}
Config.Menu[#Config.Menu + 1] = {
    id = "police",
    displayName = "Officer Down",
    icon = "#ambulance-action",
    close = true,
    functiontype = "client",
    functionName = "qb-radialmenu:client:OfficerDown",
    enableMenu = function()
        if Config.isPlayerDead() and (QBCore.Functions.GetPlayerData().job.name == 'police' or QBCore.Functions.GetPlayerData().job.name == 'sheriff') and QBCore.Functions.GetPlayerData().job.onduty then
            return true
        end
    end,
}

-- Config.Menu[#Config.Menu + 1] = {
--     id = "vehicle-doors",
--     displayName = "Vehicle Menu",
--     icon = "#citizen-action-vehicle",
--     close = true,
--     functiontype = "client",
--     functionName = "bl_vehiclemenu:client:open",
--     enableMenu = function()
--         if not Config.isPlayerDead() then
--             if IsPedSittingInAnyVehicle(GetPlayerPed(-1)) and not IsPedOnAnyBike(GetPlayerPed(-1)) then
--                 return true
--             end
--         end
--     end
-- }


Config.Menu[#Config.Menu + 1] = {
    id = "vehicle",
    displayName = "Vehicle",
    icon = "#citizen-action-vehicle",
    close = true,
    functiontype = "client",
    functionName = "qb-vehiclemenu:client:open",
    enableMenu = function()   
        return (not Config.isPlayerDead() and IsPedInAnyVehicle(PlayerPedId(), false))
    end
}


-- Config.Menu[#Config.Menu + 1] = {
--     id = "vehicle",
--     displayName = "Vehicle",
--     icon = "#citizen-action-vehicle",
--     close = true,
--     functiontype = "client",
--     functionName = "IsPedSittingInAnyVehicle",
--     enableMenu = function()   
--         return (not Config.isPlayerDead() and IsPedInAnyVehicle(PlayerPedId(), false))
--     end
-- }

Config.Menu[#Config.Menu + 1] = {
    id = "vehicleKey",
    displayName = "Vehicle Key",
    icon = "#vehicle-givekeys",
    close = true,
    functiontype = "client",
    functionName = "vehiclekeys:client:GiveKeys",
    enableMenu = function()
        if not Config.isPlayerDead() then
            local Vehicle, Distance = QBCore.Functions.GetClosestVehicle()
            if Vehicle ~= 0 and Distance < 2.3 then
                return true
            end
        end
    end,
}


Config.SubMenus = {
    ["clothes:Shirt"] = {
        title = "Shirt",
        icon = "#global-shirt",
        close = true,
        functiontype = "client",
        functionName = "qb-radialmenu:ToggleClothing",
        functionParameters = "Shirt"
    },
    ["clothes:Pants"] = {
        title = "Pants",
        icon = "#global-shirt",
        close = true,
        functiontype = "client",
        functionName = "qb-radialmenu:ToggleClothing",
        functionParameters = "Pants"
    },
    ["clothes:Shoes"] = {
        title = "Shoes",
        icon = "#global-shoe",
        close = true,
        functiontype = "client",
        functionName = "qb-radialmenu:ToggleClothing",
        functionParameters = "Shoes"
    },
    ["clothes:Hat"] = {
        title = "Hat",
        icon = "#global-kleren",
        close = true,
        functiontype = "client",
        functionName = "qb-radialmenu:ToggleProps",
        functionParameters = "Hat"
    },
    ["clothes:Glasses"] = {
        title = "Glasses",
        icon = "#global-glasses",
        close = true,
        functiontype = "client",
        functionName = "qb-radialmenu:ToggleProps",
        functionParameters = "Glasses"
    },
    ["clothes:Mask"] = {
        title = "Mask",
        icon = "#expressions",
        close = true,
        functiontype = "client",
        functionName = "qb-radialmenu:ToggleClothing",
        functionParameters = "Mask"
    },
    ["clothes:Gloves"] = {
        title = "Gloves",
        icon = "#global-gloves",
        close = true,
        functiontype = "client",
        functionName = "qb-radialmenu:ToggleClothing",
        functionParameters = "gloves"
    },


    ["ambulance:heal"] = {
        title = "Heal",
        icon = "#ems-heal",
        close = true,
        functiontype = "client",
        functionName = "hospital:client:TreatWounds",
    },
    ["ambulance:revive"] = {
        title = "Revive",
        icon = "#ems-revive",
        close = true,
        functiontype = "client",
        functionName = "hospital:client:RevivePlayer",
    },
    ["ambulance:depot"] = {
        title = "Depot Vehicle",
        icon = "#police-action-vehicle",
        close = true,
        functiontype = "client",
        functionName = "qb-hospital:client:impoundambulancemenu",
    },
    ["ambulance:emshub"] = {
        title = "Open Hub",
        icon = "#police-minimenu",
        close = true,
        functiontype = "client",
        functionName = "qb-ambulancehub:cl:RadialMenu"
    },
    ["hotel:stash"] = {
        title = "Open stash",
        icon = "#makelaar-blips",
        close = true,
        functiontype = "client",
        functionName = "hotel:client:stash",
    },
    ["hotel:clothes"] = {
        title = "Open clothes locker",
        icon = "#global-clothes",
        close = true,
        functiontype = "client",
        functionName = "qb-clothing:client:openOutfitMenu",
    },
    -- ["hotel:logout"] = {
    --     title = "Loog out",
    --     icon = "#makelaar-blips",
    --     close = true,
    --     functiontype = "client",
    --     functionName = "hotel:client:logout",
    -- },
    ["garbagejob:deposit"] = {
        title = "Hand in vehicle",
        icon = "#makelaar-blips",
        close = true,
        functiontype = "client",
        functionName = "qb-garbagejob:client:storewaggie",
    },
    ["garbagejob:withdraw"] = {
        title = "Get Vehicle",
        icon = "#makelaar-blips",
        close = true,
        functiontype = "client",
        functionName = "qb-garbagejob:client:pakwaggie",
        -- functionParameters = true,
    },
    ["makelaar:blips"] = {
        title = "Blips",
        icon = "#makelaar-blips",
        close = true,
        functiontype = "client",
        functionName = "ToggleHouseBlips",
        -- functionParameters = true,
    },
    ["makelaar:duty"] = {
        title = "Service clocker",
        icon = "#makelaar-duty",
        close = true,
        functiontype = "client",
        functionName = "qb-housing:client:duty:checker",
        -- functionParameters = true,
    },
    ["lawyer:duty"] = {
        title = "Service clocker",
        icon = "#makelaar-duty",
        close = true,
        functiontype = "client",
        functionName = "qb-housing:client:duty:checker",
        -- functionParameters = true,
    },
    ["camera:een"] = {
        title = "Camera 1",
        icon = "#police-camera",
        close = true,
        functiontype = "client",
        functionName = "qb-police:client:CameraCommand",
        functionParameters = 1,
    },
    ["camera:twee"] = {
        title = "Camera 2",
        icon = "#police-camera",
        close = true,
        functiontype = "client",
        functionName = "qb-police:client:CameraCommand",

        functionParameters = 2,
    },
    ["camera:drie"] = {
        title = "Camera 3",
        icon = "#police-camera",
        close = true,
        functiontype = "client",
        functionName = "qb-police:client:CameraCommand",

        functionParameters = 3,
    },
    ["camera:vier"] = {
        title = "Camera 4",
        icon = "#police-camera",
        close = true,
        functiontype = "client",
        functionName = "qb-police:client:CameraCommand",

        functionParameters = 4,
    },
    ["camera:vijf"] = {
        title = "Camera 5",
        icon = "#police-camera",
        close = true,
        functiontype = "client",
        functionName = "qb-police:client:CameraCommand",
   
        functionParameters = 5,
    },
    ["camera:zes"] = {
        title = "Camera 6",
        icon = "#police-camera",
        close = true,
        functiontype = "client",
        functionName = "qb-police:client:CameraCommand",
   
        functionParameters = 6,
    },
    
    ["camera:zeven"] = {
        title = "Camera 7",
        icon = "#police-camera",
        close = true,
        functiontype = "client",
        functionName = "qb-police:client:CameraCommand",
   
        functionParameters = 7,
    },
    
    ["camera:acht"] = {
        title = "Camera 8",
        icon = "#police-camera",
        close = true,
        functiontype = "client",
        functionName = "qb-police:client:CameraCommand",
   
        functionParameters = 8,
    },
    
    ["camera:negen"] = {
        title = "Camera 9",
        icon = "#police-camera",
        close = true,
        functiontype = "client",
        functionName = "qb-police:client:CameraCommand",
   
        functionParameters = 9,
    },
    
    ["camera:tien"] = {
        title = "Camera 10",
        icon = "#police-camera",
        close = true,
        functiontype = "client",
        functionName = "qb-police:client:CameraCommand",
   
        functionParameters = 10,
    },
    
    ["camera:11"] = {
        title = "Camera 11",
        icon = "#police-camera",
        close = true,
        functiontype = "client",
        functionName = "qb-police:client:CameraCommand",
   
        functionParameters = 11,
    },
    
    ["camera:12"] = {
        title = "Camera 12",
        icon = "#police-camera",
        close = true,
        functiontype = "client",
        functionName = "qb-police:client:CameraCommand",
   
        functionParameters = 12,
    },
    
    ["camera:13"] = {
        title = "Camera 13",
        icon = "#police-camera",
        close = true,
        functiontype = "client",
        functionName = "qb-police:client:CameraCommand",
   
        functionParameters = 13,
    },
    
    ["camera:14"] = {
        title = "Camera 14",
        icon = "#police-camera",
        close = true,
        functiontype = "client",
        functionName = "qb-police:client:CameraCommand",
   
        functionParameters = 14,
    },
    
    ["camera:15"] = {
        title = "Camera 15",
        icon = "#police-camera",
        close = true,
        functiontype = "client",
        functionName = "qb-police:client:CameraCommand",
   
        functionParameters = 15,
    },
    
    ["camera:16"] = {
        title = "Camera 16",
        icon = "#police-camera",
        close = true,
        functiontype = "client",
        functionName = "qb-police:client:CameraCommand",
   
        functionParameters = 16,
    },
    ["camera:17"] = {
        title = "Camera 17",
        icon = "#police-camera",
        close = true,
        functiontype = "client",
        functionName = "qb-police:client:CameraCommand",
   
        functionParameters = 17,
    },
    ["camera:18"] = {
        title = "Camera 18",
        icon = "#police-camera",
        close = true,
        functiontype = "client",
        functionName = "qb-police:client:CameraCommand",
   
        functionParameters = 18,
    },
    ["camera:19"] = {
        title = "Camera 19",
        icon = "#police-camera",
        close = true,
        functiontype = "client",
        functionName = "qb-police:client:CameraCommand",
   
        functionParameters = 19,
    },
    
    ["camera:20"] = {
        title = "Camera 20",
        icon = "#police-camera",
        close = true,
        functiontype = "client",
        functionName = "qb-police:client:CameraCommand",
   
        functionParameters = 20,
    },
    
    ["camera:21"] = {
        title = "Camera 21",
        icon = "#police-camera",
        close = true,
        functiontype = "client",
        functionName = "qb-police:client:CameraCommand",
   
        functionParameters = 21,
    },
    
    ["camera:22"] = {
        title = "Camera 22",
        icon = "#police-camera",
        close = true,
        functiontype = "client",
        functionName = "qb-police:client:CameraCommand",
   
        functionParameters = 22,
    },
    
    ["camera:23"] = {
        title = "Camera 23",
        icon = "#police-camera",
        close = true,
        functiontype = "client",
        functionName = "qb-police:client:CameraCommand",
   
        functionParameters = 23,
    },
    
    ["camera:24"] = {
        title = "Camera 24",
        icon = "#police-camera",
        close = true,
        functiontype = "client",
        functionName = "qb-police:client:CameraCommand",
   
        functionParameters = 24,
    },
    
    ["camera:25"] = {
        title = "Camera 25",
        icon = "#police-camera",
        close = true,
        functiontype = "client",
        functionName = "qb-police:client:CameraCommand",
   
        functionParameters = 25,
    },
    
    ["camera:26"] = {
        title = "Camera 26",
        icon = "#police-camera",
        close = true,
        functiontype = "client",
        functionName = "qb-police:client:CameraCommand",
   
        functionParameters = 26,
    },
    
    ["camera:27"] = {
        title = "Camera 27",
        icon = "#police-camera",
        close = true,
        functiontype = "client",
        functionName = "qb-police:client:CameraCommand",
   
        functionParameters = 27,
    },
    
    ["camera:28"] = {
        title = "Camera 28",
        icon = "#police-camera",
        close = true,
        functiontype = "client",
        functionName = "qb-police:client:CameraCommand",
   
        functionParameters = 28,
    },
    
    ["camera:29"] = {
        title = "Camera 29",
        icon = "#police-camera",
        close = true,
        functiontype = "client",
        functionName = "qb-police:client:CameraCommand",
   
        functionParameters = 29,
    },
    
    ["camera:30"] = {
        title = "Camera 30",
        icon = "#police-camera",
        close = true,
        functiontype = "client",
        functionName = "qb-police:client:CameraCommand",
   
        functionParameters = 30,
    },
    ["camera:31"] = {
        title = "Camera 31",
        icon = "#police-camera",
        close = true,
        functiontype = "client",
        functionName = "qb-police:client:CameraCommand",
   
        functionParameters = 31,
    },
    ["camera:32"] = {
        title = "Camera 32",
        icon = "#police-camera",
        close = true,
        functiontype = "client",
        functionName = "qb-police:client:CameraCommand",
   
        functionParameters = 32,
    },
    ["camera:33"] = {
        title = "Camera 33",
        icon = "#police-camera",
        close = true,
        functiontype = "client",
        functionName = "qb-police:client:CameraCommand",
   
        functionParameters = 33,
    },
    ["camera:34"] = {
        title = "Camera 34",
        icon = "#police-camera",
        close = true,
        functiontype = "client",
        functionName = "qb-police:client:CameraCommand",
   
        functionParameters = 34,
    },
    ["camera:70"] = {
        title = "Juwelier 70",
        icon = "#police-camera",
        close = true,
        functiontype = "client",
        functionName = "qb-police:client:CameraCommand",
   
        functionParameters = 70,
    },
    ["camera:71"] = {
        title = "Juwelier 71",
        icon = "#police-camera",
        close = true,
        functiontype = "client",
        functionName = "qb-police:client:CameraCommand",
   
        functionParameters = 71,
    },
    ["camera:72"] = {
        title = "Juwelier 72",
        icon = "#police-camera",
        close = true,
        functiontype = "client",
        functionName = "qb-police:client:CameraCommand",
   
        functionParameters = 72,
    },
    ["camera:80"] = {
        title = "Gevangenis 80",
        icon = "#police-camera",
        close = true,
        functiontype = "client",
        functionName = "qb-police:client:CameraCommand",
   
        functionParameters = 80,
    },
    ["camera:81"] = {
        title = "Gevangenis 81",
        icon = "#police-camera",
        close = true,
        functiontype = "client",
        functionName = "qb-police:client:CameraCommand",
   
        functionParameters = 81,
    },
    ["camera:40"] = {
        title = "Pacific 40",
        icon = "#police-camera",
        close = true,
        functiontype = "client",
        functionName = "qb-police:client:CameraCommand",
   
        functionParameters = 40,
    },
    ["camera:41"] = {
        title = "Pacific 41",
        icon = "#police-camera",
        close = true,
        functiontype = "client",
        functionName = "qb-police:client:CameraCommand",
   
        functionParameters = 41,
    },
    ["camera:42"] = {
        title = "Pacific 42",
        icon = "#police-camera",
        close = true,
        functiontype = "client",
        functionName = "qb-police:client:CameraCommand",
   
        functionParameters = 42,
    },
    ["camera:43"] = {
        title = "Pacific 43",
        icon = "#police-camera",
        close = true,
        functiontype = "client",
        functionName = "qb-police:client:CameraCommand",
   
        functionParameters = 43,
    },
    ["camera:44"] = {
        title = "Pacific 44",
        icon = "#police-camera",
        close = true,
        functiontype = "client",
        functionName = "qb-police:client:CameraCommand",
   
        functionParameters = 44,
    },
    ["camera:50"] = {
        title = "Fleeca BP 1",
        icon = "#police-camera",
        close = true,
        functiontype = "client",
        functionName = "qb-police:client:CameraCommand",
   
        functionParameters = 50,
    },
    ["camera:51"] = {
        title = "Fleeca BP 2",
        icon = "#police-camera",
        close = true,
        functiontype = "client",
        functionName = "qb-police:client:CameraCommand",
   
        functionParameters = 51,
    },
    ["camera:52"] = {
        title = "Fleeca Hawick 1",
        icon = "#police-camera",
        close = true,
        functiontype = "client",
        functionName = "qb-police:client:CameraCommand",
   
        functionParameters = 52,
    },
    ["camera:53"] = {
        title = "Fleeca Hawick 2",
        icon = "#police-camera",
        close = true,
        functiontype = "client",
        functionName = "qb-police:client:CameraCommand",
   
        functionParameters = 53,
    },
    ["camera:54"] = {
        title = "Fleeca Motel 1",
        icon = "#police-camera",
        close = true,
        functiontype = "client",
        functionName = "qb-police:client:CameraCommand",
   
        functionParameters = 54,
    },
    ["camera:55"] = {
        title = "Fleeca Motel 2",
        icon = "#police-camera",
        close = true,
        functiontype = "client",
        functionName = "qb-police:client:CameraCommand",
   
        functionParameters = 55,
    },
    ["camera:56"] = {
        title = "Fleeca Del Perro 1",
        icon = "#police-camera",
        close = true,
        functiontype = "client",
        functionName = "qb-police:client:CameraCommand",
   
        functionParameters = 56,
    },
    ["camera:57"] = {
        title = "Fleeca Del Perro 2",
        icon = "#police-camera",
        close = true,
        functiontype = "client",
        functionName = "qb-police:client:CameraCommand",
   
        functionParameters = 57,
    },
    ["camera:58"] = {
        title = "Fleeca Great ocean 1",
        icon = "#police-camera",
        close = true,
        functiontype = "client",
        functionName = "qb-police:client:CameraCommand",
   
        functionParameters = 58,
    },
    ["camera:59"] = {
        title = "Fleeca Great ocean 2",
        icon = "#police-camera",
        close = true,
        functiontype = "client",
        functionName = "qb-police:client:CameraCommand",
   
        functionParameters = 59,
    },
    ["camera:60"] = {
        title = "Paleto 1",
        icon = "#police-camera",
        close = true,
        functiontype = "client",
        functionName = "qb-police:client:CameraCommand",
   
        functionParameters = 60,
    },
    ["camera:61"] = {
        title = "Paleto 2",
        icon = "#police-camera",
        close = true,
        functiontype = "client",
        functionName = "qb-police:client:CameraCommand",
   
        functionParameters = 61,
    },
    ["camera:62"] = {
        title = "Paleto 3",
        icon = "#police-camera",
        close = true,
        functiontype = "client",
        functionName = "qb-police:client:CameraCommand",
   
        functionParameters = 62,
    },
    --blips
    ["blips:tattooshop"] = {
        title = "Tattooshop",
        icon = "#blips-tattooshop",
        close = true,
        functiontype = "client",
        functionName = "qb-radialmenu:client:tattooshop",
    },

    ["blips:barbershop"] = {
        title = "Barber",
        icon = "#blips-barbershop",
        close = true,
        functiontype = "client",
        functionName = "qb-radialmenu:client:barbershop",
    },
    ["blips:garage"] = {
        title = "Garage",
        icon = "#global-garage",
        close = true,
        functiontype = "client",
        functionName = "qb-radialmenu:client:garage",
    },
    ["blips:gas"] = {
        title = "Petrol station",
        icon = "#blips-gasstations",
        close = true,
        functiontype = "client",
        functionName = "qb-radialmenu:client:benzine",
    },
    ["blips:clothing"] = {
        title = "clothes shop",
        icon = "#house-setoutift",
        close = true,
        functiontype = "client",
        functionName = "qb-radialmenu:client:clothing",
    },
    ["blips:bennys"] = {
        title = "bennys",
        icon = "#citizen-action-vehicle",
        close = true,
        functiontype = "client",
        functionName = "qb-radialmenu:client:bennys",
    },
    
    ['favo:radio:one'] = {
        title = "Own. Freq",
        icon = "#radio-channel",
        close = true,
        functiontype = "client",
        functionName = "qb-radialmenu:client:enter:playerradio"
    },
    ['police:radio:one'] = {
        title = "#1",
        icon = "#radio-channel",
        close = true,
        functionParameters = 1,
        functiontype = "client",
        functionName = "qb-radialmenu:client:enter:radio"
    },
    ['police:radio:two'] = {
        title = "#2",
        icon = "#radio-channel",
        close = true,
        functionParameters = 2,
        functiontype = "client",
        functionName = "qb-radialmenu:client:enter:radio"
    },
    ['police:radio:three'] = {
        title = "#3",
        icon = "#radio-channel",
        close = true,
        functionParameters = 3,
        functiontype = "client",
        functionName = "qb-radialmenu:client:enter:radio"
    },
    ['police:radio:four'] = {
        title = "#4",
        icon = "#radio-channel",
        close = true,
        functionParameters = 4,
        functiontype = "client",
        functionName = "qb-radialmenu:client:enter:radio"
    },
    ['police:radio:five'] = {
        title = "#5",
        icon = "#radio-channel",
        close = true,
        functionParameters = 5,
        functiontype = "client",
        functionName = "qb-radialmenu:client:enter:radio"
    },
    ['police:radio:6'] = {
        title = "#6",
        icon = "#radio-channel",
        close = true,
        functionParameters = 6,
        functiontype = "client",
        functionName = "qb-radialmenu:client:enter:radio"
    },
    ['police:radio:7'] = {
        title = "#7",
        icon = "#radio-channel",
        close = true,
        functionParameters = 7,
        functiontype = "client",
        functionName = "qb-radialmenu:client:enter:radio"
    },
    ['police:radio:8'] = {
        title = "#8",
        icon = "#radio-channel",
        close = true,
        functionParameters = 8,
        functiontype = "client",
        functionName = "qb-radialmenu:client:enter:radio"
    },
    ['police:radio:9'] = {
        title = "#9",
        icon = "#radio-channel",
        close = true,
        functionParameters = 9,
        functiontype = "client",
        functionName = "qb-radialmenu:client:enter:radio"
    },
    ['police:radio:10'] = {
        title = "#10",
        icon = "#radio-channel",
        close = true,
        functionParameters = 10,
        functiontype = "client",
        functionName = "qb-radialmenu:client:enter:radio"
    },
    ['police:bill'] = {
        title = "Fine",
        icon = "#bill-icon",
        close = true,
        functiontype = "client",
        functionName = "police:client:billplayer"
    },
    ['police:jail'] = {
        title = "Jail",
        icon = "#police-jail",
        close = true,
        functiontype = "client",
        functionName = "police:client:JailPlayer"
    },
    ["taxi:togglemeter"] = {
        title = "Show/Hide Meter",
        icon = "#taxi-power",
        close = true,
        functiontype = "client",
        functionName = "qb-taxi:client:toggleMeter",
    },
    ["taxi:start"] = {
        title = "Start/Stop Meter",
        icon = "#taxi-start",
        close = true,
        functiontype = "client",
        functionName = "qb-taxi:client:enableMeter",
    },
    ["taxi:npcmission"] = {
        title = "Toggle NPC",
        icon = "#taxi-npcmission",
        close = true,
        functiontype = "client",
        functionName = "qb-taxi:client:DoTaxiNpc",
    },
    ["taxi:veh"] = {
        title = "Vehicle",
        icon = "#taxi-npc",
        close = true,
        functiontype = "client",
        functionName = "qb-taxi:client:vehicle",
    },
    ['police:DispatchMenu'] = {
     title = "Alerts",
     icon = "#police-action-panic",
     close = true,
     functiontype = "client",
     functionName = "qb-police:client:Dispatch"
    },
    ['police:tablet'] = {
     title = "MDT Tablet",
     icon = "#police-mdt",
     close = true,
     functiontype = "client",
     functionName = "mdt:openMDT"
    },
    ['police:gsr'] = {
        title = "GSR",
        icon = "#police-gsr",
        close = true,
        functiontype = "client",
        functionName = "GSR_Client:PerformTest"
    },
    ['police:minimenu'] = {
        title = "Police Menu",
        icon = "#police-minimenu",
        close = true,
        functiontype = "client",
        functionName = "qb-policescripts:client:openMenu"
    },
    ['police:plate'] = {
        title = "Flag Plate",
        icon = "#blips",
        close = true,
        functiontype = "client",
        functionName = "police:client:FlagMenu"
    },
    ['police:jaberlove'] = {
        title = "Open Hub",
        icon = "#police-minimenu",
        close = true,
        functiontype = "client",
        functionName = "qb-policehub:cl:RadialMenu"
    },
    ['police:impound'] = {
     title = "Impound",
     icon = "#police-action-vehicle",
     close = true,
     functiontype = "client",
     functionName = "qb-police:client:impoundnewmenu"
    },
    ['police:news'] = {
        title = "Dispatch options",
        icon = "#judge-actions",
        close = true,
        functiontype = "client",
        functionName = "qb-policescripts11:client:openMenu"
       },
    ['police:obj'] = {
     title = "Objects",
     icon = "#objects",
     close = true,
     functiontype = "client",
     functionName = "police:client:spawnObjects"
    },
    ['police:report'] = {
     title = "Report",
     icon = "#police-action-report",
     close = true,
     functiontype = "client",
     functionName = "police:client:reportRobbery"
    },
    ['police:depot'] = {
        title = "Impound with fine",
        icon = "#police-action-vehicle",
        close = true,
        functiontype = "client",
        functionName = "qb-police:client:impound:depot"
    },
    ['police:depottime'] = {
        title = "Depot with time",
        icon = "#police-action-vehicle",
        close = true,
        functiontype = "client",
        functionName = "qb-police:client:impound:depottime"
    },
    ['police:search'] = {
     title = "Search",
     icon = "#police-search",
     close = true,
     functiontype = "client",
     functionName = "police:client:SearchPlayer"
    },
    ['Dispatch:Open'] = {
        title = "Open/Close Dispatch",
        icon = "#police-open",
        close = true,
        functiontype = "client",
        functionName = "qb-radialmenu:cl:Dispatch"
       },
       ['Dispatch:Large'] = {
        title = "Large Dispatch",
        icon = "#police-large",
        close = true,
        functiontype = "client",
        functionName = "qb-radialmenu:cl:Large"
       },
       ['Dispatch:Resize'] = {
        title = "Resize Dispatch",
        icon = "#police-resize",
        close = true,
        functiontype = "client",
        functionName = "qb-radialmenu:cl:Resize"
       },
    -- ['police:impound'] = {
    --  title = "Search",
    --  icon = "#police-action-vehicle",
    --  close = true,
    --  functiontype = "client",
    --  functionName = "qb-police:client:impoundnewmenu"
    -- },
    ['police:resetdoor'] = {
     title = "Reset Door",
     icon = "#global-appartment",
     close = true,
     functiontype = "client",
     functionName = "qb-housing:client:reset:house:door"
    },
    ['police:enkelband'] = {
     title = "Ankle",
     icon = "#police-action-enkelband",
     close = true,
     functiontype = "client",
     functionName = "police:client:CuffPlayer"
    },

    -- POLICE VEHICLES START -- 

    ['police:vehicle:touran'] = {
        title = "Volkswagen Touran",
        icon = "#police-action-vehicle-spawn",
        close = true,
        functionParameters = 'ptouran',
        functiontype = "client",
        functionName = "qb-police:client:spawn:vehicle"
        },
    ['police:vehicle:touran11'] = {
        title = "Volkswagen Touran",
        icon = "#police-action-vehicle-spawn",
        close = true,
        functionParameters = 'ptouran11',
        functiontype = "client",
        functionName = "qb-police:client:spawn:vehicle"
        }, 
    ['police:vehicle:klasse'] = {
        title = "Mercedes B-Klasse",
        icon = "#police-action-vehicle-spawn",
        close = true,
        functionParameters = 'pbklasse',
        functiontype = "client",
        functionName = "qb-police:client:spawn:vehicle"
        },
    ['police:vehicle:amarok'] = {
        title = "Volkswagen Amarok",
        icon = "#police-action-vehicle-spawn-bus",
        close = true,
        functionParameters = 'pamarok',
        functiontype = "client",
        functionName = "qb-police:client:spawn:vehicle"
        },
    ['police:vehicle:pvito'] = {
        title = "Mercedes Vito",
        icon = "#police-action-vehicle-spawn",
        close = true,
        functionParameters = 'pvito',
        functiontype = "client",
        functionName = "qb-police:client:spawn:vehicle"
        },
    ['police:vehicle:dsivito'] = {
        title = "Vito Unmarked",
        icon = "#police-action-vehicle-spawn",
        close = true,
        functionParameters = 'dsivito',
        functiontype = "client",
        functionName = "qb-police:client:spawn:vehicle"
        },
    ['police:vehicle:fiets'] = {
        title = "Fiets",
        icon = "#police-action-vehicle-spawn",
        close = true,
        functionParameters = 'pfiets',
        functiontype = "client",
        functionName = "qb-police:client:spawn:vehicle"
        },
    ['police:vehicle:pbal'] = {
        title = "Unmarked Baller",
        icon = "#police-action-vehicle-spawn",
        close = true,
        functionParameters = 'pbal',
        functiontype = "client",
        functionName = "qb-police:client:spawn:vehicle"
        },
    ['police:vehicle:audi'] = {
        title = "Audi A6",
        icon = "#police-action-vehicle-spawn",
        close = true,
        functionParameters = 'paudi',
        functiontype = "client",
        functionName = "qb-police:client:spawn:vehicle"
        },
    ['police:vehicle:velar'] = {
        title = "Oracle Unmarked",
        icon = "#police-action-vehicle-spawn",
        close = true,
        functionParameters = 'poracle',
        functiontype = "client",
        functionName = "qb-police:client:spawn:vehicle"
        },
    ['police:vehicle:pyamahamotor'] = {
        title = "Yamaha Motor",
        icon = "#police-action-vehicle-spawn",
        close = true,
        functionParameters = 'pyamahamotor',
        functiontype = "client",
        functionName = "qb-police:client:spawn:vehicle"
        },
    ['police:vehicle:dsimerc'] = {
        title = "Mercedes (DSI)",
        icon = "#police-action-vehicle-spawn",
        close = true,
        functionParameters = 'dsimerc',
        functiontype = "client",
        functionName = "qb-police:client:spawn:vehicle"
        },
    ['police:vehicle:prs6'] = {
        title = "Audi RS6",
        icon = "#police-action-vehicle-spawn",
        close = true,
        functionParameters = 'prs6',
        functiontype = "client",
        functionName = "qb-police:client:spawn:vehicle"
        },
    ['police:vehicle:gevang'] = {
        title = "Transport",
        icon = "#police-action-vehicle-spawn",
        close = true,
        functionParameters = 'pasprinter',
        functiontype = "client",
        functionName = "qb-police:client:spawn:vehicle"
        },
    ['police:vehicle:pschafter'] = {
        title = "Unmarked Shafter",
        icon = "#police-action-vehicle-spawn",
        close = true,
        functionParameters = 'pschafter',
        functiontype = "client",
        functionName = "qb-police:client:spawn:vehicle"
        },
    ['police:vehicle:pmas'] = {
        title = "Unmarked Maserati",
        icon = "#police-action-vehicle-spawn",
        close = true,
        functionParameters = 'pmas',
        functiontype = "client",
        functionName = "qb-police:client:spawn:vehicle"
        },
    ['police:vehicle:dsiq5'] = {
        title = "Unmarked DSIQ 5",
        icon = "#police-action-vehicle-spawn",
        close = true,
        functionParameters = 'dsiq5',
        functiontype = "client",
        functionName = "qb-police:client:spawn:vehicle"
        },
    ['police:vehicle:pfosprinter'] = {
        title = "FO Sprinter",
        icon = "#police-action-vehicle-spawn",
        close = true,
        functionParameters = 'pfosprinter',
        functiontype = "client",
        functionName = "qb-police:client:spawn:vehicle"
        },
    ['police:vehicle:heli'] = {
        title = "Zulu",
        icon = "#police-action-vehicle-spawn-heli",
        close = true,
        functionParameters = 'pzulu',
        functiontype = "client",
        functionName = "qb-police:client:spawn:vehicle"
        },
    ['police:vehicle:motor'] = {
        title = "BMW Motor",
        icon = "#police-action-vehicle-spawn-motor",
        close = true,
        functionParameters = 'pbmwmotor2',
        functiontype = "client",
        functionName = "qb-police:client:spawn:vehicle"
        },
        
    -- POLICE VEHICLES END -- 

    ['police:object:cone'] = {
     title = "Pion",
     icon = "#global-box",
     close = true,
     functionParameters = 'cone',
     functiontype = "client",
     functionName = "qb-police:client:spawn:object"
    },
    ['police:object:barrier'] = {
     title = "Barrier",
     icon = "#global-box",
     close = true,
     functionParameters = 'barrier',
     functiontype = "client",
     functionName = "qb-police:client:spawn:object"
    },
    ['police:object:schot'] = {
     title = "Fence",
     icon = "#global-box",
     close = true,
     functionParameters = 'schot',
     functiontype = "client",
     functionName = "qb-police:client:spawn:object"
    },
    ['police:object:tent'] = {
     title = "Tent",
     icon = "#global-tent",
     close = true,
     functionParameters = 'tent',
     functiontype = "client",
     functionName = "qb-police:client:spawn:object"
    },
    ['police:object:light'] = {
     title = "Lamps",
     icon = "#global-box",
     close = true,
     functionParameters = 'light',
     functiontype = "client",
     functionName = "qb-police:client:spawn:object"
    },
    ['police:object:delete'] = {
     title = "Remove object",
     icon = "#global-delete",
     close = false,
     functiontype = "client",
     functionName = "qb-police:client:delete:object"
    },
    -- ['ambulance:heal'] = {
    --   title = "Heal",
    --   icon = "#ambulance-action-heal",
    --   close = true,
    --   functiontype = "client",
    --   functionName = "qb-hospital:client:heal:closest"
    -- },
    -- ['ambulance:revive'] = {
    --   title = "Revive",
    --   icon = "#ambulance-action-heal",
    --   close = true,
    --   functiontype = "client",
    --   functionName = "qb-hospital:client:revive:closest"
    -- },
    ['ambulance:blood'] = {
      title = "Take Bloodsample",
      icon = "#ambulance-action-blood",
      close = true,
      functiontype = "client",
      functionName = "qb-hospital:client:take:blood:closest"
    },
    ['ambulance:garage:heli'] = {
      title = "Ambulance Heli",
      icon = "#police-action-vehicle-spawn",
      close = true,
      functionParameters = 'alifeliner',
      functiontype = "client",
      functionName = "qb-hospital:client:spawn:vehicle"
    },
    ['ambulance:garage:touran'] = {
     title = "Mercedes Klasse B",
     icon = "#police-action-vehicle-spawn",
     close = true,
     functionParameters = 'aeklasse',
     functiontype = "client",
     functionName = "qb-hospital:client:spawn:vehicle"
    },
    ['ambulance:garage:sprinter'] = {
     title = "Ambulance Sprinter",
     icon = "#police-action-vehicle-spawn",
     close = true,
     functionParameters = 'asprinter',
     functiontype = "client",
     functionName = "qb-hospital:client:spawn:vehicle"
    },
    ['vehicle:delete'] = {
     title = "Delete Vehicle",
     icon = "#police-action-vehicle-delete",
     close = true,
     functiontype = "client",
     functionName = "LRCore:Command:DeleteVehicle"
    },
    ['judge:tablet'] = {
     title = "Rechter Tablet",
     icon = "#police-action-tablet",
     close = true,
     functiontype = "client",
     functionName = "qb-judge:client:toggle"
    },
    ['judge:job'] = {
     title = "Rent lawyer",
     icon = "#judge-actions",
     close = true,
     functiontype = "client",
     functionName = "qb-judge:client:lawyer:add:closest"
    },
    ['citizen:contact'] = {
     title = "Share contact",
     icon = "#givenum",
     close = true,
     functiontype = "client",
     functionName = "qb-phone:client:GiveContactDetails"
    },
    ['citizen:givecash'] = {
     title = "Give Cash",
     icon = "#police-cash",
     close = true,
     functiontype = "client",
     functionName = "qb-radialmenu:client:GiveCash"
    },
    ['citizen:escort'] = {
     title = "Escort",
     icon = "#general-escort",
     close = true,
     functiontype = "client",
     functionName = "police:client:EscortPlayer"
    },
    ['tow'] = {
        title = "Towing vehicle",
        icon = "#citizen-action-vehicle",
        close = true,
        functiontype = "client",
        functionName = "ssadasd"
       },
       ['jabbdd'] = {
        title = 'Cut Ziptie',
        icon = '#police-action-enkelband',
        type = 'client',
        event = 'Crazy:Client:ZipOff',
        close = true,
       },
    ['citizen:steal'] = {
     title = "Steal",
     icon = "#police-search",
     close = true,
     functiontype = "client",
     functionName = "police:client:RobPlayer"
    },
    ['citizen:vehicle:getout'] = {
     title = "Put out Vehicle",
     icon = "#police-radioout",
     close = true,
     functiontype = "client",
     functionName = "police:client:SetPlayerOutVehicle"
    },
    ['citizen:vehicle:getin'] = {
     title = "Put in Vehicle",
     icon = "#general-put-in-veh",
     close = true,
     functiontype = "client",
     functionName = "police:client:PutPlayerInVehicle"
    },
    -- ['citizen:bills'] = {
    --  title = "Bills",
    --  icon = "#global-bills",
    --  close = true,
    --  functiontype = "client",
    --  functionName = "police:client:billplayer"
    -- },
    ['citizen:Kidnap'] = {
     title = "Carry",
     icon = "#cuffs-carry",
     close = true,
     functiontype = "client",
     functionName = "police:client:KidnapPlayer"
    },
    ['vehicle:flip'] = {
     title = "Flip Vehicle",
     icon = "#citizen-action-vehicle",
     close = true,
     functiontype = "client",
     functionName = "qb-radialmenu:client:flip:vehicle"
    },
    ['vehicle:door:left:front'] = {
     title = "Front left",
     icon = "#global-arrow-left",
     close = true,
     functionParameters = 0,
     functiontype = "client",
     functionName = "qb-radialmenu:client:open:door"
    },
    ['vehicle:door:motor'] = {
     title = "Bonnet",
     icon = "#global-arrow-up",
     close = true,
     functionParameters = 4,
     functiontype = "client",
     functionName = "qb-radialmenu:client:open:door"
    },
    ['vehicle:door:right:front'] = {
     title = "Front right",
     icon = "#global-arrow-right",
     close = true,
     functionParameters = 1,
     functiontype = "client",
     functionName = "qb-radialmenu:client:open:door"
    },
    ['vehicle:door:right:back'] = {
     title = "Right behind",
     icon = "#global-arrow-right",
     close = true,
     functionParameters = 3,
     functiontype = "client",
     functionName = "qb-radialmenu:client:open:door"
    },
    ['vehicle:door:trunk'] = {
     title = "Trunk",
     icon = "#global-arrow-down",
     close = true,
     functionParameters = 5,
     functiontype = "client",
     functionName = "qb-radialmenu:client:open:door"
    },
    ['vehicle:door:left:back'] = {
     title = "Left behind",
     icon = "#global-arrow-left",
     close = true,
     functionParameters = 2,
     functiontype = "client",
     functionName = "qb-radialmenu:client:open:door"
    },
    ["mechanic:repair"] = {
        title = "Repair",
        icon = "#citizen-action-vehicle",
        close = true,
        functiontype = "client",
        functionName = "qb-repair:client:triggerMenu",
    },
    ['tow:hook'] = {
     title = "Trail vehicle",
     icon = "#citizen-action-vehicle",
     close = true,
     functiontype = "client",
     functionName = "qb-tow:client:hook:car"
    },
    ['tow:npc'] = {
     title = "Toggle Npc",
     icon = "#taxi-npcmission",
     close = true,
     functiontype = "client",
     functionName = "jobs:client:ToggleNpc"
    },
    ['tow:townpc'] = {
        title = "Tow NPC Vehicle",
        icon = "#tow-npcmission",
        close = true,
        functiontype = "client",
        functionName = "qb-tow:client:TowVehicle"
    },
    ['tow:civ'] = {
        title = "Tow Civilian Vehicle",
        icon = "#tow-npcmission",
        close = true,
        functiontype = "client",
        functionName = "qb-tow:client:TowCivilianVehicle"
    },
    ['tow:locaton'] = {
        title = "Drop off Location",
        icon = "#tow-npcmission",
        close = true,
        functiontype = "client",
        functionName = "qb-tow:client:Chooseplace"
    },
    ['citizen:corner:selling'] = {
        title = "Cornersell",
        icon = "#citizen-action-cornerselling",
        close = true,
        functiontype = "client",
        functionName = "qb-illegal:client:toggle:corner:selling"
    },
    ['garage:putin'] = {
        title = "Park Vehicle",
        icon = "#citizen-put-in-veh",
        close = true,
        functiontype = "client",
        functionName = "qb-garages:client:PutInGarageMenu"
    },
    ['garage:getout'] = {
        title = "Take Out Vehicle",
        icon = "#citizen-put-out-veh",
        close = true,
        functiontype = "client",
        functionName = "qb-garages:client:OpenGarageMenu"
    },
    ['house:setstash'] = {
     title = "Place Stash",
     icon = "#citizen-put-out-veh",
     close = true,
     functionParameters = 'setstash',
     functiontype = "client",
     functionName = "qb-houses:client:setLocation"
    },
    ['house:setlogout'] = {
     title = "Place Logout",
     icon = "#citizen-put-out-veh",
     close = true,
     functionParameters = 'setlogout',
     functiontype = "client",
     functionName = "qb-houses:client:setLocation"
    },
    ['house:setclothes'] = {
     title = "Place Clothes",
     icon = "#citizen-put-out-veh",
     close = true,
     functionParameters = 'setoutift',
     functiontype = "client",
     functionName = "qb-houses:client:setLocation"
    },
    ['house:givekey'] = {
     title = "Give Keys",
     icon = "#citizen-action-vehicle-key",
     close = true,
     functiontype = "client",
     functionName = "qb-houses:client:giveHouseKey"
    },
    ['house:decorate'] = {
     title = "Decorate",
     icon = "#global-box",
     close = true,
     functiontype = "client",
     functionName = "qb-houses:client:decorate"
    },
    -- // Anims and Expression \\ --
    ['animations:brave'] = {
        title = "Brave",
        icon = "#animation-brave",
        close = true,
        functionName = "AnimSet:Brave",
        functiontype = "client",
    },
    ['animations:hurry'] = {
        title = "Hurry",
        icon = "#animation-hurry",
        close = true,
        functionName = "AnimSet:Hurry",
        functiontype = "client",
    },
    ['animations:business'] = {
        title = "Business",
        icon = "#animation-business",
        close = true,
        functionName = "AnimSet:Business",
        functiontype = "client",
    },
    ['animations:tipsy'] = {
        title = "Tipsy",
        icon = "#animation-tipsy",
        close = true,
        functionName = "AnimSet:Tipsy",
        functiontype = "client",
    },
    ['animations:injured'] = {
        title = "Injured",
        icon = "#animation-injured",
        close = true,
        functionName = "AnimSet:Injured",
        functiontype = "client",
    },
    ['animations:tough'] = {
        title = "Tough",
        icon = "#animation-tough",
        close = true,
        functionName = "AnimSet:ToughGuy",
        functiontype = "client",
    },
    ['animations:sassy'] = {
        title = "Sassy",
        icon = "#animation-sassy",
        close = true,
        functionName = "AnimSet:Sassy",
        functiontype = "client",
    },
    ['animations:sad'] = {
        title = "Sad",
        icon = "#animation-sad",
        close = true,
        functionName = "AnimSet:Sad",
        functiontype = "client",
    },
    ['animations:posh'] = {
        title = "Posh",
        icon = "#animation-posh",
        close = true,
        functionName = "AnimSet:Posh",
        functiontype = "client",
    },
    ['animations:alien'] = {
        title = "Alien",
        icon = "#animation-alien",
        close = true,
        functionName = "AnimSet:Alien",
        functiontype = "client",
    },
    ['animations:nonchalant'] =
    {
        title = "Nonchalant",
        icon = "#animation-nonchalant",
        close = true,
        functionName = "AnimSet:NonChalant",
        functiontype = "client",
    },
    ['animations:hobo'] = {
        title = "Hobo",
        icon = "#animation-hobo",
        close = true,
        functionName = "AnimSet:Hobo",
        functiontype = "client",
    },
    ['animations:money'] = {
        title = "Money",
        icon = "#animation-money",
        close = true,
        functionName = "AnimSet:Money",
        functiontype = "client",
    },
    ['animations:swagger'] = {
        title = "Swagger",
        icon = "#animation-swagger",
        close = true,
        functionName = "AnimSet:Swagger",
        functiontype = "client",
    },
    ['animations:shady'] = {
        title = "Shady",
        icon = "#animation-shady",
        close = true,
        functionName = "AnimSet:Shady",
        functiontype = "client",
    },
    ['animations:maneater'] = {
        title = "Man Eater",
        icon = "#animation-maneater",
        close = true,
        functionName = "AnimSet:ManEater",
        functiontype = "client",
    },
    ['animations:chichi'] = {
        title = "ChiChi",
        icon = "#animation-chichi",
        close = true,
        functionName = "AnimSet:ChiChi",
        functiontype = "client",
    },
    ['animations:default'] = {
        title = "Default",
        icon = "#animation-default",
        close = true,
        functionName = "AnimSet:default",
        functiontype = "client",
    },
    ["expressions:angry"] = {
        title="Angry",
        icon="#expressions-angry",
        close = true,
        functionName = "expressions",
        functionParameters =  { "mood_angry_1" },
        functiontype = "client",
    },
    ["expressions:drunk"] = {
        title="Drunk",
        icon="#expressions-drunk",
        close = true,
        functionName = "expressions",
        functionParameters =  { "mood_drunk_1" },
        functiontype = "client",
    },
    ["expressions:dumb"] = {
        title="Dumb",
        icon="#expressions-dumb",
        close = true,
        functionName = "expressions",
        functionParameters =  { "pose_injured_1" },
        functiontype = "client",
    },
    ["expressions:electrocuted"] = {
        title="Electrocuted",
        icon="#expressions-electrocuted",
        close = true,
        functionName = "expressions",
        functionParameters =  { "electrocuted_1" },
        functiontype = "client",
    },
    ["expressions:grumpy"] = {
        title="Grumpy",
        icon="#expressions-grumpy",
        close = true,
        functionName = "expressions", 
        functionParameters =  { "mood_drivefast_1" },
        functiontype = "client",
    },
    ["expressions:happy"] = {
        title="Happy",
        icon="#expressions-happy",
        close = true,
        functionName = "expressions",
        functionParameters =  { "mood_happy_1" },
        functiontype = "client",
    },
    ["expressions:injured"] = {
        title="Injured",
        icon="#expressions-injured",
        close = true,
        functionName = "expressions",
        functionParameters =  { "mood_injured_1" },
        functiontype = "client",
    },
    ["expressions:joyful"] = {
        title="Joyful",
        icon="#expressions-joyful",
        close = true,
        functionName = "expressions",
        functionParameters =  { "mood_dancing_low_1" },
        functiontype = "client",
    },
    ["expressions:mouthbreather"] = {
        title="Mouthbreather",
        icon="#expressions-mouthbreather",
        close = true,
        functionName = "expressions",
        functionParameters = { "smoking_hold_1" },
        functiontype = "client",
    },
    ["expressions:normal"]  = {
        title="Normal",
        icon="#expressions-normal",
        close = true,
        functionName = "expressions:clear",
        functiontype = "client",
    },
    ["expressions:oneeye"]  = {
        title="One Eye",
        icon="#expressions-oneeye",
        close = true,
        functionName = "expressions",
        functionParameters = { "pose_aiming_1" },
        functiontype = "client",
    },
    ["expressions:shocked"]  = {
        title="Shocked",
        icon="#expressions-shocked",
        close = true,
        functionName = "expressions",
        functionParameters = { "shocked_1" },
        functiontype = "client",
    },
    ["expressions:sleeping"]  = {
        title="Sleeping",
        icon="#expressions-sleeping",
        close = true,
        functionName = "expressions",
        functionParameters = { "dead_1" },
        functiontype = "client",
    },
    ["expressions:smug"]  = {
        title="Smug",
        icon="#expressions-smug",
        close = true,
        functionName = "expressions",
        functionParameters = { "mood_smug_1" },
        functiontype = "client",
    },
    ["expressions:speculative"]  = {
        title="Speculative",
        icon="#expressions-speculative",
        close = true,
        functionName = "expressions",
        functionParameters = { "mood_aiming_1" },
        functiontype = "client",
    },
    ["expressions:stressed"]  = {
        title="Stressed",
        icon="#expressions-stressed",
        close = true,
        functionName = "expressions",
        functionParameters = { "mood_stressed_1" },
        functiontype = "client",
    },
    ["expressions:sulking"]  = {
        title="Sulking",
        icon="#expressions-sulking",
        close = true,
        functionName = "expressions",
        functionParameters = { "mood_sulk_1" },
        functiontype = "client",
    },
    ["expressions:weird"]  = {
        title="Weird",
        icon="#expressions-weird",
        close = true,
        functionName = "expressions",
        functionParameters = { "effort_2" },
        functiontype = "client",
    },
    ["expressions:weird2"]  = {
        title="Weird 2",
        icon="#expressions-weird2",
        close = true,
        functionName = "expressions",
        functionParameters = { "effort_3" },
        functiontype = "client",
    },
	['vehicle:extra3'] = {
        title = "Extra3",
        icon = "#vehicle-plus",
        close = false,
        functionParameters = 3,
        functiontype = "client",
        functionName = "qb-radialmenu:client:setExtra"
    },
}

















----clothes
Config.ExtrasEnabled = true

Config.Commands = {
    ["top"] = {
        Func = function() ToggleClothing("Top") end,
        Sprite = "top",
        Desc = "Take your shirt off/on",
        Button = 1,
        Name = "Torso"
    },
    ["gloves"] = {
        Func = function() ToggleClothing("gloves") end,
        Sprite = "gloves",
        Desc = "Take your gloves off/on",
        Button = 2,
        Name = "Gloves"
    },
    ["visor"] = {
        Func = function() ToggleProps("visor") end,
        Sprite = "visor",
        Desc = "Toggle hat variation",
        Button = 3,
        Name = "Visor"
    },
    ["bag"] = {
        Func = function() ToggleClothing("Bag") end,
        Sprite = "bag",
        Desc = "Opens or closes your bag",
        Button = 8,
        Name = "Bag"
    },
    ["shoes"] = {
        Func = function() ToggleClothing("Shoes") end,
        Sprite = "shoes",
        Desc = "Take your shoes off/on",
        Button = 5,
        Name = "Shoes"
    },
    ["vest"] = {
        Func = function() ToggleClothing("Vest") end,
        Sprite = "vest",
        Desc = "Take your vest off/on",
        Button = 14,
        Name = "Vest"
    },
    ["hair"] = {
        Func = function() ToggleClothing("hair") end,
        Sprite = "hair",
        Desc = "Put your hair up/down/in a bun/ponytail.",
        Button = 7,
        Name = "Hair"
    },
    ["hat"] = {
        Func = function() ToggleProps("Hat") end,
        Sprite = "hat",
        Desc = "Take your hat off/on",
        Button = 4,
        Name = "Hat"
    },
    ["glasses"] = {
        Func = function() ToggleProps("Glasses") end,
        Sprite = "glasses",
        Desc = "Take your glasses off/on",
        Button = 9,
        Name = "Glasses"
    },
    ["ear"] = {
        Func = function() ToggleProps("Ear") end,
        Sprite = "ear",
        Desc = "Take your ear accessory off/on",
        Button = 10,
        Name = "Ear"
    },
    ["neck"] = {
        Func = function() ToggleClothing("Neck") end,
        Sprite = "neck",
        Desc = "Take your neck accessory off/on",
        Button = 11,
        Name = "Neck"
    },
    ["watch"] = {
        Func = function() ToggleProps("Watch") end,
        Sprite = "watch",
        Desc = "Take your watch off/on",
        Button = 12,
        Name = "Watch",
        Rotation = 5.0
    },
    ["bracelet"] = {
        Func = function() ToggleProps("Bracelet") end,
        Sprite = "bracelet",
        Desc = "Take your bracelet off/on",
        Button = 13,
        Name = "Bracelet"
    },
    ["mask"] = {
        Func = function() ToggleClothing("Mask") end,
        Sprite = "mask",
        Desc = "Take your mask off/on",
        Button = 6,
        Name = "Mask"
    }
}

Config.ExtraCommands = {
    ["pants"] = {
        Func = function() ToggleClothing("Pants", true) end,
        Sprite = "pants",
        Desc = "Take your pants off/on",
        Name = "Pants",
        OffsetX = -0.04,
        OffsetY = 0.0
    },
    ["shirt"] = {
        Func = function() ToggleClothing("Shirt", true) end,
        Sprite = "shirt",
        Desc = "Take your shirt off/on",
        Name = "shirt",
        OffsetX = 0.04,
        OffsetY = 0.0
    },
    ["reset"] = {
        Func = function()
            if not ResetClothing(true) then
                Notify('Nothing To Reset', 'error')
            end
        end,
        Sprite = "reset",
        Desc = "Revert everything back to normal",
        Name = "reset",
        OffsetX = 0.12,
        OffsetY = 0.2,
        Rotate = true
    },
    ["bagoff"] = {
        Func = function() ToggleClothing("Bagoff", true) end,
        Sprite = "bagoff",
        SpriteFunc = function()
            local Bag = GetPedDrawableVariation(PlayerPedId(), 5)
            local BagOff = LastEquipped["Bagoff"]
            if LastEquipped["Bagoff"] then
                if bags[BagOff.Drawable] then
                    return "bagoff"
                else
                    return "paraoff"
                end
            end
            if Bag ~= 0 then
                if bags[Bag] then
                    return "bagoff"
                else
                    return "paraoff"
                end
            else
                return false
            end
        end,
        Desc = "Take your bag off/on",
        Name = "bagoff",
        OffsetX = -0.12,
        OffsetY = 0.2
    }
}
