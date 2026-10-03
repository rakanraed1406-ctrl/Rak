--[[ ==========================================================================
     JINXED TOWN — MILITARY LOGISTICS  (JT-MilitaryArmory 3.6)

     الإيفنتات (كلاينت) — اسم الإيفنت لحاله يكفي (يفتح أقرب متجر):
         jt-logistics:open        فتح المتجر
         jt-logistics:supplies    استلام الأغراض (عند الضابط)
         jt-logistics:store       تخزين المركبات (عند الضابط)
     متجر معين: TriggerEvent('jt-logistics:open', 'cia') أو exports['JT-MilitaryArmory']:Open('cia')
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

-- الأسطول (الكراج): مركبة العرض تطلع بمكانها بس لما يكون فيه وحدة بالكراج.
-- تطلعها بـ qb-target عليها (لو طلعت آخر وحدة يختفي العرض)، وترجعها: تقرّبها من بوت الأغراض
-- (itemPed) → "Store the vehicle" → ترجع للكراج ويرجع العرض.
Config.Fleet = {
    DestroyedAreLost = true,   -- true = المركبة اللي تنفجر تروح من الأسطول، false = ترجع للكراج
    StoreAnyOfModel = true,    -- true = أي مركبة من موديلات المتجر (اللي تنشرى) قريبة من الضابط تنخزن وتنضاف للكراج،
                               --        حتى لو ما طلعت من الكراج (السيارات الشخصية المملوكة ما تنخزن)
                               -- false = بس المركبات اللي طلعت من الكراج
    KeepInWorld = false,       -- true = المركبة الطالعة تبقى مكانها حتى لو ما أحد قريب منها
                               -- false = لو السيرفر شالها (ما أحد قريب / ريستارت) ترجع للكراج تلقائي
}

-- تصوير المركبات (/logisticsphotos): نفس الزاوية والإضاءة لكل المركبات
-- عدّل وصوّر مرة ثانية: /logisticsphotos (الكل) أو /logisticsphotos lazer (وحدة)
Config.Photo = {
    yaw = 35.0,    -- الزاوية من قدّام المركبة: موجب = جهتها اليسار، سالب = اليمين، 0 = من قدّام
    pitch = 12.0,  -- ارتفاع الكاميرا (درجات)
    fov = 28.0,    -- العدسة (أقل = تشويه أقل)
    hour = 12,     -- وقت التصوير
    sun = 180.0,   -- وين الشمس بهالوقت (180 = جنوب): المركبة تنلف عشان الشمس تكون ورا الكاميرا
    fill = 1.0,    -- إضاءة الاستوديو من جهة الكاميرا (0 = بدون، 2 = أقوى)
    brightness = 0.42, -- سطوع المركبة بالصورة (يتضبط تلقائي لكل مركبة؛ أعلى = أفتح، 0 = بدون)
    sharpen = 0.35,    -- حدّة (0 = بدون)
    width = 1024,      -- مقاس الصورة (1024×576)
}

Config.FuelResource = 'LegacyFuel'   -- فاضي = نيتف
-- المفاتيح تنعطى من السيرفر: qb-vehiclekeys يعرف إنها لك → القفل (L) والموتر يشتغلون
-- وما يحسبها "غش" بالـ anti-cheat حقه. (تتشغل بالسيرفر بس)
Config.Keys = {
    give = function(source, plate)
        exports['qb-vehiclekeys']:GiveKeys(source, plate)
    end,
    remove = function(source, plate) -- لما المركبة تنخزن / ترجع للكراج
        exports['qb-vehiclekeys']:RemoveKeys(source, plate)
    end,
}
-- سكربت مفاتيح يشتغل من الكلاينت بس؟ حطه هنا (يتشغل عند اللي طلّع المركبة)
Config.GiveKeys = nil -- function(vehicle, plate) TriggerEvent('qb-vehiclekeys:client:AddKeys', plate) end

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
                          vtype = 'automobile' | 'heli' | 'plane' | 'boat' | 'bike' — نوع المركبة (مهم)
                            السيرفر نفسه يرسبنها بهالنوع، فتطلع حتى المركبات المحظورة بالبلاك ليست
                            (rhino / lazer / hydra …) واللاعبين ما يقدرون يرسبنونها بأنفسهم.
                            لو نسيته: الهليكوبترات heli، الطائرات plane، الباقي automobile.
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

        budget = { start = 0, daily = 500000, max = 500000000000 },
        deposit = { min = 1000, max = 100000000000, from = { 'cash', 'bank' } },
        deliveryMinutes = 1,
        platePrefix = 'CIA',

        -- اختياري: لازم يكون قريب من هالنقطة عشان يطلب / يودع (nil = من أي مكان)
        terminal = nil, -- { coords = vector3(-2035.03, 3116.78, 32.81), distance = 15.0 },

        -- اختياري: بوت يفتح المتجر بـ qb-target (nil = بس بالـ event)
        openPed = { model = 's_m_y_pilot_01', coords = vector4(-2035.03, 3116.78, 1.81, 120.52), label = 'Military Logistics' },

        -- ضابط الإمداد (qb-target): تستلم منه الأسلحة والأغراض، و تخزن عنده المركبات
        itemPed = { model = 's_m_y_marine_01', coords = vector4(-2136.72, 3230.18, 32.81, 103.45), label = 'Receive supplies', storeLabel = 'Store the vehicle' },
        storeRadius = 30.0, -- المركبة لازم تكون ضمن هالمسافة من الضابط عشان تتخزن

        -- وين تطلع المركبات لما تستخرجها (تقدر تحط أكثر من مكان لكل مجموعة)
        spawnPoints = {
            air = {
                vector4(-2151.25, 3233.79, 32.51, 150.64),
                vector4(-2043.92, 3118.99, 32.81, 328.11),
                vector4(-2165.22, 3209.97, 32.51, 148.19),
                vector4(-2188.11, 3193.06, 32.51, 105.77),
                vector4(-2166.84, 3178.75, 32.51, 197.8),
            },
            ground = { -- غرب المهابط، بعيد عن صفوف العرض
                vector4(-2129.26, 3200.22, 32.51, 61.29),
                vector4(-2106.5, 3186.58, 32.5, 59.49),
                vector4(-2187.14, 3232.96, 32.51, 238.44),
                vector4(-2199.48, 3239.76, 32.51, 244.48),
            },
        },

        products = {
            -- ARMORED
            { id = 'rhino', type = 'vehicle', vtype = 'automobile', model = 'rhino', label = 'Rhino Tank', desc = 'Main Battle Tank', category = 'armored', price = 4000000, stock = 4, spawn = 'ground', display = vector4(-2102.77, 3264.4, 32.77, 111.29) },
            { id = 'apc', type = 'vehicle', vtype = 'automobile', model = 'apc', label = 'APC', desc = 'Amphibious Personnel Carrier', category = 'armored', price = 1000000, stock = 5, spawn = 'ground', display = vector4(-2145.51, 3288.43, 32.73, 186.23) },
            { id = 'insurgent', type = 'vehicle', vtype = 'automobile', model = 'insurgent', label = 'Insurgent', desc = 'Armored SUV', category = 'armored', price = 850000, stock = 5, spawn = 'ground', display = vector4(-2150.7, 3280.85, 32.73, 195.74) },
            { id = 'insurgent2', type = 'vehicle', vtype = 'automobile', model = 'insurgent2', label = 'Insurgent Pick-Up', desc = 'Armed Insurgent Variant', category = 'armored', price = 200000, stock = 10, spawn = 'ground', display = vector4(-2107.52, 3255.53, 32.74, 113.3) },
            { id = 'minitank', type = 'vehicle', vtype = 'automobile', model = 'minitank', label = 'Invade & Persuade', desc = 'RC-style Mini Tank', category = 'armored', price = 500000, stock = 3, spawn = 'ground', display = vector4(-2107.63, 3262.9, 32.18, 103.46) },

            -- HELICOPTERS
            { id = 'hunter', type = 'vehicle', model = 'hunter', vtype = 'heli', label = 'FH-1 Hunter', desc = 'Attack Helicopter', category = 'helicopters', price = 1000000, stock = 5, spawn = 'air', display = vector4(-2118.89, 3263.7, 34.13, 124.4) },
            { id = 'Hunter V2', type = 'vehicle', model = 'ah64', vtype = 'heli', label = 'FH-2 Hunter', desc = 'Attack Helicopter', category = 'helicopters', price = 2500000, stock = 3, spawn = 'air', display = vector4(-2137.88, 3252.89, 33.68, 149.51) },
            { id = 'akula', type = 'vehicle', model = 'akula', vtype = 'heli', label = 'Akula', desc = 'Stealth Attack Helicopter', category = 'helicopters', price = 500000, stock = 10, spawn = 'air', display = vector4(-2142.7, 3270.41, 33.94, 179.73) },
            { id = 'valkyrie', type = 'vehicle', model = 'valkyrie', vtype = 'heli', label = 'Valkyrie', desc = 'Armed Transport Helicopter', category = 'helicopters', price = 500000, stock = 5, spawn = 'air', display = vector4(-2153.81, 3253.9, 33.19, 218.34) },
            { id = 'savage', type = 'vehicle', model = 'savage', vtype = 'heli', label = 'Savage', desc = 'Heavy Attack Helicopter', category = 'helicopters', price = 1200000, stock = 5, spawn = 'air', display = vector4(-2125.44, 3236.15, 33.31, 98.24) },

            -- JETS
            { id = 'lazer', type = 'vehicle', model = 'lazer', vtype = 'plane', label = 'P-996 LAZER', desc = 'Military Fighter Jet', category = 'jets', price = 3000000, stock = 3, spawn = 'air', display = vector4(-2232.9, 3270.46, 33.65, 61.31) },
            { id = 'hydra', type = 'vehicle', model = 'hydra', vtype = 'plane', label = 'Hydra', desc = 'VTOL Fighter Jet', category = 'jets', price = 3000000, stock = 3, spawn = 'air', display = vector4(-2264.34, 3223.86, 33.65, 58.96) },
            { id = 'strikeforce', type = 'vehicle', model = 'strikeforce', vtype = 'plane', label = 'B-11 Strikeforce', desc = 'Ground Attack Aircraft', category = 'jets', price = 1500000, stock = 3, spawn = 'air', display = vector4(-2248.95, 3247.51, 33.65, 61.91) },
            { id = 'raiju', type = 'vehicle', model = 'raiju', vtype = 'plane', label = 'F-160 Raiju', desc = 'Stealth VTOL', category = 'jets', price = 2500000, stock = 2, spawn = 'air', display = vector4(-2117.03, 3286.66, 33.82, 150.37) },

            -- WEAPONS (من qb-inventory)
            { id = 'carbine', type = 'item', item = 'weapon_carbinerifle', label = 'Carbine Rifle', desc = 'Service Rifle', category = 'weapons', price = 25000, stock = 30 },
            { id = 'combatmg', type = 'item', item = 'weapon_combatmg', label = 'Combat MG', desc = 'Heavy Machine Gun', category = 'weapons', price = 75000, stock = 20 },
            { id = 'stickybomb', type = 'item', item = 'weapon_stickybomb', label = 'Sticky Bomb', desc = 'Remote Detonation Explosive', category = 'weapons', price = 50000, stock = 50 },
            { id = 'weapon_rpg', type = 'item', item = 'weapon_rpg', label = 'RPG', desc = 'Secure Comms', category = 'items', price = 550000, stock = 5 },


            -- ITEMS
            { id = 'heavyarmor', type = 'item', item = 'heavyarmor', label = 'Heavy Armor', desc = 'Ballistic Vest', category = 'items', price = 2500, stock = 100 },
            { id = 'mg_ammo', type = 'item', item = 'mg_ammo', label = 'MG Ammo', desc = 'Ammunition Box', category = 'items', price = 500, stock = 200 },
            { id = 'rpg_ammo', type = 'item', item = 'rpg_ammo', label = 'RPG Ammo', desc = 'Ammunition Box', category = 'items', price = 500000, stock = 3 },


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
            { id = 'riot', type = 'vehicle', vtype = 'automobile', model = 'riot', label = 'Riot Van', desc = 'Armored Response', category = 'armored', price = 300000, stock = 3, spawn = 'ground', display = vector4(452.10, -1021.70, 28.30, 90.0) },
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
