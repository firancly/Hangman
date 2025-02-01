local Hangman = {}
Hangman.__index = Hangman

-- Configuration
local CONFIG = {
	MAX_ATTEMPTS = 2,
	INTERMISSION_TIME = 5,
	PLAYER_TURN_TIME = 10,
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
					humanoidRootPart.Anchored = true -- Prevent the player from falling of the chair

					-- Teleport the player to the chair
					if chair and chair.PrimaryPart then
						humanoidRootPart.CFrame = chair.PrimaryPart.CFrame
							* CFrame.new(0, 1, 0) -- Offset the player above the chair
							* CFrame.Angles(0, math.rad(90), 0) -- Rotate the player to face a specific direction

						task.wait(0.2)

						humanoidRootPart.Anchored = false
					else
						warn("Invalid chair or missing PrimaryPart.")
					end

					-- Extra check if the player is wrongly sitting
					task.wait(1)

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
	-- local word = randomTheme[math.random(1, #randomTheme)]
	local word = "Grasshopper"

	return string.upper(word)
end

local function playerRound()
	-- Send the player to the intermission area and remove the ui
end

function Hangman:handleButtonPress(player, action, letter)
	if action == "Button Input" then
		local currentTime = os.clock()

		if self.hasGuessed then
			warn("You have already guessed!")
			return
		end

		if currentTime - self.lastGuessTime < 0.2 then
			return
		end

		self.lastGuessTime = currentTime

		if self.state == gameStates.PLAYER_TURN and player == self.players[self.currentPlayerIndex] then
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

-- Constructor
function Hangman.new()
	local self = {
		state = gameStates.INTERMISSION,
		players = {},
		playerAttempts = {},
		currentPlayerIndex = 1,
		word = RandomWord(),
		guessedLetters = {},
		remainingAttempts = CONFIG.MAX_ATTEMPTS,
		hasGuessed = false,
		round = 1,
		lastGuessTime = 0,
		timerConnections = {},
	}

	self.Events = {
		ButtonPressEvent = game.ReplicatedStorage:WaitForChild("ButtonPressEvent"),
		WordLengthEvent = game.ReplicatedStorage:WaitForChild("WordLengthEvent"),
		CorrectGuessEvent = game.ReplicatedStorage:WaitForChild("CorrectGuessEvent"),
		GameOverEvent = game.ReplicatedStorage:WaitForChild("GameOverEvent"),
		TestEvent = game.ReplicatedStorage:WaitForChild("TestEvent"),
		TimerEvent = game.ReplicatedStorage:WaitForChild("TimerEvent"),
	}

	game.Players.PlayerRemoving:Connect(function(player)
		for i = #self.players, 1, -1 do
			if self.players[i] == player then
				table.remove(self.players, i)
				print(player.Name .. " left! Players: " .. #self.players)
				break
			end
		end
	end)

	self.Events.ButtonPressEvent.OnServerEvent:Connect(function(player, action, letter)
		self:handleButtonPress(player, action, letter)
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

	local handler = stateHandlers[self.state]
	if handler then
		game.TestService:Error(self.state)
		handler(self)
	else
		game.TestService:Error("No handler for state:", self.state)
	end
end

function Hangman:handleIntermission()
	-- Update players table & attempts
	self:initializePlayers()

	while #self.players < CONFIG.MIN_PLAYERS do
		print("Waiting for more players... (" .. #self.players .. "/" .. CONFIG.MIN_PLAYERS .. ")")
		task.wait(1) -- Check player count every second
		self:initializePlayers()
	end

	print("Intermission: Players, vote for a theme!", self.players)

	-- Send an event to update the timer on the client
	local timeRemmaining = CONFIG.INTERMISSION_TIME + 1
	while timeRemmaining > 0 and self.state == gameStates.INTERMISSION do
		self.Events.TimerEvent:FireAllClients(timeRemmaining)
		task.wait(1)
		timeRemmaining -= 1
	end

	self.Events.TimerEvent:FireAllClients(0)

	self.state = gameStates.ROUND_START
end

function Hangman:startRound()
	-- Get new word for new round
	self.word = RandomWord()

	-- send the word to the client test
	self.Events.TestEvent:FireAllClients(self.word)

	-- TP to seats
	teleportPlayers(self.players, self.state)

	warn(self.word) -- Display text for testing purposes
	for _, player in self.players do
		-- send length to active players to update underlines
		self.Events.WordLengthEvent:FireClient(player, self.word:len())
	end

	self.state = gameStates.PLAYER_TURN
	self.guessedLetters = {}
	self.hasGuessed = false
end

function Hangman:checkAttempts(currentPlayer)
	if self.playerAttempts[currentPlayer.UserId] <= 0 then
		for i = #self.players, 1, -1 do
			if self.players[i] == currentPlayer then
				-- Remove the player from the game
				table.remove(self.players, i)
				teleportPlayers({ currentPlayer }, "RoundEnd")

				-- Update UI
				self.Events.WordLengthEvent:FireClient(currentPlayer, 0)
				self.Events.GameOverEvent:FireClient(currentPlayer, "Lose")

				-- Humiliate the player
				print("Kicked the", currentPlayer, "out of the game! Skill issue noob!")
				print("Players:", #self.players)
				break
			end
		end
	end
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
		-- local timeLeft = endTime - os.time()
		-- self.Events.TimerEvent:FireAllClients(timeLeft)
		task.wait(1)
	end

	-- Only move to next player if still in PLAYER_TURN state
	if self.state == gameStates.PLAYER_TURN then
		if not self.hasGuessed then
			warn("Player did not guess in time!")

			-- Have a global attempts manager
			self.playerAttempts[currentPlayer.UserId] -= 1
			print("Attempts:", self.playerAttempts[currentPlayer.UserId], "for player", currentPlayer)
			-- self:checkAttempts(currentPlayer) -----------------------------------------------------------------------------------------------------------DISABLED FOR TESTING
		end
		-- self.Events.TimerEvent:FireAllClients(0)
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

		print("Current guessedLetters table:", table.concat(self.guessedLetters, ", "))

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
				-- Send player.name to the client to update the ui
				self.Events.GameOverEvent:FireAllClients("Win")
				print("fired all clients")
				return true
			end
			return true
		else
			if not self.playerAttempts[player.UserId] then
				self.playerAttempts[player.UserId] = CONFIG.MAX_ATTEMPTS
			end

			self.playerAttempts[player.UserId] -= 1

			self:checkAttempts(player)

			if #self.players > 0 then
				self.state = gameStates.PLAYER_TURN
				self:nextPlayer() -- Move to next player
			else
				self.state = gameStates.ROUND_END
				print("Round over - no players remaining!")
			end

			return false
		end
	end
end

function Hangman:nextPlayer()
	if not self.players or #self.players == 0 then
		warn("No players to switch to!")
		self.state = gameStates.ROUND_END
		return
	end

	warn("CurrentPlayer Index", self.currentPlayerIndex, "Table:", self.players)
	self.currentPlayerIndex += 1

	-- Hang the player

	if self.currentPlayerIndex > #self.players then
		self.currentPlayerIndex = 1
	end

	self.hasGuessed = false
	print("Next player is:", self.players[self.currentPlayerIndex])
end

function Hangman:endRound()
	-- Reset game state for next round
	self.round = self.round + 1
	self.currentPlayerIndex = 1
	self.guessedLetters = {}
	self.remainingAttempts = CONFIG.MAX_ATTEMPTS
	self.hasGuessed = false

	-- Clear the previous word display
	self.Events.TimerEvent:FireAllClients(0) -- Clear the timer display
	self.Events.WordLengthEvent:FireAllClients(0) -- Clear the current word display

	-- Reset UI elements
	self.Events.ButtonPressEvent:FireAllClients("Reset Buttons")

	-- Add delay for players to see results
	task.wait(3)

	teleportPlayers(self.players, "RoundEnd")

	-- Transition to intermission state
	self.state = gameStates.INTERMISSION
end

function Hangman:initializePlayers()
	self.players = {}
	self.playerAttempts = {}

	for _, player in game.Players:GetPlayers() do
		if player.Character then
			if not table.find(self.players, player) then
				table.insert(self.players, player)
				self.playerAttempts[player.UserId] = CONFIG.MAX_ATTEMPTS
			end
		else
			warn(player.Name .. " has no character, waiting for load")
			player.CharacterAdded:Wait()
			table.insert(self.players, player)
			self.playerAttempts[player.UserId] = CONFIG.MAX_ATTEMPTS
		end
	end

	return #self.players > 0
end

return Hangman
