fx_version 'cerulean'
game 'gta5'
name 'st-core'
author 'StormsReaper'
description 'Storms Technologies core framework for FiveM.'
version '0.6.2'
lua54 'yes'
ui_page 'html/index.html'
shared_scripts {'config.lua','shared/validation.lua'}
client_scripts {'client.lua','client/dmv.lua','client/unified_dmv.lua','client/sales.lua','integrations/jg-dealerships/client.lua'}
server_scripts {'@oxmysql/lib/MySQL.lua','server.lua','server/payments.lua','server/documents.lua','server/purchases.lua','server/vehicles.lua','server/vehicle_history.lua','server/titles.lua','server/licenses.lua','server/insurance.lua','server/insurance_claims.lua','server/insurance_cron.lua','server/dmv_services.lua','server/dmv_api.lua','server/unified_dmv.lua','server/enforcement.lua','server/mdt.lua','server/dmv.lua','server/sales.lua','integrations/jg-dealerships/server.lua'}
files {'html/index.html','html/style.css','html/app.js','html/claims.js','html/unified-dmv.js','html/contract-hotkeys.js'}
dependencies {'oxmysql','ox_inventory'}
