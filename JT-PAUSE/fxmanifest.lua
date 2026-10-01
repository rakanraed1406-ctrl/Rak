fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'jt-pause'
author 'JT'
description 'JT Pause Menu'
version '2.0.0'

ui_page 'nui/index.html'

files {
    'nui/index.html',
    'nui/style.css',
    'nui/app.js',
    'nui/logo.png',
    'nui/fonts/*.woff2',
}

shared_scripts {
    'config.lua',
    'locales.lua',
}

client_script 'client/main.lua'
server_script 'server/main.lua'

dependency 'qb-core'
