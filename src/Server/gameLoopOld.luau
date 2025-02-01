local Hangman = {}

-- Configuration
local CONFIG = {
	MAX_ATTEMPTS = 6,
	INTERMISSION_TIME = 5,
	PLAYER_TURN_TIME = 20,
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
		hasGuessed = false,
		round = 1,
	}

	self.Events = {
		ButtonPressEvent = game.ReplicatedStorage:WaitForChild("ButtonPressEvent"),
		WordLengthEvent = game.ReplicatedStorage:WaitForChild("WordLengthEvent"),
		CorrectGuessEvent = game.ReplicatedStorage:WaitForChild("CorrectGuessEvent"),
	}

	self.Events.ButtonPressEvent.OnServerEvent:Connect(function(player, action, letter)
		if action == "Button Input" then
			if self.state == gameStates.PLAYER_TURN and player == self.players[self.currentPlayerIndex] then
				if self.hasGuessed then
					warn("You have already guessed!")
					return
				end

				print(player.Name .. " pressed: " .. letter)
				local success = Hangman.guessLetter(self, player, letter)
				if success then
					print("Correct guess!")
				else
					warn("Incorrect guess!")
				end
				self.hasGuessed = true
				Hangman.nextPlayer(self)
			else
				warn("It's not your turn, " .. player.Name .. "!")
			end
		end
	end)

	return self
end

-- Utility functions
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

local function findAllIndexes(word, letter)
	local indexes = {}
	local startIndex = 1

	while true do
		local index = string.find(word, letter, startIndex)
		if not index then
			break
		end
		table.insert(indexes, index)
		startIndex = index + 1
	end

	return indexes
end

function Hangman.endRoundIfOver(self)
	local isRoundOver, message = Hangman.checkRoundOver(self)
	if isRoundOver then
		print(message)
		self.state = gameStates.ROUND_END
	end

	return isRoundOver
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
		game.TestService:Error(self.state)
		local handler = stateHandlers[self.state]
		if handler then
			handler(self)
		else
			error("Invalid game state:", self.state)
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
	warn(self.word)
	self.Events.WordLengthEvent:FireAllClients(self.word:len())
	teleportPlayers(self.players)
	self.state = gameStates.PLAYER_TURN
	self.remainingAttempts = CONFIG.MAX_ATTEMPTS
	self.guessedLetters = {}
	self.hasGuessed = false
end

function Hangman.handlePlayerTurn(self)
	local currentPlayer = self.players[self.currentPlayerIndex]
	if not currentPlayer then
		warn("No current player!")
		return
	end

	local startTime = os.time()
	local endTime = startTime + CONFIG.PLAYER_TURN_TIME

	while os.time() < endTime do
		Hangman.endRoundIfOver(self)
		task.wait(1)
	end

	warn("Next Player!")
	Hangman.nextPlayer(self)
end

function Hangman.guessLetter(self, player, letter)
	if self.state ~= gameStates.PLAYER_TURN or player ~= self.players[self.currentPlayerIndex] then
		return false
	end

	-- Check if letter was already guessed
	if table.find(self.guessedLetters, letter) then
		warn("Letter already guessed:", letter)
		return false
	end

	-- Add the letter to the guessed letters list
	table.insert(self.guessedLetters, letter)
	self.Events.ButtonPressEvent:FireAllClients("Button Disable", letter)

	-- Check if the letter is in the word
	local indexes = findAllIndexes(self.word, letter)
	if #indexes > 0 then
		for _, index in indexes do
			self.Events.CorrectGuessEvent:FireAllClients(player, index, letter)
		end

		Hangman.endRoundIfOver(self)
		return true
	else
		self.remainingAttempts = self.remainingAttempts - 1

		Hangman.endRoundIfOver(self)
		return false
	end
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
	self.hasGuessed = false
	print("Next player is:", self.players[self.currentPlayerIndex].Name)
end

return Hangman
