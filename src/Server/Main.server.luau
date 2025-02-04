--!strict
local RunService = game:GetService("RunService")
local Hangman = require(script.Parent:WaitForChild("State"))

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
createRemoteEvent("CurrentPlayerEvent")

-- Create game instance with states
local game = Hangman.new()
game:setState(Hangman.gameStates.INTERMISSION)

RunService.Heartbeat:Connect(function()
	if game then
		game:update()
	end
end)
