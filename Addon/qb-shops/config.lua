Config = {}
Config.UseTruckerJob = false -- true = The shops stock is based on when truckers refill it | false = shop inventory never runs out
Config.UseTarget = GetConvar('UseTarget', 'false') == 'true' -- Use qb-target interactions (don't change this, go to your server.cfg and add `setr UseTarget true` to use this and just that from true to false or the other way around)
Config.ShopsInvJsonFile = './json/shops-inventory.json' -- json file location


-- optional requiredJob = {'police', 'ambulance'}
-- optional requiredGang = {'ballas', 'vagps'}
-- optional requiredLicense = {'driver', 'business', 'weapon'}

Config.Products = {
    ["normal"] = {
        ["name"] = "247 Supermarket",
        ["category"] = "Supermarket",
        ["job"] = "",
        ["categoryList"] = {
            ["Foods"] = "Foods for your hunger.",
            ["Drinks"] = "Drinks for your thirst.",
            ["Sweet"] = "Sweet for your mood.",
            ["Other"] = "Other items for your needs.",
        },
        ["itemList"] = {
            ["Foods"] = {
                [1] = {
                    name = "tosti",
                    price = 1,
                    amount = 50,
                    info = {},
                    type = "item",
                },
                [2] = {
                    name = "sandwich",
                    price = 2,
                    amount = 50,
                    info = {},
                    type = "item",
                },
            },
            ["Drinks"] = {
                [1] = {
                    name = "water_bottle",
                    price = 1,
                    amount = 50,
                    info = {},
                    type = "item",
                },
                [2] = {
                    name = "kurkakola",
                    price = 1.5,
                    amount = 50,
                    info = {},
                    type = "item",
                },
            },
            ["Sweet"] = {
                [1] = {
                    name = "twerks_candy",
                    price = 1,
                    amount = 50,
                    info = {},
                    type = "item",
                },
                [2] = {
                    name = "snikkel_candy",
                    price = 1,
                    amount = 50,
                    info = {},
                    type = "item",
                },
            },
            ["Other"] = {
                [1] = {
                    name = "lighter",
                    price = 1,
                    amount = 50,
                    info = {},
                    type = "item",
                },
                [2] = {
                    name = "ciggypack",
                    price = 5,
                    amount = 50,
                    info = {
                        uses = 20,
                    },
                    type = "item",
                },
                [3] = {
                    name = "notebook",
                    price = 3,
                    amount = 50,
                    info = {},
                    type = "item",
                },
            }
        }
    },

    ["liquor"] = {
        ["name"] = "liquor Supermarket",
        ["category"] = "Supermarket",
        ["job"] = "",
        ["categoryList"] = {
            ["Beer"] = "Beer for your thirst.",
            ["Sweet"] = "Sweet for your mood.",
            ["Other"] = "Other items for your needs.",
        },
        ["itemList"] = {
            ["Beer"] = {
                [1] = {
                    name = "beer",
                    price = 4,
                    amount = 50,
                    info = {},
                    type = "item",
                },
                [2] = {
                    name = "whiskey",
                    price = 5,
                    amount = 50,
                    info = {},
                    type = "item",
                },
                [3] = {
                    name = "vodka",
                    price = 5,
                    amount = 50,
                    info = {},
                    type = "item",
                },
            },
            ["Sweet"] = {
                [1] = {
                    name = "twerks_candy",
                    price = 1,
                    amount = 50,
                    info = {},
                    type = "item",
                },
                [2] = {
                    name = "snikkel_candy",
                    price = 1,
                    amount = 50,
                    info = {},
                    type = "item",
                },
            },
            ["Other"] = {
                [1] = {
                    name = "lighter",
                    price = 1,
                    amount = 50,
                    info = {},
                    type = "item",
                },
                [2] = {
                    name = "ciggypack",
                    price = 5,
                    amount = 50,
                    info = {
                        uses = 20,
                    },
                    type = "item",
                },
            }
        }
    },

    ["hardware"] = {
        ["name"] = "Hardware Store",
        ["category"] = "Store",
        ["job"] = "",
        ["categoryList"] = {
            ["General"] = "Diverse items for various needs.",
        },
        ["itemList"] = {
            ["General"] = {
                [1] = {
                    name = "lockpick",
                    price = 10,
                    amount = 50,
                    info = {
                        uses = math.random(3, 5),
                        tier = "low"
                    },
                    type = "item",
                },
                [2] = {
                    name = "repairkit",
                    price = 30,
                    amount = 50,
                    info = {},
                    type = "item",
                },
                [3] = {
                    name = "binoculars",
                    price = 15,
                    amount = 50,
                    info = {},
                    type = "item",
                },
                [4] = {
                    name = "cleaningkit",
                    price = 5,
                    amount = 150,
                    info = {},
                    type = "item",
                },
                [5] = {
                    name = "diving_gear",
                    price = 50,
                    amount = 10,
                    info = {},
                    type = "item",
                },
                [6] = {
                    name = "parachute",
                    price = 50,
                    amount = 10,
                    info = {},
                    type = "item",
                },
                [7] = {
                    name = "tire",
                    price = 50,
                    amount = 10,
                    info = {},
                    type = "item",
                },
                [8] = {
                    name = "a4sheets",
                    price = 50,
                    amount = 10,
                    info = {},
                    type = "item",
                },
                [9] = {
                    name = "blowtorch",
                    price = 50,
                    amount = 10,
                    info = {},
                    type = "item",
                },
                [10] = {
                    name = "screwdriverset",
                    price = 50,
                    amount = 10,
                    info = {},
                    type = "item",
                },
                [11] = {
                    name = "diving_gear",
                    price = 50,
                    amount = 10,
                    info = {},
                    type = "item",
                },
                [12] = {
                    name = "syphoningkit",
                    price = 50,
                    amount = 10,
                    info = {},
                    type = "item",
                },
            },
        }
    },

    ["weapons"] = {
        ["name"] = "Weapon Store",
        ["category"] = "Store",
        ["job"] = "",
        ["categoryList"] = {
            ["Weapon"] = "Lethal tools for self-defense.",
        },
        ["itemList"] = {
            ["Weapon"] = {
                -- [1] = {
                --     name = "weapon_knife",
                --     price = 250,
                --     amount = 250,
                --     info = {},
                --     type = "item",
                -- },

            },
        }
    },

    ["electronic"] = {
        ["name"] = "Electronic Store",
        ["category"] = "Store",
        ["job"] = "",
        ["categoryList"] = {
            ["electronic"] = "Diverse items for various needs.",
        },
        ["itemList"] = {
            ["electronic"] = {
                [1] = {
                    name = 'phone',
                    price = 500,
                    amount = 100,
                    info = {},
                    type = 'item',
                },
                [2] = {
                    name = 'radio',
                    price = 100,
                    amount = 100,
                    info = {},
                    type = 'item',
                },
                [3] = {
                    name = 'camera',
                    price = 200,
                    amount = 100,
                    info = {},
                    type = 'item',
                },
            },
        }
    },
    ["blueprint"] = {
        ["name"] = "blueprint Shops",
        ["category"] = "blueprint",
        ["job"] = "",
        ["categoryList"] = {
            ["blueprint"] = "blueprint",
        },
        ["itemList"] = {
            ["blueprint"] = {
                [1] = {
                    name = "pistolammo_blueprint",
                    price = 500,
                    amount = 50,
                    info = {},
                    type = "item",
                },
                [2] = {
                    name = "sns_blueprint",
                    price = 1500,
                    amount = 50,
                    info = {},
                    type = "item",
                },
                [3] = {
                    name = "snsmk_blueprint",
                    price = 1500,
                    amount = 50,
                    info = {},
                    type = "item",
                },
                [4] = {
                    name = "pistol_blueprint",
                    price = 2000,
                    amount = 50,
                    info = {},
                    type = "item",
                },
                [5] = {
                    name = "mk2_blueprint",
                    price = 2200,
                    amount = 50,
                    info = {},
                    type = "item",
                },
                [6] = {
                    name = "50_blueprint",
                    price = 3000,
                    amount = 50,
                    info = {},
                    type = "item",
                },
                [7] = {
                    name = "heavypistol_blueprint",
                    price = 2500,
                    amount = 50,
                    info = {},
                    type = "item",
                },
                [8] = {
                    name = "vintag_blueprint",
                    price = 1800,
                    amount = 50,
                    info = {},
                    type = "item",
                },
            },
        }
    },
    ["police"] = {
        ["name"] = "Police Armory",
        ["category"] = "Armory",
        ["requiredJob"] = { ["police"] = 1 },
        ["categoryList"] = {
            ["Weapons"] = "Weapons.",
            ["Ammos"] = "Ammos For Your Weapons.",
            ["Items"] = "items.",
            ["Other"] = "Other items for your needs.",
        },
        ["itemList"] = {
            ["Weapons"] = {
                [1] = {
                    name = "weapon_combatpistol",
                    price = 1500,
                    amount = 1,
                    info = {},
                    type = "weapon",
                },
                [2] = {
                    name = "weapon_stungun",
                    price = 500,
                    amount = 1,
                    info = {},
                    type = "weapon",
                },
                [3] = {
                    name = "weapon_flashlight",
                    price = 250,
                    amount = 1,
                    info = {},
                    type = "weapon",
                },
                [4] = {
                    name = "weapon_pistol50",
                    price = 1000,
                    amount = 1,
                    info = {},
                    type = "weapon",
                },
                [5] = {
                    name = "weapon_heavypistol",
                    price = 2000,
                    amount = 1,
                    info = {},
                    type = "weapon",
                },
                [6] = {
                    name = "weapon_carbinerifle",
                    price = 6500,
                    amount = 1,
                    info = { 
                      serie = "",
                      attachments = {
                        {component = "COMPONENT_AT_AR_FLSH", label = "Flashlight"},
                        {component = "COMPONENT_AT_SCOPE_MEDIUM", label = "3x Scope"},
                      }
                    },
                    type = "weapon",
                    authorizedJobGrades = {8, 9, 10, 11, 12}
                },
                [7] = {
                    name = "weaponrepairkit",
                    price = 500,
                    amount = 1,
                    info = {},
                    type = "item",
                },
                [8] = {
                    name = "police_stormram",
                    price = 100,
                    amount = 1,
                    info = {},
                    type = "weapon",
                },
            },
            ["Ammos"] = {
                [1] = {
                    name = "pistol_ammo",
                    price = 75,
                    amount = 50,
                    info = {},
                    type = "item",
                },
                [2] = {
                    name = "smg_ammo",
                    price = 100,
                    amount = 50,
                    info = {},
                    type = "item",
                },
                [3] = {
                    name = "rifle_ammo",
                    price = 150,
                    amount = 50,
                    info = {},
                    type = "item",
                },
            },
            ["Items"] = {
                [1] = {
                    name = "armor",
                    price = 250,
                    amount = 5,
                    info = {},
                    type = "item",
                },
                [2] = {
                    name = "shield",
                    price = 750,
                    amount = 2,
                    info = {},
                    type = "item",
                },
                [3] = {
                    name = "handcuffs",
                    price = 100,
                    amount = 5,
                    info = {},
                    type = "item",
                },
                [4] = {
                    name = "policelaptop",
                    price = 0,
                    amount = 1,
                    info = {},
                    type = "item",
                    authorizedJobGrades = { 9,10, 11, 12}
                },
                [5] = {
                    name = "badge",
                    price = 0,
                    amount = 1,
                    info = {},
                    type = "item",
                },
                [6] = {
                    name = "tracker",
                    price = 100,
                    amount = 1,
                    info = {},
                    type = "item",
                    authorizedJobGrades = {10, 11, 12}
                },
                [7] = {
                    name = "radio",
                    price = 0,
                    amount = 1,
                    info = {},
                    type = "item",
                },
                [8] = {
                    name = "rifle_suppressor",
                    price = 100,
                    amount = 1,
                    info = {},
                    type = "item",
                    authorizedJobGrades = {8, 9, 10, 11, 12}
                },
                [9] = {
                    name = "diving_gear",
                    price = 400,
                    amount = 1,
                    info = {},
                    type = "item",
                },
                [10] = {
                    name = "dslrcamera",
                    price = 100,
                    amount = 1,
                    info = {},
                    type = "item",
                },
                [11] = {
                    name = "bodycam",
                    price = 100,
                    amount = 1,
                    info = {},
                    type = "item",
                },
                [12] = {
                    name = "dashcam",
                    price = 100,
                    amount = 1,
                    info = {},
                    type = "item",
                },
                [13] = {
                    name = "nightvision",
                    price = 100,
                    amount = 1,
                    info = {},
                    type = "item",
                },

            },
            ["Other"] = {
                [1] = {
                    name = "empty_evidence_bag",
                    price = 1,
                    amount = 5,
                    info = {},
                    type = "item",
                },
                [2] = {
                    name = "megaphone",
                    price = 5,
                    amount = 5,
                    info = {
                        uses = 20,
                    },
                    type = "item",
                },
                [3] = {
                    name = "dslrcamera",
                    price = 3,
                    amount = 50,
                    info = {},
                    type = "item",
                },
                [4] = {
                    name = "camviewer",
                    price = 100,
                    amount = 1,
                    info = {},
                    type = "item",
                },
                [5] = {
                    name = "360cctv",
                    price = 100,
                    amount = 1,
                    info = {},
                    type = "item",
                },
                [6] = {
                    name = "cctv",
                    price = 100,
                    amount = 1,
                    info = {},
                    type = "item",
                },
                [7] = {
                    name = "spikestrip",
                    price = 100,
                    amount = 5,
                    info = {},
                    type = "item",
                },
                [8] = {
                    name = "evidencebox",
                    price = 100,
                    amount = 1,
                    info = {},
                    type = "item",
                },
            }
        }
    },           
}


Config.Locations = {
    -- 24/7 Locations
    ["247supermarket"] = {
        ["label"] = "24/7 Supermarket",
        ['coords'] = vector4(24.903238296509, -1347.1453857422, 29.496938705444, 268.16839599609),
        ["ped"] = 'mp_m_shopkeep_01',
        ["scenario"] = "WORLD_HUMAN_STAND_MOBILE",
        ["radius"] = 1.5,        
        ["targetIcon"] = "fas fa-shopping-basket",
        ["targetLabel"] = "Open Shop",
        ["products"] = "normal",
        ["showblip"] = true,
        ["blipsprite"] = 52,
        ["blipscale"] = 0.6,
        ["blipcolor"] = 0,
        ["delivery"] = vector4(26.45, -1315.51, 29.62, 0.07)
    },

    ["247supermarket2"] = {
        ["label"] = "24/7 Supermarket",
        ['coords'] = vector4(-3039.54, 584.38, 7.91, 17.27),
        ["ped"] = 'mp_m_shopkeep_01',
        ["scenario"] = "WORLD_HUMAN_STAND_MOBILE",
        ["radius"] = 1.5,
        ["targetIcon"] = "fas fa-shopping-basket",
        ["targetLabel"] = "Open Shop",
        ["products"] = "normal",
        ["showblip"] = true,
        ["blipsprite"] = 52,
        ["blipscale"] = 0.6,
        ["blipcolor"] = 0,
        ["delivery"] = vector4(-3047.95, 590.71, 7.62, 19.53)
    },

    ["247supermarket3"] = {
        ["label"] = "24/7 Supermarket",
        ['coords'] = vector4(-3242.97, 1000.01, 12.83, 357.57),
        ["ped"] = 'mp_m_shopkeep_01',
        ["scenario"] = "WORLD_HUMAN_STAND_MOBILE",
        ["radius"] = 1.5,
        ["targetIcon"] = "fas fa-shopping-basket",
        ["targetLabel"] = "Open Shop",
        ["products"] = "normal",
        ["showblip"] = true,
        ["blipsprite"] = 52,
        ["blipscale"] = 0.6,
        ["blipcolor"] = 0,
        ["delivery"] = vector4(-3245.76, 1005.25, 12.83, 269.45)
    },

    ["247supermarket4"] = {
        ["label"] = "24/7 Supermarket",
        ['coords'] = vector4(1728.07, 6415.63, 35.04, 242.95),
        ["ped"] = 'mp_m_shopkeep_01',
        ["scenario"] = "WORLD_HUMAN_STAND_MOBILE",
        ["radius"] = 1.5,
        ["targetIcon"] = "fas fa-shopping-basket",
        ["targetLabel"] = "Open Shop",
        ["products"] = "normal",
        ["showblip"] = true,
        ["blipsprite"] = 52,
        ["blipscale"] = 0.6,
        ["blipcolor"] = 0,
        ["delivery"] = vector4(1741.76, 6419.61, 35.04, 6.83)
    },

    ["247supermarket5"] = {
        ["label"] = "24/7 Supermarket",
        ['coords'] = vector4(1959.82, 3740.48, 32.34, 301.57),
        ["ped"] = 'mp_m_shopkeep_01',
        ["scenario"] = "WORLD_HUMAN_STAND_MOBILE",
        ["radius"] = 1.5,
        ["targetIcon"] = "fas fa-shopping-basket",
        ["targetLabel"] = "Open Shop",
        ["products"] = "normal",
        ["showblip"] = true,
        ["blipsprite"] = 52,
        ["blipscale"] = 0.6,
        ["blipcolor"] = 0,
        ["delivery"] = vector4(1963.81, 3750.09, 32.26, 302.46)
    },

    ["247supermarket6"] = {
        ["label"] = "24/7 Supermarket",
        ['coords'] = vector4(549.13, 2670.85, 42.16, 99.39),
        ["ped"] = 'mp_m_shopkeep_01',
        ["scenario"] = "WORLD_HUMAN_STAND_MOBILE",
        ["radius"] = 1.5,
        ["targetIcon"] = "fas fa-shopping-basket",
        ["targetLabel"] = "Open Shop",
        ["products"] = "normal",
        ["showblip"] = true,
        ["blipsprite"] = 52,
        ["blipscale"] = 0.6,
        ["blipcolor"] = 0,
        ["delivery"] = vector4(541.54, 2663.53, 42.17, 120.51)
    },

    ["247supermarket7"] = {
        ["label"] = "24/7 Supermarket",
        ['coords'] = vector4(2677.47, 3279.76, 55.24, 335.08),
        ["ped"] = 'mp_m_shopkeep_01',
        ["scenario"] = "WORLD_HUMAN_STAND_MOBILE",
        ["radius"] = 1.5,
        ["targetIcon"] = "fas fa-shopping-basket",
        ["targetLabel"] = "Open Shop",
        ["products"] = "normal",
        ["showblip"] = true,
        ["blipsprite"] = 52,
        ["blipscale"] = 0.6,
        ["blipcolor"] = 0,
        ["delivery"] = vector4(2662.19, 3264.95, 55.24, 168.55)
    },

    ["247supermarket8"] = {
        ["label"] = "24/7 Supermarket",
        ['coords'] = vector4(2556.66, 380.84, 108.62, 356.67),
        ["ped"] = 'mp_m_shopkeep_01',
        ["scenario"] = "WORLD_HUMAN_STAND_MOBILE",
        ["radius"] = 1.5,
        ["targetIcon"] = "fas fa-shopping-basket",
        ["targetLabel"] = "Open Shop",
        ["products"] = "normal",
        ["showblip"] = true,
        ["blipsprite"] = 52,
        ["blipscale"] = 0.6,
        ["blipcolor"] = 0,
        ["delivery"] = vector4(2553.24, 399.73, 108.56, 344.86)
    },

    ["247supermarket9"] = {
        ["label"] = "24/7 Supermarket",
        ['coords'] = vector4(372.66, 326.98, 103.57, 253.73),
        ["ped"] = 'mp_m_shopkeep_01',
        ["scenario"] = "WORLD_HUMAN_STAND_MOBILE",
        ["radius"] = 1.5,
        ["targetIcon"] = "fas fa-shopping-basket",
        ["targetLabel"] = "Open Shop",
        ["products"] = "normal",
        ["showblip"] = true,
        ["blipsprite"] = 52,
        ["blipscale"] = 0.6,
        ["blipcolor"] = 0,
        ["delivery"] = vector4(379.97, 357.3, 102.56, 26.42)
    },

    ["247supermarket10"] = {
        ["label"] = "24/7 Supermarket",
        ['coords'] = vector4(-548.47, -582.94, 34.68, 177.83),
        ["ped"] = 'mp_m_shopkeep_01',
        ["scenario"] = "WORLD_HUMAN_STAND_MOBILE",
        ["radius"] = 1.5,
        ["targetIcon"] = "fas fa-shopping-basket",
        ["targetLabel"] = "Open Shop",
        ["products"] = "normal",
        ["showblip"] = true,
        ["blipsprite"] = 52,
        ["blipscale"] = 0.6,
        ["blipcolor"] = 0,
        ["delivery"] = vector4(-548.47, -582.94, 34.68, 177.83)
    },

    -- LTD Gasoline Locations
    ["ltdgasoline"] = {
        ["label"] = "24/7 Supermarket",
        ["coords"] = vector4(-47.02, -1758.23, 29.42, 45.05),
        ["ped"] = 'mp_m_shopkeep_01',
        ["scenario"] = "WORLD_HUMAN_STAND_MOBILE",
        ["radius"] = 1.5,
        ["targetIcon"] = "fas fa-shopping-basket",
        ["targetLabel"] = "Open Shop",
        ["products"] = "normal",
        ["showblip"] = true,
        ["blipsprite"] = 52,
        ["blipscale"] = 0.6,
        ["blipcolor"] = 0,
        ["delivery"] = vector4(-40.51, -1747.45, 29.29, 326.39)
    },

    ["ltdgasoline2"] = {
        ["label"] = "24/7 Supermarket",
        ["coords"] = vector4(-706.06, -913.97, 19.22, 88.04),
        ["ped"] = 'mp_m_shopkeep_01',
        ["scenario"] = "WORLD_HUMAN_STAND_MOBILE",
        ["radius"] = 1.5,
        ["targetIcon"] = "fas fa-shopping-basket",
        ["targetLabel"] = "Open Shop",
        ["products"] = "normal",
        ["showblip"] = true,
        ["blipsprite"] = 52,
        ["blipscale"] = 0.6,
        ["blipcolor"] = 0,
        ["delivery"] = vector4(-702.89, -917.44, 19.21, 181.96)
    },

    ["ltdgasoline3"] = {
        ["label"] = "24/7 Supermarket",
        ["coords"] = vector4(-1820.02, 794.03, 138.09, 135.45),
        ["ped"] = 'mp_m_shopkeep_01',
        ["scenario"] = "WORLD_HUMAN_STAND_MOBILE",
        ["radius"] = 1.5,
        ["targetIcon"] = "fas fa-shopping-basket",
        ["targetLabel"] = "Open Shop",
        ["products"] = "normal",
        ["showblip"] = true,
        ["blipsprite"] = 52,
        ["blipscale"] = 0.6,
        ["blipcolor"] = 0,
        ["delivery"] = vector4(-1829.29, 801.49, 138.41, 41.39)
    },

    ["ltdgasoline4"] = {
        ["label"] = "24/7 Supermarket",
        ["coords"] = vector4(1164.71, -322.94, 69.21, 101.72),
        ["ped"] = 'mp_m_shopkeep_01',
        ["scenario"] = "WORLD_HUMAN_STAND_MOBILE",
        ["radius"] = 1.5,
        ["targetIcon"] = "fas fa-shopping-basket",
        ["targetLabel"] = "Open Open Shop",
        ["products"] = "normal",
        ["showblip"] = true,
        ["blipsprite"] = 52,
        ["blipscale"] = 0.6,
        ["blipcolor"] = 0,
        ["delivery"] = vector4(1160.62, -312.06, 69.28, 3.77)
    },

    ["ltdgasoline5"] = {
        ["label"] = "24/7 Supermarket",
        ["coords"] = vector4(1697.87, 4922.96, 42.06, 324.71),
        ["ped"] = 'mp_m_shopkeep_01',
        ["scenario"] = "WORLD_HUMAN_STAND_MOBILE",
        ["radius"] = 1.5,
        ["targetIcon"] = "fas fa-shopping-basket",
        ["targetLabel"] = "Open Shop",
        ["products"] = "normal",
        ["showblip"] = true,
        ["blipsprite"] = 52,
        ["blipscale"] = 0.6,
        ["blipcolor"] = 0,
        ["delivery"] = vector4(1702.68, 4917.28, 42.22, 139.27)
    },

    -- Rob's Liquor Locations
    ["robsliquor"] = {
        ["label"] = "Rob's Liqour",
        ["coords"] = vector4(-1221.58, -908.15, 12.33, 35.49),
        ["ped"] = 'mp_m_shopkeep_01',
        ["scenario"] = "WORLD_HUMAN_STAND_MOBILE",
        ["radius"] = 1.5,
        ["targetIcon"] = "fas fa-shopping-basket",
        ["targetLabel"] = "Open Shop",
        ["products"] = "liquor",
        ["showblip"] = true,
        ["blipsprite"] = 52,
        ["blipscale"] = 0.6,
        ["blipcolor"] = 0,
        ["delivery"] = vector4(-1226.92, -901.82, 12.28, 213.26)
    },

    ["robsliquor2"] = {
        ["label"] = "Rob's Liqour",
        ["coords"] = vector4(-1486.59, -377.68, 40.16, 139.51),
        ["ped"] = 'mp_m_shopkeep_01',
        ["scenario"] = "WORLD_HUMAN_STAND_MOBILE",
        ["radius"] = 1.5,
        ["targetIcon"] = "fas fa-shopping-basket",
        ["targetLabel"] = "Open Shop",
        ["products"] = "liquor",
        ["showblip"] = true,
        ["blipsprite"] = 52,
        ["blipscale"] = 0.6,
        ["blipcolor"] = 0,
        ["delivery"] = vector4(-1468.29, -387.61, 38.79, 220.13)
    },

    ["robsliquor3"] = {
        ["label"] = "Rob's Liqour",
        ["coords"] = vector4(-2966.39, 391.42, 15.04, 87.48),
        ["ped"] = 'mp_m_shopkeep_01',
        ["scenario"] = "WORLD_HUMAN_STAND_MOBILE",
        ["radius"] = 1.5,
        ["targetIcon"] = "fas fa-shopping-basket",
        ["targetLabel"] = "Open Shop",
        ["products"] = "liquor",
        ["showblip"] = true,
        ["blipsprite"] = 52,
        ["blipscale"] = 0.6,
        ["blipcolor"] = 0,
        ["delivery"] = vector4(-2961.49, 376.25, 15.02, 111.41)
    },

    ["robsliquor4"] = {
        ["label"] = "Rob's Liqour",
        ["coords"] = vector4(1165.17, 2710.88, 38.16, 179.43),
        ["ped"] = 'mp_m_shopkeep_01',
        ["scenario"] = "WORLD_HUMAN_STAND_MOBILE",
        ["radius"] = 1.5,
        ["targetIcon"] = "fas fa-shopping-basket",
        ["targetLabel"] = "Open Shop",
        ["products"] = "liquor",
        ["showblip"] = true,
        ["blipsprite"] = 52,
        ["blipscale"] = 0.6,
        ["blipcolor"] = 0,
        ["delivery"] = vector4(1194.52, 2722.21, 38.62, 9.37)
    },

    ["robsliquor5"] = {
        ["label"] = "Rob's Liqour",
        ["coords"] = vector4(1134.2, -982.91, 46.42, 277.24),
        ["ped"] = 'mp_m_shopkeep_01',
        ["scenario"] = "WORLD_HUMAN_STAND_MOBILE",
        ["radius"] = 1.5,
        ["targetIcon"] = "fas fa-shopping-basket",
        ["targetLabel"] = "Open Shop",
        ["products"] = "liquor",
        ["showblip"] = true,
        ["blipsprite"] = 52,
        ["blipscale"] = 0.6,
        ["blipcolor"] = 0,
        ["delivery"] = vector4(1129.73, -989.27, 45.97, 280.98)
    },

    -- Hardware Store Locations
    ["hardware"] = {
        ["label"] = "Hardware Store",
        ["coords"] = vector4(2736.9658, 3462.3054, 55.695678, 338.75286),
        ["ped"] = 'mp_m_waremech_01',
        ["scenario"] = "WORLD_HUMAN_CLIPBOARD",
        ["radius"] = 1.5,
        ["targetIcon"] = "fas fa-wrench",
        ["targetLabel"] = "Open Hardware Store",
        ["products"] = "hardware",
        ["showblip"] = true,
        ["blipsprite"] = 402,
        ["blipscale"] = 0.6,
        ["blipcolor"] = 0,
        ["delivery"] = vector4(2704.68, 3457.21, 55.54, 176.28)
    },

    -- ["hardware2"] = {
    --     ["label"] = "Hardware Store",
    --     ["coords"] = vector4(45.68, -1749.04, 29.61, 53.13),
    --     ["ped"] = 'mp_m_waremech_01',
    --     ["scenario"] = "WORLD_HUMAN_CLIPBOARD",
    --     ["radius"] = 1.5,
    --     ["targetIcon"] = "fas fa-wrench",
    --     ["targetLabel"] = "Open Hardware Store",
    --     ["products"] = "hardware",
    --     ["showblip"] = true,
    --     ["blipsprite"] = 402,
    --     ["blipscale"] = 0.6,
    --     ["blipcolor"] = 0,
    --     ["delivery"] = vector4(89.15, -1745.29, 30.09, 315.25)
    -- },

    -- ["hardware3"] = {
    --     ["label"] = "Hardware Store",
    --     ["coords"] = vector4(-421.83, 6136.13, 31.88, 228.2),
    --     ["ped"] = 'mp_m_waremech_01',
    --     ["scenario"] = "WORLD_HUMAN_CLIPBOARD",
    --     ["radius"] = 1.5,
    --     ["targetIcon"] = "fas fa-wrench",
    --     ["targetLabel"] = "Hardware Store",
    --     ["products"] = "hardware",
    --     ["showblip"] = true,
    --     ["blipsprite"] = 402,
    --     ["blipscale"] = 0.6,
    --     ["blipcolor"] = 0,
    --     ["delivery"] = vector4(-438.25, 6146.9, 31.48, 136.99)
    -- },

    -- Ammunation Locations
    -- ["ammunation"] = {
    --     ["label"] = "Ammunation",
    --     ["type"] = "weapon",
    --     ["coords"] = vector4(-661.96, -933.53, 21.83, 177.05),
    --     ["ped"] = 's_m_y_ammucity_01',
    --     ["scenario"] = "WORLD_HUMAN_COP_IDLES",
    --     ["radius"] = 1.5,
    --     ["targetIcon"] = "fas fa-gun",
    --     ["targetLabel"] = "Open Ammunation",
    --     ["products"] = "weapons",
    --     ["showblip"] = true,
    --     ["blipsprite"] = 110,
    --     ["blipscale"] = 0.6,
    --     ["blipcolor"] = 0,
    --     ["delivery"] = vector4(-660.61, -938.14, 21.83, 167.22)
    -- },
    -- ["ammunation2"] = {
    --     ["label"] = "Ammunation",
    --     ["type"] = "weapon",
    --     ["coords"] = vector4(809.68, -2159.13, 29.62, 1.43),
    --     ["ped"] = 's_m_y_ammucity_01',
    --     ["scenario"] = "WORLD_HUMAN_COP_IDLES",
    --     ["radius"] = 1.5,
    --     ["targetIcon"] = "fas fa-gun",
    --     ["targetLabel"] = "Open Ammunation",
    --     ["products"] = "weapons",
    --     ["showblip"] = true,
    --     ["blipsprite"] = 110,
    --     ["blipscale"] = 0.6,
    --     ["blipcolor"] = 0,
    --     ["delivery"] = vector4(820.97, -2146.7, 28.71, 359.98)
    -- },
    -- ["ammunation3"] = {
    --     ["label"] = "Ammunation",
    --     ["type"] = "weapon",
    --     ["coords"] = vector4(1692.67, 3761.38, 34.71, 227.65),
    --     ["ped"] = 's_m_y_ammucity_01',
    --     ["scenario"] = "WORLD_HUMAN_COP_IDLES",
    --     ["radius"] = 1.5,
    --     ["targetIcon"] = "fas fa-gun",
    --     ["targetLabel"] = "Open Ammunation",
    --     ["products"] = "weapons",
    --     ["showblip"] = true,
    --     ["blipsprite"] = 110,
    --     ["blipscale"] = 0.6,
    --     ["blipcolor"] = 0,
    --     ["delivery"] = vector4(1687.17, 3755.47, 34.34, 163.69)
    -- },
    -- ["ammunation4"] = {
    --     ["label"] = "Ammunation",
    --     ["type"] = "weapon",
    --     ["coords"] = vector4(-331.23, 6085.37, 31.45, 228.02),
    --     ["ped"] = 's_m_y_ammucity_01',
    --     ["scenario"] = "WORLD_HUMAN_COP_IDLES",
    --     ["radius"] = 1.5,
    --     ["targetIcon"] = "fas fa-gun",
    --     ["targetLabel"] = "Open Ammunation",
    --     ["products"] = "weapons",
    --     ["showblip"] = true,
    --     ["blipsprite"] = 110,
    --     ["blipscale"] = 0.6,
    --     ["blipcolor"] = 0,
    --     ["delivery"] = vector4(-341.72, 6098.49, 31.32, 11.05)
    -- },
    -- ["ammunation5"] = {
    --     ["label"] = "Ammunation",
    --     ["type"] = "weapon",
    --     ["coords"] = vector4(253.63, -51.02, 69.94, 72.91),
    --     ["ped"] = 's_m_y_ammucity_01',
    --     ["scenario"] = "WORLD_HUMAN_COP_IDLES",
    --     ["radius"] = 1.5,
    --     ["targetIcon"] = "fas fa-gun",
    --     ["targetLabel"] = "Open Ammunation",
    --     ["products"] = "weapons",
    --     ["showblip"] = true,
    --     ["blipsprite"] = 110,
    --     ["blipscale"] = 0.6,
    --     ["blipcolor"] = 0,
    --     ["delivery"] = vector4(249.0, -50.64, 69.94, 60.71)
    -- },
    -- ["ammunation6"] = {
    --     ["label"] = "Ammunation",
    --     ["type"] = "weapon",
    --     ["coords"] = vector4(23.0, -1105.67, 29.8, 162.91),
    --     ["ped"] = 's_m_y_ammucity_01',
    --     ["scenario"] = "WORLD_HUMAN_COP_IDLES",
    --     ["radius"] = 1.5,
    --     ["targetIcon"] = "fas fa-gun",
    --     ["targetLabel"] = "Open Ammunation",
    --     ["products"] = "weapons",
    --     ["showblip"] = true,
    --     ["blipsprite"] = 110,
    --     ["blipscale"] = 0.6,
    --     ["blipcolor"] = 0,
    --     ["delivery"] = vector4(-5.82, -1107.48, 29.0, 164.32)
    -- },
    -- ["ammunation7"] = {
    --     ["label"] = "Ammunation",
    --     ["type"] = "weapon",
    --     ["coords"] = vector4(2567.48, 292.59, 108.73, 349.68),
    --     ["ped"] = 's_m_y_ammucity_01',
    --     ["scenario"] = "WORLD_HUMAN_COP_IDLES",
    --     ["radius"] = 1.5,
    --     ["targetIcon"] = "fas fa-gun",
    --     ["targetLabel"] = "Open Ammunation",
    --     ["products"] = "weapons",
    --     ["showblip"] = true,
    --     ["blipsprite"] = 110,
    --     ["blipscale"] = 0.6,
    --     ["blipcolor"] = 0,
    --     ["delivery"] = vector4(2578.77, 285.53, 108.61, 277.2)
    -- },
    -- ["ammunation8"] = {
    --     ["label"] = "Ammunation",
    --     ["type"] = "weapon",
    --     ["coords"] = vector4(-1118.59, 2700.05, 18.55, 221.89),
    --     ["ped"] = 's_m_y_ammucity_01',
    --     ["scenario"] = "WORLD_HUMAN_COP_IDLES",
    --     ["radius"] = 1.5,
    --     ["targetIcon"] = "fas fa-gun",
    --     ["targetLabel"] = "Open Ammunation",
    --     ["products"] = "weapons",
    --     ["showblip"] = true,
    --     ["blipsprite"] = 110,
    --     ["blipscale"] = 0.6,
    --     ["blipcolor"] = 0,
    --     ["delivery"] = vector4(-1127.67, 2708.18, 18.8, 41.76)
    -- },
    -- ["ammunation9"] = {
    --     ["label"] = "Ammunation",
    --     ["type"] = "weapon",
    --     ["coords"] = vector4(841.92, -1035.32, 28.19, 1.56),
    --     ["ped"] = 's_m_y_ammucity_01',
    --     ["scenario"] = "WORLD_HUMAN_COP_IDLES",
    --     ["radius"] = 1.5,
    --     ["targetIcon"] = "fas fa-gun",
    --     ["targetLabel"] = "Open Ammunation",
    --     ["products"] = "weapons",
    --     ["showblip"] = true,
    --     ["blipsprite"] = 110,
    --     ["blipscale"] = 0.6,
    --     ["blipcolor"] = 0,
    --     ["delivery"] = vector4(847.83, -1020.36, 27.88, 88.29)
    -- },
    -- ["ammunation10"] = {
    --     ["label"] = "Ammunation",
    --     ["type"] = "weapon",
    --     ["coords"] = vector4(-1304.19, -395.12, 36.7, 75.03),
    --     ["ped"] = 's_m_y_ammucity_01',
    --     ["scenario"] = "WORLD_HUMAN_COP_IDLES",
    --     ["radius"] = 1.5,
    --     ["targetIcon"] = "fas fa-gun",
    --     ["targetLabel"] = "Open Ammunation",
    --     ["products"] = "weapons",
    --     ["showblip"] = true,
    --     ["blipsprite"] = 110,
    --     ["blipscale"] = 0.6,
    --     ["blipcolor"] = 0,
    --     ["delivery"] = vector4(-1302.44, -385.23, 36.62, 303.79)
    -- },
    -- ["ammunation11"] = {
    --     ["label"] = "Ammunation",
    --     ["type"] = "weapon",
    --     ["coords"] = vector4(-3173.31, 1088.85, 20.84, 244.18),
    --     ["ped"] = 's_m_y_ammucity_01',
    --     ["scenario"] = "WORLD_HUMAN_COP_IDLES",
    --     ["radius"] = 1.5,
    --     ["targetIcon"] = "fas fa-gun",
    --     ["targetLabel"] = "Open Ammunation",
    --     ["products"] = "weapons",
    --     ["showblip"] = true,
    --     ["blipsprite"] = 110,
    --     ["blipscale"] = 0.6,
    --     ["blipcolor"] = 0,
    --     ["delivery"] = vector4(-3183.6, 1084.35, 20.84, 68.13)
    -- },

    -- Casino Locations
    -- ["casino"] = {
    --     ["label"] = "Diamond Casino",
    --     ["coords"] = vector4(978.46, 39.07, 74.88, 64.0),
    --     ["ped"] = 'csb_tomcasino',
    --     ["scenario"] = "WORLD_HUMAN_STAND_MOBILE",
    --     ["radius"] = 1.5,
    --     ["targetIcon"] = "fas fa-coins",
    --     ["targetLabel"] = "Buy Chips",
    --     ["products"] = "casino",
    --     ["showblip"] = true,
    --     ["blipsprite"] = 617,
    --     ["blipscale"] = 0.6,
    --     ["blipcolor"] = 0,
    --     ["delivery"] = vector4(972.6, 9.22, 81.04, 233.38)
    -- },

    -- ["casinobar"] = {
    --     ["label"] = "Casino Bar",
    --     ["coords"] = vector4(968.13, 29.85, 74.88, 208.86),
    --     ["ped"] = 'a_m_y_smartcaspat_01',
    --     ["scenario"] = "WORLD_HUMAN_VALET",
    --     ["radius"] = 1.5,
    --     ["targetIcon"] = "fas fa-wine-bottle",
    --     ["targetLabel"] = "Open Casino Bar",
    --     ["products"] = "liquor",
    --     ["showblip"] = false,
    --     ["blipsprite"] = 52,
    --     ["blipscale"] = 0.6,
    --     ["blipcolor"] = 0,
    --     ["delivery"] = vector4(937.16, 1.0, 78.76, 152.4)
    -- },

    ["electronic"] = {
        ["label"] = "Click Lovers",
        ["coords"] = vector4(212.60856, -1507.437, 29.294555, 220.72323),
        ["ped"] = 'a_m_y_stwhi_02',
        ["scenario"] = "WORLD_HUMAN_VALET",
        ["radius"] = 1.5,
        ["targetIcon"] = "fas fa-mobile",
        ["targetLabel"] = "Open Electronic shop",
        ["products"] = "electronic",
        ["showblip"] = true,
        ["blipsprite"] = 89,
        ["blipscale"] = 0.6,
        ["blipcolor"] = 1,
        ["delivery"] = vector4(937.16, 1.0, 78.76, 152.4)
    },

    ["electronic1"] = {
        ["label"] = "iFruit",
        ["coords"] = vector4(1134.43, -468.15, 66.49, 164.99),
        ["ped"] = 'a_m_y_soucent_01',
        ["scenario"] = "WORLD_HUMAN_VALET",
        ["radius"] = 1.5,
        ["targetIcon"] = "fas fa-mobile",
        ["targetLabel"] = "Open Electronic shop",
        ["products"] = "electronic",
        ["showblip"] = true,
        ["blipsprite"] = 521,
        ["blipscale"] = 0.6,
        ["blipcolor"] = 4,
        ["delivery"] = vector4(1134.43, -468.15, 66.49, 164.99)
    },

    ["electronic2"] = {
        ["label"] = "iFruit",
        ["coords"] = vector4(-529.24, -582.73, 34.68, 180.61),
        ["ped"] = 'a_m_y_soucent_01',
        ["scenario"] = "WORLD_HUMAN_VALET",
        ["radius"] = 1.5,
        ["targetIcon"] = "fas fa-mobile",
        ["targetLabel"] = "Open Electronic shop",
        ["products"] = "electronic",
        ["showblip"] = true,
        ["blipsprite"] = 521,
        ["blipscale"] = 0.6,
        ["blipcolor"] = 4,
        ["delivery"] = vector4(-529.24, -582.73, 34.68, 180.61)
    },

    -- Weedshop Locations
    -- ["weedshop"] = {
    --     ["label"] = "Smoke On The Water",
    --     ["coords"] = vector4(-1168.26, -1573.2, 4.66, 105.24),
    --     ["ped"] = 'a_m_y_hippy_01',
    --     ["scenario"] = "WORLD_HUMAN_AA_SMOKE",
    --     ["radius"] = 1.5,
    --     ["targetIcon"] = "fas fa-cannabis",
    --     ["targetLabel"] = "Open Weed Shop",
    --     ["products"] = "weedshop",
    --     ["showblip"] = true,
    --     ["blipsprite"] = 140,
    --     ["blipscale"] = 0.6,
    --     ["blipcolor"] = 0,
    --     ["delivery"] = vector4(-1162.13, -1568.57, 4.39, 328.52)
    -- },

    -- Sea Word Locations
    -- ["seaword"] = {
    --     ["label"] = "Sea Word",
    --     ["coords"] = vector4(-1687.03, -1072.18, 13.15, 52.93),
    --     ["ped"] = 'a_m_y_beach_01',
    --     ["scenario"] = "WORLD_HUMAN_STAND_IMPATIENT",
    --     ["radius"] = 1.5,
    --     ["targetIcon"] = "fas fa-fish",
    --     ["targetLabel"] = "Sea Word",
    --     ["products"] = "gearshop",
    --     ["showblip"] = true,
    --     ["blipsprite"] = 52,
    --     ["blipscale"] = 0.6,
    --     ["blipcolor"] = 0,
    --     ["delivery"] = vector4(-1674.18, -1073.7, 13.15, 333.56)
    -- },

    -- Leisure Shop Locations
    -- ["leisureshop"] = {
    --     ["label"] = "Leisure Shop",
    --     ["coords"] = vector4(-1505.91, 1511.95, 115.29, 257.13),
    --     ["ped"] = 'a_m_y_beach_01',
    --     ["scenario"] = "WORLD_HUMAN_STAND_MOBILE_CLUBHOUSE",
    --     ["radius"] = 1.5,
    --     ["targetIcon"] = "fas fa-leaf",
    --     ["targetLabel"] = "Open Leisure Shop",
    --     ["products"] = "leisureshop",
    --     ["showblip"] = true,
    --     ["blipsprite"] = 52,
    --     ["blipscale"] = 0.6,
    --     ["blipcolor"] = 0,
    --     ["delivery"] = vector4(-1507.64, 1505.52, 115.29, 262.2)
    -- },

    ["blueprint"] = {
        ["label"] = "blueprint Shops",
        ['coords'] = vector4(927.58, -1983.69, 30.28, 180.75),
        ["ped"] = 'mp_m_shopkeep_01',
        ["scenario"] = "WORLD_HUMAN_STAND_MOBILE",
        ["radius"] = 1.5,        
        ["targetIcon"] = "fas fa-shopping-basket",
        ["targetLabel"] = "Open Shop",
        ["products"] = "blueprint",
        ["showblip"] = false,
        ["blipsprite"] = 52,
        ["blipscale"] = 0.6,
        ["blipcolor"] = 0,
        ["delivery"] = vector4(927.58, -1983.69, 30.28, 180.75)
    },
    -- ["police"] = {
     --   ["label"] = "Police Armory",
    --    ['coords'] = vector4(455.65, -973.78, 30.25, 163.19),
     --   ["ped"] = 's_m_m_armoured_01',
     --   ["scenario"] = "WORLD_HUMAN_STAND_MOBILE",
      --  ["radius"] = 1.5,        
     --   ["targetIcon"] = "fas fa-shopping-basket",
      --  ["targetLabel"] = "Open Police Armory",
     --   ["products"] = "police",
     --  ["showblip"] = false,
      --  ["blipsprite"] = 52,
      --  ["blipscale"] = 0.6,
      --  ["blipcolor"] = 0,
      --  ["delivery"] = vector4(927.58, -1983.69, 30.28, 180.75)
   -- },
}
