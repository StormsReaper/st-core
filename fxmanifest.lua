fx_version 'cerulean'
game 'gta5'

name 'st-core'
author 'StormsReaper'
description 'Storms Technologies core framework for FiveM.'
version '0.3.0'

lua54 'yes'

ui_page 'html/index.html'

shared_scripts {
    'config.lua',
    'shared/validation.lua'
}

client_scripts {
    'client.lua',
    'client/dmv.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua',
    'server/payments.lua',
    'server/documents.lua',
    'server/purchases.lua',
    'server/vehicles.lua',
    'server/insurance.lua',
    'server/dmv.lua'
}

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}

dependencies {
    'oxmysql'
}
