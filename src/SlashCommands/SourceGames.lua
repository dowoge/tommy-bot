local SlashCommandTools = require('discordia-slash').util.tools()

local SubCommandHandler = require('../Modules/SubCommandHandler.lua')

local SOURCE_DEFAULT_M_YAW = 0.022

local SourceSubCommandHandler = SubCommandHandler.new()
local SourceMainCommand = SlashCommandTools.slashCommand('source', 'Utility commands for source games (CS:S specifically)')

local VSensMultiplierSubCommand = SlashCommandTools.subCommand('vsensmul', 'Apply a vertical multiplier to your sensitivity (roblox "myaw" equivalent)')
local VSensMultiplierSensitivityOption = SlashCommandTools.string('sensitivity', 'Your current sensitivity'):setRequired(true)
local VSensMultiplierMultiplierOption = SlashCommandTools.string('multiplier', 'The desired vertical sensitivity multiplier'):setRequired(true)
local VSensMultiplierMYawOption = SlashCommandTools.string('m_yaw', 'Your current m_yaw')
VSensMultiplierSubCommand:addOption(VSensMultiplierSensitivityOption)
VSensMultiplierSubCommand:addOption(VSensMultiplierMultiplierOption)
VSensMultiplierSubCommand:addOption(VSensMultiplierMYawOption)

SourceMainCommand:addOption(VSensMultiplierSubCommand)

SourceSubCommandHandler:AddSubCommand(VSensMultiplierSubCommand.name, function(Interaction, Command, Args)
	local Sensitivity = tonumber(Args.sensitivity)
	local VSensMultiplier = tonumber(Args.multiplier)
	local MYaw = Args.m_yaw and tonumber(Args.m_yaw) or SOURCE_DEFAULT_M_YAW

	if type(Sensitivity) ~= 'number' then
		error('"sensitivity" argument was not a valid number')
	end

	if type(VSensMultiplier) ~= 'number' then
		error('"multiplier" argument was not a valid number')
	end

	if type(MYaw) ~= 'number' then
		error('"m_yaw" argument was not a valid number')
	end

	local OldVSensMultiplier = SOURCE_DEFAULT_M_YAW / MYaw
	local SensitivityWithDefaultMYaw = Sensitivity / OldVSensMultiplier
	local NewSensitivity = SensitivityWithDefaultMYaw * VSensMultiplier
	local NewMYaw = SOURCE_DEFAULT_M_YAW / VSensMultiplier

	local Message = 'OldVSensMultiplier = '..OldVSensMultiplier..'\n'..
					'SensitivityWithDefaultMYaw = '..SensitivityWithDefaultMYaw..'\n'..
					'```'..'\n'..
					'sensitivity '..NewSensitivity..'; \n'..
					'm_yaw '..NewMYaw..'\n'..
					'```'

	Interaction:reply(Message)
end)

return {
	Command = SourceMainCommand,
	Callback = SourceSubCommandHandler:GetMainCommandCallback()
}	