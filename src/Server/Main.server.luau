--!strict
local RunService = game:GetService("RunService")
local Hangman = require(script.Parent:WaitForChild("State"))
local Stats = require(script.Parent:WaitForChild("Stats"))

-- Create remote events
local function createRemoteEvent(name)
	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = game.ReplicatedStorage
	return event
end

createRemoteEvent("ButtonPressEvent")
createRemoteEvent("WordLengthEvent")
createRemoteEvent("CorrectGuessEvent")
createRemoteEvent("GameOverEvent")
createRemoteEvent("TestEvent")
createRemoteEvent("TimerEvent")
createRemoteEvent("PlayerAttemptsEvent")
createRemoteEvent("CurrentPlayerEvent")
createRemoteEvent("HangmanSelectionEvent")

local function disableAnimations(character)
	local humanoid = character:WaitForChild("Humanoid")

	-- Disable default animations
	humanoid.AutoRotate = false
	humanoid.AutomaticScalingEnabled = false

	-- Stop existing animations
	for _, track in pairs(humanoid:GetPlayingAnimationTracks()) do
		track:Stop(0) -- Stop immediately
	end

	-- Prevent new animations
	humanoid.Animator:Destroy()

	-- Lock character in place
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
end

game.Players.PlayerAdded:Connect(function(player)
	Stats.initializePlayer(player)

	-- Wait for character to load and handle respawns
	local function setupAttachments(character)
		disableAnimations(character)

		-- Wait for all parts to load
		local rightHand = character:WaitForChild("RightHand")
		local leftHand = character:WaitForChild("LeftHand")
		local rightFoot = character:WaitForChild("RightFoot")
		local leftFoot = character:WaitForChild("LeftFoot")

		-- Create and add attachments
		local rightHandAttachment = Instance.new("Attachment")
		rightHandAttachment.Name = "RightHandAttachment"
		rightHandAttachment.Parent = rightHand

		local leftHandAttachment = Instance.new("Attachment")
		leftHandAttachment.Name = "LeftHandAttachment"
		leftHandAttachment.Parent = leftHand

		local rightFootAttachment = Instance.new("Attachment")
		rightFootAttachment.Name = "RightFootAttachment"
		rightFootAttachment.Parent = rightFoot

		local leftFootAttachment = Instance.new("Attachment")
		leftFootAttachment.Name = "LeftFootAttachment"
		leftFootAttachment.Parent = leftFoot

		print("Attachments added to", player.Name)
	end

	-- Set up attachments when character spawns/respawns
	player.CharacterAdded:Connect(setupAttachments)

	-- Set up attachments for existing character
	if player.Character then
		setupAttachments(player.Character)
	end
end)

-- Create game instance with states
-- local game = Hangman.new()
-- game:setState(Hangman.gameStates.INTERMISSION)

-- RunService.Heartbeat:Connect(function()
-- 	if game then
-- 		game:update()
-- 	end
-- end)
