fx_version 'cerulean'
game 'gta5'

name 'st-core'
author 'StormsReaper'
description 'Storms Technologies core framework for FiveM.'
version '0.2.0'

lua54 'yes'

shared_scripts {
    'config.lua',
    'shared/validation.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua',
    'server/vehicles.lua',
    'server/insurance.lua'
}

dependencies {
    'oxmysql'
}
