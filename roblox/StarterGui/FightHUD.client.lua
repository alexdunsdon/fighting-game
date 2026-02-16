--[[
	FightHUD - Client-side UI for Pixel Brawl
	LOCATION: StarterGui > FightHUD (LocalScript)

	Creates: health bars, timer, round counter, messages,
	lobby banner, bot difficulty popup, queue indicator,
	token display, shop popup, equip panel, ability indicators,
	AND mobile touch controls (D-pad + attack buttons + ability buttons)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("FightConfig"))
local remotesFolder = ReplicatedStorage:WaitForChild("FightRemotes")
local gameStateEvent = remotesFolder:WaitForChild(Config.Remotes.GAME_STATE)
local gameEventEvent = remotesFolder:WaitForChild(Config.Remotes.GAME_EVENT)
local sendInputEvent = remotesFolder:WaitForChild(Config.Remotes.SEND_INPUT)
local selectDifficultyEvent = remotesFolder:WaitForChild(Config.Remotes.SELECT_DIFFICULTY)
local shopPurchaseEvent = remotesFolder:WaitForChild(Config.Remotes.SHOP_PURCHASE)
local equipAbilityEvent = remotesFolder:WaitForChild(Config.Remotes.EQUIP_ABILITY)

local player = Players.LocalPlayer
local isMobile = UserInputService.TouchEnabled

-- ============================================================
-- PLAYER DATA (synced from server)
-- ============================================================
local myTokens = 0
local myInventory = {}    -- { "dashPunch", "spinKick", ... }
local myEquipped = { nil, nil }  -- { slot1 = abilityKey or nil, slot2 = abilityKey or nil }

-- ============================================================
-- MUSIC & SOUND EFFECTS
-- ============================================================
local SoundService = game:GetService("SoundService")

local function makeSound(name, id, vol, looped, speed)
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = "rbxassetid://" .. tostring(id)
	s.Volume = vol or 0.5
	s.Looped = looped or false
	s.PlaybackSpeed = speed or 1
	s.Parent = SoundService
	return s
end

-- MUSIC
local menuMusic = makeSound("MenuMusic", 9043887091, 0.35, true, 1.0)
local battleMusic1 = makeSound("BattleMusic1", 1837779548, 0.5, true, 1.0)
local battleMusic2 = makeSound("BattleMusic2", 1846856152, 0.5, true, 1.0)
local battleMusic3 = makeSound("BattleMusic3", 9038254803, 0.5, true, 1.0)
local battleTracks = { battleMusic1, battleMusic2, battleMusic3 }
local currentBattleTrack = nil

-- SFX
local punchSound = makeSound("PunchSFX", 278061737, 0.5)
local kickSound = makeSound("KickSFX", 138285836, 0.6)
local koSound = makeSound("KOSound", 5765631938, 0.8, false, 0.5)
local winSound = makeSound("WinSound", 5765631938, 0.7, false, 0.7)
local countdownBeep = makeSound("CountdownBeep", 5765631938, 0.4, false, 2)
local fightShout = makeSound("FightShout", 5765631938, 0.9, false, 0.5)
local buySFX = makeSound("BuySFX", 5765631938, 0.6, false, 1.5)
local coinSFX = makeSound("CoinSFX", 5765631938, 0.5, false, 2.0)

local function stopAllMusic()
	menuMusic:Stop()
	for _, track in ipairs(battleTracks) do
		track:Stop()
	end
end

local function playMenuMusic()
	stopAllMusic()
	if not menuMusic.IsPlaying then
		menuMusic:Play()
	end
end

local function playBattleMusic()
	stopAllMusic()
	currentBattleTrack = battleTracks[math.random(1, #battleTracks)]
	currentBattleTrack:Play()
end

-- Start menu music immediately
menuMusic:Play()

-- ============================================================
-- TOUCH INPUT STATE (for mobile)
-- ============================================================
local touchInput = {
	left = false, right = false, jump = false,
	block = false, punch = false, kick = false, special = false,
	ability1 = false, ability2 = false,
}

RunService.Heartbeat:Connect(function()
	if isMobile then
		sendInputEvent:FireServer(touchInput)
	end
end)

-- ============================================================
-- CREATE GUI
-- ============================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FightHUD"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = player:WaitForChild("PlayerGui")

local COLOR_RED = Color3.fromRGB(220, 40, 40)
local COLOR_YELLOW = Color3.fromRGB(220, 220, 40)
local COLOR_GREEN = Color3.fromRGB(40, 200, 40)
local COLOR_BLUE = Color3.fromRGB(60, 120, 255)
local COLOR_BG = Color3.fromRGB(30, 30, 30)
local COLOR_WHITE = Color3.fromRGB(255, 255, 255)
local COLOR_GOLD = Color3.fromRGB(255, 215, 0)
local COLOR_DARK = Color3.fromRGB(15, 15, 25)
local COLOR_PURPLE = Color3.fromRGB(130, 50, 200)
local COLOR_ORANGE = Color3.fromRGB(255, 140, 40)
local COLOR_SHOP_BG = Color3.fromRGB(25, 20, 15)
local COLOR_EQUIP_BG = Color3.fromRGB(15, 20, 30)

-- ============================================================
-- HELPERS
-- ============================================================
local function newFrame(props)
	local f = Instance.new("Frame")
	f.BackgroundColor3 = props.color or COLOR_BG
	f.BorderSizePixel = 0
	f.Size = props.size or UDim2.new(0, 100, 0, 20)
	f.Position = props.pos or UDim2.new(0, 0, 0, 0)
	f.AnchorPoint = props.anchor or Vector2.new(0, 0)
	if props.transparency then f.BackgroundTransparency = props.transparency end
	if props.corner then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, props.corner)
		c.Parent = f
	end
	if props.zindex then f.ZIndex = props.zindex end
	f.Parent = props.parent or screenGui
	return f
end

local function newLabel(props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = props.size or UDim2.new(0, 100, 0, 30)
	l.Position = props.pos or UDim2.new(0, 0, 0, 0)
	l.AnchorPoint = props.anchor or Vector2.new(0, 0)
	l.Text = props.text or ""
	l.TextColor3 = props.color or COLOR_WHITE
	l.TextSize = props.textSize or 18
	l.Font = props.font or Enum.Font.GothamBold
	l.TextXAlignment = props.alignX or Enum.TextXAlignment.Center
	l.TextStrokeTransparency = props.strokeTransparency or 0.5
	l.TextStrokeColor3 = Color3.new(0, 0, 0)
	if props.zindex then l.ZIndex = props.zindex end
	l.Parent = props.parent or screenGui
	return l
end

local function newButton(props)
	local b = Instance.new("TextButton")
	b.Size = props.size or UDim2.new(0, 100, 0, 30)
	b.Position = props.pos or UDim2.new(0, 0, 0, 0)
	b.AnchorPoint = props.anchor or Vector2.new(0, 0)
	b.BackgroundColor3 = props.color or COLOR_BG
	b.BackgroundTransparency = props.transparency or 0
	b.Text = props.text or ""
	b.TextColor3 = props.textColor or COLOR_WHITE
	b.TextSize = props.textSize or 16
	b.Font = props.font or Enum.Font.GothamBold
	b.TextStrokeTransparency = 0.5
	b.TextStrokeColor3 = Color3.new(0, 0, 0)
	b.Active = true
	if props.corner then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, props.corner)
		c.Parent = b
	end
	b.Parent = props.parent or screenGui
	return b
end

-- ============================================================
-- HUD (health bars, timer, rounds) ‚Äî shown during fights
-- ============================================================
local hudFrame = newFrame({
	size = UDim2.new(1, 0, 0, 80),
	pos = UDim2.new(0, 0, 0, 0),
	color = Color3.new(0, 0, 0),
	transparency = 0.6,
	parent = screenGui,
})
hudFrame.Name = "HUD"
hudFrame.Visible = false

local p1NameLabel = newLabel({
	size = UDim2.new(0, 200, 0, 20), pos = UDim2.new(0, 20, 0, 5),
	text = "PLAYER 1", color = COLOR_RED, textSize = 14,
	alignX = Enum.TextXAlignment.Left, parent = hudFrame,
})

local p2NameLabel = newLabel({
	size = UDim2.new(0, 200, 0, 20), pos = UDim2.new(1, -20, 0, 5),
	anchor = Vector2.new(1, 0), text = "PLAYER 2", color = COLOR_BLUE,
	textSize = 14, alignX = Enum.TextXAlignment.Right, parent = hudFrame,
})

local p1BarBG = newFrame({
	size = UDim2.new(0.35, 0, 0, 20), pos = UDim2.new(0, 20, 0, 28),
	color = COLOR_BG, corner = 4, parent = hudFrame,
})
local p1BarFill = newFrame({
	size = UDim2.new(1, 0, 1, 0), color = COLOR_GREEN, corner = 4, parent = p1BarBG,
})
local p1Border = Instance.new("UIStroke")
p1Border.Color = COLOR_WHITE; p1Border.Thickness = 1.5; p1Border.Parent = p1BarBG

local p2BarBG = newFrame({
	size = UDim2.new(0.35, 0, 0, 20), pos = UDim2.new(1, -20, 0, 28),
	anchor = Vector2.new(1, 0), color = COLOR_BG, corner = 4, parent = hudFrame,
})
local p2BarFill = newFrame({
	size = UDim2.new(1, 0, 1, 0), pos = UDim2.new(1, 0, 0, 0),
	anchor = Vector2.new(1, 0), color = COLOR_GREEN, corner = 4, parent = p2BarBG,
})
local p2Border = Instance.new("UIStroke")
p2Border.Color = COLOR_WHITE; p2Border.Thickness = 1.5; p2Border.Parent = p2BarBG

local timerLabel = newLabel({
	size = UDim2.new(0, 80, 0, 40), pos = UDim2.new(0.5, 0, 0, 14),
	anchor = Vector2.new(0.5, 0), text = "60", color = COLOR_WHITE,
	textSize = 32, parent = hudFrame,
})

local roundLabel = newLabel({
	size = UDim2.new(0, 200, 0, 18), pos = UDim2.new(0.5, 0, 0, 54),
	anchor = Vector2.new(0.5, 0), text = "ROUND 1", color = COLOR_GOLD,
	textSize = 12, parent = hudFrame,
})

local p1Dots = {}
for i = 1, Config.ROUNDS_TO_WIN do
	local dot = newFrame({
		size = UDim2.new(0, 10, 0, 10), pos = UDim2.new(0, 20 + (i-1)*15, 0, 55),
		color = Color3.fromRGB(60,60,60), corner = 5, parent = hudFrame,
	})
	table.insert(p1Dots, dot)
end

local p2Dots = {}
for i = 1, Config.ROUNDS_TO_WIN do
	local dot = newFrame({
		size = UDim2.new(0, 10, 0, 10), pos = UDim2.new(1, -20-(i-1)*15, 0, 55),
		anchor = Vector2.new(1, 0), color = Color3.fromRGB(60,60,60), corner = 5, parent = hudFrame,
	})
	table.insert(p2Dots, dot)
end

-- ============================================================
-- CENTER MESSAGES (FIGHT!, K.O.!, etc.)
-- ============================================================
local centerLabel = newLabel({
	size = UDim2.new(1, 0, 0, 80), pos = UDim2.new(0.5, 0, 0.4, 0),
	anchor = Vector2.new(0.5, 0.5), text = "", color = COLOR_WHITE,
	textSize = 48, font = Enum.Font.GothamBlack, parent = screenGui,
})
centerLabel.Name = "CenterMessage"

local subLabel = newLabel({
	size = UDim2.new(1, 0, 0, 30), pos = UDim2.new(0.5, 0, 0.48, 0),
	anchor = Vector2.new(0.5, 0.5), text = "", color = COLOR_GOLD,
	textSize = 18, parent = screenGui,
})

-- ============================================================
-- TOKEN DISPLAY (top-right, visible in lobby)
-- ============================================================
local tokenFrame = newFrame({
	size = UDim2.new(0, 160, 0, 40),
	pos = UDim2.new(1, -15, 0, 15),
	anchor = Vector2.new(1, 0),
	color = Color3.fromRGB(30, 25, 10),
	transparency = 0.2,
	corner = 10,
	parent = screenGui,
})
tokenFrame.Name = "TokenDisplay"

local tokenStroke = Instance.new("UIStroke")
tokenStroke.Color = COLOR_GOLD
tokenStroke.Thickness = 2
tokenStroke.Parent = tokenFrame

-- Coin icon (circle)
local coinIcon = newFrame({
	size = UDim2.new(0, 26, 0, 26),
	pos = UDim2.new(0, 10, 0.5, 0),
	anchor = Vector2.new(0, 0.5),
	color = COLOR_GOLD,
	corner = 13,
	parent = tokenFrame,
})
newLabel({
	size = UDim2.new(1, 0, 1, 0),
	pos = UDim2.new(0.5, 0, 0.5, 0),
	anchor = Vector2.new(0.5, 0.5),
	text = "$", color = Color3.fromRGB(120, 80, 0), textSize = 16,
	font = Enum.Font.GothamBlack, parent = coinIcon,
})

local tokenLabel = newLabel({
	size = UDim2.new(0, 100, 0, 30),
	pos = UDim2.new(0, 42, 0.5, 0),
	anchor = Vector2.new(0, 0.5),
	text = "0", color = COLOR_GOLD, textSize = 22,
	font = Enum.Font.GothamBlack,
	alignX = Enum.TextXAlignment.Left,
	parent = tokenFrame,
})

local function updateTokenDisplay()
	tokenLabel.Text = tostring(myTokens)
end

-- ============================================================
-- LOBBY BANNER (shown in lobby, no overlay ‚Äî player walks freely)
-- ============================================================
local lobbyBanner = newFrame({
	size = UDim2.new(0, 500, 0, 50),
	pos = UDim2.new(0.5, 0, 0, 20),
	anchor = Vector2.new(0.5, 0),
	color = Color3.fromRGB(0, 0, 0),
	transparency = 0.5,
	corner = 12,
	parent = screenGui,
})
lobbyBanner.Name = "LobbyBanner"

newLabel({
	size = UDim2.new(1, 0, 1, 0),
	pos = UDim2.new(0.5, 0, 0.5, 0),
	anchor = Vector2.new(0.5, 0.5),
	text = "WALK INTO A PORTAL TO FIGHT!",
	color = COLOR_GOLD, textSize = 22,
	font = Enum.Font.GothamBlack,
	parent = lobbyBanner,
})

-- Controls hint below banner
local controlsHint = newLabel({
	size = UDim2.new(0, 500, 0, 20),
	pos = UDim2.new(0.5, 0, 0, 75),
	anchor = Vector2.new(0.5, 0),
	text = isMobile and "Walk to a glowing portal" or "Move: WASD  |  Portals to fight  |  Shop in the back  |  [C] Controls",
	color = Color3.fromRGB(180, 180, 180), textSize = 13,
	parent = screenGui,
})
controlsHint.Name = "ControlsHint"

-- ============================================================
-- CONTROLS PANEL (toggleable with C key or button)
-- ============================================================
local controlsPanel = newFrame({
	size = UDim2.new(0, 360, 0, 340),
	pos = UDim2.new(0.5, 0, 0.5, 0),
	anchor = Vector2.new(0.5, 0.5),
	color = Color3.fromRGB(15, 15, 25),
	transparency = 0.02,
	corner = 16,
	parent = screenGui,
	zindex = 12,
})
controlsPanel.Name = "ControlsPanel"
controlsPanel.Visible = false

local controlsPanelStroke = Instance.new("UIStroke")
controlsPanelStroke.Color = COLOR_WHITE
controlsPanelStroke.Thickness = 2
controlsPanelStroke.Parent = controlsPanel

-- Title
newLabel({
	size = UDim2.new(1, 0, 0, 30),
	pos = UDim2.new(0.5, 0, 0, 12),
	anchor = Vector2.new(0.5, 0),
	text = "CONTROLS", color = COLOR_WHITE, textSize = 24,
	font = Enum.Font.GothamBlack, parent = controlsPanel, zindex = 12,
})

-- Helper to make a control row
local function makeControlRow(yPos, keyText, keyColor, actionText)
	-- Key badge
	local keyBadge = newFrame({
		size = UDim2.new(0, 70, 0, 26),
		pos = UDim2.new(0, 25, 0, yPos),
		color = Color3.fromRGB(40, 40, 55),
		corner = 6,
		parent = controlsPanel,
		zindex = 12,
	})
	local badgeStroke = Instance.new("UIStroke")
	badgeStroke.Color = keyColor
	badgeStroke.Thickness = 1.5
	badgeStroke.Parent = keyBadge

	newLabel({
		size = UDim2.new(1, 0, 1, 0),
		pos = UDim2.new(0.5, 0, 0.5, 0),
		anchor = Vector2.new(0.5, 0.5),
		text = keyText, color = keyColor, textSize = 13,
		font = Enum.Font.GothamBlack,
		parent = keyBadge, zindex = 12,
	})

	-- Action label
	newLabel({
		size = UDim2.new(0, 220, 0, 26),
		pos = UDim2.new(0, 105, 0, yPos),
		text = actionText, color = Color3.fromRGB(200, 200, 200), textSize = 14,
		font = Enum.Font.GothamBold,
		alignX = Enum.TextXAlignment.Left,
		parent = controlsPanel, zindex = 12,
	})
end

-- Section: Movement
newLabel({
	size = UDim2.new(1, 0, 0, 18),
	pos = UDim2.new(0, 25, 0, 48),
	text = "MOVEMENT", color = COLOR_GOLD, textSize = 11,
	font = Enum.Font.GothamBlack,
	alignX = Enum.TextXAlignment.Left,
	parent = controlsPanel, zindex = 12,
})
makeControlRow(68, "A / D", Color3.fromRGB(150, 150, 200), "Move Left / Right")
makeControlRow(98, "W / Space", Color3.fromRGB(150, 200, 150), "Jump")
makeControlRow(128, "S", Color3.fromRGB(200, 200, 100), "Block")

-- Section: Attacks
newLabel({
	size = UDim2.new(1, 0, 0, 18),
	pos = UDim2.new(0, 25, 0, 162),
	text = "ATTACKS", color = COLOR_RED, textSize = 11,
	font = Enum.Font.GothamBlack,
	alignX = Enum.TextXAlignment.Left,
	parent = controlsPanel, zindex = 12,
})
makeControlRow(182, "F / Q", COLOR_RED, "Punch (fast, light)")
makeControlRow(212, "G / E", COLOR_BLUE, "Kick (slow, heavy)")
makeControlRow(242, "H / R", COLOR_ORANGE, "Special (projectile)")

-- Section: Abilities
newLabel({
	size = UDim2.new(1, 0, 0, 18),
	pos = UDim2.new(0, 25, 0, 276),
	text = "ABILITIES (equip in lobby)", color = COLOR_PURPLE, textSize = 11,
	font = Enum.Font.GothamBlack,
	alignX = Enum.TextXAlignment.Left,
	parent = controlsPanel, zindex = 12,
})
makeControlRow(296, "Z / 1", Color3.fromRGB(255, 160, 60), "Ability Slot 1")
makeControlRow(326, "X / 2", Color3.fromRGB(60, 160, 255), "Ability Slot 2")

-- Divider line
local divider = newFrame({
	size = UDim2.new(0.85, 0, 0, 1),
	pos = UDim2.new(0.5, 0, 0, 156),
	anchor = Vector2.new(0.5, 0),
	color = Color3.fromRGB(60, 60, 80),
	parent = controlsPanel,
	zindex = 12,
})
local divider2 = newFrame({
	size = UDim2.new(0.85, 0, 0, 1),
	pos = UDim2.new(0.5, 0, 0, 270),
	anchor = Vector2.new(0.5, 0),
	color = Color3.fromRGB(60, 60, 80),
	parent = controlsPanel,
	zindex = 12,
})

-- Extra info: Tab + Equip
newLabel({
	size = UDim2.new(0.9, 0, 0, 16),
	pos = UDim2.new(0.5, 0, 1, -8),
	anchor = Vector2.new(0.5, 1),
	text = "[Tab] Equip Menu  |  [C] Close",
	color = Color3.fromRGB(120, 120, 140), textSize = 11,
	parent = controlsPanel, zindex = 12,
})

-- Close controls panel on click
local controlsCloseBtn = newButton({
	size = UDim2.new(0, 28, 0, 28),
	pos = UDim2.new(1, -10, 0, 10),
	anchor = Vector2.new(1, 0),
	color = Color3.fromRGB(80, 30, 30),
	text = "X", textColor = COLOR_WHITE,
	textSize = 14, corner = 14,
	parent = controlsPanel,
})
controlsCloseBtn.ZIndex = 12
controlsCloseBtn.MouseButton1Click:Connect(function()
	controlsPanel.Visible = false
end)

-- Controls button in lobby (bottom-left, next to equip)
local controlsOpenBtn = newButton({
	size = UDim2.new(0, 50, 0, 38),
	pos = UDim2.new(0, 155, 1, -60),
	anchor = Vector2.new(0, 1),
	color = Color3.fromRGB(60, 60, 80),
	transparency = 0.15,
	text = "[C]", textColor = COLOR_WHITE,
	textSize = 15, corner = 10, font = Enum.Font.GothamBlack,
	parent = screenGui,
})
controlsOpenBtn.Name = "ControlsOpenBtn"
controlsOpenBtn.Visible = false

local controlsOpenStroke = Instance.new("UIStroke")
controlsOpenStroke.Color = COLOR_WHITE
controlsOpenStroke.Thickness = 1.5
controlsOpenStroke.Transparency = 0.5
controlsOpenStroke.Parent = controlsOpenBtn

controlsOpenBtn.MouseButton1Click:Connect(function()
	controlsPanel.Visible = not controlsPanel.Visible
	shopPopup.Visible = false
	equipPanel.Visible = false
end)

-- C key to toggle controls panel
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.C and controlsOpenBtn.Visible then
		controlsPanel.Visible = not controlsPanel.Visible
		if controlsPanel.Visible then
			shopPopup.Visible = false
			equipPanel.Visible = false
		end
	end
end)

-- ============================================================
-- BOT DIFFICULTY POPUP (shown when player enters VS BOT zone)
-- ============================================================
local botPopup = newFrame({
	size = UDim2.new(0, 340, 0, 260),
	pos = UDim2.new(0.5, 0, 0.5, 0),
	anchor = Vector2.new(0.5, 0.5),
	color = Color3.fromRGB(20, 20, 35),
	transparency = 0.05,
	corner = 16,
	parent = screenGui,
})
botPopup.Name = "BotDifficultyPopup"
botPopup.Visible = false

local botPopupStroke = Instance.new("UIStroke")
botPopupStroke.Color = COLOR_RED
botPopupStroke.Thickness = 2.5
botPopupStroke.Parent = botPopup

newLabel({
	size = UDim2.new(1, 0, 0, 30),
	pos = UDim2.new(0.5, 0, 0, 15),
	anchor = Vector2.new(0.5, 0),
	text = "VS CPU", color = COLOR_RED, textSize = 26,
	font = Enum.Font.GothamBlack, parent = botPopup,
})

newLabel({
	size = UDim2.new(1, 0, 0, 20),
	pos = UDim2.new(0.5, 0, 0, 48),
	anchor = Vector2.new(0.5, 0),
	text = "Choose Difficulty:", color = COLOR_WHITE, textSize = 16,
	parent = botPopup,
})

local function makeDifficultyButton(label, color, yOffset, value)
	local btn = Instance.new("TextButton")
	btn.Name = value
	btn.Size = UDim2.new(0.8, 0, 0, 40)
	btn.Position = UDim2.new(0.5, 0, 0, yOffset)
	btn.AnchorPoint = Vector2.new(0.5, 0)
	btn.BackgroundColor3 = color
	btn.BackgroundTransparency = 0.15
	btn.Text = label
	btn.TextColor3 = COLOR_WHITE
	btn.TextSize = 20
	btn.Font = Enum.Font.GothamBlack
	btn.TextStrokeTransparency = 0.3
	btn.TextStrokeColor3 = Color3.new(0, 0, 0)
	btn.Parent = botPopup
	btn.Active = true

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = btn

	local stroke = Instance.new("UIStroke")
	stroke.Color = COLOR_WHITE
	stroke.Thickness = 1.5
	stroke.Transparency = 0.5
	stroke.Parent = btn

	-- Show token reward on difficulty buttons
	local reward = Config.TOKEN_REWARDS[value] or 0
	if reward > 0 then
		local rewardLabel = Instance.new("TextLabel")
		rewardLabel.Size = UDim2.new(0, 80, 0, 20)
		rewardLabel.Position = UDim2.new(1, -5, 0.5, 0)
		rewardLabel.AnchorPoint = Vector2.new(1, 0.5)
		rewardLabel.BackgroundTransparency = 1
		rewardLabel.Text = "+" .. reward .. " $"
		rewardLabel.TextColor3 = COLOR_GOLD
		rewardLabel.TextSize = 13
		rewardLabel.Font = Enum.Font.GothamBold
		rewardLabel.TextXAlignment = Enum.TextXAlignment.Right
		rewardLabel.TextStrokeTransparency = 0.3
		rewardLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
		rewardLabel.Parent = btn
	end

	btn.MouseButton1Click:Connect(function()
		print("[PixelBrawl] Selected difficulty: " .. value)
		selectDifficultyEvent:FireServer(value)
		botPopup.Visible = false
	end)

	btn.MouseEnter:Connect(function() btn.BackgroundTransparency = 0 end)
	btn.MouseLeave:Connect(function() btn.BackgroundTransparency = 0.15 end)

	return btn
end

makeDifficultyButton("EASY", Color3.fromRGB(40, 160, 40), 78, "easy")
makeDifficultyButton("MEDIUM", Color3.fromRGB(200, 160, 30), 125, "medium")
makeDifficultyButton("HARD", Color3.fromRGB(200, 40, 40), 172, "hard")

-- Cancel button
local cancelBtn = Instance.new("TextButton")
cancelBtn.Name = "Cancel"
cancelBtn.Size = UDim2.new(0.5, 0, 0, 28)
cancelBtn.Position = UDim2.new(0.5, 0, 0, 222)
cancelBtn.AnchorPoint = Vector2.new(0.5, 0)
cancelBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
cancelBtn.BackgroundTransparency = 0.3
cancelBtn.Text = "CANCEL"
cancelBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
cancelBtn.TextSize = 14
cancelBtn.Font = Enum.Font.GothamBold
cancelBtn.Parent = botPopup

local cancelCorner = Instance.new("UICorner")
cancelCorner.CornerRadius = UDim.new(0, 8)
cancelCorner.Parent = cancelBtn

cancelBtn.MouseButton1Click:Connect(function()
	botPopup.Visible = false
end)

-- ============================================================
-- PVP QUEUE INDICATOR (shown when waiting for opponent)
-- ============================================================
local queueIndicator = newFrame({
	size = UDim2.new(0, 340, 0, 80),
	pos = UDim2.new(0.5, 0, 0.5, 0),
	anchor = Vector2.new(0.5, 0.5),
	color = Color3.fromRGB(20, 15, 35),
	transparency = 0.05,
	corner = 16,
	parent = screenGui,
})
queueIndicator.Name = "QueueIndicator"
queueIndicator.Visible = false

local queueStroke = Instance.new("UIStroke")
queueStroke.Color = COLOR_PURPLE
queueStroke.Thickness = 2.5
queueStroke.Parent = queueIndicator

local queueLabel = newLabel({
	size = UDim2.new(1, 0, 0, 30),
	pos = UDim2.new(0.5, 0, 0, 12),
	anchor = Vector2.new(0.5, 0),
	text = "VS FRIEND", color = COLOR_PURPLE, textSize = 22,
	font = Enum.Font.GothamBlack, parent = queueIndicator,
})

local queueStatus = newLabel({
	size = UDim2.new(1, 0, 0, 20),
	pos = UDim2.new(0.5, 0, 0, 48),
	anchor = Vector2.new(0.5, 0),
	text = "Waiting for opponent...", color = COLOR_WHITE, textSize = 16,
	parent = queueIndicator,
})

-- Animate dots on queue status
local queueDots = 0
local queueAnimRunning = false

local function startQueueAnimation()
	queueAnimRunning = true
	task.spawn(function()
		while queueAnimRunning and queueIndicator.Visible do
			queueDots = (queueDots % 3) + 1
			queueStatus.Text = "Waiting for opponent" .. string.rep(".", queueDots)
			task.wait(0.5)
		end
	end)
end

local function stopQueueAnimation()
	queueAnimRunning = false
end

-- ============================================================
-- SHOP POPUP (shown when player enters shop zone)
-- ============================================================
local shopPopup = newFrame({
	size = UDim2.new(0, 420, 0, 440),
	pos = UDim2.new(0.5, 0, 0.5, 0),
	anchor = Vector2.new(0.5, 0.5),
	color = COLOR_SHOP_BG,
	transparency = 0.02,
	corner = 16,
	parent = screenGui,
	zindex = 10,
})
shopPopup.Name = "ShopPopup"
shopPopup.Visible = false

local shopStroke = Instance.new("UIStroke")
shopStroke.Color = COLOR_GOLD
shopStroke.Thickness = 2.5
shopStroke.Parent = shopPopup

-- Shop title
newLabel({
	size = UDim2.new(1, 0, 0, 35),
	pos = UDim2.new(0.5, 0, 0, 12),
	anchor = Vector2.new(0.5, 0),
	text = "ABILITY SHOP", color = COLOR_GOLD, textSize = 26,
	font = Enum.Font.GothamBlack, parent = shopPopup, zindex = 10,
})

-- Token display inside shop
local shopTokenLabel = newLabel({
	size = UDim2.new(1, 0, 0, 20),
	pos = UDim2.new(0.5, 0, 0, 48),
	anchor = Vector2.new(0.5, 0),
	text = "Your Tokens: 0", color = COLOR_GOLD, textSize = 15,
	font = Enum.Font.GothamBold, parent = shopPopup, zindex = 10,
})

-- Shop item list
local shopScrollFrame = Instance.new("ScrollingFrame")
shopScrollFrame.Size = UDim2.new(0.92, 0, 0, 310)
shopScrollFrame.Position = UDim2.new(0.5, 0, 0, 75)
shopScrollFrame.AnchorPoint = Vector2.new(0.5, 0)
shopScrollFrame.BackgroundTransparency = 1
shopScrollFrame.BorderSizePixel = 0
shopScrollFrame.ScrollBarThickness = 4
shopScrollFrame.ScrollBarImageColor3 = COLOR_GOLD
shopScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0) -- auto-set
shopScrollFrame.ZIndex = 10
shopScrollFrame.Parent = shopPopup

local shopListLayout = Instance.new("UIListLayout")
shopListLayout.SortOrder = Enum.SortOrder.LayoutOrder
shopListLayout.Padding = UDim.new(0, 6)
shopListLayout.Parent = shopScrollFrame

-- Table to hold shop item frames for updating
local shopItemButtons = {}

local function buildShopItems()
	-- Clear old items
	for _, item in ipairs(shopItemButtons) do
		if item.frame then item.frame:Destroy() end
	end
	shopItemButtons = {}

	for displayOrder, abilityKey in ipairs(Config.ShopAbilityOrder) do
		local abilityData = Config.ShopAbilities[abilityKey]
		if not abilityData then continue end

		local owned = false
		for _, inv in ipairs(myInventory) do
			if inv == abilityKey then
				owned = true
				break
			end
		end

		local itemFrame = newFrame({
			size = UDim2.new(1, 0, 0, 56),
			color = Color3.fromRGB(35, 30, 22),
			corner = 8,
			parent = shopScrollFrame,
			zindex = 10,
		})
		itemFrame.LayoutOrder = displayOrder

		local itemStroke = Instance.new("UIStroke")
		itemStroke.Color = abilityData.color
		itemStroke.Thickness = 1.5
		itemStroke.Transparency = 0.3
		itemStroke.Parent = itemFrame

		-- Color bar on left
		local colorBar = newFrame({
			size = UDim2.new(0, 5, 0.8, 0),
			pos = UDim2.new(0, 5, 0.5, 0),
			anchor = Vector2.new(0, 0.5),
			color = abilityData.color,
			corner = 2,
			parent = itemFrame,
			zindex = 10,
		})

		-- Ability name
		newLabel({
			size = UDim2.new(0, 180, 0, 22),
			pos = UDim2.new(0, 18, 0, 4),
			text = abilityData.name, color = COLOR_WHITE, textSize = 16,
			font = Enum.Font.GothamBlack,
			alignX = Enum.TextXAlignment.Left,
			parent = itemFrame, zindex = 10,
		})

		-- Description
		newLabel({
			size = UDim2.new(0, 230, 0, 18),
			pos = UDim2.new(0, 18, 0, 28),
			text = abilityData.description, color = Color3.fromRGB(170, 170, 170), textSize = 11,
			font = Enum.Font.Gotham,
			alignX = Enum.TextXAlignment.Left,
			parent = itemFrame, zindex = 10,
		})

		-- Buy/Owned button
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0, 90, 0, 34)
		btn.Position = UDim2.new(1, -10, 0.5, 0)
		btn.AnchorPoint = Vector2.new(1, 0.5)
		btn.Font = Enum.Font.GothamBlack
		btn.TextStrokeTransparency = 0.3
		btn.TextStrokeColor3 = Color3.new(0, 0, 0)
		btn.Active = true
		btn.ZIndex = 10
		btn.Parent = itemFrame

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 8)
		btnCorner.Parent = btn

		if owned then
			btn.Text = "OWNED"
			btn.BackgroundColor3 = Color3.fromRGB(50, 70, 50)
			btn.TextColor3 = COLOR_GREEN
			btn.TextSize = 13
			btn.BackgroundTransparency = 0.3
		else
			btn.Text = "$" .. abilityData.cost
			btn.BackgroundColor3 = COLOR_GOLD
			btn.TextColor3 = Color3.fromRGB(40, 30, 0)
			btn.TextSize = 16
			btn.BackgroundTransparency = 0.1

			local canAfford = myTokens >= abilityData.cost
			if not canAfford then
				btn.BackgroundColor3 = Color3.fromRGB(80, 60, 30)
				btn.TextColor3 = Color3.fromRGB(120, 100, 60)
				btn.BackgroundTransparency = 0.4
			end

			btn.MouseButton1Click:Connect(function()
				print("[PixelBrawl] Attempting to buy: " .. abilityKey)
				shopPurchaseEvent:FireServer(abilityKey)
			end)

			btn.MouseEnter:Connect(function()
				if myTokens >= abilityData.cost then
					btn.BackgroundTransparency = 0
				end
			end)
			btn.MouseLeave:Connect(function()
				if myTokens >= abilityData.cost then
					btn.BackgroundTransparency = 0.1
				end
			end)
		end

		table.insert(shopItemButtons, {
			frame = itemFrame,
			key = abilityKey,
			btn = btn,
		})
	end

	-- Update canvas size
	shopScrollFrame.CanvasSize = UDim2.new(0, 0, 0, shopListLayout.AbsoluteContentSize.Y + 10)
end

-- Shop close button
local shopCloseBtn = newButton({
	size = UDim2.new(0.6, 0, 0, 32),
	pos = UDim2.new(0.5, 0, 1, -12),
	anchor = Vector2.new(0.5, 1),
	color = Color3.fromRGB(80, 80, 80),
	transparency = 0.2,
	text = "CLOSE", textColor = Color3.fromRGB(200, 200, 200),
	textSize = 14, corner = 8,
	parent = shopPopup,
})
shopCloseBtn.ZIndex = 10

shopCloseBtn.MouseButton1Click:Connect(function()
	shopPopup.Visible = false
end)

-- ============================================================
-- EQUIP PANEL (shown when player clicks equip from lobby)
-- ============================================================
local equipPanel = newFrame({
	size = UDim2.new(0, 400, 0, 380),
	pos = UDim2.new(0.5, 0, 0.5, 0),
	anchor = Vector2.new(0.5, 0.5),
	color = COLOR_EQUIP_BG,
	transparency = 0.02,
	corner = 16,
	parent = screenGui,
	zindex = 10,
})
equipPanel.Name = "EquipPanel"
equipPanel.Visible = false

local equipStroke = Instance.new("UIStroke")
equipStroke.Color = COLOR_BLUE
equipStroke.Thickness = 2.5
equipStroke.Parent = equipPanel

newLabel({
	size = UDim2.new(1, 0, 0, 30),
	pos = UDim2.new(0.5, 0, 0, 12),
	anchor = Vector2.new(0.5, 0),
	text = "EQUIP ABILITIES", color = COLOR_BLUE, textSize = 24,
	font = Enum.Font.GothamBlack, parent = equipPanel, zindex = 10,
})

-- Slot indicators
local slotFrames = {}
for slotIdx = 1, 2 do
	local slotFrame = newFrame({
		size = UDim2.new(0.44, 0, 0, 60),
		pos = UDim2.new(slotIdx == 1 and 0.03 or 0.53, 0, 0, 48),
		color = Color3.fromRGB(25, 30, 45),
		corner = 10,
		parent = equipPanel,
		zindex = 10,
	})

	local slotStroke = Instance.new("UIStroke")
	slotStroke.Color = Color3.fromRGB(80, 100, 140)
	slotStroke.Thickness = 1.5
	slotStroke.Parent = slotFrame

	local keyLabel = newLabel({
		size = UDim2.new(0, 30, 0, 20),
		pos = UDim2.new(0, 8, 0, 5),
		text = slotIdx == 1 and "[Z]" or "[X]", color = COLOR_GOLD, textSize = 12,
		font = Enum.Font.GothamBlack,
		alignX = Enum.TextXAlignment.Left,
		parent = slotFrame, zindex = 10,
	})

	local slotTitle = newLabel({
		size = UDim2.new(0, 60, 0, 20),
		pos = UDim2.new(0, 40, 0, 5),
		text = "SLOT " .. slotIdx, color = Color3.fromRGB(150, 150, 180), textSize = 11,
		alignX = Enum.TextXAlignment.Left,
		parent = slotFrame, zindex = 10,
	})

	local slotAbilityLabel = newLabel({
		size = UDim2.new(0.9, 0, 0, 24),
		pos = UDim2.new(0.5, 0, 0, 28),
		anchor = Vector2.new(0.5, 0),
		text = "- Empty -", color = Color3.fromRGB(100, 100, 120), textSize = 14,
		font = Enum.Font.GothamBold,
		parent = slotFrame, zindex = 10,
	})

	slotFrames[slotIdx] = {
		frame = slotFrame,
		abilityLabel = slotAbilityLabel,
		stroke = slotStroke,
	}
end

-- Owned abilities list for equipping
local equipScrollFrame = Instance.new("ScrollingFrame")
equipScrollFrame.Size = UDim2.new(0.92, 0, 0, 200)
equipScrollFrame.Position = UDim2.new(0.5, 0, 0, 120)
equipScrollFrame.AnchorPoint = Vector2.new(0.5, 0)
equipScrollFrame.BackgroundTransparency = 1
equipScrollFrame.BorderSizePixel = 0
equipScrollFrame.ScrollBarThickness = 4
equipScrollFrame.ScrollBarImageColor3 = COLOR_BLUE
equipScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
equipScrollFrame.ZIndex = 10
equipScrollFrame.Parent = equipPanel

local equipListLayout = Instance.new("UIListLayout")
equipListLayout.SortOrder = Enum.SortOrder.LayoutOrder
equipListLayout.Padding = UDim.new(0, 5)
equipListLayout.Parent = equipScrollFrame

local function updateEquipSlotDisplay()
	for slotIdx = 1, 2 do
		local key = myEquipped[slotIdx]
		local sf = slotFrames[slotIdx]
		if key and Config.ShopAbilities[key] then
			sf.abilityLabel.Text = Config.ShopAbilities[key].name
			sf.abilityLabel.TextColor3 = Config.ShopAbilities[key].color
			sf.stroke.Color = Config.ShopAbilities[key].color
		else
			sf.abilityLabel.Text = "- Empty -"
			sf.abilityLabel.TextColor3 = Color3.fromRGB(100, 100, 120)
			sf.stroke.Color = Color3.fromRGB(80, 100, 140)
		end
	end
end

local function buildEquipList()
	-- Clear old items
	for _, child in ipairs(equipScrollFrame:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end

	updateEquipSlotDisplay()

	if #myInventory == 0 then
		newLabel({
			size = UDim2.new(1, 0, 0, 40),
			pos = UDim2.new(0.5, 0, 0, 20),
			anchor = Vector2.new(0.5, 0),
			text = "No abilities owned yet!\nVisit the SHOP to buy some.",
			color = Color3.fromRGB(140, 140, 140), textSize = 14,
			parent = equipScrollFrame, zindex = 10,
		})
		equipScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 80)
		return
	end

	for i, abilityKey in ipairs(myInventory) do
		local abilityData = Config.ShopAbilities[abilityKey]
		if not abilityData then continue end

		-- Check if already equipped
		local equippedInSlot = nil
		for s = 1, 2 do
			if myEquipped[s] == abilityKey then
				equippedInSlot = s
				break
			end
		end

		local itemFrame = newFrame({
			size = UDim2.new(1, 0, 0, 48),
			color = Color3.fromRGB(30, 35, 50),
			corner = 8,
			parent = equipScrollFrame,
			zindex = 10,
		})
		itemFrame.LayoutOrder = i

		-- Color bar
		newFrame({
			size = UDim2.new(0, 4, 0.7, 0),
			pos = UDim2.new(0, 6, 0.5, 0),
			anchor = Vector2.new(0, 0.5),
			color = abilityData.color,
			corner = 2,
			parent = itemFrame, zindex = 10,
		})

		-- Name
		newLabel({
			size = UDim2.new(0, 150, 0, 24),
			pos = UDim2.new(0, 18, 0.5, 0),
			anchor = Vector2.new(0, 0.5),
			text = abilityData.name, color = COLOR_WHITE, textSize = 15,
			font = Enum.Font.GothamBold,
			alignX = Enum.TextXAlignment.Left,
			parent = itemFrame, zindex = 10,
		})

		if equippedInSlot then
			-- Show which slot
			local slotLabel = newLabel({
				size = UDim2.new(0, 80, 0, 24),
				pos = UDim2.new(1, -10, 0.5, 0),
				anchor = Vector2.new(1, 0.5),
				text = "SLOT " .. equippedInSlot,
				color = abilityData.color, textSize = 13,
				font = Enum.Font.GothamBlack,
				parent = itemFrame, zindex = 10,
			})
		else
			-- Slot 1 button
			local s1Btn = newButton({
				size = UDim2.new(0, 55, 0, 30),
				pos = UDim2.new(1, -125, 0.5, 0),
				anchor = Vector2.new(0, 0.5),
				color = Color3.fromRGB(50, 60, 90),
				text = "Slot 1", textColor = COLOR_WHITE,
				textSize = 12, corner = 6,
				parent = itemFrame,
			})
			s1Btn.ZIndex = 10
			s1Btn.MouseButton1Click:Connect(function()
				equipAbilityEvent:FireServer(abilityKey, 1)
			end)

			-- Slot 2 button
			local s2Btn = newButton({
				size = UDim2.new(0, 55, 0, 30),
				pos = UDim2.new(1, -62, 0.5, 0),
				anchor = Vector2.new(0, 0.5),
				color = Color3.fromRGB(50, 60, 90),
				text = "Slot 2", textColor = COLOR_WHITE,
				textSize = 12, corner = 6,
				parent = itemFrame,
			})
			s2Btn.ZIndex = 10
			s2Btn.MouseButton1Click:Connect(function()
				equipAbilityEvent:FireServer(abilityKey, 2)
			end)
		end
	end

	equipScrollFrame.CanvasSize = UDim2.new(0, 0, 0, equipListLayout.AbsoluteContentSize.Y + 10)
end

-- Equip close button
local equipCloseBtn = newButton({
	size = UDim2.new(0.6, 0, 0, 32),
	pos = UDim2.new(0.5, 0, 1, -12),
	anchor = Vector2.new(0.5, 1),
	color = Color3.fromRGB(80, 80, 80),
	transparency = 0.2,
	text = "CLOSE", textColor = Color3.fromRGB(200, 200, 200),
	textSize = 14, corner = 8,
	parent = equipPanel,
})
equipCloseBtn.ZIndex = 10

equipCloseBtn.MouseButton1Click:Connect(function()
	equipPanel.Visible = false
end)

-- ============================================================
-- EQUIP BUTTON (small button in lobby, bottom-left area)
-- ============================================================
local equipOpenBtn = newButton({
	size = UDim2.new(0, 130, 0, 38),
	pos = UDim2.new(0, 15, 1, -60),
	anchor = Vector2.new(0, 1),
	color = COLOR_BLUE,
	transparency = 0.15,
	text = "EQUIP [Tab]", textColor = COLOR_WHITE,
	textSize = 15, corner = 10, font = Enum.Font.GothamBlack,
	parent = screenGui,
})
equipOpenBtn.Name = "EquipOpenBtn"
equipOpenBtn.Visible = false

local equipOpenStroke = Instance.new("UIStroke")
equipOpenStroke.Color = COLOR_WHITE
equipOpenStroke.Thickness = 1.5
equipOpenStroke.Transparency = 0.5
equipOpenStroke.Parent = equipOpenBtn

equipOpenBtn.MouseButton1Click:Connect(function()
	if equipPanel.Visible then
		equipPanel.Visible = false
	else
		buildEquipList()
		equipPanel.Visible = true
		shopPopup.Visible = false
	end
end)

-- Tab key to toggle equip panel
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.Tab and equipOpenBtn.Visible then
		if equipPanel.Visible then
			equipPanel.Visible = false
		else
			buildEquipList()
			equipPanel.Visible = true
			shopPopup.Visible = false
		end
	end
end)

-- ============================================================
-- ABILITY INDICATORS (shown during fight, bottom-center)
-- ============================================================
local abilityIndicatorFrame = newFrame({
	size = UDim2.new(0, 200, 0, 50),
	pos = UDim2.new(0.5, 0, 1, -15),
	anchor = Vector2.new(0.5, 1),
	color = Color3.new(0, 0, 0),
	transparency = 0.7,
	corner = 10,
	parent = screenGui,
})
abilityIndicatorFrame.Name = "AbilityIndicators"
abilityIndicatorFrame.Visible = false

local abilitySlotLabels = {}
for slotIdx = 1, 2 do
	local slotBG = newFrame({
		size = UDim2.new(0, 85, 0, 36),
		pos = UDim2.new(0, slotIdx == 1 and 10 or 105, 0.5, 0),
		anchor = Vector2.new(0, 0.5),
		color = Color3.fromRGB(30, 30, 40),
		corner = 6,
		parent = abilityIndicatorFrame,
	})

	local slotKey = newLabel({
		size = UDim2.new(0, 22, 0, 22),
		pos = UDim2.new(0, 4, 0.5, 0),
		anchor = Vector2.new(0, 0.5),
		text = slotIdx == 1 and "Z" or "X", color = COLOR_GOLD, textSize = 12,
		font = Enum.Font.GothamBlack, parent = slotBG,
	})

	local abilityName = newLabel({
		size = UDim2.new(0, 55, 0, 20),
		pos = UDim2.new(0, 28, 0.5, 0),
		anchor = Vector2.new(0, 0.5),
		text = "-", color = COLOR_WHITE, textSize = 10,
		font = Enum.Font.GothamBold,
		alignX = Enum.TextXAlignment.Left,
		parent = slotBG,
	})

	abilitySlotLabels[slotIdx] = {
		bg = slotBG,
		nameLabel = abilityName,
	}
end

local function updateAbilityIndicators()
	local hasAny = false
	for slotIdx = 1, 2 do
		local key = myEquipped[slotIdx]
		local slot = abilitySlotLabels[slotIdx]
		if key and Config.ShopAbilities[key] then
			slot.nameLabel.Text = Config.ShopAbilities[key].name
			slot.nameLabel.TextColor3 = Config.ShopAbilities[key].color
			slot.bg.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
			hasAny = true
		else
			slot.nameLabel.Text = "-"
			slot.nameLabel.TextColor3 = Color3.fromRGB(80, 80, 80)
			slot.bg.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
		end
	end
	return hasAny
end

-- ============================================================
-- FLOATING TOKEN REWARD MESSAGE
-- ============================================================
local function showTokenReward(amount)
	coinSFX:Play()
	local floatLabel = Instance.new("TextLabel")
	floatLabel.Size = UDim2.new(0, 200, 0, 40)
	floatLabel.Position = UDim2.new(0.5, 0, 0.55, 0)
	floatLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	floatLabel.BackgroundTransparency = 1
	floatLabel.Text = "+" .. amount .. " TOKENS!"
	floatLabel.TextColor3 = COLOR_GOLD
	floatLabel.TextSize = 28
	floatLabel.Font = Enum.Font.GothamBlack
	floatLabel.TextStrokeTransparency = 0.2
	floatLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	floatLabel.Parent = screenGui

	-- Float up and fade out
	local tweenUp = TweenService:Create(floatLabel, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0.4, 0),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	tweenUp:Play()
	tweenUp.Completed:Connect(function()
		floatLabel:Destroy()
	end)
end

-- ============================================================
-- SHOP RESULT MESSAGE (purchase feedback)
-- ============================================================
local function showShopResult(success, msg)
	if success then
		buySFX:Play()
	end

	-- Flash message on shop popup
	local flashLabel = Instance.new("TextLabel")
	flashLabel.Size = UDim2.new(0.9, 0, 0, 24)
	flashLabel.Position = UDim2.new(0.5, 0, 1, -48)
	flashLabel.AnchorPoint = Vector2.new(0.5, 1)
	flashLabel.BackgroundTransparency = 1
	flashLabel.Text = msg or (success and "Purchase successful!" or "Purchase failed")
	flashLabel.TextColor3 = success and COLOR_GREEN or COLOR_RED
	flashLabel.TextSize = 14
	flashLabel.Font = Enum.Font.GothamBold
	flashLabel.TextStrokeTransparency = 0.3
	flashLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	flashLabel.ZIndex = 11
	flashLabel.Parent = shopPopup

	task.delay(2.5, function()
		if flashLabel.Parent then flashLabel:Destroy() end
	end)
end

-- ============================================================
-- MOBILE TOUCH CONTROLS
-- ============================================================
local touchFrame = nil

if isMobile then
	touchFrame = Instance.new("Frame")
	touchFrame.Name = "TouchControls"
	touchFrame.Size = UDim2.new(1, 0, 1, 0)
	touchFrame.BackgroundTransparency = 1
	touchFrame.Parent = screenGui
	touchFrame.Visible = false

	local function makeTouchButton(name, label, size, pos, anchor, color, action)
		local btn = Instance.new("TextButton")
		btn.Name = name
		btn.Size = size
		btn.Position = pos
		btn.AnchorPoint = anchor or Vector2.new(0, 0)
		btn.BackgroundColor3 = color or Color3.fromRGB(80, 80, 80)
		btn.BackgroundTransparency = 0.4
		btn.Text = label
		btn.TextColor3 = COLOR_WHITE
		btn.TextSize = 18
		btn.Font = Enum.Font.GothamBold
		btn.TextStrokeTransparency = 0.5
		btn.Parent = touchFrame
		btn.Active = true

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = btn

		local stroke = Instance.new("UIStroke")
		stroke.Color = COLOR_WHITE
		stroke.Thickness = 1.5
		stroke.Transparency = 0.5
		stroke.Parent = btn

		btn.MouseButton1Down:Connect(function()
			touchInput[action] = true
			btn.BackgroundTransparency = 0.1
		end)
		btn.MouseButton1Up:Connect(function()
			touchInput[action] = false
			btn.BackgroundTransparency = 0.4
		end)

		btn.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				touchInput[action] = true
				btn.BackgroundTransparency = 0.1
			end
		end)
		btn.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				touchInput[action] = false
				btn.BackgroundTransparency = 0.4
			end
		end)

		return btn
	end

	local btnSize = UDim2.new(0, 65, 0, 65)
	local dpadY = 0.72

	-- D-PAD (bottom left)
	makeTouchButton("Left", "<", btnSize,
		UDim2.new(0, 15, dpadY, 0), Vector2.new(0, 0),
		Color3.fromRGB(70, 70, 90), "left")

	makeTouchButton("Right", ">", btnSize,
		UDim2.new(0, 145, dpadY, 0), Vector2.new(0, 0),
		Color3.fromRGB(70, 70, 90), "right")

	makeTouchButton("Jump", "JUMP", UDim2.new(0, 130, 0, 50),
		UDim2.new(0, 15, dpadY, -58), Vector2.new(0, 0),
		Color3.fromRGB(70, 90, 70), "jump")

	makeTouchButton("Block", "BLOCK", UDim2.new(0, 130, 0, 50),
		UDim2.new(0, 15, dpadY, 72), Vector2.new(0, 0),
		Color3.fromRGB(90, 90, 50), "block")

	-- ATTACK BUTTONS (bottom right)
	local atkBtnSize = UDim2.new(0, 75, 0, 75)

	makeTouchButton("Punch", "PUNCH", atkBtnSize,
		UDim2.new(1, -165, dpadY, -20), Vector2.new(0, 0),
		Color3.fromRGB(180, 60, 60), "punch")

	makeTouchButton("Kick", "KICK", atkBtnSize,
		UDim2.new(1, -80, dpadY, -20), Vector2.new(0, 0),
		Color3.fromRGB(60, 100, 180), "kick")

	makeTouchButton("Special", "SPECIAL", UDim2.new(0, 160, 0, 50),
		UDim2.new(1, -165, dpadY, 62), Vector2.new(0, 0),
		Color3.fromRGB(160, 120, 30), "special")

	-- ABILITY BUTTONS (above attack buttons)
	makeTouchButton("Ability1", "ABIL 1", UDim2.new(0, 75, 0, 50),
		UDim2.new(1, -165, dpadY, -78), Vector2.new(0, 0),
		Color3.fromRGB(200, 100, 30), "ability1")

	makeTouchButton("Ability2", "ABIL 2", UDim2.new(0, 75, 0, 50),
		UDim2.new(1, -80, dpadY, -78), Vector2.new(0, 0),
		Color3.fromRGB(30, 120, 200), "ability2")
end

-- ============================================================
-- MESSAGE SYSTEM
-- ============================================================
local messageClear = nil

local function showMessage(text, color, duration, sub)
	centerLabel.Text = text
	centerLabel.TextColor3 = color or COLOR_WHITE
	centerLabel.TextSize = 48
	subLabel.Text = sub or ""

	centerLabel.TextTransparency = 1
	TweenService:Create(centerLabel, TweenInfo.new(0.2), { TextTransparency = 0 }):Play()

	if sub then
		subLabel.TextTransparency = 1
		TweenService:Create(subLabel, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
	end

	if messageClear then task.cancel(messageClear) end
	messageClear = task.delay(duration or 2, function()
		TweenService:Create(centerLabel, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		TweenService:Create(subLabel, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
	end)
end

-- ============================================================
-- HUD UPDATE
-- ============================================================
local function getHealthColor(ratio)
	if ratio > 0.5 then return COLOR_GREEN
	elseif ratio > 0.25 then return COLOR_YELLOW
	else return COLOR_RED end
end

local function updateHUD(state)
	if not state or not state.fighters or #state.fighters < 2 then return end

	local f1 = state.fighters[1]
	local f2 = state.fighters[2]

	p1NameLabel.Text = f1.name or "P1"
	p2NameLabel.Text = f2.name or "P2"

	local h1 = math.clamp(f1.health / Config.MAX_HEALTH, 0, 1)
	local h2 = math.clamp(f2.health / Config.MAX_HEALTH, 0, 1)

	p1BarFill.Size = UDim2.new(h1, 0, 1, 0)
	p1BarFill.BackgroundColor3 = getHealthColor(h1)
	p2BarFill.Size = UDim2.new(h2, 0, 1, 0)
	p2BarFill.BackgroundColor3 = getHealthColor(h2)

	timerLabel.Text = tostring(math.ceil(state.roundTimer or 60))
	timerLabel.TextColor3 = (state.roundTimer or 60) <= 10 and COLOR_RED or COLOR_WHITE

	roundLabel.Text = "ROUND " .. (state.currentRound or 1)

	for i, dot in ipairs(p1Dots) do
		dot.BackgroundColor3 = i <= (f1.roundWins or 0) and COLOR_GOLD or Color3.fromRGB(60,60,60)
	end
	for i, dot in ipairs(p2Dots) do
		dot.BackgroundColor3 = i <= (f2.roundWins or 0) and COLOR_GOLD or Color3.fromRGB(60,60,60)
	end
end

-- ============================================================
-- HELPER: show/hide lobby UI
-- ============================================================
local function showLobbyUI()
	lobbyBanner.Visible = true
	controlsHint.Visible = true
	tokenFrame.Visible = true
	equipOpenBtn.Visible = true
	controlsOpenBtn.Visible = true
	hudFrame.Visible = false
	botPopup.Visible = false
	queueIndicator.Visible = false
	shopPopup.Visible = false
	equipPanel.Visible = false
	controlsPanel.Visible = false
	abilityIndicatorFrame.Visible = false
	stopQueueAnimation()
	if touchFrame then touchFrame.Visible = false end
end

local function hideLobbyUI()
	lobbyBanner.Visible = false
	controlsHint.Visible = false
	botPopup.Visible = false
	queueIndicator.Visible = false
	shopPopup.Visible = false
	equipPanel.Visible = false
	equipOpenBtn.Visible = false
	controlsOpenBtn.Visible = false
	controlsPanel.Visible = false
	stopQueueAnimation()
end

-- ============================================================
-- EVENT HANDLERS
-- ============================================================
gameStateEvent.OnClientEvent:Connect(function(state)
	updateHUD(state)
	if state.phase == Config.Phases.COUNTDOWN then
		local t = math.ceil(state.phaseTimer or 0)
		if t > 0 then
			local prevText = centerLabel.Text
			centerLabel.Text = tostring(t)
			centerLabel.TextColor3 = COLOR_WHITE
			centerLabel.TextTransparency = 0
			subLabel.Text = "ROUND " .. (state.currentRound or 1)
			subLabel.TextTransparency = 0
			if prevText ~= tostring(t) then
				countdownBeep:Play()
			end
		end
	end
end)

gameEventEvent.OnClientEvent:Connect(function(eventType, data)
	if eventType == "enterLobby" then
		-- Player returned to lobby (or initial spawn)
		hideLobbyUI()
		showLobbyUI()
		playMenuMusic()

	elseif eventType == "enteredBotZone" then
		-- Player walked into VS BOT portal ‚Äî show difficulty popup
		botPopup.Visible = true
		queueIndicator.Visible = false
		shopPopup.Visible = false
		equipPanel.Visible = false
		controlsPanel.Visible = false
		stopQueueAnimation()

	elseif eventType == "queued" then
		-- Player walked into VS FRIEND portal ‚Äî show queue indicator
		botPopup.Visible = false
		shopPopup.Visible = false
		equipPanel.Visible = false
		controlsPanel.Visible = false
		queueIndicator.Visible = true
		startQueueAnimation()

	elseif eventType == "queueCancelled" then
		-- Player walked away from VS FRIEND zone
		queueIndicator.Visible = false
		stopQueueAnimation()

	elseif eventType == "enteredShopZone" then
		-- Player walked into SHOP portal ‚Äî show shop popup
		botPopup.Visible = false
		queueIndicator.Visible = false
		equipPanel.Visible = false
		controlsPanel.Visible = false
		stopQueueAnimation()
		shopTokenLabel.Text = "Your Tokens: " .. tostring(myTokens)
		buildShopItems()
		shopPopup.Visible = true

	elseif eventType == "matchStart" then
		-- Entering a fight
		hideLobbyUI()
		tokenFrame.Visible = false
		hudFrame.Visible = true
		if touchFrame then touchFrame.Visible = true end
		-- Show ability indicators if player has equipped abilities
		local hasAbilities = updateAbilityIndicators()
		abilityIndicatorFrame.Visible = hasAbilities
		showMessage("VS " .. (data.opponentName or "???"), COLOR_WHITE, 2)
		playBattleMusic()

	elseif eventType == "fight" then
		showMessage("FIGHT!", COLOR_GOLD, 1.5)
		fightShout:Play()

	elseif eventType == "hit" then
		if data and data.attackType == "kick" then
			kickSound:Play()
		else
			punchSound:Play()
		end

	elseif eventType == "roundEnd" then
		showMessage("K.O.!", COLOR_RED, 2.5)
		koSound:Play()

	elseif eventType == "newRound" then
		showMessage("ROUND " .. (data.round or "?"), COLOR_WHITE, 1.5, "GET READY")

	elseif eventType == "matchEnd" then
		local color = data.winnerName == player.Name and COLOR_GOLD or COLOR_RED
		showMessage(data.winnerName .. " WINS!", color, 4, "Match Over")
		stopAllMusic()
		winSound:Play()
		abilityIndicatorFrame.Visible = false
		-- Just hide fight UI; server will send "enterLobby" after teleport
		task.delay(4, function()
			hudFrame.Visible = false
			if touchFrame then touchFrame.Visible = false end
		end)

	elseif eventType == "opponentLeft" then
		showMessage("OPPONENT LEFT", COLOR_YELLOW, 2)

	elseif eventType == "tokenUpdate" then
		-- Server synced token count
		myTokens = data.tokens or 0
		updateTokenDisplay()
		if shopPopup.Visible then
			shopTokenLabel.Text = "Your Tokens: " .. tostring(myTokens)
			buildShopItems()
		end

	elseif eventType == "inventoryUpdate" then
		-- Server synced inventory and equipped abilities
		myInventory = data.inventory or {}
		myEquipped = { data.equipped1, data.equipped2 }
		updateAbilityIndicators()
		if equipPanel.Visible then
			buildEquipList()
		end
		if shopPopup.Visible then
			buildShopItems()
		end

	elseif eventType == "tokenReward" then
		-- Floating "+X tokens!" after winning a bot fight
		local amount = data.amount or 0
		if amount > 0 then
			showTokenReward(amount)
		end

	elseif eventType == "shopResult" then
		-- Purchase feedback
		local success = data.success or false
		local msg = data.message or ""
		showShopResult(success, msg)
		-- Rebuild shop items after purchase
		if shopPopup.Visible then
			task.delay(0.2, function()
				buildShopItems()
			end)
		end
	end
end)

-- ============================================================
-- INITIAL STATE ‚Äî lobby banner visible, everything else hidden
-- ============================================================
lobbyBanner.Visible = true
controlsHint.Visible = true
tokenFrame.Visible = true
equipOpenBtn.Visible = true
controlsOpenBtn.Visible = true
hudFrame.Visible = false
botPopup.Visible = false
queueIndicator.Visible = false
shopPopup.Visible = false
equipPanel.Visible = false
controlsPanel.Visible = false
abilityIndicatorFrame.Visible = false
if touchFrame then touchFrame.Visible = false end
centerLabel.TextTransparency = 1
subLabel.TextTransparency = 1

print("[PixelBrawl] HUD loaded! Mobile controls: " .. tostring(isMobile))
