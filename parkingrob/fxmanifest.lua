fx_version 'cerulean'
game 'gta5'
lua54 'yes'

description 'Parking meter robbery + coin buyer with a daily market price'
version '2.0.0'

client_script 'client/parkingrob.lua'
server_script 'server/parkingrob.lua'

dependencies {
    'qb-core',
    'qb-target',
    'qb-input'
}
