local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local ScreenGui = PlayerGui:WaitForChild("ScreenGui")
local KeyboardUI = ScreenGui:WaitForChild("Keyboard")
local WordUI = ScreenGui:WaitForChild("Word")

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

-- Utility functions to handle button click
local function disableButton(button, letter)
	if not button then
		return
	end

	-- Grey out button
	button.AutoButtonColor = false
	button.BackgroundColor3 = Color3.fromRGB(128, 128, 128)

	-- Disconnect the button's click event
	if buttonConnections[button] then
		buttonConnections[button]:Disconnect()
		buttonConnections[button] = nil
	end

	local testLabel = button:FindFirstChild("TestLabel")
	if testLabel then
		testLabel.Visible = true
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
			buttonConnections[button] = button.MouseButton1Click:Connect(function()
				handleButtonClick(button)
			end)
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
	else
		local underlines = WordUI:GetChildren()
		for _, underline in underlines do
			if underline:IsA("Frame") and string.find(underline.Name, "Underline_") then
				underline:Destroy()
			end
		end
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
		local keyboard = KeyboardUI:GetDescendants()
		for _, ui in keyboard do
			if ui:IsA("TextButton") then
				ui.AutoButtonColor = true
				ui.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
				for _, row in KeyboardRows do
					connectButtons(row)
				end
			end
		end
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
		for _, ui in keyboard do
			if ui:IsA("TextButton") and ui.Name == letter then
				disableButton(ui, letter)
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
	local underline = WordUI:FindFirstChild("Underline_" .. index)
	if underline then
		local letterUi = underline.TextLabel
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
