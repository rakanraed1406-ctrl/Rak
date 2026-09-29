fx_version 'cerulean'
game 'gta5'
lua54 'yes'

description 'Laundromat robbery (cleaned: backdoor removed, server-side validation)'
version '2.0.0'

shared_scripts {
    'shared/config.lua',
}

client_scripts {
    'client/cl_main.lua',
}

server_scripts {
    'server/sv_main.lua',
}
