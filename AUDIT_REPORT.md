# Bomb Survival — Systems Audit Report

## 1. Lava Visibility

### Current Issues

**The lava is essentially invisible during normal gameplay.** Three compounding problems:

**Depth problem.** The terrain lava sits at Y = -28. The LOW tier surface is at Y = 16 (3 layers of 8-stud tiles stacked on a base of -8). That's **44 studs** of separation. Even after all 3 LOW-tier layers are destroyed above a lava tile, the player is looking down a 24-stud shaft. CrackedLava terrain is a dark, low-contrast material — at that distance, it blends into shadow.

**No VFX.** When we switched from Part-based lava (which had PointLights with orange glow, Brightness 1.5, Range 12) to `Terrain:FillBlock(CrackedLava)`, all visual cues were removed. There are zero particles, zero lights, and zero ambient effects. The terrain material alone does not communicate "danger below" to a player dodging bombs above.

**Gameplay readability.** A player on the LOW tier surface has no way to know lava is underneath until they've already fallen through destroyed tiles. There is no warning glow seeping through cracks, no ambient particle rising from below, no audio cue. The lava is a surprise rather than a readable hazard.

### Recommended VFX/Visual Improvements

**Priority 1 — Underglow (low effort, high impact).** Place a `PointLight` on an invisible anchored Part at each lava grid position, just below the bottom tile layer. Color: `RGB(255, 100, 30)`, Brightness 2, Range 16. This makes orange light bleed upward through gaps between tiles even before tiles are destroyed, hinting at danger below. Roughly 30–40 lights at 30% coverage — negligible performance cost.

**Priority 2 — Rising ember particles (medium effort, high impact).** Attach a `ParticleEmitter` to each lava light-anchor Part. Configuration: 2–3 particles/sec, Lifetime 1.5–2.5s, upward velocity (8–14 studs/s), Size 0.3→0.1 (shrink), Color orange→dark red, LightEmission 0.6, small random spread. These embers drift upward through holes in the floor, giving the player a visual read even from the MID tier looking sideways at a LOW tier pit. Cap at ~100 total particles across all lava tiles by keeping Rate low.

**Priority 3 — Lava surface glow plane (low effort, medium impact).** Place a thin semi-transparent Neon Part (Size T×0.2×T, Transparency 0.3, Color `RGB(255, 60, 10)`) directly on top of the terrain lava at each position. This gives the lava a bright, readable surface that's visible from above even at 44 studs distance. The terrain CrackedLava becomes a texture detail underneath; the Neon plane becomes the gameplay signal.

**Priority 4 — Ambient lava audio.** A looping "lava bubbling" sound (low volume, 0.15–0.2) on a single Part at the map center, audible only when the player is on or near the LOW tier. Adds atmosphere and subconsciously signals danger.

### Trade-offs

- 30–40 PointLights is well within Roblox's comfort zone; performance impact is minimal.
- ParticleEmitters at 2–3/sec each × 30–40 emitters = 60–120 particles total. Fine for all devices.
- The Neon glow plane adds ~30–40 Parts but they're static, anchored, and tiny — negligible.
- Avoid adding more than 5 particles/sec per emitter or the screen gets noisy during later rounds when lots of tiles are destroyed.

---

## 2. Post-Death Behavior

### Current Issues

**Instant respawn kills tension and consequence.** The current flow:
1. Player HP hits 0 → `alive = false`, `inGame = false`
2. Client: white flash → death screen fades in (0.6s) → shows cause text + round + survival time
3. Client: after 1.5s, `startSpectating()` begins
4. **Server: after 1.5s, `LoadCharacter()` fires** — player respawns at lobby immediately

The problem is steps 3 and 4 happen simultaneously. The player barely sees the death screen before their character loads at the lobby, which can interrupt spectating. The death doesn't *land* — there's no lingering moment of "oh no, I'm out."

**No camera payoff.** The death flash and screen shake are good, but there's no dramatic camera pull — the camera just stays on the player's ragdoll (if any) or immediately snaps to the lobby spawn. Compare this to games like Natural Disaster Survival or Super Bomb Survival where the camera lingers on the destruction.

**Spectating conflicts with respawn.** `startSpectating()` tries to follow alive players, but `LoadCharacter()` fires at the same time, which creates a new character at the lobby. The spectating camera and the new character's camera fight each other.

### Recommended Handling

**Delay respawn to 5–6 seconds (not 1.5).** This is the single highest-impact change. The sequence should be:

1. **0.0s** — Death flash + screen shake (already implemented)
2. **0.0–0.6s** — Death screen fades in with cause text (already implemented)
3. **0.6–1.5s** — Camera slowly zooms out and tilts down ~15°, showing the crater/explosion area. This gives the player a moment to process what killed them and see the map state.
4. **1.5–5.0s** — Spectating kicks in. Camera smoothly transitions to an alive player. Show "Spectating [Name]" subtitle. Player can click to cycle between survivors.
5. **5.0s** — `LoadCharacter()` at lobby. Death screen fades out. Brief "Returned to Lobby" text.

**Alternative: keep spectating until round ends.** Don't respawn at all during an active round. Let dead players spectate until game_over fires, then everyone returns to lobby together. This is simpler to implement (remove the 1.5s LoadCharacter entirely) and is the standard pattern in survival games. It also builds investment in the surviving players.

**Add a subtle camera pull on death.** When `PlayerDied` fires on client, tween the camera's CFrame to pull back 10–15 studs and look down at the death position over 0.8s. Use `Enum.CameraType.Scriptable` temporarily. This creates a cinematic "you died" moment.

**Add death VFX on the character.** When the humanoid dies, spawn a brief particle burst (gray smoke + orange sparks, 0.5s duration) at the character's position. This gives visual feedback to both the dying player AND spectators watching.

### Player Experience Considerations

- The 1.5-second respawn makes death feel like a glitch rather than an event. Survival games need death to feel *significant* — it's what makes surviving feel good.
- Spectating builds social investment: "come on, you can make it!" This is a proven retention pattern in Roblox survival games.
- The "spectate until round ends" approach is simpler code-wise (fewer race conditions) and better for game feel. Recommended over timed respawn.

---

## 3. Player Spawn Distribution

### Current Issues

**All players spawn in a 30×30 stud square on a 200×200 arena.** The 4 GameSpawns are at (±15, 16.5, ±15) on a 60×60 SpawnPlatform. This means:

- In multiplayer, players cluster tightly in the center. The first bomb wave has a disproportionate chance of hitting everyone.
- Players all drop to the same ~30×30 area of the map when the platform disappears. No positional variety between rounds.
- The 200×200 arena with 3 tiers, ramps, and lava is designed for exploration, but everyone starts in the same spot every time.
- With the hot zone system rotating through quadrants (NW→NE→SW→SE→CENTER), starting at center means players are always in the first "CENTER" hot zone.

### Recommended Randomization Method

**Scatter spawns across the map surface, avoiding edges and lava.** Replace the fixed 4-spawn system with dynamically generated spawn positions each round:

```
Algorithm: Safe Scatter Spawn
1. Define safe zone: 20% inset from arena edges (inner 120×120 of 200×200)
2. For each player, pick a random (X, Z) within the safe zone
3. Check MapManager.GetTierAt(X, Z) — avoid LOW tier (lava risk at start)
4. Check MapManager.GetSurfaceY(X, Z) — ensure tiles exist
5. If position fails checks, re-roll (max 10 attempts, fallback to center)
6. Set spawn CFrame to (X, surfaceY + 5, Z) — drop from 5 studs above
7. Ensure minimum 20-stud spacing between any two players
```

**Keep the SpawnPlatform + countdown, but randomize where on it players stand.** A simpler approach: keep the dramatic platform drop, but make the platform larger (120×120) and scatter spawn points randomly across it. Players still get the shared "3, 2, 1, DROP!" moment but land in different parts of the map.

**Recommended hybrid: Platform drop with random landing.** This preserves the dramatic countdown while spreading players out:
1. All players spawn on the 60×60 platform (shared moment, builds tension)
2. During the "3, 2, 1" countdown, each player gets assigned a random landing CFrame on MID or HIGH tier
3. When platform drops, instead of freefall, each player gets briefly teleported to their assigned landing position + 10 studs up
4. Players land scattered across the map

### How It Affects Fairness, Engagement, and Tension

**Fairness.** Fixed center spawns create a "luck of the draw" problem — if the first bomb pattern targets center, everyone takes damage. Scattered spawns mean some players start on HIGH tier (safer but isolated), some on MID (central but flatter), creating natural strategic variety.

**Engagement.** Positional variety means each round starts differently. A player who spawned near a LOW tier edge last round might spawn on a HIGH plateau this round. This is a free source of replayability.

**Tension.** Spawning apart from other players creates isolated survival moments early in the round. You can't just follow the crowd — you have to read the terrain around YOUR position. This works perfectly with the hot zone system, since different players will have different proximity to the hot zone.

**Edge case: very few players.** With 1–3 players, scatter spawning can feel lonely. Consider a minimum cluster distance — if fewer than 4 players, spawn within a 60-stud radius of center rather than full scatter.

---

## Summary: Priority Actions

| Change | Effort | Impact | System |
|--------|--------|--------|--------|
| Add PointLights below lava tiles | Low | High | Lava Visibility |
| Add rising ember particles | Medium | High | Lava Visibility |
| Delay respawn / spectate until round end | Low | High | Post-Death |
| Camera pull-back on death | Low | Medium | Post-Death |
| Randomize spawn positions on map surface | Medium | High | Spawn Distribution |
| Add Neon glow plane on lava surface | Low | Medium | Lava Visibility |
| Death VFX burst on character | Low | Medium | Post-Death |
| Minimum player spacing for spawns | Low | Medium | Spawn Distribution |
