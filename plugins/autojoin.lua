#!/usr/bin/env lua

-- hook and logger are passed in when the plugin is loadfile()'d
local hook, logger = ...

function autojoin(params, conn)
    logger:debug("Running autojoiner.")

    for _, chann in pairs(conn.channels) do
        conn:command('JOIN', chann)
    end
end

hook:event('004', autojoin)
