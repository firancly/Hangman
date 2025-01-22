local Hangman = {}
Hangman.__index = Hangman

-- Configuration
local CONFIG = {
	MAX_ATTEMPTS = 2,
	INTERMISSION_TIME = 5,
	PLAYER_TURN_TIME = 20,
	MIN_PLAYERS = 1,
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

	if state == "GameStart" then -- Teleport players to chairs
		local occupiedChairs = {}

		-- Shuffle the chairs and assign them to players
		local shuffleChairs = {}
		for _, chair in chairs do
			table.insert(shuffleChairs, chair)
		end
		for i = #shuffleChairs, 2, -1 do
			local j = math.random(1, i)
			shuffleChairs[i], shuffleChairs[j] = shuffleChairs[j], shuffleChairs[i]
		end

		for i, player in players do
			local chair = shuffleChairs[i]
			if chair and not occupiedChairs[chair] and player.Character then
				local humanoidRootPart = player.Character:FindFirstChild("HumanoidRootPart")
				local humanoid = player.Character:FindFirstChild("Humanoid")
				if humanoidRootPart then
					-- Disable player movement
					humanoid.WalkSpeed = 0
					humanoid.JumpHeight = 0

					-- Teleport the player to the chair
					if chair and chair.PrimaryPart then
						humanoidRootPart.CFrame = chair.PrimaryPart.CFrame
							* CFrame.new(0, 1, 0) -- Offset the player above the chair
							* CFrame.Angles(0, math.rad(90), 0) -- Rotate the player to face a specific direction
					else
						warn("Invalid chair or missing PrimaryPart.")
					end

					-- Extra check if the player is wrongly sitting
					task.wait(1)

					humanoidRootPart.CFrame = chair.PrimaryPart.CFrame
						* CFrame.new(0, 1, 0)
						* CFrame.Angles(0, math.rad(90), 0)
					humanoid.Sit = true
					occupiedChairs[chair] = true
				end
			else
				if not chair then
					warn("Not enough chairs for " .. player.Name)
				elseif occupiedChairs[chair] then
					warn("Chair is already occupied.")
				end
				if not player.Character then
					warn(player.Name .. " does not have a character.")
				end
			end
		end
	else -- Teleport players to the lobby
		for _, player in players do
			if player.Character then
				local humanoid = player.Character:FindFirstChild("Humanoid")
				local humanoidRootPart = player.Character:FindFirstChild("HumanoidRootPart")
				local lobby = workspace.IntermissionTP

				-- Random position around the lobby
				local positionRange = 10
				local rotationRange = 180
				local randomRotation = CFrame.Angles(0, math.rad(math.random(-rotationRange, rotationRange)), 0)
				local randomPostion = Vector3.new(
					math.random(-positionRange, positionRange),
					0,
					math.random(-positionRange, positionRange)
				)

				-- Teleport the player
				if humanoid then
					humanoid.Sit = false
					humanoidRootPart.CFrame = lobby.CFrame * CFrame.new(randomPostion) * randomRotation
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

local function RandomWord()
	local themes = script.Parent.Themes:GetChildren()
	local randomTheme: { string } = require(themes[math.random(1, #themes)])
	local word = randomTheme[math.random(1, #randomTheme)]

	return string.upper(word)
end

-- Constructor
function Hangman.new(players)
	local self = {
		state = gameStates.INTERMISSION,
		players = players,
		currentPlayerIndex = 1,
		word = RandomWord(),
		guessedLetters = {},
		remainingAttempts = CONFIG.MAX_ATTEMPTS,
		hasGuessed = false,
		round = 1,
		lastGuessTime = 0,
	}

	self.Events = {
		ButtonPressEvent = game.ReplicatedStorage:WaitForChild("ButtonPressEvent"),
		WordLengthEvent = game.ReplicatedStorage:WaitForChild("WordLengthEvent"),
		CorrectGuessEvent = game.ReplicatedStorage:WaitForChild("CorrectGuessEvent"),
	}

	game.Players.PlayerAdded:Connect(function(player)
		table.insert(self.players, player)
		print(player.Name .. " joined! Players: " .. #self.players)
	end)

	game.Players.PlayerRemoving:Connect(function(player)
		for i, activePlayer in self.players do
			if activePlayer == player then
				table.remove(self.players, i)
				print(player.Name .. " left! Players: " .. #self.players)
				break
			end
		end
	end)

	-- Set up button press event handler
	self.Events.ButtonPressEvent.OnServerEvent:Connect(function(player, action, letter)
		if action == "Button Input" then
			local currentTime = os.clock()

			if self.hasGuessed then
				warn("You have already guessed!")
				return
			end

			if currentTime - self.lastGuessTime < 0.2 then -- 500ms debounce
				return
			end

			self.lastGuessTime = currentTime

			if self.state == gameStates.PLAYER_TURN and player == self.players[self.currentPlayerIndex] then
				if self.hasGuessed then
					warn("You have already guessed!")
					return
				end

				self.hasGuessed = true

				print(player.Name .. " pressed: " .. letter)
				local success = self:guessLetter(player, letter)
				if success then
					print("Correct guess!")
				else
					warn("Incorrect guess!")
				end

				self:nextPlayer()
			else
				warn("It's not your turn, " .. player.Name .. "!")
			end
		end
	end)

	setmetatable(self, Hangman)
	return self
end

function Hangman:update()
	local stateHandlers = {
		[gameStates.INTERMISSION] = self.handleIntermission,
		[gameStates.ROUND_START] = self.startRound,
		[gameStates.PLAYER_TURN] = self.handlePlayerTurn,
		[gameStates.ROUND_END] = self.endRound,
	}

	if #self.players < CONFIG.MIN_PLAYERS then
		print("Not enough players to start. Returning to intermission.")
		self.state = gameStates.INTERMISSION
		return
	end

	local handler = stateHandlers[self.state]
	if handler then
		game.TestService:Error(self.state)
		handler(self)
	else
		game.TestService:Error("No handler for state:", self.state)
	end
end

--[[
	Handles the intermission state, where players vote for a theme.
	Once the intermission time is up, the game transitions to the ROUND_START state.
]]
function Hangman:handleIntermission()
	while #self.players < CONFIG.MIN_PLAYERS do
		print("Waiting for more players... (" .. #self.players .. "/" .. CONFIG.MIN_PLAYERS .. ")")
		task.wait(1) -- Check player count every second
	end

	print("Intermission: Players, vote for a theme!")

	self.hasGuessed = false
	task.wait(CONFIG.INTERMISSION_TIME)

	print("Intermission over!")
	self.state = gameStates.ROUND_START
end

--[[
	Handles the ROUND_START state, where the game transitions to the PLAYER_TURN state.
	Players are teleported to their chairs and the word length is displayed.
]]
function Hangman:startRound()
	warn(self.word)
	self.Events.WordLengthEvent:FireAllClients(self.word:len())

	teleportPlayers(self.players, self.state)

	self.state = gameStates.PLAYER_TURN
	self.remainingAttempts = CONFIG.MAX_ATTEMPTS
	self.guessedLetters = {}
	self.hasGuessed = false
end

--[[
	Handles the PLAYER_TURN state, where the current player has a limited time to guess a letter.
	If the player does not guess within the time limit, the game transitions to the next player.
]]
function Hangman:handlePlayerTurn()
	local currentPlayer = self.players[self.currentPlayerIndex]
	if not currentPlayer then
		warn("No current player!")
		return
	end

	-- Check if

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
	if self.state == gameStates.PLAYER_TURN or player == self.players[self.currentPlayerIndex] then
		if not self.guessedLetters then
			warn("guessedLetters is nil! Reinitializing...")
			self.guessedLetters = {}
		end

		warn("Current guessedLetters table:", table.concat(self.guessedLetters, ", "))

		if table.find(self.guessedLetters, letter) then
			warn("Letter already guessed:", letter)
			return false
		end

		warn("Before insert:", #self.guessedLetters)
		table.insert(self.guessedLetters, letter)
		warn("After insert:", #self.guessedLetters)
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
	-- Add delay for players to see results
	task.wait(3)
	teleportPlayers(self.players, "RoundEnd")

	-- Get new word for next round
	self.word = RandomWord()

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
