Config = {}

Config.Objects = {
    ["cone"] = {model = `prop_roadcone02a`, freeze = false},
    ["barrier"] = {model = `prop_barrier_work06a`, freeze = true},
    ["roadsign"] = {model = `prop_snow_sign_road_06g`, freeze = true},
    ["tent"] = {model = `prop_gazebo_03`, freeze = true},
    ["light"] = {model = `prop_worklight_03b`, freeze = true},
}

Config.MaxSpikes = 5

Config.HandCuffItem = 'handcuffs'
Config.LicenseRank = 2

Config.Time = 15                                    -- المدة لزايدة نقاط التصنيع
Config.TimeBasedRep = 0.25                          -- النقاط الي تنزاد كل مدة
Config.WeaponLicPrice = 2500 -- 2500$
Config.WeaponLicPirs  = 0.50 -- 50% + الباقي يعود الى خزنة الشرطة
Config.Webhooklink    = '' -- الويب هوك لأرسال معلومات الترخيص

Config.LicenseRank = 2
Config.Locations = {
    ["duty"] = {
        [1] = vector3(440.085, -974.924, 30.689),
        [2] = vector3(-449.811, 6012.909, 31.815),
    },
    ["vehicle"] = {
        [1] = vector4(451.57, -975.78, 25.7, 0.0),
        [2] = vector4(471.13, -1024.05, 28.17, 274.5),
        [3] = vector4(-455.39, 6002.02, 31.34, 87.93),
        -- [4] = vector4(384.97546386719,-1634.5473632813,29.292066574097, 322.55810546875), --davis
    },
    ["stash"] = {
        [1] = vector3(453.075, -980.124, 30.889),
    },
    ["impound"] = {
        [1] = vector4(436.68, -1007.42, 27.32, 180.0),
        [2] = vector4(-436.14, 5982.63, 31.34, 136.0),
    },
    ["helicopter"] = {
        [1] = vector4(438.65, -984.61, 40.76, 91.32),
        [2] = vector4(-475.43, 5988.353, 31.716, 31.34),
        [3] = vector4(1853.8, 3705.08, 33.97, 204.17),
        [4] = vector4(-475.23626708984,5988.505859375,31.336502075195, 314.91754150391),
    },
    ["armory"] = {
        [1] = vector3(462.23, -981.12, 30.68),
    },
    ["trash"] = {
        [1] = vector3(439.0907, -976.746, 30.776),
    },
    ["fingerprint"] = {
        [1] = vector3(460.9667, -989.180, 24.92),
    },
    ["evidence"] = {
        [1] = vector3(442.1722, -996.067, 30.689),
        [2] = vector3(451.7031, -973.232, 30.689),
        [3] = vector3(455.1456, -985.462, 30.689),
    },
    ["stations"] = {
        [1] = {label = "Police Station", coords = vector4(428.23, -984.28, 29.76, 3.5)},
        [2] = {label = "Prison", coords = vector4(1845.903, 2585.873, 45.672, 272.249)},
        --[3] = {label = "Sheriff Station Paleto", coords = vector4(-451.55, 6014.25, 31.716, 223.81), sheriff = true},
         [4] = {label = "Sandy Sheriff", coords = vector4(1833.4759521484,3676.4182128906,34.189170837402, 58.605846405029), sheriff = true},
        -- [5] = {label = "Davis Police Station", coords = vector4(373.42175292969,-1598.6900634766,30.051416397095, 140.79710388184)},
    },
}

Config.ArmoryWhitelist = {}

Config.PoliceHelicopter = ""
Config.SheriffHelicopter = ""

Config.SecurityCameras = {
    hideradar = false,
    cameras = {
        [1] = {label = "Pacific Bank CAM#1", coords = vector3(257.45, 210.07, 109.08), r = {x = -25.0, y = 0.0, z = 28.05}, canRotate = false, isOnline = true},
        [2] = {label = "Pacific Bank CAM#2", coords = vector3(232.86, 221.46, 107.83), r = {x = -25.0, y = 0.0, z = -140.91}, canRotate = false, isOnline = true},
        [3] = {label = "Pacific Bank CAM#3", coords = vector3(252.27, 225.52, 103.99), r = {x = -35.0, y = 0.0, z = -74.87}, canRotate = false, isOnline = true},
        [4] = {label = "Limited Ltd Grove St. CAM#1", coords = vector3(-53.1433, -1746.714, 31.546), r = {x = -35.0, y = 0.0, z = -168.9182}, canRotate = false, isOnline = true},
        [5] = {label = "Rob's Liqour Prosperity St. CAM#1", coords = vector3(-1482.9, -380.463, 42.363), r = {x = -35.0, y = 0.0, z = 79.53281}, canRotate = false, isOnline = true},
        [6] = {label = "Rob's Liqour San Andreas Ave. CAM#1", coords = vector3(-1224.874, -911.094, 14.401), r = {x = -35.0, y = 0.0, z = -6.778894}, canRotate = false, isOnline = true},
        [7] = {label = "Limited Ltd Ginger St. CAM#1", coords = vector3(-718.153, -909.211, 21.49), r = {x = -35.0, y = 0.0, z = -137.1431}, canRotate = false, isOnline = true},
        [8] = {label = "24/7 Supermarkt Innocence Blvd. CAM#1", coords = vector3(23.885, -1342.441, 31.672), r = {x = -35.0, y = 0.0, z = -142.9191}, canRotate = false, isOnline = true},
        [9] = {label = "Rob's Liqour El Rancho Blvd. CAM#1", coords = vector3(1133.024, -978.712, 48.515), r = {x = -35.0, y = 0.0, z = -137.302}, canRotate = false, isOnline = true},
        [10] = {label = "Limited Ltd West Mirror Drive CAM#1", coords = vector3(1151.93, -320.389, 71.33), r = {x = -35.0, y = 0.0, z = -119.4468}, canRotate = false, isOnline = true},
        [11] = {label = "24/7 Supermarkt Clinton Ave CAM#1", coords = vector3(383.102, 328.515, 105.541), r = {x = -35.0, y = 0.0, z = 118.585}, canRotate = false, isOnline = true},
        [12] = {label = "Limited Ltd Banham Canyon Dr CAM#1", coords = vector3(-1832.057, 789.389, 140.436), r = {x = -35.0, y = 0.0, z = -91.481}, canRotate = false, isOnline = true},
        [13] = {label = "Rob's Liqour Great Ocean Hwy CAM#1", coords = vector3(-2966.15, 387.067, 17.393), r = {x = -35.0, y = 0.0, z = 32.92229}, canRotate = false, isOnline = true},
        [14] = {label = "24/7 Supermarkt Ineseno Road CAM#1", coords = vector3(-3046.149, 592.191, 9.808), r = {x = -35.0, y = 0.0, z = -116.673}, canRotate = false, isOnline = true},
        [15] = {label = "24/7 Supermarkt Barbareno Rd. CAM#1", coords = vector3(-3246.089, 1010.008, 14.705), r = {x = -35.0, y = 0.0, z = -135.2151}, canRotate = false, isOnline = true},
        [16] = {label = "24/7 Supermarkt Route 68 CAM#1", coords = vector3(539.773, 2665.504, 43.556), r = {x = -35.0, y = 0.0, z = -42.947}, canRotate = false, isOnline = true},
        [17] = {label = "Rob's Liqour Route 68 CAM#1", coords = vector3(1169.855, 2711.493, 40.432), r = {x = -35.0, y = 0.0, z = 127.17}, canRotate = false, isOnline = true},
        [18] = {label = "24/7 Supermarkt Senora Fwy CAM#1", coords = vector3(2673.579, 3281.265, 57.541), r = {x = -35.0, y = 0.0, z = -80.242}, canRotate = false, isOnline = true},
        [19] = {label = "24/7 Supermarkt Alhambra Dr. CAM#1", coords = vector3(1966.24, 3748.80, 34.143), r = {x = -35.0, y = 0.0, z = 163.065}, canRotate = false, isOnline = true},
        [20] = {label = "24/7 Supermarkt Senora Fwy CAM#2", coords = vector3(1729.522, 6419.87, 37.262), r = {x = -35.0, y = 0.0, z = -160.089}, canRotate = false, isOnline = true},
        [21] = {label = "Fleeca Bank Hawick Ave CAM#1", coords = vector3(309.341, -281.439, 55.88), r = {x = -35.0, y = 0.0, z = -146.1595}, canRotate = false, isOnline = true},
        [22] = {label = "Fleeca Bank Legion Square CAM#1", coords = vector3(144.871, -1043.044, 31.017), r = {x = -35.0, y = 0.0, z = -143.9796}, canRotate = false, isOnline = true},
        [23] = {label = "Fleeca Bank Hawick Ave CAM#2", coords = vector3(-355.7643, -52.506, 50.746), r = {x = -35.0, y = 0.0, z = -143.8711}, canRotate = false, isOnline = true},
        [24] = {label = "Fleeca Bank Del Perro Blvd CAM#1", coords = vector3(-1214.226, -335.86, 39.515), r = {x = -35.0, y = 0.0, z = -97.862}, canRotate = false, isOnline = true},
        [25] = {label = "Fleeca Bank Great Ocean Hwy CAM#1", coords = vector3(-2958.885, 478.983, 17.406), r = {x = -35.0, y = 0.0, z = -34.69595}, canRotate = false, isOnline = true},
        [26] = {label = "Paleto Bank CAM#1", coords = vector3(-102.939, 6467.668, 33.424), r = {x = -35.0, y = 0.0, z = 24.66}, canRotate = false, isOnline = true},
        [27] = {label = "Del Vecchio Liquor Paleto Bay", coords = vector3(-163.75, 6323.45, 33.424), r = {x = -35.0, y = 0.0, z = 260.00}, canRotate = false, isOnline = true},
        [28] = {label = "Don's Country Store Paleto Bay CAM#1", coords = vector3(166.42, 6634.4, 33.69), r = {x = -35.0, y = 0.0, z = 32.00}, canRotate = false, isOnline = true},
        [29] = {label = "Don's Country Store Paleto Bay CAM#2", coords = vector3(163.74, 6644.34, 33.69), r = {x = -35.0, y = 0.0, z = 168.00}, canRotate = false, isOnline = true},
        [30] = {label = "Don's Country Store Paleto Bay CAM#3", coords = vector3(169.94, 6641.99, 33.69), r = {x = -35.0, y = 0.0, z = 5.0}, canRotate = false, isOnline = true},
        [31] = {label = "Vangelico Jewelery CAM#1", coords = vector3(-627.54, -239.74, 40.33), r = {x = -35.0, y = 0.0, z = 5.78}, canRotate = true, isOnline = true},
        [32] = {label = "Vangelico Jewelery CAM#2", coords = vector3(-627.51, -229.51, 40.24), r = {x = -35.0, y = 0.0, z = -95.78}, canRotate = true, isOnline = true},
        [33] = {label = "Vangelico Jewelery CAM#3", coords = vector3(-620.3, -224.31, 40.23), r = {x = -35.0, y = 0.0, z = 165.78}, canRotate = true, isOnline = true},
        [34] = {label = "Vangelico Jewelery CAM#4", coords = vector3(-622.57, -236.3, 40.31), r = {x = -35.0, y = 0.0, z = 5.78}, canRotate = true, isOnline = true},
        [35] = {label = "Money Factory CAM#1", coords = vector3(1006.7401123047,-2538.9362792969,30.734375), r = {x = -35.0, y = 0.0, z = -55.08}, canRotate = true, isOnline = true},
        [36] = {label = "Money Factory CAM#2", coords = vector3(1030.0301513672,-2535.8483886719,30.734375), r = {x = -35.0, y = 0.0, z = 125.08}, canRotate = true, isOnline = true},
    },
}


Config.WhitelistedVehicles = {}

Config.AmmoLabels = {
    ["AMMO_PISTOL"] = "9x19mm parabellum bullet",
    ["AMMO_SMG"] = "9x19mm parabellum bullet",
    ["AMMO_RIFLE"] = "7.62x39mm bullet",
    ["AMMO_MG"] = "7.92x57mm mauser bullet",
    ["AMMO_SHOTGUN"] = "12-gauge bullet",
    ["AMMO_SNIPER"] = "Large caliber bullet",
}

Config.Radars = {
	vector4(-623.44421386719, -823.08361816406, 25.25704574585, 145.0),
	vector4(-652.44421386719, -854.08361816406, 24.55704574585, 325.0),
	vector4(1623.0114746094, 1068.9924316406, 80.903594970703, 84.0),
	vector4(-2604.8994140625, 2996.3391113281, 27.528566360474, 175.0),
	vector4(2136.65234375, -591.81469726563, 94.272926330566, 318.0),
	vector4(2117.5764160156, -558.51013183594, 95.683128356934, 158.0),
	vector4(406.89505004883, -969.06286621094, 29.436267852783, 33.0),
	vector4(657.315, -218.819, 44.06, 320.0),
	vector4(2118.287, 6040.027, 50.928, 172.0),
	vector4(-106.304, -1127.5530, 30.778, 230.0),
	vector4(-823.3688, -1146.980, 8.0, 300.0),
}

Config.CarItems = {
    [1] = {
        name = "armor",
        amount = 2,
        info = {},
        type = "item",
        slot = 1,
    },
    [2] = {
        name = "empty_evidence_bag",
        amount = 10,
        info = {},
        type = "item",
        slot = 2,
    },
    [3] = {
        name = "police_stormram",
        amount = 1,
        info = {},
        type = "item",
        slot = 3,
    },
}

Config.Items = {
    label = "Police Armory",
    slots = 30,
    items = {
        [1] = {
            name = "weapon_combatpistol",
            price = 0,
            amount = 1,
            info = {
                serie = "",
                attachments = {
                    {component = "COMPONENT_AT_PI_FLSH", label = "Flashlight"},
                }
            },
            type = "weapon",
            slot = 1,
            authorizedJobGrades = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12}
        },
        [2] = {
            name = "weapon_stungun",
            price = 0,
            amount = 1,
            info = {
                serie = "",
            },
            type = "weapon",
            slot = 2,
            authorizedJobGrades = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12}
        },
        [3] = {
            name = "carbinerifle_extendedclip",
            price = 0,
            amount = 1,
            info = {
                serie = "",
                attachments = {
                    {component = "COMPONENT_AT_AR_FLSH", label = "Flashlight"},
                }
            },
            type = "weapon",
            slot = 3,
            authorizedJobGrades = {8, 9, 10, 11, 12}
        },
        [4] = {
            name = "weapon_carbinerifle_mk2",
            price = 0,
            amount = 1,
            info = {
                serie = "",
                attachments = {
                    {component = "COMPONENT_AT_AR_FLSH", label = "1x Scope"},
                    {component = "COMPONENT_AT_CR_BARREL_02", label = "Barrel"},
                    {component = "COMPONENT_AT_SCOPE_MEDIUM", label = "Flashlight"},
                }
            },
            type = "weapon",
            slot = 4,
            authorizedJobGrades = {7, 8, 9, 10, 11, 12}
        },
         [5] = {
             name = "nightvision",
             price = 0,
             amount = 1,
             info = {},
             type = "item",
             slot = 4,
             authorizedJobGrades = {5, 6, 7, 8, 9, 10, 11, 12}
         },
        [6] = {
            name = "weapon_nightstick",
            price = 0,
            amount = 1,
            info = {},
            type = "weapon",
            slot = 3,
            authorizedJobGrades = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12}
        },
        [7] = {
            name = "pistol_ammo",
            price = 0,
            amount = 50,
            info = {},
            type = "item",
            slot = 4,
            authorizedJobGrades = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12}
        },
        [8] = {
            name = "smg_ammo",
            price = 0,
            amount = 50,
            info = {},
            type = "item",
            slot = 5,
            authorizedJobGrades = {5, 6, 7, 8, 9, 10, 11, 12}
        },
        [9] = {
            name = "rifle_suppressor",
            price = 0,
            amount = 50,
            info = {},
            type = "item",
            slot = 6,
            authorizedJobGrades = {5, 6, 7, 8, 9, 10, 11, 12}
        },
        [10] = {
            name = "rifle_ammo",
            price = 0,
            amount = 50,
            info = {},
            type = "item",
            slot = 7,
            authorizedJobGrades = {5, 6, 7, 8, 9, 10, 11, 12}
        },
        [11] = {
            name = "handcuffs",
            price = 0,
            amount = 1,
            info = {},
            type = "item",
            slot = 8,
            authorizedJobGrades = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12}
        },
        [12] = {
            name = "weapon_flashlight",
            price = 0,
            amount = 1,
            info = {},
            type = "weapon",
            slot = 9,
            authorizedJobGrades = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12}
        },
        --[10] = {
           -- name = "empty_evidence_bag",
           -- price = 0,
            --amount = 50,
            --info = {},
           -- type = "item",
           -- slot = 10,
            --authorizedJobGrades = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12}
        --},
        [13] = {
            name = "police_stormram",
            price = 0,
            amount = 50,
            info = {},
            type = "item",
            slot = 11,
            authorizedJobGrades = {5, 6, 7, 8, 9, 10, 11, 12}
        },
        [14] = {
            name = "armor",
            price = 0,
            amount = 5,
            info = {},
            type = "item",
            slot = 12,
            authorizedJobGrades = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12}
        },
        [15] = {
            name = "radio",
            price = 0,
            amount = 1,
            info = {},
            type = "item",
            slot = 13,
            authorizedJobGrades = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12}
        },
        [16] = {
            name = "diving_gear",
            price = 0,
            amount = 200,
            info = {},
            type = "item",
            slot = 14,
            authorizedJobGrades = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12}
        },
        [17] = {
            name = "weapon_fireextinguisher",
            price = 0,
            amount = 200,
            info = {},
            type = "item",
            slot = 15,
            authorizedJobGrades = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12}
        },
        [18] = {
            name = "weapon_pistol50",
            price = 0,
            amount = 1,
            info = {},
            type = "weapon",
            slot = 16,
            authorizedJobGrades = {7, 8, 9, 10, 11, 12}
        },
        [19] = {
            name = "dslrcamera",
            price = 0,
            amount = 200,
            info = {},
            type = "item",
            slot = 17,
            authorizedJobGrades = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12}
        },
        [20] = {
            name = "weapon_heavypistol",
            price = 0,
            amount = 1,
            info = {},
            type = "weapon",
            slot = 18,
            authorizedJobGrades = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12}
        },
        [21] = {
            name = "Tracker",
            price = 0,
            amount = 1,
            info = {},
            type = "item",
            slot = 20,
            authorizedJobGrades = {10, 11, 12}
        },
        [22] = {
            name = "bodycam",
            price = 0,
            amount = 1,
            info = {},
            type = "item",
            slot = 21,
            authorizedJobGrades = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12}
        },
        [23] = {
            name = "dashcam",
            price = 0,
            amount = 1,
            info = {},
            type = "item",
            slot = 22,
            authorizedJobGrades = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12}
        },
        [24] = {
            name = "badge",
            price = 0,
            amount = 1,
            info = {},
            type = "item",
            slot = 23,
            authorizedJobGrades = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12}
        },
        [25] = {
            name = "evidencebox",
            price = 0,
            amount = 1,
            info = {},
            type = "item",
            slot = 24,
            authorizedJobGrades = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12}
        },
        [26] = {
            name = "weapon_emplauncher",
            price = 0,
            amount = 1,
            info = {},
            type = "weapon",
            slot = 18,
            authorizedJobGrades = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12}
        },
        [27] = {
            name = "emp_ammo",
            price = 0,
            amount = 1,
            info = {},
            type = "item",
            slot = 24,
            authorizedJobGrades = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12}
        },
        [28] = {
            name = "weapon_beanbagshotgun",
            price = 5000,
            amount = 1,
            info = {},
            type = "weapon",
            slot = 29,
            authorizedJobGrades = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13}
        },
        [29] = {
            name = "rubberslugs_ammo",
            price = 200,
            amount = 10,
            info = {},
            type = "item",
            slot = 30,
            authorizedJobGrades = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13}
        },
        [30] = {
            name = "spikestrip",
            price = 0,
            amount = 1,
            info = {},
            type = "item",
            slot = 24,
            authorizedJobGrades = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12}
        },
        [31] = {
             name = "weapon_carbinerifle",
             price = 0,
            amount = 1,
            info = {
                serie = "",
                 attachments = {
                    {component = "COMPONENT_AT_AR_FLSH", label = "Flashlight"},
                   {component = "COMPONENT_AT_SCOPE_MEDIUM", label = "3x Scope"},
              }
           },
           type = "weapon",
             slot = 5,
            authorizedJobGrades = {8, 9, 10, 11, 12}
        },
        [32] = {
            name = "weaponrepairkit",
            price = 0,
            amount = 1,
            info = {},
            type = "item",
            slot = 18,
            authorizedJobGrades = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12}
        },
        [33] = {
            name = "weapon_assaultrifle",
            price = 0,
            amount = 1,
            info = {},
            type = "weapon",
            slot = 18,
            authorizedJobGrades = { 9,10, 11, 12}
        },
        [34] = {
            name = "cctv",
            price = 20,
            amount = 1,
            info = {},
            type = "item",
            slot = 24,
            authorizedJobGrades = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12}
        },
        [35] = {
            name = "360cctv",
            price = 30,
            amount = 1,
            info = {},
            type = "item",
            slot = 24,
            authorizedJobGrades = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12}
        },
        [36] = {
            name = "camviewer",
            price = 20,
            amount = 1,
            info = {},
            type = "item",
            slot = 24,
            authorizedJobGrades = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12}
        },
        [37] = {
            name = "megaphone",
            price = 30,
            amount = 1,
            info = {},
            type = "item",
            slot = 24,
            authorizedJobGrades = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12}
        },
        [38] = {
            name = "policelaptop",
            price = 40,
            amount = 1,
            info = {},
            type = "item",
            slot = 24,
            authorizedJobGrades = { 9,10, 11, 12}
        },
        [39] = {
            name = "shield",
            price = 110,
            amount = 1,
            info = {},
            type = "item",
            slot = 25,
            authorizedJobGrades = {8, 9, 10, 11, 12}
        },
        [40] = {
            name = "a4sheets",
            price = 5,
            amount = 1,
            info = {},
            type = "item",
            slot = 26,
            authorizedJobGrades = {10, 11, 12}
        },
        [41] = {
            name = "empty_evidence_bag",
            amount = 10,
            price = 10,
            info = {},
            type = "item",
            slot = 27,
            authorizedJobGrades = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12}
        },
        [42] = {
            name = "managmentlaptop",
            amount = 1,
            price = 90,
            info = {},
            type = "item",
            slot = 28,
            authorizedJobGrades = {9, 10, 11, 12}
        },
    }
}

Config.AuthorizedVehicles = {
	-- Grade 0
	[0] = {
        ["b211vic"] = "CROWN VICTORIA",
	},
	-- Grade 1
	[1] = {
        ["b211vic"] = "CROWN VICTORIA",
        ["mtchr1"] = "Police Char",
        ["mttur"] = "Police Tur",
	},
	-- Grade 2
	[2] = {
        ["b211vic"] = "CROWN VICTORIA",
        ["mtchr1"] = "Police Char",
        ["mttur"] = "Police Tur",
	},
	-- Grade 3
	[3] = {
        ["b211vic"] = "CROWN VICTORIA",
        ["mtchr1"] = "Police Char",
        ["mttur"] = "Police Tur",
	},
	-- Grade 4
	[4] = {
        ["b211vic"] = "CROWN VICTORIA",
        ["mtchr1"] = "Police Char",
        ["mttur"] = "Police Tur",
        ["23sirhd"] = "Police Sierra",
	},
	[5] = {
        ["b211vic"] = "CROWN VICTORIA",
        ["mtchr1"] = "Police Char",
        ["mttur"] = "Police Tur",
        ["23sirhd"] = "Police Sierra",
	},
	[6] = {
        ["b211vic"] = "CROWN VICTORIA",
        ["mtchr1"] = "Police Char",
        ["mttur"] = "Police Tur",
        ["23sirhd"] = "Police Sierra",
	},
	[7] = {
        ["b211vic"] = "CROWN VICTORIA",
        ["mtchr1"] = "Police Char",
        ["mttur"] = "Police Tur",
        ["23sirhd"] = "Police Sierra",
        ["mtdur"] = "Police Dur",
	},
	[8] = {
        ["b211vic"] = "CROWN VICTORIA",
        ["mtchr1"] = "Police Char",
        ["mttur"] = "Police Tur",
        ["23sirhd"] = "Police Sierra",
        ["mtdur"] = "Police Dur",
        ["npolchal"] = "Police Chal",
        ["bcat"] = "Police Bcat",
	},
	[9] = {
        ["b211vic"] = "CROWN VICTORIA",
        ["mtchr1"] = "Police Char",
        ["mttur"] = "Police Tur",
        ["23sirhd"] = "Police Sierra",
        ["mtdur"] = "Police Dur",
        ["b216explorer"] = "Police Explorer",
        ["npolvette"] = "Police Vette",
        ["npolchal"] = "Police Chal",
        ["bcat"] = "Police Bcat",
	},
	[10] = {
        ["dr911"] = "Police Dr911",
		["mtdur"] = "Police Dur",
		["mttmustang"] = "Police Mustang",
		--["polharley"] = 'polharley',
		-- ["polraptor"] = 'FORD RAPTOR',
		["mttur"] = "Police Tur",
		["23sirhd"] = "Police Sierra",
        ["b216explorer"] = "Police Explorer",
        ["b211vic"] = "Police Vic",
        ["mtchr1"] = "Police Char",
        ["npolvette"] = "Police Vette",
        ["npolchal"] = "Police Chal",
        ["bcat"] = "Police Bcat",
	},
}

Config.VehicleSettings = {
    ['lspd'] = {
        ["pd_dirtbike"] = { --- Model name
            ["extras"] = {
                ["1"] = true, -- on/off
                ["2"] = true,
                ["3"] = true,
                ["4"] = true,
                ["5"] = true,
                ["6"] = true,
                ["7"] = true,
                ["8"] = true,
                ["9"] = true,
                ["10"] = true,
                ["11"] = true,
                ["12"] = true,
                ["13"] = true,
            },
            ['liv'] = 0,
        },
        ["Kawasaki"] = { --- Model name
            ["extras"] = {
                ["1"] = false, -- on/off
                ["2"] = false,
                ["3"] = false,
                ["4"] = false,
                ["5"] = false,
                ["6"] = false,
                ["7"] = false,
                ["8"] = false,
                ["9"] = false,
                ["10"] = false,
                ["11"] = false,
                ["12"] = false,
                ["13"] = false,
            },
            ['liv'] = 1,
        },
        ["polmm"] = { --- Model name
            ["extras"] = {
                ["1"] = false, -- on/off
                ["2"] = false,
                ["3"] = false,
                ["4"] = false,
                ["5"] = false,
                ["6"] = false,
                ["7"] = false,
                ["8"] = false,
                ["9"] = false,
                ["10"] = false,
                ["11"] = false,
                ["12"] = false,
                ["13"] = false,
            },
            ['liv'] = 0,
        },
        ["polvic"] = { --- Model name
            ["extras"] = {
                ["1"] = true, -- on/off
                ["2"] = true,
                ["3"] = true,
                ["4"] = true,
                ["5"] = true,
                ["6"] = true,
                ["7"] = true,
                ["8"] = true,
                ["9"] = true,
                ["10"] = true,
                ["11"] = true,
                ["12"] = true,
                ["13"] = true,
            },
            ['liv'] = 0,
        },
        ["npolexp"] = { --- Model name
            ["extras"] = {
                ["1"] = true, -- on/off
                ["2"] = true,
                ["3"] = true,
                ["4"] = true,
                ["5"] = true,
                ["6"] = true,
                ["7"] = true,
                ["8"] = true,
                ["9"] = true,
                ["10"] = true,
                ["11"] = true,
                ["12"] = true,
                ["13"] = true,
            },
            ['liv'] = 0,
            ['color1'] = 0,
            ['color2'] = 5,
        },
        ["npolstang"] = { --- Model name
            ["extras"] = {
                ["1"] = true, -- on/off
                ["2"] = true,
                ["3"] = true,
                ["4"] = true,
                ["5"] = true,
                ["6"] = true,
                ["7"] = true,
                ["8"] = true,
                ["9"] = true,
                ["10"] = true,
                ["11"] = true,
                ["12"] = true,
                ["13"] = true,
            },
            ['liv'] = 2,
            -- ['color1'] = 0,
            -- ['color2'] = 5,
            ['turbo'] = 1,
            ['en'] = 5,
        },
        ["npolchar"] = { --- Model name
            ["extras"] = {
                ["1"] = true, -- on/off
                ["2"] = true,
                ["3"] = true,
                ["4"] = true,
                ["5"] = true,
                ["6"] = true,
                ["7"] = true,
                ["8"] = true,
                ["9"] = true,
                ["10"] = true,
                ["11"] = true,
                ["12"] = true,
                ["13"] = true,
            },
            ['liv'] = 0,
            ['color1'] = 67,
            ['color2'] = 0,
            ['turbo'] = 1,
            ['en'] = 5,
        },
        ["polharley"] = { --- Model name
            ["extras"] = {
                ["1"] = true, -- on/off
                ["2"] = true,
                ["3"] = true,
                ["4"] = true,
                ["5"] = true,
                ["6"] = true,
                ["7"] = true,
                ["8"] = true,
                ["9"] = true,
                ["10"] = true,
                ["11"] = true,
                ["12"] = true,
                ["13"] = true,
            },
            ['liv'] = 0,
            ['color1'] = 0,
            ['color2'] = 0,
            ['turbo'] = 1,
            ['en'] = 5,
        },
        ["polraptor"] = { --- Model name
            ["extras"] = {
                ["1"] = true, -- on/off
                ["2"] = true,
                ["3"] = true,
                ["4"] = true,
                ["5"] = true,
                ["6"] = true,
                ["7"] = true,
                ["8"] = true,
                ["9"] = true,
                ["10"] = true,
                ["11"] = true,
                ["12"] = true,
                ["13"] = true,
            },
            ['liv'] = 0,
            ['color1'] = 0,
            ['color2'] = 0,
            ['turbo'] = 1,
            ['en'] = 5,
        },
        ["poltah"] = { --- Model name
            ["extras"] = {
                ["1"] = true, -- on/off
                ["2"] = true,
                ["3"] = true,
                ["4"] = true,
                ["5"] = true,
                ["6"] = true,
                ["7"] = true,
                ["8"] = true,
                ["9"] = true,
                ["10"] = true,
                ["11"] = true,
                ["12"] = true,
                ["13"] = true,
            },
            ['liv'] = 0,
            ['color1'] = 0,
            ['color2'] = 0,
            ['turbo'] = 1,
            ['en'] = 5,
        },
        ["poltaurus"] = { --- Model name
            ["extras"] = {
                ["1"] = true, -- on/off
                ["2"] = true,
                ["3"] = true,
                ["4"] = true,
                ["5"] = true,
                ["6"] = true,
                ["7"] = true,
                ["8"] = true,
                ["9"] = true,
                ["10"] = true,
                ["11"] = true,
                ["12"] = true,
                ["13"] = true,
            },
            ['liv'] = 0,
            ['color1'] = 0,
            ['color2'] = 0,
            ['turbo'] = 1,
            ['en'] = 5,
        },
    },
    -- ['sheriff'] = {
    --         ["pd_dirtbike"] = { --- Model name
    --         ["extras"] = {
    --             ["1"] = true, -- on/off
    --             ["2"] = true,
    --             ["3"] = true,
    --             ["4"] = true,
    --             ["5"] = true,
    --             ["6"] = true,
    --             ["7"] = true,
    --             ["8"] = true,
    --             ["9"] = true,
    --             ["10"] = true,
    --             ["11"] = true,
    --             ["12"] = true,
    --             ["13"] = true,
    --         },
    --         ['liv'] = 0,
    --     },
    --     ["Kawasaki"] = { --- Model name
    --         ["extras"] = {
    --             ["1"] = false, -- on/off
    --             ["2"] = false,
    --             ["3"] = false,
    --             ["4"] = false,
    --             ["5"] = false,
    --             ["6"] = false,
    --             ["7"] = false,
    --             ["8"] = false,
    --             ["9"] = false,
    --             ["10"] = false,
    --             ["11"] = false,
    --             ["12"] = false,
    --             ["13"] = false,
    --         },
    --         ['liv'] = 1,
    --     },
    --     ["polmm"] = { --- Model name
    --         ["extras"] = {
    --             ["1"] = true, -- on/off
    --             ["2"] = true,
    --             ["3"] = true,
    --             ["4"] = true,
    --             ["5"] = true,
    --             ["6"] = true,
    --             ["7"] = true,
    --             ["8"] = true,
    --             ["9"] = true,
    --             ["10"] = true,
    --             ["11"] = true,
    --             ["12"] = true,
    --             ["13"] = true,
    --         },
    --         ['liv'] = 1,
    --     },
    --     ["polvic"] = { --- Model name
    --         ["extras"] = {
    --             ["1"] = true, -- on/off
    --             ["2"] = true,
    --             ["3"] = true,
    --             ["4"] = true,
    --             ["5"] = true,
    --             ["6"] = true,
    --             ["7"] = true,
    --             ["8"] = true,
    --             ["9"] = true,
    --             ["10"] = true,
    --             ["11"] = true,
    --             ["12"] = true,
    --             ["13"] = true,
    --         },
    --         ['liv'] = 1,
    --     },
    --     ["npolexp"] = { --- Model name
    --         ["extras"] = {
    --             ["1"] = true, -- on/off
    --             ["2"] = true,
    --             ["3"] = true,
    --             ["4"] = true,
    --             ["5"] = true,
    --             ["6"] = true,
    --             ["7"] = true,
    --             ["8"] = true,
    --             ["9"] = true,
    --             ["10"] = true,
    --             ["11"] = true,
    --             ["12"] = true,
    --             ["13"] = true,
    --         },
    --         ['liv'] = 1,
    --         ['color1'] = 0,
    --         ['color2'] = 5,
    --     },
    --     ["npolstang"] = { --- Model name
    --         ["extras"] = {
    --             ["1"] = true, -- on/off
    --             ["2"] = true,
    --             ["3"] = true,
    --             ["4"] = true,
    --             ["5"] = true,
    --             ["6"] = true,
    --             ["7"] = true,
    --             ["8"] = true,
    --             ["9"] = true,
    --             ["10"] = true,
    --             ["11"] = true,
    --             ["12"] = true,
    --             ["13"] = true,
    --         },
    --         ['liv'] = 1,
    --         -- ['color1'] = 0,
    --         -- ['color2'] = 5,
    --         ['turbo'] = 1,
    --         ['en'] = 5,
    --     },
    --     ["npolchar"] = { --- Model name
    --         ["extras"] = {
    --             ["1"] = true, -- on/off
    --             ["2"] = true,
    --             ["3"] = true,
    --             ["4"] = true,
    --             ["5"] = true,
    --             ["6"] = true,
    --             ["7"] = true,
    --             ["8"] = true,
    --             ["9"] = true,
    --             ["10"] = true,
    --             ["11"] = true,
    --             ["12"] = true,
    --             ["13"] = true,
    --         },
    --         ['liv'] = 4,
    --         ['color1'] = 0,
    --         ['color2'] = 0,
    --         ['turbo'] = 1,
    --         ['en'] = 5,
    --     },
    --     ["polharley"] = { --- Model name
    --         ["extras"] = {
    --             ["1"] = true, -- on/off
    --             ["2"] = true,
    --             ["3"] = true,
    --             ["4"] = true,
    --             ["5"] = true,
    --             ["6"] = true,
    --             ["7"] = true,
    --             ["8"] = true,
    --             ["9"] = true,
    --             ["10"] = true,
    --             ["11"] = true,
    --             ["12"] = true,
    --             ["13"] = true,
    --         },
    --         ['liv'] = 0,
    --         ['color1'] = 0,
    --         ['color2'] = 0,
    --         ['turbo'] = 1,
    --         ['en'] = 5,
    --     },
    --     ["polraptor"] = { --- Model name
    --         ["extras"] = {
    --             ["1"] = true, -- on/off
    --             ["2"] = true,
    --             ["3"] = true,
    --             ["4"] = true,
    --             ["5"] = true,
    --             ["6"] = true,
    --             ["7"] = true,
    --             ["8"] = true,
    --             ["9"] = true,
    --             ["10"] = true,
    --             ["11"] = true,
    --             ["12"] = true,
    --             ["13"] = true,
    --         },
    --         ['liv'] = 1,
    --         ['color1'] = 0,
    --         ['color2'] = 0,
    --         ['turbo'] = 1,
    --         ['en'] = 5,
    --     },
    --     ["poltah"] = { --- Model name
    --         ["extras"] = {
    --             ["1"] = true, -- on/off
    --             ["2"] = true,
    --             ["3"] = true,
    --             ["4"] = true,
    --             ["5"] = true,
    --             ["6"] = true,
    --             ["7"] = true,
    --             ["8"] = true,
    --             ["9"] = true,
    --             ["10"] = true,
    --             ["11"] = true,
    --             ["12"] = true,
    --             ["13"] = true,
    --         },
    --         ['liv'] = 1,
    --         ['color1'] = 0,
    --         ['color2'] = 0,
    --         ['turbo'] = 1,
    --         ['en'] = 5,
    --     },
    --     ["poltaurus"] = { --- Model name
    --         ["extras"] = {
    --             ["1"] = true, -- on/off
    --             ["2"] = true,
    --             ["3"] = true,
    --             ["4"] = true,
    --             ["5"] = true,
    --             ["6"] = true,
    --             ["7"] = true,
    --             ["8"] = true,
    --             ["9"] = true,
    --             ["10"] = true,
    --             ["11"] = true,
    --             ["12"] = true,
    --             ["13"] = true,
    --         },
    --         ['liv'] = 1,
    --         ['color1'] = 0,
    --         ['color2'] = 0,
    --         ['turbo'] = 1,
    --         ['en'] = 5,
    --     },
    -- },
}

Config.Target = {
    ["policeArmory"] = {
        coords = vector3(1553.37, 1491.13, 30.25),
        name = "policeArmory",
        heading = 0,
        info1 = 1.0,
        info2 = 1,
        minZ=27.89,
        maxZ=31.89,
        debugPoly = false,
        distance = 3.0,
        type = "client", 
        event = "qb-police:policeArmory",  
        icon = 'fas fa-box', 
        label = 'Open Armory', 
        job = "police",
        params = {},
        canInteract = function(entity)
            return true
        end,
    },
    ["policePersonalStash"] = {
        coords = vector3(452.04, -978.04, 30.10),
        name = "policePersonalStash",
        heading = 0,
        info1 = 1,
        info2 = 1,
        minZ=28.09,
        maxZ=32.09,
        debugPoly = false,
        distance = 2.0,
        type = "client", 
        event = "qb-police:policePersonalStash",  
        icon = 'fas fa-box-full', 
        label = 'Personal Stash', 
        job = "police",
        params = {},
        canInteract = function(entity)
            return true
        end,
    },
    ["policeFinger"] = {
        coords = vector3(466.56, -992.09, 23.15),
        name = "policeFinger",
        heading = 0,
        info1 = 1,
        info2 = 1,
        minZ=22.47,
        maxZ=26.47,
        debugPoly = false,
        distance = 2.0,
        type = "client", 
        event = "qb-police:policeFinger",  
        icon = 'fas fa-fingerprint', 
        label = 'FingerPrint', 
        job = "police",
        params = {},
        canInteract = function(entity)
            return true
        end,
    },
    ["policeEvidence"] = {
        coords = vector3(468.19, -994.59, 23.70), 
        name = "policeEvidence",
        heading = 0,
        info1 = 2.0,
        info2 = 0.4,
        minZ=27.69,
        maxZ=31.69,
        debugPoly = false,
        distance = 2.0,
        type = "client", 
        event = "police:client:EvidenceStashDrawer",  
        icon = 'far fa-capsules', 
        label = 'Evidence', 
        job = "police",
        params = {id = 1},
        canInteract = function(entity)
            return true
        end,
    },
    -- Sandy Sheriff Target
    ["sheriffArmory"] = {
        coords = vector3(1838.31, 3696.09, 34.24),
        name = "sheriffArmory",
        heading = 30,
        info1 = 0.9,
        info2 = 0.5,
        minZ=34.19,
        maxZ=35.99,
        debugPoly = false,
        distance = 3.0,
        type = "client", 
        event = "qb-police:policeArmory",  
        icon = 'fas fa-box', 
        label = 'Open Armory', 
        job = "police",
        params = {},
        canInteract = function(entity)
            return true
        end,
    },
    ["sheriffPersonalStash"] = {
        coords = vector3(1842.3, 3692.17, 34.24),
        name = "sheriffPersonalStash",
        heading = 210,
        info1 = 0.5,
        info2 = 3.4,
        minZ=31.39,
        maxZ=35.39,
        debugPoly = false,
        distance = 2.0,
        type = "client", 
        event = "qb-police:policePersonalStash",  
        icon = 'fas fa-box-full', 
        label = 'Personal Stash', 
        job = "police",
        params = {},
        canInteract = function(entity)
            return true
        end,
    },
    ["sheriffFinger"] = {
        coords = vector3(1859.23, 3705.90, 34.37),
        name = "sheriffFinger",
        heading = 330,
        info1 = 0.3,
        info2 = 0.5,
        minZ=33.99,
        maxZ=34.59,
        debugPoly = false,
        distance = 2.0,
        type = "client", 
        event = "qb-police:policeFinger",  
        icon = 'fas fa-fingerprint', 
        label = 'FingerPrint', 
        job = "police",
        params = {},
        canInteract = function(entity)
            return true
        end,
    },
    ["sheriffEvidence"] = {
        coords = vector3(1857.08, 3698.61, 34.24),
        name = "sheriffEvidence",
        heading = 300,
        info1 = 3.6,
        info2 = 1,
        minZ=35.86,
        maxZ=39.86,
        debugPoly = false,
        distance = 2.0,
        type = "client", 
        event = "police:client:EvidenceStashDrawer",  
        icon = 'far fa-capsules',  
        label = 'Sheriff Evidence', 
        job = "police",
        params = {id = 8},
        canInteract = function(entity)
            return true
        end,
    },
       -- Paleto Sheriff Target
       ["sheriffPaletoArmory"] = {
        coords = vector3(-449.72, 6015.55, 37.0),
        name = "sheriffPaletoArmory",
        heading = 135,
        info1 = 0.9,
        info2 = 0.5,
        minZ = 33.85,
        maxZ = 37.85,
        debugPoly = false,
        distance = 3.0,
        type = "client", 
        event = "qb-police:policeArmory",  
        icon = 'fas fa-box', 
        label = 'Open Armory', 
        job = "police",
        params = {},
        canInteract = function(entity)
            return true
        end,
    },
    ["sheriffPaletoPersonalStash"] = {
        coords = vector3(-439.8, 6011.76, 37.0),
        name = "sheriffPaletoPersonalStash",
        heading = 315,
        info1 = 4.2,
        info2 = 0.5,
        minZ=34.2,
        maxZ=38.2,
        debugPoly = false,
        distance = 2.0,
        type = "client", 
        event = "qb-police:policePersonalStash",  
        icon = 'fas fa-box-full', 
        label = 'Personal Stash', 
        job = "police",
        params = {},
        canInteract = function(entity)
            return true
        end,
    },
    ["sheriffPaletoFinger"] = {
        coords = vector3(-452.55, 5997.2, 27.58),
        name = "sheriffPaletoFinger",
        heading = 225,
        info1 = 0.7,
        info2 = 0.5,
        minZ=27.38,
        maxZ=28.18,
        debugPoly = false,
        distance = 2.0,
        type = "client", 
        event = "qb-police:policeFinger",  
        icon = 'fas fa-fingerprint', 
        label = 'FingerPrint', 
        job = "police",
        params = {},
        canInteract = function(entity)
            return true
        end,
    },
    ["sheriffPaletoEvidence"] = {
        coords = vector3(-453.26, 6000.01, 37.01),
        name = "sheriffPaletoEvidence",
        heading = 315,
        info1 = 1.3,
        info2 = 0.5,
        minZ=37.01,
        maxZ=38.01,
        debugPoly = false,
        distance = 2.0,
        type = "client", 
        event = "police:client:EvidenceStashDrawer",  
        icon = 'far fa-capsules',  
        label = 'Sheriff Evidence', 
        job = "police",
        params = {id = 9},
        canInteract = function(entity)
            return true
        end,
    },
}
