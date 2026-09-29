QBCore = exports['qb-core']:GetCoreObject()
EMSServer = {}

local Active = {}     -- [src] = { tool = name, target = src|nil, at = ms, time = ms }
local CprCount = {}   -- [patient] = number of CPR rounds this time down
local DeathAt = {}    -- [patient] = os.time() the heart stopped (VF → asystole on the monitor)

local function IsMedic(Player)
    if not Player or Player.PlayerData.job.name ~= Config.Job then return false end
    return not Config.RequireDuty or Player.PlayerData.job.onduty
end
EMSServer.IsMedic = IsMedic

local function Distance(a, b)
    local pa, pb = GetPlayerPed(a), GetPlayerPed(b)
    if pa == 0 or pb == 0 then return math.huge end
    return #(GetEntityCoords(pa) - GetEntityCoords(pb))
end
EMSServer.Distance = Distance

local function Name(Player)
    local ci = Player and Player.PlayerData.charinfo or {}
    return ((ci.firstname or '') .. ' ' .. (ci.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
end
EMSServer.Name = Name

local function Notify(src, msg, kind)
    TriggerClientEvent('QBCore:Notify', src, msg, kind or 'primary', 5000)
end

-- Every treatment ends up in the patient's record on the EMS tablet (grouped per call).
function EMSServer.Log(medicSrc, patientSrc, text)
    local res = Config.TabletResource
    if not res or res == '' or GetResourceState(res) ~= 'started' then return end
    pcall(function() exports[res]:LogFieldTreatment(medicSrc, patientSrc, text) end)
end

local function PatientState(Target)
    local meta = Target.PlayerData.metadata or {}
    return meta.isdead == true, meta.inlaststand == true and meta.isdead ~= true
end

-- ── Items ──────────────────────────────────────────────────────────────────
for name, tool in pairs(Config.Tools) do
    QBCore.Functions.CreateUseableItem(name, function(source)
        local Player = QBCore.Functions.GetPlayer(source)
        if not Player then return end
        if tool.emsOnly and not IsMedic(Player) then
            return Notify(source, 'Only on-duty paramedics know how to use this', 'error')
        end
        TriggerClientEvent('ems-tools:client:UseTool', source, name)
    end)
end

QBCore.Functions.CreateUseableItem(Config.Monitor.Item, function(source)
    if not IsMedic(QBCore.Functions.GetPlayer(source)) then
        return Notify(source, 'Only on-duty paramedics can use the monitor', 'error')
    end
    TriggerClientEvent('ems-tools:client:OpenMonitor', source)
end)

-- ── Tool use ───────────────────────────────────────────────────────────────
local function CheckTarget(src, tool, targetId)
    if targetId == 0 then
        if tool.use == 'patient' then return nil, 'This can only be used on a patient' end
        return src
    end
    if tool.use == 'self' then return nil, 'You can only use this on yourself' end
    local Target = QBCore.Functions.GetPlayer(targetId)
    if not Target or targetId == src then return nil, 'No patient' end
    if Distance(src, targetId) > Config.MaxTargetDistance + 1.5 then return nil, 'The patient is too far away' end
    local dead, laststand = PatientState(Target)
    if tool.down == 'laststand' and not laststand then return nil, 'The patient must be bleeding out (still has a pulse)' end
    if tool.down == 'alive' and (dead or laststand) then return nil, 'Stabilise the patient first' end
    return targetId
end

QBCore.Functions.CreateCallback('ems-tools:server:StartTool', function(src, cb, name, targetId)
    local tool = Config.Tools[name]
    local Player = QBCore.Functions.GetPlayer(src)
    if not tool or not Player then return cb(false) end
    if tool.emsOnly and not IsMedic(Player) then return cb(false, 'Only on-duty paramedics can use this') end
    if not Player.Functions.GetItemByName(name) then return cb(false, 'You don\'t have ' .. tool.label) end
    local target, err = CheckTarget(src, tool, tonumber(targetId) or 0)
    if not target then return cb(false, err) end
    Active[src] = { tool = name, target = target, at = GetGameTimer(), time = tool.time }
    cb(true)
end)

RegisterNetEvent('ems-tools:server:CancelTool', function()
    Active[source] = nil
end)

RegisterNetEvent('ems-tools:server:FinishTool', function(name)
    local src = source
    local act = Active[src]
    Active[src] = nil
    local tool = Config.Tools[name]
    if not act or act.tool ~= name or not tool then return end
    if GetGameTimer() - act.at < act.time * 0.8 then return end -- progress bar skipped

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local target = act.target
    if target ~= src then
        local Target = QBCore.Functions.GetPlayer(target)
        if not Target or Distance(src, target) > Config.MaxTargetDistance + 2.0 then
            return Notify(src, 'The patient moved away', 'error')
        end
    end
    if tool.consume then
        if not Player.Functions.RemoveItem(name, 1) then return end
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[name], 'remove')
    elseif not Player.Functions.GetItemByName(name) then
        return
    end

    for _, effect in ipairs(tool.effects or {}) do
        local data = {}
        for k, v in pairs(effect) do if k ~= 'kind' then data[k] = v end end
        TriggerClientEvent('hospital:client:ApplyTreatment', target, effect.kind, data)
    end
    if tool.patientProp then
        TriggerClientEvent('ems-tools:client:PatientProp', target, tool.patientProp)
    end
    TriggerClientEvent('ems-tools:client:Treated', target, tool.notify)

    if target ~= src then
        Notify(src, ('%s applied'):format(tool.label), 'success')
        EMSServer.Log(src, target, tool.label)
    end
end)

-- ── CPR ────────────────────────────────────────────────────────────────────
QBCore.Functions.CreateCallback('ems-tools:server:StartCPR', function(src, cb, targetId)
    targetId = tonumber(targetId)
    local Target = targetId and QBCore.Functions.GetPlayer(targetId)
    if not Target or targetId == src then return cb(false, 'No patient') end
    if Distance(src, targetId) > 3.0 then return cb(false, 'Get closer to the patient') end
    local dead, laststand = PatientState(Target)
    if dead then return cb(false, 'No pulse — the patient needs a defibrillator') end
    if not laststand then return cb(false, 'The patient doesn\'t need CPR') end
    if (CprCount[targetId] or 0) >= Config.CPR.MaxPerDown then return cb(false, 'CPR isn\'t helping any more, the patient needs a paramedic') end
    Active[src] = { tool = '__cpr', target = targetId, at = GetGameTimer(), time = Config.CPR.Time }
    TriggerClientEvent('ems-tools:client:CPRPatient', targetId, Config.CPR.Time)
    cb(true)
end)

RegisterNetEvent('ems-tools:server:FinishCPR', function()
    local src = source
    local act = Active[src]
    Active[src] = nil
    if not act or act.tool ~= '__cpr' then return end
    if GetGameTimer() - act.at < act.time * 0.8 then return end
    local target = act.target
    local Target = QBCore.Functions.GetPlayer(target)
    if not Target or Distance(src, target) > 4.0 then return end
    local _, laststand = PatientState(Target)
    if not laststand then return end
    CprCount[target] = (CprCount[target] or 0) + 1
    TriggerClientEvent('hospital:client:ApplyTreatment', target, 'stabilize', { seconds = Config.CPR.Seconds, max = Config.CPR.Max })
    TriggerClientEvent('ems-tools:client:Treated', target, 'Someone is doing CPR on you — you have a bit more time')
    Notify(src, ('CPR done (%d/%d)'):format(CprCount[target], Config.CPR.MaxPerDown), 'success')
    EMSServer.Log(src, target, 'CPR')
end)

-- Watch qb-hospital's own state events (CPR counter / monitor rhythm).
RegisterNetEvent('hospital:server:SetLaststandStatus', function(bool)
    if not bool then CprCount[source] = nil end
end)
RegisterNetEvent('hospital:server:SetDeathStatus', function(isDead)
    local src = source
    if isDead then DeathAt[src] = DeathAt[src] or os.time() else DeathAt[src] = nil; CprCount[src] = nil end
end)

-- Revives done by qb-hospital (first aid / defibrillator) also go to the patient's record.
AddEventHandler('hospital:server:PatientRevivedBy', function(medicSrc, patientSrc, how)
    local Medic = QBCore.Functions.GetPlayer(medicSrc)
    if Medic and Medic.PlayerData.job.name == Config.Job then
        EMSServer.Log(medicSrc, patientSrc, how == 'defib' and 'Defibrillation — pulse restored' or 'First aid — patient back on their feet')
    end
end)

-- ── Vitals ─────────────────────────────────────────────────────────────────
local function clamp(v, a, b) return math.max(a, math.min(b, v)) end
local function jitter(n) return math.random(-n, n) end

local TRIAGE = { GREEN = 'green', YELLOW = 'yellow', RED = 'red' }

function EMSServer.ComputeVitals(tsrc)
    local Target = QBCore.Functions.GetPlayer(tsrc)
    if not Target then return nil end
    local ped = GetPlayerPed(tsrc)
    local meta = Target.PlayerData.metadata or {}
    local status = {}
    if GetResourceState(Config.HospitalResource) == 'started' then
        local ok, res = pcall(function() return exports[Config.HospitalResource]:GetPatientStatus(tsrc) end)
        if ok and type(res) == 'table' then status = res end
    end

    local health = ped ~= 0 and GetEntityHealth(ped) or 200
    local hp = clamp((health - 100) / 100, 0.0, 1.0)
    local bleed = tonumber(status.bleedLevel) or 0
    local dead, laststand = PatientState(Target)
    local head = 0
    for _, l in ipairs(status.limbs or {}) do
        if l.part == 'HEAD' or l.part == 'NECK' then head = math.max(head, tonumber(l.severity) or 0) end
    end

    local v = {
        name = Name(Target), id = tsrc, citizenid = Target.PlayerData.citizenid,
        blood = meta.bloodtype or '?', gender = (tonumber(Target.PlayerData.charinfo.gender) == 1) and 'F' or 'M',
        dob = Target.PlayerData.charinfo.birthdate,
        armor = ped ~= 0 and GetPedArmour(ped) or 0, health = math.floor(hp * 100),
        bleeding = status.bleeding, bleedLevel = bleed, painkillers = status.painkillers == true,
        limbs = status.limbs or {}, weapons = status.weapons or {},
        dead = dead, laststand = laststand,
    }

    if dead then
        local since = os.time() - (DeathAt[tsrc] or os.time())
        local vf = since < 90
        v.hr, v.sys, v.dia, v.spo2, v.rr, v.gcs = vf and (200 + jitter(40)) or 0, 0, 0, 0, 0, 3
        v.temp = 35.2 + math.random() * 0.4
        v.rhythm = vf and 'VF' or 'ASYSTOLE'
        v.rhythmLabel = vf and 'V-FIB — SHOCKABLE' or 'ASYSTOLE'
        v.triage = TRIAGE.RED
        v.condition = 'NO PULSE'
    elseif laststand then
        v.hr = 128 + bleed * 5 + jitter(6)
        v.sys, v.dia = 82 - bleed * 3 + jitter(3), 48 + jitter(3)
        v.spo2 = 88 - bleed + jitter(1)
        v.rr, v.gcs = 28 + jitter(2), 8 + jitter(1)
        v.temp = 36.0 + math.random() * 0.3
        v.rhythm, v.rhythmLabel = 'TACHY', 'SINUS TACHYCARDIA'
        v.triage = TRIAGE.RED
        v.condition = 'CRITICAL — BLEEDING OUT'
    else
        local lost = 1.0 - hp
        v.hr = math.floor(72 + bleed * 14 + lost * 35 + jitter(3) - (v.painkillers and 6 or 0))
        v.sys = math.floor(122 - bleed * 11 - lost * 28 + jitter(3))
        v.dia = math.floor(80 - bleed * 7 - lost * 12 + jitter(2))
        v.spo2 = clamp(math.floor(99 - bleed * 2 - lost * 6 + jitter(1)), 70, 100)
        v.rr = math.floor(14 + bleed * 3 + lost * 6 + jitter(1))
        v.gcs = 15 - (head >= 3 and 2 or (head >= 1 and 1 or 0))
        v.temp = 36.6 + math.random() * 0.5
        v.rhythm = v.hr > 100 and 'TACHY' or 'SINUS'
        v.rhythmLabel = v.hr > 100 and 'SINUS TACHYCARDIA' or 'NORMAL SINUS RHYTHM'
        if bleed >= 3 or hp < 0.3 then
            v.triage, v.condition = TRIAGE.RED, 'SERIOUS'
        elseif bleed >= 1 or #v.limbs > 0 or hp < 0.7 then
            v.triage, v.condition = TRIAGE.YELLOW, 'INJURED'
        else
            v.triage, v.condition = TRIAGE.GREEN, 'STABLE'
        end
    end
    v.temp = math.floor(v.temp * 10 + 0.5) / 10
    return v
end

QBCore.Functions.CreateCallback('ems-tools:server:GetVitals', function(src, cb, targetId)
    targetId = tonumber(targetId)
    local Player = QBCore.Functions.GetPlayer(src)
    if not targetId or not IsMedic(Player) then return cb(nil) end
    if Config.Monitor.RequireItemForTarget and not Player.Functions.GetItemByName(Config.Monitor.Item) then return cb(nil) end
    if targetId ~= src and Distance(src, targetId) > Config.Monitor.Range + 2.0 then return cb(nil) end
    cb(EMSServer.ComputeVitals(targetId))
end)

AddEventHandler('playerDropped', function()
    local src = source
    Active[src], CprCount[src], DeathAt[src] = nil, nil, nil
end)
