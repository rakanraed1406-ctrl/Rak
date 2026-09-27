fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Rakan'
description 'Vehicle stock showroom (random stock per restart, buy only)'
version '1.0.0'

ui_page 'html/index.html'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua',
    'client/stock.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/stock.lua'
}

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}

dependencies {
    'qb-core',
    'qb-target',
    'oxmysql'
}
