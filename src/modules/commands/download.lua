local discordia=require('discordia')
local commands=require('./../commands.lua')
discordia.extensions()

function split(s,d)
    local t,c,i={},'',0
    for k in s:gmatch('.') do
        i=i+1
        if k==d and string.sub(s,i+1)~='' then
            t[#t+1]=c
            c=''
            goto continue
        end
        c=c..k
        ::continue::
    end
    t[#t+1]=c
    return t
end

function clearTmp()
    for file in io.popen([[dir "./tmp" /b]]):lines() do
        if file then
            os.remove('./tmp/'..file)
        end
    end
end
function isTmpEmpty()
    local dir = io.popen([[dir "./tmp" /b]]):read()
    return dir==nil, dir, dir~=nil and split(dir,'\n') or {}
end

commands:Add('sc',{},'download soundcloud song (usage: "sc [link]")', function(t)
    local args = t.args
    local message = t.message
    if args[1] then
        if args[1]:match('https://soundcloud.com/[%w-_]+/[%w-_]+') then
            clearTmp()
            local link=args[1]:match('https://soundcloud.com/[%w-_]+/[%w-_]+')
            message:reply('Attempting to download song from <'..link..'>')
            local filepath = ''
            local s=io.popen('ytdl.exe -o "./tmp/%(fulltitle)s.%(ext)s" '..link)
            local songName
            repeat
                local str = s:read()
                if str then
                    local tag = str:match('^%[(.+)%]')
                    if tag=='soundcloud' then
                        local song = str:match('^%[soundcloud%] (.+):')
                        if song:match('%d+')~=song then
                            songName = song:match('.+/(.+)')
                        end
                    end
                end
            until s:read()==nil
            s:close()
            if type(songName)=='string' and songName~='' then
                message:reply('found song: '..songName)
                local empty,file = isTmpEmpty()
                if not empty then
                    message:reply({file='./tmp/'..file})
                    os.remove('./tmp/'..file)
                end
            end
        else
            message:reply('Invalid URL')
        end
    else
        message:reply('No URL provided')
    end
end)

-- commands:Add('ct',{},'',function()
--     clearTmp()
-- end)
-- commands:Add('ft',{},'',function()
--     filterTmp()
-- end)