fx_version 'cerulean'
game 'gta5'

description 'JT'
version '1.0.0'

shared_scripts {
	'@ox_lib/init.lua',
	'@qb-core/shared/locale.lua',
	'locales/en.lua',
	'config.lua'
}

client_scripts {
	'client/main.lua',
	'client/wounding.lua',
	'client/laststand.lua',
	'client/job.lua',
	'client/dead.lua',
	'client/insurance.lua',
	'client/treatment.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/insurance.lua'
}

exports {
	'isPlayerDead',
	'GetLocalState',
}

ui_page 'html/index.html'

files {
	'html/index.html',
	'html/style.css',
	'html/app.js',
}

lua54 'yes'

escrow_ignore {
    'config.lua',
	'client/main.lua',
}
