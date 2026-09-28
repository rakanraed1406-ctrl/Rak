local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = QBCore.Functions.GetPlayerData()

RegisterNetEvent('police:client:checkmyfines', function()
    PlayerData = QBCore.Functions.GetPlayerData()
    if PlayerData then 
        if PlayerData.metadata then 
            if PlayerData.metadata.policefines then 
                if PlayerData.metadata.policefines.amount > 0 then 
                    local alert = lib.alertDialog({
                        header = 'Police Fines',
                        content = 'Are you sure you want to pay $ '..PlayerData.metadata.policefines.amount..' ? ',
                        centered = true,
                        cancel = true
                    })
                    if alert then 
                        if alert == 'confirm' then 
                            TriggerServerEvent('qb-police:server:PayMyInvoice')
                        end
                    end
                else
                    QBCore.Functions.Notify('You have no fines', 'error', 7500)
                end
            end
        end
    end
end)
