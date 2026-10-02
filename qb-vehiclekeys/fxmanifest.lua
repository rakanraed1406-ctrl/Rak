fx_version 'cerulean'
game 'gta5'
lua54 'yes'

description 'qb-vehiclekeys (cleaned + running-engine keys + engine rules)'
version '1.1.0'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'locales/en.lua',
    'config.lua',
}

client_script 'client/main.lua'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}
