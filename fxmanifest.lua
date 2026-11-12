fx_version 'cerulean'
game 'gta5'
provide 'qb-smallresources'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'kora_utils'
author 'Jamie'
version '0.2.0'
description 'A bundle of small always-on world/player tweaks built on kora_lib -- idle-camera kill, weapon-wheel removal, wanted-level suppression, zeroed health regen, and weapon/vehicle blacklists, all sharing one tick coordinator.'

dependencies { 'kora_lib', 'kora_core', 'kora_inventory' }

-- Pulls in the Kora.* proxy (Kora.notify is used by modules/blacklist/client.lua).
-- See kora_lib's AGENTS.md for why a consumer resource loads init.lua this way.
shared_script '@kora_lib/init.lua'

-- config.lua is shared so both the client modules and the server-side blacklist
-- handler read the same Config table.
shared_scripts {
    'config.lua'
}

-- Explicit load order, never globbed -- same discipline as kora_lib's own
-- fxmanifest. client/core.lua defines Small.onFrame/onInterval/onSpawn and MUST
-- load before any module that schedules through them; client/util.lua defines
-- Small.hashSet, used by modules/blacklist. A `modules/**/client.lua` glob would
-- expand alphabetically and load `blacklist` before `core`/`util` ever exist,
-- so every module file is listed by hand, core-and-util first.
client_scripts {
    'client/core.lua',
    'client/util.lua',
    'client/compat.lua',
    'client/hud.lua',
    'modules/seatbelt/client.lua',

    'modules/idlecamera/client.lua',
    'modules/weaponwheel/client.lua',
    'modules/vehiclerewards/client.lua',
    'modules/wantedlevel/client.lua',
    'modules/healthregen/client.lua',
    'modules/crouch/client.lua',
    'modules/blacklist/client.lua',
    'modules/worlddepop/client.lua'
}

-- Only the vehicle/ped blacklist has a server half (authoritative spawn refusal
-- via OneSync's entityCreating). config.lua above already loaded it Config.
server_scripts {
    'modules/blacklist/server.lua',
    'server/timedjobs.lua',
    'modules/seatbelt/server.lua'
}

-- kora_qa: Gherkin test scenarios (converted legacy tests), see [kora]/kora_qa/README.md
qa_feature 'tests/*.feature'
