local QBCore = exports["qb-core"]:GetCoreObject()

-- The hotel logout option is commented out in config.lua. While it is off the
-- server ignores the event too (otherwise anyone could trigger an instant
-- logout from anywhere — combat logging / escaping the police).
local AllowHotelLogout = false

local GIVE_CASH_DISTANCE = 7.0
local MAX_GIVE_CASH = 10000000

local cooldowns = {}
local function cooldown(src, key, ms)
    local now = GetGameTimer()
    local list = cooldowns[src]
    if not list then list = {}; cooldowns[src] = list end
    if list[key] and now - list[key] < ms then return false end
    list[key] = now
    return true
end
AddEventHandler('playerDropped', function() cooldowns[source] = nil end)

local function distance(a, b)
    local pa, pb = GetPlayerPed(a), GetPlayerPed(b)
    if pa == 0 or pb == 0 then return math.huge end
    return #(GetEntityCoords(pa) - GetEntityCoords(pb))
end

local function hasItem(src, Player, itemName)
    if GetResourceState('qb-inventory') == 'started' then
        local ok, has = pcall(function() return exports['qb-inventory']:HasItem(src, itemName, 1) end)
        if ok and has ~= nil then return has and true or false end
    end
    if Player.Functions.GetItemByName then
        return Player.Functions.GetItemByName(itemName) ~= nil
    end
    return false
end

QBCore.Functions.CreateCallback('qb-radialmenu:server:HasItem', function(source, cb, itemName)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player or type(itemName) ~= 'string' then return cb(false) end -- always answer, the client waits for it
    cb(hasItem(source, Player, itemName))
end)

RegisterNetEvent('hotel:server:LogoutLocation', function()
    local src = source
    if not AllowHotelLogout or not cooldown(src, 'logout', 10000) then return end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    MySQL.update('UPDATE players SET inventory = ? WHERE citizenid = ?', { json.encode(Player.PlayerData.items), Player.PlayerData.citizenid })
    QBCore.Player.Logout(src)
    TriggerClientEvent('qb-multicharacter:client:chooseChar', src)
end)

RegisterNetEvent('qb-radialmenu:server:GiveCash', function()
    local src = source
    if not cooldown(src, 'givecashlist', 1500) then return end
    local players = {}
    for _, v in pairs(QBCore.Functions.GetQBPlayers()) do
        local id = v.PlayerData.source
        if id ~= src and distance(src, id) <= GIVE_CASH_DISTANCE then
            players[#players + 1] = { id = id } -- (citizenids are not sent to the client any more)
        end
    end
    if #players > 0 then
        TriggerClientEvent('qb-radialmenu:client:GiveCashSecond', src, players)
    else
        TriggerClientEvent('QBCore:Notify', src, 'No one here', 'error', 7500)
    end
end)

RegisterNetEvent('qb-radialmenu:server:GiveCashFinal', function(playerId, amount)
    local src = source
    if not cooldown(src, 'givecash', 1500) then return end
    local target = tonumber(playerId)
    amount = tonumber(amount)
    -- whole, positive, sane amounts only (no NaN / decimals / negatives)
    if not target or target == src or not amount or amount ~= amount or amount < 1 or amount > MAX_GIVE_CASH then return end
    amount = math.floor(amount)

    local Player = QBCore.Functions.GetPlayer(src)
    local OtherPlayer = QBCore.Functions.GetPlayer(target)
    if not Player or not OtherPlayer then return end
    if distance(src, target) > GIVE_CASH_DISTANCE + 3.0 then
        return TriggerClientEvent('QBCore:Notify', src, "Person is to far from you", "error", 4500)
    end
    if (Player.PlayerData.money.cash or 0) < amount or not Player.Functions.RemoveMoney('cash', amount, 'Give Cash') then
        return TriggerClientEvent('QBCore:Notify', src, "You don't have cash", 'error', 7500)
    end
    OtherPlayer.Functions.AddMoney('cash', amount, 'Received Cash From ' .. GetPlayerName(src))
    local name = OtherPlayer.PlayerData.charinfo.firstname .. ' ' .. OtherPlayer.PlayerData.charinfo.lastname
    local name1 = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    TriggerClientEvent('QBCore:Notify', src, "You Gave " .. name .. " Amount $" .. amount, "success", 4500)
    TriggerClientEvent('QBCore:Notify', target, "You Received Amount $" .. amount .. " From " .. name1, "success", 4500)
    TriggerEvent('qb-log:server:CreateLog', 'givecash', 'Give Cash', 'green',
        ('%s (%s) gave $%s to %s (%s)'):format(name1, Player.PlayerData.citizenid, amount, name, OtherPlayer.PlayerData.citizenid))
end)

QBCore.Commands.Add("f1reset", "Reset the F1.", {}, false, function(source)
    TriggerClientEvent('qb-radialmenu:client:refresh', source)
end)
