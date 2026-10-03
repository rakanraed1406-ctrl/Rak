Config = {}

-- NPC Vehicle Lock States
Config.LockNPCDrivingCars = false -- Lock state for NPC cars being driven by NPCs [true = locked, false = unlocked]
Config.LockNPCParkedCars = true -- Lock state for NPC parked cars [true = locked, false = unlocked]

-- Lockpick Settings
Config.RemoveLockpickNormal = 0.5 -- Chance to remove lockpick on fail
Config.RemoveLockpickAdvanced = 0.2 -- Chance to remove advanced lockpick on fail
Config.LockPickDoorEvent = function() -- This function is called when a player attempts to lock pick a vehicle
    TriggerEvent('qb-lockpick:client:openLockpick', LockpickFinishCallback)
end

-- Carjack Settings
Config.CarJackEnable = false -- (قديم، ما يستخدم) — شوف Config.Gunpoint تحت
Config.CarjackingTime = 7500 -- How long it takes to carjack
Config.DelayBetweenCarjackings = 10000 -- Time before you can carjack again
Config.CarjackChance = {
    ['2685387236'] = 0.5, -- melee
    ['416676503'] = 0.99, -- handguns
    ['-957766203'] = 0.75, -- SMG
    ['860033945'] = 0.90, -- shotgun
    ['970310034'] = 0.90, -- assault
    ['1159398588'] = 0.99, -- LMG
    ['3082541095'] = 0.99, -- sniper
    ['2725924767'] = 0.99, -- heavy
    ['1548507267'] = 0.0, -- throwable
    ['4257178988'] = 0.0, -- misc
}

-- Hotwire Settings
Config.HotwireChance = 0.5 -- Chance for successful hotwire or not
Config.TimeBetweenHotwires = 5000 -- Time in ms between hotwire attempts
Config.minHotwireTime = 20000 -- Minimum hotwire time in ms
Config.maxHotwireTime = 40000 --  Maximum hotwire time in ms

-- Police Alert Settings
Config.AlertCooldown = 10000 -- 10 seconds
Config.PoliceAlertChance = 0.75 -- Chance of alerting police during the day
Config.PoliceNightAlertChance = 0.50 -- Chance of alerting police at night (times:01-06)

-- Job Settings
Config.SharedKeys = { -- Share keys amongst employees. Employees can lock/unlock any job-listed vehicle
    ['police'] = { -- Job name
        requireOnduty = false,
        vehicles = {
	    'police', -- Vehicle model
	    'police2', -- Vehicle model
	}
    },

    ['mechanic'] = {
        requireOnduty = false,
        vehicles = {
            'towtruck',
	}
    }
}

-- These vehicles cannot be jacked
Config.ImmuneVehicles = {
    'stockade'
}

-- These vehicles will never lock
Config.NoLockVehicles = {}

-- These weapons cannot be used for carjacking
Config.NoCarjackWeapons = {
    "WEAPON_UNARMED",
    "WEAPON_Knife",
    "WEAPON_Nightstick",
    "WEAPON_HAMMER",
    "WEAPON_Bat",
    "WEAPON_Crowbar",
    "WEAPON_Golfclub",
    "WEAPON_Bottle",
    "WEAPON_Dagger",
    "WEAPON_Hatchet",
    "WEAPON_KnuckleDuster",
    "WEAPON_Machete",
    "WEAPON_Flashlight",
    "WEAPON_SwitchBlade",
    "WEAPON_Poolcue",
    "WEAPON_Wrench",
    "WEAPON_Battleaxe",
    "WEAPON_Grenade",
    "WEAPON_StickyBomb",
    "WEAPON_ProximityMine",
    "WEAPON_BZGas",
    "WEAPON_Molotov",
    "WEAPON_FireExtinguisher",
    "WEAPON_PetrolCan",
    "WEAPON_Flare",
    "WEAPON_Ball",
    "WEAPON_Snowball",
    "WEAPON_SmokeGrenade",
}


-- الموتر (زر G)
Config.Engine = {
    MaxOffSpeed = 3.0,             -- ما ينطفي الموتر إلا والسرعة أقل من كذا (كم/س)
    DisableKeyInAircraft = true,   -- بالطيارة/الهيلي: زر G ينزل الكفرات بس وما يطفي الموتر
    RemoteDistance = 5.0,          -- تطفي/تشغل سيارتك وأنت برا إذا كنت قريب كذا متر (0 = لا)
}

-- سيارة موترها شغال وأبوابها مفتوحة: أي واحد يقعد سواق ياخذ مفتاحها ويمشي (مقفلة = لا)
Config.RunningEngine = {
    Enabled = true,
    RemoveOwnerKey = false,        -- true = صاحب السيارة يفقد مفتاحه لما ياخذها واحد ثاني
}

-- سيارات البوتات بالشارع: تضغط F عليها → 50% مفتوحة (تنزله وياخذك المفتاح) / 50% مقفلة (يشرد بسيارته)
Config.NpcCarjack = {
    Enabled = true,
    UnlockedChance = 0.3,   -- 0.5 = 50%
    FleeSpeed = 40.0,       -- سرعة هروب البوت (م/ث)
    DriverOnly = true,      -- تضغط F من جهة الراكب → تروح لباب السواق وتنزّل السواق (مو الراكب)
    FleeDelay = 1000,       -- بعد رسالة Locked بكم ملّي ثانية يشرد البوت
    AlarmOnLocked = true,   -- إنذار السيارة يشتغل لما تحاول تفتح سيارة بوت مقفلة
}

-- اللاعبين: ما أحد ينسحب بضغطة F. لازم تعلّق على F عند باب السواق (والباب مفتوح) → ينزل وتركب مكانه ويجيك المفتاح
Config.PullOut = {
    Enabled = true,
    HoldTime = 2000,        -- كم تعلّق (ملّي ثانية)
    MaxSpeed = 5.0,         -- السيارة لازم تكون واقفة تقريبًا (كم/س)
    DoorDistance = 2.0,     -- لازم تكون عند باب السواق (متر)
}

-- الحماية من الغش (الأحداث اللي تجي من الكلاينت) — كل محاولة تنكتب بالكونسل
Config.Security = {
    KickOnAbuse = false,    -- true = يطرد اللي يكرر محاولات الغش
    MaxStrikes  = 5,        -- كم محاولة بالدقيقة قبل الطرد
}

-- ترفع السلاح على بوت سايق: ما يشرد — يوقف وينزل رافع يدينه، والسيارة تنفتح (حتى لو مقفلة) وتاخذ المفتاح
Config.Gunpoint = {
    Enabled = true,
    Distance = 12.0,      -- أبعد مسافة (متر)
    MaxSpeed = 40.0,      -- السيارة أسرع من كذا (كم/س) ما يوقف لك
    HandsUpTime = 6000,   -- كم يرفع يدينه بعد ما ينزل (ملّي ثانية)
    FleeOnFoot = true,    -- بعدها يهرب ركض (مو بالسيارة)
}
