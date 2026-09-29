
fx_version 'cerulean'
games      { 'gta5' }
lua54 'yes'

author 'FC1'
description 'Manual handbrake script'
version '1.0.6'

ui_page 'sound/nui.html'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/cache.lua',
    'client/editables/editable.lua',
    'client/client.lua'
}

server_scripts {
    'server/server.lua'
}

files {
    'sound/nui.html',
    'sound/handbrake_release.mp3',
    'sound/handbrake_tighten.mp3'
}

escrow_ignore {
    'client/editables/*',
    'sound/*',
    'config.lua'
}

dependency '/assetpacks'