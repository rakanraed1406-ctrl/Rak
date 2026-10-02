fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'byrko · Jinxed Town'
description 'Jinxed Town — Military Logistics (department shops, budget, stock, delivery, fleet garage)'
version '3.4.0'

shared_script 'config.lua'
client_script 'client.lua'
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/img/logo.webp',
    'html/img/vehicles/*.webp', -- made by /logisticsphotos (restart after)
}

dependencies {
    'qb-core',
    'oxmysql',
}
