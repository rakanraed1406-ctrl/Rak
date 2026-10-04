fx_version 'adamant'
lua54 "yes"

game 'gta5'

description 'JT'

version '1.0.0'

ui_page 'UI/index.html'

files {
	'UI/index.html',
	'UI/styles/*.css',
	'UI/images/background/*.png',
	'UI/images/icons/*.svg',
	'UI/scripts/*.js'
}

client_scripts {
	'Client/*.lua'
}

exports {
	'createGame'
}



escrow_ignore {

    "Client/**/*",
    "Server/**/*",
	'UI/index.html',
	'UI/styles/*.css',
	'UI/images/background/*.png',
	'UI/images/icons/*.svg',
	'UI/scripts/*.js'
}

dependency '/assetpacks'
