local QBCore = exports['qb-core']:GetCoreObject()


QBCore.Functions.CreateCallback("insurance:timer:call", function(source, cb, args)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local current_time = os.time()
    local jaber = os.date("%d/%m/%Y %H:%M", current_time):gsub("0*(%d+)/0*(%d+)/", "%1/%2/") 
    if jaber >= Player.PlayerData.metadata["timerinsurance"] then
        cb(false)
        else
        cb(true)
    end
end)

RegisterNetEvent("insurance:server:code", function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local bankBalance = Player.PlayerData.money["bank"]
    local current_time = os.time()
    local one_week_later = current_time + (7 * 24 * 60 * 60)
    local jaber = os.date("%d/%m/%Y %H:%M", one_week_later):gsub("0*(%d+)/0*(%d+)/", "%1/%2/")  -- formatted as string
    if bankBalance >= Config.insurancePrice then
        TriggerClientEvent('QBCore:Notify', src, 'You have an insurance now', 'success', 3000)
        if Player.Functions.RemoveMoney('bank', Config.insurancePrice, "bought-insurance") then
            Player.Functions.SetMetaData('insurance', (Player.PlayerData.metadata['insurance'] or 0) + 1)
            Player.Functions.SetMetaData('timerinsurance', jaber)
        end
    else
        TriggerClientEvent('QBCore:Notify', src, "You don't have enough money to buy this", "error", 3000)
    end
end)

RegisterNetEvent("jabertestcode", function(args)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	if Player then
		Player.Functions.SetMetaData('insurance', Player.PlayerData.metadata['insurance'] == 0)
        Player.Functions.SetMetaData('timerinsurance', "")
	end
end)
