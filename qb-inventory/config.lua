Config = {}

-- ════════════════════════════════════════════════════════════
--  General
-- ════════════════════════════════════════════════════════════
Config.UseTarget = GetConvar('UseTarget', 'false') == 'true' -- set `setr UseTarget true` in server.cfg to use qb-target

Config.MaxInventoryWeight = 120000 -- grams (120 kg)
Config.MaxInventorySlots = 41      -- slot 41 is the 6th hotbar key
Config.Blur = true                 -- blur the game behind the inventory
Config.InventorySide = 'left'      -- 'left' or 'right' side of the screen
Config.BrandTag = 'JT'             -- small text on the blue line between the inventories

-- ════════════════════════════════════════════════════════════
--  Opening emote (plays a short animation, then the inventory opens)
--  Set enabled = false to open instantly. Any animation can be changed.
-- ════════════════════════════════════════════════════════════
Config.OpenAnimation = {
    enabled = true,
    player = { dict = 'missmic4', clip = 'michael_tux_fidget', delay = 650, flag = 48 },          -- checks the pockets
    trunk  = { dict = 'amb@prop_human_bum_bin@idle_b', clip = 'idle_d', delay = 600, flag = 49 },  -- reaches into the trunk (kept until closed)
    drop   = { dict = 'pickup_object', clip = 'pickup_low', delay = 700, flag = 48 },              -- bends down to the bag on the ground
    glovebox = { delay = 250 },                                                                    -- no body animation inside a vehicle
}

-- ════════════════════════════════════════════════════════════
--  Ground drops
-- ════════════════════════════════════════════════════════════
Config.EnableDrops = true                 -- false = the "Drop" option is removed (items can't be dropped)
Config.CleanupDropTime = 15 * 60          -- seconds an untouched drop stays on the ground
Config.MaxDropViewDistance = 12.5         -- distance the drop marker/bag is shown
Config.DropInteractDistance = 1.5         -- distance to open a drop with TAB
Config.UseItemDrop = true                 -- spawn a bag prop instead of a marker
Config.ItemDropObject = `prop_paper_bag_small`
Config.DropSlots = 30
Config.DropMaxWeight = 100000

-- ════════════════════════════════════════════════════════════
--  Security
-- ════════════════════════════════════════════════════════════
Config.RobDistance = 3.0                  -- max distance to search / rob another player
Config.GiveDistance = 3.0                 -- max distance to give an item
Config.TrunkDistance = 8.0                -- max distance to a spawned vehicle to use its trunk
Config.MaxStashWeight = 10000000          -- upper limit for stash sizes requested by other scripts
Config.MaxStashSlots = 200
Config.PoliceJobs = { ['police'] = true }  -- jobs that can open "POL" vehicle trunks
Config.PoliceSearchLocation = vector3(482.03, -1008.99, 26.27) -- police here can also see the last slot when searching
Config.TrunkItemJobs = { ['police'] = true, ['ambulance'] = true } -- jobs allowed to preload trunk items (inventory:server:addTrunkItems)

-- Trunk size per GTA vehicle class (the server decides, not the client)
Config.TrunkSizes = {
    [0] = { maxweight = 38000, slots = 30 },   -- Compacts
    [1] = { maxweight = 50000, slots = 40 },   -- Sedans
    [2] = { maxweight = 75000, slots = 50 },   -- SUVs
    [3] = { maxweight = 42000, slots = 35 },   -- Coupes
    [4] = { maxweight = 38000, slots = 30 },   -- Muscle
    [5] = { maxweight = 30000, slots = 25 },   -- Sports Classics
    [6] = { maxweight = 30000, slots = 25 },   -- Sports
    [7] = { maxweight = 30000, slots = 25 },   -- Super
    [8] = { maxweight = 15000, slots = 15 },   -- Motorcycles
    [9] = { maxweight = 60000, slots = 35 },   -- Off-road
    [12] = { maxweight = 120000, slots = 35 }, -- Vans
    [13] = { maxweight = 0, slots = 0 },       -- Cycles
    [14] = { maxweight = 120000, slots = 50 }, -- Boats
    [15] = { maxweight = 120000, slots = 50 }, -- Helicopters
    [16] = { maxweight = 120000, slots = 50 }, -- Planes
    default = { maxweight = 60000, slots = 35 },
}
Config.GloveboxSize = { maxweight = 10000, slots = 5 }

-- ════════════════════════════════════════════════════════════
--  Interactions
-- ════════════════════════════════════════════════════════════
Config.VendingObjects = {
    "prop_vend_soda_01",
    "prop_vend_soda_02",
    "prop_vend_water_01",
}
Config.VendingObjects2 = {
    "prop_vend_snak_01",
}

-- Trash bins open a temporary bin (items are destroyed). Uses "interact" or qb-target if started.
Config.EnableTrash = true
Config.TrashModels = {
    "prop_bin_05a", "prop_bin_01a", "v_ind_cfwaste", "prop_bin_08a", "prop_bin_08open", "prop_bin_02a",
    "prop_bin_03a", "prop_bin_04a", "prop_bin_06a", "prop_bin_07a", "prop_bin_07b", "prop_bin_07c",
    "prop_bin_07d", "prop_bin_10a", "prop_bin_10b", "prop_bin_11a", "prop_bin_11b", "prop_bin_12a",
}

Config.CraftingObject = `prop_toolchest_05`

Config.VendingItem = {
    [1] = {
        name = "kurkakola",
        price = 110,
        amount = 50,
        info = {},
        type = "item",
        slot = 1,
    },
    [2] = {
        name = "water_bottle",
        price = 110,
        amount = 50,
        info = {},
        type = "item",
        slot = 2,
    },
}

Config.VendingSnaksItem = {
    [1] = {
        name = "tosti",
        price = 100,
        amount = 50,
        info = {},
        type = "item",
        slot = 1,
    },
    [2] = {
        name = "twerks_candy",
        price = 80,
        amount = 50,
        info = {},
        type = "item",
        slot = 2,
    },
}

Config.CraftingItems = {
    [1] = {
        name = "lockpick",
        amount = 50,
        info = {},
        costs = {
            ["metalscrap"] = 22,
            ["plastic"] = 32,
        },
        type = "item",
        slot = 1,
        threshold = 0,
        points = 1,
    },
    [2] = {
        name = "screwdriverset",
        amount = 50,
        info = {},
        costs = {
            ["metalscrap"] = 30,
            ["plastic"] = 42,
        },
        type = "item",
        slot = 2,
        threshold = 0,
        points = 2,
    },
    [3] = {
        name = "electronickit",
        amount = 50,
        info = {},
        costs = {
            ["metalscrap"] = 30,
            ["plastic"] = 45,
            ["aluminum"] = 28,
        },
        type = "item",
        slot = 3,
        threshold = 0,
        points = 3,
    },
    [4] = {
        name = "radioscanner",
        amount = 50,
        info = {},
        costs = {
            ["electronickit"] = 2,
            ["plastic"] = 52,
            ["steel"] = 40,
        },
        type = "item",
        slot = 4,
        threshold = 0,
        points = 4,
    },
    [5] = {
        name = "gatecrack",
        amount = 50,
        info = {},
        costs = {
            ["metalscrap"] = 10,
            ["plastic"] = 50,
            ["aluminum"] = 30,
            ["iron"] = 17,
            ["electronickit"] = 2,
        },
        type = "item",
        slot = 5,
        threshold = 110,
        points = 5,
    },
    [6] = {
        name = "handcuffs",
        amount = 50,
        info = {},
        costs = {
            ["metalscrap"] = 36,
            ["steel"] = 24,
            ["aluminum"] = 28,
        },
        type = "item",
        slot = 6,
        threshold = 160,
        points = 6,
    },
    [7] = {
        name = "repairkit",
        amount = 50,
        info = {},
        costs = {
            ["metalscrap"] = 32,
            ["steel"] = 43,
            ["plastic"] = 61,
        },
        type = "item",
        slot = 7,
        threshold = 200,
        points = 7,
    },
    [8] = {
        name = "pistol_ammo",
        amount = 50,
        info = {},
        costs = {
            ["metalscrap"] = 50,
            ["steel"] = 37,
            ["copper"] = 26,
        },
        type = "item",
        slot = 8,
        threshold = 250,
        points = 8,
    },
    [9] = {
        name = "ironoxide",
        amount = 50,
        info = {},
        costs = {
            ["iron"] = 60,
            ["glass"] = 30,
        },
        type = "item",
        slot = 9,
        threshold = 300,
        points = 9,
    },
    [10] = {
        name = "aluminumoxide",
        amount = 50,
        info = {},
        costs = {
            ["aluminum"] = 60,
            ["glass"] = 30,
        },
        type = "item",
        slot = 10,
        threshold = 300,
        points = 10,
    },
    [11] = {
        name = "armor",
        amount = 50,
        info = {},
        costs = {
            ["iron"] = 33,
            ["steel"] = 44,
            ["plastic"] = 55,
            ["aluminum"] = 22,
        },
        type = "item",
        slot = 11,
        threshold = 350,
        points = 11,
    },
    [12] = {
        name = "drill",
        amount = 50,
        info = {},
        costs = {
            ["iron"] = 50,
            ["steel"] = 50,
            ["screwdriverset"] = 3,
            ["advancedlockpick"] = 2,
        },
        type = "item",
        slot = 12,
        threshold = 1750,
        points = 12,
    },
}

Config.AttachmentCraftingLocation = vector3(88.91, 3743.88, 40.77)

Config.AttachmentCrafting = {
    ["items"] = {
        [1] = {
            name = "pistol_extendedclip",
            amount = 50,
            info = {},
            costs = {
                ["metalscrap"] = 140,
                ["steel"] = 250,
                ["rubber"] = 60,
            },
            type = "item",
            slot = 1,
            threshold = 0,
            points = 1,
        },
        [2] = {
            name = "pistol_suppressor",
            amount = 50,
            info = {},
            costs = {
                ["metalscrap"] = 165,
                ["steel"] = 285,
                ["rubber"] = 75,
            },
            type = "item",
            slot = 2,
            threshold = 10,
            points = 2,
        },
        [3] = {
            name = "smg_extendedclip",
            amount = 50,
            info = {},
            costs = {
                ["metalscrap"] = 190,
                ["steel"] = 305,
                ["rubber"] = 85,
            },
            type = "item",
            slot = 3,
            threshold = 25,
            points = 3,
        },
        [4] = {
            name = "microsmg_extendedclip",
            amount = 50,
            info = {},
            costs = {
                ["metalscrap"] = 205,
                ["steel"] = 340,
                ["rubber"] = 110,
            },
            type = "item",
            slot = 4,
            threshold = 50,
            points = 4,
        },
        [5] = {
            name = "smg_drum",
            amount = 50,
            info = {},
            costs = {
                ["metalscrap"] = 230,
                ["steel"] = 365,
                ["rubber"] = 130,
            },
            type = "item",
            slot = 5,
            threshold = 75,
            points = 5,
        },
        [6] = {
            name = "smg_scope",
            amount = 50,
            info = {},
            costs = {
                ["metalscrap"] = 255,
                ["steel"] = 390,
                ["rubber"] = 145,
            },
            type = "item",
            slot = 6,
            threshold = 100,
            points = 6,
        },
        [7] = {
            name = "assaultrifle_extendedclip",
            amount = 50,
            info = {},
            costs = {
                ["metalscrap"] = 270,
                ["steel"] = 435,
                ["rubber"] = 155,
                ["smg_extendedclip"] = 1,
            },
            type = "item",
            slot = 7,
            threshold = 150,
            points = 7,
        },
        [8] = {
            name = "assaultrifle_drum",
            amount = 50,
            info = {},
            costs = {
                ["metalscrap"] = 300,
                ["steel"] = 469,
                ["rubber"] = 170,
                ["smg_extendedclip"] = 2,
            },
            type = "item",
            slot = 8,
            threshold = 200,
            points = 8,
        },
    }
}

BackEngineVehicles = {
    [`ninef`] = true,
    [`adder`] = true,
    [`vagner`] = true,
    [`t20`] = true,
    [`infernus`] = true,
    [`zentorno`] = true,
    [`reaper`] = true,
    [`comet2`] = true,
    [`comet3`] = true,
    [`jester`] = true,
    [`jester2`] = true,
    [`cheetah`] = true,
    [`cheetah2`] = true,
    [`prototipo`] = true,
    [`turismor`] = true,
    [`pfister811`] = true,
    [`ardent`] = true,
    [`nero`] = true,
    [`nero2`] = true,
    [`tempesta`] = true,
    [`vacca`] = true,
    [`bullet`] = true,
    [`osiris`] = true,
    [`entityxf`] = true,
    [`turismo2`] = true,
    [`fmj`] = true,
    [`re7b`] = true,
    [`tyrus`] = true,
    [`italigtb`] = true,
    [`penetrator`] = true,
    [`monroe`] = true,
    [`ninef2`] = true,
    [`stingergt`] = true,
    [`surfer`] = true,
    [`surfer2`] = true,
    [`gp1`] = true,
    [`autarch`] = true,
    [`tyrant`] = true
}

Config.MaximumAmmoValues = {
    ["pistol"] = 250,
    ["smg"] = 250,
    ["shotgun"] = 200,
    ["rifle"] = 250,
}

--[[═════════════════════════════════════════════════════════════════════
    الحماية والأداء
═════════════════════════════════════════════════════════════════════════]]

-- لما تستخدم أي آيتم (Use) الانفنتوري يتقفل
Config.CloseOnUse = true
Config.UseCooldown = 350          -- أقل وقت بين استخدامين (ملّي ثانية) — يمنع سبام الأكل/العلاج

-- مين يفتح أي ستاش (كانت ثغرة: أي واحد يفتح أي ستاش بالسيرفر بترقر)
Config.StashAccess = {
    -- ستاش اسمه فيه citizenid حق شخص ثاني (لوكر شخصي/فندق/...) = ممنوع
    ProtectCitizenIds = true,
    -- القواعد (الاسم يتحول لحروف صغيرة قبل المقارنة)
    Rules = {
        { pattern = 'evidence',    jobs = { police = true }, onduty = true },
        { pattern = '^policetrash', jobs = { police = true } },
        { pattern = '^ambulance',  jobs = { ambulance = true } },
        -- مثال عصابة: { pattern = '^ballas', gangs = { ballas = true } },
    },
}

-- متاجر قديمة ترسل الأسعار من الكلاينت (qb-drugs / pawnshop): نقبلها بس بسعر >= MinPrice وبدون أسلحة
-- (المتاجر الثانية: يا الفندنق، يا qb-toolsfactory، يا مسجلة بـ exports['qb-inventory']:RegisterShop(id, items))
Config.LegacyShops = { Dealer = true, Pawnshop = true }
Config.LegacyShopMinPrice = 1
Config.LegacyShopsAllowWeapons = false

-- تفتيش/سرقة لاعب: لازم يكون رافع يدينه (وإلا ميت/طايح/مكلبش، أو أنت شرطي على الدوام)
Config.RobHandsUpAnims = {
    { 'missminuteman_1ig_2', 'handsup_base' },
    { 'missminuteman_1ig_2', 'handsup_enter' },
    { 'random@mugging3', 'handsup_standing_base' },
    { 'random@arrests@busted', 'idle_a' },
    { 'mp_arresting', 'idle' },
}

Config.MaxSnowballs = 10          -- أقصى كرات ثلج بالشنطة

Config.Security = {
    KickOnAbuse = false,          -- true = يطرد اللي يكرر محاولات الغش
    MaxStrikes  = 5,              -- كم محاولة بالدقيقة قبل الطرد
}
