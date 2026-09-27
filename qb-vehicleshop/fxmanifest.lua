fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author '! TMX'
description 'QB Vehicle Shop + admin vehicle auctions'
version '2.1.0'

ui_page 'html/index.html'

shared_script {
    'config.lua',
    'auction/config.lua',
    '@qb-core/shared/locale.lua',
    'locales/en.lua',
    'locales/*.lua'
}

client_scripts {
    '@PolyZone/client.lua',
    '@PolyZone/BoxZone.lua',
    '@PolyZone/EntityZone.lua',
    '@PolyZone/CircleZone.lua',
    '@PolyZone/ComboZone.lua',
    'client.lua',
    'auction/client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua',
    'auction/server.lua'
}

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}
