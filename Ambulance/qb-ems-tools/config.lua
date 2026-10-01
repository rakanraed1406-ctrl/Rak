Config = {}

Config.Job = 'ambulance'           -- وظيفة الإسعاف
Config.RequireDuty = true          -- أدوات المسعفين (emsOnly) تشتغل بس وأنت على الدوام
Config.HospitalResource = 'qb-hospital'
Config.TabletResource = 'mdt-ems-tablet' -- كل علاج ينكتب تلقائي بسجل المريض بالتابلت (Field treatment)
Config.MaxTargetDistance = 3.0     -- أبعد مسافة للمريض وقت العلاج

-- ==========================================================================
-- الانميشن (نفس الأسماء تنستخدم بالأدوات تحت)
-- ==========================================================================
Config.Anims = {
    self_wrap = { dict = 'amb@world_human_clipboard@male@idle_a', anim = 'idle_c', flag = 49 },
    pill      = { dict = 'mp_suicide', anim = 'pill', flag = 49 },
    kneel     = { dict = 'amb@medic@standing@tendtodead@idle_a', anim = 'idle_a', flag = 1 },
    kneel_alt = { dict = 'amb@medic@standing@kneel@idle_a', anim = 'idle_a', flag = 1 },
    cpr       = { dict = 'mini@cpr@char_a@cpr_str', anim = 'cpr_pumpchest', flag = 1 },
    cpr_patient = { dict = 'mini@cpr@char_b@cpr_str', anim = 'cpr_pumpchest', flag = 1 },
    tablet    = { dict = 'amb@world_human_tourist_map@male@base', anim = 'base', flag = 49 },
    clipboard = { dict = 'missfam4', anim = 'base', flag = 49 },
    push      = { dict = 'anim@heists@box_carry@', anim = 'idle', flag = 49 },
    lie       = { dict = 'anim@gangops@morgue@table@', anim = 'body_search', flag = 1 },
    sit_chair = { dict = 'missfinale_c2leadinoutfin_c_int', anim = '_leadin_loop2_lester', flag = 1 },
}

-- ==========================================================================
-- البروبات (bone 57005 = اليد اليمين · 18905 = اليسار · 28422 = اليمين (مسكة) · 12844 = الراس)
-- ground = true → ينحط على الأرض جنب المسعف بدل ما يمسكه
-- ==========================================================================
Config.Props = {
    syringe   = { model = 'prop_syringe_01', bone = 57005, offset = vector3(0.13, 0.02, -0.02), rotation = vector3(-80.0, 0.0, 0.0) },
    gauze     = { model = 'prop_ld_health_pack', bone = 18905, offset = vector3(0.12, 0.02, 0.06), rotation = vector3(-90.0, 0.0, 0.0) },
    pills     = { model = 'prop_cs_pills', bone = 58866, offset = vector3(0.11, -0.01, 0.0), rotation = vector3(-60.0, 0.0, 0.0) },
    tablet    = { model = 'prop_cs_tablet', bone = 28422, offset = vector3(0.0, -0.03, 0.0), rotation = vector3(20.0, -90.0, 0.0) },
    clipboard = { model = 'p_amb_clipboard_01', bone = 36029, offset = vector3(0.16, 0.08, 0.1), rotation = vector3(-130.0, -50.0, 0.0) },
    medbag_ground = { model = 'xm_prop_x17_bag_med_01a', ground = true, offset = vector3(0.60, 0.25, 0.0), heading = 90.0 },
    kit_ground    = { model = 'prop_ld_health_pack', ground = true, offset = vector3(-0.50, 0.35, 0.0) },
    bottle_ground = { model = 'prop_ld_flow_bottle', ground = true, offset = vector3(0.45, -0.25, 0.0) },
    tank_ground   = { model = 'p_s_scuba_tank_s', ground = true, offset = vector3(0.55, -0.30, 0.0), heading = 90.0 },
}

-- ==========================================================================
-- الأدوات الطبية
--   label      : الاسم
--   use        : 'self' على نفسك · 'patient' على مريض بس · 'any' تختار (نفسك أو المريض اللي جنبك)
--   emsOnly    : للمسعفين بس
--   down       : nil = أي حالة · 'laststand' = لازم المريض ينزف · 'alive' = لازم يكون صاحي (مو طايح)
--   time       : المدة (ملي ثانية)
--   anim       : انميشن على نفسك / anim_patient : على المريض
--   props      : بروبات المسعف (من Config.Props)
--   patientProp: بروب يتركب على المريض نفسه لمدة (مثل قناع الأكسجين)
--   effects    : وش يسوي (bleed · stopbleed · limbs · minor · painkiller · health · oxygen · stabilize)
--   consume    : ينقص من الانفنتوري ولا لا
-- ==========================================================================
Config.Tools = {
    ems_gauze = {
        label = 'Hemostatic Gauze', use = 'any', emsOnly = false, time = 5000, consume = true,
        anim = 'self_wrap', anim_patient = 'kneel',
        props = { 'gauze' }, props_patient = { 'medbag_ground' },
        effects = { { kind = 'bleed', amount = 2 }, { kind = 'health', amount = 5 } },
        notify = 'The gauze slowed the bleeding',
    },
    ems_tourniquet = {
        label = 'Tourniquet', use = 'any', emsOnly = false, time = 8000, consume = true,
        anim = 'self_wrap', anim_patient = 'kneel_alt',
        props = { 'gauze' }, props_patient = { 'medbag_ground' },
        effects = { { kind = 'stopbleed' } },
        notify = 'Tourniquet applied, the bleeding stopped',
    },
    ems_splint = {
        label = 'SAM Splint', use = 'any', emsOnly = false, time = 10000, consume = true,
        anim = 'self_wrap', anim_patient = 'kneel',
        props = { 'gauze' }, props_patient = { 'medbag_ground', 'kit_ground' },
        effects = { { kind = 'limbs', parts = { 'legs', 'arms' } } },
        notify = 'The fracture is splinted, you can walk properly again',
    },
    ems_coldpack = {
        label = 'Cold Pack', use = 'any', emsOnly = false, time = 4000, consume = true,
        anim = 'self_wrap', anim_patient = 'kneel',
        props = { 'gauze' }, props_patient = {},
        effects = { { kind = 'painkiller', doses = 1 }, { kind = 'limbs', max = 1 } },
        notify = 'The cold pack eased the pain',
    },
    ems_morphine = {
        label = 'Morphine Auto-Injector', use = 'any', emsOnly = true, time = 4000, consume = true,
        anim = 'self_wrap', anim_patient = 'kneel',
        props = { 'syringe' }, props_patient = { 'syringe' },
        effects = { { kind = 'painkiller', doses = 3 }, { kind = 'health', amount = 15 } },
        notify = 'Morphine administered, the pain fades',
    },
    adrenaline = {
        label = 'Adrenaline Syringe', use = 'patient', emsOnly = true, down = 'laststand', time = 4000, consume = true,
        anim_patient = 'kneel',
        props_patient = { 'syringe', 'medbag_ground' },
        effects = { { kind = 'stabilize', seconds = 90, max = 240 } },
        notify = 'Adrenaline! Your heart is racing (more time before bleeding out)',
    },
    ems_saline = {
        label = 'IV Saline Bag', use = 'patient', emsOnly = true, time = 12000, consume = true,
        anim_patient = 'kneel',
        props_patient = { 'syringe', 'bottle_ground', 'medbag_ground' },
        effects = { { kind = 'health', amount = 60 }, { kind = 'bleed', amount = 1 } },
        notify = 'An IV drip was started, you slowly recover',
    },
    ems_suture = {
        label = 'Suture Kit', use = 'patient', emsOnly = true, down = 'alive', time = 15000, consume = true,
        anim_patient = 'kneel_alt',
        props_patient = { 'syringe', 'medbag_ground', 'kit_ground' },
        effects = { { kind = 'minor' }, { kind = 'bleed', amount = 2 }, { kind = 'limbs', max = 3 } },
        notify = 'Your wounds were stitched up',
    },
    ems_oxygen = {
        label = 'Oxygen Mask', use = 'patient', emsOnly = true, time = 6000, consume = false,
        anim_patient = 'kneel',
        props_patient = { 'tank_ground' },
        patientProp = { model = 'p_s_scuba_mask_s', bone = 12844, offset = vector3(0.0, 0.0, 0.0), rotation = vector3(180.0, 90.0, 0.0), duration = 45000 },
        effects = { { kind = 'oxygen', health = 25 } },
        notify = 'Oxygen mask on, breathing is easier',
    },
}

-- الإنعاش القلبي (CPR) بالـ First Aid Kit — أي أحد معه الشنطة يقدر يسويه للمريض الطايح
-- (النظام القديم حق الـ First Aid انشال: الحين الشنطة = CPR)
-- عدد الجولات المطلوبة عشوائي من 1 إلى 3 حسب قوة الحالة:
--   حالة خفيفة  (ينزف بس)                         → 1
--   حالة متوسطة (نزيف قوي / إصابة بالراس أو الصدر) → 1 أو 2
--   حالة خطيرة  (بدون نبض + نزيف أو إصابات)         → 2 أو 3
-- لما تخلص الجولات المطلوبة المريض يقوم (يعيش) بصحة ضعيفة
Config.CPR = {
    Enabled = true,
    Item = 'firstaid',     -- لازم يكون معك (First Aid Kit) — تستخدمه من الانفنتوري أو بالتارقت على المريض
    ConsumeOn = 'revive',  -- 'revive' = ينقص واحد لما يقوم المريض · 'round' = ينقص واحد كل جولة
    Time = 12000,          -- مدة الجولة الوحدة (ملي ثانية)
    AllowNoPulse = true,   -- يشتغل حتى على اللي بدون نبض (ميت) — false = للي ينزف بس
    Seconds = 45,          -- بين الجولات: كم ثانية تنضاف لوقت النزيف عشان ما يموت وأنت تنعشه
    Max = 240,             -- أقصى وقت نزيف ممكن يوصله
    ReviveHealth = 130,    -- صحته لما يقوم (100 = على الموت، 200 = كاملة)
    ShowRounds = false,    -- true = يطلع للمنقذ كم جولة باقية · false = ما يدري (أكثر واقعية)
}

-- ==========================================================================
-- الشاشة الحيوية (Vitals Monitor) — ECG + النبض + الأكسجين + الضغط + الإصابات
-- ==========================================================================
Config.Monitor = {
    Item = 'ems_monitor',     -- الأيتم اللي يفتحها (للمسعفين)
    RequireItemForTarget = false, -- true = حتى خيار "Examine" بالتارقت يحتاج الأيتم
    Range = 10.0,             -- تنقفل لو ابتعدت عن المريض أكثر من كذا
    Refresh = 2000,           -- تحديث القراءات (ملي ثانية)
    Volume = 0.25,            -- صوت البيب (0 = بدون)
    CloseKey = 177,           -- BACKSPACE
    Anim = 'tablet', Prop = 'tablet',
}

-- ==========================================================================
-- النقالة / الكرسي المتحرك / شنطة الإسعاف
-- Models = أول موديل موجود باللعبة ينستخدم (تقدر تحط موديل مخصص أول القائمة)
-- ==========================================================================
Config.Stretcher = {
    Item = 'ems_stretcher',
    Models = { 'v_med_emptybed', 'v_med_bed1' },
    PushOffset = vector3(0.0, 1.45, -1.0),   -- مكانها قدام المسعف وهو يدفها
    PushRotation = vector3(0.0, 0.0, 90.0),
    PatientOffset = vector3(0.0, 0.0, 1.05), -- مكان المريض فوقها
    PatientRotation = vector3(0.0, 0.0, 90.0),
    VehicleOffset = vector3(0.0, -2.0, 0.35), -- مكانها داخل الإسعاف
    VehicleRotation = vector3(0.0, 0.0, 90.0),
    Vehicles = { 'ambulance' },               -- الإسعافات اللي تنحط فيها (+ أي سيارة كلاس Emergency قريبة)
}

Config.Wheelchair = {
    Item = 'ems_wheelchair',
    Models = { 'prop_wheelchair_01' },
    SitOffset = vector3(0.0, 0.05, 0.4),
    SitRotation = vector3(0.0, 0.0, 180.0),
    PushOffset = vector3(-0.0, -0.3, -0.73),
    PushRotation = vector3(195.0, 180.0, 180.0),
    PushBone = 28422,
}

Config.MedBag = {
    Item = 'ems_medbag',
    Models = { 'xm_prop_x17_bag_med_01a', 'prop_med_bag_01b' },
    Slots = 20, MaxWeight = 60000,  -- مساحة الشنطة (Stash)
}

Config.MaxPlacedPerPlayer = 3       -- كم نقالة/كرسي/شنطة يقدر المسعف يحط بنفس الوقت
