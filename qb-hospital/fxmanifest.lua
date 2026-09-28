fx_version 'cerulean'
game 'gta5'

description 'JT'
version '1.0.0'

shared_scripts {
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
	'@ox_lib/init.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/insurance.lua'
}

exports {
	'isPlayerDead',
}

lua54 'yes'


escrow_ignore {
    'config.lua',
	'client/main.lua',
}
