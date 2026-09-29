--[[ client/recruitment.lua - applicant-side EMS application menu (qb-menu / qb-input) ]]

local QBCore = MDTClient.QBCore

local function OpenApplicationMenu()
    local elements = {
        { header = '🚑 EMS Recruitment', isMenuHeader = true },
        { header = '📝 Submit Application', txt = 'Apply to join EMS (paramedics)', params = { event = 'ems-mdt:client:SubmitApplication' } },
        { header = '📄 Check Application Status', txt = 'View the status of your latest application', params = { event = 'ems-mdt:client:CheckApplicationStatus' } },
    }
    exports['qb-menu']:openMenu(elements)
end

RegisterCommand(Config.ApplicationCommand or 'emsapp', function()
    OpenApplicationMenu()
end, false)

RegisterNetEvent('ems-mdt:client:SubmitApplication', function()
    local PlayerData = QBCore.Functions.GetPlayerData()

    if PlayerData.job and PlayerData.job.name == Config.JobName then
        QBCore.Functions.Notify('You are already employed by EMS.', 'error')
        return
    end

    local defaultName = ''
    if PlayerData.charinfo then
        defaultName = (PlayerData.charinfo.firstname or '') .. ' ' .. (PlayerData.charinfo.lastname or '')
    end

    local dialog = exports['qb-input']:ShowInput({
        header = 'EMS Application',
        submitText = 'Submit',
        inputs = {
            { text = 'Full Name', name = 'name', type = 'text', isRequired = true, default = defaultName },
            { text = 'Age', name = 'age', type = 'number', isRequired = true },
            { text = 'Medical / First-aid Experience', name = 'experience', type = 'text', isRequired = true },
            { text = 'Contact Number', name = 'contact', type = 'text', isRequired = false },
        }
    })

    if not dialog then return end -- player cancelled

    local age = tonumber(dialog.age)
    if not age or age < 18 or age > 90 then
        QBCore.Functions.Notify('Please enter a valid age (18-90).', 'error')
        return
    end

    if not dialog.name or dialog.name:gsub('%s+', '') == '' or not dialog.experience or dialog.experience:gsub('%s+', '') == '' then
        QBCore.Functions.Notify('Please fill in all required fields.', 'error')
        return
    end

    TriggerServerEvent('ems-mdt:server:SubmitApplication', {
        name = dialog.name,
        age = age,
        experience = dialog.experience,
        contact = dialog.contact or 'N/A'
    })
end)

RegisterNetEvent('ems-mdt:client:CheckApplicationStatus', function()
    TriggerServerEvent('ems-mdt:server:RequestApplicationStatus')
end)

RegisterNetEvent('ems-mdt:client:ReceiveApplicationStatus', function(status)
    if not status then
        QBCore.Functions.Notify('You have not submitted any application yet.', 'error')
        return
    end

    local notifyType = 'primary'
    if status == 'Accepted' then notifyType = 'success' end
    if status == 'Rejected' then notifyType = 'error' end

    QBCore.Functions.Notify(('Application Status: %s'):format(status), notifyType, 7000)
end)
