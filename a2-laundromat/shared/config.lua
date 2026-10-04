Config = {}

Config.MinimumHouseRobberyPolice = 0 --- عدد الشرطة عشان تقدر تسرق (ينفحص من السيرفر)
Config.PoliceJobs = { 'police', 'sheriff' }

-- بعد ما تنفتح الأبواب: كم دقيقة لين تنقفل المغسلة من جديد وتقدر تنسرق مرة ثانية (لكل السيرفر)
Config.CooldownMinutes = 45

-- مكان المغسلة (للتأكد إن اللاعب فعلاً داخلها)
Config.Location = vector3(168.9, -1505.2, 29.3)
Config.Radius = 40.0

Config.Items = {
    Hack = 'hacking_device',   -- يفتح الباب الرئيسي (ينسحب)
    Laptop = 'laptop',         -- يفتح المكتب (ينسحب)
    Crowbar = 'weapon_crowbar' -- للتكسير (ما ينسحب)
}

-- الجوائز: رقم الحدث → a2-laundromat:server:roblaundromatX
-- (0 = الحدث بدون رقم a2-laundromat:server:roblaundromat)
Config.Loot = {
    [0]  = { item = 'goldchain', amount = 18 },
    [1]  = { item = '10kgoldchain', amount = 18 },
    [2]  = { item = 'diamond_ring', amount = 9 },
    [3]  = { item = 'goldchain', amount = 1 },
    [4]  = { item = 'goldchain', amount = 1 },
    [5]  = { item = 'goldchain', amount = 1 },
    [6]  = { item = 'goldchain', amount = 1 },
    [7]  = { item = 'goldchain', amount = 1 },
    [8]  = { item = 'goldchain', amount = 1 },
    [9]  = { item = 'goldchain', amount = 1 },
    [10] = { item = 'goldchain', amount = 1 },
    [11] = { item = 'goldchain', amount = 1 },
    [12] = { item = 'goldchain', amount = 1 },
    [13] = { item = 'moneyroll', amount = 55, office = true }, -- خزنة المكتب (تحتاج فتح المكتب باللابتوب)
}

Config.SmashTime = 2000   -- مدة التكسير (ملي ثانية)
Config.HackTime = 10000   -- مدة الاختراق (ملي ثانية)

-- ميني قيم الغسالات (سكربت 2na_lockpick لازم يكون شغال)
Config.Lockpick = {
    Stages = 3,   -- كم قفل لازم تفتح في كل غسالة
    MaxFails = 2, -- كم غلطة مسموحة (الغلطة اللي بعدها تخسر، 0 = أول غلطة تخسر)
}

-- الأبواب اللي تنقفل وتنفتح (لكل اللاعبين)
Config.Doors = {
    { hash = -849772278, coords = vector3(168.46, -1504.77, 29.3) },
    { hash = 1536367999, coords = vector3(169.37, -1505.65, 29.53) },
    { hash = 1531355165, coords = vector3(162.6, -1485.37, 29.31) },
    { hash = 234130018, coords = vector3(178.57, -1488.57, 28.09) },
}
Config.OfficeDoors = {
    { hash = -2071136470, coords = vector3(165.09, -1497.3, 28.18) },
}
