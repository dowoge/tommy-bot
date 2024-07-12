local Discordia = require('discordia')
local json = require('json')
local http_request = require('../Modules/http.lua')
Discordia.extensions()

local ApplicationCommandOptionTypes = Discordia.enums.appCommandOptionType

local SlashCommandTools = require('discordia-slash').util.tools()

local MinecraftMainCommand = SlashCommandTools.slashCommand('minecraft', 'Minecraft server related commands')

local MinecraftStatusSubCommand = SlashCommandTools.subCommand('status', 'Get the Minecraft server status according to the preferred IP address set for this server')
local MinecraftSetIpSubCommand = SlashCommandTools.subCommand('setip', 'Set the preferred Minecraft server IP address for this server')

local MinecraftSetIpOptions = SlashCommandTools.string('ip', 'The IP address of the server')
MinecraftSetIpOptions:setRequired(true)
MinecraftSetIpSubCommand:addOption(MinecraftSetIpOptions)

MinecraftMainCommand:addOption(MinecraftSetIpSubCommand)
MinecraftMainCommand:addOption(MinecraftStatusSubCommand)

local COLOURS = {
	GREEN = 0x00ff00,
	RED = 0xff0000
}

--initialize minecraft ip data
local MinecraftDataFile = io.open('minecraft_data.json', 'r')
if not MinecraftDataFile or (MinecraftDataFile and MinecraftDataFile:read('*a') == '') then
	print('no such file exists! so make it')
	io.open('minecraft_data.json', 'w+'):write(json.encode({})):close()
end
if MinecraftDataFile then
	MinecraftDataFile:close()
end

local SubCommandCallbacks = {}
local function Status(Interaction, Command, Args)
	local GuildId = Interaction.guild and Interaction.guild.id
	if not GuildId then
		return Interaction:reply('You cannot use this command outside of a Discord server', true)
	end

	local GlobalMinecraftData = json.decode(io.open('minecraft_data.json', 'r'):read('*a'))
	if not GlobalMinecraftData then
		return Interaction:reply('Could not read server data', true)
	end

	local ServerMinecraftData = GlobalMinecraftData[GuildId]
	if not ServerMinecraftData then
		return Interaction:reply('There is no data for this Discord server', true)
	end

	local ServerIPStr = ServerMinecraftData.IP..':'..ServerMinecraftData.PORT
	local Response, Headers = http_request('GET', ('https://api.mcsrvstat.us/3/%s'):format(ServerIPStr))

	local IsOnline = Response.online
	local EmbedData
	if IsOnline then
		local MaxPlayers = Response.players.max
		local OnlinePlayers = Response.players.online
		local AnonymousPlayers = OnlinePlayers
		local Players = {}
		if OnlinePlayers>0 then
			for PlayerIndex, PlayerData in next, Response.players.list do
				table.insert(Players, PlayerData.name)
				AnonymousPlayers = AnonymousPlayers-1
			end
		else
			table.insert(Players, 'No players online')
		end
		if AnonymousPlayers>0 then
			for AnonymousPlayerIndex = 1, AnonymousPlayers do
				table.insert(Players, 'Anonymous Player')
			end
		end
		EmbedData = {
	        title = 'Server Status for '..ServerIPStr,
	        description = Response.motd.clean[1]..' ('..Response.version..')',
	        fields = {
	        	{name = 'Players', value = OnlinePlayers..'/'..MaxPlayers, inline = true},
	        	{name = 'List of players', value = table.concat(Players, '\n'), inline = true}
	        },
	        color = COLOURS.GREEN
	    }
	else
		EmbedData = {
			title = 'Server Status for '..ServerIPStr,
			description = 'Server is offline',
			color = COLOURS.RED
		}
	end
	return Interaction:reply({embed = EmbedData})
end

local function SetIp(Interaction, Command, Args)
	local ServerIPStr = Args.ip

	local GuildId = Interaction.guild and Interaction.guild.id
	if not GuildId then
		return Interaction:reply('You cannot use this command outside of a Discord server')
	end

	local ServerIP = ServerIPStr:match("(%d+%.%d+%.%d+%.%d+)") or ServerIPStr:match("(%w*%.?%w+%.%w+)")
	if not ServerIP then
		return Interaction:reply('Invalid server IP')
	end
	local ServerPort = ServerIPStr:match(ServerIP..':(%d+)') or 25565

	local GuildMinecraftData = {IP = ServerIP, PORT = ServerPort}

	local GlobalMinecraftData = json.decode(io.open('minecraft_data.json','r'):read('*a'))
	GlobalMinecraftData[GuildId] = GuildMinecraftData
	io.open('minecraft_data.json','w+'):write(json.encode(GlobalMinecraftData)):close()

	return Interaction:reply('Successfully added `'..ServerIP..':'..ServerPort..'` for ServerId='..GuildId)
end
SubCommandCallbacks.status = Status
SubCommandCallbacks.setip = SetIp



local function Callback(Interaction, Command, Args)
	local SubCommandOption = Command.options[1]
	if SubCommandOption.type == ApplicationCommandOptionTypes.subCommand then
		local SubCommandName = SubCommandOption.name
		local SubCommandCallback = SubCommandCallbacks[SubCommandName]
		local SubCommandArgs = Args[SubCommandName]
		if SubCommandCallback then
			SubCommandCallback(Interaction, Command, SubCommandArgs)
		end
	end
end

return {
	Command = MinecraftMainCommand,
	Callback = Callback
}