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
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    'server.lua'
}

files {
    'config.lua',
    'client.lua',
    'server.lua',
}

escrow_ignore {
    'config.lua'
}