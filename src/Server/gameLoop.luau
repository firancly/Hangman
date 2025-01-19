local Hangman = {}

-- Game states
local gameStates = {
	INTERMISSION = "Intermission",
	ROUND_START = "GameStart",
	PLAYER_TURN = "PlayerTurn",
	ROUND_END = "RoundEnd",
	GAME_OVER = "GameOver",
}

local CONFIG = {
	waitTime = 5,
}

-- Constructor
function Hangman.new(players, word)
	local self = {}

	self.state = gameStates.INTERMISSION
	self.players = players
	self.currentPlayerIndex = 1
	self.word = word
	self.guessedLetters = {}
	self.remainingAttempts = 6
	self.round = 1

	return self
end

local function teleportPlayers(players)
	local chairs = workspace.Chairs:GetChildren()
	print(players)

	for i, player in players do
		local chair = chairs[i]
		if chair and player.Character then
			local humanoidRootPart = player.Character:FindFirstChild("HumanoidRootPart")
			local humanoid = player.Character:FindFirstChild("Humanoid")
			if humanoidRootPart then
				humanoid.WalkSpeed = 0
				humanoid.JumpHeight = 0
				humanoidRootPart.CFrame = chair:GetPivot()
			end
		else
			if not chair then
				warn("Not enough chairs for " .. player.Name)
			end
			if not player.Character then
				warn(player.Name .. " does not have a character.")
			end
		end
	end
end

-- Define methods that take the instance as first parameter
function Hangman.update(self)
	local stateHandlers = {
		[gameStates.INTERMISSION] = Hangman.Intermission,
		[gameStates.ROUND_START] = Hangman.startRound,
		[gameStates.PLAYER_TURN] = Hangman.handlePlayerTurn,
		[gameStates.ROUND_END] = Hangman.endRound,
	}

	while self.state ~= gameStates.ROUND_END do
		print(self.state)
		local handler = stateHandlers[self.state]
		if handler then
			handler(self)
		else
			warn("Invalid game state:", self.state)
		end
		task.wait(1) -- Configurable delay
	end
end

function Hangman.Intermission(self)
	print("Intermission: Players, vote for a theme!")
	task.wait(CONFIG.waitTime)
	print("Intermission over!")
	self.state = gameStates.ROUND_START
end

function Hangman.startRound(self)
	print("Start Game")
	teleportPlayers(self.players)
	self.state = gameStates.PLAYER_TURN
end

function Hangman.handlePlayerTurn(self)
	local currentPlayer = self.players[self.currentPlayerIndex]

	-- Receive a fireevent from the client to get the input letter from the player
	-- Hangman.guessLetter(self, currentPlayer, letter)
	local ButtonPressEvent = game.ReplicatedStorage.ButtonPressEvent
	local letter = ButtonPressEvent.OnServerEvent:Connect(function(player, letter)
		print(player, letter)
		Hangman.guessLetter(self, player, letter)
	end)

	local isRoundOver, message = Hangman.checkRoundOver(self)
	if isRoundOver then
		print(message)
		self.state = gameStates.ROUND_END
	else
		Hangman.nextPlayer(self)
	end
end

function Hangman.guessLetter(self, player, letter)
	if self.state ~= gameStates.PLAYER_TURN or player ~= self.players[self.currentPlayerIndex] then
		return false
	end

	table.insert(self.guessedLetters, letter)
	if not string.find(self.word, letter) then
		self.remainingAttempts = self.remainingAttempts - 1
	end

	return true
end

function Hangman.checkRoundOver(self)
	local allLettersGuessed = true
	for letter in string.gmatch(self.word, "%a") do
		if not table.find(self.guessedLetters, letter) then
			allLettersGuessed = false
			break
		end
	end

	if allLettersGuessed then
		self.state = gameStates.ROUND_END
		return true, "Round over! " .. self.players[self.currentPlayerIndex].name .. " wins!"
	end

	if self.remainingAttempts <= 0 then
		self.state = gameStates.ROUND_END
		return true, "Round over! " .. self.players[self.currentPlayerIndex].name .. " loses!"
	end

	return false
end

function Hangman.nextPlayer(self)
	self.currentPlayerIndex = self.currentPlayerIndex + 1
	if self.currentPlayerIndex > #self.players then
		self.currentPlayerIndex = 1
	end
end

return Hangman
