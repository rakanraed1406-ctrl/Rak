local QBCore = exports['qb-core']:GetCoreObject()



RegisterNetEvent("policejob:weaponlic:firstmenu", function(source)
    if QBCore.Functions.GetPlayerData().job.name == "police" and QBCore.Functions.GetPlayerData().job.grade.level >= 8 then
        exports['qb-menu']:openMenu({
            {
                header = "Weapon License",
                icon = "fa-solid fa-gun",
                isMenuHeader = true
            },
            {
                header = "Create Weapon License",
                icon = "fa-solid fa-plus",
                txt = "",
                params = {
                    event = "policejob:weaponlic:inputinf",
                }
            },
            {
                header = "Revoke License",
                icon = "fa-solid fa-minus",
                txt = "",
                params = {
                    event = "policejob:weaponlic:revolklic",
                },
            },
            {
                header = "Return",
                icon = "fad fa-undo",
                txt = "Return to main menu",
                params = {
                    event = "qb-new:client:openMenu",
                }
            },
        })
    else
        QBCore.Functions.Notify('You must be a lieutenant or higher', 'error')
    end
end)

RegisterNetEvent('policejob:weaponlic:inputinf', function()
    local weaponlic = exports['qb-input']:ShowInput({
        name = 'Weapon License',
        header = 'Create Weapon License | $2500',
        inputs = {
            {
                text = 'Citizen ID',
                name = 'citizenid',
                type = 'text',
                isRequired = true
            },
            {
                text = 'Weapon Type',
                name = 'weapontype',
                type = 'text',
                isRequired = true
            },
            {
                text = 'Weapon Serial Number',
                name = 'weapontsirsype',
                type = 'text',
                isRequired = true
            },
            {
                text = 'Reason for Weapon License',
                name = 'weaponlicreso',
                type = 'text',
                isRequired = true
            },
            {
                text = 'License Expiry Duration Max 30 days',
                name = 'weaponlicexp',
                type = 'number',
                isRequired = true
            },
            {
                text = 'Ammo Count Max 96',
                name = 'weaponammomx',
                type = 'number',
                isRequired = true
            },
            {
                text = 'Payment Method',
                name = 'billtype',
                type = 'radio',
                options = {
                    { value = 'cash', text = 'Cash' },
                    { value = 'bank', text = 'Bank' }
                }
            }
        }
    })
    if weaponlic == nil then return end 
    TriggerServerEvent('policejob:server:createweaponlic', weaponlic)
end)

RegisterNetEvent('policejob:weaponlic:revolklic', function()
    local weaponrevlic = exports['qb-input']:ShowInput({
        name = 'Weapon License',
        header = 'Revoking Weapon License',
        inputs = {
            {
                text = 'Citizen ID',
                name = 'citizenid',
                type = 'text',
                isRequired = true
            },
            {
                text = 'Weapon Serial Number',
                name = 'weapontsirsype',
                type = 'text',
                isRequired = true
            },
            {
                text = 'Reason for License Revocation',
                name = 'weaponlicreso',
                type = 'text',
                isRequired = true
            },
            {
                text = 'Ammo Count at Revocation',
                name = 'weaponammomx',
                type = 'number',
                isRequired = true
            }
        }
    })
    if weaponrevlic == nil then return end 
    TriggerServerEvent('policejob:server:revolkweaponlic', weaponrevlic)
end)

RegisterNetEvent('policejob:client:sendWWebhook', function(info, Player2, Player)
    title = "Creating Weapon License"
    color = 655104
    footer = 'IIPLXA LOG.'
    message = 
    '**[Officer]: **'..Player.PlayerData.charinfo.firstname..Player.PlayerData.charinfo.lastname..'\n'..
    '**[Officer Rank]: **'..Player.PlayerData.job.grade.name..'\n'..
    '**[Citizen]: **'..Player2.PlayerData.charinfo.firstname..Player2.PlayerData.charinfo.lastname..'\n'..
    '**[Weapon Type]: **'..info.weapontype..'\n'..
    '**[Weapon Serial Number]: **'..info.weapontsirsype..'\n'..
    '**[Reason for License Creation]: **'..info.weaponlicreso..'\n'..
    '**[License Expiry Duration]: **'..info.weaponlicexp..'\n'..
    '**[Ammo Count]: **'..info.weaponammomx..'\n'
    TriggerServerEvent('policejob:sendlog', color, title, message, footer)
end)

RegisterNetEvent('policejob:client:sendrevolWebhook', function(info, Player2, Player)
    title = "Revoking Weapon License"
    color = 16711680
    footer = 'IIPLXA LOG.'
    message = 
    '**[Officer]: **'..Player.PlayerData.charinfo.firstname..Player.PlayerData.charinfo.lastname..'\n'..
    '**[Officer Rank]: **'..Player.PlayerData.job.grade.name..'\n'..
    '**[Citizen]: **'..Player2.PlayerData.charinfo.firstname..Player2.PlayerData.charinfo.lastname..'\n'..
    '**[Weapon Serial Number]: **'..info.weapontsirsype..'\n'..
    '**[Reason for License Revocation]: **'..info.weaponlicreso..'\n'..
    '**[Ammo Count at Revocation]: **'..info.weaponammomx..'\n'
    TriggerServerEvent('policejob:sendlog', color, title, message, footer)
end)
