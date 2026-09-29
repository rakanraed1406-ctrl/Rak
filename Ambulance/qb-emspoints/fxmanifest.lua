fx_version 'cerulean'
game 'gta5'
author '! TMX'
description 'JT'
lua54 'yes'

client_script 'client/client.lua'
server_script { 'server/server.lua', '@oxmysql/lib/MySQL.lua' }
shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

