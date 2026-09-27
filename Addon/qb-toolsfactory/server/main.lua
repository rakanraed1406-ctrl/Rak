local QBCore = exports['qb-core']:GetCoreObject()




CreateThread(function()
    while true do 
        UpdateStore()
        Wait(Config.RefreshTime * (60 * 1000))
        -- Wait(5000)
    end
end)

function UpdateStore()
    Config.Items = {}
    for i = 1, #Config.GlobalItems do 
        Wait(100)
        Config.Items[#Config.Items + 1] = {
            name = Config.GlobalItems[i].name,
            price = math.random(Config.GlobalItems[i].minPrice, Config.GlobalItems[i].maxPrice),
            amount = Config.GlobalItems[i].dAmount + math.random(50, 100),
            info = {},
            type = "item",
            slot = #Config.Items + 1,
        }
    end
end

QBCore.Functions.CreateCallback('qb-toolsfactory:server:getconfig', function(source, cb)
    cb(Config.Items)
end)

RegisterNetEvent('qb-toolsfactory:server:UpdateShopItems', function(itemData, amount)
    for i = 1, #Config.Items, 1 do 
        if not Config.Items[i].name then return end
        if Config.Items[i].name == itemData.name then 
            if Config.Items[i].amount >= tonumber(amount) then 
                Config.Items[i].amount = Config.Items[i].amount - tonumber(amount)
                if Config.Items[i].amount < 0 then 
                    Config.Items[i].amount = 0 
                end
            end
            break
        end
    end
end)

QBCore.Functions.CreateCallback('qb-toolsfactory:server:toolsfactoryinvecanbuy', function(source, cb, itemData, amount)
    local answer = false
    for i = 1, #Config.Items, 1 do 
        if not Config.Items[i].name then cb(false) return end
        if Config.Items[i].name == itemData.name then 
            if Config.Items[i].amount >= tonumber(amount) then 
                answer = true
            end
        end
    end
    cb(answer)
end)
