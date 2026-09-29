# EMS Tablet (mdt-ems-tablet) — v1.0.0

نفس تابلت الشرطة بالضبط (Hub + Dispatch + الإشعارات + الخريطة…) لكن **بالكامل للمسعفين**.
كل شي يخص الشرطة انشال وانحط بداله شي يخص الإسعاف، وإشعارات المستشفى اللي كانت تروح لـ **cd_dispatch** صارت تروح للتابلت.

> التابلتين يشتغلون مع بعض بنفس السيرفر بدون أي تعارض (أحداث وأوامر وجداول وأيتم مختلفة).

## ⚠️ قبل التشغيل
1. حط المجلد `mdt-ems-tablet` بالسيرفر وضيف بالـ `server.cfg` بعد `qb-core` و `oxmysql`:
   ```
   ensure mdt-ems-tablet
   ```
2. استخدم نسخة **qb-hospital** اللي بالمجلد `Ambulance/` (معدّلة عشان ترسل للتابلت بدل cd_dispatch).
3. الجداول تنسوى تلقائيًا أول تشغيل (أو شغّل `sql/install.sql`).
4. أيتم **`ems_tablet`** — الصورة جاهزة بـ `install/ems_tablet.png` (100×100 شفافة) ونسخة كبيرة `install/ems_tablet_512.png`:
   - **qb-inventory**: انسخ الصورة لـ `qb-inventory/html/images/ems_tablet.png` وضيف في `qb-core/shared/items.lua`:
     ```lua
     ems_tablet = { name = 'ems_tablet', label = 'EMS Tablet', weight = 1000, type = 'item', image = 'ems_tablet.png', unique = true, useable = true, shouldClose = true, description = 'EMS Medical Data Terminal' },
     ```
   - **ox_inventory**: انسخ الصورة لـ `ox_inventory/web/images/ems_tablet.png` وضيف في `ox_inventory/data/items.lua`:
     ```lua
     ['ems_tablet'] = { label = 'EMS Tablet', weight = 1000, stack = false, close = true, description = 'EMS Medical Data Terminal' },
     ```
5. يفتح بالأيتم أو بالأمر **`/emdt`** (لازم وظيفة `ambulance` + الأيتم معك).

## 🚨 تحذير مهم عن cd_dispatch
نسخة **cd_dispatch** اللي أرسلتها فيها **باك دور (Backdoor)**: الملف المخفي `cd_dispatch/html/.lpt.js` ينزّل كود من
`steaxscripts.com` ويشغله. الحين الشرطة والإسعاف ما يحتاجون cd_dispatch أبدًا، فـ **احذف cd_dispatch كامل من السيرفر**.
وافحص باقي السكربتات عندك عن أي ملف `.js` مخفي أو سطر غريب بالـ `fxmanifest.lua` (نفس اللي انشال قبل من qb-radialmenu).
- لو في سكربتات ثانية تنادي `exports['cd_dispatch']:GetPlayerInfo()` تبقى شغالة بعد الحذف (`Config.Dispatch.CdDispatchCompat`).

## 📱 التطبيقات (وش تغيّر عن تابلت الشرطة)
| تابلت الشرطة | تابلت الإسعاف |
|---|---|
| Command Hub | **EMS Hub** — الروستر، الدوام، الكول ساين، الحالات: متاح / ينقل مريض / بالمستشفى / ديسباتش / مشرف / استراحة، وزر **بانيك المسعف 10-99** |
| Dispatch | **Dispatch** — نفس نظام الـ CAD والألوان والأصوات، أكواد وأدوار إسعاف (Lead paramedic, Triage, Transport…) |
| Most Wanted | **Patient Records** — بحث بالاسم / CID / الرقم: فصيلة الدم، التأمين، **حالة المريض الحية وإصاباته** (من qb-hospital)، الحساسية والأمراض والأدوية، وسجل العلاج |
| BOLO | **Ward Board** — المرضى المنوّمين: السرير، التشخيص، الحالة (مستقر / خطير / **حرج** → بلاغ أحمر للطاقم)، والخروج |
| Reports | **Medical Reports** — تقارير علاج فيها اسم المريض والـ CID (تطلع بسجل المريض) |
| Citations | **Billing** — فاتورة للمريض اللي جنبك تنسحب من حسابه وتروح لخزنة الإسعاف (`Config.Billing`) |
| Vehicle Lookup | **Protocols** — مرجع سريع: خطوات العلاج، الأدوات (defibrillator / firstaid / bandage…) ورموز الراديو |
| Personnel | **Personnel + نقاط الإسعاف** — نفس نقاط qb-emspoints، القيادة تعطي/تنقص/تصفر من التابلت |
| Tactical Ops | **Command Ops** — تتبع المسعفين، إغلاق المستشفى، **إعلان إصابات جماعية (MCI)** |
| Treasury / Recruitment / Directives / CCTV / Map | نفسها للإسعاف (`/emsapp` للتقديم، كاميرات المستشفى، خريطة المسعفين) |

## 🔔 الإشعارات (بدل cd_dispatch)
نفس نظام الشرطة: 3 ألوان وأصوات، توصلك والتابلت مسكّر لو هو بالانفنتوري وأنت على الدوام.

| من وين | الكود | اللون | وش فيه |
|---|---|---|---|
| المريض يضغط **G** وهو ميت (بدون نبض) | `10-69` | 🔴 | اسمه + ID، الجنس، فصيلة الدم، النزيف، الإصابات، سبب الإصابة (السلاح) |
| المريض يضغط **G** وهو ينزف (Last stand) | `10-47` | 🟡 | نفس اللي فوق |
| مريض بالاستقبال والمسعفين موجودين | `CHECK-IN` | 🔵 | اسمه ومكانه |
| `/997 رسالة` (مواطن) | `997-CALL` | 🟡 | اسم + رقم + ID المتصل |
| `/997a رسالة` (مجهول) | `997-ANON` | 🟡 | بدون اسم ولا رقم |
| حادث سيارة قوي (تلقائي) | `10-50` | 🟡 / 🔴 لو السيارة منقلبة | السيارة، اللون، اللوحة، السرعة، عدد الركاب |
| بانيك مسعف | `10-99` | 🔴 | + يوصل **للشرطة** بتابلتهم (`PanicAlsoAlertsPolice`) |
| مريض حرج بالعنبر / MCI / بث القيادة | … | 🔴 | |

- لما المريض **يقوم** (مسعف أنعشه / First Aid / أدمن) أو يرسبن بالمستشفى، البلاغ حقه يتحول تلقائي **CONTAINED** ويتكتب عليه.
- الرد على المتصل: `/997r E1001 الرسالة` أو مثل القديم `/997r [ID] الرسالة`.
- `G` = Respond · `DELETE` = تجاهل · `/emdtmute` = كتم · `/emspanic` = بانيك — كلها تتغير من إعدادات GTA → Key Bindings → FiveM.

## 🔗 ربط سكربت ثاني بالإسعاف
**من الكلاينت:**
```lua
TriggerEvent('ems-mdt:client:CreateDispatchCall', {
    code = '10-52', title = 'Injured hiker', priority = 'medium', -- low / medium / high
    description = 'Fell from a cliff', tags = { { icon = 'fa-user-injured', label = '1 patient' } }
})
```
**من السيرفر:**
```lua
TriggerEvent('ems-mdt:server:CreateDispatchCall', { code = '10-52', title = 'Injured hiker', coords = vector3(0.0, 0.0, 0.0) })
exports['mdt-ems-tablet']:CreateDispatchCall('ambulance', { code = '10-52', title = 'Injured hiker' })
```
- سكربتات ترسل `cd_dispatch:AddNotification` / `ps-dispatch` / `qb-dispatch` للإسعاف (`job_table = { 'ambulance' }`) تشتغل تلقائي.
- ولو سكربت أرسل بلاغ إسعاف لتابلت الشرطة (`CreateDispatchCall('ambulance', …)`) الشرطة تحوّله للإسعاف بدل ما يضيع.
- إكسبورتات ثانية: `IsDepartmentLocked()` (إغلاق المستشفى)، `AddTreasuryMoney(amount)`، `GetTreasuryMoney()`، `HospitalAlert(src, kind, info)`.

## ⚙️ الإعدادات (config.lua)
- `Config.JobName` (ambulance)، `Config.MinCommandGrade`، `Config.Department` (الاسم اللي يطلع بالتابلت).
- `Config.Dispatch` — الأوامر، الأكواد والألوان، الأدوار، الحالات، الأصوات، مدة الإشعار.
- `Config.Billing` — سحب الفلوس فعلي أو تسجيل بس، الحد الأعلى، الأسعار الجاهزة.
- `Config.Points` — نقاط الإسعاف. `Config.Cameras` — كاميرات المستشفى (**عدّل الإحداثيات على مستشفاك**، `/emdtmapcalibrate` يطبع مكانك بالكونسول).
- `Config.Alerts.Crash` — حساسية كشف الحوادث. `Config.Protocols` / `Config.RadioCodes` — محتوى تطبيق Protocols.

## 🏥 التعديلات على سكربتات الإسعاف (`Ambulance/`)
- **qb-hospital**: شلنا cd_dispatch — طلب المساعدة (G) و /997 وتنبيه الاستقبال كلها تروح للتابلت، مع إصابات المريض.
  لو التابلت طافي يرجع للبلب القديم تلقائي (`Config.EmsTablet` بـ config.lua). وضفنا إكسبورت `GetPatientStatus`
  وصلّحنا كراش فحص الحالة (`WeaponDamageList` ما كان معرّف).
- **qb-emspoints**: كان أي لاعب يقدر يعطي نفسه نقاط (الأحداث بدون تحقق) — الحين بس البوس، والنقاط التلقائية يحددها السيرفر.
- شلنا تعليقات الإعلانات من الملفات.

## هيكلة الملفات
- `server/hub.lua` (الروستر/الدوام/الحالة/البانيك/الشات) · `server/dispatch.lua` (البلاغات، /997، التوافق) · `server/alerts.lua` (المستشفى + الحوادث)
- `server/patients.lua` · `server/ward.lua` · `server/billing.lua` · `server/personnel.lua` (+ النقاط) · `server/tactical.lua`
- `html/script.js` (التطبيقات) · `html/js/hub.js` · `html/js/dispatch.js` · `html/js/notify.js` · `html/js/dialog.js`
