-- إخفاء الكاش (3, 4, 13) صار داخل الـ loop الوحيد اللي يشتغل كل فريم في client/thick.lua

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
