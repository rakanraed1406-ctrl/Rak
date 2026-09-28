local QBCore = exports['qb-core']:GetCoreObject()
--args





RegisterNetEvent('policejob:server:createweaponlic', function(infow)
    local Player = QBCore.Functions.GetPlayer(source)
    local Player2 = QBCore.Functions.GetPlayer(tonumber(infow.citizenid))
    local type = infow.billtype
    local pos = GetEntityCoords(GetPlayerPed(source))
    local pos2 = GetEntityCoords(GetPlayerPed(tonumber(infow.citizenid)))
    local dist = #(pos - pos2)
    if Player.PlayerData.job.name == 'police' then
        if Player.PlayerData.job.onduty then
            if type == 'bank' then
                if dist < 5 then
                    local Amount = Config.WeaponLicPrice
                    local playeramount = Amount * Config.WeaponLicPirs
                    local bossamount = Amount - playeramount
					if Player2.Functions.RemoveMoney('bank', Amount, 'Weapon License Fee') then
                        TriggerClientEvent('policejob:client:sendWWebhook', source, infow, Player2, Player)
                        local licenses = {["driver"] = Player2.PlayerData.metadata["licences"].driver, ['weapon'] = true, ["business"] = Player2.PlayerData.metadata["licences"].business, ["hunt"] = Player2.PlayerData.metadata["hunt"]}
                        Player2.Functions.SetMetaData("licences", licenses)
                        local info = {}
                        info.firstname = Player2.PlayerData.charinfo.firstname
                        info.lastname = Player2.PlayerData.charinfo.lastname
                        info.birthdate = Player2.PlayerData.charinfo.birthdate
                        info.weapontype = infow.weapontype
                        info.weapontsirsype = infow.weapontsirsype
                        Player2.Functions.AddItem("weaponlicense", 1, nil, info)
                        TriggerClientEvent("inventory:client:ItemBox", Player2.PlayerData.source, QBCore.Shared.Items["weaponlicense"], "add")
                        Player.Functions.AddMoney('bank', playeramount, 'Create Weapon License')
                        exports['qb-management']:AddMoney(Player.PlayerData.job.name, bossamount)
                        -----
						TriggerClientEvent('QBCore:Notify', Player2.PlayerData.source, 'You have been charged $ '..Amount..' from your debit card', 'error')
                        TriggerClientEvent('QBCore:Notify', source, 'I charged the person $ '..Amount..' from their debit card', 'success')
                    else
						TriggerClientEvent('QBCore:Notify', source, '!Person does not have enough money in the bank', 'error')
                    end
                else
					TriggerClientEvent('QBCore:Notify', Player2.PlayerData.source, "You're too far!", 'error')
                end
            else
                if dist < 5 then
                    local Amount = Config.WeaponLicPrice
                    local playeramount = Amount * Config.WeaponLicPirs
                    local bossamount = Amount - playeramount
					if Player2.Functions.RemoveMoney('cash', Amount, 'Weapon License Fee') then
                        TriggerClientEvent('policejob:client:sendWWebhook', source, infow, Player2, Player)
                        local licenses = {["driver"] = Player2.PlayerData.metadata["licences"].driver, ['weapon'] = true, ["business"] = Player2.PlayerData.metadata["licences"].business, ["hunt"] = Player2.PlayerData.metadata["hunt"]}
                        Player2.Functions.SetMetaData("licences", licenses)
                        local info = {}
                        info.firstname = Player2.PlayerData.charinfo.firstname
                        info.lastname = Player2.PlayerData.charinfo.lastname
                        info.birthdate = Player2.PlayerData.charinfo.birthdate
                        info.weapontype = infow.weapontype
                        info.weapontsirsype = infow.weapontsirsype
                        Player2.Functions.AddItem("weaponlicense", 1, nil, info)
                        TriggerClientEvent("inventory:client:ItemBox", Player2.PlayerData.source, QBCore.Shared.Items["weaponlicense"], "add")
                        -- Send money to sender job--
						Player.Functions.AddMoney('cash', playeramount, 'Create Weapon License')
                        exports['qb-management']:AddMoney(Player.PlayerData.job.name, bossamount)
                        -----
						TriggerClientEvent('QBCore:Notify', Player2.PlayerData.source, 'You have been charged $' ..Amount, 'error')
                        TriggerClientEvent('QBCore:Notify', source, 'You charged the person $' ..Amount, 'success')
                    else
						TriggerClientEvent('QBCore:Notify', source, 'The person does not have enough money in the cache!', 'error')
                    end
                else
					TriggerClientEvent('QBCore:Notify', Player2.PlayerData.source, "You're too far!", 'error')
                end
            end
        else
			TriggerClientEvent('QBCore:Notify', Player.PlayerData.source, 'You are not on the service!', 'error')
        end
    end
end)

RegisterNetEvent('policejob:server:revolkweaponlic', function(info)
    local Player = QBCore.Functions.GetPlayer(source)
    local Player2 = QBCore.Functions.GetPlayer(tonumber(info.citizenid))
    if Player.PlayerData.job.name == 'police' then
        if Player.PlayerData.job.onduty then
			TriggerClientEvent('QBCore:Notify', Player2.PlayerData.source, 'Your weapon license has been deactivated', 'error')
			TriggerClientEvent('QBCore:Notify', source, 'License deactivated', 'success')

            TriggerClientEvent('policejob:client:sendrevolWebhook', source, info, Player2, Player)
            local licenses = {["driver"] = Player2.PlayerData.metadata["licences"].driver, ['weapon'] = false, ["business"] = Player2.PlayerData.metadata["licences"].business, ["hunt"] = Player2.PlayerData.metadata["hunt"]}
            Player2.Functions.SetMetaData("licences", licenses)
        else
			TriggerClientEvent('QBCore:Notify', Player.PlayerData.source, 'You are not on the service!', 'error')
        end
    end
end)

RegisterServerEvent("policejob:sendlog", function(color, title, message, footer)

    local embedData = {
        {
            ["title"] = "**".. title .."**",
            ["color"] = color,
            ['footer'] = {
              ['text'] = os.date('%c'),
          },
          ['description'] = message,
          ['author'] = {
              ['icon_url'] = '',
          },
        }
    }

  PerformHttpRequest(Config.Webhooklink, function(err, text, headers) end, 'POST', json.encode({username = title, embeds = embedData}), { ['Content-Type'] = 'application/json' })
end)
