#!/usr/bin/env lua

function autojoin(params, conn)
    logger:debug("Running autojoiner.")

    for _, chann in pairs(conn.channels) do
        conn:command('JOIN', chann)
    end
end

hook:event('004', autojoin)
