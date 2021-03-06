#!/usr/bin/env lua

-- handles the details of the irc protocol/connection

pcall(function() require("luarocks.require") end)

local socket = require("socket")
local pcre = require("rex_pcre")

IRC = {}
IRC.re_line_with_prefix = pcre.new('(.*?) (.*?) (.*)')
IRC.re_line_no_prefix = pcre.new('(.*?) (.*)')
IRC.re_netmask = pcre.new(':?([^!@]*)!?([^@]*)@?(.*)')
IRC.re_param_ref = pcre.new('(?:^|(?<= ))(:.*|[^ ]+)')

function IRC:new(config, copas, logger)
    logger:info('Initializing new IRC connection')

    local object = {
        config = config,
        copas = copas,
        logger = logger,
        server = config.server,
        port = config.port,
        nick = config.nick,
        channels = config.channels,
        sock = nil
    }
    setmetatable(object, { __index = IRC })
    return object
end

function IRC:connect()
    local fmt = "Connecting to %s:%d as %s"
    self.logger:info(fmt:format(self.server, self.port, self.nick))

    local sock, err = socket.connect(self.server, self.port)
    if sock == nil then
        return nil, err
    end

    self.sock = sock
    assert(self.sock:settimeout(1))
    self.sock:setoption("keepalive", true)
    self.sock = assert(self.copas.wrap(self.sock))

    self:command('NICK', self.nick)
    self:command('USER', 'moonbot', 3, '*', 'Moonbot')

    return true -- indicate success connecting

end

function IRC:command(command, ...)
    if ... then
        args = {...}
        args[#args] = ':' .. args[#args]
        message = command .. ' ' .. table.concat(args, ' ')
    else
        message = command
    end

    self.logger:debug('[CMD] ' .. message)
    self:send(message)

end

function IRC:send(message)
    if not self.sock then return nil, "Dead socket." end

    self.logger:debug("[SEND] " .. message)

    self.sock:send(message .. "\r\n")
end

function IRC:recv(message)
    -- Receives (and parses) a message from the IRC server

    self.logger:info('RECV: ' .. message)

    local prefix = ''
    local command, params = nil

    if string.find(message, ':') == 1 then
        prefix, command, params = self.re_line_with_prefix:match(message)
    else
        command, params = self.re_line_no_prefix:match(message)
    end

    local nick, user, host = nil
    nick, user, host = self.re_netmask:match(prefix)

    local paramlist = {}
    for param in pcre.gmatch(params, self.re_param_ref) do
        table.insert(paramlist, param)
    end

    if #paramlist > 0 then
        if paramlist[#paramlist]:find(':') == 1 then
            -- strip the : from the beginning
            paramlist[#paramlist] = paramlist[#paramlist]:sub(2)
        end
    end

    if command == 'PING' then
        self:command('PONG', unpack(paramlist))
    end

    -- search the plugin event list for this command
    if plugins.event[command] then
        for _, fn in pairs(plugins.event[command]) do
            fn(paramlist, self)
        end
    end

end

function IRC:loop()
    -- The main loop for an IRC connection

    while self.sock do
        local line, err, partial = self.sock:receive("*l")
        if line == nil then
            self.logger:error('No line received.')
            return line, err, partial
        end

        self:recv(line)

    end
end

return IRC
