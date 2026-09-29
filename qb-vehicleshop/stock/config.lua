-- ==========================================================================
-- المعرض بنظام الستوك (بدل المعرض القديم — شوف Config.OldShowroom في config.lua)
-- ==========================================================================
-- كل ريستارت (أو /restockcars) كل مكان يختار سيارة عشوائية من قائمة نوعه.
-- لما تقرب من سيارة تطلع بطاقة فوق يمين (السعر، فلوسك، الأداء): E شراء · G تجربة.
-- تنشرى (أو بـ qb-target) → تختفي من مكانها لين الريستارت الجاي.
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
    Show3DText = false,               -- النص القديم فوق السيارة (البطاقة فوق يمين بدله)
    RestockEveryMinutes = 0,          -- تجديد تلقائي كل كم دقيقة (0 = مع الريستارت بس)

    -- البطاقة فوق يمين لما تقرب من سيارة
    Card = {
        Enabled = true,
        Distance = 4.5,          -- كم متر من السيارة عشان تطلع البطاقة
        SpeedUnit = 'kmh',       -- 'kmh' أو 'mph'
        KeyBuy = 38,             -- E
        KeyTestDrive = 47,       -- G
        -- أعلى قيمة لكل شريط (الشريط يتعبى بالنسبة لها)
        StatMax = { speed = 250, acceleration = 0.55, braking = 1.6, handling = 3.0 },
    },

    -- تجربة السيارة (زر G)
    TestDrive = {
        Enabled = true,
        Price = 1000,            -- سعر التجربة (0 = مجانية)
        MoneyType = 'cash',      -- 'cash' أو 'bank' — لو ما يكفي يسحب من الثاني
        Seconds = 60,            -- مدة التجربة
        LeaveSeconds = 3,        -- لو نزل من السيارة كذا ثانية تخلص التجربة
    },

    -- أداء السيارات: السكربت يقيسها لحاله من اللعبة.
    -- تبي تحدد رقم بنفسك؟ حطه هنا (أو داخل السيارة نفسها تحت: { model = 'x', price = 1, speed = 180 })
    -- speed بنفس الوحدة اللي فوق (kmh / mph)
    VehicleStats = {
        -- ['kamacho'] = { speed = 165, acceleration = 0.32, braking = 1.1, handling = 2.2 },
    },

    GiveKeys = function(vehicle, plate)
        TriggerEvent('vehiclekeys:client:SetOwner', plate)
    end,

    -- المتاجر: لكل نوع مكان رسبون (أو أكثر) + السيارات وأسعارها
    Stores = {
        ['pdm'] = {
            label = 'Premium Deluxe Motorsport',
            blip = { enabled = true, coords = vector3(-45.67, -1098.34, 26.42), sprite = 326, color = 3, scale = 0.7 },
            deliverySpawn = vector4(-56.79, -1109.85, 26.43, 71.5), -- وين تطلع السيارة بعد الشراء
            testDriveSpawn = vector4(-56.79, -1109.85, 26.43, 71.5), -- وين تطلع سيارة التجربة (فاضي = deliverySpawn)

            categories = {
                offroad = {
                    label = 'Offroad',
                    spots = { vector4(-45.65, -1093.66, 25.44, 69.5) },
                    vehicles = {
                        { model = 'draugur', price = 67000 },
                        { model = 'kamacho', price = 44000 },
                        { model = 'mesa3', price = 60000 },
                        { model = 'dubsta3', price = 95000 },
                    },
                },
                sedan = {
                    label = 'Sedan',
                    spots = { vector4(-48.27, -1101.86, 25.44, 294.5), vector4(-40.18, -1104.13, 25.44, 338.5) },
                    vehicles = {
                        { model = 'stafford', price = 50000 },
                        { model = 'rhinehart', price = 65000 },
                        { model = 'deity', price = 99000 },
                        { model = 'astron', price = 75000 },
                        { model = 'rocoto', price = 85000 },
                    },
                },
                sports = {
                    label = 'Sports',
                    spots = { vector4(-39.6, -1096.01, 25.44, 66.5) },
                    vehicles = {
                        { model = 'growler', price = 90000 },
                        { model = 'jester', price = 83000 },
                        { model = 'imorgon', price = 120000 },
                    },
                },
                muscle = {
                    label = 'Muscle',
                    spots = { vector4(-51.21, -1096.77, 25.44, 254.5) },
                    vehicles = {
                        { model = 'blade', price = 45000 },
                        { model = 'hermes', price = 60000 },
                        { model = 'buccaneer2', price = 55000 },
                    },
                },
                motorcycle = {
                    label = 'Motorcycle',
                    spots = {
                        vector4(-34.75, -1099.12, 26.42, 98.34),
                        vector4(-50.66, -1093.05, 25.44, 222.5),
                        vector4(-44.28, -1102.47, 25.44, 298.5),
                    },
                    vehicles = {
                        { model = 'shinobi', price = 50000 },
                        { model = 'akuma', price = 22000 },
                        { model = 'double', price = 67000 },
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
    testdrive_target = 'تجربة — $%s',
    testdrive_started = 'بدأت التجربة — عندك %s ثانية',
    testdrive_ended = 'خلصت التجربة',
    testdrive_left = 'نزلت من السيارة — خلصت التجربة',
    testdrive_money = 'ما عندك فلوس للتجربة ($%s)',
    testdrive_busy = 'أنت في تجربة الحين',
    testdrive_off = 'التجربة مقفلة',
    testdrive_failed = 'ما قدرنا نطلع السيارة — رجعنا لك فلوسك',
    insufficient = 'ما عندك فلوس كافية',
}
