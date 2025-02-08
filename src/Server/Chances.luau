local Chances = {}
Chances.__index = Chances

local DataStoreService = game:GetService("DataStoreService")
local HangmanChanceDataStore = DataStoreService:GetDataStore("HangmanChanceDataStore")

local playerChances = {} -- replace with datastore

local CORRECT_LETTER_GUESS = 2
local CORRECT_WORD_GUESS = 5

-- Receive player chances from another module
-- Update player chances
-- Select a player randomly to be the hangman higher chances of being selected if player has more chances

function Chances.updatePlayerChances(player: Instance, letters: number, word: boolean)
	if not playerChances[player] then
		playerChances[player] = 0
	end

	local bonusChance = letters * CORRECT_LETTER_GUESS
	if word then
		bonusChance = bonusChance + CORRECT_WORD_GUESS
	end

	playerChances[player] = bonusChance
	print(playerChances[player] .. "xp")
end

return Chances
