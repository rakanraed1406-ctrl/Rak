fx_version 'cerulean'
game 'gta5'

files {
    'data_car/**/*.meta',
    'data_skin/**/*.meta',

    -- صوت الهيلكات (b2chal)
    'data_car/b2chal/audioconfig/*.dat151.rel',
    'data_car/b2chal/audioconfig/*.dat54.rel',
    'data_car/b2chal/sfx/dlc_dodgehemihellcat/*.awc',
}

data_file 'VEHICLE_LAYOUTS_FILE' 'data_car/**/vehiclelayouts.meta'
data_file 'HANDLING_FILE' 'data_car/**/handling.meta'
data_file 'VEHICLE_METADATA_FILE' 'data_car/**/vehicles.meta'
data_file 'CARCOLS_FILE' 'data_car/**/carcols.meta'
data_file 'VEHICLE_VARIATION_FILE' 'data_car/**/carvariations.meta'
data_file 'DLCTEXT_FILE' 'data_car/**/dlctext.meta'
data_file 'CARCONTENTUNLOCKS_FILE' 'data_car/**/carcontentunlocks.meta'
data_file 'WEAPONINFO_FILE_PATCH' 'data_car/**/weapons.meta'
data_file 'WEAPONCOMPONENTSINFO_FILE' 'data_car/**/weaponcomponents.meta'

data_file 'VEHICLE_LAYOUTS_FILE' 'data_car/1vehiclelayouts/**.meta'
data_file 'HANDLING_FILE' 'data_car/1handling/**.meta'
data_file 'VEHICLE_METADATA_FILE' 'data_car/1vehicles/**.meta'
data_file 'CARCOLS_FILE' 'data_car/1carcols/**.meta'
data_file 'VEHICLE_VARIATION_FILE' 'data_car/1carvariations/**.meta'
data_file 'DLCTEXT_FILE' 'data_car/1dlctext/**.meta'

-- صوت الهيلكات الحقيقي (audioNameHash = dodgehemihellcat)
data_file 'AUDIO_GAMEDATA'  'data_car/b2chal/audioconfig/dodgehemihellcat_game.dat'
data_file 'AUDIO_SOUNDDATA' 'data_car/b2chal/audioconfig/dodgehemihellcat_sounds.dat'
data_file 'AUDIO_WAVEPACK'  'data_car/b2chal/sfx/dlc_dodgehemihellcat'

data_file "PED_METADATA_FILE" "data_skin/**/*.meta"
