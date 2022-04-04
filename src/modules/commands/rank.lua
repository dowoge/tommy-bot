local discordia=require('discordia')
local API=require('./../strafes_net.lua')
local commands=require('./../commands.lua')
function dump(a,b,c,d)b=b or 50;d=d or("DUMP START "..tostring(a))c=c or 0;for e,f in next,a do local g;if type(f)=="string"then g="\""..f.."\""else g=tostring(f)end;d=d.."\nD "..string.rep(" ",c*2)..tostring(e)..": "..g;if type(f)=="table"then if c>=b then d=d.." [ ... ]"else d=dump(f,b,c+1,d)end end end;return d end
discordia.extensions()
commands:Add('rank',{},'rank <username|mention|"me"> <game> <style>', function(t)
    local args=t.args
    local message=t.message
    if #args<3 then return message:reply('invalid arguments') end
    local user=args[1]
    local game=API.GAMES[args[2]]
    local style=API.STYLES[args[3]]
    if user=='me' then
        local me=message.author
        local roblox_user=API:GetRobloxInfoFromDiscordId(me.id)
        if not roblox_user.id then return message:reply('```You are not registered with the RoverAPI```') end
        user=roblox_user
    elseif user:match('<@%d+>') then
        local user_id=user:match('<@(%d+)>')
        local member=message.guild:getMember(user_id)
        local roblox_user=API:GetRobloxInfoFromDiscordId(member.id)
        if not roblox_user.id then return message:reply('```You are not registered with the RoverAPI```') end
        user=roblox_user
    else
        local roblox_user=API:GetRobloxInfoFromUsername(user)
        user=roblox_user
    end
    local rank = API:GetRank(user.id,game,style)
    local sn_info = API:GetUser(user.id)
    local rank_string = API:FormatRank(rank.Rank)
    local skill = API:FormatSkill(rank.Skill)
    local formatted_message = '```'..
    'Name: '..user.displayName..' ('..user.name..')\n'..
    'Style: '..API.STYLES_LIST[rank.Style]..'\n'..
    'Rank: '..rank_string..'\n'..
    'Skill: '..skill..'\n'..
    'Placement: '..rank.Placement..'\n'..
    'State '..API.STATES[sn_info.State]..'\n'..
    '```'
    message:reply(formatted_message)
end)