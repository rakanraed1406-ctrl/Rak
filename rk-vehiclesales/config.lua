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

-- رتب الأدمن اللي تقدر تعيد الستوك (QBCore permissions)
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
}
