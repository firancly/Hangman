-- ModuleScript: Hangman
local Hangman = {}

-- Game states
local gameStates = {
	INTERMISSION = "Intermission",
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
		word = word,
		guessedLetters = {},
		remainingAttempts = 6, -- Number of incorrect guesses allowed
		round = 1,
	}

	self.start = Hangman.start
	self.startIntermission = Hangman.startIntermission
	self.guessLetter = Hangman.guessLetter
	self.checkRoundOver = Hangman.checkRoundOver
	self.nextPlayer = Hangman.nextPlayer

	-- Debug: Verify that the start method is attached
	print("Is start method attached?", self.start ~= nil)

	return self
end

-- Method to start intermission (theme voting)
function Hangman:startIntermission()
	print("Intermission: Players, vote for a theme!")
	task.wait(20) -- Simulate 20s intermission
	self.state = gameStates.PLAYER_TURN
end

-- Method to handle player's guess
function Hangman:guessLetter(player, letter)
	if self.state ~= gameStates.PLAYER_TURN or player ~= self.players[self.currentPlayerIndex] then
		return false -- Only allow guesses during the player's turn
	end

	table.insert(self.guessedLetters, letter)
	if not string.find(self.word, letter) then
		self.remainingAttempts = self.remainingAttempts - 1
	end

	return true
end

-- Method to check if the round is over
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
		return true, "Round over! " .. self.players[self.currentPlayerIndex].name .. " wins!"
	end

	if self.remainingAttempts <= 0 then
		self.state = gameStates.ROUND_END
		return true, "Round over! " .. self.players[self.currentPlayerIndex].name .. " loses!"
	end

	return false
end

-- Method to move to the next player
function Hangman:nextPlayer()
	self.currentPlayerIndex = self.currentPlayerIndex + 1
	if self.currentPlayerIndex > #self.players then
		self.currentPlayerIndex = 1
	end
end

-- Method to start the game loop
function Hangman:start()
	while self.state ~= gameStates.GAME_OVER do
		if self.state == gameStates.INTERMISSION then
			self:startIntermission()
		elseif self.state == gameStates.PLAYER_TURN then
			local currentPlayer = self.players[self.currentPlayerIndex]
			print(currentPlayer.name .. ", guess a letter!")

			-- Simulate player input (replace this with actual input logic)

			local letter = "a" -- Example: Player guesses 'a'
			self:guessLetter(currentPlayer, letter)

			local isRoundOver, message = self:checkRoundOver()
			if isRoundOver then
				print(message)
				self.state = gameStates.ROUND_END
			else
				self:nextPlayer()
			end
		elseif self.state == gameStates.ROUND_END then
			print("Starting a new round...")
			self.round = self.round + 1
			self.state = gameStates.INTERMISSION
		end

		task.wait(1) -- Simulate a delay between turns
	end
end

return Hangman
