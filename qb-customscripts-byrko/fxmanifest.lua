fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'byrko'
description 'CORE — engine guard, keep engine on exit, aircraft fixes, RP helpers'
version '3.0.0'

dependency 'ox_lib'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client/utils.lua',
    'client/engine.lua',
    'client/aircraft.lua',
    'client/npc_vehicles.lua',
    'client/passenger_combat.lua',
    'client/vehicle_tuning.lua',
    'client/roleplay.lua'
}

server_scripts {
    'server/server.lua',
    'server/vehicle_tuning.lua'
}
