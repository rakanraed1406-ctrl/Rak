local QBCore = exports["qb-core"]:GetCoreObject()

QBCore.Functions.CreateCallback('qb-radialmenu:server:HasItem', function(source, cb, itemName)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player ~= nil then
      local Item = Player.Functions.GetItemByName(itemName)
        if Item ~= nil then
			cb(true)
        else
			cb(false)
        end
	end
end)

RegisterNetEvent('hotel:server:LogoutLocation', function()
  local src = source
  local Player = QBCore.Functions.GetPlayer(src)
  local MyItems = Player.PlayerData.items
  MySQL.Async.execute('UPDATE players SET inventory = ? WHERE citizenid = ?',
      {json.encode(MyItems), Player.PlayerData.citizenid})
  QBCore.Player.Logout(src)
  TriggerClientEvent('qb-multicharacter:client:chooseChar', src)
end)

RegisterNetEvent('qb-radialmenu:server:GiveCash', function()
  local src = source
  local players = {}
  local MyPed = GetPlayerPed(src)
  local MyCoords = GetEntityCoords(MyPed)
  local PlayersTable = QBCore.Functions.GetQBPlayers()
  for k, v in pairs(PlayersTable) do
    if v.PlayerData.source ~= src then 
        local targetped = GetPlayerPed(v.PlayerData.source)
        local TargetCoords = GetEntityCoords(targetped)
        if #(MyCoords - TargetCoords) <= 7 then 
            local ped = QBCore.Functions.GetPlayer(v.PlayerData.source)
            players[#players+1] = {
                name = ped.PlayerData.charinfo.firstname .. ' ' .. ped.PlayerData.charinfo.lastname,
                id = v.PlayerData.source,
                citizenid = ped.PlayerData.citizenid,
            }
        end
    end
  end
  if #players > 0 then 
    TriggerClientEvent('qb-radialmenu:client:GiveCashSecond', src, players)
  else
    QBCore.Functions.Notify(src, 'No one here', 'error', 7500)
  end
end)

RegisterNetEvent('qb-radialmenu:server:GiveCashFinal', function(playerId, amount)
  local src = source
  local Player = QBCore.Functions.GetPlayer(src)
  local OtherPlayer = QBCore.Functions.GetPlayer(playerId)
  local myCoords = GetEntityCoords(GetPlayerPed(source))

  if OtherPlayer then
    local TargetCoords = GetEntityCoords(GetPlayerPed(OtherPlayer.PlayerData.source))
    if #(myCoords - TargetCoords) <= 10 then 
      if Player.PlayerData.money.cash and Player.PlayerData.money.cash > tonumber(amount) then 
        if Player.Functions.RemoveMoney('cash', tonumber(amount), 'Give Cash') then 
          OtherPlayer.Functions.AddMoney('cash', tonumber(amount), 'Received Cash From '..GetPlayerName(src)..'')
          local name = ''..OtherPlayer.PlayerData.charinfo.firstname..'  '..OtherPlayer.PlayerData.charinfo.lastname..''
          local name1 = ''..Player.PlayerData.charinfo.firstname..'  '..Player.PlayerData.charinfo.lastname..''
          TriggerClientEvent('QBCore:Notify', src, "You Gave "..name.." Amount $"..tonumber(amount).."", "success", 4500)
          TriggerClientEvent('QBCore:Notify', OtherPlayer.PlayerData.source, "You Received Amount $"..tonumber(amount).." From "..name1.."", "success", 4500)
        end
      else
        QBCore.Functions.Notify(src, 'You don\'t have cash', 'error', 7500)
      end
    else
        TriggerClientEvent('QBCore:Notify', src, "Person is to far from you", "error", 4500)
    end
  end
end)

QBCore.Commands.Add("f1reset", "Reset the F1.", {}, false, function(source, args)
  TriggerClientEvent('qb-radialmenu:client:refresh', source)
end)

-- QBCore.Commands.Add('char1', "", {}, false, function(source)
--   local src = source
--   TriggerClientEvent('QBCore:Client:OnPlayerLoaded', src)
-- end, 'god')
