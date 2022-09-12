local discordia=require('discordia')
local API=require('./../strafes_net.lua')
local commands=require('./../commands.lua')
local pad = API.Pad

discordia.extensions()

-- args: game, style, map
commands:Add('wr', {}, 'get map wr', function(t)
    local args = t.args
    local message = t.message

    if #args < 3 then return message:reply('invalid arguments') end
    local game = API.GAMES[args[1]]
    local style = API.STYLES[args[2]]
    local map = API.MAPS[game][table.concat(args,' ',3)]

    if not game then return message:reply('invalid game') end
    if not style then return message:reply('invalid style') end
    if not map then return message:reply('invalid map') end

    local time = API:GetMapWr(map.ID,style)

    if not time then return message:reply('No time was found') end

    local user = API:GetRobloxInfoFromUserId(time.User)
    local username = user.name

    local time_formatted = API.FormatTime(time.Time)
    local date = os.date("%x", time.Date)
    local count = tonumber(API:GetMapCompletionCount(time.Map, style))
    local points = tostring(API.CalculatePoint(1, count))

    -- Username:           | Time:     | Points:      | Date:
    local n_n,t_n,p_n = 20,#time_formatted,#points
    
    local first_line = 'WR Time for map: '..map.DisplayName..' ( 1/'..count..' ) ['..API.GAMES[game]..', '..API.STYLES_LIST[style]..']'

    local second_line = pad('Username:', n_n + 1) .. '| '
                    .. pad('Time:', t_n + 1) .. '| '
                    .. pad('Points:',p_n + 1).. '| '
                    .. 'Date:'

    local third_line = pad(username, n_n + 1) .. '| '
                     .. pad(time_formatted, t_n + 1) .. '| '
                     .. pad(points, p_n + 1) .. '| '
                     .. date

    return message:reply('```' .. first_line .. '\n' .. second_line .. '\n' .. third_line .. '```')
end)