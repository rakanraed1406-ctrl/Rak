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
-- ربط الديسباتش — sk1-hub بس (الملفات اللي أرسلتها)، ما نستخدم أي سكربت
-- ديسباتش ثاني إطلاقًا.
-- ==========================================================================
Config.DispatchResource = 'sk1-hub'

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

-- كولداون بين كل رسمة/دبوس على الخريطة من نفس الضابط (مللي ثانية)
Config.MapMarkerCooldownMs = 1000
