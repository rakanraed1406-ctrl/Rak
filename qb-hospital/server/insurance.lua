local QBCore = exports['qb-core']:GetCoreObject()

-- Health insurance.
-- The expiry is kept in metadata "timerinsurance" as "d/m/YYYY HH:MM" (same format
-- as before, so old saves keep working) and is always compared as a real date.
-- Before: it was compared as text (so a date from last month could still count as
-- valid), the menu showed stale data, and "jabertestcode" stored a true/false in
-- metadata "insurance" which then crashed the menu.

local function FormatExpiry(ts)
    return os.date('%d/%m/%Y %H:%M', ts)
end

-- Clears an insurance that already ran out, so every screen agrees it is gone.
local function ClearIfExpired(Player)
    if not Player then return end
    local meta = Player.PlayerData.metadata
    local ts = HospitalInsuranceExpiry(Player)
    if ts and ts > os.time() then
        if type(meta['insurance']) ~= 'number' or meta['insurance'] < 1 then
            Player.Functions.SetMetaData('insurance', 1)
        end
    elseif (meta['timerinsurance'] or '') ~= '' or meta['insurance'] ~= 0 then
        Player.Functions.SetMetaData('timerinsurance', '')
        Player.Functions.SetMetaData('insurance', 0)
    end
end

local function Status(Player)
    ClearIfExpired(Player)
    local ts = HospitalInsuranceExpiry(Player)
    local now = os.time()
    if ts and ts > now then
        local left = ts - now
        return { active = true, expires = FormatExpiry(ts), daysLeft = math.floor(left / 86400), hoursLeft = math.floor((left % 86400) / 3600) }
    end
    return { active = false }
end

QBCore.Functions.CreateCallback('insurance:server:GetStatus', function(source, cb)
    cb(Status(QBCore.Functions.GetPlayer(source)))
end)

-- kept for other scripts that still ask the old way
QBCore.Functions.CreateCallback("insurance:timer:call", function(source, cb)
    cb(Status(QBCore.Functions.GetPlayer(source)).active)
end)

-- Buy / renew: a renewal adds the days on top of the time you still have left.
RegisterNetEvent("insurance:server:code", function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local price = tonumber(Config.insurancePrice) or 250
    local days = tonumber(Config.insuranceDays) or 7

    if not Player.Functions.RemoveMoney('bank', price, "bought-insurance") then
        TriggerClientEvent('QBCore:Notify', src, "You don't have enough money in the bank for this.", "error", 4000)
        return
    end

    local current = HospitalInsuranceExpiry(Player)
    local base = (current and current > os.time()) and current or os.time()
    local expiry = base + days * 86400
    Player.Functions.SetMetaData('insurance', 1)
    Player.Functions.SetMetaData('timerinsurance', FormatExpiry(expiry))
    TriggerClientEvent('QBCore:Notify', src, ('Health insurance active until %s.'):format(FormatExpiry(expiry)), 'success', 6000)
end)

-- Old event name: now only clears an insurance that really expired
-- (it used to wipe any insurance, even a valid one, for whoever sent it).
RegisterNetEvent("jabertestcode", function()
    local src = source
    if not src or src == '' then return end
    ClearIfExpired(QBCore.Functions.GetPlayer(src))
end)

-- players who log in with an expired insurance get it cleared straight away
AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    ClearIfExpired(Player)
end)
