fx_version 'cerulean'
game 'gta5'

description 'JT'
version '1.0.0'

shared_script { 
--	'@qb-core/import.lua'
}

client_scripts {
	'config.lua',
	'client/camera.lua',
}

server_script 'server/main.lua'

ui_page 'html/index.html'

files {
	'html/*.html',
	'html/vue.min.js',
	'html/script.js',
	'html/style.css',
	'html/vcr-ocd.ttf'
}

dependency 'qb-core'
