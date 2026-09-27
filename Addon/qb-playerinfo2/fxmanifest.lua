fx_version 'bodacious'
game 'gta5'

author '! TMX'

ui_page 'html/index.html'

shared_scripts {
    'config.lua',
}

client_scripts {
    'client/*.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/*.lua',
}

files {
    'html/*.html',
    'html/js/*.js',
    'html/css/*.css',
}

lua54 'yes'
