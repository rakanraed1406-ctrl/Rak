# data_car — ضبط سيارات الشرطة

| الموديل | السيارة | الوزن | الدفع | القير | السرعة القصوى | الفرامل | الريوس |
|---|---|---|---|---|---|---|---|
| b211vic | Crown Victoria P71 | 1880 كغ | خلفي | 4 | ~210 | 0.85 | 32 |
| b212caprice | Caprice PPV | 1885 كغ | خلفي | 6 | ~249 | 0.95 | 35 |
| b214charger | Charger Pursuit 2014 | 1950 كغ | خلفي | 5 | ~240 | 1.00 | 35 |
| b216explorer | Explorer PIU 2016 | 2130 كغ | رباعي | 6 | ~220 | 0.90 | 32 |
| b218charger | Charger Pursuit 2018 | 1950 كغ | خلفي | 6 | ~240 | 1.00 | 35 |
| b218tau | Taurus PI 2018 | 1950 كغ | رباعي | 6 | ~238 | 0.95 | 35 |
| b219tahoe | Tahoe PPV 2019 | 2450 كغ | خلفي | 6 | ~220 | 0.85 | 30 |
| b2chal | Challenger Hellcat | 2030 كغ | خلفي | 6 | ~320 | 1.15 | 38 |

(السرعات بالكيلو، والريوس من `qb-customscripts-byrko` → `Config.VehicleTuning.Reverse`)

## القومة 0-100 = 4 ثواني
القيم بالملفات تقريبية لأن القومة باللعبة تتأثر بالجير والجريب والسحب.
عشان تكون **4.0 ثواني بالضبط**: اركب السيارة على خط طويل مستقيم واكتب `/carcalib` (أدمن).
يقيس ويعدّل لين توصل 4.0، ويحفظها للسيرفر كله تلقائي (`qb-customscripts-byrko/calibration.json`).

- `/cartest` : يقيس 0-100 ومسافة الفرامل من 100.
- `/cartest top` : يقيس السرعة القصوى.

## الأصوات
كل السيارات صارت على أصوات GTA الأصلية (ما تحتاج باك صوت خارجي) ومطابقة للمحرك الحقيقي:

| الموديل | قبل | بعد |
|---|---|---|
| b211vic | WINDSOR (V12) | POLICE — Crown Vic V8 |
| b212caprice | kc37plycuda70 (باك ناقص) | FUGITIVE — Caprice V8 |
| b214charger | ratloader2 (شاحنة) | BUFFALO2 — HEMI V8 |
| b216explorer | SENTINEL | POLICE3 — Ford V6 |
| b218charger | b218charger (باك ناقص) | POLICE2 — HEMI V8 |
| b218tau | aq46forgtebv6 (باك ناقص) | POLICE3 — Taurus V6 |
| b219tahoe | BALLER | GRANGER — Tahoe V8 |
| b2chal | POLICE | GAUNTLET — Challenger V8 |

### صوت الهيلكات الحقيقي (اختياري)
الباك موجود بـ `b2chal/audioconfig` و `b2chal/sfx`. عشان يشتغل:
1. ضيف هذا بالـ `fxmanifest.lua` حق المورد (عدّل المسار لو `data_car` داخل مجلد ثاني):
```lua
files {
    'data_car/b2chal/audioconfig/*.dat151.rel',
    'data_car/b2chal/audioconfig/*.dat54.rel',
    'data_car/b2chal/sfx/**/*.awc',
}
data_file 'AUDIO_GAMEDATA'  'data_car/b2chal/audioconfig/dodgehemihellcat_game.dat'
data_file 'AUDIO_SOUNDDATA' 'data_car/b2chal/audioconfig/dodgehemihellcat_sounds.dat'
data_file 'AUDIO_WAVEPACK'  'data_car/b2chal/sfx/dlc_dodgehemihellcat'
```
2. بـ `b2chal/vehicles.meta` غيّر `<audioNameHash>GAUNTLET</audioNameHash>` إلى `<audioNameHash>dodgehemihellcat</audioNameHash>`.

## إصلاحات
- Crown Vic: الفرامل كانت 50 (مفروض حول 1).
- Caprice: الوزن كان 5000 كغ والفرامل 0.5.
- Tahoe: الجريب ما كان يفلت أبد (0.2) وتبديل القير 8.0.
- Challenger: `handling.meta` كان خربان (ناقص إغلاق `SubHandlingData`) فاللعبة كانت تتجاهله.
