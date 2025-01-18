-- Get Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Get theme
local themes = script.Parent.Themes:GetChildren()
local randomTheme: { string } = require(themes[math.random(1, #themes)])
local word: string = randomTheme[math.random(1, #randomTheme)]
local wordLength = string.len(word)

local WordSend = Instance.new("RemoteEvent")
WordSend.Name = "WordSend"
WordSend.Parent = ReplicatedStorage

local gameStates = {
	INTERMISSION = "Intermission",
	PLAYING = "Playing",
	END = "End",
}

local Game = {}

function Game.new()
	local self = { state = gameStates.INTERMISSION }

	return self
end

function Game:transitionTo(game, newState)
	self.state = newState
end

function Game:handleIntermission()
	self.state = gameStates.INTERMISSION
	print("Game reset! State: " .. self.state)
	task.wait(20)
end

function Game:handlePlaying()
	self.state = gameStates.PLAYING
	print("Game started! State: " .. self.state)
end

function Game:handleEnded()
	self.transitionTo(gameStates.END)
	print("Game ended! State: " .. self.state)
end

function game:update()
	local stateHandlers = {
		[gameStates.INTERMISSION] = self.reset,
		[gameStates.PLAYING] = self.start,
		[gameStates.END] = self.endGame,
	}
end

-- Utility functions
local function randomPlayer()
	local players = Players:GetPlayers()
	return players[math.random(1, #players)]
end

local function sendWord(player)
	WordSend:FireClient(player, word, wordLength)
end

return Game
