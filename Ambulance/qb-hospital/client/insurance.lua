local QBCore = exports['qb-core']:GetCoreObject()

RegisterNetEvent("Insurance:firstmenu")
AddEventHandler("Insurance:firstmenu", function()
    QBCore.Functions.TriggerCallback("insurance:timer:call",function(Insurancetimer)
        if Insurancetimer then
        else
            TriggerServerEvent("jabertestcode")
        end
    local Menu = {}
    local disable = false
    Menu[#Menu + 1] = {
        header = "Medical Center",
        icon = "fa-solid fa-hospital",
        isMenuHeader = true
    }
    local plyData = QBCore.Functions.GetPlayerData()
    if ((plyData.metadata["insurance"] and plyData.metadata["insurance"] >= 1)) then
        Menu[#Menu + 1] = {
            header = "Expire Health insurance:<br>"..plyData.metadata["timerinsurance"],
            icon = "fa-sharp fa-regular fa-calendar-clock",
            isMenuHeader = true
        }
    end
    local plyData = QBCore.Functions.GetPlayerData()
    if ((plyData.metadata["insurance"] and plyData.metadata["insurance"] >= 1)) then
        disable = true
    else
        disable = false
    end
    Menu[#Menu + 1] = {
        header = "Request health insurance For: "..Config.insurancePrice.." $",
        icon = "fa-regular fa-hospitals",
        disabled = disable,
        params = {
            event = "Insurance:Confirm"
        }
    }
    Menu[#Menu + 1] = {
        header = "Maybe later..",
        txt = "Here You Can Close The Menu And Come Back Soon",
        icon = "fa-duotone fa-clock",
        params = {
            event = "closeevent"
        }
    }
    exports['qb-menu']:openMenu(Menu)
end)
end)

RegisterNetEvent('Insurance:Confirm', function()
    TriggerServerEvent("jabertestcode")
    local alert = lib.alertDialog({
        header = 'Insurance Confirmation',
        content = "You Wan't to buy Insurance With " .. Config.insurancePrice .. "$ In bank ?",
        centered = true,
        cancel = true
    })
    if alert then
        if alert == 'confirm' then
            TriggerServerEvent('insurance:server:code')
        end
    end
end)
