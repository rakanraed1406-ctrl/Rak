fx_version 'cerulean'
game 'gta5'

ui_page "html/ui.html"

client_script {
    "locale.lua",
	"locales/*.lua",
    "config.lua",
    "client/menu.lua",
    "client/clothes.lua",
    "client/client.lua"
}
server_script {
    "locale.lua",
	"locales/*.lua",
    '@oxmysql/lib/MySQL.lua',
    "server/server.lua",
}

shared_scripts {
    '@qb-core/shared/locale.lua',
    "locale.lua", -- Change this to your preferred language
}

files {
    "html/ui.html",
    "html/css/RadialMenu.css",
    "html/js/RadialMenu.js",
    'html/css/all.min.css',
    'html/js/all.min.js',
}

lua54 'yes'

exports {
    'CanOpenDoor'
}
escrow_ignore {
    'config.lua'
}
