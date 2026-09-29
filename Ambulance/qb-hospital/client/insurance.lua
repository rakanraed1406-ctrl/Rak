local QBCore = exports['qb-core']:GetCoreObject()

-- Insurance desk menu. Built from what the SERVER says right now (the old menu
-- used stale player data, so an expired insurance still looked valid).
RegisterNetEvent("Insurance:firstmenu", function()
    QBCore.Functions.TriggerCallback('insurance:server:GetStatus', function(status)
        status = status or { active = false }
        local menu = {
            { header = "Medical Center", icon = "fa-solid fa-hospital", isMenuHeader = true },
        }
        if status.active then
            local left = status.daysLeft > 0 and (status.daysLeft .. ' day(s) ' .. status.hoursLeft .. 'h') or (status.hoursLeft .. 'h')
            menu[#menu + 1] = {
                header = "Health insurance: ACTIVE",
                txt = "Expires: " .. status.expires .. "<br>Time left: " .. left,
                icon = "fa-solid fa-shield-heart",
                isMenuHeader = true,
            }
            menu[#menu + 1] = {
                header = ("Extend by %d days for %s $"):format(Config.insuranceDays or 7, Config.insurancePrice),
                txt = "Added on top of the time you still have",
                icon = "fa-regular fa-calendar-plus",
                params = { event = "Insurance:Confirm", args = { renew = true } },
            }
        else
            menu[#menu + 1] = {
                header = "Health insurance: NONE",
                txt = "Without insurance you lose your items when you respawn and pay the full hospital bill",
                icon = "fa-solid fa-shield",
                isMenuHeader = true,
            }
            menu[#menu + 1] = {
                header = ("Buy %d days of insurance for %s $"):format(Config.insuranceDays or 7, Config.insurancePrice),
                icon = "fa-regular fa-hospitals",
                params = { event = "Insurance:Confirm", args = { renew = false } },
            }
        end
        menu[#menu + 1] = {
            header = "Maybe later..",
            txt = "Close the menu",
            icon = "fa-solid fa-xmark",
            params = { event = "qb-menu:client:closeMenu" },
        }
        exports['qb-menu']:openMenu(menu)
    end)
end)

RegisterNetEvent('Insurance:Confirm', function(data)
    local renew = type(data) == 'table' and data.renew
    local alert = lib.alertDialog({
        header = renew and 'Extend Insurance' or 'Insurance Confirmation',
        content = ("%s health insurance for %d days — %s$ from your bank?"):format(renew and 'Extend your' or 'Buy', Config.insuranceDays or 7, Config.insurancePrice),
        centered = true,
        cancel = true
    })
    if alert == 'confirm' then
        TriggerServerEvent('insurance:server:code')
    end
end)
