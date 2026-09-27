fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author '! TMX'
description 'JT'
version '1.0.0'

shared_scripts {
	'config/*.lua',
}

client_scripts {
	'client/*.lua',
}

server_scripts {
	'server/*.lua',
}

ui_page 'html/index.html'

files {
	'html/*.*',
}

escrow_ignore {
	'server/*.lua',
	'client/*.lua',
	'config/*.lua',
}
dependency '/assetpacks'
