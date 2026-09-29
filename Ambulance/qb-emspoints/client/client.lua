local QBCore = exports[Rc2store.Core]:GetCoreObject()

-- Wait a full shift period BEFORE the first point (it used to give one right away,
-- so reconnecting was a free point every time).
CreateThread(function()
    while true do
        Wait(Rc2store.Minutes * 60 * 1000)
        local job = QBCore.Functions.GetPlayerData().job
        if job and job.name == 'ambulance' and job.onduty then
            TriggerServerEvent('qb-ambulance:addpoints')
        end
    end
end)

RegisterNetEvent('qb-emspoints:client:openmenu', function(data)
    QBCore.Functions.TriggerCallback('qb-playermanagement:server:getambulanceofficers', function(playerss)
        local options = {}
        for k, v in pairs(playerss) do
            table.insert(options, {
                title = v.firstname .. " " .. v.lastname,
                description = "grade: " .. v.grade .. " \n Points: " .. v.ppoints,
                icon = 'user-circle',
                event = 'qb-emspoints:manageplayers',
                arrow = true,
                args = {
                    fullname = v.firstname .. " " .. v.lastname,
                    id = v.cid,
                    jj = v.job,
                }
            })
        end
        lib.registerContext({
            id = 'ambulance_menuu',
            title = 'Player Points',
            options = options
        })
        lib.showContext('ambulance_menuu')
    end)
end)
RegisterNetEvent('qb-emspoints:manageplayers', function(data)
    lib.registerContext({
        id = 'ambulancemana',
        title = 'Player Points',
        menu = 'ambulance_menuu',
        options = {
            {
                title = 'Give ambulance points',
                description = "Click here to give " .. data.fullname .. " ambulance points",
                icon = 'plus',
                onSelect = function()
                    Giveppinput(data.id)
                end,

            },
            {
                title = 'Remove ambulance points',
                description = "Click here to Remove " .. data.fullname .. " ambulance points",
                icon = 'minus',
                onSelect = function()
                    REmovepp(data.id)
                end

            },
            {
                title = 'Remove all ambulance points',
                description = "Click here to remove  " .. data.fullname .. " all ambulance points",
                icon = 'minus',
                event = 'qb-ambulance:allloppo',
                args = {
                    icd = data.id
                }
            }

        }
    })
    lib.showContext('ambulancemana')
end)
RegisterNetEvent('qb-ambulance:allloppo', function(data)
    TriggerServerEvent('qb-ambulance:rmvallppp', data.icd)
end)
function Giveppinput(data)
    local input = lib.inputDialog('Give ambulancepoints',
        { { type = 'number', label = 'Points amount ', description = 'Put your amount here', icon = 'plus' } })
    if not input then return end
    TriggerServerEvent('qb-ambulance:giveppoints', data, input[1])
end

function REmovepp(data)
    local input = lib.inputDialog('Remove ambulancepoints',
        { { type = 'number', label = 'Points amount ', description = 'Put your amount here', icon = 'plus' } })
    if not input then return end
    TriggerServerEvent('qb-ambulance:rmvppoints', data, input[1])
end

