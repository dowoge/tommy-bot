local SlashCommandTools = require('discordia-slash').util.tools()

local LINK_EXPLANATION_MESSAGE = [[Use the `!link <roblox username>` command with <@759490176119472178> to start the linking process, make sure your DMs are open so it can message you. For more information, use `!help link`]]

local LinkCommand = SlashCommandTools.slashCommand('link', 'Explains how to link your Roblox account to your discord account')

local function Callback(Interaction, Command, Args)
	return Interaction:reply(LINK_EXPLANATION_MESSAGE, true)
end

return {
	Command = LinkCommand,
	Callback = Callback
}