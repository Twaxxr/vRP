fx_version 'adamant'
games { 'gta5' }

local client = client_scripts
local server = server_scripts

client {
    '@vrp/client_alpha/Tunnel.lua',
    '@vrp/client_alpha/Proxy.lua',
    'client.lua'
}

server {
    '@vrp/lib/utils.lua',
    'server.lua'
}