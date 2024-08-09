local RELATIVE_PATH_TO_COMMANDS = '../' --this is because the require function will call to a path relative to this current file :D
local IGNORE_STARTING_FILE_NAME = '_'

local CommandCollector = {}
CommandCollector.__index = CommandCollector

function CommandCollector.new(Prefix)
	local self = setmetatable({}, CommandCollector)

	self.Prefix = Prefix
	self.Collected = false
	self.Collection = {}

	return self
end

function CommandCollector:Get(CommandName)
	for CommandIndex, CommandData in next, self.Collection do
		if CommandName == CommandData.Command.name then
			return CommandData
		end
	end
end

function CommandCollector:Collect()
	if self.Collected then
		print('Command collector for', self.Prefix, 'commands was already collected')
		return
	end

	local CommandsContainerPath = self.Prefix..'Commands/'

	for File in io.popen('dir "./src/'..CommandsContainerPath..'" /b'):lines() do
		if File:sub(1, 1) ~= IGNORE_STARTING_FILE_NAME then
			local Success, Return = pcall(require, RELATIVE_PATH_TO_COMMANDS..CommandsContainerPath..File)
			if Success then
				if not Return.Command or not Return.Callback then
					print('Malformed command data in', CommandsContainerPath..File, 'Reason: returned command data table is missing a Command or Callback field')
					return
				end
				print('Loaded', CommandsContainerPath..File)
				table.insert(self.Collection, {Command = Return.Command, Callback = Return.Callback})
			else
				print('Error loading', CommandsContainerPath..File, 'Error:', Return)
			end
		end
	end

	print('Loaded a total of '..#self.Collection..' '..self.Prefix..' command'..(#self.Collection ~= 1 and 's' or ''))

	self.Collected = true
	return self
end

function CommandCollector:Publish(Client)
	if not Client.createGlobalApplicationCommand then
		print('Client does not have the method \'createGlobalApplicationCommand\'')
		return
	end

	for CommandIndex, CommandData in next, self.Collection do
		local Success, Return = pcall(Client.createGlobalApplicationCommand, Client, CommandData.Command)
		if Success then
			print('Published command', CommandData.Command.name)
		else
			print('Failed to publish command', CommandData.Command.name, 'Error:', Return)
		end
	end

	return self
end

return CommandCollector