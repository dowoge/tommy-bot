local Discordia = require('discordia')
local json = require('json')
local HttpRequest = require('../Modules/HttpRequest.lua')
local Request = HttpRequest.Request
local SubCommandHandler = require('../Modules/SubCommandHandler.lua')
Discordia.extensions()

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

local MINECRAFT_DATA_PATH = 'minecraft_data.json'

local function ReadMinecraftData()
	local Handle = io.open(MINECRAFT_DATA_PATH, 'r')
	if not Handle then return nil end
	local Contents = Handle:read('*a')
	Handle:close()
	if not Contents or Contents == '' then return nil end
	local Ok, Decoded = pcall(json.decode, Contents)
	if not Ok then return nil end
	return Decoded
end

local function WriteMinecraftData(Data)
	local Handle, OpenError = io.open(MINECRAFT_DATA_PATH, 'w+')
	if not Handle then return false, OpenError end
	Handle:write(json.encode(Data))
	Handle:close()
	return true
end

if not ReadMinecraftData() then
	WriteMinecraftData({})
end

MinecraftSubCommandHandler:AddSubCommand(MinecraftStatusSubCommand.name, function(Interaction, Command, Args)
	local GuildId = Interaction.guild and Interaction.guild.id
	if not GuildId then
		return Interaction:reply('You cannot use this command outside of a Discord server', true)
	end

	local GlobalMinecraftData = ReadMinecraftData()
	if not GlobalMinecraftData then
		return Interaction:reply('Could not read server data', true)
	end

	local ServerMinecraftData = GlobalMinecraftData[GuildId]
	if not ServerMinecraftData then
		return Interaction:reply('There is no data for this Discord server', true)
	end

    Interaction:replyDeferred()

	local ServerIPStr = ServerMinecraftData.IP .. ':' .. ServerMinecraftData.PORT
	local Headers, Body = Request("GET", ('https://api.mcsrvstat.us/3/%s'):format(ServerIPStr), nil,
		{ ["User-Agent"] = "tommy-bot/1.0 Main-Release" }, {CacheTTL = 60 * 5, MaxRetries = 5})
	if tonumber(Headers.code) ~= 200 then
		return Interaction:reply("Something went wrong", true)
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

	local GlobalMinecraftData = ReadMinecraftData() or {}
	GlobalMinecraftData[GuildId] = GuildMinecraftData
	local Ok, WriteError = WriteMinecraftData(GlobalMinecraftData)
	if not Ok then
		return Interaction:reply('Failed to save server data: ' .. tostring(WriteError), true)
	end

	return Interaction:reply('Successfully added `' .. ServerIP .. ':' .. ServerPort .. '` for ServerId=' .. GuildId)
end)

return {
	Command = MinecraftMainCommand,
	Callback = MinecraftSubCommandHandler:GetMainCommandCallback()
}
