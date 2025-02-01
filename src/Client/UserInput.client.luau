local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local ScreenGui = PlayerGui:WaitForChild("ScreenGui")

local KeyboardUI = ScreenGui.Keyboard
local WordUI = ScreenGui.Word
local sign = ScreenGui.WordSign

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

local function updateContainerSize(container)
	local gridLayout = container:FindFirstChildOfClass("UIGridLayout")
	local padding = container:FindFirstChildOfClass("UIPadding")

	if not gridLayout then
		return
	end

	-- Get layout properties
	local cellSize = gridLayout.CellSize.X.Offset
	local cellPadding = gridLayout.CellPadding.X.Offset
	local containerPadding = padding and (padding.PaddingLeft.Offset + padding.PaddingRight.Offset) or 0

	-- Calculate required width
	local childCount = #container:GetChildren() - 2 -- Subtract UIGridLayout and UIPadding
	local totalWidth = (cellSize * childCount) + (cellPadding * (childCount - 1)) + containerPadding

	-- Update container size
	container.Size = UDim2.new(0, totalWidth, container.Size.Y.Scale, container.Size.Y.Offset)
end

local function updateButtonState(button, state)
	if not button or not stateHandlers[state] then
		return
	end

	buttonStates[button] = state
	stateHandlers[state](button)
end

-- Utility functions to handle button click
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

local function handleButtonClick(button)
	if not button then
		return
	end
	Events.ButtonPress:FireServer("Button Input", button.Name)
end

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

local function underlineUpdater(wordLength)
	if wordLength > 0 then
		for i = 1, wordLength do
			local underline = WordUI.UnderlineTemplate:Clone()
			underline.Parent = WordUI
			underline.Name = "Underline_" .. i
			underline.Visible = true
		end
		updateContainerSize(WordUI)
	else
		local underlines = WordUI:GetChildren()
		for _, underline in underlines do
			if underline:IsA("Frame") and string.find(underline.Name, "Underline_") then
				underline:Destroy()
			end
		end
		updateContainerSize(WordUI)
	end
end

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

		-- Game over ui cleanup
		for _, ui in ScreenGui.GameOver:GetChildren() do
			ui.Visible = false
		end

		-- Keyboard reset
		-- local keyboard = KeyboardUI:GetDescendants()
		-- for _, ui in keyboard do
		-- 	if ui:IsA("TextButton") then
		-- 		ui.AutoButtonColor = true
		-- 		ui.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		-- 		for _, row in KeyboardRows do
		-- 			connectButtons(row)
		-- 		end
		-- 	end
		-- end
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
	if wordLength > 0 then
		for i = 1, wordLength do
			local underline = sign.UnderlineTemplate:Clone()
			underline.Parent = sign
			underline.Name = "Underline_" .. i
			underline.Visible = true
		end
	else
		local underlines = sign:GetChildren()
		for _, underline in underlines do
			if underline:IsA("Frame") and string.find(underline.Name, "Underline_") then
				underline:Destroy()
			end
		end
	end
	underlineUpdater(wordLength)
	wordViewUpdater("GameStart")
end)

-- Update word UI
Events.CorrectGuess.OnClientEvent:Connect(function(player, index, letter)
	local underline = WordUI:FindFirstChild("Underline_" .. index)
	local signUnderline = sign:FindFirstChild("Underline_" .. index)
	if underline and signUnderline then
		local letterUi = underline.TextLabel
		local signUi = signUnderline.TextLabel
		signUi.Text = letter
		letterUi.Text = letter
	end
end)

-- Handle game over event
Events.GameOver.OnClientEvent:Connect(function(action)
	local frame = ScreenGui.GameOver
	local win = frame.Win
	local lose = frame.Lose

	-- Destroy all underlines
	underlineUpdater(0)
	if action == "Win" then
		win.Visible = true
	elseif action == "Lose" then
		-- Display lose message
		lose.Visible = true
	end
end)

-- TEST EVENT
Events.TestEvent.OnClientEvent:Connect(function(word)
	local textLabel = ScreenGui.Shit.TextLabel
	textLabel.Text = word
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

-- Initialize keyboard
for _, row in KeyboardRows do
	connectButtons(row)
end
