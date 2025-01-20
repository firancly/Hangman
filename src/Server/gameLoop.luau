local Hangman = {}

-- Configuration
local CONFIG = {
	MAX_ATTEMPTS = 6,
	INTERMISSION_TIME = 5,
	MIN_PLAYERS = 2,
	MAX_PLAYERS = 8,
}

-- Game states
local gameStates = {
	INTERMISSION = "Intermission",
	ROUND_START = "GameStart",
	PLAYER_TURN = "PlayerTurn",
	ROUND_END = "RoundEnd",
	GAME_OVER = "GameOver",
}

-- Constructor
function Hangman.new(players, word)
	local self = {
		state = gameStates.INTERMISSION,
		players = players,
		currentPlayerIndex = 1,
		word = string.upper(word),
		guessedLetters = {},
		remainingAttempts = CONFIG.MAX_ATTEMPTS,
		round = 1,
	}

	self.Events = {
		ButtonPressEvent = game.ReplicatedStorage:WaitForChild("ButtonPressEvent"),
		WordLengthEvent = game.ReplicatedStorage:WaitForChild("WordLengthEvent"),
		CorrectGuessEvent = game.ReplicatedStorage:WaitForChild("CorrectGuessEvent"),
	}

	self.Events.ButtonPressEvent.OnServerEvent:Connect(function(player, letter)
		-- Only process input if it's the player's turn
		if self.state == gameStates.PLAYER_TURN and player == self.players[self.currentPlayerIndex] then
			print(player.Name .. " pressed: " .. letter)
			Hangman.guessLetter(self, player, letter)
		else
			warn("It's not your turn, " .. player.Name .. "!")
		end
	end)

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
		warn(self.state)
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
	task.wait(CONFIG.INTERMISSION_TIME)
	print("Intermission over!")
	self.state = gameStates.ROUND_START
end

function Hangman.startRound(self)
	print("Start Game")
	warn(self.word)
	self.Events.WordLengthEvent:FireAllClients(self.word:len())
	teleportPlayers(self.players)
	self.state = gameStates.PLAYER_TURN
end

function Hangman.handlePlayerTurn(self)
	local currentPlayer = self.players[self.currentPlayerIndex]

	task.wait(20) -- Time given for players to choose a letter
	local isRoundOver, message = Hangman.checkRoundOver(self)
	if isRoundOver then
		print(message)
		self.state = gameStates.ROUND_END
	else
		warn("Next Player!")
		Hangman.nextPlayer(self)
	end
end

function Hangman.guessLetter(self, player, letter)
	if self.state ~= gameStates.PLAYER_TURN or player ~= self.players[self.currentPlayerIndex] then
		return false
	end

	if table.find(self.guessedLetters, letter) then
		warn("Letter already guessed:", letter)
		return false
	else
		table.insert(self.guessedLetters, letter)
	end

	local index = string.find(self.word, letter)
	if index then
		self.Events.CorrectGuessEvent:FireClient(player, index, letter)
	else
		self.remainingAttempts = self.remainingAttempts - 1
	end

	print("Guessed letters:", table.concat(self.guessedLetters, ", "))
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
