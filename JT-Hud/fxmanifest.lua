

fx_version 'cerulean'
game 'gta5'

author '1iuae'
description 'Sx_Hud System'
version '2.0.0'

shared_scripts {
    'config.lua',        
    'shared/utils.lua',
    'shared/locales.lua',
}

client_scripts {
    'client/core.lua',
    'client/events.lua',
    'client/thick.lua',
    'client/utils.lua',
    'client/seatbelt.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/core.lua',
    'server/events.lua',
    'server/utils.lua',
    'server/seatbelt.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/seatbelt.svg',
    'html/seatbelt2.svg',
}

data_file 'TEXTURE_DICTIONARY' 'stream/squaremap.ytd'
data_file 'TEXTURE_DICTIONARY' 'stream/circlemap.ytd'
data_file 'TEXTURE_DICTIONARY' 'stream/minimap.ytd'

lua54 'yes'

