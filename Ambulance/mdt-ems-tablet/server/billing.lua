--[[
    server/billing.lua - Medical bills. All medics bill / view; void = author or Command.
    With Config.Billing.ChargePatient the patient must be online and next to the
    medic (checked here, not trusted from the client) and the money goes to the
    EMS treasury. Otherwise the bill is only recorded (like police citations).
]]
local QBCore = MDT.QBCore
local BCfg = Config.Billing or {}

local function SendBills(src)
    exports.oxmysql:execute(
        'SELECT id, citizenid, medic_name, patient_name, patient_cid, treatment, amount, paid, notes, created_at FROM ' ..
        MDT.Tables.Bills .. ' ORDER BY created_at DESC LIMIT 150',
        {}, function(rows) TriggerClientEvent('ems-mdt:client:ReceiveBills', src, rows or {}) end
    )
end

RegisterNetEvent('ems-mdt:server:GetBills', function()
    local src = source
    if not MDT.IsEmployee(QBCore.Functions.GetPlayer(src)) then return end
    SendBills(src)
end)

RegisterNetEvent('ems-mdt:server:IssueBill', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsEmployee(Player) or type(data) ~= 'table' then return end
    if not Player.PlayerData.job.onduty then
        TriggerClientEvent('QBCore:Notify', src, 'You must be on duty to bill patients.', 'error')
        return
    end

    local treatment = MDT.Clean(data.treatment, 255)
    local notes = MDT.Clean(data.notes, 255)
    local amount = math.floor(tonumber(data.amount) or 0)
    if treatment == '' or amount <= 0 or amount > (BCfg.MaxAmount or 50000) then
        TriggerClientEvent('QBCore:Notify', src, ('Treatment and an amount between $1 and $%d are required.'):format(BCfg.MaxAmount or 50000), 'error')
        return
    end

    local patientName, patientCid, Patient
    local targetId = tonumber(data.serverId)
    if targetId then
        Patient = QBCore.Functions.GetPlayer(targetId)
        if not Patient or targetId == src then
            TriggerClientEvent('QBCore:Notify', src, 'That patient is not available.', 'error')
            return
        end
        local a, b = GetPlayerPed(src), GetPlayerPed(targetId)
        if a == 0 or b == 0 or #(GetEntityCoords(a) - GetEntityCoords(b)) > (Config.HireDistance or 3.0) + 3.0 then
            TriggerClientEvent('QBCore:Notify', src, 'The patient must be next to you to be billed.', 'error')
            return
        end
        patientName, patientCid = MDT.GetName(Patient), Patient.PlayerData.citizenid
    else
        patientName = MDT.Clean(data.patientName, 100)
        patientCid = MDT.Clean(data.patientCid, 50):upper()
        if patientName == '' then
            TriggerClientEvent('QBCore:Notify', src, 'Pick a nearby patient or type a name.', 'error')
            return
        end
    end

    if not MDT.CheckCooldown('bill', Player.PlayerData.citizenid) then
        TriggerClientEvent('QBCore:Notify', src, 'Please wait a moment before issuing another bill.', 'error')
        return
    end

    local paid = 0
    if BCfg.ChargePatient and Patient then
        if Patient.Functions.RemoveMoney(BCfg.Account or 'bank', amount, 'ems-medical-bill') then
            paid = 1
            MDT.AddSocietyMoney(math.floor(amount * (tonumber(BCfg.TreasuryShare) or 1.0)))
            TriggerClientEvent('QBCore:Notify', Patient.PlayerData.source,
                ('Medical bill: $%d for %s (%s).'):format(amount, treatment, MDT.GetName(Player)), 'primary', 8000)
        else
            TriggerClientEvent('QBCore:Notify', src, 'The patient cannot afford this bill — it was recorded as unpaid.', 'error')
            TriggerClientEvent('QBCore:Notify', Patient.PlayerData.source,
                ('Unpaid medical bill: $%d for %s.'):format(amount, treatment), 'error', 8000)
        end
    end

    exports.oxmysql:execute(
        'INSERT INTO ' .. MDT.Tables.Bills .. ' (citizenid, medic_name, patient_name, patient_cid, treatment, amount, paid, notes) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        { Player.PlayerData.citizenid, MDT.GetName(Player), patientName, patientCid ~= '' and patientCid or nil, treatment, amount, paid, notes },
        function()
            TriggerClientEvent('QBCore:Notify', src, ('Bill issued to %s ($%d)%s.'):format(patientName, amount, paid == 1 and ' — paid' or ''), 'success')
            MDT.LogMdtAction(Player, 'Issued Medical Bill', ('%s $%d%s'):format(patientName, amount, paid == 1 and ' (paid)' or ''))
            SendBills(src)
        end
    )
end)

RegisterNetEvent('ems-mdt:server:VoidBill', function(billId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsEmployee(Player) then return end
    billId = tonumber(billId)
    if not billId then return end

    exports.oxmysql:execute('SELECT citizenid, paid FROM ' .. MDT.Tables.Bills .. ' WHERE id = ?', { billId }, function(res)
        if not (res and res[1]) then return end
        if not (res[1].citizenid == Player.PlayerData.citizenid or MDT.IsSeniorCommand(Player)) then
            TriggerClientEvent('QBCore:Notify', src, 'You are not authorized to void this bill.', 'error')
            return
        end
        if tonumber(res[1].paid) == 1 and not MDT.IsSeniorCommand(Player) then
            TriggerClientEvent('QBCore:Notify', src, 'Paid bills can only be removed by Command.', 'error')
            return
        end
        exports.oxmysql:execute('DELETE FROM ' .. MDT.Tables.Bills .. ' WHERE id = ?', { billId }, function()
            MDT.LogMdtAction(Player, 'Voided Medical Bill', 'Bill #' .. billId)
            SendBills(src)
        end)
    end)
end)
