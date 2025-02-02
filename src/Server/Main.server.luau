-- Script: MainScript
local Hangman = require(script.Parent:WaitForChild("gameLoopUpd"))

-- Create remote events
local function createRemoteEvent(name)
	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = game.ReplicatedStorage
	return event
end

createRemoteEvent("ButtonPressEvent")
createRemoteEvent("WordLengthEvent")
createRemoteEvent("CorrectGuessEvent")
createRemoteEvent("GameOverEvent")
createRemoteEvent("TestEvent")
createRemoteEvent("TimerEvent")
createRemoteEvent("PlayerAttemptsEvent")

-- Create a new multiplayer Hangman game
local game = Hangman.new()

task.spawn(function()
	while true do
		game:update()
		task.wait(0.5)
	end
end)
