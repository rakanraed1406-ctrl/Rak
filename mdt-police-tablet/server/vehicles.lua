--[[ server/vehicles.lua - read-only plate lookup against player_vehicles ]]
local QBCore = MDT.QBCore

RegisterNetEvent('police:server:LookupPlate', function(plate)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not MDT.IsEmployee(Player) then return end

    if type(plate) ~= 'string' then return end
    plate = plate:upper():gsub('%s+', ''):sub(1, 20)
    if plate == '' then return end

    exports.oxmysql:execute(
        'SELECT pv.plate, pv.vehicle, pv.citizenid, p.charinfo FROM ' .. MDT.Tables.Vehicles ..
        ' pv LEFT JOIN players p ON p.citizenid = pv.citizenid WHERE pv.plate = ? LIMIT 1',
        { plate },
        function(rows)
            local result = nil
            if rows and rows[1] then
                local row = rows[1]
                local ci = row.charinfo and json.decode(row.charinfo) or {}
                result = {
                    plate = row.plate,
                    vehicle = row.vehicle,
                    citizenid = row.citizenid,
                    ownerName = (ci.firstname or 'Unknown') .. ' ' .. (ci.lastname or '')
                }
            end
            TriggerClientEvent('police:client:ReceivePlateLookup', src, plate, result)
        end
    )
end)

-- ===================================================================
-- Tactical operations (unchanged — "isboss" flag gated, as before)
-- ===================================================================

--- Live GPS of on-duty officers only (never off-duty/offline personnel — that would
--- be a serious privacy/safety issue for undercover or off-shift officers).
