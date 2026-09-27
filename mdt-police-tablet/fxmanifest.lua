fx_version 'cerulean'
game 'gta5'

author 'Rakan'
description 'Police Department MDT Tablet System + built-in Command Hub & Dispatch (sk1-hub merged)'
version '8.0.0'

lua54 'yes'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/js/*.js',
    'html/css/*.css',
    'html/vendor/fontawesome/css/*.css',
    'html/vendor/fontawesome/webfonts/*.woff2',
    'html/img/*.png',
    'html/img/*.jpg'
    -- لو حطيت أصوات مخصصة: ضيف 'html/sounds/*.ogg' هنا (شوف Config.Dispatch.Sounds)
}

shared_scripts { 'config.lua' }

server_scripts {
    'server/_shared.lua',
    'server/dashboard.lua',
    'server/cameras.lua',
    'server/personnel.lua',
    'server/treasury.lua',
    'server/recruitment.lua',
    'server/reports.lua',
    'server/directives.lua',
    'server/map.lua',
    'server/bodycam.lua',
    'server/bolo.lua',
    'server/vehicles.lua',
    'server/tactical.lua',
    'server/hub.lua',
    'server/dispatch.lua',
    'server/alerts.lua',
    'server/wanted.lua',
    'server/citations.lua'
}

client_scripts {
    'client/_shared.lua',
    'client/core.lua',
    'client/cameras.lua',
    'client/map.lua',
    'client/personnel.lua',
    'client/treasury.lua',
    'client/reports.lua',
    'client/directives.lua',
    'client/bolo.lua',
    'client/vehicles.lua',
    'client/tactical.lua',
    'client/hub.lua',
    'client/dispatch.lua',
    'client/alerts.lua',
    'client/recruitment.lua',
    'client/wanted.lua',
    'client/citations.lua'
}

dependencies {
    'oxmysql',
    'qb-core',
    'qb-menu',
    'qb-input'
}
