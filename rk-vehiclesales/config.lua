Config = {}

-- ==========================================================================
-- عام
-- ==========================================================================
-- الفلوس تنسحب من وين: 'bank' أو 'cash'
Config.MoneyType = 'bank'

-- الكراج اللي تنسجل فيه السيارة بقاعدة البيانات (نفس اسم الكراج في qb-garages)
Config.DefaultGarage = 'pillboxgarage'

-- اللاعب ينحط داخل السيارة بعد الشراء / الفوز بالمزاد
Config.WarpIntoVehicle = true

-- سكربت البنزين (فاضي = يستخدم نيتف اللعبة). أمثلة: 'LegacyFuel', 'cdn-fuel', 'ps-fuel'
Config.FuelResource = 'LegacyFuel'

-- إعطاء المفتاح (يشتغل بالكلاينت). غيّره لو تستخدم سكربت مفاتيح ثاني.
Config.GiveKeys = function(vehicle, plate)
    TriggerEvent('vehiclekeys:client:SetOwner', plate)
end

-- رتب الأدمن اللي تقدر تسوي مزاد / تعيد الستوك (QBCore permissions)
Config.AdminGroups = { 'god', 'admin' }

-- ==========================================================================
-- المتاجر (نظام الستوك)
-- ==========================================================================
-- كل ما السيرفر يرستارت (أو أدمن يكتب /restockcars) كل مكان يختار سيارة
-- عشوائية من قائمة النوع حقه. لما أحد يشتريها تختفي من مكانها وتبقى فاضية
-- لين الريستارت الجاي.
--
-- كل نوع (category) له:
--   label    = اسمه
--   spots    = أماكن الرسبون (vector4). تقدر تحط مكان واحد أو أكثر
--   vehicles = السيارات اللي ممكن تطلع + سعر كل وحدة
--
-- tip: اكتب /vscoords وأنت أدمن عشان تطلع لك إحداثياتك جاهزة (F8).
-- ==========================================================================
Config.Stores = {
    ['sandy_motors'] = {
        label = 'Sandy Motors',
        blip = { enabled = true, coords = vector3(1224.5, 2712.0, 38.0), sprite = 326, color = 3, scale = 0.75 },

        -- وين تطلع السيارة بعد الشراء
        deliverySpawn = vector4(1213.31, 2735.4, 38.27, 182.5),

        categories = {
            offroad = {
                label = 'Offroad',
                spots = {
                    vector4(1237.07, 2699.00, 38.27, 1.5),
                },
                vehicles = {
                    { model = 'sandking', price = 55000 },
                    { model = 'rebel2',   price = 32000 },
                    { model = 'bfinjection', price = 18000 },
                    { model = 'mesa3',    price = 60000 },
                    { model = 'kamacho',  price = 95000 },
                },
            },
            sedan = {
                label = 'Sedan',
                spots = {
                    vector4(1232.98, 2698.92, 38.27, 2.5),
                },
                vehicles = {
                    { model = 'tailgater', price = 38000 },
                    { model = 'schafter2', price = 45000 },
                    { model = 'fugitive',  price = 24000 },
                    { model = 'premier',   price = 14000 },
                    { model = 'washington', price = 20000 },
                },
            },
            motorcycle = {
                label = 'Motorcycle',
                spots = {
                    vector4(1228.90, 2698.78, 38.27, 3.5),
                },
                vehicles = {
                    { model = 'bati',     price = 28000 },
                    { model = 'akuma',    price = 22000 },
                    { model = 'sanchez',  price = 9000 },
                    { model = 'pcj',      price = 12000 },
                    { model = 'hakuchou', price = 40000 },
                },
            },
            -- تبي نوع زيادة؟ انسخ واحد من فوق وغيّر اسمه وأماكنه وسياراته.
            -- sports = { label = 'Sports', spots = { vector4(...) }, vehicles = { { model = 'elegy2', price = 90000 } } },
        },
    },
}

-- كم متر لازم يكون اللاعب قريب عشان يشتري (حماية من السيرفر)
Config.BuyDistance = 8.0
-- مسافة ظهور سيارات العرض (تنرسم بس للاعبين القريبين)
Config.DisplayDistance = 90.0
-- نص فوق السيارة فيه السعر
Config.Show3DText = true
-- تجديد الستوك تلقائي كل كم دقيقة (0 = بس مع الريستارت أو /restockcars)
Config.RestockEveryMinutes = 0

-- ==========================================================================
-- المزادات
-- ==========================================================================
Config.Auction = {
    -- الأيتم اللي يوصل لكل مشارك. استخدامه = زيادة (bid).
    -- لازم تضيفه في items (شوف README).
    BidItem = 'auction_paddle',

    MinParticipants = 3,        -- أقل عدد لازم يقبلون عشان يبدأ
    Radius = 15.0,              -- النطاق المخفي (متر)
    MinStartPrice = 5000,       -- أقل سعر بداية
    MinIncrement = 100,         -- أقل زيادة يقدر الأدمن يحطها
    Duration = 5 * 60,          -- مدة المزاد (ثواني)
    SoldAfter = 10,             -- لو محد زاد خلال هالثواني → آخر واحد زاد يفوز
    InviteTimeout = 30,         -- كم ثانية تبقى نافذة الدعوة
    LobbyTimeout = 5 * 60,      -- لو ما اكتمل العدد خلال هالمدة ينلغي المزاد
    AutoStart = true,           -- يبدأ لحاله أول ما يقبل العدد المطلوب
    StartCountdown = 5,         -- عداد قبل البداية (ثواني)
    RequireSharedVehicle = true, -- الموديل لازم يكون موجود في qb-core/shared/vehicles.lua

    -- أماكن المزاد (الأدمن يختار منها وقت ما يسوي المزاد)
    Locations = {
        {
            label = 'Legion Square',
            center = vector3(195.2, -933.8, 30.7),           -- مركز النطاق
            vehicleSpawn = vector4(190.9, -948.5, 30.1, 145.0), -- السيارة المعروضة
            deliverySpawn = vector4(225.7, -792.3, 30.7, 250.0), -- وين يستلم الفايز السيارة
        },
        {
            label = 'Sandy Shores Airfield',
            center = vector3(1720.5, 3274.0, 41.1),
            vehicleSpawn = vector4(1716.0, 3269.0, 41.1, 105.0),
            deliverySpawn = vector4(1702.0, 3255.0, 41.0, 105.0),
        },
    },
}

-- ==========================================================================
-- النصوص
-- ==========================================================================
Config.Lang = {
    buy_target = 'شراء %s — $%s',
    not_enough_money = 'ما عندك فلوس كافية ($%s)',
    bought = 'اشتريت %s بـ $%s — المفتاح معك',
    already_sold = 'هالسيارة انباعت',
    too_far = 'قرّب من السيارة',
    restocked = 'تجدد ستوك المعارض',
    no_permission = 'ما عندك صلاحية',
    auction_busy = 'فيه مزاد شغال الحين',
    auction_created = 'تم إنشاء المزاد — ينتظر %s مشاركين داخل النطاق',
    auction_ready = 'اكتمل العدد — المزاد يبدأ بعد %s ثواني',
    auction_started = 'بدأ المزاد! استخدم الأيتم عشان تزيد',
    auction_cancelled = 'انلغى المزاد',
    auction_lobby_timeout = 'انلغى المزاد: ما اكتمل عدد المشاركين',
    auction_no_bids = 'انتهى المزاد بدون أي زيادة',
    auction_won = 'مبروك! فزت بـ %s بـ $%s — المفتاح معك',
    auction_winner_all = '%s فاز بـ %s بـ $%s',
    auction_not_participant = 'أنت مو مشارك في المزاد',
    auction_out_of_range = 'لازم تكون داخل نطاق المزاد عشان تزيد',
    auction_already_top = 'أنت أعلى مزايد حاليًا',
    auction_cant_afford = 'ما تقدر: ما عندك $%s',
    auction_bid_placed = 'زايدت: $%s',
    auction_not_running = 'ما فيه مزاد شغال',
    auction_joined = 'انضميت للمزاد — انتظر البداية',
    auction_bad_model = 'الموديل غلط أو مو موجود في shared/vehicles',
    auction_bad_price = 'أقل سعر بداية $%s',
    auction_bad_increment = 'أقل زيادة $%s',
    auction_missing_item = 'الأيتم %s مو موجود في items — ضيفه أول',
}
