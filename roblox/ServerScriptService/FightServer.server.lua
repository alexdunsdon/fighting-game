--[[
	FightServer - Main server script for Pixel Brawl
	LOCATION: ServerScriptService > FightServer (Script)

	Handles: matchmaking, AI bot, game loop, combat, rounds, state broadcasting,
	lobby, shop, tokens, abilities
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("[PixelBrawl] Server script starting...")

local configModule = ReplicatedStorage:WaitForChild("FightConfig", 10)
if not configModule then
	warn("[PixelBrawl] ERROR: Could not find FightConfig in ReplicatedStorage! Make sure it exists as a ModuleScript.")
	return
end

print("[PixelBrawl] Found FightConfig, loading...")
local ok, Config = pcall(function()
	return require(configModule)
end)
if not ok then
	warn("[PixelBrawl] ERROR: Failed to load FightConfig: " .. tostring(Config))
	return
end
print("[PixelBrawl] FightConfig loaded successfully!")

-- ============================================================
-- CREATE REMOTE EVENTS
-- ============================================================
local remotesFolder = Instance.new("Folder")
remotesFolder.Name = "FightRemotes"
remotesFolder.Parent = ReplicatedStorage

local sendInputEvent = Instance.new("RemoteEvent")
sendInputEvent.Name = Config.Remotes.SEND_INPUT
sendInputEvent.Parent = remotesFolder

local gameStateEvent = Instance.new("RemoteEvent")
gameStateEvent.Name = Config.Remotes.GAME_STATE
gameStateEvent.Parent = remotesFolder

local gameEventEvent = Instance.new("RemoteEvent")
gameEventEvent.Name = Config.Remotes.GAME_EVENT
gameEventEvent.Parent = remotesFolder

local selectDifficultyEvent = Instance.new("RemoteEvent")
selectDifficultyEvent.Name = Config.Remotes.SELECT_DIFFICULTY
selectDifficultyEvent.Parent = remotesFolder

local shopPurchaseEvent = Instance.new("RemoteEvent")
shopPurchaseEvent.Name = Config.Remotes.SHOP_PURCHASE
shopPurchaseEvent.Parent = remotesFolder

local equipAbilityEvent = Instance.new("RemoteEvent")
equipAbilityEvent.Name = Config.Remotes.EQUIP_ABILITY
equipAbilityEvent.Parent = remotesFolder

-- ============================================================
-- CREATE ARENA
-- ============================================================
local function setupArena()
	local arena = workspace:FindFirstChild("Arena")
	if not arena then
		arena = Instance.new("Folder")
		arena.Name = "Arena"
		arena.Parent = workspace

		-- === FLOOR (fighting platform) ===
		local floor = Instance.new("Part")
		floor.Name = "Floor"
		floor.Size = Vector3.new(120, 2, 20)
		floor.Position = Vector3.new(0, -1, 0)
		floor.Anchored = true
		floor.Material = Enum.Material.Concrete
		floor.Color = Color3.fromRGB(50, 45, 45)
		floor.Parent = arena

		-- Floor stripe (center line)
		local centerLine = Instance.new("Part")
		centerLine.Name = "CenterLine"
		centerLine.Size = Vector3.new(1, 0.1, 20)
		centerLine.Position = Vector3.new(0, 0.05, 0)
		centerLine.Anchored = true
		centerLine.CanCollide = false
		centerLine.Material = Enum.Material.Neon
		centerLine.Color = Color3.fromRGB(255, 200, 50)
		centerLine.Parent = arena

		-- Floor edge glow left
		local edgeL = Instance.new("Part")
		edgeL.Name = "EdgeLeft"
		edgeL.Size = Vector3.new(2, 0.15, 20)
		edgeL.Position = Vector3.new(Config.ARENA_MIN_X, 0.07, 0)
		edgeL.Anchored = true
		edgeL.CanCollide = false
		edgeL.Material = Enum.Material.Neon
		edgeL.Color = Color3.fromRGB(220, 40, 40)
		edgeL.Parent = arena

		-- Floor edge glow right
		local edgeR = Instance.new("Part")
		edgeR.Name = "EdgeRight"
		edgeR.Size = Vector3.new(2, 0.15, 20)
		edgeR.Position = Vector3.new(Config.ARENA_MAX_X, 0.07, 0)
		edgeR.Anchored = true
		edgeR.CanCollide = false
		edgeR.Material = Enum.Material.Neon
		edgeR.Color = Color3.fromRGB(220, 40, 40)
		edgeR.Parent = arena

		-- === INVISIBLE WALLS ===
		local wallL = Instance.new("Part")
		wallL.Name = "WallLeft"
		wallL.Size = Vector3.new(2, 40, 20)
		wallL.Position = Vector3.new(Config.ARENA_MIN_X - 1, 19, 0)
		wallL.Anchored = true
		wallL.Transparency = 1
		wallL.CanCollide = true
		wallL.Parent = arena

		local wallR = Instance.new("Part")
		wallR.Name = "WallRight"
		wallR.Size = Vector3.new(2, 40, 20)
		wallR.Position = Vector3.new(Config.ARENA_MAX_X + 1, 19, 0)
		wallR.Anchored = true
		wallR.Transparency = 1
		wallR.CanCollide = true
		wallR.Parent = arena

		-- === BACKGROUND BUILDINGS ===
		local bgFolder = Instance.new("Folder")
		bgFolder.Name = "Background"
		bgFolder.Parent = arena

		local buildingData = {
			{ x = -55, w = 18, h = 45, color = Color3.fromRGB(35, 35, 50) },
			{ x = -35, w = 14, h = 60, color = Color3.fromRGB(30, 30, 45) },
			{ x = -18, w = 20, h = 38, color = Color3.fromRGB(40, 35, 50) },
			{ x = 0,   w = 16, h = 55, color = Color3.fromRGB(32, 32, 48) },
			{ x = 18,  w = 22, h = 42, color = Color3.fromRGB(38, 35, 52) },
			{ x = 38,  w = 14, h = 65, color = Color3.fromRGB(28, 28, 42) },
			{ x = 55,  w = 18, h = 35, color = Color3.fromRGB(36, 34, 48) },
		}

		for i, bd in ipairs(buildingData) do
			local building = Instance.new("Part")
			building.Name = "Building" .. i
			building.Size = Vector3.new(bd.w, bd.h, 6)
			building.Position = Vector3.new(bd.x, bd.h / 2, -25)
			building.Anchored = true
			building.CanCollide = false
			building.Material = Enum.Material.SmoothPlastic
			building.Color = bd.color
			building.Parent = bgFolder

			for row = 1, math.floor(bd.h / 6) do
				for col = 1, math.floor(bd.w / 5) do
					if math.random() > 0.35 then
						local window = Instance.new("Part")
						window.Name = "Window"
						window.Size = Vector3.new(1.5, 1.5, 0.2)
						window.Position = Vector3.new(
							bd.x - bd.w/2 + col * (bd.w / (math.floor(bd.w/5) + 1)),
							row * 5.5,
							-22
						)
						window.Anchored = true
						window.CanCollide = false
						window.Material = Enum.Material.Neon
						local windowColors = {
							Color3.fromRGB(255, 220, 100),
							Color3.fromRGB(100, 180, 255),
							Color3.fromRGB(255, 150, 80),
							Color3.fromRGB(200, 200, 255),
						}
						window.Color = windowColors[math.random(1, #windowColors)]
						window.Parent = bgFolder
					end
				end
			end
		end

		-- === NEON SIGNS ===
		local sign1 = Instance.new("Part")
		sign1.Name = "NeonSign1"
		sign1.Size = Vector3.new(12, 4, 0.5)
		sign1.Position = Vector3.new(-35, 30, -20)
		sign1.Anchored = true
		sign1.CanCollide = false
		sign1.Material = Enum.Material.Neon
		sign1.Color = Color3.fromRGB(255, 50, 100)
		sign1.Parent = bgFolder

		local signText1 = Instance.new("SurfaceGui")
		signText1.Face = Enum.NormalId.Front
		signText1.Parent = sign1
		local signLabel1 = Instance.new("TextLabel")
		signLabel1.Size = UDim2.new(1, 0, 1, 0)
		signLabel1.BackgroundTransparency = 1
		signLabel1.Text = "FIGHT!"
		signLabel1.TextColor3 = Color3.fromRGB(255, 255, 255)
		signLabel1.TextScaled = true
		signLabel1.Font = Enum.Font.GothamBlack
		signLabel1.Parent = signText1

		local sign2 = Instance.new("Part")
		sign2.Name = "NeonSign2"
		sign2.Size = Vector3.new(14, 3, 0.5)
		sign2.Position = Vector3.new(38, 35, -20)
		sign2.Anchored = true
		sign2.CanCollide = false
		sign2.Material = Enum.Material.Neon
		sign2.Color = Color3.fromRGB(50, 150, 255)
		sign2.Parent = bgFolder

		local signText2 = Instance.new("SurfaceGui")
		signText2.Face = Enum.NormalId.Front
		signText2.Parent = sign2
		local signLabel2 = Instance.new("TextLabel")
		signLabel2.Size = UDim2.new(1, 0, 1, 0)
		signLabel2.BackgroundTransparency = 1
		signLabel2.Text = "PIXEL BRAWL"
		signLabel2.TextColor3 = Color3.fromRGB(255, 255, 255)
		signLabel2.TextScaled = true
		signLabel2.Font = Enum.Font.GothamBlack
		signLabel2.Parent = signText2

		-- === GROUND DETAILS ===
		for i = -4, 4 do
			local strip = Instance.new("Part")
			strip.Name = "FloorStrip"
			strip.Size = Vector3.new(8, 0.1, 20)
			strip.Position = Vector3.new(i * 12, 0.06, 0)
			strip.Anchored = true
			strip.CanCollide = false
			strip.Material = Enum.Material.SmoothPlastic
			strip.Color = Color3.fromRGB(60, 55, 55)
			strip.Parent = bgFolder
		end

		-- === ARENA LIGHTS ===
		local light1 = Instance.new("Part")
		light1.Name = "ArenaLight1"
		light1.Size = Vector3.new(1, 1, 1)
		light1.Position = Vector3.new(-20, 35, 10)
		light1.Anchored = true
		light1.CanCollide = false
		light1.Transparency = 1
		light1.Parent = bgFolder

		local spot1 = Instance.new("SpotLight")
		spot1.Face = Enum.NormalId.Bottom
		spot1.Angle = 60
		spot1.Range = 50
		spot1.Brightness = 3
		spot1.Color = Color3.fromRGB(255, 230, 200)
		spot1.Parent = light1

		local light2 = Instance.new("Part")
		light2.Name = "ArenaLight2"
		light2.Size = Vector3.new(1, 1, 1)
		light2.Position = Vector3.new(20, 35, 10)
		light2.Anchored = true
		light2.CanCollide = false
		light2.Transparency = 1
		light2.Parent = bgFolder

		local spot2 = Instance.new("SpotLight")
		spot2.Face = Enum.NormalId.Bottom
		spot2.Angle = 60
		spot2.Range = 50
		spot2.Brightness = 3
		spot2.Color = Color3.fromRGB(255, 230, 200)
		spot2.Parent = light2

		-- === SET EVENING ATMOSPHERE ===
		local lighting = game:GetService("Lighting")
		lighting.ClockTime = 15
		lighting.Brightness = 3
		lighting.Ambient = Color3.fromRGB(170, 160, 180)
		lighting.OutdoorAmbient = Color3.fromRGB(150, 140, 160)
		lighting.FogEnd = 1000
		lighting.FogColor = Color3.fromRGB(180, 80, 80)

		local existingAtmo = lighting:FindFirstChildOfClass("Atmosphere")
		if not existingAtmo then
			local atmo = Instance.new("Atmosphere")
			atmo.Density = 0.2
			atmo.Offset = 0.5
			atmo.Color = Color3.fromRGB(200, 120, 120)
			atmo.Decay = Color3.fromRGB(180, 80, 80)
			atmo.Glare = 0.1
			atmo.Haze = 1.5
			atmo.Parent = lighting
		end

		local existingBloom = lighting:FindFirstChildOfClass("BloomEffect")
		if not existingBloom then
			local bloom = Instance.new("BloomEffect")
			bloom.Intensity = 0.6
			bloom.Size = 20
			bloom.Threshold = 0.9
			bloom.Parent = lighting
		end

		local existingCC = lighting:FindFirstChildOfClass("ColorCorrectionEffect")
		if not existingCC then
			local cc = Instance.new("ColorCorrectionEffect")
			cc.Brightness = 0.05
			cc.Contrast = 0.1
			cc.Saturation = 0.15
			cc.TintColor = Color3.fromRGB(255, 210, 210)
			cc.Parent = lighting
		end
	end
	return arena
end

local arena = setupArena()

-- ============================================================
-- CREATE LOBBY (bigger dojo at Z=300)
-- ============================================================
local function setupLobby()
	local lobby = Instance.new("Folder")
	lobby.Name = "Lobby"
	lobby.Parent = workspace

	local LZ = 300 -- lobby center Z

	-- Floor (dark wood dojo) — BIGGER: 120x100
	local floor = Instance.new("Part")
	floor.Name = "LobbyFloor"
	floor.Size = Vector3.new(120, 2, 100)
	floor.Position = Vector3.new(0, -1, LZ)
	floor.Anchored = true
	floor.Material = Enum.Material.WoodPlanks
	floor.Color = Color3.fromRGB(60, 40, 25)
	floor.Parent = lobby

	-- Tatami strips
	for i = -5, 5 do
		local strip = Instance.new("Part")
		strip.Size = Vector3.new(10, 0.05, 96)
		strip.Position = Vector3.new(i * 10, 0.03, LZ)
		strip.Anchored = true
		strip.CanCollide = false
		strip.Material = Enum.Material.Fabric
		strip.Color = (i % 2 == 0) and Color3.fromRGB(75, 55, 30) or Color3.fromRGB(55, 38, 20)
		strip.Parent = lobby
	end

	-- Walls — expanded
	local function makeWall(name, size, pos)
		local w = Instance.new("Part")
		w.Name = name
		w.Size = size
		w.Position = pos
		w.Anchored = true
		w.Material = Enum.Material.Wood
		w.Color = Color3.fromRGB(45, 35, 30)
		w.Parent = lobby
		return w
	end
	makeWall("BackWall", Vector3.new(120, 20, 2), Vector3.new(0, 9, LZ + 51))
	makeWall("LeftWall", Vector3.new(2, 20, 102), Vector3.new(-61, 9, LZ))
	makeWall("RightWall", Vector3.new(2, 20, 102), Vector3.new(61, 9, LZ))

	-- Invisible front boundary
	local frontWall = Instance.new("Part")
	frontWall.Size = Vector3.new(120, 20, 2)
	frontWall.Position = Vector3.new(0, 9, LZ - 51)
	frontWall.Anchored = true
	frontWall.Transparency = 1
	frontWall.Parent = lobby

	-- Roof with skylight
	local roof = Instance.new("Part")
	roof.Size = Vector3.new(124, 1, 104)
	roof.Position = Vector3.new(0, 19.5, LZ)
	roof.Anchored = true
	roof.Material = Enum.Material.Wood
	roof.Color = Color3.fromRGB(35, 25, 18)
	roof.Parent = lobby

	-- Skylight (neon center)
	local skylight = Instance.new("Part")
	skylight.Size = Vector3.new(30, 0.5, 30)
	skylight.Position = Vector3.new(0, 19.8, LZ)
	skylight.Anchored = true
	skylight.CanCollide = false
	skylight.Material = Enum.Material.Neon
	skylight.Color = Color3.fromRGB(200, 180, 140)
	skylight.Parent = lobby

	-- PIXEL BRAWL sign on back wall
	local signPart = Instance.new("Part")
	signPart.Size = Vector3.new(30, 6, 0.5)
	signPart.Position = Vector3.new(0, 14, LZ + 49.5)
	signPart.Anchored = true
	signPart.CanCollide = false
	signPart.Material = Enum.Material.SmoothPlastic
	signPart.Color = Color3.fromRGB(15, 15, 25)
	signPart.Parent = lobby
	local function makeMainSign(face)
		local sGui = Instance.new("SurfaceGui")
		sGui.Face = face
		sGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sGui.PixelsPerStud = 50
		sGui.Parent = signPart
		local sBg = Instance.new("Frame")
		sBg.Size = UDim2.new(1, 0, 1, 0)
		sBg.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
		sBg.BorderSizePixel = 0
		sBg.Parent = sGui
		local sText = Instance.new("TextLabel")
		sText.Size = UDim2.new(1, 0, 1, 0)
		sText.BackgroundTransparency = 1
		sText.Text = "PIXEL BRAWL"
		sText.TextColor3 = Color3.fromRGB(255, 60, 30)
		sText.TextScaled = true
		sText.Font = Enum.Font.GothamBlack
		sText.TextStrokeTransparency = 0
		sText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		sText.Parent = sBg
	end
	makeMainSign(Enum.NormalId.Front)
	makeMainSign(Enum.NormalId.Back)
	local signGlow = Instance.new("PointLight")
	signGlow.Color = Color3.fromRGB(255, 60, 30)
	signGlow.Brightness = 2
	signGlow.Range = 20
	signGlow.Parent = signPart

	-- === PORTAL BUILDER ===
	local function makePortal(name, posX, posZ, color, labelText)
		local portalFolder = Instance.new("Folder")
		portalFolder.Name = name
		portalFolder.Parent = lobby

		local pad = Instance.new("Part")
		pad.Size = Vector3.new(12, 0.3, 12)
		pad.Position = Vector3.new(posX, 0.15, posZ)
		pad.Anchored = true
		pad.CanCollide = false
		pad.Material = Enum.Material.Neon
		pad.Color = color
		pad.Parent = portalFolder

		local lPillar = Instance.new("Part")
		lPillar.Size = Vector3.new(1, 10, 1)
		lPillar.Position = Vector3.new(posX - 6, 5, posZ)
		lPillar.Anchored = true
		lPillar.Material = Enum.Material.SmoothPlastic
		lPillar.Color = color
		lPillar.Parent = portalFolder

		local rPillar = Instance.new("Part")
		rPillar.Size = Vector3.new(1, 10, 1)
		rPillar.Position = Vector3.new(posX + 6, 5, posZ)
		rPillar.Anchored = true
		rPillar.Material = Enum.Material.SmoothPlastic
		rPillar.Color = color
		rPillar.Parent = portalFolder

		local topBeam = Instance.new("Part")
		topBeam.Size = Vector3.new(14, 1, 1.5)
		topBeam.Position = Vector3.new(posX, 10.5, posZ)
		topBeam.Anchored = true
		topBeam.Material = Enum.Material.SmoothPlastic
		topBeam.Color = color
		topBeam.Parent = portalFolder

		local sPart = Instance.new("Part")
		sPart.Size = Vector3.new(12, 4, 0.5)
		sPart.Position = Vector3.new(posX, 13.5, posZ)
		sPart.Anchored = true
		sPart.CanCollide = false
		sPart.Material = Enum.Material.SmoothPlastic
		sPart.Color = Color3.fromRGB(20, 20, 30)
		sPart.Parent = portalFolder

		local function makeSignGui(face)
			local sGui = Instance.new("SurfaceGui")
			sGui.Face = face
			sGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			sGui.PixelsPerStud = 50
			sGui.Parent = sPart

			local bg = Instance.new("Frame")
			bg.Size = UDim2.new(1, 0, 1, 0)
			bg.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
			bg.BorderSizePixel = 0
			bg.Parent = sGui

			local topLine = Instance.new("Frame")
			topLine.Size = UDim2.new(1, 0, 0, 6)
			topLine.Position = UDim2.new(0, 0, 0, 0)
			topLine.BackgroundColor3 = color
			topLine.BorderSizePixel = 0
			topLine.Parent = bg

			local botLine = Instance.new("Frame")
			botLine.Size = UDim2.new(1, 0, 0, 6)
			botLine.Position = UDim2.new(0, 0, 1, -6)
			botLine.BackgroundColor3 = color
			botLine.BorderSizePixel = 0
			botLine.Parent = bg

			local sText = Instance.new("TextLabel")
			sText.Size = UDim2.new(1, 0, 1, 0)
			sText.BackgroundTransparency = 1
			sText.Text = labelText
			sText.TextColor3 = Color3.fromRGB(255, 255, 255)
			sText.TextScaled = true
			sText.Font = Enum.Font.GothamBlack
			sText.TextStrokeTransparency = 0
			sText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
			sText.Parent = bg
		end

		makeSignGui(Enum.NormalId.Front)
		makeSignGui(Enum.NormalId.Back)

		local padLight = Instance.new("PointLight")
		padLight.Color = color
		padLight.Brightness = 3
		padLight.Range = 16
		padLight.Parent = pad

		return portalFolder
	end

	-- Portals wider apart
	makePortal("VSBotPortal", -30, LZ - 15, Color3.fromRGB(220, 40, 40), "VS BOT")
	makePortal("VSFriendPortal", 30, LZ - 15, Color3.fromRGB(130, 50, 200), "VS FRIEND")
	-- SHOP portal (gold, center-front)
	makePortal("ShopPortal", 0, LZ - 35, Color3.fromRGB(255, 200, 50), "SHOP")

	-- Lanterns (6 around the bigger room)
	local lanternPositions = {
		Vector3.new(-50, 6, LZ + 40),
		Vector3.new(50, 6, LZ + 40),
		Vector3.new(-50, 6, LZ),
		Vector3.new(50, 6, LZ),
		Vector3.new(-50, 6, LZ - 40),
		Vector3.new(50, 6, LZ - 40),
	}
	for _, lpos in ipairs(lanternPositions) do
		local lantern = Instance.new("Part")
		lantern.Size = Vector3.new(1.5, 2, 1.5)
		lantern.Position = lpos
		lantern.Anchored = true
		lantern.CanCollide = false
		lantern.Material = Enum.Material.Neon
		lantern.Color = Color3.fromRGB(255, 160, 50)
		lantern.Shape = Enum.PartType.Cylinder
		lantern.Parent = lobby
		local ll = Instance.new("PointLight")
		ll.Color = Color3.fromRGB(255, 160, 50)
		ll.Brightness = 2
		ll.Range = 25
		ll.Parent = lantern
	end

	-- Weapon rack on back wall
	local rack = Instance.new("Part")
	rack.Size = Vector3.new(15, 0.5, 0.5)
	rack.Position = Vector3.new(-30, 8, LZ + 49.5)
	rack.Anchored = true
	rack.Material = Enum.Material.Wood
	rack.Color = Color3.fromRGB(80, 50, 30)
	rack.Parent = lobby
	for i = -2, 2 do
		local staff = Instance.new("Part")
		staff.Size = Vector3.new(0.3, 6, 0.3)
		staff.Position = Vector3.new(-30 + i * 3, 8, LZ + 49.3)
		staff.Anchored = true
		staff.CanCollide = false
		staff.Material = Enum.Material.Wood
		staff.Color = Color3.fromRGB(120, 80, 40)
		staff.Rotation = Vector3.new(0, 0, 15 + i * 5)
		staff.Parent = lobby
	end

	return lobby
end

local lobby = setupLobby()

-- ============================================================
-- PLAYER STATE TRACKING
-- ============================================================
local playerState = {}      -- [UserId] = "lobby" | "inMatch" | "queued"
local zoneCooldown = {}      -- [UserId] = tick() of last zone trigger
local playerTokens = {}      -- [UserId] = number (battle tokens)
local playerInventory = {}   -- [UserId] = { ["dashPunch"] = true, ... }
local playerEquipped = {}    -- [UserId] = { [1] = "dashPunch" or nil, [2] = nil }

local function teleportToLobby(player)
	playerState[player.UserId] = Config.PlayerStates.LOBBY
	local char = player.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then
		player:LoadCharacter()
		return
	end
	char.HumanoidRootPart.CFrame = CFrame.new(Config.LOBBY_SPAWN)
	char.HumanoidRootPart.Velocity = Vector3.new(0, 0, 0)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.MaxHealth = 100
		hum.Health = 100
		hum.WalkSpeed = 16
		hum.JumpPower = 50
	end
end

-- Send token/inventory/equip state to a player
local function sendPlayerData(player)
	local uid = player.UserId
	gameEventEvent:FireClient(player, "tokenUpdate", {
		tokens = playerTokens[uid] or 0,
	})

	-- Convert inventory dict { dashPunch = true } to array { "dashPunch" }
	local invArray = {}
	if playerInventory[uid] then
		for key, owned in pairs(playerInventory[uid]) do
			if owned then
				table.insert(invArray, key)
			end
		end
	end

	local eq = playerEquipped[uid] or {}
	gameEventEvent:FireClient(player, "inventoryUpdate", {
		inventory = invArray,
		equipped1 = eq[1],
		equipped2 = eq[2],
	})
end

-- ============================================================
-- AI BOT SYSTEM
-- ============================================================
local AI_BOT = { Name = "CPU Fighter", UserId = -1, Parent = true, IsBot = true }

local playerDifficulty = {}

local AI_SETTINGS = {
	easy = { attackChance = 0.03, blockChance = 0.15, specialChance = 0.01, reactionDist = 10 },
	medium = { attackChance = 0.08, blockChance = 0.35, specialChance = 0.03, reactionDist = 15 },
	hard = { attackChance = 0.14, blockChance = 0.55, specialChance = 0.06, reactionDist = 20 },
}

local function createBotModel(spawnX)
	local model = Instance.new("Model")
	model.Name = "CPU Fighter"

	local function makePart(name, size, pos, color, material, shape)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Position = pos
		p.Anchored = true
		p.CanCollide = false
		p.Material = material or Enum.Material.SmoothPlastic
		p.Color = color
		if shape then p.Shape = shape end
		p.Parent = model
		return p
	end

	local torso = makePart("HumanoidRootPart",
		Vector3.new(2.2, 2.4, 1.2),
		Vector3.new(spawnX, 4.2, 0),
		Color3.fromRGB(25, 25, 35), Enum.Material.Fabric)
	model.PrimaryPart = torso

	local chest = makePart("Chest",
		Vector3.new(0.8, 0.6, 0.1),
		Vector3.new(spawnX, 5.0, -0.56),
		Color3.fromRGB(180, 130, 90), Enum.Material.SmoothPlastic)

	local belt = makePart("Belt",
		Vector3.new(2.3, 0.3, 1.3),
		Vector3.new(spawnX, 2.9, 0),
		Color3.fromRGB(180, 20, 20), Enum.Material.Fabric)

	local head = makePart("Head",
		Vector3.new(1.6, 1.6, 1.6),
		Vector3.new(spawnX, 6.3, 0),
		Color3.fromRGB(180, 130, 90), Enum.Material.SmoothPlastic, Enum.PartType.Ball)

	local headband = makePart("Headband",
		Vector3.new(1.8, 0.25, 1.8),
		Vector3.new(spawnX, 6.5, 0),
		Color3.fromRGB(200, 20, 20), Enum.Material.Fabric)

	local hbTail = makePart("HeadbandTail",
		Vector3.new(0.2, 0.15, 1.2),
		Vector3.new(spawnX - 0.8, 6.4, -0.6),
		Color3.fromRGB(200, 20, 20), Enum.Material.Fabric)

	local lEye = makePart("LeftEye",
		Vector3.new(0.2, 0.15, 0.1),
		Vector3.new(spawnX - 0.3, 6.4, -0.75),
		Color3.fromRGB(255, 255, 255), Enum.Material.Neon)
	local rEye = makePart("RightEye",
		Vector3.new(0.2, 0.15, 0.1),
		Vector3.new(spawnX + 0.3, 6.4, -0.75),
		Color3.fromRGB(255, 255, 255), Enum.Material.Neon)

	local lPupil = makePart("LeftPupil",
		Vector3.new(0.1, 0.1, 0.1),
		Vector3.new(spawnX - 0.3, 6.4, -0.81),
		Color3.fromRGB(20, 20, 20), Enum.Material.SmoothPlastic)
	local rPupil = makePart("RightPupil",
		Vector3.new(0.1, 0.1, 0.1),
		Vector3.new(spawnX + 0.3, 6.4, -0.81),
		Color3.fromRGB(20, 20, 20), Enum.Material.SmoothPlastic)

	local lArm = makePart("LeftArm",
		Vector3.new(0.9, 2.2, 0.9),
		Vector3.new(spawnX - 1.55, 4.2, 0),
		Color3.fromRGB(25, 25, 35), Enum.Material.Fabric)
	local rArm = makePart("RightArm",
		Vector3.new(0.9, 2.2, 0.9),
		Vector3.new(spawnX + 1.55, 4.2, 0),
		Color3.fromRGB(25, 25, 35), Enum.Material.Fabric)

	local lFist = makePart("LeftFist",
		Vector3.new(0.6, 0.6, 0.6),
		Vector3.new(spawnX - 1.55, 2.9, 0),
		Color3.fromRGB(255, 80, 30), Enum.Material.Neon)
	local rFist = makePart("RightFist",
		Vector3.new(0.6, 0.6, 0.6),
		Vector3.new(spawnX + 1.55, 2.9, 0),
		Color3.fromRGB(255, 80, 30), Enum.Material.Neon)

	local lLeg = makePart("LeftLeg",
		Vector3.new(0.9, 2.2, 0.9),
		Vector3.new(spawnX - 0.55, 1.1, 0),
		Color3.fromRGB(30, 30, 50), Enum.Material.Fabric)
	local rLeg = makePart("RightLeg",
		Vector3.new(0.9, 2.2, 0.9),
		Vector3.new(spawnX + 0.55, 1.1, 0),
		Color3.fromRGB(30, 30, 50), Enum.Material.Fabric)

	local lShoe = makePart("LeftShoe",
		Vector3.new(1.0, 0.5, 1.3),
		Vector3.new(spawnX - 0.55, 0.25, 0),
		Color3.fromRGB(15, 15, 15), Enum.Material.SmoothPlastic)
	local rShoe = makePart("RightShoe",
		Vector3.new(1.0, 0.5, 1.3),
		Vector3.new(spawnX + 0.55, 0.25, 0),
		Color3.fromRGB(15, 15, 15), Enum.Material.SmoothPlastic)

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 120, 0, 40)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.Adornee = head
	billboard.Parent = head

	local nameTag = Instance.new("TextLabel")
	nameTag.Size = UDim2.new(1, 0, 1, 0)
	nameTag.BackgroundTransparency = 1
	nameTag.Text = "CPU FIGHTER"
	nameTag.TextColor3 = Color3.fromRGB(255, 80, 30)
	nameTag.TextStrokeTransparency = 0
	nameTag.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	nameTag.TextSize = 16
	nameTag.Font = Enum.Font.GothamBlack
	nameTag.Parent = billboard

	local lGlow = Instance.new("PointLight")
	lGlow.Color = Color3.fromRGB(255, 80, 30)
	lGlow.Brightness = 2
	lGlow.Range = 4
	lGlow.Parent = lFist
	local rGlow = Instance.new("PointLight")
	rGlow.Color = Color3.fromRGB(255, 80, 30)
	rGlow.Brightness = 2
	rGlow.Range = 4
	rGlow.Parent = rFist

	model.Parent = workspace
	return model
end

local function updateBotModel(model, fighter)
	if not model or not model.Parent then return end
	local x = fighter.x
	local yOff = fighter.y - Config.GROUND_Y
	local dir = fighter.facingRight and 1 or -1

	local layout = {
		{ "HumanoidRootPart", 0, 4.2 },
		{ "Chest", 0, 5.0 },
		{ "Belt", 0, 2.9 },
		{ "Head", 0, 6.3 },
		{ "Headband", 0, 6.5 },
		{ "HeadbandTail", -0.8, 6.4 },
		{ "LeftEye", -0.3, 6.4 },
		{ "RightEye", 0.3, 6.4 },
		{ "LeftPupil", -0.3, 6.4 },
		{ "RightPupil", 0.3, 6.4 },
		{ "LeftArm", -1.55, 4.2 },
		{ "RightArm", 1.55, 4.2 },
		{ "LeftFist", -1.55, 2.9 },
		{ "RightFist", 1.55, 2.9 },
		{ "LeftLeg", -0.55, 1.1 },
		{ "RightLeg", 0.55, 1.1 },
		{ "LeftShoe", -0.55, 0.25 },
		{ "RightShoe", 0.55, 0.25 },
	}

	local armPunch = 0
	local fistPunch = 0
	local legKick = 0
	local shoeKick = 0
	local crouch = 0
	local breathe = math.sin(tick() * 3) * 0.05

	local st = fighter.state
	if st == "punch" or st == "ability1" or st == "ability2" then
		armPunch = dir * 2.0
		fistPunch = dir * 2.5
	elseif st == "kick" then
		legKick = dir * 2.5
		shoeKick = dir * 3.0
	elseif st == "block" then
		crouch = 0.6
		armPunch = -dir * 0.5
	elseif st == "special" then
		armPunch = dir * 1.5
		fistPunch = dir * 2.0
	end

	if st == "hitstun" then
		local flash = math.sin(tick() * 30) > 0
		for _, child in ipairs(model:GetChildren()) do
			if child:IsA("BasePart") and child.Name ~= "LeftEye" and child.Name ~= "RightEye"
				and child.Name ~= "LeftPupil" and child.Name ~= "RightPupil" then
				if flash then
					child.Color = Color3.fromRGB(255, 200, 200)
				else
					child.Color = Color3.fromRGB(255, 60, 60)
				end
			end
		end
	elseif st == "ko" then
		for _, child in ipairs(model:GetChildren()) do
			if child:IsA("BasePart") then
				child.Color = Color3.fromRGB(80, 80, 90)
				child.Position = Vector3.new(x + (math.random() - 0.5) * 2, 0.3, 0)
			end
		end
		for _, child in ipairs(model:GetDescendants()) do
			if child:IsA("PointLight") then child.Enabled = false end
		end
		return
	else
		local colorMap = {
			HumanoidRootPart = Color3.fromRGB(25, 25, 35),
			Chest = Color3.fromRGB(180, 130, 90),
			Belt = Color3.fromRGB(180, 20, 20),
			Head = Color3.fromRGB(180, 130, 90),
			Headband = Color3.fromRGB(200, 20, 20),
			HeadbandTail = Color3.fromRGB(200, 20, 20),
			LeftEye = Color3.fromRGB(255, 255, 255),
			RightEye = Color3.fromRGB(255, 255, 255),
			LeftPupil = Color3.fromRGB(20, 20, 20),
			RightPupil = Color3.fromRGB(20, 20, 20),
			LeftArm = Color3.fromRGB(25, 25, 35),
			RightArm = Color3.fromRGB(25, 25, 35),
			LeftFist = Color3.fromRGB(255, 80, 30),
			RightFist = Color3.fromRGB(255, 80, 30),
			LeftLeg = Color3.fromRGB(30, 30, 50),
			RightLeg = Color3.fromRGB(30, 30, 50),
			LeftShoe = Color3.fromRGB(15, 15, 15),
			RightShoe = Color3.fromRGB(15, 15, 15),
		}
		for _, child in ipairs(model:GetChildren()) do
			if child:IsA("BasePart") and colorMap[child.Name] then
				child.Color = colorMap[child.Name]
			end
		end
		for _, child in ipairs(model:GetDescendants()) do
			if child:IsA("PointLight") then child.Enabled = true end
		end
		if st == "punch" or st == "special" or st == "ability1" or st == "ability2" then
			for _, child in ipairs(model:GetDescendants()) do
				if child:IsA("PointLight") then
					child.Brightness = 5
					child.Range = 8
				end
			end
		else
			for _, child in ipairs(model:GetDescendants()) do
				if child:IsA("PointLight") then
					child.Brightness = 2
					child.Range = 4
				end
			end
		end
	end

	for _, info in ipairs(layout) do
		local part = model:FindFirstChild(info[1])
		if part then
			local px = x + info[2]
			local py = yOff + info[3] - crouch + breathe

			if info[1] == "RightArm" then px = px + armPunch end
			if info[1] == "RightFist" then px = px + fistPunch end
			if st == "block" and (info[1] == "LeftArm" or info[1] == "LeftFist") then
				px = px - armPunch
			end
			if info[1] == "RightLeg" then px = px + legKick end
			if info[1] == "RightShoe" then px = px + shoeKick end

			if info[1] == "HeadbandTail" then
				px = x + (dir * -0.8)
			end

			part.Position = Vector3.new(px, py, 0)
		end
	end
end

local function destroyBotModel(model)
	if model and model.Parent then
		model:Destroy()
	end
end

local function createAIInput(self, opponent, difficulty)
	local input = {
		left = false, right = false, jump = false,
		block = false, punch = false, kick = false, special = false,
		ability1 = false, ability2 = false,
	}
	if not opponent then return input end

	local settings = AI_SETTINGS[difficulty or "medium"]
	local dist = math.abs(self.x - opponent.x)
	local dir = self.x < opponent.x and 1 or -1
	local goRight = dir > 0

	if (opponent.state == "punch" or opponent.state == "kick" or opponent.state == "special"
		or opponent.state == "ability1" or opponent.state == "ability2") and dist < settings.reactionDist then
		if math.random() < settings.blockChance then
			input.block = true
			return input
		end
	end

	if dist > 25 then
		if math.random() < settings.specialChance then
			input.special = true
		else
			if goRight then input.right = true else input.left = true end
		end
	elseif dist > 10 then
		local roll = math.random()
		if roll < settings.attackChance * 0.5 then
			input.kick = true
		elseif roll < settings.attackChance * 0.7 then
			input.punch = true
		elseif roll < settings.attackChance then
			input.jump = true
			if goRight then input.right = true else input.left = true end
		else
			if goRight then input.right = true else input.left = true end
		end
	else
		local roll = math.random()
		if roll < settings.attackChance then
			input.punch = true
		elseif roll < settings.attackChance * 1.8 then
			input.kick = true
		elseif roll < settings.attackChance * 2 then
			input.special = true
		elseif roll < settings.attackChance * 2.2 then
			input.block = true
		elseif roll < settings.attackChance * 2.5 then
			if goRight then input.left = true else input.right = true end
		elseif roll < settings.attackChance * 2.7 then
			input.jump = true
		end
	end

	return input
end

-- ============================================================
-- MATCHMAKING & MATCH STATE
-- ============================================================
local activeMatches = {}
local pvpQueue = {}

local function createFighterState(player, spawnX, facingRight)
	-- Copy equipped abilities from player data
	local equipped = { nil, nil }
	if player ~= AI_BOT and playerEquipped[player.UserId] then
		equipped = { playerEquipped[player.UserId][1], playerEquipped[player.UserId][2] }
	end

	return {
		player = player,
		x = spawnX,
		y = Config.GROUND_Y,
		vx = 0,
		vy = 0,
		health = Config.MAX_HEALTH,
		state = Config.States.IDLE,
		stateTimer = 0,
		facingRight = facingRight,
		attackHit = false,
		roundWins = 0,
		input = {
			left = false, right = false, jump = false,
			block = false, punch = false, kick = false, special = false,
			ability1 = false, ability2 = false,
		},
		prevInput = {},
		onGround = true,
		isBot = (player == AI_BOT),
		equippedAbilities = equipped,
	}
end

local function getMatchForPlayer(player)
	for matchId, match in pairs(activeMatches) do
		for i, f in ipairs(match.fighters) do
			if f.player == player then
				return match, i
			end
		end
	end
	return nil, nil
end

local function isInMatch(player)
	return getMatchForPlayer(player) ~= nil
end

local function fireToFighters(match, eventName, data)
	for _, f in ipairs(match.fighters) do
		if not f.isBot and f.player.Parent then
			gameEventEvent:FireClient(f.player, eventName, data)
		end
	end
end

-- Forward declaration
local startMatchWithAI

-- ============================================================
-- GET ATTACK DATA (resolves ability or base attack)
-- ============================================================
local function getAttackData(fighter, stateName)
	if stateName == Config.States.ABILITY1 then
		local abilityKey = fighter.equippedAbilities[1]
		if abilityKey and Config.AbilityAttacks[abilityKey] then
			return Config.AbilityAttacks[abilityKey], abilityKey
		end
		return Config.Attacks.punch, "punch" -- fallback
	elseif stateName == Config.States.ABILITY2 then
		local abilityKey = fighter.equippedAbilities[2]
		if abilityKey and Config.AbilityAttacks[abilityKey] then
			return Config.AbilityAttacks[abilityKey], abilityKey
		end
		return Config.Attacks.punch, "punch" -- fallback
	elseif Config.Attacks[stateName] then
		return Config.Attacks[stateName], stateName
	end
	return nil, nil
end

-- ============================================================
-- END MATCH (with token rewards)
-- ============================================================
local function endMatch(match)
	local winner = match.fighters[1].roundWins >= Config.ROUNDS_TO_WIN and 1 or 2
	local winnerName = match.fighters[winner].player.Name

	fireToFighters(match, "matchEnd", {
		winner = winner,
		winnerName = winnerName,
	})

	match.phase = Config.Phases.MATCH_END
	match.phaseTimer = Config.MATCH_END_DELAY

	-- Award tokens for bot wins ONLY
	if match.botModel then
		-- Find the human player
		for _, f in ipairs(match.fighters) do
			if not f.isBot and f.player.Parent then
				-- Did the human win?
				if f.roundWins >= Config.ROUNDS_TO_WIN then
					local diff = playerDifficulty[f.player.UserId] or "medium"
					local reward = Config.TOKEN_REWARDS[diff] or 10
					playerTokens[f.player.UserId] = (playerTokens[f.player.UserId] or 0) + reward
					print("[PixelBrawl] " .. f.player.Name .. " won! +" .. reward .. " tokens (total: " .. playerTokens[f.player.UserId] .. ")")
					gameEventEvent:FireClient(f.player, "tokenReward", { amount = reward, total = playerTokens[f.player.UserId] })
				end
			end
		end
	end

	-- Clean up bot model
	if match.botModel then
		destroyBotModel(match.botModel)
		match.botModel = nil
	end

	task.delay(Config.MATCH_END_DELAY + 1, function()
		for _, f in ipairs(match.fighters) do
			if not f.isBot and f.player.Parent then
				teleportToLobby(f.player)
				gameEventEvent:FireClient(f.player, "enterLobby", {})
				sendPlayerData(f.player)
			end
		end
		activeMatches[match.id] = nil
	end)
end

local function createMatch(player1, player2)
	local matchId = tostring(tick()) .. "_" .. player1.UserId
	local match = {
		id = matchId,
		phase = Config.Phases.COUNTDOWN,
		fighters = {
			createFighterState(player1, -30, true),
			createFighterState(player2, 30, false),
		},
		timer = Config.COUNTDOWN_TIME,
		roundTimer = Config.ROUND_TIME,
		currentRound = 1,
		projectiles = {},
		phaseTimer = Config.COUNTDOWN_TIME,
	}
	activeMatches[matchId] = match

	if player2 == AI_BOT then
		match.botModel = createBotModel(30)
	elseif player1 == AI_BOT then
		match.botModel = createBotModel(-30)
	end

	-- Debug: print equipped abilities at match start
	for i, f in ipairs(match.fighters) do
		print("[PixelBrawl] Fighter " .. i .. " (" .. f.player.Name .. ") equippedAbilities: [1]=" .. tostring(f.equippedAbilities[1]) .. " [2]=" .. tostring(f.equippedAbilities[2]))
	end

	if not (player1 == AI_BOT) then
		gameEventEvent:FireClient(player1, "matchStart", {
			matchId = matchId, playerIndex = 1, opponentName = player2.Name,
		})
	end
	if not (player2 == AI_BOT) then
		gameEventEvent:FireClient(player2, "matchStart", {
			matchId = matchId, playerIndex = 2, opponentName = player1.Name,
		})
	end

	if not (player1 == AI_BOT) then
		local char1 = player1.Character
		if char1 and char1:FindFirstChild("HumanoidRootPart") then
			char1.HumanoidRootPart.CFrame = CFrame.new(-30, Config.GROUND_Y + 3, 0)
		end
	end
	if not (player2 == AI_BOT) then
		local char2 = player2.Character
		if char2 and char2:FindFirstChild("HumanoidRootPart") then
			char2.HumanoidRootPart.CFrame = CFrame.new(30, Config.GROUND_Y + 3, 0)
		end
	end

	for _, f in ipairs(match.fighters) do
		if not f.isBot and f.player.Character then
			local hum = f.player.Character:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.MaxHealth = math.huge
				hum.Health = math.huge
			end
		end
	end

	return match
end

-- ============================================================
-- COMBAT LOGIC
-- ============================================================
local function applyPhysics(fighter, dt)
	fighter.x = fighter.x + fighter.vx * dt
	fighter.y = fighter.y + fighter.vy * dt
	if not fighter.onGround then
		fighter.vy = fighter.vy - 120 * dt
	end
	if fighter.y <= Config.GROUND_Y and fighter.vy <= 0 then
		fighter.y = Config.GROUND_Y
		fighter.vy = 0
		fighter.onGround = true
	end
	if fighter.state == Config.States.HITSTUN then
		fighter.vx = fighter.vx * (1 - 5 * dt)
	end
	fighter.x = math.clamp(fighter.x, Config.ARENA_MIN_X + 2, Config.ARENA_MAX_X - 2)
end

local function checkHit(attacker, defender, attackData)
	if defender.state == Config.States.KO then return end
	if attacker.attackHit then return end

	local dir = attacker.facingRight and 1 or -1

	-- AoE: hits in radius ignoring direction
	if attackData.isAoE then
		local dist = math.abs(attacker.x - defender.x)
		local yDist = math.abs(attacker.y - defender.y)
		if dist < attackData.range and yDist < 10 then
			attacker.attackHit = true
			if defender.state == Config.States.BLOCK then
				defender.health = defender.health - attackData.damage * Config.BLOCK_REDUCTION
				local pushDir = defender.x > attacker.x and 1 or -1
				defender.vx = pushDir * attackData.knockback * Config.BLOCK_KNOCKBACK_MULT
				return "blocked"
			else
				defender.health = defender.health - attackData.damage
				defender.state = Config.States.HITSTUN
				defender.stateTimer = attackData.hitstun
				local pushDir = defender.x > attacker.x and 1 or -1
				defender.vx = pushDir * attackData.knockback
				defender.vy = 5
				return "hit"
			end
		end
		return nil
	end

	-- hitsBothSides: check both directions
	if attackData.hitsBothSides then
		local dist = math.abs(attacker.x - defender.x)
		local yDist = math.abs(attacker.y - defender.y)
		if dist < attackData.range and yDist < 8 then
			attacker.attackHit = true
			if defender.state == Config.States.BLOCK then
				defender.health = defender.health - attackData.damage * Config.BLOCK_REDUCTION
				local pushDir = defender.x > attacker.x and 1 or -1
				defender.vx = pushDir * attackData.knockback * Config.BLOCK_KNOCKBACK_MULT
				return "blocked"
			else
				defender.health = defender.health - attackData.damage
				defender.state = Config.States.HITSTUN
				defender.stateTimer = attackData.hitstun
				local pushDir = defender.x > attacker.x and 1 or -1
				defender.vx = pushDir * attackData.knockback
				defender.vy = 3
				return "hit"
			end
		end
		return nil
	end

	-- Normal directional hit
	local hitX = attacker.x + dir * attackData.range
	local dist = math.abs(hitX - defender.x)
	local yDist = math.abs(attacker.y - defender.y)

	if dist < 8 and yDist < 8 then
		attacker.attackHit = true
		if defender.state == Config.States.BLOCK then
			defender.health = defender.health - attackData.damage * Config.BLOCK_REDUCTION
			defender.vx = dir * attackData.knockback * Config.BLOCK_KNOCKBACK_MULT
			return "blocked"
		else
			defender.health = defender.health - attackData.damage
			defender.state = Config.States.HITSTUN
			defender.stateTimer = attackData.hitstun
			defender.vx = dir * attackData.knockback
			defender.vy = 3
			-- Launch upward for uppercut
			if attackData.launchVY then
				defender.vy = attackData.launchVY
				defender.onGround = false
			end
			return "hit"
		end
	end
	return nil
end

local function updateFighter(fighter, opponent, dt, match)
	if fighter.state == Config.States.KO then return end
	fighter.stateTimer = math.max(0, fighter.stateTimer - dt)

	if fighter.isBot then
		local diff = "medium"
		for _, f in ipairs(match and match.fighters or {}) do
			if not f.isBot and f.player then
				diff = playerDifficulty[f.player.UserId] or "medium"
			end
		end
		fighter.input = createAIInput(fighter, opponent, diff)
	end

	local input = fighter.input

	if fighter.state == Config.States.HITSTUN then
		if fighter.stateTimer <= 0 then fighter.state = Config.States.IDLE end
		applyPhysics(fighter, dt)
		return
	end

	-- Check if in an attack state (base or ability)
	local attackName = nil
	local st = fighter.state
	if st == Config.States.PUNCH then attackName = "punch"
	elseif st == Config.States.KICK then attackName = "kick"
	elseif st == Config.States.SPECIAL then attackName = "special"
	elseif st == Config.States.ABILITY1 then attackName = "ability1"
	elseif st == Config.States.ABILITY2 then attackName = "ability2"
	end

	if attackName then
		local atk, atkKey = getAttackData(fighter, st)
		if not atk then
			fighter.state = Config.States.IDLE
			applyPhysics(fighter, dt)
			return
		end

		local totalTime = atk.startup + atk.active + atk.recovery
		local elapsed = totalTime - fighter.stateTimer

		-- Dash punch: set velocity during startup + active (smooth lunge)
		if atk.dashSpeed then
			local dir = fighter.facingRight and 1 or -1
			if elapsed < atk.startup + atk.active then
				-- Ramp down speed: full during startup, half during active
				local speedMult = elapsed < atk.startup and 1.0 or 0.4
				fighter.vx = dir * atk.dashSpeed * speedMult
			else
				-- Recovery: decelerate
				fighter.vx = fighter.vx * (1 - 8 * dt)
			end
		end

		if not atk.isProjectile then
			if elapsed >= atk.startup and elapsed < atk.startup + atk.active and not fighter.attackHit then
				local result = checkHit(fighter, opponent, atk)
				if result then
					fireToFighters(match, result, { x = opponent.x, y = opponent.y, attackType = atkKey or attackName })
				end
			end
		end

		if atk.isProjectile and elapsed >= atk.startup and elapsed < atk.startup + dt * 2 then
			local dir = fighter.facingRight and 1 or -1
			table.insert(match.projectiles, {
				x = fighter.x + dir * 4, y = fighter.y + 3,
				vx = dir * atk.projectileSpeed, owner = fighter,
				life = atk.projectileLifetime, damage = atk.damage,
				knockback = atk.knockback, hitstun = atk.hitstun,
			})
			fireToFighters(match, "projectile", { x = fighter.x + dir * 4, y = fighter.y + 3, dir = dir })
		end

		if fighter.stateTimer <= 0 then fighter.state = Config.States.IDLE end
		applyPhysics(fighter, dt)
		return
	end

	if input.block and fighter.onGround then
		fighter.state = Config.States.BLOCK
		fighter.vx = 0
	elseif fighter.state == Config.States.BLOCK and not input.block then
		fighter.state = Config.States.IDLE
	end

	if fighter.state == Config.States.BLOCK then
		applyPhysics(fighter, dt)
		return
	end

	if input.jump and fighter.onGround then
		fighter.vy = Config.JUMP_FORCE
		fighter.y = fighter.y + 0.1
		fighter.onGround = false
		fighter.state = Config.States.JUMP
	end

	local moving = false
	if input.left then fighter.vx = -Config.MOVE_SPEED; moving = true
	elseif input.right then fighter.vx = Config.MOVE_SPEED; moving = true
	else fighter.vx = 0 end

	if fighter.onGround and not moving and fighter.state ~= Config.States.JUMP then
		fighter.state = Config.States.IDLE
	elseif fighter.onGround and moving and fighter.state ~= Config.States.JUMP then
		fighter.state = Config.States.WALK
	end
	if not fighter.onGround then fighter.state = Config.States.JUMP end

	local function newPress(key)
		return input[key] and not fighter.prevInput[key]
	end

	-- Base attacks
	if newPress("punch") then
		local atk = Config.Attacks.punch
		fighter.state = Config.States.PUNCH
		fighter.stateTimer = atk.startup + atk.active + atk.recovery
		fighter.attackHit = false; fighter.vx = 0
		fireToFighters(match, "attack", { attackType = "punch", attacker = fighter == match.fighters[1] and 1 or 2 })
	elseif newPress("kick") then
		local atk = Config.Attacks.kick
		fighter.state = Config.States.KICK
		fighter.stateTimer = atk.startup + atk.active + atk.recovery
		fighter.attackHit = false; fighter.vx = 0
		fireToFighters(match, "attack", { attackType = "kick", attacker = fighter == match.fighters[1] and 1 or 2 })
	elseif newPress("special") then
		local atk = Config.Attacks.special
		fighter.state = Config.States.SPECIAL
		fighter.stateTimer = atk.startup + atk.active + atk.recovery
		fighter.attackHit = false; fighter.vx = 0
		fireToFighters(match, "attack", { attackType = "special", attacker = fighter == match.fighters[1] and 1 or 2 })
	elseif newPress("ability1") then
		if fighter.equippedAbilities[1] then
			local atk = Config.AbilityAttacks[fighter.equippedAbilities[1]]
			if atk then
				fighter.state = Config.States.ABILITY1
				fighter.stateTimer = atk.startup + atk.active + atk.recovery
				fighter.attackHit = false; fighter.vx = 0
				fireToFighters(match, "attack", { attackType = fighter.equippedAbilities[1], attacker = fighter == match.fighters[1] and 1 or 2 })
				print("[PixelBrawl] ABILITY1 triggered: " .. tostring(fighter.equippedAbilities[1]) .. " timer=" .. tostring(fighter.stateTimer))
			else
				print("[PixelBrawl] ABILITY1 key '" .. tostring(fighter.equippedAbilities[1]) .. "' not found in AbilityAttacks!")
			end
		else
			print("[PixelBrawl] ABILITY1 pressed but equippedAbilities[1] is nil! equippedAbilities = " .. tostring(fighter.equippedAbilities[1]) .. ", " .. tostring(fighter.equippedAbilities[2]))
		end
	elseif newPress("ability2") then
		if fighter.equippedAbilities[2] then
			local atk = Config.AbilityAttacks[fighter.equippedAbilities[2]]
			if atk then
				fighter.state = Config.States.ABILITY2
				fighter.stateTimer = atk.startup + atk.active + atk.recovery
				fighter.attackHit = false; fighter.vx = 0
				fireToFighters(match, "attack", { attackType = fighter.equippedAbilities[2], attacker = fighter == match.fighters[1] and 1 or 2 })
				print("[PixelBrawl] ABILITY2 triggered: " .. tostring(fighter.equippedAbilities[2]) .. " timer=" .. tostring(fighter.stateTimer))
			else
				print("[PixelBrawl] ABILITY2 key '" .. tostring(fighter.equippedAbilities[2]) .. "' not found in AbilityAttacks!")
			end
		else
			print("[PixelBrawl] ABILITY2 pressed but equippedAbilities[2] is nil! equippedAbilities = " .. tostring(fighter.equippedAbilities[1]) .. ", " .. tostring(fighter.equippedAbilities[2]))
		end
	end

	if opponent and fighter.state ~= Config.States.HITSTUN then
		fighter.facingRight = fighter.x < opponent.x
	end

	fighter.prevInput = {}
	for k, v in pairs(input) do fighter.prevInput[k] = v end
	applyPhysics(fighter, dt)
end

local function updateProjectiles(match, dt)
	for i = #match.projectiles, 1, -1 do
		local p = match.projectiles[i]
		p.x = p.x + p.vx * dt
		p.life = p.life - dt
		if p.life <= 0 or p.x < Config.ARENA_MIN_X - 10 or p.x > Config.ARENA_MAX_X + 10 then
			table.remove(match.projectiles, i)
		else
			for _, f in ipairs(match.fighters) do
				if f ~= p.owner and f.state ~= Config.States.KO then
					if math.abs(p.x - f.x) < 6 and math.abs(p.y - f.y - 3) < 6 then
						if f.state == Config.States.BLOCK then
							f.health = f.health - p.damage * Config.BLOCK_REDUCTION
							fireToFighters(match, "blocked", { x = p.x, y = p.y, attackType = "special" })
						else
							f.health = f.health - p.damage
							f.state = Config.States.HITSTUN
							f.stateTimer = p.hitstun
							local dir = p.vx > 0 and 1 or -1
							f.vx = dir * p.knockback; f.vy = 3
							fireToFighters(match, "hit", { x = p.x, y = p.y, attackType = "special" })
						end
						table.remove(match.projectiles, i)
						break
					end
				end
			end
		end
	end
end

local function resetRound(match)
	for i, f in ipairs(match.fighters) do
		f.x = i == 1 and -30 or 30
		f.y = Config.GROUND_Y; f.vx = 0; f.vy = 0
		f.health = Config.MAX_HEALTH; f.state = Config.States.IDLE
		f.stateTimer = 0; f.attackHit = false
		f.facingRight = i == 1; f.onGround = true
		if not f.isBot then
			local char = f.player.Character
			if char and char:FindFirstChild("HumanoidRootPart") then
				char.HumanoidRootPart.CFrame = CFrame.new(f.x, Config.GROUND_Y + 3, 0)
				char.HumanoidRootPart.Velocity = Vector3.new(0, 0, 0)
			end
		end
	end
	match.projectiles = {}
	match.roundTimer = Config.ROUND_TIME

	if match.botModel then
		for _, f in ipairs(match.fighters) do
			if f.isBot then
				updateBotModel(match.botModel, f)
			end
		end
	end
end

-- ============================================================
-- UPDATE MATCH
-- ============================================================
local function updateMatch(match, dt)
	for i, f in ipairs(match.fighters) do
		if not f.isBot and not f.player.Parent then
			activeMatches[match.id] = nil
			return
		end
	end

	if match.phase == Config.Phases.COUNTDOWN then
		match.phaseTimer = match.phaseTimer - dt
		if match.phaseTimer <= 0 then
			match.phase = Config.Phases.FIGHTING
			fireToFighters(match, "fight", {})
		end
	elseif match.phase == Config.Phases.FIGHTING then
		match.roundTimer = match.roundTimer - dt
		if match.roundTimer <= 0 then match.roundTimer = 0 end
		local f1 = match.fighters[1]
		local f2 = match.fighters[2]
		updateFighter(f1, f2, dt, match)
		updateFighter(f2, f1, dt, match)
		updateProjectiles(match, dt)

		for _, f in ipairs(match.fighters) do
			if not f.isBot then
				local char = f.player.Character
				if char and char:FindFirstChild("HumanoidRootPart") then
					local targetCF = CFrame.new(f.x, f.y + 3, 0)
					if f.facingRight then
						targetCF = targetCF * CFrame.Angles(0, math.rad(90), 0)
					else
						targetCF = targetCF * CFrame.Angles(0, math.rad(-90), 0)
					end
					char.HumanoidRootPart.CFrame = targetCF
					char.HumanoidRootPart.Velocity = Vector3.new(f.vx, f.vy, 0)
				end
			else
				if match.botModel then
					updateBotModel(match.botModel, f)
				end
			end
		end

		local p1Dead = f1.health <= 0
		local p2Dead = f2.health <= 0
		if p1Dead or p2Dead or match.roundTimer <= 0 then
			if p2Dead or (not p1Dead and f1.health > f2.health) then
				f1.roundWins = f1.roundWins + 1; f2.state = Config.States.KO
			elseif p1Dead or (not p2Dead and f2.health > f1.health) then
				f2.roundWins = f2.roundWins + 1; f1.state = Config.States.KO
			end
			match.phase = Config.Phases.ROUND_END
			match.phaseTimer = Config.ROUND_END_DELAY
			fireToFighters(match, "roundEnd", { p1Wins = f1.roundWins, p2Wins = f2.roundWins, round = match.currentRound })
		end
	elseif match.phase == Config.Phases.ROUND_END then
		match.phaseTimer = match.phaseTimer - dt
		if match.phaseTimer <= 0 then
			local f1 = match.fighters[1]
			local f2 = match.fighters[2]
			if f1.roundWins >= Config.ROUNDS_TO_WIN or f2.roundWins >= Config.ROUNDS_TO_WIN then
				endMatch(match)
			else
				match.currentRound = match.currentRound + 1
				resetRound(match)
				match.phase = Config.Phases.COUNTDOWN
				match.phaseTimer = Config.COUNTDOWN_TIME
				fireToFighters(match, "newRound", { round = match.currentRound })
			end
		end
	end

	if match.phase ~= Config.Phases.MATCH_END then
		local stateData = {
			phase = match.phase, roundTimer = match.roundTimer,
			currentRound = match.currentRound, phaseTimer = match.phaseTimer,
			fighters = {}, projectiles = {},
		}
		for i, f in ipairs(match.fighters) do
			stateData.fighters[i] = {
				x = f.x, y = f.y, health = f.health, state = f.state,
				facingRight = f.facingRight, roundWins = f.roundWins, name = f.player.Name,
			}
		end
		for _, p in ipairs(match.projectiles) do
			table.insert(stateData.projectiles, { x = p.x, y = p.y, vx = p.vx })
		end
		for _, f in ipairs(match.fighters) do
			if not f.isBot and f.player.Parent then
				gameStateEvent:FireClient(f.player, stateData)
			end
		end
	end
end

-- ============================================================
-- START MATCH WITH AI
-- ============================================================
startMatchWithAI = function(player)
	if isInMatch(player) then return end
	createMatch(player, AI_BOT)
	print("[PixelBrawl] Match started: " .. player.Name .. " vs CPU Fighter (difficulty: " .. (playerDifficulty[player.UserId] or "medium") .. ")")
end

-- ============================================================
-- REMOVE FROM PVP QUEUE
-- ============================================================
local function removeFromQueue(player)
	for i, p in ipairs(pvpQueue) do
		if p == player then
			table.remove(pvpQueue, i)
			return true
		end
	end
	return false
end

-- ============================================================
-- DIFFICULTY SELECTION HANDLER (AI only)
-- ============================================================
selectDifficultyEvent.OnServerEvent:Connect(function(player, difficulty)
	if type(difficulty) ~= "string" then return end
	difficulty = string.lower(difficulty)

	if difficulty ~= "easy" and difficulty ~= "medium" and difficulty ~= "hard" then
		difficulty = "medium"
	end
	playerDifficulty[player.UserId] = difficulty
	playerState[player.UserId] = Config.PlayerStates.IN_MATCH
	print("[PixelBrawl] " .. player.Name .. " selected difficulty: " .. difficulty)

	if player.Parent and not isInMatch(player) then
		startMatchWithAI(player)
	end
end)

-- ============================================================
-- SHOP PURCHASE HANDLER
-- ============================================================
shopPurchaseEvent.OnServerEvent:Connect(function(player, abilityKey)
	if type(abilityKey) ~= "string" then return end
	local shopItem = Config.ShopAbilities[abilityKey]
	if not shopItem then
		print("[PixelBrawl] Invalid shop item: " .. abilityKey)
		return
	end

	local uid = player.UserId
	if not playerInventory[uid] then playerInventory[uid] = {} end

	-- Already owned?
	if playerInventory[uid][abilityKey] then
		gameEventEvent:FireClient(player, "shopResult", { success = false, reason = "Already owned!" })
		return
	end

	-- Enough tokens?
	local tokens = playerTokens[uid] or 0
	if tokens < shopItem.cost then
		gameEventEvent:FireClient(player, "shopResult", { success = false, reason = "Not enough tokens!" })
		return
	end

	-- Purchase!
	playerTokens[uid] = tokens - shopItem.cost
	playerInventory[uid][abilityKey] = true
	print("[PixelBrawl] " .. player.Name .. " bought " .. shopItem.name .. " for " .. shopItem.cost .. " tokens")

	gameEventEvent:FireClient(player, "shopResult", { success = true, abilityKey = abilityKey })
	sendPlayerData(player)
end)

-- ============================================================
-- EQUIP ABILITY HANDLER
-- ============================================================
equipAbilityEvent.OnServerEvent:Connect(function(player, abilityKey, slot)
	print("[PixelBrawl] EquipAbility received: player=" .. player.Name .. " abilityKey=" .. tostring(abilityKey) .. " (" .. type(abilityKey) .. ") slot=" .. tostring(slot) .. " (" .. type(slot) .. ")")
	local uid = player.UserId
	if not playerEquipped[uid] then playerEquipped[uid] = { nil, nil } end
	if not playerInventory[uid] then playerInventory[uid] = {} end

	if type(slot) ~= "number" or (slot ~= 1 and slot ~= 2) then
		print("[PixelBrawl] EquipAbility REJECTED: invalid slot type or value")
		return
	end

	-- Unequip
	if abilityKey == nil or abilityKey == "" then
		playerEquipped[uid][slot] = nil
		sendPlayerData(player)
		return
	end

	if type(abilityKey) ~= "string" then return end

	-- Must own it
	if not playerInventory[uid][abilityKey] then return end

	-- Remove from other slot if already equipped there
	if playerEquipped[uid][1] == abilityKey then playerEquipped[uid][1] = nil end
	if playerEquipped[uid][2] == abilityKey then playerEquipped[uid][2] = nil end

	playerEquipped[uid][slot] = abilityKey
	print("[PixelBrawl] " .. player.Name .. " equipped " .. abilityKey .. " to slot " .. slot)
	sendPlayerData(player)
end)

-- ============================================================
-- PVP ZONE ENTRY HANDLER
-- ============================================================
local function handlePvpZoneEntry(player)
	if isInMatch(player) then return end
	if playerState[player.UserId] == Config.PlayerStates.QUEUED then return end

	playerState[player.UserId] = Config.PlayerStates.QUEUED
	removeFromQueue(player)

	local opponent = nil
	for i, p in ipairs(pvpQueue) do
		if p ~= player and p.Parent and not isInMatch(p) then
			opponent = p
			table.remove(pvpQueue, i)
			break
		end
	end

	if opponent then
		playerState[player.UserId] = Config.PlayerStates.IN_MATCH
		playerState[opponent.UserId] = Config.PlayerStates.IN_MATCH
		print("[PixelBrawl] PVP match: " .. player.Name .. " vs " .. opponent.Name)
		createMatch(opponent, player)
	else
		table.insert(pvpQueue, player)
		gameEventEvent:FireClient(player, "queued", {})
		print("[PixelBrawl] " .. player.Name .. " waiting for PVP opponent")
	end
end

-- ============================================================
-- INPUT HANDLER
-- ============================================================
sendInputEvent.OnServerEvent:Connect(function(player, inputData)
	local match, index = getMatchForPlayer(player)
	if not match then return end
	if match.phase ~= Config.Phases.FIGHTING then return end
	local fighter = match.fighters[index]
	if type(inputData) ~= "table" then return end
	fighter.input = {
		left = inputData.left == true, right = inputData.right == true,
		jump = inputData.jump == true, block = inputData.block == true,
		punch = inputData.punch == true, kick = inputData.kick == true,
		special = inputData.special == true,
		ability1 = inputData.ability1 == true, ability2 = inputData.ability2 == true,
	}
end)

-- ============================================================
-- PLAYER JOIN / LEAVE
-- ============================================================
local function setupPlayer(player)
	playerState[player.UserId] = Config.PlayerStates.LOBBY
	playerTokens[player.UserId] = playerTokens[player.UserId] or 0
	playerInventory[player.UserId] = playerInventory[player.UserId] or {}
	playerEquipped[player.UserId] = playerEquipped[player.UserId] or { nil, nil }

	player.CharacterAdded:Connect(function(character)
		task.delay(0.5, function()
			local healthScript = character:FindFirstChild("Health")
			if healthScript then healthScript:Destroy() end
		end)
		character:WaitForChild("HumanoidRootPart")
		if playerState[player.UserId] ~= Config.PlayerStates.IN_MATCH then
			teleportToLobby(player)
			gameEventEvent:FireClient(player, "enterLobby", {})
			sendPlayerData(player)
		end
	end)
end

Players.PlayerAdded:Connect(function(player)
	print("[PixelBrawl] Player joined: " .. player.Name)
	setupPlayer(player)
end)

for _, player in ipairs(Players:GetPlayers()) do
	setupPlayer(player)
	if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
		teleportToLobby(player)
		task.delay(1, function()
			gameEventEvent:FireClient(player, "enterLobby", {})
			sendPlayerData(player)
		end)
	end
end

Players.PlayerRemoving:Connect(function(player)
	removeFromQueue(player)
	playerState[player.UserId] = nil
	zoneCooldown[player.UserId] = nil
	playerDifficulty[player.UserId] = nil
	playerTokens[player.UserId] = nil
	playerInventory[player.UserId] = nil
	playerEquipped[player.UserId] = nil
end)

-- ============================================================
-- MAIN GAME LOOP
-- ============================================================
RunService.Heartbeat:Connect(function(dt)
	dt = math.min(dt, 1/30)

	-- Zone detection for lobby players
	for _, p in ipairs(Players:GetPlayers()) do
		local state = playerState[p.UserId]
		if state == Config.PlayerStates.LOBBY then
			local char = p.Character
			if char then
				local hrp = char:FindFirstChild("HumanoidRootPart")
				if hrp then
					local pos = hrp.Position
					local cooldownOk = not zoneCooldown[p.UserId] or (tick() - zoneCooldown[p.UserId] > 3)

					-- Check VS BOT zone
					local distBot = (pos - Config.ZONE_VS_BOT).Magnitude
					if distBot < Config.ZONE_RADIUS and cooldownOk then
						zoneCooldown[p.UserId] = tick()
						gameEventEvent:FireClient(p, "enteredBotZone", {})
					end

					-- Check VS FRIEND zone
					local distFriend = (pos - Config.ZONE_VS_FRIEND).Magnitude
					if distFriend < Config.ZONE_RADIUS and cooldownOk then
						zoneCooldown[p.UserId] = tick()
						handlePvpZoneEntry(p)
					end

					-- Check SHOP zone
					local distShop = (pos - Config.ZONE_SHOP).Magnitude
					if distShop < Config.ZONE_RADIUS and cooldownOk then
						zoneCooldown[p.UserId] = tick()
						gameEventEvent:FireClient(p, "enteredShopZone", {})
					end
				end
			end
		elseif state == Config.PlayerStates.QUEUED then
			local char = p.Character
			if char then
				local hrp = char:FindFirstChild("HumanoidRootPart")
				if hrp then
					local dist = (hrp.Position - Config.ZONE_VS_FRIEND).Magnitude
					if dist > Config.ZONE_RADIUS * 2 then
						removeFromQueue(p)
						playerState[p.UserId] = Config.PlayerStates.LOBBY
						gameEventEvent:FireClient(p, "queueCancelled", {})
					end
				end
			end
		end
	end

	-- Update active matches
	for matchId, match in pairs(activeMatches) do
		updateMatch(match, dt)
	end
end)

print("[PixelBrawl] Server loaded! (AI mode + abilities + shop + tokens)")
