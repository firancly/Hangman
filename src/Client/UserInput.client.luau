local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
		for _, ui in keyboard do
			if ui:IsA("TextButton") then
				ui.AutoButtonColor = true
				ui.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
				for _, row in KeyboardRows do
					connectButtons(row)
				end
			end
		end
	end
end)

-- Initialize word UI
Events.WordLength.OnClientEvent:Connect(function(wordLength)
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
end)

-- Update word UI
Events.CorrectGuess.OnClientEvent:Connect(function(player, index, letter)
	local underline = WordUI:FindFirstChild("Underline_" .. index)
	if underline then
		local letterUi = underline.TextLabel
		letterUi.Text = letter
	end
end)

-- Initialize keyboard
for _, row in KeyboardRows do
	connectButtons(row)
end
