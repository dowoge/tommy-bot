local Discordia = require('discordia')
local json = require('json')
local HttpRequest = require('../Modules/HttpRequest.lua')
local Request = HttpRequest.Request
local SubCommandHandler = require('../Modules/SubCommandHandler.lua')
Discordia.extensions()

local ApplicationCommandOptionTypes = Discordia.enums.appCommandOptionType

local SlashCommandTools = require('discordia-slash').util.tools()

local MinecraftSubCommandHandler = SubCommandHandler.new()

local MinecraftMainCommand = SlashCommandTools.slashCommand('minecraft', 'Minecraft server related commands')

local MinecraftStatusSubCommand = SlashCommandTools.subCommand('status',
	'Get the Minecraft server status according to the preferred IP address set for this server')
local MinecraftSetIpSubCommand = SlashCommandTools.subCommand('setip',
	'Set the preferred Minecraft server IP address for this server')

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

MinecraftSubCommandHandler:AddSubCommand(MinecraftStatusSubCommand.name, function(Interaction, Command, Args)
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

	local ServerIPStr = ServerMinecraftData.IP .. ':' .. ServerMinecraftData.PORT
	local Headers, Body = Request("GET", ('https://api.mcsrvstat.us/3/%s'):format(ServerIPStr), nil,
		{ ["User-Agent"] = "tommy-bot/1.0 Main-Release" })
	if tonumber(Headers.code) ~= 200 then
		return error("Something went wrong")
	end
	local IsOnline = Body.online
	local EmbedData
	if IsOnline then
		local MaxPlayers = Body.players.max
		local OnlinePlayers = Body.players.online
		local AnonymousPlayers = OnlinePlayers
		local Players = {}
		if OnlinePlayers > 0 then
			for PlayerIndex, PlayerData in next, Body.players.list do
				table.insert(Players, PlayerData.name)
				AnonymousPlayers = AnonymousPlayers - 1
			end
		else
			table.insert(Players, 'No players online')
		end
		if AnonymousPlayers > 0 then
			for AnonymousPlayerIndex = 1, AnonymousPlayers do
				table.insert(Players, 'Anonymous Player')
			end
		end
		EmbedData = {
			title = 'Server Status for ' .. ServerIPStr,
			description = Body.motd.clean[1] .. ' (' .. Body.version .. ')',
			fields = {
				{ name = 'Players',         value = OnlinePlayers .. '/' .. MaxPlayers, inline = true },
				{ name = 'List of players', value = table.concat(Players, '\n'),        inline = true }
			},
			color = COLOURS.GREEN
		}
	else
		EmbedData = {
			title = 'Server Status for ' .. ServerIPStr,
			description = 'Server is offline',
			color = COLOURS.RED
		}
	end
	return Interaction:reply({ embed = EmbedData })
end)

MinecraftSubCommandHandler:AddSubCommand(MinecraftSetIpSubCommand.name, function(Interaction, Command, Args)
	local ServerIPStr = Args.ip

	local GuildId = Interaction.guild and Interaction.guild.id
	if not GuildId then
		return Interaction:reply('You cannot use this command outside of a Discord server')
	end

	local ServerIP = ServerIPStr:match("(%d+%.%d+%.%d+%.%d+)") or ServerIPStr:match("(%w*%.?%w+%.%w+)")
	if not ServerIP then
		return Interaction:reply('Invalid server IP')
	end
	local ServerPort = ServerIPStr:match(ServerIP .. ':(%d+)') or 25565

	local GuildMinecraftData = { IP = ServerIP, PORT = ServerPort }

	local GlobalMinecraftData = json.decode(io.open('minecraft_data.json', 'r'):read('*a'))
	GlobalMinecraftData[GuildId] = GuildMinecraftData
	io.open('minecraft_data.json', 'w+'):write(json.encode(GlobalMinecraftData)):close()

	return Interaction:reply('Successfully added `' .. ServerIP .. ':' .. ServerPort .. '` for ServerId=' .. GuildId)
end)

return {
	Command = MinecraftMainCommand,
	Callback = MinecraftSubCommandHandler:GetMainCommandCallback()
}
