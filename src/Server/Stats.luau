local Stats = {}
Stats.__index = Stats

local DataStoreService = game:GetService("DataStoreService")
local LeadboardStore = DataStoreService:GetDataStore("HangmanLeaderboard")
-- Creating one just for the leaderboard
local LeaderboardOrderedStore = DataStoreService:GetOrderedDataStore("HangmanLeaderboard_Ordered")

local playerStats = {
	-- {wins = 0, lettersGuessed = 0, totalChances = 0}
}

-- Constants
local CORRECT_LETTER_GUESS = 2
local CORRECT_WORD_GUESS = 5

function Stats.setupLeaderstats(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	-- Create letters guessed stat
	local lettersGuessed = Instance.new("IntValue")
	lettersGuessed.Name = "Letters"
	lettersGuessed.Value = 0
	lettersGuessed.Parent = leaderstats

	-- Create wins stat
	local wins = Instance.new("IntValue")
	wins.Name = "Wins"
	wins.Value = 0
	wins.Parent = leaderstats

	leaderstats.Parent = player

	-- Load existing data if available
	if playerStats[player.UserId] then
		wins.Value = playerStats[player.UserId].wins
		lettersGuessed.Value = playerStats[player.UserId].lettersGuessed
	end
end

function Stats.initializePlayer(player: Instance)
	local success, data = pcall(function()
		return LeadboardStore:GetAsync(player.UserId)
	end)

	if success and data then
		playerStats[player.UserId] = data
	else
		playerStats[player.UserId] = {
			wins = 0,
			lettersGuessed = 0,
			totalChances = 0,
		}
	end

	Stats.setupLeaderstats(player)
end

function Stats.updatePlayerStats(player: Instance, letters: number, isWordGuess: boolean)
	if not playerStats[player.UserId] then
		Stats.initializePlayer(player)
	end

	local stats = playerStats[player.UserId]

	if isWordGuess then
		stats.wins += 1
		stats.totalChances += CORRECT_WORD_GUESS
	else
		stats.lettersGuessed += letters
		stats.totalChances += (letters * CORRECT_LETTER_GUESS)
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		leaderstats.Wins.Value = stats.wins
		leaderstats.Letters.Value = stats.lettersGuessed
		-- leaderstats.Score.Value = stats.totalChances
	end

	pcall(function()
		LeadboardStore:SetAsync(player.UserId, stats)
		LeaderboardOrderedStore:SetAsync(player.UserId, stats.wins)
	end)

	print(playerStats[player.UserId].totalChances .. "xp")
	return stats
end

function Stats.getPlayerStats(player: Instance)
	if not playerStats[player.UserId] then
		Stats.initializePlayer(player)
	end

	return playerStats[player.UserId]
end

function Stats.getLeaderboard()
	local leadboardData = {}

	for userId, stats in playerStats do
		table.insert(leadboardData, { userId = userId, stats = stats })
	end

	table.sort(leadboardData, function(a, b)
		return a.stats.totalChances > b.stats.totalChances
	end)

	return leadboardData
end

function Stats.getTopLeaderboard()
	local success, data = pcall(function()
		local pages = LeaderboardOrderedStore:GetSortedAsync(false, 100)
		return pages:GetCurrentPage()
	end)

	if not success then
		warn("Failed to get leaderboard data:", data)
		return {}
	end

	local leaderboardData = {}

	for _, entry in ipairs(data) do
		-- Get full player stats from regular DataStore
		local success, playerData = pcall(function()
			return LeadboardStore:GetAsync(entry.key)
		end)

		if success and playerData then
			table.insert(leaderboardData, {
				userId = entry.key,
				stats = playerData,
			})
		end
	end

	return leaderboardData
end

return Stats
