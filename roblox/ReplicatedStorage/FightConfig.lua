--[[
	FightConfig - Shared constants for Pixel Brawl
	LOCATION: ReplicatedStorage > FightConfig (ModuleScript)
]]

local Config = {}

-- General
Config.MAX_HEALTH = 200  -- Doubled from 100 for longer battles
Config.ROUND_TIME = 90  -- Increased from 60 for longer rounds
Config.ROUNDS_TO_WIN = 2
Config.COUNTDOWN_TIME = 3
Config.ROUND_END_DELAY = 3
Config.MATCH_END_DELAY = 5

-- Movement
Config.MOVE_SPEED = 32
Config.JUMP_FORCE = 50
Config.ARENA_MIN_X = -50
Config.ARENA_MAX_X = 50
Config.GROUND_Y = 3

-- Lobby
Config.LOBBY_SPAWN = Vector3.new(0, 2, 300)
Config.ZONE_VS_BOT = Vector3.new(-30, 2, 285)
Config.ZONE_VS_FRIEND = Vector3.new(30, 2, 285)
Config.ZONE_SHOP = Vector3.new(0, 2, 265)
Config.ZONE_RADIUS = 8

-- Token rewards (bot wins only)
Config.TOKEN_REWARDS = { easy = 10, medium = 25, hard = 50 }

-- Player states
Config.PlayerStates = {
	LOBBY = "lobby",
	IN_MATCH = "inMatch",
	QUEUED = "queued",
}

-- Block
Config.BLOCK_REDUCTION = 0.25
Config.BLOCK_KNOCKBACK_MULT = 0.3

-- Attack data: { damage, range, startup, active, recovery, knockback, hitstun }
Config.Attacks = {
	punch = {
		damage = 8,
		range = 6,
		startup = 0.05,
		active = 0.07,
		recovery = 0.13,
		knockback = 6,
		hitstun = 0.2,
		isProjectile = false,
	},
	kick = {
		damage = 14,
		range = 8,
		startup = 0.1,
		active = 0.08,
		recovery = 0.2,
		knockback = 10,
		hitstun = 0.3,
		isProjectile = false,
	},
	special = {
		damage = 20,
		range = 0,
		startup = 0.2,
		active = 0,
		recovery = 0.33,
		knockback = 14,
		hitstun = 0.35,
		isProjectile = true,
		projectileSpeed = 60,
		projectileLifetime = 2,
	},
}

-- Shop abilities (purchasable combat moves)
Config.ShopAbilities = {
	dashPunch = {
		name = "Dash Punch",
		cost = 50,
		description = "Fast forward lunge + punch",
		color = Color3.fromRGB(255, 120, 40),
	},
	uppercut = {
		name = "Uppercut",
		cost = 75,
		description = "Powerful upward strike, launches enemy",
		color = Color3.fromRGB(80, 200, 255),
	},
	spinKick = {
		name = "Spin Kick",
		cost = 75,
		description = "360 kick, hits from both sides",
		color = Color3.fromRGB(100, 255, 100),
	},
	fireball = {
		name = "Fireball",
		cost = 100,
		description = "Powerful fire projectile",
		color = Color3.fromRGB(255, 60, 30),
	},
	groundSlam = {
		name = "Ground Slam",
		cost = 150,
		description = "Jump slam with AoE shockwave",
		color = Color3.fromRGB(180, 100, 255),
	},
}

-- Ability attack data (same format as Config.Attacks)
Config.AbilityAttacks = {
	dashPunch = {
		damage = 12,
		range = 14,
		startup = 0.12,
		active = 0.1,
		recovery = 0.2,
		knockback = 12,
		hitstun = 0.25,
		isProjectile = false,
		dashSpeed = 55,
	},
	uppercut = {
		damage = 16,
		range = 7,
		startup = 0.1,
		active = 0.08,
		recovery = 0.25,
		knockback = 10,
		hitstun = 0.3,
		isProjectile = false,
		launchVY = 30,
	},
	spinKick = {
		damage = 12,
		range = 10,
		startup = 0.12,
		active = 0.1,
		recovery = 0.22,
		knockback = 8,
		hitstun = 0.25,
		isProjectile = false,
		hitsBothSides = true,
	},
	fireball = {
		damage = 25,
		range = 0,
		startup = 0.25,
		active = 0,
		recovery = 0.35,
		knockback = 16,
		hitstun = 0.4,
		isProjectile = true,
		projectileSpeed = 70,
		projectileLifetime = 2.5,
	},
	groundSlam = {
		damage = 22,
		range = 12,
		startup = 0.3,
		active = 0.15,
		recovery = 0.4,
		knockback = 14,
		hitstun = 0.35,
		isProjectile = false,
		isAoE = true,
	},
}

-- Ordered list for shop display
Config.ShopAbilityOrder = { "dashPunch", "uppercut", "spinKick", "fireball", "groundSlam" }

-- State names
Config.States = {
	IDLE = "idle",
	WALK = "walk",
	JUMP = "jump",
	PUNCH = "punch",
	KICK = "kick",
	SPECIAL = "special",
	BLOCK = "block",
	HITSTUN = "hitstun",
	KO = "ko",
	ABILITY1 = "ability1",
	ABILITY2 = "ability2",
}

-- Game phases
Config.Phases = {
	WAITING = "waiting",
	COUNTDOWN = "countdown",
	FIGHTING = "fighting",
	ROUND_END = "roundEnd",
	MATCH_END = "matchEnd",
}

-- Remote event names
Config.Remotes = {
	SEND_INPUT = "SendInput",
	GAME_STATE = "GameState",
	GAME_EVENT = "GameEvent",
	SELECT_DIFFICULTY = "SelectDifficulty",
	SHOP_PURCHASE = "ShopPurchase",
	EQUIP_ABILITY = "EquipAbility",
}

return Config
