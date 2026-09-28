fx_version 'cerulean'
game 'gta5'
lua54 'yes'
version '1.8.1'
description 'Emotes menu (blue theme)'

provide 'scully_emotemenu'
provide 'rpemotes'
provide 'dpemotes'


shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    "locales/*.lua",
    "animations/*.lua",
    "client/*.lua",
}

server_scripts {
    "server/sv_main.lua",
}

ui_page "html/index.html"

files {
    "animations/AnimationList.json",
    "html/index.html",
    "html/assets/*.css",
    "html/images/*.svg",
    "html/images/no-image.png",
    "html/assets/*.png",
    "html/js/*.js",
    "html/fonts/*.otf",
    "html/fonts/*.ttf",
    "html/fonts/*.TTF",
}

escrow_ignore {
    "config.lua",
    "locales/*.lua",
    "animations/*.lua",
}

data_file 'DLC_ITYP_REQUEST' 'stream/taymckenzienz_rpemotes.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/brummie_props.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/bzzz_props.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/apple_1.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/kaykaymods_props.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/knjgh_pizzas.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/ultra_ringcase.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/pata_props.ytyp'
data_file "DLC_ITYP_REQUEST" "stream/badge1.ytyp"
data_file "DLC_ITYP_REQUEST" "stream/copbadge.ytyp"
data_file "DLC_ITYP_REQUEST" "stream/prideprops_ytyp"
data_file "DLC_ITYP_REQUEST" "stream/lilflags_ytyp"
data_file 'DLC_ITYP_REQUEST' 'stream/natty_props_lollipops.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/bebekbus.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/badge1.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/copbadge.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/bzzz_foodpack'
data_file 'DLC_ITYP_REQUEST' 'stream/bzzz_prop_torch_fire001.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/glap-pom-pillow.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/vedere_props.ytyp'
