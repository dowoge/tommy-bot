local SlashCommandTools = require('discordia-slash').util.tools()

local GetProfilePictureCommand = SlashCommandTools.userCommand('Get profile picture', 'Gets user avatar')

local function Callback(Interaction, Command, Member)
	local AvatarURL = Member:getAvatarURL(1024)
	if AvatarURL then
		return Interaction:reply(AvatarURL, true)
	end
	return Interaction:reply('Could not retrieve avatar', true)
end

return {
	Command = GetProfilePictureCommand,
	Callback = Callback
}