server_script '@ElectronAC/src/include/server.lua'
client_script '@ElectronAC/src/include/client.lua'
--shared_script '@PegasusAC/server/install/EP.lua'
--shared_script "@ReaperV4/bypass.lua"
lua54 "yes" -- needed for Reaper


------------------------------------------
author 'Eh Eh Eh Eh' -- [[ Chuckles ]] --
fx_version 'cerulean'
game 'gta5'

lua54 'yes'

shared_scripts {
	'@ox_lib/init.lua',
	'@lation_ui/init.lua',
	'bridge/debug.lua',
	'bridge/config.lua',
	'bridge/framework.lua',
	'shared/config.lua'
}

client_scripts {
	'bridge/client/functions.lua',
	'bridge/client/esx.lua',
	'bridge/client/qb.lua',
	'bridge/client/qbox.lua',
	'bridge/client/mythic.lua',
	'client/client.lua'
}

server_scripts {
	'bridge/server/functions.lua',
	'bridge/server/esx.lua',
	'bridge/server/qb.lua',
	'bridge/server/qbox.lua',
	'bridge/server/mythic.lua',
	'server/server.lua'
}

files {
	'shared/config.lua',
	'client/client.lua',
	'server/server.lua',
	'bridge/config.lua',
	'bridge/debug.lua',
	'locales/*.json'
}

escrow_ignore {
	'shared/config.lua',
	'bridge/config.lua',
	'bridge/debug.lua',
	'locales/*.json'
}