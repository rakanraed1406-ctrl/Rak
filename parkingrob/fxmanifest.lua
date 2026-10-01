fx_version 'cerulean'
game 'gta5'
lua54 'yes'

description 'Parking meter robbery + coin buyer with a daily market price'
version '2.0.0'

shared_script 'config.lua'
client_script 'client/main.lua'
server_script 'server/main.lua'

dependencies {
    'qb-core',
    'qb-target',
    'qb-input'
}
