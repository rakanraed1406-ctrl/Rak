Config = {}

-- اسم الوظيفة في السيرفر (Job Name)
Config.JobName = 'police'

-- أقل رتبة (Level) مطلوبة للتحكم بصلاحيات الإدارة والـ Command Staff
Config.MinCommandGrade = 9

-- ==========================================================================
-- لوق ديسكورد (بدال نظام /mdtlog الإداري القديم اللي انشال بالكامل)
-- ==========================================================================
-- حط رابط الـ Webhook هنا عشان يشتغل اللوق. خله فاضي '' لو ما تبي أي لوق
-- ديسكورد إطلاقًا. يرسل فقط الأحداث "المهمة": توظيف، طرد/فصل، ترقية،
-- تنزيل رتبة، تعليق/فك تعليق صلاحية، تغيير حالة الإغلاق الأمني، طلب دعم
-- (Code 99)، والتنبيهات. فتح أو قفل التابلت نفسه ما يترسل أبدًا.
Config.DiscordWebhook = ''
Config.DiscordWebhookName = 'Police MDT Log'
Config.DiscordWebhookAvatar = ''

-- ==========================================================================
-- الديسباتش صار مدموج داخل التابلت نفسه (نظام الـ HUB انشال واندمج هنا).
-- ما يحتاج sk1-hub بعد الحين — شيله من server.cfg عشان ما يصير تعارض.
-- السكربتات الثانية اللي تنادي exports['sk1-hub']:CreateDispatchCall تبقى
-- شغالة لأن التابلت يسجل نفس الإكسبورت باسم sk1-hub (شوف Config.Dispatch.Sk1HubCompat).
-- ==========================================================================
Config.Dispatch = {
    -- تسجيل exports['sk1-hub']:CreateDispatchCall من داخل التابلت (للتوافق مع السكربتات القديمة)
    Sk1HubCompat = true,

    -- أوامر البلاغات للمواطنين
    Commands911 = { '911', '919' },
    -- بلاغ مجهول (ما يطلع اسم المتصل ولا رقمه)
    CommandsAnonymous = { '911a' },
    -- الشرطي يرد على المتصل: /reply C1001 الرسالة
    ReplyCommand = 'reply',

    -- الإشعارات توصل بس للي معه أيتم التابلت بالانفنتوري
    RequireItemForAlerts = true,
    -- والإشعارات توصل بس للي على الدوام
    RequireDutyForAlerts = true,

    -- كم بلاغ يتخزن بالهستوري
    MaxHistory = 40,
    -- البلاغ ينقفل تلقائيًا بعد هالمدة (بالدقايق) لو ما أحد قفله — 0 = أبدًا
    AutoCloseMinutes = 30,

    -- أصوات الإشعارات: فاضي = صوت مدمج (مولّد داخل الـ NUI، كل مستوى له نغمة مختلفة).
    -- تبي ملف صوت خاص؟ حطه بـ html/sounds/ واكتب اسمه هنا (مثال 'sounds/high.ogg')
    -- وضيف 'html/sounds/*.ogg' في files داخل fxmanifest.lua.
    -- الكتم والصوت (Volume) يتحكم فيه كل ضابط من التابلت: Dispatch > Sound & Alerts.
    Sounds = { low = '', medium = '', high = '' },
    DefaultVolume = 0.7,

    -- الإشعار ما يبقى طول الوقت: يدخل بأنيميشن، يبقى المدة هذي، وبعدين يطلع بأنيميشن.
    -- (بالمللي ثانية) سهل 10 ثواني · متوسط 15 ثانية · صعب 20 ثانية
    ToastDuration = { low = 10000, medium = 15000, high = 20000 },

    -- أزرار الإشعار وهو ظاهر (والتابلت مسكّر): رد على البلاغ / تجاهل
    RespondKey = 'G',
    DismissKey = 'DELETE',
    -- زر كتم/تشغيل صوت الإشعارات بسرعة (فاضي = بدون زر، يبقى الأمر /mdtmute)
    MuteKey = '',

    -- زر البانيك (فاضي = بدون زر افتراضي، تقدر تربطه من إعدادات اللعبة) والأمر /panic
    PanicKey = '',
    PanicCommand = 'panic',
    PanicCooldown = 15, -- ثواني

    -- ترتيب الأولوية حسب الكود (يتقدّم على اللي يرسله السكربت الخارجي)
    -- low = سهل (أزرق)  |  medium = متوسط (أصفر)  |  high = صعب (أحمر)
    CodePriority = {
        ['10-99'] = 'high',     -- Officer down / panic
        ['10-13'] = 'high',
        ['10-11'] = 'high',     -- Shots fired
        ['10-60'] = 'high',     -- Shots from vehicle
        ['10-71'] = 'high',
        ['10-90'] = 'high',     -- Robbery / alarm
        ['MOST-WANTED'] = 'high',
        ['10-35'] = 'medium',   -- Carjacking
        ['10-16'] = 'medium',   -- Stolen vehicle
        ['SPEEDING'] = 'low',   -- Speed trap
        ['911-ANON'] = 'medium',
        ['911-CALL'] = 'medium',
        ['BOLO'] = 'medium',
        ['10-14'] = 'medium',
        ['ALL-UNITS'] = 'low',
        ['ALERT-LEVEL'] = 'low',
        ['DIRECTIVE'] = 'low',
    },

    -- الأدوار اللي يقدر الديسباتشر يعطيها للوحدات
    UnitRoles = {
        'Awaiting role', 'Primary unit', 'Scene command', 'Entry team', 'Perimeter',
        'Traffic control', 'Investigation', 'Medical staging'
    },

    -- الحالات المسموحة من قائمة الـ Hub
    Statuses = { 'active', 'dispatch', 'commander', 'break' },

    -- استقبال بلاغات السكربتات القديمة (cd_dispatch / ps-dispatch / qb-dispatch / qb-policejob)
    LegacyEvents = true,
}

-- إعدادات الـ Hub (قائمة الشرطة داخل التابلت)
Config.Hub = {
    -- لو true: فتح التابلت وأنت خارج الدوام يسجل دخولك تلقائيًا (السلوك القديم).
    -- لو false: التابلت ينفتح وتسجل دخولك بنفسك من تطبيق Command Hub.
    AutoClockIn = false,
    -- كل كم مللي ثانية الكلاينت يرسل موقعه (اسم الشارع / المركبة / الراديو)
    PresenceInterval = 5000,
    -- ممنوع روابط/HTML بالكول ساين والرسائل
    BlockedPatterns = {
        'http://', 'https://', 'www%.', 'discord%.gg', 'discord%.com', '%.com', '%.net', '%.org',
        '%.xyz', '%.io', '%.me', '%.gg', '<script', '<html', '<iframe', 'href=', 'src=', 'javascript:'
    },
    -- قنوات الشات
    ChatChannels = {
        { id = 'all', label = '#All-Units' },
        { id = 'tac1', label = '#Tac-1' },
        { id = 'command', label = '#Command' },
    },
    ChatHistory = 60,
    -- بلبات الزملاء على خريطة اللعبة (لكل ضابط على الدوام) — نفس نظام الـ HUB
    UnitBlips = true,
    UnitBlipColor = 38,       -- أزرق
    UnitBlipScale = 0.8,
    UnitBlipSprites = { person = 1, car = 56, bike = 348, helicopter = 43, plane = 423, boat = 427 },
    -- مدة بلب البانيك على الخريطة (مللي ثانية)
    PanicBlipDuration = 90000,
}

-- مجموعة الصلاحيات المطلوبة (لم تعد مستخدمة بعد إزالة /mdtlog، تركت لو حبيت تستخدمها بمكان ثاني)
Config.MdtLogPermission = 'admin'

-- المسافة المسموحة لتوظيف لاعب قريب (بالأمتار)
Config.HireDistance = 3.0

-- أسماء جداول قاعدة البيانات (Database Tables)
Config.ReportsTable = 'police_reports'
Config.DirectivesTable = 'police_directives'
Config.MdtLogsTable = 'police_mdt_logs'
Config.BolosTable = 'police_bolos'
Config.ApplicationsTable = 'police_applications'
Config.PlayerVehiclesTable = 'player_vehicles'

-- الحد الأقصى لعدد طلبات التوظيف التي يتم إظهارها في اللوحة
Config.MaxApplicationsShown = 20

-- إعدادات نظام التتبع (GPS) للأعضاء في الخدمة (بالمللي ثانية)
Config.GPSRefreshInterval = 3000

-- مدة ظهور نقطة الدعم (Backup Ping) على الخريطة (بالمللي ثانية)
Config.BackupPingDuration = 60000

-- إعدادات كاميرات المراقبة (CCTV)
Config.CameraDefaultPanLimit = 45.0
Config.CameraPanSpeed = 1.5
Config.CameraTimecycleModifier = 'default'

Config.Cameras = {
    { name = 'Mission Row - Front Entrance', coords = vector4(434.78, -981.85, 30.71, 180.0), panLimit = 60.0, fov = 50.0 },
    { name = 'Mission Row - Booking Area', coords = vector4(475.21, -993.42, 26.27, 90.0), panLimit = 45.0, fov = 50.0 },
    { name = 'Mission Row - Armory & Garage', coords = vector4(452.12, -980.34, 30.69, 270.0), panLimit = 50.0, fov = 50.0 },
}

-- ==========================================================================
-- فتح التابلت: أيتم + وظيفة (كلاهما مطلوب)
-- ==========================================================================
Config.MdtItem = 'mdt'

-- ==========================================================================
-- أنيميشن فتح/قفل التابلت
-- ==========================================================================
-- السكربت الحين يشغل الأنيميشن مباشرة (مو عن طريق أمر إيموت خارجي زي "/e tablet")،
-- فما يحتاج ريسورس إيموشنز ثاني عشان تشتغل.
Config.TabletAnimDict = "amb@code_human_in_bus_passenger_idles@female@tablet@base"
Config.TabletAnimName = "base"
Config.TabletProp = `prop_cs_tablet`

-- مكان إمساك البروب (البون + الإزاحة/الدوران). القيم هذي متوافقة مع
-- الأنيميشن والبروب أعلاه؛ لو حسّيت إن التابلت مو ملتصق بإيد الشخصية 100%
-- بس عدّل هالأرقام لين تظبط بالضبط عندك.
Config.TabletPropBone = 28422 -- SKEL_L_Hand
Config.TabletPropOffset = vector3(0.034, 0.001, -0.042)
Config.TabletPropRotation = vector3(0.0, 0.0, 0.0)

-- ==========================================================================
-- الخريطة التكتيكية
-- ==========================================================================
Config.MapWorldBounds = {
    minX = -4000.0, maxX = 4600.0,
    minY = -4300.0, maxY = 8100.0
}

-- ==========================================================================
-- تكامل الـ Bodycam — مربوط مباشرة بسكربت qb-bodycam (! TMX)
-- ==========================================================================
Config.BodycamResource = 'qb-bodycam'
Config.BodycamExitKeyLabel = 'BACKSPACE'

-- ==========================================================================
-- راديو الشرطة (اختياري) — ربط عام لحين إرسال ملفات سكربت راديو محدد
-- ==========================================================================
Config.RadioResource = ''
Config.RadioOpenCommand = 'radio'

-- ==========================================================================
-- البلاغات التلقائية (شوت فاير / سرقة سيارة / رادار السرعة)
-- تطلع للشرطة داخل التابلت بنفس نظام الأولويات والأصوات.
-- ==========================================================================
Config.Alerts = {
    Enabled = true,
    -- هالوظائف (وهم على الدوام) ما يطلّعون بلاغات تلقائية
    IgnoreJobs = { 'police', 'ambulance' },

    -- سرقة سيارة / كارجاك (يحاول يفتح سيارة مقفلة أو يسحب أحد من سيارته)
    StolenCar = {
        enabled = true,
        cooldown = 25, -- ثواني لكل لاعب
    },

    -- إطلاق نار
    Gunshots = {
        enabled = true,
        cooldown = 15, -- ثواني لكل لاعب
        ignoreSilenced = true, -- السلاح بكاتم ما يطلّع بلاغ
        -- أماكن ما يطلع فيها بلاغ (ميدان رماية مثلًا)
        WhitelistedZones = {
            { coords = vector3(13.5, -1097.5, 29.8), radius = 25.0 },   -- Ammu-Nation (ميدان الرماية)
            { coords = vector3(821.5, -2163.6, 29.6), radius = 25.0 },  -- Ammu-Nation Cypress Flats
        },
        WhitelistedWeapons = {
            [`WEAPON_FLARE`] = true, [`WEAPON_FLAREGUN`] = true, [`WEAPON_FIREEXTINGUISHER`] = true,
            [`WEAPON_PETROLCAN`] = true, [`WEAPON_STUNGUN`] = true, [`WEAPON_SNOWBALL`] = true,
            [`WEAPON_BALL`] = true, [`WEAPON_HAZARDCAN`] = true,
        },
        -- أسماء الأسلحة اللي تطلع بالبلاغ (اللي مو موجود يطلع "Firearm")
        WeaponLabels = {
            [`WEAPON_PISTOL`] = 'Pistol', [`WEAPON_PISTOL_MK2`] = 'Pistol MK2', [`WEAPON_COMBATPISTOL`] = 'Combat Pistol',
            [`WEAPON_HEAVYPISTOL`] = 'Heavy Pistol', [`WEAPON_PISTOL50`] = '.50 Pistol', [`WEAPON_SNSPISTOL`] = 'SNS Pistol',
            [`WEAPON_REVOLVER`] = 'Revolver', [`WEAPON_MICROSMG`] = 'Micro SMG', [`WEAPON_SMG`] = 'SMG',
            [`WEAPON_ASSAULTRIFLE`] = 'Assault Rifle', [`WEAPON_CARBINERIFLE`] = 'Carbine Rifle',
            [`WEAPON_CARBINERIFLE_MK2`] = 'Carbine Rifle MK2', [`WEAPON_SPECIALCARBINE`] = 'Special Carbine',
            [`WEAPON_BULLPUPRIFLE`] = 'Bullpup Rifle', [`WEAPON_PUMPSHOTGUN`] = 'Pump Shotgun',
            [`WEAPON_SAWNOFFSHOTGUN`] = 'Sawed-off Shotgun', [`WEAPON_MUSKET`] = 'Musket',
            [`WEAPON_SNIPERRIFLE`] = 'Sniper Rifle', [`WEAPON_MG`] = 'Machine Gun',
        },
    },

    -- رادار السرعة (طافي افتراضيًا)
    SpeedTrap = {
        enabled = false,
        cooldown = 10,         -- ثواني لكل لاعب
        unit = 'kmh',          -- 'kmh' أو 'mph'
        checkOwner = false,    -- true = يغرّم بس لو السيارة ملكه (السيارات المسروقة ما تنغرّم)
        fineAccount = 'bank',
        alertPolice = true,    -- بلاغ أزرق للشرطة مع الغرامة
        blip = { enabled = true, sprite = 184, color = 1, scale = 0.6, display = 5, name = 'Speed Camera' },
        Locations = {
            { coords = vector3(1051.42, 331.11, 84.00), radius = 9.0, limit = 150, fine = 500 },   -- LS Freeway
            { coords = vector3(544.43, -373.24, 33.14), radius = 9.0, limit = 130, fine = 1000 },  -- Legion
            { coords = vector3(287.94, -517.44, 42.89), radius = 15.0, limit = 100, fine = 500 },  -- Pillbox
            { coords = vector3(2792.73, 4407.68, 48.44), radius = 24.0, limit = 150, fine = 1000 }, -- Sandy Freeway
        },
    },

    -- وحدات الشرطة: البلب يومض لما السيارين شغال
    FlashBlipOnSiren = true,
    -- صوت البانيك يسمعه اللي قريبين (بالأمتار، 0 = طافي)
    PanicSoundRadius = 40.0,
}

-- كولداون بين كل رسمة/دبوس على الخريطة من نفس الضابط (مللي ثانية)
Config.MapMarkerCooldownMs = 1000
