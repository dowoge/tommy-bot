local discordia=require('discordia')
local json=require('json')
local http_request=require('./../http.lua')
local Commands=require('./../commands.lua')
discordia.extensions()

local COLOURS={
	GREEN=0x00ff00,
	RED=0xff0000
}

--initialize minecraft ip data
local MinecraftDataFile=io.open('minecraft_data.json','r')
if not MinecraftDataFile or (MinecraftDataFile and MinecraftDataFile:read('*a')=='') then
	print('no such file exists! so make it')
	io.open('minecraft_data.json','w+'):write(json.encode({})):close()
end
if MinecraftDataFile then
	MinecraftDataFile:close()
end

Commands:Add('setip',{},'set ip for status',function(CommandData)
	local CommandArgs=CommandData.args
	local CommandMessage=CommandData.message
	local ServerIPStr=CommandArgs[1]
	if not ServerIPStr then
		return CommandMessage:reply('No IP provided')
	end

	local ServerIP=ServerIPStr:match("(%d+%.%d+%.%d+%.%d+)") or ServerIPStr:match("(%w*%.?%w+%.%w+)")
	if not ServerIP then
		return CommandMessage:reply('Invalid server IP')
	end
	local ServerPort=ServerIPStr:match(ServerIP..':(%d+)') or 25565

	local GuildId=CommandMessage.guild.id
	if not GuildId then
		return CommandMessage:reply('You cannot use this command outside of a Discord server')
	end

	local GuildMinecraftData={IP=ServerIP,PORT=ServerPort}

	local GlobalMinecraftData=json.decode(io.open('minecraft_data.json','r'):read('*a'))
	GlobalMinecraftData[GuildId]=GuildMinecraftData
	io.open('minecraft_data.json','w+'):write(json.encode(GlobalMinecraftData)):close()

	return CommandMessage:reply({
		content='Successfully added `'..ServerIP..':'..ServerPort..'` for ServerId='..GuildId,
		reference={
			message=CommandMessage,
			mention=true
		}
	})
end)

Commands:Add('status',{},'get status for minecraft server',function(CommandData)
	local CommandMessage=CommandData.message

	local GuildId=CommandMessage.guild.id
	if not GuildId then
		return CommandMessage:reply('You cannot use this command outside of a Discord server')
	end

	local GlobalMinecraftData=json.decode(io.open('minecraft_data.json','r'):read('*a'))
	if not GlobalMinecraftData then
		return CommandMessage:reply('Could not read server data')
	end

	local ServerMinecraftData=GlobalMinecraftData[GuildId]
	if not ServerMinecraftData then
		return CommandMessage:reply('There is no data for this Discord server')
	end

	local ServerIPStr=ServerMinecraftData.IP..':'..ServerMinecraftData.PORT
	local Response,Headers=http_request('GET',('https://api.mcsrvstat.us/3/%s'):format(ServerIPStr))

	local IsOnline=Response.online
	local EmbedData
	if IsOnline then
		local MaxPlayers=Response.players.max
		local OnlinePlayers=Response.players.online
		local AnonymousPlayers=OnlinePlayers
		local Players={}
		if OnlinePlayers>0 then
			for PlayerIndex,PlayerData in next,Response.players.list do
				table.insert(Players,PlayerData.name)
				AnonymousPlayers=AnonymousPlayers-1
			end
		else
			table.insert(Players,'No players online')
		end
		if AnonymousPlayers>0 then
			for AnonymousPlayerIndex=1,AnonymousPlayers do
				table.insert(Players,'Anonymous Player')
			end
		end
		EmbedData={
	        title='Server Status for '..ServerIPStr,
	        description=Response.motd.clean[1]..' ('..Response.version..')',
	        fields={
	        	{name='Players',value=OnlinePlayers..'/'..MaxPlayers,inline=true},
	        	{name='List of players',value=table.concat(Players,'\n'),inline=true}
	        },
	        color=COLOURS.GREEN
	    }
	else
		EmbedData={
			title='Server Status for '..ServerIPStr,
			description='Server is offline',
			color=COLOURS.RED
		}
	end
	return CommandMessage:reply({embed=EmbedData})
end)