local toggled = {}
local logEnabled = {}
RegisterServerEvent('chat:init')
RegisterServerEvent('chat:addTemplate')
RegisterServerEvent('chat:addMessage')
RegisterServerEvent('chat:addSuggestion')
RegisterServerEvent('chat:removeSuggestion')
RegisterServerEvent('_chat:messageEntered')
RegisterServerEvent('chat:clear')
RegisterServerEvent('__cfx_internal:commandFallback')
 
AddEventHandler('_chat:messageEntered', function(author, color, message)
    if not message or not author then
        return
    end
 
    TriggerEvent('chatMessage', source, author, message)
 
    if not WasEventCanceled() then
        TriggerClientEvent('chatMessage', -1, author,  { 255, 255, 255 }, message)
    end
end)

AddEventHandler("chatMessage", function(source, args, raw)
    CancelEvent()
end)
 

AddEventHandler('__cfx_internal:commandFallback', function(command)
    local name = GetPlayerName(source)

    TriggerEvent('chatMessage', source, name, '/' .. command)

    if not WasEventCanceled() then
        TriggerClientEvent('chatMessage', -1, name, { 255, 255, 255 }, '/' .. command) 
    end

    CancelEvent()
end)

-- command suggestions for clients

local function refreshCommands(player)
    if GetRegisteredCommands then
        local registeredCommands = GetRegisteredCommands()

        local suggestions = {}

        for _, command in ipairs(registeredCommands) do
            if IsPlayerAceAllowed(player, ('command.%s'):format(command.name)) then
                table.insert(suggestions, {
                    name = '/' .. command.name,
                    help = ''
                })
            end
        end

        TriggerClientEvent('chat:addSuggestions', player, suggestions)
    end
end

AddEventHandler('chat:init', function()
    refreshCommands(source)
end)

AddEventHandler('onServerResourceStart', function(resName)
    Wait(500)

    for _, player in ipairs(GetPlayers()) do
        refreshCommands(player)
    end
end)

-- RegisterCommand('ooc', function(source, args)
--     if not args[1] then return end
--     local src = source
--     local msg = ""
--     for i = 1, #args do
--       msg = msg .. " " .. args[i]
--     end
--     local Player = QBCore.Functions.GetPlayer(src)
--     local name = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
--     if not toggled then
--         TriggerClientEvent('chatMessage', -1, 'OOC | '.. name .. ' ['.. src .. '] ', 2, msg, "OOC")
--     elseif toggled then
--         TriggerClientEvent('QBCore:Notify', 'pSrc, OOC is disabled', 'error', 3500)
--         --TriggerClientEvent("DoLongHudText", src, "OOC is disabled", 2)
--     end
--  end)  

RegisterCommand("clear", function(source)
    TriggerClientEvent("chat:clear", source)
end)

RegisterCommand("clearall", function(source)
    local steamIdentifier = GetPlayerIdentifiers(source)[1]
    exports.oxmysql:execute("SELECT rank FROM users WHERE hex_id = ?", {steamIdentifier}, function(data)
        if data[1].rank ~= "user" then
            TriggerClientEvent("chat:clear", -1)
        end
    end)
end)

RegisterServerEvent('3dme:log')
AddEventHandler('3dme:log', function(text, meOrdo)
    local src = source
 
  
    
    

    
    local xPlayer = QBCore.Functions.GetPlayer(src)
    local name = xPlayer.PlayerData.charinfo.firstname.." "..xPlayer.PlayerData.charinfo.lastname
    if xPlayer ~= nil then

        -- Me
        if meOrdo == '/me' then
            
            
            TriggerEvent('qb-log:server:CreateLog', 'me', 'ME', 'blue', name..": ".. text)
            
           
             
            
           
        -- Do
        elseif meOrdo == '/do' then
            
          
                TriggerEvent('qb-log:server:CreateLog', 'do', 'DO', 'pink',  name..": "..text)
         
          
       
       elseif meOrdo == '/ooc' then
        TriggerEvent('qb-log:server:CreateLog', 'ooc', 'OOC', 'BLACK',  name..": "..text)
           
     
         
         
      
       
        end
    end
end)
RegisterServerEvent('3dme:shareDisplay')
AddEventHandler('3dme:shareDisplay', function(text, target, meOrdo)
    local src = source
    local srcCoords = GetEntityCoords(GetPlayerPed(src))
    local targetCoords = GetEntityCoords(GetPlayerPed(target))
    local dist = #(srcCoords - targetCoords)
    

    if meOrdo ~= "ooc" and dist > 30.0 then 
        --print('^1'..src..' - '..GetPlayerIdentifier(src, 0)..' - '..text..'^0')
        return
    elseif meOrdo == "ooc" and dist > 110.0 then     
       return
    end
    local xPlayer = QBCore.Functions.GetPlayer(src)
    local name = xPlayer.PlayerData.charinfo.firstname.." "..xPlayer.PlayerData.charinfo.lastname
    if xPlayer ~= nil then

        -- Me
        if meOrdo == '/me' then
            
            TriggerClientEvent('3dme:triggerDisplay', target, text, src, meOrdo)
            -- TriggerEvent('qb-log:server:CreateLog', 'me', 'ME', 'blue', name..": ".. text)
            
           
             
               TriggerClientEvent('chat:addMessage',target, {
                   color = {32, 125, 201, 0.8},
                   multiline = true,
                   emsalsiz = "me",
                   args = {name, text}
               })
           
        -- Do
        elseif meOrdo == '/do' then
            TriggerClientEvent('3dme:triggerDisplay', target, text, src, meOrdo)
          
                -- TriggerEvent('qb-log:server:CreateLog', 'do', 'DO', 'pink',  name..": "..text)
         
           TriggerClientEvent('chat:addMessage',target, {
               color = {168, 117, 255, 0.8},
               multiline = true,
               emsalsiz = "do",
               args = {name, text}
           })
           
          
       
       elseif meOrdo == '/ooc' then
        -- TriggerEvent('qb-log:server:CreateLog', 'ooc', 'OOC', 'BLACK',  name..": "..text)
           
     
           TriggerClientEvent('chat:addMessage',target, {
               color = {150, 19, 19, 0.8},
               multiline = true,
               emsalsiz = "ooc",
               args = {name, text}
           })
         
      
       
        end
    end
end)
