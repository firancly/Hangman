local player = game.Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

local ButtonPressEvent = game.ReplicatedStorage:WaitForChild("ButtonPressEvent")

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

connectButtons(upperRow)
connectButtons(middleRow)
connectButtons(lowerRow)
