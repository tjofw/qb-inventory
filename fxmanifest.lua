fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'tRaves'
description 'traves-inventory - custom QBCore inventory'
version '0.3.0'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'config/config.lua',
}

client_scripts {
    'client/weapons.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',

    'server/database.lua',
    'server/items.lua',
    'server/migration.lua',
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/images/*.png',
}

dependencies {
    'qb-core',
    'oxmysql',
}