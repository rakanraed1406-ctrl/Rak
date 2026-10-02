Config = {}

-- الـ CitizenID المسموح لهم بفتح قائمة البوت (السيرفر يتحقق منها بعد، مو بس الكلاينت)
Config.AllowedCitizens = {
    ["3320"] = true,
    ["136861"] = true,
    ["07"] = true,
}

-- إعدادات البوت ومكانه
Config.Bot = {
    model = joaat('s_m_y_pilot_01'),
    coords = vector4(-2035.03, 3116.78, 32.81, 120.52),
}

Config.UseDistance = 10.0    -- لازم تكون قريب من البوت كذا متر عشان تشتري / تطلع / تخزن (حماية سيرفر)
Config.StoreDistance = 60.0  -- الطيارة لازم تكون قريبة من البوت كذا متر عشان تنخزن
Config.MoneyType = 'cash'    -- 'cash' أو 'bank'

-- لو الطيارة "برا" بالداتابيس بس ما لها أي أثر بالسيرفر (ريستارت، انحذفت، اختفت)
-- true = تقدر تطلعها من الهنقر مرة ثانية · false = تبقى عالقة مثل قبل
Config.RecoverLost = true

-- إعطاء المفتاح (كلاينت)
Config.GiveKeys = function(vehicle, plate)
    TriggerEvent('qb-vehiclekeys:client:AddKeys', plate)
end

-- قائمة بأماكن الإرساء المتعددة (Spawn Points)
Config.SpawnPoints = {
    vector4(-2058.95, 3093.08, 33.82, 329.69),
    vector4(-2043.92, 3118.99, 32.81, 328.11),
    vector4(-2076.45, 3062.62, 32.81, 327.02), -- يمكنك إضافة إحداثيات أخرى هنا
}

-- الطائرات المتاحة للبيع — السعر والموديل من هنا بس (الكلاينت ما يقدر يغيرها)
-- type (اختياري): 'heli' أو 'plane' — يخلي السيرفر يرسبنها أسرع. بدونه تشتغل عادي.
Config.Helicopters = {
    { model = 'mh60l', label = 'MH60L', price = 150000 },
    { model = 'swat_heli', label = 'Swat Helicopter', price = 55000 },
    { model = 'savage', label = 'Savage', price = 1000000, type = 'heli' },
    { model = 'raiju', label = 'F-160', price = 2500000, type = 'plane' },
    { model = 'lazer', label = 'Lazer', price = 1500000, type = 'plane' },
    { model = 'csk131', label = 'CSK131', price = 500000 },
}
