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

-- Send input to server (only during matches, keyboard only — mobile handled by FightHUD)
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
	-- Determine projectile properties from ability data
	local speed = 60
	local lifetime = 2
	local coreColor = Color3.fromRGB(255, 200, 50)   -- bright yellow-orange core
	local glowColor = Color3.fromRGB(255, 80, 20)     -- deep orange-red glow
	local trailColor = Color3.fromRGB(255, 60, 10)    -- red-orange trail

	if data.abilityKey and Config.AbilityAttacks[data.abilityKey] then
		local atkData = Config.AbilityAttacks[data.abilityKey]
		speed = atkData.projectileSpeed or speed
		lifetime = atkData.projectileLifetime or lifetime
		if Config.ShopAbilities[data.abilityKey] then
			local c = Config.ShopAbilities[data.abilityKey].color
			glowColor = c
		end
	end

	-- Main fireball core (bright inner sphere)
	local core = Instance.new("Part")
	core.Name = "FireballCore"
	core.Size = Vector3.new(1.8, 1.8, 1.8)
	core.Position = Vector3.new(data.x, data.y + 3, 0)
	core.Anchored = false
	core.CanCollide = false
	core.Material = Enum.Material.Neon
	core.Shape = Enum.PartType.Ball
	core.Color = coreColor
	core.Transparency = 0
	core.Parent = workspace

	-- Outer glow shell (slightly larger, semi-transparent)
	local glow = Instance.new("Part")
	glow.Name = "FireballGlow"
	glow.Size = Vector3.new(3.0, 3.0, 3.0)
	glow.Anchored = false
	glow.CanCollide = false
	glow.Material = Enum.Material.Neon
	glow.Shape = Enum.PartType.Ball
	glow.Color = glowColor
	glow.Transparency = 0.5
	glow.Parent = workspace

	-- Weld glow to core so they move together
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = core
	weld.Part1 = glow
	weld.Parent = core

	-- Velocity on core (glow follows via weld)
	local vel = Instance.new("BodyVelocity")
	vel.Velocity = Vector3.new(data.dir * speed, 0, 0)
	vel.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	vel.Parent = core

	-- Bright point light for fire glow
	local light = Instance.new("PointLight")
	light.Color = glowColor
	light.Range = 18
	light.Brightness = 3
	light.Parent = core

	-- Fire particle emitter (trailing flames)
	local fireEmitter = Instance.new("ParticleEmitter")
	fireEmitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, coreColor),
		ColorSequenceKeypoint.new(0.3, glowColor),
		ColorSequenceKeypoint.new(1, trailColor),
	})
	fireEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 2.0),
		NumberSequenceKeypoint.new(0.5, 1.2),
		NumberSequenceKeypoint.new(1, 0),
	})
	fireEmitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.5, 0.5),
		NumberSequenceKeypoint.new(1, 1),
	})
	fireEmitter.Lifetime = NumberRange.new(0.15, 0.35)
	fireEmitter.Rate = 120
	fireEmitter.Speed = NumberRange.new(2, 8)
	fireEmitter.SpreadAngle = Vector2.new(25, 25)
	fireEmitter.RotSpeed = NumberRange.new(-200, 200)
	fireEmitter.LightEmission = 1
	fireEmitter.LightInfluence = 0
	fireEmitter.Parent = core

	-- Smoke trail behind fireball
	local smokeEmitter = Instance.new("ParticleEmitter")
	smokeEmitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 40, 10)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 30, 30)),
	})
	smokeEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8),
		NumberSequenceKeypoint.new(1, 2.5),
	})
	smokeEmitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	smokeEmitter.Lifetime = NumberRange.new(0.3, 0.6)
	smokeEmitter.Rate = 60
	smokeEmitter.Speed = NumberRange.new(1, 4)
	smokeEmitter.SpreadAngle = Vector2.new(40, 40)
	smokeEmitter.LightEmission = 0.3
	smokeEmitter.Parent = core

	-- Flickering light effect (animate brightness/color)
	task.spawn(function()
		local startTick = tick()
		while core and core.Parent and (tick() - startTick) < lifetime do
			local flicker = 0.7 + math.random() * 0.6
			light.Brightness = 2.5 * flicker
			light.Range = 14 + math.random() * 8
			glow.Transparency = 0.4 + math.random() * 0.2
			core.Size = Vector3.new(1.6 + math.random() * 0.4, 1.6 + math.random() * 0.4, 1.6 + math.random() * 0.4)
			task.wait(0.04)
		end
	end)

	game:GetService("Debris"):AddItem(core, lifetime)
	game:GetService("Debris"):AddItem(glow, lifetime)
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
		-- Don't set inLobby yet — wait for "enterLobby" from server after teleport
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
