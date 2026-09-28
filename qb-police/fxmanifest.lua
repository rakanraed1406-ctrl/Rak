--  ██████╗░░█████╗░██████╗░  ███████╗██╗██╗░░░░░███████╗░██████╗  ██╗░░░██╗██████╗░░░░░█████╗░
--  ██╔══██╗██╔══██╗╚════██╗  ██╔════╝██║██║░░░░░██╔════╝██╔════╝  ██║░░░██║╚════██╗░░░██╔══██╗
--  ██████╔╝██║░░╚═╝░░███╔═╝  █████╗░░██║██║░░░░░█████╗░░╚█████╗░  ╚██╗░██╔╝░░███╔═╝░░░██║░░██║
--  ██╔══██╗██║░░██╗██╔══╝░░  ██╔══╝░░██║██║░░░░░██╔══╝░░░╚═══██╗  ░╚████╔╝░██╔══╝░░██╗██║░░██║
--  ██║░░██║╚█████╔╝███████╗  ██║░░░░░██║███████╗███████╗██████╔╝  ░░╚██╔╝░░███████╗╚█║╚█████╔╝
--  ╚═╝░░╚═╝░╚════╝░╚══════╝  ╚═╝░░░░░╚═╝╚══════╝╚══════╝╚═════╝░  ░░░╚═╝░░░╚══════╝░╚╝░╚════╝░

-- ░██████╗░█████╗░██████╗░██╗██████╗░████████╗
-- ██╔════╝██╔══██╗██╔══██╗██║██╔══██╗╚══██╔══╝
-- ╚█████╗░██║░░╚═╝██████╔╝██║██████╔╝░░░██║░░░
-- ░╚═══██╗██║░░██╗██╔══██╗██║██╔═══╝░░░░██║░░░
-- ██████╔╝╚█████╔╝██║░░██║██║██║░░░░░░░░██║░░░
-- ╚═════╝░░╚════╝░╚═╝░░╚═╝╚═╝╚═╝░░░░░░░░╚═╝░░░


fx_version 'cerulean'
game 'gta5'

description 'JT'
version '1.0.0'

shared_scripts {
	'@ox_lib/init.lua',
    'config.lua',
    '@qb-core/shared/locale.lua',
    'locales/en.lua' -- Change this to your preferred language
}

client_scripts {
	'@PolyZone/client.lua',
	'@PolyZone/BoxZone.lua',
	'@PolyZone/EntityZone.lua',
	'@PolyZone/CircleZone.lua',
	'@PolyZone/ComboZone.lua',
	'client/main.lua',
	'client/camera.lua',
	'client/interactions.lua',
	'client/job.lua',
	'client/heli.lua',
	--'client/anpr.lua',
	'client/policexp.lua',
	'client/objects.lua',
	'client/evidence.lua',
	'client/tracker.lua',
	'client/fines.lua',
}

server_scripts {
	'@oxmysql/lib/MySQL.lua',
	'server/main.lua',
	'server/fines.lua',
	'server/policexp.lua',
	'server/evidencebox.lua',
}

ui_page 'html/index.html'

files {
	'html/index.html',
	'html/vue.min.js',
	'html/script.js',
	'html/tablet-frame.png',
	'html/fingerprint.png',
	'html/main.css',
	'html/vcr-ocd.ttf'
}

lua54 "yes"

escrow_ignore {
    'config.lua'
}
