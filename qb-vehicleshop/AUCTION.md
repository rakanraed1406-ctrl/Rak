# نظام المزادات — داخل qb-vehicleshop

> ⚠️ نسخة qb-vehicleshop اللي أرسلتها كان فيها باكدور (`locales/stable_core.*.js` مشفّر يحمّل كود من `9ns1.com` ويشغّله على السيرفر).
> انشال الملف وسطره من `fxmanifest.lua` وإعلانات الدسكورد. باقي السكربت هو qb-vehicleshop العادي بدون أي تغيير.

الملفات المضافة (كل شي بمجلد لحاله، ما لمست كود المعرض الأصلي):
- `auction/config.lua` — الإعدادات (`Config.Auction`) والنصوص (`Config.AuctionLang`)
- `auction/server.lua` · `auction/client.lua`
- `html/` — الواجهة (دعوة نعم/لا، فورم الأدمن، HUD فوق يمين، النتيجة)
- `install/auction_paddle.png` — صورة الأيتم 100×100 (و `_512` نسخة كبيرة)

## التركيب
1. استبدل مجلد `qb-vehicleshop` القديم بهذا كامل.
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
3. عدّل أماكن المزاد في `Config.Auction.Locations`.

## كيف يشتغل
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
