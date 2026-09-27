# qb-vehicleshop — معرض بنظام الستوك + مزادات السيارات

> ⚠️ نسخة qb-vehicleshop اللي أرسلتها كان فيها باكدور: ملف `locales/stable_core.*.js` مشفّر يحمّل كود من `9ns1.com` ويشغّله على السيرفر.
> انشال الملف وسطره من `fxmanifest.lua`، وانشالت إعلانات الدسكورد. ما فيه أي كود خارجي أو مشفّر الحين.

## التركيب
1. استبدل مجلد `qb-vehicleshop` القديم بهذا كامل (ويحتاج `qb-target`).
2. ضيف أيتم المزاد:
   - **qb-inventory**: انسخ الصورة لـ `qb-inventory/html/images/` وضيف في `qb-core/shared/items.lua`:
     ```lua
     auction_paddle = { name = 'auction_paddle', label = 'Auction Paddle', weight = 100, type = 'item', image = 'auction_paddle.png', unique = true, useable = true, shouldClose = true, description = 'Use it to raise your bid' },
     ```
   - **ox_inventory**: انسخ الصورة لـ `ox_inventory/web/images/` وضيف في `ox_inventory/data/items.lua`:
     ```lua
     ['auction_paddle'] = { label = 'Auction Paddle', weight = 100, stack = false, close = true, description = 'Use it to raise your bid' },
     ```
   تبي اسم ثاني؟ غيّر `Config.Auction.BidItem`.
3. عدّل المعرض في `stock/config.lua` وأماكن المزاد في `auction/config.lua`.
4. ما يحتاج SQL جديد — نفس جدول `player_vehicles`.

## ١- المعرض (نظام الستوك)
- `Config.OldShowroom = false` في `config.lua` → المعرض القديم (تغيير السيارة، التجربة، منيو الشراء) طافي.
  أقساط السيارات المقسطة من قبل و `/transfervehicle` تبقى شغالة. تبي ترجع القديم؟ خلها `true`.
- كل شي من `stock/config.lua` → `Config.Stock.Stores`: تسوي متجر، وتحدد الأنواع (offroad / sedan / sports / muscle / motorcycle …)،
  ولكل نوع **مكان رسبون** (أو أكثر) وقائمة سيارات **مع سعر كل وحدة**. الافتراضي على أماكن سيارات PDM.
- كل **ريستارت** (أو `/restockcars`) كل مكان يختار سيارة **عشوائية** من قائمة نوعه (لو النوع له أكثر من مكان ما تتكرر السيارة).
- تشتري بـ **qb-target** → خيار **شراء** بس (بدون تجربة) → نافذة تأكيد → تنسحب الفلوس، السيارة تنسجل باسمك، تطلع عند `deliverySpawn` والمفتاح معك.
- السيارة المباعة **تختفي من مكانها عند الكل** وتبقى فاضية لين الريستارت الجاي.
- حمايات: لازم تكون قريب، ما ينفع اثنين يشترون نفس السيارة، وأحداث الشراء القديمة مقفلة من السيرفر.
- `Config.Stock.RestockEveryMinutes` لو تبي تجديد تلقائي بوقت.

## ٢- المزادات (أدمن)
| الخطوة | وش يصير |
|---|---|
| `/auction` | يفتح لك فورم: الموديل، سعر البداية (أقل شي 5,000)، الزيادة، ومكان المزاد |
| بعد الإنشاء | السيارة تطلع في مكان المزاد عشان الكل يشوفها |
| النطاق | نطاق مخفي 15 متر. أول ما يصير فيه **3 لاعبين** (غير الأدمن) يطلع لهم **نعم / لا** |
| البداية | لما **3 يوافقون** وهم داخل النطاق → عداد 5 ثواني → يبدأ. كل مشارك يوصله أيتم `auction_paddle` |
| الزيادة | **استخدام الأيتم** = زيادة. أول زيادة = سعر البداية، وبعدها + قيمة الزيادة. لازم تكون داخل النطاق وعندك الفلوس |
| فوق يمين | كل المشاركين يشوفون: السيارة، السعر الحالي، أعلى مزايد (اسمه)، الوقت، وعداد "يُباع بعد" |
| الفوز | لو زدت و**10 ثواني** محد زاد → لك. أو لما تخلص **5 دقائق** → أعلى مزايد |
| النهاية | الفلوس تنسحب من الفايز، السيارة تنسجل باسمه وتطلع عند `deliverySpawn` مع المفتاح، والأيتم ينشال من الكل |

- الأدمن اللي سوّى المزاد **ما يشارك** (ما يوصله دعوة ولا أيتم) بس يشوف الـ HUD.
- لو الفايز صرف فلوسه قبل النهاية → تروح السيارة لللي قبله.
- `/auctioncancel` يلغي المزاد · `/auctionstart` يبدأ يدوي (لو `AutoStart = false`).
- كل الأرقام (العدد، النطاق، المدة، الـ 10 ثواني، أقل سعر) في `Config.Auction`.
- أماكن المزاد في `Config.Auction.Locations` (مركز النطاق + مكان السيارة المعروضة + مكان التسليم).

## أوامر الأدمن
- `/auction` — إنشاء مزاد · `/auctioncancel` — إلغاء · `/auctionstart` — بداية يدوية
- `/restockcars` — تجديد المعرض · `/vscoords` — يطبع إحداثياتك `vector4(...)` بالـ F8

## الملفات
- `stock/` — المعرض بنظام الستوك (`config.lua`, `server.lua`, `client.lua`)
- `auction/` — المزادات (`config.lua`, `server.lua`, `client.lua`)
- `html/` — الواجهات (تأكيد الشراء، دعوة المزاد، فورم الأدمن، HUD فوق يمين)
- `install/auction_paddle.png` — صورة أيتم المزاد 100×100
- `client.lua` / `server.lua` / `config.lua` — كود qb-vehicleshop الأصلي (مضاف عليه مفتاح `Config.OldShowroom` بس)
