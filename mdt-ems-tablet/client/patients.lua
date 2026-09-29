--[[ client/patients.lua - Patient records callbacks ]]

RegisterNUICallback('searchPatients', function(data, cb)
    TriggerServerEvent('ems-mdt:server:SearchPatients', data.query)
    cb('ok')
end)

RegisterNUICallback('getPatientProfile', function(data, cb)
    TriggerServerEvent('ems-mdt:server:GetPatientProfile', data.citizenid)
    cb('ok')
end)

RegisterNUICallback('savePatientNotes', function(data, cb)
    TriggerServerEvent('ems-mdt:server:SavePatientNotes', data.citizenid, data)
    cb('ok')
end)

RegisterNUICallback('nearbyPatients', function(_, cb)
    TriggerServerEvent('ems-mdt:server:NearbyPatients')
    cb('ok')
end)

RegisterNetEvent('ems-mdt:client:PatientSearchResults', function(query, results)
    SendNUIMessage({ action = 'patientSearchResults', query = query, results = results })
end)

RegisterNetEvent('ems-mdt:client:PatientProfile', function(profile)
    SendNUIMessage({ action = 'patientProfile', profile = profile })
end)

RegisterNetEvent('ems-mdt:client:NearbyPatients', function(list)
    SendNUIMessage({ action = 'nearbyPatients', list = list })
end)
