------------------------------------------
author 'Hollow' -- [[ Chuckles ]] --
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