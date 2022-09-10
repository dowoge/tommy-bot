local discordia=require('discordia')
local API=require('./../strafes_net.lua')
local commands=require('./../commands.lua')
local pad = API.Pad

discordia.extensions()

-- args: user, game, style, map
commands:Add('pb', {}, 'get placement on map', function(t)
    local args = t.args
    local message = t.message

    if #args < 4 then return message:reply('invalid arguments') end

    local user = API:GetUserFromAny(args[1],message)
    local sn_info = API:GetUser(user.id)
    local game = API.GAMES[args[2]]
    local style = API.STYLES[args[3]]
    local map = API.MAPS[game][args[4]]

    -- i love checks
    if not game then return message:reply('invalid game') end
    if not style then return message:reply('invalid style') end
    if not map then return message:reply('invalid map') end
    if not sn_info.ID then return message:reply('```No data with StrafesNET is associated with that user.```') end
    if sn_info.State==2 then return message:reply('```This user is currently blacklisted```') end

    local time = API:GetUserTimes(user.id, map.ID, style, game)[1]

    if not time then return message:reply('idk bruh') end

    local rank = API:GetTimeRank(time.ID).Rank
    local count = tonumber(API:GetMapCompletionCount(time.Map, style))

    if not rank or not count then
        rank = 1
        count = 1
    end

    local time_formatted = API.FormatTime(time.Time)
    local date = os.date("%x", time.Date)
    local placement = rank .. '/' .. count
    local points = API:CalculatePoint(rank, count)

    local t_n, d_n, p_n= #time_formatted, 8, math.max(#placement, 10)

    local first_line = pad('Time:', t_n + 1) .. '| '
                    .. pad('Date:', d_n + 1) .. '| '
                    .. pad('Placement:', p_n + 1) .. '| '
                    .. 'Points:'

    local second_line = pad(time_formatted, t_n + 1) .. '| '
                     .. pad(date, d_n + 1) .. '| '
                     .. pad(placement, p_n + 1) .. '| '
                     .. tostring(points)

    return message:reply('```' .. first_line .. '\n' .. second_line .. '```')
end)
