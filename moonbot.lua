#!/usr/bin/env lua

pcall(function() require("luarocks.require") end)

-- init the logger
require("logging.console")
local logger = logging.console()
logger:setLevel(logging.DEBUG)
logger:info('Loading dependencies...')

-- initialize the dumper utility for debug purposes
require("util.dumper")
function dump(...)
    print(DataDumper(...), "\n---")
end

-- load dependencies
local copas = require("copas")
local IRC = require("core.irc")

-- TODO load this from an actual config
local networks = {
    synirc = {
        server = 'irc.synirc.net',
        port = 6667,
        nick = 'moonbot',
        channels = { '#cobot' }
    },
}

-- TODO load this from config
local modules = {
    "autojoin.lua",
}

connections = {}

plugins = { command = {}, event = {} }

local hook = {}
function hook:event(event, fn)
    logger:debug('Registering event for code ' .. event)
    if plugins.event[event] == nil then
        plugins.event[event] = {}
    end

    table.insert(plugins.event[event], fn)
end

-- Load all modules
logger:info('Loading modules')

for _, mod in pairs(modules) do
    logger:debug('Loading ' .. mod)
    assert(loadfile('plugins/' .. mod))(hook, logger)
end

for label, opts in pairs(networks) do
    conn = IRC:new(opts, copas, logger)
    connections[label] = conn

    local sock, err = connections[label]:connect()
    if sock then
        copas.addthread(function() connections[label]:loop() end)
    else
        local fmt = "Could not connect to %s (%s:%d)"
        logger:error(fmt:format(label, opts.server, opts.port))
    end
end

while true do
    copas.step(1)
    logger:debug('TICK')
end
