
-- ══════════════════════════════════════════════
--  CLIENT UTILS — ضع هنا exports مخصصة
-- ══════════════════════════════════════════════

function Utils.Functions:CustomFuelExport(vehicle)
    -- مثال: return GetVehicleFuelLevel(vehicle)
    return GetVehicleFuelLevel(vehicle)
end

function Utils.Functions:CustomVoiceResource()
    -- أضف events نظام صوت مخصص هنا
    --[[
    AddEventHandler("myVoice:setRange", function(mode)
        Koci.Client.HUD.data.bars.voice.range = mode
    end)
    AddEventHandler("myVoice:radioActive", function(active)
        Koci.Client.HUD.data.bars.voice.radio = active
    end)
    --]]
end

exports("SeatbeltState", function(...)
    Koci.Client.HUD:ToggleSeatBelt(...)
end)
