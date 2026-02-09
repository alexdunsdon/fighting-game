# CLAUDE.md — fighting-game

## What it is
"Pixel Brawl" — a Street Fighter-style 2D fighting game with two implementations: a standalone web version and a Roblox multiplayer version.

---

## Web Version (`index.html`)

### Tech
- Vanilla JS, HTML5 Canvas, single self-contained file (~1184 lines)
- Internal resolution 480x270, upscaled with `image-rendering: crisp-edges`
- Offscreen canvas buffer for pixel-perfect rendering
- Web Audio API (oscillator-based SFX, no samples)
- No dependencies, no build step — just open in a browser

### Game States
`title` → `controls` → `countdown` → `fight` → `roundEnd` → `matchEnd`

### Characters
- **RYU** (P1): Red/brown gi, spiky hair, red headband
- **KEN** (P2): Blue gi, long black hair, blue headband
- Same moveset, different palettes; procedurally drawn (no sprites)

### Controls

| Action  | Player 1 | Player 2    |
|---------|----------|-------------|
| Left    | A        | Arrow Left  |
| Right   | D        | Arrow Right |
| Jump    | W        | Arrow Up    |
| Block   | S (hold) | Arrow Down  |
| Punch   | F        | ;           |
| Kick    | G        | '           |
| Special | H        | Enter       |

### Combat System
- State machine: idle, walk, jump, punch, kick, special, block, hitstun, ko
- Frame-based attacks: startup → active → recovery
- Punch: 8 dmg, 40px range | Kick: 14 dmg, 50px range | Special: 20 dmg (projectile)
- Block: 25% damage reduction, 30% knockback reduction
- Projectiles: 5px/frame, 80-frame lifetime

### AI (3 Difficulties)
- **Easy**: 30% aggression, 10% block, 30-frame reaction delay
- **Medium**: 55% aggression, 35% block, 15-frame reaction delay
- **Hard**: 80% aggression, 60% block, 6-frame reaction delay

### Game Balance
- 100 HP per fighter, 60-second rounds, best of 3 rounds
- Screen shake on hits (5–8px, decays at 0.85/frame)
- Particle effects: 6–10 per hit, 25-frame lifetime

### Physics
- Ground Y: 220px, gravity: 0.6/frame, jump: -10/frame, move speed: 3/frame
- Arena bounds: X=[20, 460]

---

## Roblox Version (`roblox/`)

### Tech
- Lua scripts, server-authoritative architecture
- Python 3 build script generates `.rbxlx` from Lua sources

### Commands
```bash
python3 roblox/generate_rbxlx.py   # Outputs roblox/PixelBrawl.rbxlx
```

### Script Organization
| File | Location | Purpose |
|------|----------|---------|
| `FightConfig.lua` | ReplicatedStorage | Shared constants, attack defs, remote event names |
| `FightServer.server.lua` | ServerScriptService | Arena gen, match management, AI, combat sim, tokens/shop |
| `FightClient.client.lua` | StarterPlayerScripts | Input (keyboard + mobile), camera, VFX, screen shake |
| `FightHUD.client.lua` | StarterGui | All UI, music/SFX, game event handlers |
| `generate_rbxlx.py` | roblox/ | Embeds Lua into Roblox XML via CDATA sections |

### Key Constants (FightConfig)
- `MAX_HEALTH=100`, `ROUND_TIME=60`, `ROUNDS_TO_WIN=2`
- `MOVE_SPEED=32` studs/s, `JUMP_FORCE=50`, `GRAVITY=120` studs/s²
- Arena X bounds: [-50, 50] studs

### Networking (RemoteEvents)
- `SendInput` — Client → Server (player input state)
- `GameState` — Server → Client (positions, health, phase) ~60Hz
- `GameEvent` — Server → Client (matchStart, roundEnd, tokenReward, etc.)
- `SelectDifficulty` — Client → Server
- `ShopPurchase` / `EquipAbility` — Client → Server

### Roblox-Only Features
- **Token economy**: Earn tokens by beating AI (Easy=10, Medium=25, Hard=50)
- **Shop abilities** (5 purchasable moves): dashPunch, uppercut, spinKick, fireball, groundSlam
- **PVP queue**: Player-vs-player matchmaking
- **Lobby (Dojo)**: 3 portal zones — VS BOT, VS FRIEND, SHOP
- **Mobile touch controls**: D-pad + attack buttons

### Player States
`LOBBY` → `QUEUED` → `IN_MATCH`

---

## Architecture Notes

- Both versions share identical combat balance values and state machine design
- Web version is frame-based (60fps); Roblox version is delta-time based
- All rendering is procedural — no sprite assets in either version
- Roblox arena, dojo, and fighter models are built from code (Parts, not meshes)

## Conventions
- Web: everything in one file, no modules or bundling
- Roblox: one config + one server + two client scripts, flat hierarchy
- No test framework, no CI/CD
- No external assets or CDN dependencies
