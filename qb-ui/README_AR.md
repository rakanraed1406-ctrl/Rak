# qb-ui — Command UI (واجهة جديدة)

> انشالت إعلانات الدسكورد. ما كان فيه كود مخفي، بس كان فيه **أخطاء تخرّب السكربت** (تحت).

كل الـ exports والأحداث نفسها: `DrawText` … `DrawText10`, `HideText`, `KeyPressed`, `DrawBlackUi`, `HideBlackUi`, `StartLockPickCircle`
والأحداث `qb-core:client:DrawText / ChangeText / HideText / KeyPressed` و `qb-lockpick:client:openLockpick`.

## الأجزاء (كلها بنفس هوية الراديال منيو و qb-menu و qb-input)
- **DrawText** (تحت بالنص): لو النص يبدأ بـ `[E]` يطلع حرف E كزر، وإلا تطلع الأيقونة. تغيير النص وهو ظاهر يتبدّل بنعومة بدل ما يطلع وينزل. `KeyPressed` يسوي حركة ضغطة + صوت.
- **الإشعارات (جديد — كانت خربانة)**: `exports['qb-ui']:Notify(text, type, length, caption, icon)` أو `TriggerEvent('qb-ui:client:notify', text, type, length)`.
  الأنواع: `primary` `success` `error` `warning` `police` `ambulance`. شريط وقت، حد أقصى 5، والإشعار المكرر ما يتكدّس — يطلع عليه `×2`.
- **DrawBlackUi / HideBlackUi**: خلفية كحلية للشاشة (مثل عداد الرسبون) + صندوق النص فوق. تحديث النص (العداد) ما يعيد الأنيميشن.
- **Lockpick**: نفس قوانين اللعبة ونفس السرعة، رسم جديد (حلقة كحلي + منطقة زرقاء + رقم بالنص + نقاط التقدّم). `Esc` = انسحاب.

## الأخطاء اللي انحلت
- **اللوكبيك كان ما يشتغل أبداً**: سطر `qb` زايد بالكود يطلع error، والنتيجة كانت تنرسل لسكربت اسمه `Rc2-ui` (مو موجود) → اللاعب يعلق والماوس/الكيبورد مقفولة.
- اللوكبيك بالـ Lua كان يلف loop كل 5ms طول اللعبة — صار promise بدون loop.
- الإشعارات القديمة كانت تستورد ملف `testing.js` مو موجود وتنتظر callback `getNotifyConfig` مو مسجّل → ما تشتغل.
- أي رسالة NUI ثانية كانت تخفي الـ DrawText.
- حدث `ChangeText` و `KeyPressed` كانوا ينادون دوال مو موجودة (error).
- حدث `openLockpick` كان ينادي `exports['qb-lock']` بمتغير مو معرّف.

## الأداء
شلت Vue و Quasar و jQuery و Font Awesome 5 و Roboto (كلها كانت تتحمّل مع كل تشغيل). بدون `backdrop-filter`، بدون أنيميشن شغال على طول، كل جزء `display:none` وهو مخفي، ورسم اللوكبيك بس وقت اللعب، ومحرّك الصوت ينام إذا ما فيه شي.

## الأصوات
نفس مجموعة أصوات باقي الواجهات. `html/index.html`:
`UiSfx.enabled`, `UiSfx.volume`, و `UiSfx.parts = { drawtext, notify, lockpick, info }` لو تبي تطفي صوت جزء معيّن.

## الألوان
متغيرات `--rm-*` أعلى `html/css/ui.css`. ألوان أنواع الإشعارات في `NOTE_TYPES` داخل `html/js/ui.js`.
