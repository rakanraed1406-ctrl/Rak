fx_version 'cerulean'
game 'gta5'

shared_scripts {
	'shared/locale.lua',
	'locales/en.lua',
	'locales/*.lua',
	'shared/cores.lua',
    'shared/config.lua',
	'doors/*.lua',
}
client_scripts {
	'client/*.lua'
}
server_scripts {
	'server/*.lua'
}
ui_page 'html/index.html'
files {
	'html/*.html',
	'html/*.js',
	'html/*.css',
	'html/sounds/*.ogg',
	'assets/**/*.png'
}
lua54 'yes'
dependency '/assetpacks'
dependency '/assetpacks'
