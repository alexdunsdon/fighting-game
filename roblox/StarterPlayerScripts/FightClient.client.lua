--[[
	FightClient - Client-side input, camera, and effects for Pixel Brawl
	LOCATION: StarterPlayer > StarterPlayerScripts > FightClient (LocalScript)

	Supports keyboard AND mobile touch input!
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("FightConfig"))
local remotesFolder = ReplicatedStorage:WaitForChild("FightRemotes")
local sendInputEvent = remotesFolder:WaitForChild(Config.Remotes.SEND_INPUT)
local gameStateEvent = remotesFolder:WaitForChild(Config.Remotes.GAME_STATE)
local gameEventEvent = remotesFolder:WaitForChild(Config.Remotes.GAME_EVENT)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- ============================================================
-- STATE
-- ============================================================
local inMatch = false
local inLobby = true
local myIndex = 0
local opponentName = ""
local currentState = nil
local screenShake = 0
local shakeDecay = 0.85

-- Detect mobile
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- ============================================================
-- INPUT STATE (shared between keyboard and touch)
-- ============================================================
local keysHeld = {
	left = false, right = false, jump = false,
	block = false, punch = false, kick = false, special = false,
	ability1 = false, ability2 = false,
}

local InputState = {}
InputState.keysHeld = keysHeld
InputState.isMobile = isMobile

local inputModule = Instance.new("BindableEvent")
inputModule.Name = "FightInputBridge"
inputModule.Parent = player:WaitForChild("PlayerGui")

-- ============================================================
-- KEYBOARD INPUT
-- ============================================================
local keyMap = {
	[Enum.KeyCode.A] = "left",
	[Enum.KeyCode.Left] = "left",
	[Enum.KeyCode.D] = "right",
	[Enum.KeyCode.Right] = "right",
	[Enum.KeyCode.W] = "jump",
	[Enum.KeyCode.Up] = "jump",
	[Enum.KeyCode.Space] = "jump",
	[Enum.KeyCode.S] = "block",
	[Enum.KeyCode.Down] = "block",
	[Enum.KeyCode.F] = "punch",
	[Enum.KeyCode.Q] = "punch",
	[Enum.KeyCode.G] = "kick",
	[Enum.KeyCode.E] = "kick",
	[Enum.KeyCode.H] = "special",
	[Enum.KeyCode.R] = "special",
	[Enum.KeyCode.Z] = "ability1",
	[Enum.KeyCode.One] = "ability1",
	[Enum.KeyCode.X] = "ability2",
	[Enum.KeyCode.Two] = "ability2",
}

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	local action = keyMap[input.KeyCode]
	if action then keysHeld[action] = true end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
	local action = keyMap[input.KeyCode]
	if action then keysHeld[action] = false end
end)

-- Send input to server (only during matches, keyboard only ‚Äî mobile handled by FightHUD)
RunService.Heartbeat:Connect(function()
	if inMatch and not isMobile then
		sendInputEvent:FireServer(keysHeld)
	end
end)

-- ============================================================
-- CAMERA - LOBBY (normal Roblox) / FIGHT (close side view)
-- ============================================================
local CAMERA_Z_OFFSET = 25
local CAMERA_Y_BASE = 6
local cameraSmooth = Vector3.new(0, CAMERA_Y_BASE, CAMERA_Z_OFFSET)

local function updateCamera()
	-- In lobby: use normal Roblox 3rd-person camera
	if inLobby then
		camera.CameraType = Enum.CameraType.Custom
		return
	end

	-- In match: use scriptable fight camera
	camera.CameraType = Enum.CameraType.Scriptable

	if currentState and currentState.fighters and #currentState.fighters >= 2 then
		local f1 = currentState.fighters[1]
		local f2 = currentState.fighters[2]
		local midX = (f1.x + f2.x) / 2
		local midY = math.max((f1.y + f2.y) / 2 + 4, CAMERA_Y_BASE)

		local dist = math.abs(f1.x - f2.x)
		local zoomZ = math.clamp(dist * 0.6 + 12, 16, 40)

		local targetPos = Vector3.new(midX, midY, zoomZ)
		cameraSmooth = cameraSmooth:Lerp(targetPos, 0.08)

		local shakeX, shakeY = 0, 0
		if screenShake > 0.5 then
			shakeX = (math.random() - 0.5) * screenShake * 0.4
			shakeY = (math.random() - 0.5) * screenShake * 0.4
			screenShake = screenShake * shakeDecay
		else
			screenShake = 0
		end

		local finalPos = cameraSmooth + Vector3.new(shakeX, shakeY, 0)
		local lookAt = Vector3.new(midX + shakeX, midY + shakeY - 1, 0)
		camera.CFrame = CFrame.new(finalPos, lookAt)
	else
		camera.CFrame = CFrame.new(Vector3.new(0, 12, 40), Vector3.new(0, 8, 0))
	end
end

RunService.RenderStepped:Connect(updateCamera)

-- ============================================================
-- EFFECTS
-- ============================================================
local function createHitEffect(position, color, count)
	for i = 1, (count or 6) do
		local part = Instance.new("Part")
		part.Size = Vector3.new(0.4, 0.4, 0.4)
		part.Position = Vector3.new(position.x or 0, (position.y or 3) + 3, 0)
		part.Anchored = false
		part.CanCollide = false
		part.Material = Enum.Material.Neon
		part.BrickColor = BrickColor.new(color or "Bright yellow")
		part.Parent = workspace

		local velocity = Instance.new("BodyVelocity")
		velocity.Velocity = Vector3.new(
			(math.random() - 0.5) * 30,
			math.random() * 20 + 10,
			(math.random() - 0.5) * 5
		)
		velocity.MaxForce = Vector3.new(1000, 1000, 1000)
		velocity.Parent = part

		game:GetService("Debris"):AddItem(part, 0.5)
		game:GetService("Debris"):AddItem(velocity, 0.15)
	end
end

local function createProjectileEffect(data)
	local part = Instance.new("Part")
	part.Name = "Projectile"
	part.Size = Vector3.new(2, 1, 1)
	part.Position = Vector3.new(data.x, data.y + 3, 0)
	part.Anchored = false
	part.CanCollide = false
	part.Material = Enum.Material.Neon
	part.Shape = Enum.PartType.Ball
	part.Parent = workspace

	-- Determine projectile properties (ability fireball vs base special)
	local speed = Config.Attacks.special.projectileSpeed
	local lifetime = Config.Attacks.special.projectileLifetime
	local lightColor = Color3.fromRGB(100, 180, 255)
	local partColor = BrickColor.new("Cyan")

	if data.abilityKey and Config.AbilityAttacks[data.abilityKey] then
		local atkData = Config.AbilityAttacks[data.abilityKey]
		speed = atkData.projectileSpeed or speed
		lifetime = atkData.projectileLifetime or lifetime
		if Config.ShopAbilities[data.abilityKey] then
			local c = Config.ShopAbilities[data.abilityKey].color
			lightColor = c
			partColor = BrickColor.new(c)
		end
	end

	part.BrickColor = partColor

	local vel = Instance.new("BodyVelocity")
	vel.Velocity = Vector3.new(data.dir * speed, 0, 0)
	vel.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	vel.Parent = part

	local light = Instance.new("PointLight")
	light.Color = lightColor
	light.Range = 12
	light.Brightness = 2
	light.Parent = part

	game:GetService("Debris"):AddItem(part, lifetime)
end

-- ============================================================
-- SOUND EFFECTS
-- ============================================================
local function createSound(name, volume, pitch)
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.Volume = volume or 0.5
	if pitch then sound.PlaybackSpeed = pitch end
	sound.Parent = player:WaitForChild("PlayerGui")
	return sound
end

local punchSound = createSound("Punch", 0.3, 1.5)
local kickSound = createSound("Kick", 0.4, 0.8)
local hitSound = createSound("Hit", 0.5, 1.0)
local blockSound = createSound("Block", 0.3, 2.0)

-- ============================================================
-- HELPER: enable/disable Roblox controls
-- ============================================================
local function setRobloxControls(enabled)
	local playerModule = player:WaitForChild("PlayerScripts"):FindFirstChild("PlayerModule")
	if playerModule then
		local controls = require(playerModule):GetControls()
		if enabled then controls:Enable() else controls:Disable() end
	end
end

-- ============================================================
-- GAME EVENT HANDLER
-- ============================================================
gameEventEvent.OnClientEvent:Connect(function(eventType, data)
	if eventType == "enterLobby" then
		inMatch = false
		inLobby = true
		currentState = nil
		camera.CameraType = Enum.CameraType.Custom
		setRobloxControls(true)

	elseif eventType == "matchStart" then
		inMatch = true
		inLobby = false
		myIndex = data.playerIndex
		opponentName = data.opponentName
		setRobloxControls(false)

	elseif eventType == "attack" then
		if data.attackType == "punch" then punchSound:Play()
		elseif data.attackType == "kick" then kickSound:Play() end

	elseif eventType == "hit" then
		hitSound:Play()
		screenShake = 6
		createHitEffect(data, "Bright yellow", 8)

	elseif eventType == "blocked" then
		blockSound:Play()
		screenShake = 2
		createHitEffect(data, "Bright blue", 4)

	elseif eventType == "projectile" then
		createProjectileEffect(data)

	elseif eventType == "roundEnd" then
		screenShake = 10

	elseif eventType == "matchEnd" then
		screenShake = 15
		inMatch = false
		-- Don't set inLobby yet ‚Äî wait for "enterLobby" from server after teleport
	end
end)

gameStateEvent.OnClientEvent:Connect(function(state)
	currentState = state
end)

-- Lock Z axis during fights only
RunService.Heartbeat:Connect(function()
	local char = player.Character
	if char and inMatch then
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if hrp and math.abs(hrp.Position.Z) > 1 then
			hrp.CFrame = CFrame.new(hrp.Position.X, hrp.Position.Y, 0) * (hrp.CFrame - hrp.CFrame.Position)
		end
	end
end)

print("[PixelBrawl] Client loaded! Mobile: " .. tostring(isMobile))
