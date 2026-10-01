fx_version 'cerulean'
game 'gta5'
lua54 'yes'

description 'qb-inventory (JT edition)'
version '2.0.0'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'locales/en.lua',
    'locales/ar.lua', -- used when `setr qb_locale "ar"` is in server.cfg
    'config.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/decay.lua',
}

client_script 'client/main.lua'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js',
    'html/fonts/*.woff2',
    'html/images/*.png',
    'html/ammo_images/*.png',
    'html/attachment_images/*.png',
}

dependencies {
    'qb-core',
    'oxmysql',
}
