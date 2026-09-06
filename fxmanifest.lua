fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'qbsmallresources'
author 'Jamie'
version '1.0.0'
description 'A bundle of small always-on world/player tweaks built on qblib -- idle-camera kill, weapon-wheel removal, wanted-level suppression, zeroed health regen, and weapon/vehicle blacklists, all sharing one tick coordinator.'

dependency 'qblib'

-- Pulls in the QB.* proxy (QB.notify is used by modules/blacklist/client.lua).
-- See qblib's AGENTS.md for why a consumer resource loads init.lua this way.
shared_script '@qblib/init.lua'

-- config.lua is shared so both the client modules and the server-side blacklist
-- handler read the same Config table.
shared_scripts {
    'config.lua'
}

-- Explicit load order, never globbed -- same discipline as qblib's own
-- fxmanifest. client/core.lua defines Small.onFrame/onInterval/onSpawn and MUST
-- load before any module that schedules through them; client/util.lua defines
-- Small.hashSet, used by modules/blacklist. A `modules/**/client.lua` glob would
-- expand alphabetically and load `blacklist` before `core`/`util` ever exist,
-- so every module file is listed by hand, core-and-util first.
client_scripts {
    'client/core.lua',
    'client/util.lua',

    'modules/idlecamera/client.lua',
    'modules/weaponwheel/client.lua',
    'modules/wantedlevel/client.lua',
    'modules/healthregen/client.lua',
    'modules/crouch/client.lua',
    'modules/blacklist/client.lua',
    'modules/worlddepop/client.lua'
}

-- Only the vehicle/ped blacklist has a server half (authoritative spawn refusal
-- via OneSync's entityCreating). config.lua above already loaded it Config.
server_scripts {
    'modules/blacklist/server.lua'
}
