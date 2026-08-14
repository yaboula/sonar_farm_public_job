fx_version 'cerulean' -- Forcing cache refresh
game 'gta5'
lua54 'yes'

name 'sonar_farm_publicjob'
author 'Sonar'
description 'Server-authoritative public farming job for FiveM (QB-Core + ox).'
version '0.1.0'
repository 'https://github.com/yaboula/sonar_farm_public_job.git'

dependencies { 'qb-core', 'ox_lib', 'ox_inventory', 'ox_target', 'oxmysql' }

shared_scripts {
    '@ox_lib/init.lua',
    '@prism_uipack/lib_override.lua',
    'config/config.lua', 'config/crops.lua', 'config/zones.lua', 'config/minigames.lua',
    'data/fields.lua', 'shared/item_catalog.lua', 'shared/constants.lua', 'shared/utils.lua',
    'shared/time.lua', 'shared/crop_clock.lua', 'shared/conditions.lua', 'shared/growth.lua',
    'shared/physiology.lua', 'shared/inspection.lua', 'shared/zones.lua', 'shared/fields.lua',
    'shared/config_validation.lua', 'bridge/bridge.lua', 'bridge/frameworks/qbcore.lua',
    'bridge/inventory/ox_inventory.lua', 'bridge/target/ox_target.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/modules/logger/logger.lua', 'server/modules/runtime/runtime.lua',
    'server/modules/admin/permissions.lua', 'server/modules/database/database.lua',
    'server/modules/farming/lock.lua',
    'server/modules/publicjob/database.lua', 'server/modules/progression/service.lua',
    'server/modules/fields/service.lua', 'server/modules/reservations/service.lua',
    'server/modules/market/service.lua', 'server/modules/sell/service.lua',
    'server/modules/hub/runtime.lua', 'server/modules/state/state.lua',
    'server/modules/security/ratelimit.lua', 'server/modules/security/validation.lua',
    'server/modules/inventory/items.lua', 'server/modules/sync/subscriptions.lua',
    'server/modules/farming/inspection.lua',
    'server/modules/farming/physiology.lua', 'server/modules/farming/quality.lua',
    'server/modules/minigames/tomato_plant_scoring.lua', 'server/modules/minigames/sessions.lua',
    'server/modules/farming/plant.lua', 'server/modules/farming/care.lua',
    'server/modules/farming/cultivation.lua', 'server/modules/farming/harvest.lua',
    'server/modules/debug/commands.lua', 'server/main.lua',
}

client_scripts {
    'client/main.lua', 'client/modules/render/pool.lua', 'client/modules/render/crops.lua',
    'client/modules/render/target.lua', 'client/modules/interaction/actions.lua',
    'client/modules/minigames/controller.lua', 'client/modules/hub/controller.lua',
    'client/modules/inspection/controller.lua', 'client/modules/zones/slots.lua',
    'client/modules/sync/client.lua', 'client/modules/zones/blips.lua',
    'client/modules/admin/permissions.lua', 'client/modules/admin/zone_builder.lua',
    'client/modules/admin/slot_builder.lua', 'client/modules/debug/commands.lua',
}

ui_page 'nui-shell/index.html'
files {
    'nui-shell/index.html', 'minigames-ui/dist/index.html', 'minigames-ui/dist/assets/**/*',
    'minigames-ui/dist/contracts/**/*', 'inspection-ui/dist/index.html',
    'inspection-ui/dist/assets/**/*', 'web/build/index.html', 'web/build/assets/**/*',
}
