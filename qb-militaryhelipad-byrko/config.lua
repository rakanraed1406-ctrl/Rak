--[[ ==========================================================================
     JINXED TOWN — MILITARY LOGISTICS  (qb-militaryhelipad-byrko 3.1)

     فتح المتجر من أي سكربت (interact / qb-target / زر…):
         TriggerEvent('jt-logistics:open', 'cia')          -- كلاينت
         exports['qb-militaryhelipad-byrko']:Open('cia')    -- أو export
     السيرفر يتحقق من الصلاحية بنفسه، فما يهم من وين ينفتح.

     الإحداثيات تحت أمثلة (Fort Zancudo) — عدلها بـ /logisticscoords (أدمن).
     ========================================================================== ]]

Config = {}

-- ---- عام -------------------------------------------------------------------
Config.DeliveryMinutes = 30          -- مدة التوصيل الافتراضية (كل متجر يقدر يغيرها)
Config.ResetHours = 24               -- كل كم ساعة يترست الستوك وتنضاف الميزانية اليومية
Config.IntroSeconds = 3              -- شريط التحميل لما ينفتح المتجر
Config.IntroEveryOpen = true         -- false = الانترو أول مرة بس كل جلسة
Config.MaxLinesPerOrder = 25         -- أقصى عدد منتجات مختلفة بالطلب الواحد
Config.AdminGroups = { 'god', 'admin' }
Config.DisplayDistance = 120.0       -- المركبات المعروضة والـ NPC تطلع بس لما تكون قريب

-- صور الأغراض من qb-inventory
Config.ItemImages = 'nui://qb-inventory/html/images/'
-- صور المركبات: أولاً الصور اللي يطلعها /logisticsphotos (html/img/vehicles)،
-- بعدين صور FiveM الرسمية للمركبات الأصلية (نفس الزاوية للكل). false = بدونها
Config.VehicleImageFallback = 'https://docs.fivem.net/vehicles/%s.webp'

-- الأسطول (الكراج): المركبة اللي توصل تثبت بمكان العرض وما تختفي أبد.
-- تطلعها بـ qb-target عليها، وترجعها: تقرّبها من بوت الأغراض (itemPed) → "Store the vehicle".
Config.Fleet = {
    DestroyedAreLost = true,   -- true = المركبة اللي تنفجر تروح من الأسطول، false = ترجع للكراج
    KeepInWorld = false,       -- true = المركبة الطالعة تبقى مكانها حتى لو ما أحد قريب منها
                               -- false = لو السيرفر شالها (ما أحد قريب / ريستارت) ترجع للكراج تلقائي
}

Config.FuelResource = 'LegacyFuel'   -- فاضي = نيتف
Config.GiveKeys = function(vehicle, plate)
    TriggerEvent('qb-vehiclekeys:client:AddKeys', plate)
end

-- الأقسام (التبويبات) بالترتيب
Config.Categories = {
    { id = 'armored', label = 'ARMORED' },
    { id = 'helicopters', label = 'HELICOPTERS' },
    { id = 'jets', label = 'JETS' },
    { id = 'weapons', label = 'WEAPONS' },
    { id = 'items', label = 'ITEMS' },
}

--[[ ---- المتاجر -------------------------------------------------------------
  access       مين يفتح المتجر (أي وحدة تتحقق تكفي):
                 jobs = { [وظيفة] = أقل رتبة }, gangs = {...}, citizenids = { ['ABC123'] = true }, onDuty = true/false
  permissions  اختياري: order / deposit / pickup بنفس الشكل (nil = نفس access)
  budget       start = البداية، daily = يضاف كل ResetHours، max = أعلى حد (nil = بدون)
  products     type = 'vehicle' | 'item'
                 vehicle: model, display = vector4 (وين تطلع المركبة المعروضة بعد التوصيل)،
                          spawn = مجموعة من spawnPoints (وين تطلع لما تستخرجها)،
                          vtype = 'heli' | 'plane' | 'automobile' (اختياري — أسرع وأضمن للرسبنة)
                 item:    item = اسم الأيتم في qb-core/shared/items.lua
               stock = الحد كل ResetHours، price = السعر من الميزانية
------------------------------------------------------------------------------ ]]
Config.Shops = {
    cia = {
        enabled = true,
        label = 'CENTRAL INTELLIGENCE AGENCY',
        badge = 'CIA',
        authority = 'MINISTRY OF INTERIOR',
        title = 'MILITARY LOGISTICS',

        access = {
            jobs = { cia = 0 },
            citizenids = { ['3320'] = true, ['136861'] = true, ['07'] = true },
            onDuty = false,
        },
        permissions = {
            order = nil,      -- مثال: { jobs = { cia = 3 } } = الطلب من رتبة 3 وفوق بس
            deposit = nil,
            pickup = nil,
        },

        budget = { start = 0, daily = 500000, max = 50000000 },
        deposit = { min = 1000, max = 10000000, from = { 'cash', 'bank' } },
        deliveryMinutes = 30,
        platePrefix = 'CIA',

        -- اختياري: لازم يكون قريب من هالنقطة عشان يطلب / يودع (nil = من أي مكان)
        terminal = nil, -- { coords = vector3(-2035.03, 3116.78, 32.81), distance = 15.0 },

        -- اختياري: بوت يفتح المتجر بـ qb-target (nil = بس بالـ event)
        openPed = { model = 's_m_y_pilot_01', coords = vector4(-2035.03, 3116.78, 32.81, 120.52), label = 'Military Logistics' },

        -- ضابط الإمداد (qb-target): تستلم منه الأسلحة والأغراض، و تخزن عنده المركبات
        itemPed = { model = 's_m_y_marine_01', coords = vector4(-2031.20, 3121.90, 32.81, 150.0), label = 'Receive supplies', storeLabel = 'Store the vehicle' },
        storeRadius = 30.0, -- المركبة لازم تكون ضمن هالمسافة من الضابط عشان تتخزن

        -- وين تطلع المركبات لما تستخرجها (تقدر تحط أكثر من مكان لكل مجموعة)
        spawnPoints = {
            air = {
                vector4(-2058.95, 3093.08, 33.82, 329.69),
                vector4(-2043.92, 3118.99, 32.81, 328.11),
                vector4(-2076.45, 3062.62, 32.81, 327.02),
            },
            ground = { -- غرب المهابط، بعيد عن صفوف العرض
                vector4(-2102.40, 3077.60, 32.81, 330.0),
                vector4(-2088.40, 3101.90, 32.81, 330.0),
                vector4(-2074.40, 3126.10, 32.81, 330.0),
                vector4(-2060.40, 3150.40, 32.81, 330.0),
            },
        },

        products = {
            -- ARMORED
            { id = 'rhino', type = 'vehicle', model = 'rhino', label = 'Rhino Tank', desc = 'Main Battle Tank', category = 'armored', price = 4000000, stock = 4, spawn = 'ground', display = vector4(-2041.80, 3042.60, 32.81, 60.0) },
            { id = 'halftrack', type = 'vehicle', model = 'halftrack', label = 'Half-track', desc = 'Armored Half-track', category = 'armored', price = 500000, stock = 5, spawn = 'ground', display = vector4(-2027.80, 3066.85, 32.81, 60.0) },
            { id = 'apc', type = 'vehicle', model = 'apc', label = 'APC', desc = 'Amphibious Personnel Carrier', category = 'armored', price = 1000000, stock = 5, spawn = 'ground', display = vector4(-2013.80, 3091.10, 32.81, 60.0) },
            { id = 'insurgent', type = 'vehicle', model = 'insurgent', label = 'Insurgent', desc = 'Armored SUV', category = 'armored', price = 850000, stock = 5, spawn = 'ground', display = vector4(-1999.80, 3115.35, 32.81, 60.0) },
            { id = 'insurgent2', type = 'vehicle', model = 'insurgent2', label = 'Insurgent Pick-Up', desc = 'Armed Insurgent Variant', category = 'armored', price = 200000, stock = 10, spawn = 'ground', display = vector4(-1985.80, 3139.60, 32.81, 60.0) },
            { id = 'minitank', type = 'vehicle', model = 'minitank', label = 'Invade & Persuade', desc = 'RC-style Mini Tank', category = 'armored', price = 500000, stock = 3, spawn = 'ground', display = vector4(-1971.80, 3163.85, 32.81, 60.0) },

            -- HELICOPTERS
            { id = 'hunter', type = 'vehicle', model = 'hunter', vtype = 'heli', label = 'FH-1 Hunter', desc = 'Attack Helicopter', category = 'helicopters', price = 1000000, stock = 5, spawn = 'air', display = vector4(-2015.80, 3027.60, 32.81, 60.0) },
            { id = 'akula', type = 'vehicle', model = 'akula', vtype = 'heli', label = 'Akula', desc = 'Stealth Attack Helicopter', category = 'helicopters', price = 500000, stock = 10, spawn = 'air', display = vector4(-2001.80, 3051.85, 32.81, 60.0) },
            { id = 'valkyrie', type = 'vehicle', model = 'valkyrie', vtype = 'heli', label = 'Valkyrie', desc = 'Armed Transport Helicopter', category = 'helicopters', price = 500000, stock = 5, spawn = 'air', display = vector4(-1987.80, 3076.10, 32.81, 60.0) },
            { id = 'savage', type = 'vehicle', model = 'savage', vtype = 'heli', label = 'Savage', desc = 'Heavy Attack Helicopter', category = 'helicopters', price = 1200000, stock = 5, spawn = 'air', display = vector4(-1973.80, 3100.35, 32.81, 60.0) },
            { id = 'mh60l', type = 'vehicle', model = 'mh60l', label = 'MH-60L', desc = 'Utility Helicopter', category = 'helicopters', price = 150000, stock = 5, spawn = 'air', display = vector4(-1959.80, 3124.60, 32.81, 60.0) },
            { id = 'swat_heli', type = 'vehicle', model = 'swat_heli', label = 'SWAT Helicopter', desc = 'Tactical Transport', category = 'helicopters', price = 55000, stock = 5, spawn = 'air', display = vector4(-1945.80, 3148.85, 32.81, 60.0) },
            { id = 'csk131', type = 'vehicle', model = 'csk131', label = 'CSK-131', desc = 'Special Operations', category = 'helicopters', price = 500000, stock = 3, spawn = 'air', display = vector4(-1931.80, 3173.10, 32.81, 60.0) },

            -- JETS
            { id = 'lazer', type = 'vehicle', model = 'lazer', vtype = 'plane', label = 'P-996 LAZER', desc = 'Military Fighter Jet', category = 'jets', price = 3000000, stock = 3, spawn = 'air', display = vector4(-1989.80, 3012.60, 32.81, 60.0) },
            { id = 'hydra', type = 'vehicle', model = 'hydra', vtype = 'plane', label = 'Hydra', desc = 'VTOL Fighter Jet', category = 'jets', price = 3000000, stock = 3, spawn = 'air', display = vector4(-1975.80, 3036.85, 32.81, 60.0) },
            { id = 'strikeforce', type = 'vehicle', model = 'strikeforce', vtype = 'plane', label = 'B-11 Strikeforce', desc = 'Ground Attack Aircraft', category = 'jets', price = 1500000, stock = 3, spawn = 'air', display = vector4(-1961.80, 3061.10, 32.81, 60.0) },
            { id = 'raiju', type = 'vehicle', model = 'raiju', vtype = 'plane', label = 'F-160 Raiju', desc = 'Stealth VTOL', category = 'jets', price = 2500000, stock = 2, spawn = 'air', display = vector4(-1947.80, 3085.35, 32.81, 60.0) },

            -- WEAPONS (من qb-inventory)
            { id = 'carbine', type = 'item', item = 'weapon_carbinerifle', label = 'Carbine Rifle', desc = 'Service Rifle', category = 'weapons', price = 25000, stock = 30 },
            { id = 'combatmg', type = 'item', item = 'weapon_combatmg', label = 'Combat MG', desc = 'Heavy Machine Gun', category = 'weapons', price = 75000, stock = 20 },
            { id = 'stickybomb', type = 'item', item = 'weapon_stickybomb', label = 'Sticky Bomb', desc = 'Remote Detonation Explosive', category = 'weapons', price = 50000, stock = 50 },

            -- ITEMS
            { id = 'heavyarmor', type = 'item', item = 'heavyarmor', label = 'Heavy Armor', desc = 'Ballistic Vest', category = 'items', price = 2500, stock = 100 },
            { id = 'rifle_ammo', type = 'item', item = 'rifle_ammo', label = 'Rifle Ammo', desc = 'Ammunition Box', category = 'items', price = 500, stock = 200 },
            { id = 'radio', type = 'item', item = 'radio', label = 'Radio', desc = 'Secure Comms', category = 'items', price = 1000, stock = 50 },
        },
    },

    -- مثال ثاني — عدل الإحداثيات بعدين خله enabled = true
    lspd = {
        enabled = false,
        label = 'LOS SANTOS POLICE DEPARTMENT',
        badge = 'LSPD',
        authority = 'MINISTRY OF INTERIOR',
        title = 'POLICE LOGISTICS',
        access = { jobs = { police = 0 }, onDuty = true },
        permissions = { order = { jobs = { police = 3 } } }, -- الطلب من رتبة 3، الباقي لكل الشرطة
        budget = { start = 100000, daily = 250000, max = 20000000 },
        deposit = { min = 1000, max = 5000000, from = { 'cash', 'bank' } },
        deliveryMinutes = 30,
        platePrefix = 'LSPD',
        terminal = { coords = vector3(441.10, -978.90, 30.69), distance = 20.0 },
        openPed = nil,
        itemPed = { model = 's_m_y_cop_01', coords = vector4(458.90, -1017.10, 28.40, 90.0), label = 'Receive supplies', storeLabel = 'Store the vehicle' },
        storeRadius = 25.0,
        spawnPoints = {
            air = { vector4(449.20, -981.30, 43.69, 90.0) },
            ground = { vector4(445.40, -1025.60, 28.40, 5.0), vector4(441.70, -1025.90, 28.40, 5.0) },
        },
        products = {
            { id = 'riot', type = 'vehicle', model = 'riot', label = 'Riot Van', desc = 'Armored Response', category = 'armored', price = 300000, stock = 3, spawn = 'ground', display = vector4(452.10, -1021.70, 28.30, 90.0) },
            { id = 'polmav', type = 'vehicle', model = 'polmav', vtype = 'heli', label = 'Police Maverick', desc = 'Air Support', category = 'helicopters', price = 400000, stock = 2, spawn = 'air', display = vector4(463.70, -1014.40, 28.10, 90.0) },
            { id = 'pistol', type = 'item', item = 'weapon_pistol', label = 'Pistol', desc = 'Sidearm', category = 'weapons', price = 5000, stock = 40 },
            { id = 'armor', type = 'item', item = 'armor', label = 'Armor', desc = 'Light Vest', category = 'items', price = 1500, stock = 100 },
        },
    },
}

-- رسائل
Config.Lang = {
    no_access = 'ما عندك صلاحية لهالمتجر',
    no_permission = 'ما عندك صلاحية',
    too_far = 'لازم تكون قريب',
    order_placed = 'تم الطلب #%s — يوصل خلال %s دقيقة',
    order_arrived = 'وصل الطلب #%s (%s) — استلمه من المستودع',
    not_enough_budget = 'الميزانية ما تكفي',
    out_of_stock = '%s: الكمية المتاحة %s بس',
    cart_empty = 'السلة فاضية',
    deposit_done = 'أودعت $%s في ميزانية %s',
    not_enough_money = 'ما عندك فلوس كافية',
    bad_amount = 'المبلغ غلط (من $%s إلى $%s)',
    budget_full = 'الميزانية وصلت الحد الأعلى',
    nothing_here = 'ما فيه شي للاستلام',
    vehicles_out = 'طلعت %s × %s — المفاتيح معك',
    pads_busy = 'كل أماكن الرسبنة مشغولة',
    items_received = 'استلمت %s',
    inventory_full = 'شنطتك ما تتسع لكل شي — الباقي بالمستودع',
    stored = 'خزنت %s مركبة بالكراج',
    nothing_to_store = 'ما فيه مركبات للأسطول قريبة من الضابط',
    wrecked = 'المركبة مدمرة — ما تنخزن',
    recalled = 'رجعت %s مركبة للكراج',
    photos_start = 'جاري تصوير %s مركبة… لا تتحرك',
    photos_done = 'خلص التصوير: %s صورة. سو ريستارت للسكربت عشان توصل الصور للاعبين',
    photos_missing = 'تحتاج screenshot-basic عشان التصوير',
}
