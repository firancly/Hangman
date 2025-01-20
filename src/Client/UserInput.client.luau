local player = game.Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

local ButtonPressEvent = game.ReplicatedStorage:WaitForChild("ButtonPressEvent")
local WordLengthEvent = game.ReplicatedStorage:WaitForChild("WordLengthEvent")
local CorrectGuessEvent = game.ReplicatedStorage:WaitForChild("CorrectGuessEvent")

local upperRow = PlayerGui:WaitForChild("ScreenGui").Keyboard.Row_1
local middleRow = PlayerGui:WaitForChild("ScreenGui").Keyboard.Row_2
local lowerRow = PlayerGui:WaitForChild("ScreenGui").Keyboard.Row_3

local function onButtonClick(button)
	local buttonName = button.Name
	ButtonPressEvent:FireServer(buttonName)
end

local function connectButtons(parent)
	for _, button in parent:GetChildren() do
		if button:isA("TextButton") then
			button.MouseButton1Click:Connect(function()
				onButtonClick(button)
			end)
		end
	end
end

WordLengthEvent.OnClientEvent:Connect(function(wordLength)
	for i = 1, wordLength do
		local underline = PlayerGui.ScreenGui.Word.UnderlineTemplate:Clone()
		underline.Parent = PlayerGui.ScreenGui.Word
		underline.Name = "Underline_" .. i
		underline.Visible = true
	end
end)

CorrectGuessEvent.OnClientEvent:Connect(function(index, letter)
	warn(index, letter)
	local underline = PlayerGui.ScreenGui.Word:FindFirstChild("Underline_" .. index)
	print(underline)
	if underline then
		local letterUi = underline.TextLabel
		letterUi.Text = letter
	end
end)

connectButtons(upperRow)
connectButtons(middleRow)
connectButtons(lowerRow)
