CreateThread(function()
    while true do
        -- إخفاء عداد الفلوس والوقت والأسلحة الافتراضي لـ GTA V
        HideHudComponentThisFrame(3) -- CASH
        HideHudComponentThisFrame(4) -- MP_CASH
        HideHudComponentThisFrame(13) -- CASH_CHANGE
        
        -- إذا كنت تريد إخفاء عناصر أخرى مثل الخريطة المصغرة (الرادار) أو الأسلحة يمكنك تفعيل الأسطر بالأسفل:
        -- HideHudComponentThisFrame(2) -- WEAPON_ICON
        -- DisplayRadar(false) -- لإخفاء الخريطة الدائرية تماماً
        
        Wait(0) -- ضروري جداً لعدم تعليق اللعبة
    end
end)

-- الواتر مارك يشتغل تلقائياً مع تشغيل الريسورس
-- لا يحتاج فوكس (NuiFocus) لأنه بس عرض، مافيه تفاعل

CreateThread(function()
    SetNuiFocus(false, false)
end)

-- أمر لإخفاء/إظهار الواتر مارك يدوياً (اختياري)
RegisterCommand('togglewatermark', function()
    SendNUIMessage({
        action = "toggle"
    })
end, false)

RegisterKeyMapping('togglewatermark', 'تشغيل/إخفاء الواتر ماركد', 'keyboard', 'F9')
