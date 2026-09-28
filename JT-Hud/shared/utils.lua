
Utils           = {}
Utils.Functions = {}

function Utils.Functions:printTable(tbl, indent)
    indent = indent or 0
    if type(tbl) == "table" then
        for k, v in pairs(tbl) do
            local t   = type(v)
            local fmt = ("%s ^3%s:^0"):format(string.rep("  ", indent), k)
            if     t == "table"   then print(fmt); Utils.Functions:printTable(v, indent + 1)
            elseif t == "boolean" then print(("%s^1 %s ^0"):format(fmt, v))
            elseif t == "number"  then print(("%s^5 %s ^0"):format(fmt, v))
            elseif t == "string"  then print(("%s ^2%s ^0"):format(fmt, v))
            else                       print(("%s^2 %s ^0"):format(fmt, v)) end
        end
    else
        print(("%s ^0%s"):format(string.rep("  ", indent), tbl))
    end
end

function Utils.Functions:debugPrint(tbl, indent)
    if not Config.DebugPrint then return end
    print(("\x1b[ qb-hud : DEBUG]\x1b"))
    Utils.Functions:printTable(tbl, indent)
    print("\x1b[ END DEBUG ]\x1b")
end

function Utils.Functions:hasResource(name)
    return GetResourceState(name):find("start") ~= nil
end

function Utils.Functions:GetFramework()
    if not Utils.Functions:hasResource("qb-core") then return false end
    return exports["qb-core"]:GetCoreObject()
end

function Utils.Functions:CustomNotify(source, title, notifyType, text, duration, icon)
    -- اضف هنا اي نظام نوتيفيكيشن ثاني
end

function Utils.Functions:CustomFuelExport(vehicle)
    return GetVehicleFuelLevel(vehicle)
end

function Utils.Functions:CustomVoiceResource()
    -- اضف events صوت مخصصة هنا
end

function Utils.Functions:HUD_CodeToElement(code)
    local map = {
        [1]="voice",[2]="health",[3]="armor",[4]="oxygen",
        [5]="stamina",[6]="stress",[7]="terminal",[8]="leaf",[9]="vehicle"
    }
    return map[code] or "voice"
end
