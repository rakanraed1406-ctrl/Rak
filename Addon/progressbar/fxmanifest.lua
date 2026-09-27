fx_version 'cerulean'
lua54 'yes'
game 'gta5'

author 'Yas'
description 'Yas Progressbar'
version '1.1.0'

ui_page 'html/index.html'

client_script 'client.lua'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

exports {
    'Progress',
    'ProgressWithStartEvent',
    'ProgressWithTickEvent',
    'ProgressWithStartAndTick',
    'isDoingSomething'
}
