-- ==========================================================================
-- المعرض بنظام الستوك (بدل المعرض القديم — شوف Config.OldShowroom في config.lua)
-- ==========================================================================
-- كل ريستارت (أو /restockcars) كل مكان يختار سيارة عشوائية من قائمة نوعه.
-- تنشرى بـ qb-target (شراء بس، بدون تجربة) → تختفي من مكانها لين الريستارت الجاي.
-- tip: /vscoords وأنت أدمن يطبع لك إحداثياتك vector4 بالـ F8.
-- ==========================================================================
Config.Stock = {
    MoneyType = 'bank',               -- 'bank' أو 'cash'
    DefaultGarage = 'pillboxgarage',  -- الكراج اللي تنسجل فيه السيارة
    WarpIntoVehicle = true,           -- ينحط اللاعب داخل السيارة بعد الشراء
    FuelResource = 'LegacyFuel',      -- سكربت البنزين (فاضي = نيتف)
    AdminGroups = { 'god', 'admin' }, -- مين يقدر /restockcars و /vscoords
    BuyDistance = 8.0,                -- لازم يكون قريب من السيارة (حماية سيرفر)
    DisplayDistance = 90.0,           -- مسافة ظهور سيارات العرض
    Show3DText = true,                -- السعر فوق السيارة
    RestockEveryMinutes = 0,          -- تجديد تلقائي كل كم دقيقة (0 = مع الريستارت بس)
    GiveKeys = function(vehicle, plate)
        TriggerEvent('vehiclekeys:client:SetOwner', plate)
    end,

    -- المتاجر: لكل نوع مكان رسبون (أو أكثر) + السيارات وأسعارها
    Stores = {
        ['pdm'] = {
            label = 'Premium Deluxe Motorsport',
            blip = { enabled = true, coords = vector3(-45.67, -1098.34, 26.42), sprite = 326, color = 3, scale = 0.7 },
            deliverySpawn = vector4(-56.79, -1109.85, 26.43, 71.5), -- وين تطلع السيارة بعد الشراء

            categories = {
                offroad = {
                    label = 'Offroad',
                    spots = { vector4(-45.65, -1093.66, 25.44, 69.5) },
                    vehicles = {
                        { model = 'sandking', price = 55000 },
                        { model = 'rebel2', price = 32000 },
                        { model = 'mesa3', price = 60000 },
                        { model = 'kamacho', price = 95000 },
                    },
                },
                sedan = {
                    label = 'Sedan',
                    spots = { vector4(-48.27, -1101.86, 25.44, 294.5), vector4(-40.18, -1104.13, 25.44, 338.5) },
                    vehicles = {
                        { model = 'schafter2', price = 45000 },
                        { model = 'tailgater', price = 38000 },
                        { model = 'fugitive', price = 24000 },
                        { model = 'premier', price = 14000 },
                        { model = 'washington', price = 20000 },
                    },
                },
                sports = {
                    label = 'Sports',
                    spots = { vector4(-39.6, -1096.01, 25.44, 66.5) },
                    vehicles = {
                        { model = 'coquette', price = 90000 },
                        { model = 'elegy2', price = 95000 },
                        { model = 'jester', price = 120000 },
                    },
                },
                muscle = {
                    label = 'Muscle',
                    spots = { vector4(-51.21, -1096.77, 25.44, 254.5) },
                    vehicles = {
                        { model = 'vigero', price = 30000 },
                        { model = 'dominator', price = 45000 },
                        { model = 'gauntlet', price = 42000 },
                    },
                },
                motorcycle = {
                    label = 'Motorcycle',
                    spots = {
                        vector4(-43.31, -1099.02, 25.44, 52.5),
                        vector4(-50.66, -1093.05, 25.44, 222.5),
                        vector4(-44.28, -1102.47, 25.44, 298.5),
                    },
                    vehicles = {
                        { model = 'bati', price = 28000 },
                        { model = 'akuma', price = 22000 },
                        { model = 'sanchez', price = 9000 },
                        { model = 'pcj', price = 12000 },
                        { model = 'hakuchou', price = 40000 },
                    },
                },
            },
        },
    },
}

Config.StockLang = {
    buy_target = 'شراء %s — $%s',
    not_enough_money = 'ما عندك فلوس كافية ($%s)',
    bought = 'اشتريت %s بـ $%s — المفتاح معك',
    already_sold = 'هالسيارة انباعت',
    too_far = 'قرّب من السيارة',
    restocked = 'تجدد ستوك المعارض',
    no_permission = 'ما عندك صلاحية',
}
