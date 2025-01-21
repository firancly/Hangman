local Hangman = {}
Hangman.__index = Hangman

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

-- Utility functions (kept outside the class since they don't need self)
local function teleportPlayers(players, state)
	local chairs = workspace.Chairs:GetChildren()
	print(players)

	if state == "GameStart" then
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
	else
		for _, player in players do
			if player.Character then
				local humanoid = player.Character:FindFirstChild("Humanoid")
				-- Teleport players outside of the match area
				if humanoid then
					humanoid.WalkSpeed = 16 -- Reset to default walk speed
					humanoid.JumpHeight = 7.2 -- Reset to default jump height
				end
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

	setmetatable(self, Hangman)

	-- Set up button press event handler
	self.Events.ButtonPressEvent.OnServerEvent:Connect(function(player, action, letter)
		if action == "Button Input" then
			if self.state == gameStates.PLAYER_TURN and player == self.players[self.currentPlayerIndex] then
				if self.hasGuessed then
					warn("You have already guessed!")
					return
				end

				print(player.Name .. " pressed: " .. letter)
				local success = self:guessLetter(player, letter)
				if success then
					print("Correct guess!")
				else
					warn("Incorrect guess!")
				end
				self.hasGuessed = true
				self:nextPlayer()
			else
				warn("It's not your turn, " .. player.Name .. "!")
			end
		end
	end)

	return self
end

function Hangman:update()
	local stateHandlers = {
		[gameStates.INTERMISSION] = self.handleIntermission,
		[gameStates.ROUND_START] = self.startRound,
		[gameStates.PLAYER_TURN] = self.handlePlayerTurn,
		[gameStates.ROUND_END] = self.endRound,
	}

	local handler = stateHandlers[self.state]
	if handler then
		game.TestService:Error(self.state)
		handler(self)
	else
		game.TestService:Error("No handler for state:", self.state)
	end
end

function Hangman:handleIntermission()
	print("Intermission: Players, vote for a theme!")
	task.wait(CONFIG.INTERMISSION_TIME)
	print("Intermission over!")
	self.state = gameStates.ROUND_START
end

function Hangman:startRound()
	warn(self.word)
	self.Events.WordLengthEvent:FireAllClients(self.word:len())
	teleportPlayers(self.players, self.state)
	self.state = gameStates.PLAYER_TURN
	self.remainingAttempts = CONFIG.MAX_ATTEMPTS
	self.guessedLetters = {}
	self.hasGuessed = false
end

function Hangman:handlePlayerTurn()
	local currentPlayer = self.players[self.currentPlayerIndex]
	if not currentPlayer then
		warn("No current player!")
		return
	end

	local startTime = os.time()
	local endTime = startTime + CONFIG.PLAYER_TURN_TIME

	-- Only continue player turn if we're still in PLAYER_TURN state
	while os.time() < endTime and self.state == gameStates.PLAYER_TURN do
		task.wait(1)
	end

	-- Only move to next player if still in PLAYER_TURN state
	if self.state == gameStates.PLAYER_TURN then
		warn("Next Player!")
		self:nextPlayer()
	end
end

function Hangman:guessLetter(player, letter)
	if self.state ~= gameStates.PLAYER_TURN or player ~= self.players[self.currentPlayerIndex] then
		return false
	end

	if table.find(self.guessedLetters, letter) then
		warn("Letter already guessed:", letter)
		return false
	end

	table.insert(self.guessedLetters, letter)
	self.Events.ButtonPressEvent:FireAllClients("Button Disable", letter)

	local indexes = findAllIndexes(self.word, letter)
	if #indexes > 0 then
		for _, index in indexes do
			self.Events.CorrectGuessEvent:FireAllClients(player, index, letter)
		end

		-- Check if the round is over immediately after a correct guess
		if self:checkWinCondition() then
			self.state = gameStates.ROUND_END
			print("Round over! " .. player.Name .. " wins!")
			return true
		end
		return true
	else
		self.remainingAttempts = self.remainingAttempts - 1
		if self.remainingAttempts <= 0 then
			self.state = gameStates.ROUND_END
			print("Round over! " .. player.Name .. " loses!")
			return false
		end
		return false
	end
end

function Hangman:checkWinCondition()
	local allLettersGuessed = true
	for letter in string.gmatch(self.word, "%a") do
		if not table.find(self.guessedLetters, letter) then
			allLettersGuessed = false
			break
		end
	end
	return allLettersGuessed
end

function Hangman:checkRoundOver()
	local allLettersGuessed = true
	for letter in string.gmatch(self.word, "%a") do
		if not table.find(self.guessedLetters, letter) then
			allLettersGuessed = false
			break
		end
	end

	if allLettersGuessed then
		self.state = gameStates.ROUND_END
		return true, "Round over! " .. self.players[self.currentPlayerIndex].Name .. " wins!"
	end

	if self.remainingAttempts <= 0 then
		self.state = gameStates.ROUND_END
		return true, "Round over! " .. self.players[self.currentPlayerIndex].Name .. " loses!"
	end

	return false
end

function Hangman:nextPlayer()
	self.currentPlayerIndex = self.currentPlayerIndex + 1
	if self.currentPlayerIndex > #self.players then
		self.currentPlayerIndex = 1
	end
	self.hasGuessed = false
	print("Next player is:", self.players[self.currentPlayerIndex].Name)
end

function Hangman:endRound()
	-- for _, player in self.players do
	-- 	if player.Character then
	-- 		local humanoid = player.Character:FindFirstChild("Humanoid")
	-- 		if humanoid then
	-- 			humanoid.WalkSpeed = 16 -- Reset to default walk speed
	-- 			humanoid.JumpHeight = 7.2 -- Reset to default jump height
	-- 		end
	-- 	end
	-- end
	teleportPlayers(self.players, "RoundEnd")

	-- Add delay for players to see results
	task.wait(3)

	-- Get new word for next round
	-- You'll need to implement or connect to your word selection system here
	-- For example:
	-- self.word = WordService:GetNextWord() -- Replace with your word selection system

	-- Reset game state for next round
	self.round = self.round + 1
	self.currentPlayerIndex = 1
	self.guessedLetters = {}
	self.remainingAttempts = CONFIG.MAX_ATTEMPTS
	self.hasGuessed = false

	-- Reset UI elements
	self.Events.ButtonPressEvent:FireAllClients("Reset Buttons")

	-- Clear the previous word display
	self.Events.WordLengthEvent:FireAllClients(0) -- Clear the current word display

	-- Transition to intermission state
	self.state = gameStates.INTERMISSION
end

return Hangman
