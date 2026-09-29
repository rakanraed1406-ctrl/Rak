Config = {}

-- اسم وظيفة الإسعاف في السيرفر (Job Name)
Config.JobName = 'ambulance'

-- أقل رتبة (Level) مطلوبة لصلاحيات القيادة (Command Staff): التوظيف، الترقية، الخزنة، التعاميم...
Config.MinCommandGrade = 9

-- اسم القطاع اللي يطلع بالتابلت (شاشة القفل، شريط الحالة، About)
Config.Department = {
    Short = 'EMS',                                  -- يطلع بشريط الحالة (EMS MDT)
    Name = 'Los Santos Medical Services',           -- الاسم الكامل
    Sub = 'Medical Data Terminal · Secure Session', -- السطر الصغير تحته
}

-- ==========================================================================
-- لوق ديسكورد (توظيف، فصل، ترقية، تعليق، بانيك، حالة الطوارئ، البث...)
-- خله فاضي '' لو ما تبي لوق. فتح وقفل التابلت ما يترسل أبدًا.
-- ==========================================================================
Config.DiscordWebhook = ''
Config.DiscordWebhookName = 'EMS MDT Log'
Config.DiscordWebhookAvatar = ''

-- ==========================================================================
-- الديسباتش (CAD) — نفس نظام تابلت الشرطة بالضبط لكن للإسعاف.
-- ==========================================================================
Config.Dispatch = {
    -- رقم البلاغ يبدأ بهالحرف (الشرطة C1001 ← الإسعاف E1001)
    CallPrefix = 'E',

    -- أوامر بلاغات المواطنين للإسعاف (تشيل /997 القديم حق qb-hospital وتسويه داخل التابلت)
    Commands911 = { '997', '911ems' },
    -- بلاغ إسعاف مجهول (ما يطلع اسم المتصل ولا رقمه) — {} = بدون
    CommandsAnonymous = { '997a' },
    -- المسعف يرد على المتصل: /997r E1001 الرسالة   (أو /997r [ID اللاعب] الرسالة مثل القديم)
    ReplyCommand = '997r',

    -- الإشعارات توصل بس للي معه أيتم التابلت بالانفنتوري
    RequireItemForAlerts = true,
    -- والإشعارات توصل بس للي على الدوام
    RequireDutyForAlerts = true,

    -- كم بلاغ يتخزن بالهستوري
    MaxHistory = 40,
    -- البلاغ ينقفل تلقائيًا بعد هالمدة (بالدقايق) لو ما أحد قفله — 0 = أبدًا
    AutoCloseMinutes = 30,

    -- أصوات الإشعارات: فاضي = صوت مدمج (كل مستوى له نغمة). تبي ملف؟ حطه بـ html/sounds/
    -- واكتب اسمه هنا (مثال 'sounds/high.ogg') وضيف 'html/sounds/*.ogg' في fxmanifest.lua
    Sounds = { low = '', medium = '', high = '' },
    DefaultVolume = 0.7,

    -- مدة الإشعار (مللي ثانية): سهل 10 ثواني · متوسط 15 ثانية · صعب 20 ثانية
    ToastDuration = { low = 10000, medium = 15000, high = 20000 },

    -- أزرار الإشعار والتابلت مسكّر
    RespondKey = 'G',
    DismissKey = 'DELETE',
    MuteKey = '', -- فاضي = بدون زر (الأمر /emdtmute)

    -- زر بانيك المسعف (فاضي = بدون زر افتراضي، تقدر تربطه من إعدادات اللعبة)
    PanicKey = '',
    PanicCommand = 'emspanic',
    PanicCooldown = 15, -- ثواني
    -- بانيك المسعف يوصل كمان للشرطة (تابلت الشرطة mdt-police-tablet لازم يكون شغال)
    PanicAlsoAlertsPolice = true,

    -- لون كل كود (يتقدّم على اللي يرسله السكربت الخارجي)
    -- low = سهل (أزرق)  |  medium = متوسط (أصفر)  |  high = صعب (أحمر)
    CodePriority = {
        ['10-99'] = 'high',        -- مسعف في خطر (بانيك)
        ['10-69'] = 'high',        -- مواطن بدون نبض (من qb-hospital)
        ['10-47'] = 'medium',      -- مواطن مصاب / ينزف (من qb-hospital)
        ['MCI'] = 'high',          -- إصابات جماعية
        -- 10-50 حادث سيارة (تلقائي): أصفر، ولو السيارة منقلبة أحمر
        ['997-CALL'] = 'medium',
        ['997-ANON'] = 'medium',
        ['CHECK-IN'] = 'low',      -- مريض ينتظر بالاستقبال
        ['CRITICAL-PT'] = 'high',  -- مريض حالته حرجة بالعنبر
        ['ALL-UNITS'] = 'low',
        ['ALERT-LEVEL'] = 'low',
        ['DIRECTIVE'] = 'low',
    },

    -- الأدوار اللي يقدر الديسباتشر يعطيها للمسعفين على البلاغ
    UnitRoles = {
        'Awaiting role', 'Lead paramedic', 'Scene command', 'Triage', 'Treatment',
        'Transport', 'Air ambulance', 'Staging'
    },

    -- الحالات المسموحة من قائمة الـ Hub
    -- active = متاح · transport = ينقل مريض · hospital = بالمستشفى · dispatch · commander = مشرف · break = استراحة
    Statuses = { 'active', 'transport', 'hospital', 'dispatch', 'commander', 'break' },

    -- استقبال بلاغات الإسعاف من السكربتات القديمة (cd_dispatch / ps-dispatch / qb-dispatch / qb-hospital)
    LegacyEvents = true,
    -- لو حذفت cd_dispatch: السكربتات اللي تنادي exports['cd_dispatch']:GetPlayerInfo() تبقى شغالة
    CdDispatchCompat = true,
}

-- إعدادات الـ Hub (قائمة الإسعاف داخل التابلت)
Config.Hub = {
    -- true = فتح التابلت وأنت خارج الدوام يسجل دخولك تلقائيًا
    AutoClockIn = false,
    PresenceInterval = 5000,
    BlockedPatterns = {
        'http://', 'https://', 'www%.', 'discord%.gg', 'discord%.com', '%.com', '%.net', '%.org',
        '%.xyz', '%.io', '%.me', '%.gg', '<script', '<html', '<iframe', 'href=', 'src=', 'javascript:'
    },
    ChatChannels = {
        { id = 'all', label = '#All-Medics' },
        { id = 'med1', label = '#Med-1' },
        { id = 'command', label = '#Command' },
    },
    ChatHistory = 60,
    -- بلبات الزملاء على خريطة اللعبة
    UnitBlips = true,
    UnitBlipColor = 1,        -- أحمر
    PanicBlipColor = 5,       -- أصفر (عشان يتميز عن بلب المسعف الأحمر)
    UnitBlipScale = 0.8,
    UnitBlipSprites = { person = 1, car = 56, bike = 348, helicopter = 43, plane = 423, boat = 427 },
    PanicBlipDuration = 90000,
}

-- المسافة المسموحة لتوظيف لاعب قريب / فوترة مريض قريب (بالأمتار)
Config.HireDistance = 3.0

-- أسماء جداول قاعدة البيانات (تنسوى تلقائيًا أول تشغيل)
Config.Tables = {
    Reports = 'ems_reports',
    Directives = 'ems_directives',
    Logs = 'ems_mdt_logs',
    Ward = 'ems_ward_board',
    Suspended = 'ems_suspended',
    Patients = 'ems_patients',
    Bills = 'ems_bills',
    Funds = 'ems_funds',
    Applications = 'ems_applications',
}

Config.MaxApplicationsShown = 20

-- ==========================================================================
-- نقاط الإسعاف (نفس الـ metadata حق qb-emspoints) — تطلع بتطبيق Personnel
-- والقيادة تقدر تزيد/تنقص/تصفر النقاط من التابلت.
-- ==========================================================================
Config.Points = {
    Enabled = true,
    MetadataKey = 'ambulancepoints',
    MaxPerAction = 100, -- أكثر عدد نقاط ينعطى/ينشال بضغطة وحدة
}

-- ==========================================================================
-- الفواتير الطبية (تطبيق Billing)
-- ==========================================================================
Config.Billing = {
    -- true = الفاتورة تنسحب من حساب المريض فعليًا (لازم يكون قريب منك ومتصل)
    -- false = تنسجل بالسجل بس (مثل مخالفات الشرطة)
    ChargePatient = true,
    Account = 'bank',
    MaxAmount = 50000,
    -- كم نسبة من الفاتورة تروح لخزنة القسم (الباقي ما يروح لأحد) — 1.0 = كلها
    TreasuryShare = 1.0,
    -- قائمة جاهزة تطلع بالتطبيق (المسعف يقدر يكتب غيرها)
    Presets = {
        { label = 'Basic treatment', amount = 250 },
        { label = 'Bandaging / wound care', amount = 150 },
        { label = 'Revive (field)', amount = 500 },
        { label = 'Ambulance transport', amount = 400 },
        { label = 'Surgery', amount = 1500 },
        { label = 'Air ambulance', amount = 2000 },
    },
}

-- ==========================================================================
-- ربط سكربت المستشفى qb-hospital (الإصابات الحية تطلع بسجل المريض)
-- ==========================================================================
Config.HospitalResource = 'qb-hospital'

-- ==========================================================================
-- فتح التابلت: أيتم + وظيفة (كلاهما مطلوب)
-- ==========================================================================
Config.MdtItem = 'ems_tablet'
Config.OpenCommand = 'emdt'
-- أمر تقديم طلب توظيف للإسعاف (للمواطنين)
Config.ApplicationCommand = 'emsapp'

-- ==========================================================================
-- أنيميشن فتح/قفل التابلت
-- ==========================================================================
Config.TabletAnimDict = "amb@code_human_in_bus_passenger_idles@female@tablet@base"
Config.TabletAnimName = "base"
Config.TabletProp = `prop_cs_tablet`
Config.TabletPropBone = 28422 -- SKEL_L_Hand
Config.TabletPropOffset = vector3(0.034, 0.001, -0.042)
Config.TabletPropRotation = vector3(0.0, 0.0, 0.0)

-- ==========================================================================
-- الخريطة
-- ==========================================================================
Config.MapWorldBounds = {
    minX = -4000.0, maxX = 4600.0,
    minY = -4300.0, maxY = 8100.0
}
Config.GPSRefreshInterval = 3000
-- مدة بلب نداء الإصابات الجماعية (MCI) على الخريطة
Config.BackupPingDuration = 60000
Config.MapMarkerCooldownMs = 1000

-- ==========================================================================
-- كاميرات المستشفى (CCTV) — عدّل الإحداثيات على مستشفاك
-- ==========================================================================
Config.CameraDefaultPanLimit = 45.0
Config.CameraPanSpeed = 1.5
Config.CameraTimecycleModifier = 'default'
Config.Cameras = {
    { name = 'Hospital - Ambulance Bay', coords = vector4(-283.50, -575.20, 31.50, 150.0), panLimit = 60.0, fov = 55.0 },
    { name = 'Hospital - Lobby / Check-in', coords = vector4(-336.20, -594.80, 35.80, 200.0), panLimit = 50.0, fov = 55.0 },
    { name = 'Pillbox Medical - Front Entrance', coords = vector4(308.60, -592.30, 46.30, 70.0), panLimit = 45.0, fov = 50.0 },
}

-- ==========================================================================
-- راديو (اختياري)
-- ==========================================================================
Config.RadioResource = ''
Config.RadioOpenCommand = 'radio'

-- ==========================================================================
-- البلاغات التلقائية للإسعاف
-- ==========================================================================
Config.Alerts = {
    Enabled = true,
    -- هالوظائف (وهم على الدوام) ما يطلّعون بلاغات تلقائية
    IgnoreJobs = { 'ambulance', 'police' },

    -- حادث سيارة قوي (السرعة تنزل فجأة = صدمة) → بلاغ "10-50 حادث سير — إصابات محتملة"
    Crash = {
        enabled = true,
        cooldown = 60,        -- ثواني لكل لاعب
        minSpeed = 90,        -- أقل سرعة قبل الصدمة (كم/س)
        minDrop = 60,         -- كم لازم تنزل السرعة فجأة (كم/س) عشان تنحسب صدمة
        minBodyDamage = 60.0, -- أقل ضرر لبودي السيارة (من 1000) بنفس اللحظة
    },

    -- بلب المسعف يومض لما السيارين شغال
    FlashBlipOnSiren = true,
    -- صوت البانيك يسمعه اللي قريبين (بالأمتار، 0 = طافي)
    PanicSoundRadius = 40.0,
}

-- ==========================================================================
-- البروتوكولات الطبية (تطبيق Protocols) — مرجع سريع للمسعفين الجدد
-- ==========================================================================
Config.Protocols = {
    {
        title = 'Unconscious — no pulse (10-69)', icon = 'fa-heart-pulse', level = 'high',
        steps = { 'Secure the scene (call police if armed suspects).', 'Attach the vitals monitor: V-FIB = shock now, ASYSTOLE = keep trying.', 'Use the defibrillator on the patient.', 'Stretcher → load into the ambulance → hospital.' },
        items = { 'defibrillator', 'ems_monitor', 'ems_stretcher' },
    },
    {
        title = 'Bleeding out / last stand (10-47)', icon = 'fa-user-injured', level = 'medium',
        steps = { 'Reach the patient before the timer runs out — bystanders can do CPR to buy time.', 'Adrenaline adds time, a tourniquet stops the bleeding.', 'Use a First Aid kit to get them back up.' },
        items = { 'adrenaline', 'ems_tourniquet', 'firstaid' },
    },
    {
        title = 'Wounds / pain', icon = 'fa-kit-medical', level = 'low',
        steps = { 'Examine the patient (vitals monitor shows every injury on the body map).', 'Gauze / suture kit for wounds, IV saline if they lost a lot of blood.', 'Morphine for strong pain, painkillers or a cold pack for light pain.' },
        items = { 'ems_gauze', 'ems_suture', 'ems_saline', 'ems_morphine', 'bandage' },
    },
    {
        title = 'Fracture / can\'t walk', icon = 'fa-bone', level = 'low',
        steps = { 'Legs or arms injured = limp and no sprint.', 'Apply a SAM splint — the patient can walk again.', 'Wheelchair for the ones who still can\'t stand.' },
        items = { 'ems_splint', 'ems_wheelchair', 'ems_coldpack' },
    },
    {
        title = 'Breathing problems / smoke', icon = 'fa-lungs', level = 'medium',
        steps = { 'Move the patient out of the smoke / water.', 'Oxygen mask (low SpO2 on the monitor).', 'Transport if SpO2 stays under 94%.' },
        items = { 'ems_oxygen', 'ems_monitor' },
    },
    {
        title = 'Traffic collision (10-50)', icon = 'fa-car-burst', level = 'medium',
        steps = { 'Park the ambulance to block traffic, lights on.', 'Triage every occupant with the monitor — RED first.', 'Drop a trauma bag for supplies, request police for traffic control.' },
        items = { 'ems_medbag', 'ems_stretcher', 'ems_splint', 'firstaid' },
    },
    {
        title = 'Mass casualty (MCI)', icon = 'fa-people-group', level = 'high',
        steps = { 'First unit on scene takes Scene command.', 'Triage: RED (critical) → YELLOW → GREEN (monitor triage badge).', 'Dispatcher assigns Transport units; notify the hospital (CODE RED).' },
        items = { 'defibrillator', 'adrenaline', 'ems_tourniquet', 'ems_stretcher' },
    },
}

-- رموز الراديو للإسعاف (تطلع بتطبيق Protocols)
Config.RadioCodes = {
    { code = '10-4', label = 'Copy / understood' },
    { code = '10-8', label = 'Available / in service' },
    { code = '10-6', label = 'Busy' },
    { code = '10-7', label = 'Out of service' },
    { code = '10-97', label = 'Arrived on scene' },
    { code = '10-47', label = 'Injured person' },
    { code = '10-50', label = 'Traffic collision' },
    { code = '10-52', label = 'Ambulance needed' },
    { code = '10-69', label = 'Unconscious / no pulse' },
    { code = '10-99', label = 'Medic in distress (panic)' },
    { code = 'Code 3', label = 'Lights & sirens transport' },
}
