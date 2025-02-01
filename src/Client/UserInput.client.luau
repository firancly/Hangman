local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local ScreenGui = PlayerGui:WaitForChild("ScreenGui")

local KeyboardUI = ScreenGui.Keyboard
local WordUI = ScreenGui.Word
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
		WordUI.Visible = false
		KeyboardUI.Visible = false

		-- Underline ui cleanup
		local underlines = WordUI:GetChildren()
		for _, underline in underlines do
			if underline:IsA("Frame") and string.find(underline.Name, "Underline_") then
				underline:Destroy()
			end
		end

		task.wait(3)
		-- Game over ui cleanup
		for _, ui in ScreenGui.GameOver:GetChildren() do
			ui.Visible = false
		end

		cleanupButtons()
	elseif state == "GameStart" then
		print("GameStart")
		-- Enable main ui
		WordUI.Visible = true
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
	wordViewUpdater("GameStart")
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
	timerText.Text = time
	local counter = time

	timer.Visible = if time == 0 then false else true

	while counter > 0 do
		counter -= 1
		timerText.Text = counter
		task.wait(1)
	end

	timer.Visible = false
end)

-- TEST EVENT
Events.TestEvent.OnClientEvent:Connect(function(word)
	local textLabel = ScreenGui.Shit.TextLabel
	textLabel.Text = word
end)
