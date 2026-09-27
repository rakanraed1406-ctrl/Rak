fx_version 'cerulean'
game 'gta5'

description 'JT'
version '1.0.0'

shared_scripts {
	'config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

server_exports {
}

lua54 'yes'

escrow_ignore {
    'config.lua'
}
