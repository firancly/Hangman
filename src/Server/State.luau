local Hangman = {}
Hangman.__index = Hangman

local DataStoreService = game:GetService("DataStoreService")
local LeadboardStore = DataStoreService:GetDataStore("HangmanLeaderboard")
local Stats = require(script.Parent:WaitForChild("Stats"))

-- Configuration
local CONFIG = {
	MAX_ATTEMPTS = 6,
	INTERMISSION_TIME = 5,
	HANGMAN_TIME = 5,
	PLAYER_TURN_TIME = 10,
	MIN_PLAYERS = 1,
	MAX_PLAYERS = 8,
}

local gameStates = {
	INTERMISSION = "Intermission",
	ROUND_START = "GameStart",
	PLAYER_TURN = "PlayerTurn",
	ROUND_END = "RoundEnd",
	GAME_OVER = "GameOver",
}

function Hangman.new()
	local self = {
		state = nil,
		currentState = nil,

		-- Players
		players = {},
		playerAttempts = {},
		currentPlayerIndex = 1,
		currentPlayer = nil,

		-- Word
		word = "",
		guessedLetters = {},
		hasGuessed = false,
		remainingAttempts = CONFIG.MAX_ATTEMPTS,
		lastGuessTime = 0, -- for button press spam prevention

		-- Timers
		timerConnection = nil, -- Important
		currentTime = os.time(),
		endTime = 0,

		-- Misc
		round = 1,
	}

	self.Events = {
		ButtonPressEvent = game.ReplicatedStorage:WaitForChild("ButtonPressEvent"),
		WordLengthEvent = game.ReplicatedStorage:WaitForChild("WordLengthEvent"),
		CorrectGuessEvent = game.ReplicatedStorage:WaitForChild("CorrectGuessEvent"),
		GameOverEvent = game.ReplicatedStorage:WaitForChild("GameOverEvent"),
		TestEvent = game.ReplicatedStorage:WaitForChild("TestEvent"),
		TimerEvent = game.ReplicatedStorage:WaitForChild("TimerEvent"),
		PlayerAttemptsEvent = game.ReplicatedStorage:WaitForChild("PlayerAttemptsEvent"),
		CurrentPlayerEvent = game.ReplicatedStorage:WaitForChild("CurrentPlayerEvent"),
		HangmanSelectionEvent = game.ReplicatedStorage:WaitForChild("HangmanSelectionEvent"),
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

	-- Handle button presses
	self.Events.ButtonPressEvent.OnServerEvent:Connect(function(player, action, letter)
		self:handleButtonPress(player, action, letter)
	end)

	setmetatable(self, Hangman)
	return self
end

Hangman.stateHandlers = {
	[gameStates.INTERMISSION] = {
		enter = function(self)
			-- warn("Intermission state entered")
			-- Initialize intermission state
			self:initializePlayers()

			-- Start intermission timer
			self:startTimer(CONFIG.INTERMISSION_TIME, function()
				self:setState(gameStates.ROUND_START)
			end)
		end,

		exit = function(self)
			-- Clean up intermission state
			if self.timerConnection then
				self.timerConnection:Disconnect()
				self.timerConnection = nil
				self.Events.TimerEvent:FireAllClients(0)
			end
		end,
	},

	[gameStates.ROUND_START] = {
		enter = function(self)
			-- warn("Round start state entered")
			-- Initialize round

			-- 10 seconds to choose the hangman with ui
			self:chooseHangman(self.players)

			self:startTimer(CONFIG.HANGMAN_TIME, function()
				self.Events.HangmanSelectionEvent:FireAllClients({ state = "End" })

				-- Remove the hangman from the table self.players
				-- Teleport the hangman and attach the ropes

				self.word = self:RandomWord()
				self.Events.TestEvent:FireAllClients(self.word)

				-- Teleport players and update UI
				self:teleportPlayers(self.players, self.state)

				for _, player in self.players do
					self.Events.PlayerAttemptsEvent:FireClient(player, self.playerAttempts[player.UserId])
					self.Events.WordLengthEvent:FireClient(player, self.word:len())
				end

				self:setState(gameStates.PLAYER_TURN)
			end)
		end,
	},

	[gameStates.PLAYER_TURN] = {
		enter = function(self)
			-- warn("Player turn state entered")
			self.currentPlayer = self.players[self.currentPlayerIndex]
			if not self.currentPlayer then
				warn("No current player!")
				self:setState(gameStates.ROUND_END)
				return
			end

			self.hasGuessed = false
			self.Events.CurrentPlayerEvent:FireAllClients(self.currentPlayer.Name)

			self:startTimer(CONFIG.PLAYER_TURN_TIME, function()
				if self.hasGuessed then
					self:nextPlayer()
				elseif not self.hasGuessed then
					warn("Player did not guess in time!")
					self:handleIncorrectGuess(self.currentPlayer)
				end
			end)
		end,

		exit = function(self)
			if self.timerConnection then
				self.timerConnection:Disconnect()
				self.timerConnection = nil
				self.Events.TimerEvent:FireAllClients(0)
			end
		end,
	},

	[gameStates.ROUND_END] = {
		enter = function(self)
			-- warn("Round end state entered")
			-- Reset game state for next round
			self.round = self.round + 1
			self.currentPlayerIndex = 1
			self.guessedLetters = {}
			self.remainingAttempts = CONFIG.MAX_ATTEMPTS
			self.hasGuessed = false

			-- Clear UI
			self.Events.WordLengthEvent:FireAllClients(0)
			self.Events.ButtonPressEvent:FireAllClients("Reset Buttons")

			-- Reset the timer for the next round

			assert(self.timerConnection == nil, "Timer should be nil after cleanup")

			print("before delay:", os.time())
			-- Add delay and teleport
			task.delay(5, function()
				print("after delay:", os.time())
				self:teleportPlayers(self.players, "RoundEnd")
				self:setState(gameStates.INTERMISSION)
			end)
		end,
	},
}

function Hangman:update()
	if self.currentState and self.currentState.update then
		self.currentState.update(self)
	end
end

function Hangman:setState(newState, ...)
	-- Clean up previous state if needed
	if self.currentState and self.currentState.exit then
		self.currentState.exit(self)
	end

	-- Initialize new state
	self.state = newState
	local stateHandler = self.stateHandlers[newState]
	if stateHandler then
		self.currentState = stateHandler
		if stateHandler.enter then
			stateHandler.enter(self, ...)
		end
	end
end

----- MAIN FUNCTIONS -----
-- Used to add players to the game
function Hangman:initializePlayers()
	self.players = {}
	self.playerAttempts = {}

	while #self.players < CONFIG.MIN_PLAYERS do
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

		task.wait(1)
	end

	return #self.players > 0
end

function Hangman:startTimer(duration, callback)
	if self.timerConnection then
		self.timerConnection:Disconnect()
	end

	self.currentTime = duration
	self.endTime = os.time() + duration
	self.Events.TimerEvent:FireAllClients(self.currentTime)

	self.timerConnection = game:GetService("RunService").Heartbeat:Connect(function()
		local currentOsTime = os.time()
		local timeLeft = self.endTime - currentOsTime

		if timeLeft ~= self.currentTime then
			self.currentTime = timeLeft
			self.Events.TimerEvent:FireAllClients(self.currentTime)

			if self.currentTime <= 0 then
				self.timerConnection:Disconnect()
				if callback then
					callback()
				end
			end
		end
	end)
end

function Hangman:teleportPlayers(players, state)
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

function Hangman:handleButtonPress(player, action, letter)
	if action == "Button Input" then
		local currentTime = os.clock()

		if
			self.state ~= gameStates.PLAYER_TURN
			or player ~= self.players[self.currentPlayerIndex]
			or self.playerAttempts[player.UserId] <= 0
			or self.hasGuessed
		then
			warn("Not allowed to guess!")
			return
		end

		if currentTime - self.lastGuessTime < 0.2 then
			return
		end

		self.lastGuessTime = currentTime
		self.hasGuessed = true

		local success = self:guessLetter(player, letter)
		if success then
			self:nextPlayer()
		else
			self:handleIncorrectGuess(player)
		end
	end
end

function Hangman:guessLetter(player, letter)
	if self.state == gameStates.PLAYER_TURN or player == self.players[self.currentPlayerIndex] then
		if not self.guessedLetters then
			warn("guessedLetters is nil! Reinitializing...")
			self.guessedLetters = {}
		end

		if table.find(self.guessedLetters, letter) then
			warn("Letter already guessed:", letter)
			return false
		end

		table.insert(self.guessedLetters, letter)
		self.Events.ButtonPressEvent:FireAllClients("Button Disable", letter)

		print("Current guessedLetters table:", table.concat(self.guessedLetters, ", "))

		local indexes = self:findAllIndexes(self.word, letter)
		if #indexes > 0 then
			for _, index in indexes do
				-- Give player points and add it to the leaderboard
				self.Events.CorrectGuessEvent:FireAllClients(player, index, letter)
			end

			-- send letter to update chances
			Stats.updatePlayerStats(player, #indexes, false)

			-- Check if the round is over immediately after a correct guess
			if self:checkWinCondition() then
				print("Round over! " .. player.Name .. " wins!")
				-- send word = true to update chances
				Stats.updatePlayerStats(player, 0, true)
				-- Send player.name to the client to update the ui
				self.Events.GameOverEvent:FireClient(player, "Win")
				self:setState(gameStates.ROUND_END)
				return true
			end
			return true
		else
			return false
		end
	end
end

function Hangman:nextPlayer()
	if not self.players or #self.players == 0 or self.state == gameStates.ROUND_END then
		warn("No players to switch to!")
		self:setState(gameStates.ROUND_END)
		return
	end

	warn("CurrentPlayer Index", self.currentPlayerIndex, "Table:", self.players)

	-- Hang the player

	self.currentPlayerIndex = (self.currentPlayerIndex % #self.players) + 1
	self.hasGuessed = false

	self:setState(gameStates.PLAYER_TURN)
	print("Next player is:", self.players[self.currentPlayerIndex])
end

function Hangman:handleIncorrectGuess(player)
	if not self.playerAttempts[player.UserId] then
		self.playerAttempts[player.UserId] = CONFIG.MAX_ATTEMPTS
	end
	self.playerAttempts[player.UserId] -= 1
	self:checkAttempts(player)

	self:nextPlayer() -- Move to next playe
end

function Hangman:checkAttempts(currentPlayer)
	print("Attempts:", self.playerAttempts[currentPlayer.UserId], "for player", currentPlayer)
	self.Events.PlayerAttemptsEvent:FireClient(currentPlayer, self.playerAttempts[currentPlayer.UserId])
	if self.playerAttempts[currentPlayer.UserId] <= 0 then
		for i = #self.players, 1, -1 do
			if self.players[i] == currentPlayer then
				-- Remove the player from the game
				table.remove(self.players, i)
				self:teleportPlayers({ currentPlayer }, "RoundEnd")

				-- Update UI
				self.Events.WordLengthEvent:FireClient(currentPlayer, 0)
				self.Events.GameOverEvent:FireClient(currentPlayer, "Lose")

				-- Humiliate the player
				print("Players:", #self.players)
				break
			end
		end
	end
end

-- UTILITY FUNCTIONS
function Hangman:RandomWord()
	local themes = script.Parent.Themes:GetChildren()
	local randomTheme: { string } = require(themes[math.random(1, #themes)])
	local word = randomTheme[math.random(1, #randomTheme)]

	return string.upper(word)
end

function Hangman:findAllIndexes(word, letter)
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

function Hangman:chooseHangman(players)
	local weightTable = {}
	local totalWeight = 0

	for _, player in players do
		local stats = Stats.getPlayerStats(player)
		local weight = stats.totalChances
		totalWeight += weight

		table.insert(weightTable, {
			player = player,
			weight = weight,
			cumilative = totalWeight,
		})
	end

	for _, entry in weightTable do
		entry.percentage = math.floor((entry.weight / totalWeight) * 100)
		-- Fire event to display percentage under the player name
	end

	local randomValue = math.random() * totalWeight

	local function sanitizeWeightData(weightTable)
		local clientData = {}
		for _, entry in weightTable do
			table.insert(clientData, {
				player = entry.player,
				percentage = entry.percentage,
			})
		end
		return clientData
	end

	for _, entry in weightTable do
		if randomValue <= entry.cumilative then
			print("Hangman is:", entry.player)
			local playerStats = Stats.getPlayerStats(entry.player)
			playerStats.totalChances = 0
			self.Events.HangmanSelectionEvent:FireAllClients({
				state = "Start",
				randomValue = randomValue,
				totalWeight = totalWeight,
				hangman = entry.player,
				clientData = sanitizeWeightData(weightTable),
			})
			return entry.player
		end
	end

	local randomPlayer = math.random(1, #players)
	print("Fallback returning random player: " .. randomPlayer)
	return players[randomPlayer]
end

Hangman.gameStates = gameStates
return Hangman
