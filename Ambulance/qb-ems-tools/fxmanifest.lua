fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Rakan'
description 'EMS field tools: trauma kits with animations & props, live vitals monitor, stretcher, wheelchair, trauma bag, CPR'
version '1.0.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/utils.lua',
    'client/patient.lua',
    'client/tools.lua',
    'client/monitor.lua',
    'client/placeables.lua',
    'client/target.lua',
}

server_scripts {
    'server/main.lua',
    'server/placeables.lua',
}

dependencies {
    'qb-core',
    'qb-hospital',
    'qb-target',
    'ox_lib',
}
