local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local ScreenGui = PlayerGui:WaitForChild("ScreenGui")

local KeyboardUI = ScreenGui.Keyboard
local sign = ScreenGui.Sign.WordSign

-- Store button connections so we can disconnect them later
local buttonConnections = {}

local Events = {
	ButtonPress = ReplicatedStorage:WaitForChild("ButtonPressEvent"),
	WordLength = ReplicatedStorage:WaitForChild("WordLengthEvent"),
	CorrectGuess = ReplicatedStorage:WaitForChild("CorrectGuessEvent"),
	GameOver = ReplicatedStorage:WaitForChild("GameOverEvent"),
	TestEvent = ReplicatedStorage:WaitForChild("TestEvent"),
	TimerEvent = ReplicatedStorage:WaitForChild("TimerEvent"),
	PlayerAttempts = ReplicatedStorage:WaitForChild("PlayerAttemptsEvent"),
	CurrentPlayer = ReplicatedStorage:WaitForChild("CurrentPlayerEvent"),
	HangmanSelection = ReplicatedStorage:WaitForChild("HangmanSelectionEvent"),
}

local KeyboardRows = {
	Upper = KeyboardUI:WaitForChild("Row_1"),
	Middle = KeyboardUI:WaitForChild("Row_2"),
	Lower = KeyboardUI:WaitForChild("Row_3"),
}

local ButtonStates = {
	NORMAL = "Button",
	HOVER = "Hover",
	PRESSED = "Pressed",
}

local buttonStates = {}

local stateHandlers = {
	[ButtonStates.NORMAL] = function(button)
		button.Normal.Visible = true
		button.Hover.Visible = false
		button.Pressed.Visible = false
	end,

	[ButtonStates.HOVER] = function(button)
		button.Normal.Visible = false
		button.Hover.Visible = true
		button.Pressed.Visible = false
	end,

	[ButtonStates.PRESSED] = function(button)
		button.Normal.Visible = false
		button.Hover.Visible = false
		button.Pressed.Visible = true
	end,
}

-- Change the size of the sign container based on the word length
local function updateContainerSize(wordLength)
	local smallSign = sign.Parent.SmallSign
	local normalSign = sign.Parent.NormalSign
	local largeSign = sign.Parent.LongSign

	-- Maybe add some tweening between transitions idk
	if wordLength == 0 then
		normalSign.Visible = false
		smallSign.Visible = true
		largeSign.Visible = false
	else
		smallSign.Visible = wordLength > 0 and wordLength <= 5
		normalSign.Visible = wordLength > 5 and wordLength <= 8
		largeSign.Visible = wordLength > 8
	end
end

-- Change the state of a button
local function updateButtonState(button, state)
	if not button or not stateHandlers[state] then
		return
	end

	buttonStates[button] = state
	stateHandlers[state](button)
end

-- Disable a button
local function disableButton(button)
	if not button then
		return
	end

	-- Update button state
	updateButtonState(button, ButtonStates.PRESSED)

	-- Disconnect the button's click event
	if buttonConnections[button] then
		buttonConnections[button]:Disconnect()
		buttonConnections[button] = nil
		updateButtonState(button, ButtonStates.PRESSED)
	end
end

-- Fire server event when a button is clicked
local function handleButtonClick(button)
	if not button then
		return
	end
	Events.ButtonPress:FireServer("Button Input", button.Name)
end

-- Connect button events
local function connectButtons(parent)
	for _, button in parent:GetChildren() do
		if button:IsA("TextButton") then
			-- Click handler
			buttonConnections[button] = button.MouseButton1Click:Connect(function()
				handleButtonClick(button)
			end)

			-- Initialize button state
			buttonStates[button] = ButtonStates.NORMAL

			-- Handle button hover enter
			button.MouseEnter:Connect(function()
				if buttonStates[button] ~= ButtonStates.PRESSED then
					updateButtonState(button, ButtonStates.HOVER)
				end
			end)

			-- Handle button hover leave
			button.MouseLeave:Connect(function()
				if buttonStates[button] ~= ButtonStates.PRESSED then
					updateButtonState(button, ButtonStates.NORMAL)
				end
			end)
		end
	end
end

-- Initialize keyboard
for _, row in KeyboardRows do
	connectButtons(row)
end

-- Reset button connections after round ends
local function cleanupButtons()
	local keyboard = KeyboardUI:GetDescendants()
	for _, button in keyboard do
		if button:IsA("TextButton") then
			buttonStates[button] = nil

			updateButtonState(button, ButtonStates.NORMAL)

			for _, row in KeyboardRows do
				connectButtons(row)
			end
		end
	end
end

-- Update underlines based on word length
local function underlineUpdater(wordLength)
	if wordLength > 0 then
		for i = 1, wordLength do
			local underline = sign.UnderlineTemplate:Clone()
			underline.Parent = sign
			underline.Name = "Underline_" .. string.format("%02d", i)
			underline.Visible = true
		end
		updateContainerSize(wordLength)
	else
		local underlines = sign:GetChildren()
		for _, underline in underlines do
			if underline:IsA("Frame") and string.find(underline.Name, "Underline_") then
				underline:Destroy()
			end
		end
		updateContainerSize(wordLength)
	end
end

-- Update word view based on game state
local function wordViewUpdater(state)
	if state == "GameOver" then -- Destroy underlines and game over message
		-- Disable main ui
		KeyboardUI.Visible = false

		-- Underline ui cleanup

		task.wait(5)
		-- Game over ui cleanup
		for _, ui in ScreenGui.GameOver:GetChildren() do
			ui.Visible = false
		end

		cleanupButtons()
	elseif state == "GameStart" then
		-- Enable main ui
		KeyboardUI.Visible = true
	end
end

-- Handle button press events
Events.ButtonPress.OnClientEvent:Connect(function(action, letter)
	local keyboard = KeyboardUI:GetDescendants()
	if action == "Button Disable" then
		for _, button in keyboard do
			if button:IsA("TextButton") and button.Name == letter then
				disableButton(button)
			end
		end
	elseif action == "Reset Buttons" then
		wordViewUpdater("GameOver")
	end
end)

-- Initialize word UI
Events.WordLength.OnClientEvent:Connect(function(wordLength)
	underlineUpdater(wordLength)
	if wordLength <= 0 then
		wordViewUpdater("GameOver")
	else
		wordViewUpdater("GameStart")
	end
end)

-- Update word UI
Events.CorrectGuess.OnClientEvent:Connect(function(player, index, letter)
	local signUnderline = sign:FindFirstChild("Underline_" .. string.format("%02d", index))
	if signUnderline then
		local signUi = signUnderline.TextLabel
		signUi.Text = letter
	end
end)

-- Handle game over event
Events.GameOver.OnClientEvent:Connect(function(action)
	local frame = ScreenGui.GameOver
	local win = frame.Win
	local lose = frame.Lose

	-- Destroy all underlines
	underlineUpdater(0)
	updateContainerSize(0)

	if action == "Win" then
		win.Visible = true
	elseif action == "Lose" then
		-- Display lose message
		lose.Visible = true
	end
end)

-- INTERMISSION TIMER EVENT
Events.TimerEvent.OnClientEvent:Connect(function(time: number)
	local timer = ScreenGui:WaitForChild("Timer")
	local timerText = timer.TextLabel

	if not time or time < 0 then
		timer.Visible = false
		return
	end

	timerText.Text = time

	timer.Visible = time > 0
end)

-- CHOOSE THE HANGMAN
local function getOrderedPlayerList()
	local playerList = Players:GetPlayers()
	table.sort(playerList, function(a, b)
		return a.UserId < b.UserId
	end)
	return playerList
end

Events.HangmanSelection.OnClientEvent:Connect(function(state, randomValue, totalWeight, hangman)
	local poster = ScreenGui.HangmanSelection.Poster
	local avatars = poster:GetChildren()
	poster.Parent.Visible = true

	if state == "End" then
		-- Clear the ui
		poster.Parent.Visible = false
		return
	end

	local orderedPlayers = getOrderedPlayerList()

	-- Set player avatar photos
	for i, player in orderedPlayers do
		local avatarFrame = avatars[i]
		if avatarFrame and avatarFrame.ImageLabel:IsA("ImageLabel") then
			local success, thumbnail = pcall(function()
				return Players:GetUserThumbnailAsync(
					player.UserId,
					Enum.ThumbnailType.HeadShot,
					Enum.ThumbnailSize.Size420x420
				)
			end)

			if success then
				avatarFrame.ImageLabel.Image = thumbnail
				avatarFrame.Visible = true
				avatarFrame.NameLabel.Text = player.Name
			else
				warn("Failed to load thumbnail for player: " .. player.Name)
			end
		end
	end

	-- Adjust the progress bar according to the random value
	local progressContainer = poster.Parent.PercentageSelection.ProgressBar
	local progressBar = progressContainer.Bar

	local fillPercentage = randomValue / totalWeight
	print(fillPercentage)

	local TweenService = game:GetService("TweenService")
	local tweenInfo = TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	local goal = {
		Size = UDim2.new(fillPercentage, 0, 1, 0), -- Keep height at 100%, width based on percentage
	}

	local tween = TweenService:Create(progressBar, tweenInfo, goal)
	tween:Play()

	-- Make the Selection overlay go over random players and then stop at the hangman player
	-- Selection overlay is local selecitonOverlay = poster.Selection:GetChildren() -- basically put overlays over the the thumbnails on and off them and then stop at the hangman

	-- Add selection overlay animation
	local selectionOverlay = poster.Selection:GetChildren()
	local currentIndex = 1
	local animationDuration = 1.5 -- Duration before final selection
	local switchInterval = 0.1 -- Time between switches

	-- Function to move overlay between players
	local function moveOverlay()
		-- Hide all overlays first
		for _, overlay in selectionOverlay do
			overlay.Visible = false
		end

		-- Show current overlay
		if selectionOverlay[currentIndex] then
			selectionOverlay[currentIndex].Visible = true
		end

		-- Move to next player
		currentIndex = (currentIndex % #selectionOverlay) + 1
	end

	-- Find the hangman's index in the players list
	local hangmanIndex = 1
	if not hangman then
		warn("Hangman is nil! Using default index 1")
	else
		-- print("Received hangman data:", {
		-- 	Name = hangman.Name,
		-- 	UserId = hangman.UserId,
		-- 	ClassName = hangman.ClassName,
		-- }) -- debug print

		for i, player in orderedPlayers do
			if player.UserId == hangman.UserId then
				print("Found hangman", player.Name, "at index", i)
				hangmanIndex = i
				break
			end
		end
	end

	-- Start rapid switching animation
	local switching = true
	local startTime = os.clock()

	-- Connect animation to RunService
	local RunService = game:GetService("RunService")
	local lastSwitchTime = 0

	local connection
	connection = RunService.RenderStepped:Connect(function()
		local currentTime = os.clock()
		local elapsedTime = currentTime - startTime

		-- Check if we should stop animation
		if elapsedTime >= animationDuration then
			switching = false
			connection:Disconnect()

			-- Show overlay on final selected player
			for i, overlay in selectionOverlay do
				overlay.Visible = (i == hangmanIndex)
			end
			return
		end

		-- Switch overlay position based on interval
		if switching and (currentTime - lastSwitchTime) >= switchInterval then
			moveOverlay()
			lastSwitchTime = currentTime

			-- Gradually slow down the switching
			switchInterval = 0.1 + (elapsedTime / animationDuration * 0.2)
		end
	end)

	-- Clean up when state ends
	if state == "End" then
		if connection then
			connection:Disconnect()
		end
		-- Hide all overlays
		for _, overlay in selectionOverlay do
			overlay.Visible = false
		end
	end
end)

-- TEST EVENT
Events.TestEvent.OnClientEvent:Connect(function(word)
	local textLabel = ScreenGui.Shit.TextLabel
	textLabel.Text = word
end)

-- Display player attempts
Events.PlayerAttempts.OnClientEvent:Connect(function(attempts)
	local textLabel = ScreenGui.Shit.Attempts
	textLabel.Text = "Attempts: " .. attempts
end)

-- Display current player
Events.CurrentPlayer.OnClientEvent:Connect(function(player)
	local textLabel = ScreenGui.Shit.Player
	textLabel.Text = player
end)
