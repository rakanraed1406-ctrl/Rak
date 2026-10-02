Config = {}

Config.Debug  = false     -- true = يطبع بالـ F8 وش يصير (للتجربة فقط)
Config.Notify = 'ox'      -- 'ox' = ox_lib  |  'qb' = QBCore.Functions.Notify

--[[═════════════════════════════════════════════════════════════════════
    1) نظام الموتر (المحرك)
═════════════════════════════════════════════════════════════════════════]]
Config.Engine = {
    Enabled = true,

    -- ما ينطفي الموتر إلا إذا السرعة أقل من هذا الرقم
    MaxOffSpeed = 3.0,
    SpeedUnit   = 'kmh',          -- 'kmh' أو 'mph'

    -- الطيارات والهليكوبترات: ما ينطفي الموتر وهي بالجو أبد
    BlockInAir = true,

    -- زر G: إذا فيه شي ثاني يستخدم G، الموتر ما ينطفي من الزر
    -- (يطفيه من /motor أو بالنزول ضاغط F مطوّل)
    GKey = {
        Controls = { 47, 58, 113 },   -- أكواد G باللعبة (لا تغيرها إلا تعرف وش تسوي)
        Window   = 800,               -- كم ملّي ثانية نعتبر G "توه انضغط"
        Aircraft = true,              -- بالطيارة/الهيلي G = الكفرات ← ما يطفي الموتر
        Always   = false,             -- true = G ما يطفي الموتر بأي مركبة أبد
        Classes  = {                  -- أصناف G فيها مستخدم (مثال: [18] = true للطوارئ)
        },
        Models   = {                  -- موديلات G فيها مستخدم (مثال: ['police'] = true)
        },
        -- أي سكربت ثاني يقدر يقول "G مستخدم الحين":
        --   LocalPlayer.state:set('gKeyBusy', true, false)
        --   أو exports['qb-customscripts-byrko']:SetGKeyBusy(true)
        -- (التابلت mdt-police-tablet مربوط فيها: لما يطلع بلاغ وتضغط G للرد ما ينطفي الموتر)
    },

    -- الحماية تشتغل بعد ما يكون الموتر شغال كذا ملّي ثانية (عشان ما تتضارب مع نظام المفاتيح)
    ArmDelay = 2500,

    -- حالات طبيعية ينطفي فيها الموتر حتى لو ماشي (ما نرجّعه)
    AllowOffBelowEngineHealth = 150.0,   -- موتر خربان
    AllowOffBelowFuel         = 1.0,     -- بنزين خالص
    CrashDamage               = 40.0,    -- حادث قوي (نقص صحة بلحظة وحدة)
    CrashWindow               = 2500,

    -- لو سكربت ثاني يصر يطفيه (أكثر من كذا مرة بثلاث ثواني) نتركه
    MaxBlocks = 4,

    -- أمر تشغيل/إطفاء الموتر (يتبع نفس القوانين)
    Toggle = {
        Command = 'motor',
        Key     = '',                -- فاضي = بدون زر (تقدر تربطه من إعدادات اللعبة)
    },
}

--[[═════════════════════════════════════════════════════════════════════
    2) الموتر يبقى شغال لما تنزل
═════════════════════════════════════════════════════════════════════════]]
Config.KeepEngineOn = {
    Enabled  = true,
    Aircraft = false,        -- الطيارات/الهيلي: false = تنطفي لما تنزل
    -- تضغط F عادي = تنزل والموتر شغال
    -- تضغط F مطوّل = تنزل وتطفي الموتر
    HoldToTurnOff = true,
    HoldTime      = 650,
    -- الكفرات تبقى ملفوفة مثل ما تركتها لما تنزل
    KeepWheelAngle = true,
}

--[[═════════════════════════════════════════════════════════════════════
    3) هوا المراوح (هز الكاميرا + دفع السيارات القريبة)
═════════════════════════════════════════════════════════════════════════]]
Config.RotorWash = {
    Enabled       = true,
    Range         = 50.0,
    MaxHeight     = 40.0,
    ShakeHeli     = 0.25,
    ShakePlane    = 0.02,
    PushVehicles  = true,
    PushRange     = 15.0,
    PushForceHeli = 12.0,
    PushForcePlane = 18.0,
}

--[[═════════════════════════════════════════════════════════════════════
    4) الضرب داخل السيارة (الراكب يقدر يضرب اللي معه بنفس السيارة)
═════════════════════════════════════════════════════════════════════════]]
Config.PassengerCombat = {
    Enabled         = true,
    RequireAiming   = true,    -- لازم يصوّب (كلك يمين)
    FirstPersonOnly = false,
    MaxDistance     = 10.0,
    HeadshotRadius  = 0.25,
    Damage          = 50,      -- الضرر بالطلقة (السيرفر هو اللي يحدده)
    FireInterval    = 180,     -- أقل وقت بين طلقتين (ملّي ثانية)
    MaxHitsPerSecond = 6,      -- أقصى ضربات على نفس الشخص بالثانية (من كل اللاعبين)
    -- ما يحسب الضرب بهذي (أسلحة بيضاء / رمي)
    BlockedWeapons = {
        'WEAPON_KNIFE', 'WEAPON_NIGHTSTICK', 'WEAPON_HAMMER', 'WEAPON_BAT', 'WEAPON_CROWBAR',
        'WEAPON_GOLFCLUB', 'WEAPON_BOTTLE', 'WEAPON_DAGGER', 'WEAPON_HATCHET', 'WEAPON_KNUCKLE',
        'WEAPON_MACHETE', 'WEAPON_FLASHLIGHT', 'WEAPON_SWITCHBLADE', 'WEAPON_POOLCUE', 'WEAPON_WRENCH',
        'WEAPON_BATTLEAXE', 'WEAPON_STONE_HATCHET', 'WEAPON_GRENADE', 'WEAPON_STICKYBOMB',
        'WEAPON_PROXMINE', 'WEAPON_BZGAS', 'WEAPON_MOLOTOV', 'WEAPON_SMOKEGRENADE', 'WEAPON_FLARE',
        'WEAPON_PIPEBOMB', 'WEAPON_BALL', 'WEAPON_SNOWBALL', 'WEAPON_PETROLCAN', 'WEAPON_FIREEXTINGUISHER',
        'WEAPON_STUNGUN', 'WEAPON_STUNGUN_MP',
    },
}

-- الحماية من الغش (الأحداث اللي تجي من الكلاينت)
Config.Security = {
    KickOnAbuse = false,   -- true = يطرد اللي يكرر محاولات الغش
    MaxStrikes  = 5,       -- كم محاولة بالدقيقة قبل الطرد
}

--[[═════════════════════════════════════════════════════════════════════
    5) ضبط السيارات (القومة / الريوس / القياس)
═════════════════════════════════════════════════════════════════════════]]
Config.VehicleTuning = {
    Enabled = true,

    Target0to100 = 4.0,     -- /carcalib يظبط القومة على هذا الرقم (ثواني)
    Tolerance    = 0.1,     -- ± كم ثانية مقبولة
    MaxCalibRuns = 6,

    TestCommand  = 'cartest',
    CalibCommand = 'carcalib',
    AdminAce     = 'command',   -- مين يقدر يستخدم /carcalib (أو أدمن QBCore)

    -- أقصى سرعة للريوس (كم/س)
    Reverse = {
        Enabled = true,
        Default = 35.0,
        Models = {
            ['b211vic']      = 32.0,
            ['b212caprice']  = 35.0,
            ['b214charger']  = 35.0,
            ['b216explorer'] = 32.0,
            ['b218charger']  = 35.0,
            ['b218tau']      = 35.0,
            ['b219tahoe']    = 30.0,
            ['b2chal']       = 38.0,
        },
    },
}

--[[═════════════════════════════════════════════════════════════════════
    6) أنظمة الرول بلاي (كل وحدة تقدر تطفيها)
═════════════════════════════════════════════════════════════════════════]]
Config.Roleplay = {
    -- الراكب ما ينتقل لحاله لكرسي السواق + أمر /shuff
    SeatShuffle = { Enabled = true, Command = 'shuff' },

    -- ما ياخذ سلاح من سيارات الشرطة/الطوارئ
    NoVehicleRewards = true,

    -- ما يقدر يتحكم بالسيارة وهي طايرة ولا يقلبها وهي مقلوبة
    AntiAirControl = {
        Enabled = true,
        BlockFlipBack = true,
        IgnoreClasses = { [8] = true, [13] = true, [14] = true, [15] = true, [16] = true, [21] = true },
    },

    -- ما يلبس خوذة تلقائي على الدباب
    NoAutoHelmet = true,

    -- يوقف كاميرا الخمول (اللي تدور لما تقعد ما تتحرك)
    NoIdleCam = true,

    -- /stuck: يفك التعليق (أنيميشن معلق / غرض لاصق باليد)
    Stuck = { Enabled = true, Command = 'stuck', Cooldown = 30 },
}
