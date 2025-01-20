-- Script: MainScript
local Hangman = require(script.Parent:WaitForChild("gameLoop")) -- Adjust the path to your ModuleScript

-- Define players and word database
local players = game.Players:GetChildren()
if #players == 0 then
	game.Players.PlayerAdded:Wait()
	players = game.Players:GetChildren()
end
print("Players:", players)

-- Create remote events
local ButtonPressEvent = Instance.new("RemoteEvent")
ButtonPressEvent.Name = "ButtonPressEvent"
ButtonPressEvent.Parent = game.ReplicatedStorage

local ThemeVoteEvent = Instance.new("RemoteEvent")
ThemeVoteEvent.Name = "ThemeVoteEvent"
ThemeVoteEvent.Parent = game.ReplicatedStorage

local WordLengthEvent = Instance.new("RemoteEvent")
WordLengthEvent.Name = "WordLengthEvent"
WordLengthEvent.Parent = game.ReplicatedStorage

local CorrectGuessEvent = Instance.new("RemoteEvent")
CorrectGuessEvent.Name = "CorrectGuessEvent"
CorrectGuessEvent.Parent = game.ReplicatedStorage

-- Define a random theme and word
local themes = script.Parent.Themes:GetChildren()
local randomTheme: { string } = require(themes[math.random(1, #themes)])
local word: string = randomTheme[math.random(1, #randomTheme)]

-- Create a new multiplayer Hangman game
local game = Hangman.new(players, word)

Hangman.update(game)
