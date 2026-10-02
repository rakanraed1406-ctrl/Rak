fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author '! TMX'
description 'QB Vehicle Shop — random-stock showroom + admin vehicle auctions'
version '2.2.0'

ui_page 'html/index.html'

shared_scripts {
    'config.lua',
    'stock/config.lua',
    'auction/config.lua',
    'shared.lua',
    '@qb-core/shared/locale.lua',
    'locales/en.lua', -- only one language is used (Lang = Lang or ...), so only one is loaded
}

client_scripts {
    'common/client.lua',
    'client.lua',
    'stock/client.lua',
    'auction/client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'common/server.lua',
    'server.lua',
    'stock/server.lua',
    'auction/server.lua'
}

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}

dependencies {
    'qb-core',
    'oxmysql',
}
