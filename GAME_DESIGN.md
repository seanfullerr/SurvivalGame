# Chaos Bomb Survival v4 — Game Design Document

## 1. CORE LOOP

**Session flow:**

1. **New Game** — Fresh 5-layer map builds. Game spawns activate on transparent platform.
2. **Ready Mode** (6s) — All players spawn on glass platform at Y=12 above the map. "ROUND X — Get ready!"
3. **Drop** — Platform vanishes. Players freefall onto grass terrain.
4. **Survive** (50s) — Bombs rain down. Terrain breaks layer by layer. Bedrock holds.
5. **Results** (4s) — Survivor count. If survivors exist → next round (map stays damaged, difficulty up).
6. **Game Over** — When ALL players die: "GAME OVER! Lasted X rounds!" → full map regen → restart.

**Key rule:** Map only regenerates when everyone is eliminated. Continuous rounds until then.

---

## 2. TWO SPAWN MODES

**Lobby spawns** (waiting/not-in-game): 8 SpawnLocations around the map edges on the plain lobby floor. Enabled between games.

**Game spawns** (game-ready, DEFAULT): 4 SpawnLocations on a transparent glass platform at Y=12 above the arena center. Enabled during active rounds. Players drop to terrain when round starts.

---

## 3. 5-LAYER TERRAIN + BEDROCK

| Layer | Name | Material | Y Center | Destructible? |
|-------|------|----------|----------|---------------|
| 1 | Grass | Grass | Y = 2.5 | Yes |
| 2 | Soil | Ground | Y = -2.5 | Yes |
| 3 | Stone | Slate | Y = -7.5 | Yes |
| 4 | Deep Stone | Basalt | Y = -12.5 | Yes |
| 5 | **Bedrock** | Slate (dark) | Y = -17.5 | **NO — indestructible** |

**Grid:** 20×20 tiles × 5 layers = 2000 total tiles. Bedrock (400 tiles) never breaks — players can never fall through the map.

**Destruction:** `MapManager.DestroyAt()` only destroys layers 1–4. Layer 5 is always skipped.

---

## 4. LOBBY AREA

Plain grey concrete surrounding the arena, flush with grass top surface. No lighting effects, no decoration — just a simple wait area. Visually distinct from the colorful game zone by being intentionally plain.

---

## 5. BOMB SYSTEM

**Model:** Cartoon bomb (dark sphere body + brown fuse nub + glowing orange spark with ParticleEmitter + PointLight). Stored as BombTemplate in ServerStorage.

**Lifecycle:** Growing pulsing shadow (90%) → Bomb clone at Y=90 → Quad-In tween fall → Explosion + damage + terrain destruction + BombLanded event → Yellow flash → Cleanup.

**10% surprise bombs** with no warning shadow.

**Difficulty scaling:** Round 1 = 1.0× (bombs every ~1.5s). Increases +0.25× per round.

---

## 6. GAME FEEL

1. Growing pulsing red shadow warnings before impact
2. Smooth Quad-In tweened falls (no physics jitter)
3. Cartoon bomb with glowing fuse + spark particles
4. Damage screen shake (scales with hit strength)
5. Nearby bomb rumble within 60 studs
6. Red damage flash overlay
7. Terrain chunks fling outward on destruction
8. "ELIMINATED!" death text with Back easing
9. Difficulty bar grows across rounds
10. "Drop into chaos" platform moment each round
11. "GAME OVER" screen with round count when all eliminated

---

## 7. PROJECT HIERARCHY

```
Workspace/
  Map/ (Layer1[400] + Layer2[400] + Layer3[400] + Layer4[400] + Layer5[400]=bedrock)
  Lobby/ (4 plain concrete floor strips)
  LobbySpawns/ (8 SpawnLocations around edges, disabled during game)
  SpawnPlatform (transparent glass at Y=12)
  GameSpawns/ (4 SpawnLocations on platform, enabled during game)
  Walls/ (4 invisible boundaries)
  Bombs/ (runtime)

ServerScriptService/
  BombSystem, PlayerManager, RoundManager

ServerStorage/
  BombTemplate (Model: Body + FuseBase + Spark)

ReplicatedStorage/
  GameConfig, MapManager
  GameEvents/ (RoundUpdate, PlayerDamaged, PlayerDied, BombLanded)
  Binds/ (DamagePlayer, ResetPlayers, StartBombs, StopBombs, GetAlivePlayers)

StarterGui/
  GameHUD (TopBar + Flash + Death)

StarterPlayerScripts/
  HUDController

Lighting/
  BloomEffect, ColorCorrectionEffect, Atmosphere
```
