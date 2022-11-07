local discordia=require('discordia')
local API=require('./../strafes_net.lua')
local commands=require('./../commands.lua')
function sleep(n) local t = os.clock() while os.clock()-t <= n do end end
discordia.extensions()
local pad = API.Pad
commands:Add('skill',{},'skill <username|mention|"me"> <game> <style> <sort?=skill|point>', function(t)
    local args=t.args
    local message=t.message
    if not _G.locked then
        if #args<3 then return message:reply('usage: `skill <username|mention|"me"> <game> <style> <sort?="skill"|"point">`') end
        local user=args[1]
        local game=API.GAMES[args[2]]
        local style=API.STYLES[args[3]]
        if not game then return message:reply('invalid game') end
        if not style then return message:reply('invalid style') end
        local sort = args[4]
        if type(sort)=='string' and not sort:lower():find('skill') and not sort:lower():find('point') then
            return message:reply('invalid sort option, valid options are "skill" or "point"')
        elseif sort==nil then
            sort = 'skill'
        end
        print('getting user')
        local user = API:GetUserFromAny(user,message)
        if type(user)=='string' then return message:reply('```'..user..'```') end
        local sn_info = API:GetUser(user.id)
        if not sn_info.ID then return message:reply('```No data with StrafesNET is associated with that user.```') end
        if sn_info.State==2 then return message:reply('```This user is currently blacklisted```') end
        print(user.name,user.id,API.GAMES[game],API.STYLES[style]:lower())
        _G.locked = true
        _G.current = {name=user.name,game=API.GAMES[game],style=API.STYLES[style]:lower()}
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
            local test_a,test_b = 0,0
            for _,time in next,times do
                local rank = API:GetTimeRank(time.ID).Rank
                local count = tonumber(API:GetMapCompletionCount(time.Map,style))
                if not rank or not count then
                    print('NO RANK OR COUNT')
                    print(rank,count)
                    rank = 1
                    count = 1
                end
                time.Points = API.CalculatePoint(rank,count)
                time.Rank = rank
                time.MapCompletionCount = count
                time.SkillRaw = rank == 1 and 1 or (count-rank)/(count-1)
                time.Skill = API.FormatSkill(time.SkillRaw)
                test_a=test_a+(count-rank)
                test_b=test_b+(count-1)
            end
            table.sort(times,sort:find('skill') and function(t1,t2)
                return t1.SkillRaw<t2.SkillRaw
            end or sort:find('point') and function(t1,t2)
                return t1.Points<t2.Points
            end)
            local points = 0
            for _,time in next,times do
                points = points+time.Points
            end
            local skillFinal = (test_a)/(test_b-1)
            local msg = 'Average Skill: '..API.FormatSkill(math.clamp(skillFinal,0,1))..'\n'..
                        'Points: '..points..'\n'..
                        pad('Map',50)..' | '..pad('Points')..' | '..pad('Skill',7)..' | '.. pad('Placement',14)..' | Time\n\n'
                        
            for _,time in next,times do
                -- msg = msg..'['..time.Rank..'/'..time.MapCompletionCount..'] '..time.Map..' ('..time.Skill..')\n'
                local mapStr = API.MAPS[game][time.Map].DisplayName..' ('..time.Map..')'
                local skill = time.Skill
                local point = time.Points
                local rankStr = time.Rank..'/'..time.MapCompletionCount
                local timeStr = API.FormatTime(time.Time)
                msg = msg.. pad(mapStr,50)..' | '..pad(point)..' | '..pad(skill,7)..' | '.. pad(rankStr,14)..' | '..timeStr..'\n'
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
    else
        --_G.current = {name=user.name,game=API.GAMES[game],style=API.STYLES[style]:lower()}
        message:reply('Bot is currently in use, please try again later ('.._G.current.name..' for '.._G.current.game..' in '.._G.current.style..')')
    end
end)

commands:Add('compare',{},'compare n1 n2', function(t)
    local args=t.args
    local message=t.message
    local n1 = args[1]
    local n2 = args[2]
    local compared = API.CalculateDifference(n1,n2)
    local compared_percent = API.CalculateDifferencePercent(n1,n2)
    message:reply(tostring(compared)..' ('..compared_percent..')')
end)

commands:Add('calc',{},nil,function(t)
    local args=t.args
    local message=t.message
    local rank = args[1]
    local count = args[2]
    local points=API.CalculatePoint(rank,count)
    local skill=API.FormatSkill(rank == 1 and 1 or (count-rank)/(count-1))
    message:reply('```Points: '..points..'\nSkill: '..skill..'```')
end )