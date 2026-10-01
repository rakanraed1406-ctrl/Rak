fx_version 'cerulean'
game 'gta5'

description 'Renewed-Banking - personal, job, gang and shared accounts with physical cards'
version '2.0.0'

lua54 'yes'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'locales/en.lua',
    'config.lua'
}

client_scripts {
    'client/*.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/*.lua'
}

ui_page 'web/public/index.html'

files {
    'web/public/index.html',
    'web/public/**/*'
}

dependencies {
    'qb-core',
    'oxmysql',
    'qb-target'
}
