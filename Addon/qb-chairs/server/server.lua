local QBCore = exports[Config.Core]:GetCoreObject()
RegisterNetEvent('QBCore:Server:UpdateObject', function() if source ~= '' then return false end QBCore = exports[Config.Core]:GetCoreObject() end)

CreateThread(function()
	if Config.Inv == "ox" then for k, v in pairs(Config.Stores) do exports.ox_inventory:RegisterShop("ChairStore"..k, { name = v.label, inventory = v.items}) end end
	for i=1, 110, 1 do
		if QBCore.Shared.Items["chair"..i] then	QBCore.Functions.CreateUseableItem("chair"..i, function(source, item) TriggerClientEvent('qb-chairs:Use', source, i) end) end
	end
end)
