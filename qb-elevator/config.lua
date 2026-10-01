Config = {}
Config.Framework = "qbcore"
Config.Debug = false -- true = draw the qb-target zones

-- How you open the elevator at a point:
--   'auto'      = use the `interact` resource if it's running, otherwise qb-target,
--                 otherwise the built-in "[E] Elevator" prompt
--   'interact'  = darktable interact (press E)
--   'qb-target' = qb-target box zones (uses l1 / l2 / heading / minZ / maxZ)
--   'key'       = built-in 3D text + E key (no other resource needed)
Config.Interaction = 'auto'

-- Optional per building / per floor:
--   item = 'security_pass'          -> item needed to use it
--   jobs = { police = 0 }           -> only these jobs (min grade) can go to that floor
Config.Elevators = {
    [1] = {
        name = "Crastenburg Hotel", -- Building name
        item = nil, -- "security_pass"
        waittime = 3000, -- Progress bar waiting time
        floor = {
            [1] = {
                id = 1,
                disabled = false,
                floor = "0",
                name = "Recpition",
                target = {
                    pos = 1,
                    coords = vector3(-659.31, -1111.1, 15.06), 
                    l1 = 1,
                    l2 = 0.4, 
                    heading=335,
                    minZ=12.06,
                    maxZ=16.06,
                    playercoords = vector4(-658.84, -1110.34, 15.06, 72.47),
                },
            },
            [2] = {
                id = 2,
                disabled = false,
                floor = "1",
                name = "First Floor",
                target = {
                    pos = 1,
                    coords = vector3(-655.71, -1111.25, 21.83), 
                    l1 = 1,
                    l2 = 1, 
                    heading=300,
                    minZ=20.03,
                    maxZ=24.03,
                    playercoords = vector4(-655.48, -1110.88, 21.83, 146.56),
                },
            },
            [3] = {
                id = 3,
                disabled = false,
                floor = "2",
                name = "Second Floor",
                target = {
                    pos = 1,
                    coords = vector3(-655.82, -1111.46, 26.6), 
                    l1 = 1,
                    l2 = 1, 
                    heading=335,
                    minZ=23.6,
                    maxZ=27.6,
                    playercoords = vector4(-655.25, -1110.39, 26.6, 59.0),
                },
            },
            [4] = {
                id = 4,
                disabled = false,
                floor = "3",
                name = "Third Floor",
                target = {
                    pos = 1,
                    coords = vector3(-655.81, -1111.45, 31.37),  
                    l1 = 1,
                    l2 = 1, 
                    heading = 0,
                    minZ=28.17,
                    maxZ=32.17,
                    playercoords = vector4(-655.14, -1110.65, 31.37, 58.98),
                },
            },
            [5] = {
                id = 5,
                disabled = false,
                floor = "4",
                name = "Fourd Floor",
                target = {
                    pos = 1,
                    coords = vector3(-655.85, -1111.28, 36.14), 
                    l1 = 1,
                    l2 = 1, 
                    heading=335,
                    minZ=33.14,
                    maxZ=37.14,
                    playercoords = vector4(-655.32, -1110.51, 36.14, 62.57),
                },
            },
            [6] = {
                id = 6,
                disabled = false,
                floor = "5",
                name = "Five Floor",
                target = {
                    pos = 1,
                    coords = vector3(-655.78, -1111.45, 40.91), 
                    l1 = 1,
                    l2 = 1, 
                    heading=335,
                    minZ=37.71,
                    maxZ=41.71,
                    playercoords = vector4(-655.37, -1110.58, 40.91, 65.33),
                },
            },
            [7] = {
                id = 7,
                disabled = false,
                floor = "6",
                name = "Six Floor",
                target = {
                    pos = 1,
                    coords = vector3(-655.74, -1111.23, 45.68),  
                    l1 = 1,
                    l2 = 1, 
                    heading=335,
                    minZ=42.68,
                    maxZ=46.68,
                    playercoords = vector4(-655.45, -1110.56, 45.68, 65.29),
                },
            },
        }
    },
    [2] = {
        name = "Real Estate", -- Building name
        item = nil, -- "security_pass"
        waittime = 3000, -- Progress bar waiting time
        floor = {
            [1] = {
                id = 1,
                disabled = false,
                floor = "1",
                name = "Real Estate",
                target = {
                    pos = 1,
                    coords = vector3(-575.66, -714.87, 113.01), 
                    l1 = 1,
                    l2 = 0.4, 
                    heading=335,
                    minZ=110.01,
                    maxZ=114.01,
                    playercoords = vector4(-574.85, -715.83, 113.01, 85.34),
                },
            },
            [2] = {
                id = 2,
                disabled = false,
                floor = "0",
                name = "Street",
                target = {
                    pos = 1,
                    coords = vector3(-589.31, -708.35, 36.28), 
                    l1 = 1,
                    l2 = 1, 
                    heading=300,
                    minZ=33.48,
                    maxZ=37.48,
                    playercoords = vector4(-589.76, -707.91, 36.28, 355.65),
                },
            },
        }
    },
    [3] = {
        name = "Los Santos Police Department", -- Building name
        item = nil, -- "security_pass"
        waittime = 3000, -- Progress bar waiting time
        floor = {
            [1] = {
                id = 1,
                disabled = false,
                floor = "1",
                name = "The floor 1",
                target = {
                    pos = 1,
                    coords = vector3(459.44, -977.56, 30.35), 
                    l1 = 0.4,
                    l2 = 0.2, 
                    heading = 0,
                    minZ=30.29,
                    maxZ=30.89,
                    playercoords = vector4(460.3, -976.48, 30.25, 183.31),
                },
            },
            [2] = {
                id = 2,
                disabled = false,
                floor = "2",
                name = "The floor 2",
                target = {
                    pos = 1,
                    coords = vector3(459.97, -974.6, 36.90), 
                    l1 = 0.4,
                    l2 = 0.2, 
                    heading = 0,
                    minZ=39.81,
                    maxZ=40.41,
                    playercoords = vector4(460.95, -973.18, 36.8, 180.12),
                },
            },
            [3] = {
                id = 3,
                disabled = false,
                floor = "3",
                name = "The floor 3",
                target = {
                    pos = 1,
                    coords = vector3(453.77, -975.29, 40.90), 
                    l1 = 0.4,
                    l2 = 0.2, 
                    heading = 0,
                    minZ=44.82,
                    maxZ=45.42,
                    playercoords = vector4(454.64, -974.11, 40.76, 182.52),
                },
            },
        }
    }
}
