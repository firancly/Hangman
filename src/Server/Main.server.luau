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

-- Define a random theme and word
local themes = script.Parent.Themes:GetChildren()
local randomTheme: { string } = require(themes[math.random(1, #themes)])
local word: string = randomTheme[math.random(1, #randomTheme)]

-- Create a new multiplayer Hangman game
local game = Hangman.new(players, word)

task.spawn(function()
	while true do
		game:update()
		task.wait(0.5)
	end
end)
