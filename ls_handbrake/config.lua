Config = {}

Config.handbrake_alert = false

-- When enabled, the handbrake will not release when pressing the throttle.
-- The player must press the handbrake key to release it before driving.
Config.require_handbrake_release = false

-- Full control list is available here: https://docs.fivem.net/docs/game-references/controls/
Config.handbrake_input = {
    enabled = true,
    --Handbrake can only be interacted with when vehicle's engine is off
    when_engine_off = false,
    control = 76,
    name = '~INPUT_VEH_HANDBRAKE~',
    -- اضغط مطوّل عشان تسحب / تنزل الجلنط (بالملي ثانية)
    -- الضغطة العادية تبقى هاندبريك عادي للتفحيط والوقوف
    hold_time = 400,
    -- أعلى سرعة تقدر تسحب فيها الجلنط (كم/س) — تنزيله يشتغل بأي سرعة
    max_speed_kmh = 8.0,
}

-- ==========================================================================
-- الصوت: يسمعه اللي داخل السيارة + اللي قريبين منها بس، ويخف كل ما بعدت
-- ==========================================================================
Config.sound = {
    volume = 0.65,          -- الصوت داخل السيارة (0.0 - 1.0)
    max_distance = 10.0,    -- بعد هالمسافة (متر) ما أحد يسمع
    outside_volume = 0.85,  -- اللي برا السيارة يسمعونه أخف شوي (جدار السيارة)
    stereo = true,          -- الصوت يجي من جهة السيارة (يمين / يسار)
}

-- انميشن اليد وهي تسحب الجلنط (بس للي يسوق)
Config.anim = {
    enabled = true,
    dict = 'veh@std@ds@base',
    name = 'change_station',
    duration = 700,
}

-- لمبة (P) الحمراء بالشاشة لما الجلنط مسحوب (للي داخل السيارة)
Config.indicator = {
    enabled = true,
    position = 'bottom-right', -- bottom-right / bottom-left / top-right / top-left
}

-- ==========================================================================
-- الدحدرة: السيارة تنزل بالنزلة لو ما عليها جلنط وما أحد يسوقها
-- ==========================================================================
-- Roll speed multiplier
Config.roll_speed = 2.0

--The angle at which a vehicle will start to roll at (degrees)
Config.angle_threshold = 3.0

-- أقصى سرعة للدحدرة (كم/س) عشان ما تطير السيارة
Config.max_roll_speed_kmh = 35.0

-- كل السيارات القريبة (مو بس آخر سيارة ركبتها) — المسافة بالمتر
Config.roll_check_distance = 120.0

--Define vehicle classes or specific models for vehicles which will not roll back on a hill
Config.automatic_handbrake_vehicles = {
    --List of all vehicle classes can be found here: https://wiki.rage.mp/wiki/Vehicle_Classes
    classes = {
       'Boats',
       'Bikes',
       'Cycles',
       'Helicopters',
       'Planes',
       'Trains',
    },

    models = {
        'sultan',
        'ambulance'
    }
}
