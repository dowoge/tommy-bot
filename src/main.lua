-- local discordia = require('discordia')
-- local ordinal = require('./modules/ordinal.lua')
-- local token = require('./modules/token.lua')
-- local APIKey = require('./modules/apikey.lua')
-- local APIHeader = {{'api-key',APIKey}}
-- local prefix = '%'
-- local strafesurl = 'https://api.strafes.net/v1/'
-- local cooldown = false
-- local client = discordia.Client()
-- discordia.extensions()

-- local t=tostring

-- local games={['bhop']=1,['surf']=2}
-- local gamesr={[1]='bhop',[2]='surf'}
-- local states={[0]='Default',[1]='Whitelisted',[2]='Blacklisted',[3]='Pending'}
-- local ranks={'New (1)','Newb (2)','Bad (3)','Okay (4)','Not Bad (5)','Decent (6)','Getting There (7)','Advanced (8)','Good (9)','Great (10)','Superb (11)','Amazing (12)','Sick (13)','Master (14)','Insane (15)','Majestic (16)','Baby Jesus (17)','Jesus (18)','Half God (19)','God (20)'}
-- local stylesr={'Autohop','Scroll','Sideways','Half-Sideways','W-Only','A-Only','Backwards',}
-- local styles={['autohop']=1,['scroll']=2,['sideways']=3,['halfsideways']=4,['wonly']=5,['aonly']=6,['backwards']=7}

-- setmetatable(styles,{__index=function(self,i)
--     if i=='a' then i='auto'elseif i=='hsw'then i='half'elseif i=='s'then i='scroll'elseif i=='sw'then i='side'elseif i=='bw'then i='back'end
--     for ix,v in pairs(self) do
--         if string.sub(ix,1,#i):find(i:lower()) then
--             return self[ix]
--         end
--     end
-- end})
-- local getUserID=function(message,name)
--     if type(tonumber(name))=='number' then
--         return name
--     else
--         return get('https://api.roblox.com/users/get-by-username?username='..name)['Id']
--     end
--     message:reply('No user found')
-- end
-- local getUserInfoFromID=function(userid)
--     local d={excludeBannedUsers=false,userIds={userid}}
--     local res=post('https://users.roblox.com/v1/users',nil,json.encode(d))['data'][1]
--     if not res then res=get('https://users.roblox.com/v1/users/'..userid) end
--     return res,json.stringify(d)
-- end
-- local getIdFromRover=function(message,userid)
--     local idfromRover=get('https://verify.eryn.io/api/user/'..userid)
--     if not idfromRover.error then
--         return idfromRover.robloxId
--     end
--     message:reply(idfromRover.error)
--     return
-- end
-- local hasStrafesData=function(message,id)
--     local info=get(strafesurl..'user/'..id,APIHeader)
--     if info.State then
--         return true
--     end
--     message:reply('```User has no data with StrafesNET.```')
--     return false
-- end
-- client:on('ready', function()
-- 	client:info('yeah '.. client.user.tag)
-- 	client:info('--------------------------------------------------------------')
--     client:setGame({name='%help';type=2})
-- end)


-- client:on('messageCreate',function(message)
--     if message.author==client.user then return end
--     local content = message.content
--     local author = message.author
--     local mentioned = message.mentionedUsers
--     local mention = mentioned.first
--     if content:sub(1,1)=='%'then
--         local args = content:split(' ')
--         -- [user lookup]
--         if args[1]=='%test'then
--         elseif args[1] == prefix..'user' and args[2] then
--             if args[2]:find('@') or args[2]=='me' then
--                 local id=getIdFromRover(message,(mention and mention.id or author.id))
--                 if not id then message:addReaction('❌') return end
--                 if not hasStrafesData(message,id) then message:addReaction('❌') return end
--                 local info=getUserInfoFromID(id)
--                 local res=get(strafesurl..'user/'..id,APIHeader)
--                 message:reply('```'..info.displayName..' ('..info.name..')\n'..info.id..'\n'..states[res.State]..'```')
--             elseif args[2]~='me' and not args[2]:find('@') then
--                 local id=getUserID(message,args[2])
--                 if not id then message:addReaction('❌') return end
--                 if not hasStrafesData(message,id) then message:addReaction('❌') return end
--                 local info=getUserInfoFromID(id)
--                 local res=get(strafesurl..'user/'..id,APIHeader)
--                 message:reply('```'..info.displayName..' ('..info.name..')\n'..res.ID..'\n'..states[res.State]..'```')
--             end
--         elseif args[1]==prefix..'rank' and args[2] and args[3] and args[4] then
--             if args[2]:find('@')or args[2]=='me'then
--                 local id=getIdFromRover(message,(mention and mention.id or author.id))
--                 local game=games[args[3]]
--                 local style=styles[args[4]]
--                 if not id then message:addReaction('❌') return end
--                 if not hasStrafesData(message,id) then message:addReaction('❌') return end
--                 local res
--                 local info
--                 local rinfo
--                 local s,e=pcall(function()
--                     res=get(strafesurl..'rank/'..id..'?style='..style..'&game='..game,APIHeader) --/id?style=1&game=2
--                     info=get(strafesurl..'user/'..id,APIHeader)
--                     rinfo=getUserInfoFromID(id)
--                 end)
--                 table.foreach(rinfo,print)
--                 if not s then message:reply('style/game specified incorrectly i think')return end
--                 if not rinfo.name then
--                     message:reply('wait plz :pleading_face:')
--                     return
--                 end
--                 local userInfo={
--                     id=id,
--                     displayName=rinfo.displayName,
--                     name=rinfo.name,
--                     style=stylesr[style],
--                     rank=ranks[math.floor((res.Rank*19)+1)],
--                     skill=math.floor(res.Skill*100)~=100 and string.sub(math.floor(((res.Skill*100)*1000+.5))/1000, 1, #'00.000')..'%' or '100.000%',
--                     placement=res.Placement,
--                     state=states[info.State],
--                 }
--                 message:reply('```Name: '..userInfo.displayName..' ('..userInfo.name..')\nStyle: '..userInfo.style..'\nRank: '..userInfo.rank..'\nSkill: '..userInfo.skill..'\nPlacement: '..ordinal(userInfo.placement)..'\nState: '..userInfo.state..'```')
--             else
--                 local id = getUserID(message,args[2])
--                 local game=games[args[3]]
--                 local style=styles[args[4]]
--                 if not id then message:addReaction('❌') return end
--                 if not hasStrafesData(message,id) then message:addReaction('❌') return end
--                 local res
--                 local info
--                 local rinfo
--                 local s,e=pcall(function()
--                     res=get(strafesurl..'rank/'..id..'?style='..style..'&game='..game,APIHeader) --/id?style=1&game=2
--                     info=get(strafesurl..'user/'..id,APIHeader)
--                     rinfo=getUserInfoFromID(id)
--                 end)
--                 if not s then message:reply('style/game specified incorrectly i think')return end
--                 if not rinfo.name then
--                     message:reply('wait plz :pleading_face:')
--                     return
--                 end
--                 local userInfo={
--                     id=id,
--                     displayName=rinfo.displayName,
--                     name=rinfo.name,
--                     style=stylesr[style],
--                     rank=ranks[math.floor((res.Rank*19)+1)],
--                     skill=math.floor(res.Skill*100)~=100 and string.sub(math.floor(((res.Skill*100)*1000+.5))/1000, 1, #'00.000')..'%' or '100.000%',
--                     placement=res.Placement,
--                     state=states[info.State],
--                 }
--                 message:reply('```Name: '..userInfo.displayName..' ('..userInfo.name..')\nStyle: '..userInfo.style..'\nRank: '..userInfo.rank..'\nSkill: '..userInfo.skill..'\nPlacement: '..ordinal(userInfo.placement)..'\nState: '..userInfo.state..'```')
--             end
--         elseif args[1]==prefix..'ranks' and args[2] and args[3]then
--             local game=games[args[2]]
--             local style=styles[args[3]]
--             if not game or not style then message:reply('game/style specified incorrectly i think')return end
--             -- message:reply(strafesurl..'rank?style='..style..'&game='..game..'&page='..(type(tonumber(args[4]))=='number'and args[4]or'1'))
--             local res=get(strafesurl..'rank?style='..style..'&game='..game..'&page='..(type(tonumber(args[4]))=='number'and args[4]or'1'),APIHeader)
--             local final=''
--             for i,v in pairs(res) do
--                 local userStats=res[i]
--                 local rinfo=getUserInfoFromID(userStats.User)
--                 if not rinfo.name then
--                     message:reply('wait plz :pleading_face:')
--                     return
--                 end
--                 local userInfo={
--                     id=userStats.User,
--                     displayName=rinfo.displayName,
--                     name=rinfo.name,
--                     style=stylesr[style],
--                     rank=ranks[math.floor((userStats.Rank*19)+1)],
--                     skill=math.floor(userStats.Skill*100)~=100 and string.sub(math.floor(((userStats.Skill*100)*1000+.5))/1000, 1, #'00.000')..'%' or '100.000%',
--                     placement=userStats.Placement,
--                 }
--                 final=final..(userInfo.placement)..string.rep(' ',10-#(tostring(userInfo.placement)))..' | '..userInfo.name..string.rep(' ',32-#userInfo.name)..' | '..userInfo.rank..string.rep(' ',17-#userInfo.rank)..' | '..userInfo.skill..'\n'
--             end
--             local file=io.open('./rank.txt','w+')
--             file:write(final)
--             file:close()
--             message:reply({file='./rank.txt'})
--             os.remove('./rank.txt')
--         elseif args[1]==prefix..'maps' and args[2] then
--             local game=games[args[2]]
--             local page=type(tonumber(args[3]))=='number' and args[3] or 1
--             if not game then message:reply('game specified incorrectly i think')return end
--             local res=get(strafesurl..'map?game='..game..'&page='..page,APIHeader)
--             local final='name                             | map maker                | game   | times loaded\n'
--             for ix=1,#res do --Map name:                     | Creator:                           | Game: | Server loads:
--                 local v=res[ix]
--                 final=final..t(v.DisplayName)..string.rep(' ',32-#v.DisplayName)..' | '..v.Creator..string.rep(' ',24-#v.Creator)..' | '..gamesr[v.Game]..string.rep(' ',6-#gamesr[v.Game])..' | '..t(v.PlayCount)..'\n'
--             end
--             local file=io.open('./map.txt','w+')
--             file:write(final)
--             file:close()
--             message:reply({file='./map.txt'})
--             os.remove('./map.txt')
--         elseif args[1]==prefix..'help'then
--             message:reply('```rank <user> <game> <style>\nranks <game> <style>\nuser <user>\nmaps <game>\nhelp```')
--         end
--         if message.guild~=nil then
--             client:getUser('697004725123416095'):getPrivateChannel():send('```'..message.content..'```'..'from '.. message.author.tag..' in '..message.guild.name..': '..message.channel.mentionString..' ('..message.link..')')
--         else
--             client:getUser('697004725123416095'):getPrivateChannel():send('```'..message.content..'```'..'from dms with '.. message.author.mentionString..' ('..message.link..')')
--         end
--     end
-- end)
local discordia = require('discordia')
local token = require('./modules/token.lua')
local commands=require('./modules/commands.lua')
local prefix = ','
local client = discordia.Client()
_G.client = client
_G.locked = false

discordia.extensions()

client:on('ready',function()
    commands:INIT()
    local f=io.open('restart.txt','r+'):read()
    local t=tostring(f):split(',')
    if #t==3 then
        client:getGuild(t[1]):getChannel(t[2]):send(
            {
                content='bot ready',
                reference={
                    message=client:getChannel(t[2]):getMessage(t[3]),
                    mention=true
                }
            }
        )
        io.open('restart.txt','w+'):write(''):close()
    else
        print('restart.txt is empty or something so probably a first start')
    end
end)

function parseMentions(message)
    local content=message.content
    local usersMentioned={}
    if #message.mentionedUsers>0 then
        for user in message.mentionedUsers:iter() do
            usersMentioned[user.id]=user
        end
    end
    local msgSplit=content:split(' ')
    for i,v in next, msgSplit do
        if v:match('<@![0-9]+>') then
            local id=v:match('<@!([0-9]+)>')
            if usersMentioned[id] then
                msgSplit[i]=usersMentioned[id].mentionString
            end
        end
    end
    return table.concat(msgSplit,' ') or '',usersMentioned
end

client:on('messageCreate', function(message)
    if message.author.bot then return end
    local content,mentions=parseMentions(message)
    if content:sub(1,#prefix)==prefix then
        local cmd=content:sub(#prefix+1,#content)
        local args=cmd:split(' ')
        local cmdName=args[1]
        table.remove(args,1)
        local command=commands.command_list[cmdName]
        if not _G.locked then
            if command~=nil then
                if message.guild~=nil then
                    local s,e=pcall(function()
                        command.exec({message=message,args=args,mentions=mentions,t={client,discordia,token}})
                    end)
                    if not s then
                        message:reply('tripped : '..e:split('/')[#e:split('/')])
                    end
                else
                    message:reply('i will not let you type in dms!!! 😠')
                end
            else
                message:reply('command does not exist 👎')
            end
        else
            message:reply('bot is locked, please wait until it is unlocked')
        end 
    end
end)

client:run('Bot '..token)