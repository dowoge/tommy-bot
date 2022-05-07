local discordia=require('discordia')
local API=require('./../strafes_net.lua')
local commands=require('./../commands.lua')
function sleep(n) local t = os.clock() while os.clock()-t <= n do end end
discordia.extensions()
commands:Add('skill',{},'skill <username|mention|"me"> <game> <style>', function(t)
    local args=t.args
    local message=t.message
    if #args<3 then return message:reply('invalid arguments') end
    local user=args[1]
    local game=API.GAMES[args[2]]
    local style=API.STYLES[args[3]]
    if not game then return message:reply('invalid game') end
    if not style then return message:reply('invalid style') end
    print('getting user')
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
        if not roblox_user.id then return message:reply('```User not found```') end
        user=roblox_user
    end
    local sn_info = API:GetUser(user.id)
    if not sn_info.ID then return message:reply('```No data with StrafesNET is associated with that user.```') end
    print('user:',user.id)
    _G.locked = true
    local times = {}
    local res,rheaders = API:GetUserTimes(user.id,nil,style,game)
    if #res~=0 then
        local pages = tonumber(rheaders['Pagination-Count'])
        for _,v in next,res do
            table.insert(times,v)
        end
        if pages>1 then
            for i=2,pages do
                print('getting times page',i)
                res,rheaders = API:GetUserTimes(user.id,nil,style,game,i)
                for _,v in next,res do
                    table.insert(times,v)
                end
            end
        end
        print('times:',#times)
        t.message:reply('ETA: '..(math.floor(#times*3/100))..' minutes '..((#times*3)%60)..' seconds (found '..#times..' times out of '..API.MAPS[game].count..' maps)')
        local i = 1
        for _,time in next,times do
            local rank = API:GetTimeRank(time.ID).Rank
            local count = API:GetMapCompletionCount(time.Map,style)
            time.Rank = rank
            time.MapCompletionCount = count
            time.Skill = API:FormatSkill(1-((rank-1)/tonumber(count)))
            time.SkillRaw = 1-((rank-1)/tonumber(count))
            i=i+1
        end
        table.sort(times,function(t1,t2)
            return t1.SkillRaw<t2.SkillRaw
        end)
        local msg = ''
        for _,time in next,times do
            -- msg = msg..'['..time.Rank..'/'..time.MapCompletionCount..'] '..time.Map..' ('..time.Skill..')\n'
            msg = msg..API.MAPS[game][time.Map].DisplayName..' ('..time.Map..'): '..time.Skill..' for '..time.Rank..'/'..time.MapCompletionCount..' with '..API:FormatTime(time.Time)..'\n'
        end
        local txt = './skill-'..API.GAMES[game]..'-'..API.STYLES[style]:lower()..'-'..user.name..'.txt'
        local file=io.open(txt,'w+')
        file:write(msg)
        file:close()
        message:reply({
            file=txt,
            reference={
                message=message,
                mention=true
            }
        })
        os.remove(txt)
        _G.locked = false
    else
        message:reply('```No times found for that user.```')
        _G.locked = false
    end
end)