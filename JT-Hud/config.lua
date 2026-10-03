Config = {}

Config.DebugPrint = false
Config.Locale     = "en"
Config.FrameWork  = "qb"
Config.NotifyType = "notify"

Config.ClockOffset = 3


Config.Settings = {
    StatusBars = {
        voice    = { active = true  },
        health   = { active = true  },
        armor    = { active = true  },
        hunger   = { active = true  },
        thirst   = { active = true  },
        stress   = { active = true  },
        oxygen   = { active = false  },
        stamina  = { active = true  },
        terminal = { active = false },
        leaf     = { active = false },
        engineHealth = { active = true },
    },
    VehicleHUD = {
        active         = true,
        kmH            = true,      
        lowFuelNotify  = false,
        manualModeType = false,
    },
    Compass = {                -- البوصلة واسم الشارع فوق بالنص
        active        = true,  -- false = تنشال البوصلة نهائياً
        onlyInVehicle = false, -- true = تطلع بالسيارة بس
        show          = true,
    },
    AccountHud = {
        active = false,
    },
    Seatbelt = {
        active = false,  
        key    = "B",
    },
    CruiseControl = {
        active = false,
        key    = "CAPITAL",
    },
}

-- ── الواجهة (NUI) ──
Config.Interface = {
    smoothAnimations = true,            -- false = بدون أي حركة نهائياً (أخف شي للأجهزة الضعيفة)
    watermark        = true,            -- إظهار الواتر مارك تحت (F9 يخفيه/يظهره)
    watermarkText    = "DIS.GG/JTCFW",  -- نص الواتر مارك
    clockSeconds     = true,
    scale            = 0.85,            -- حجم الواجهة كاملة (1.0 = الحجم الكبير، 0.85 = أصغر شوي)
    minimapSize      = 1.3,             -- حجم الخريطة (1.0 = الحجم القديم)            -- الثواني في الساعة اللي فوق الخريطة (false = تتحدث كل دقيقة بس)
}

-- ── هود الطيران (يطلع بالنص تحت مكان عداد السيارة) ──
Config.FlightHud = {
    active = true,
    -- سيارات تطير: يطلع لها هود الطيران بس وهي بالجو
    models = { "deluxo", "oppressor", "oppressor2", "thruster", "scramjet" },
}

Config.ElectricVehicles = {
    "Imorgon","Neon","Raiden","Cyclone","Voltic","Voltic2",
    "Tezeract","Airtug","Caddy","Caddy2","Caddy3",
    "Surge","Khamelion","RCBandito",
}

Config.SeatBeltBlackListVehicles = {
    [8]  = true,  -- 
    [13] = true,  -- Cycles
    [14] = true,  -- Boats
    [16] = true,  -- Planes
}

Config.DisableStress          = false
Config.DisablePoliceStress    = false
Config.StressChance           = 0
Config.MinimumStress          = 0
Config.MinimumSpeedUnbuckled  = 0
Config.MinimumSpeed           = 0
Config.StressItem             = 'small_weed_joint'
Config.StressReduceAmount     = 0

Config.WhitelistedWeaponArmed = {
    [`weapon_petrolcan`]        = true,
    [`weapon_hazardcan`]        = true,
    [`weapon_fireextinguisher`] = true,
    [`weapon_dagger`]           = true,
    [`weapon_bat`]              = true,
    [`weapon_bottle`]           = true,
    [`weapon_crowbar`]          = true,
    [`weapon_flashlight`]       = true,
    [`weapon_golfclub`]         = true,
    [`weapon_hammer`]           = true,
    [`weapon_hatchet`]          = true,
    [`weapon_knuckle`]          = true,
    [`weapon_knife`]            = true,
    [`weapon_machete`]          = true,
    [`weapon_switchblade`]      = true,
    [`weapon_nightstick`]       = true,
    [`weapon_wrench`]           = true,
    [`weapon_battleaxe`]        = true,
    [`weapon_poolcue`]          = true,
    [`weapon_briefcase`]        = true,
    [`weapon_briefcase_02`]     = true,
    [`weapon_garbagebag`]       = true,
    [`weapon_handcuffs`]        = true,
    [`weapon_bread`]            = true,
    [`weapon_stone_hatchet`]    = true,
    [`weapon_grenade`]          = true,
    [`weapon_bzgas`]            = true,
    [`weapon_molotov`]          = true,
    [`weapon_stickybomb`]       = true,
    [`weapon_proxmine`]         = true,
    [`weapon_snowball`]         = true,
    [`weapon_pipebomb`]         = true,
    [`weapon_ball`]             = true,
    [`weapon_smokegrenade`]     = true,
    [`weapon_flare`]            = true,
}

Config.WhitelistedWeaponStress = {
    [`weapon_petrolcan`]        = true,
    [`weapon_hazardcan`]        = true,
    [`weapon_fireextinguisher`] = true,
}

Config.VehClassStress = {
    ['0']  = true,  ['1']  = true,  ['2']  = true,
    ['3']  = true,  ['4']  = true,  ['5']  = true,
    ['6']  = true,  ['7']  = true,  ['8']  = true,
    ['9']  = true,  ['10'] = true,  ['11'] = true,
    ['12'] = true,  ['13'] = false, ['14'] = false,
    ['15'] = false, ['16'] = false, ['18'] = false,
    ['19'] = false, ['20'] = false, ['21'] = false,
}

Config.WhitelistedVehicles = {}

Config.WhitelistedJobs = {
    -- ['police'] = true,
}


Config.EffectInterval = {
    [1] = { min = 50, max = 60,  timeout = math.random(50000, 60000) },
    [2] = { min = 60, max = 70,  timeout = math.random(40000, 50000) },
    [3] = { min = 70, max = 80,  timeout = math.random(30000, 40000) },
    [4] = { min = 80, max = 90,  timeout = math.random(20000, 30000) },
    [5] = { min = 90, max = 100, timeout = math.random(15000, 20000) },
}

Config.HungerDecayRate = 0.0 
Config.ThirstDecayRate = 0.0   

Config.HungerDecayRate = 0.0
Config.ThirstDecayRate = 0.0



Config.DurabilityBlockedWeapons = {
    "weapon_unarmed",
    "weapon_handcuffs",
}


Config.DurabilityMultiplier = setmetatable({
    weapon_pistol_mk2       = 0.4,
    weapon_pistol           = 0.4,
    weapon_tle1911       = 0.4,
    weapon_combatpistol     = 0.4,
    weapon_appistol         = 0.5,
    weapon_pistol50         = 0.5,
    weapon_heavypistol      = 0.5,
    weapon_revolver         = 0.6,
    weapon_doubleaction     = 0.6,
    weapon_snspistol        = 0.4,
    weapon_vintagepistol    = 0.5,

    weapon_microsmg         = 0.3,
    weapon_smg              = 0.3,
    weapon_smg_mk2          = 0.3,
    weapon_assaultsmg       = 0.35,
    weapon_minismg          = 0.3,
    weapon_machinepistol    = 0.35,
    weapon_combatpdw        = 0.35,

    weapon_pumpshotgun      = 0.8,
    weapon_sawnoffshotgun   = 0.8,
    weapon_assaultshotgun   = 0.9,
    weapon_heavyshotgun     = 0.9,
    weapon_bullpupshotgun   = 0.85,

    weapon_assaultrifle     = 0.5,
    weapon_assaultrifle_mk2 = 0.5,
    weapon_carbinerifle     = 0.5,
    weapon_carbinerifle_mk2 = 0.5,
    weapon_advancedrifle    = 0.5,
    weapon_specialcarbine   = 0.5,
    weapon_bullpuprifle     = 0.5,
    weapon_compactrifle     = 0.45,
    weapon_gusenberg        = 0.45,

    weapon_mg               = 0.6,
    weapon_combatmg         = 0.6,
    weapon_combatmg_mk2     = 0.6,

    weapon_sniperrifle      = 1.2,
    weapon_heavysniper      = 1.2,
    weapon_heavysniper_mk2  = 1.2,
    weapon_marksmanrifle    = 1.0,

    weapon_emplauncher      = 0,
    weapon_rubbergun        = 0.4,
}, {
    __index = function() return 0.4 end 
})

Config.WeaponRepairCosts = setmetatable({
    pistol        = 250,
    rifle         = 600,
    smg           = 400,
    shotgun       = 500,
    mg            = 700,
    sniper        = 900,
    emplauncher   = 300,
    rubberslugs   = 200,
}, {
    __index = function() return 300 end 
})


Config.WeaponRepairPoints = {
    [1] = {
        coords       = vector3(12.27, -1103.1, 29.8),
        IsRepairing  = false,
        RepairingData = {},
    },
}