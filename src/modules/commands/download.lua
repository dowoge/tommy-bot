local discordia=require('discordia')
local commands=require('./../commands.lua')
discordia.extensions()
local io = io

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
    for file in io.popen([[dir "./tmp" /b]]):lines() do os.remove('./tmp/'..file) end
end

commands:Add('yt',{},"wip", function(t)
    clearTmp()
    local args = t.args
    local message = t.message
    if args[1] then
        if args[1]:match('?v=([%w-_]+)') or args[1]:match('youtu.be/([%w-_]+)') then
            local id=args[1]:match('?v=([%w-_]+)') or args[1]:match('youtu.be/([%w-_]+)')
            message:reply('Attempting to download song ID='..id)
                local filepath = ''
                local name
                local s=io.popen('ytdl.exe -x --audio-format mp3 --output "./tmp/%(title)s - %(uploader)s.%(ext)s" '..id)
                if s then
                    repeat
                        a = split(io.popen([[dir "./tmp" /b]]):read('*all'),'\n')
                        for _,v in next,a do
                            if v:sub(#v-3)=='.mp3' then
                                print(v)
                                filepath=v
                                break
                            end
                        end
                    until filepath:sub(#filepath-3)=='.mp3'
                    if filepath then
                        message:reply('Found file: '..filepath)
                        message:reply({file='./tmp/'..filepath})
                        os.remove('./tmp/'..filepath)
                    else
                        message:reply('Error downloading song (this is not supposed to happen)')
                    end
                else
                    message:reply('Error downloading song')
                end
        else
            message:reply('Invalid URL')
        end
    else
        message:reply('No URL provided')
    end
end)
commands:Add('sc',{},"wip", function(t)
    clearTmp()
    local args = t.args
    local message = t.message
    if args[1] then
        if args[1]:match('https://soundcloud.com/[%w-_]+/[%w-_]+') then
            local link=args[1]:match('https://soundcloud.com/[%w-_]+/[%w-_]+')
            message:reply('Attempting to download song from <'..link..'>')
            local filepath
            local s=io.popen('ytdl.exe -o "./tmp/%(title)s - %(uploader)s.%(ext)s" '..link)
            if s then
                repeat
                    local name = io.popen([[dir "./tmp" /b]]):read('*all')
                    filepath = name:sub(1,name:len()-1)
                until filepath:sub(#filepath-3)=='.mp3'
                if filepath then
                    message:reply('Found file: '..filepath)
                    message:reply({file='./tmp/'..filepath})
                    os.remove('./tmp/'..filepath)
                else
                    message:reply('Error downloading song (this is not supposed to happen)')
                end
            else
                message:reply('Error downloading song')
            end
        else
            message:reply('Invalid URL')
        end
    else
        message:reply('No URL provided')
    end
end)