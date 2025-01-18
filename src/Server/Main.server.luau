-- Script: MainScript
local Hangman = require(script.Parent:WaitForChild("gameLoop")) -- Adjust the path to your ModuleScript

-- Define players and word database
local players = game.Players:GetChildren()
if #players == 0 then
	game.Players.PlayerAdded:Wait()
	players = game.Players:GetChildren()
end
print(players)

local themes = script.Parent.Themes:GetChildren()
local randomTheme: { string } = require(themes[math.random(1, #themes)])
local word: string = randomTheme[math.random(1, #randomTheme)]
local wordLength = string.len(word) -- Use later to adjust the number of underlines

-- Create a new multiplayer Hangman game
local game = Hangman.new(players, word)

-- Start the game loop
game:start()
