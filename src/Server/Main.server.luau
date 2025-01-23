-- Script: MainScript
local Hangman = require(script.Parent:WaitForChild("gameLoopUpd"))

-- Define players and word database
local players = game.Players:GetChildren()
if #players == 0 then
	game.Players.PlayerAdded:Wait()
	players = game.Players:GetChildren()
end
print("Players:", players)

-- Create remote events
local function createRemoteEvent(name)
	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = game.ReplicatedStorage
	return event
end

createRemoteEvent("ButtonPressEvent")
createRemoteEvent("ThemeVoteEvent")
createRemoteEvent("WordLengthEvent")
createRemoteEvent("CorrectGuessEvent")
createRemoteEvent("GameOverEvent")
createRemoteEvent("TestEvent")

-- Create a new multiplayer Hangman game
local game = Hangman.new()

task.spawn(function()
	while true do
		game:update()
		task.wait(0.5)
	end
end)
