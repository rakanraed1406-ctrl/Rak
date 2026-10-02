fx_version 'cerulean'
game 'gta5'
lua54 'yes'

ui_page 'html/ui.html'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'locale.lua', -- Change this to your preferred language
    'locales/*.lua',
}

client_scripts {
    'config.lua',
    'client/menu.lua',
    'client/clothes.lua',
    'client/client.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/server.lua',
}

-- Font Awesome is NOT sent to players any more: the icons are a small sprite
-- inside html/ui.html (tools/ rebuilds it and is never downloaded by clients).
files {
    'html/ui.html',
    'html/css/RadialMenu.css',
    'html/js/RadialMenu.js',
}

exports {
    'CanOpenDoor'
}

escrow_ignore {
    'config.lua'
}
