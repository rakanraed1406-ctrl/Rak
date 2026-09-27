fx_version 'cerulean'
game 'gta5'

author 'Rakan'
description 'Police Department MDT Tablet System'
version '5.0.0'

lua54 'yes'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/img/*.png',
    'html/img/*.jpg'
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
    'server/dispatch.lua',
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
    'client/dispatch.lua',
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
