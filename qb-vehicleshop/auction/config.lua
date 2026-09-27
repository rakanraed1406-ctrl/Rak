-- ==========================================================================
-- نظام المزادات (مضاف على qb-vehicleshop) — كل إعداداته هنا
-- ==========================================================================
Config.Auction = {
    -- ---- عام ----
    MoneyType = 'bank',               -- الفلوس تنسحب من: 'bank' أو 'cash'
    DefaultGarage = 'pillboxgarage',  -- الكراج اللي تنسجل فيه السيارة
    WarpIntoVehicle = true,           -- الفايز ينحط داخل السيارة
    FuelResource = 'LegacyFuel',      -- سكربت البنزين (فاضي = نيتف)
    AdminGroups = { 'god', 'admin' }, -- مين يقدر يسوي مزاد
    DisplayDistance = 90.0,           -- مسافة ظهور السيارة المعروضة
    -- إعطاء المفتاح (كلاينت)
    GiveKeys = function(vehicle, plate)
        TriggerEvent('vehiclekeys:client:SetOwner', plate)
    end,

    -- ---- المزاد ----
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

Config.AuctionLang = {
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
