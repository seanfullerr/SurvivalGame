# Bomb Survival — Gameplay Audit V3

Full code audit of all 9 scripts (180,000+ chars). Every system inspected: bombs, lava, movement, UI, round flow, missile, spectator, VFX.

---

## BUGS (Must Fix)

### B1. Missile VFX.Explode Wrong Arguments (CRITICAL)
**File:** BombSystem, line ~in spawnGuidedMissile PHASE 4
**Issue:** `VFX.Explode(explodePos, bombFolder, "missile")` passes `bombFolder` (a Folder instance) as the `radius` parameter and `"missile"` as the `parent` parameter. Correct signature is `VFX.Explode(position, radius, parent, bombType)`.
**Impact:** Missile explosions render incorrectly or error. The radius becomes a Folder object, VFX tries to parent parts to the string "missile".
**Fix:** Change to `VFX.Explode(explodePos, MISSILE_BLAST_RADIUS, bombFolder, "missile")`

### B2. Missile Proximity Double For-Loop (Minor/Perf)
**File:** BombSystem, spawnGuidedMissile PHASE 3
**Issue:** Inner `break` only exits the `for` loop, not the `while`. A second identical `for` loop runs every frame to re-check. This means every physics frame iterates Players twice.
**Fix:** Use a local `hitPlayer` flag in a single loop, then check it after.

### B3. Missile Effects Not Cleaned Up on Game End
**File:** HUDController
**Issue:** Neither `return_to_lobby` nor `lobby_wait` calls `cleanupMissileEffects()`. If a missile lock-on is active when a round ends (all players die), the reticle billboard stays attached to the dead player's character indefinitely.
**Fix:** Add `cleanupMissileEffects()` at the top of both `return_to_lobby` and `lobby_wait` handlers.

### B4. Cluster Mini-Bomb Warning Inaccuracy
**File:** BombSystem, spawnClusterBomb
**Issue:** Mini-bombs are spawned without `CanCollide = false`, so they default to `true` and bounce off terrain. But the trajectory prediction for the warning circle assumes pure parabolic flight (no collisions). The purple ground warning frequently appears in the wrong spot.
**Fix:** Either set `mini.CanCollide = false` (they phase through terrain and explode on timer), or remove the ground warning for minis (the parent cluster already has a warning).

### B5. Timed Bomb Fuse Ring Stays at Full Size
**File:** BombSystem, spawnTimedBomb
**Issue:** The `fuseRing` is created at full `fuseRadius` size immediately and only pulses transparency. There's no *shrinking* animation to communicate countdown progress. The `fuseFill` tweens transparency but doesn't shrink either. Players can't visually gauge how much fuse time is left by looking at the ring.
**Fix:** Tween `fuseFill` size from full to zero over the 3s fuse, creating a visual "filling" or "draining" effect.

---

## GAME FEEL ISSUES (High Impact Polish)

### F1. No Audio Distinction Between Bomb Types on Landing
**Current:** All bomb types play the same `Explosion` sound at the same pitch.
**Problem:** Players can't learn to *hear* what hit them. Sound is one of the strongest tools for building pattern recognition. A bouncing bomb that sounds identical to a standard bomb trains the player to treat them the same.
**Fix:** Vary `PlaybackSpeed` and `Volume` per bomb type in `explodeAt`:
- Standard: pitch 0.9-1.1 (baseline)
- Bouncing: pitch 1.3-1.5 (higher, snappier)
- Timed: pitch 0.7-0.8 (deep, heavy)
- Cluster initial: pitch 1.1-1.3, low volume (pop)
- Cluster minis: pitch 1.4-1.6 (light crackle)
- Missile: pitch 0.6-0.7 (deep boom)

### F2. No Screen Feedback for Round Difficulty Escalation
**Current:** The difficulty curve is exponential and late rounds are now significantly harder. But the player receives no explicit signal that things just changed beyond bomb frequency.
**Problem:** The player can *feel* it's harder but doesn't get a moment of "oh no" to anchor the feeling.
**Fix:** On round start for R5+, add a brief HUD flash or shake — something like the status text briefly showing "INTENSITY RISING" in orange for R5, "DANGER ZONE" in red for R6, "FINAL STAND" in deep red for R7. 1-second display, no gameplay interruption.

### F3. Bouncing Bomb Post-Bounce Trajectory Is Unpredictable
**Current:** After landing, bouncing bombs get random velocity `Vector3.new(math.random(-20,20), 30, math.random(-20,20))`. Subsequent bounces: `math.random(-15,15), math.random(18,28), math.random(-15,15)`.
**Problem:** The initial landing has a shadow warning. But after the first bounce, the bomb goes in a random direction with no warning. Players can't read or dodge it — they just randomly get hit. Deaths feel unfair.
**Fix:** Two options (pick one):
- **Option A:** Add brief mini-shadows at predicted bounce landing positions (like cluster minis, but green).
- **Option B:** Reduce horizontal randomness on bounces so the bomb stays roughly in the same area. Change bounce velocity to `math.random(-8,8), random(20,28), math.random(-8,8)`.

### F4. Spectator Camera Has No Smooth Entry
**Current:** When a player dies, the camera snaps to `Enum.CameraType.Scriptable` and lerps between spectate targets. But the initial transition from `Custom` (following your own character) to `Scriptable` (following a living player) can be jarring if the target is far away.
**Fix:** On death, keep the camera at its current position for 0.5s, then smoothly lerp to the first spectate target over 0.5s before starting the normal spectate cycle.

### F5. Kill Feed Doesn't Show Bomb Type
**Current:** Kill feed shows "PlayerName - cause" where cause is "standard", "bouncing", etc. as plain text.
**Problem:** Players don't learn bomb type names by seeing them in a death feed.
**Fix:** Color-code the cause text to match the bomb's visual color scheme (black/orange for standard, green for bouncing, red for timed, purple for cluster, orange for missile). This reinforces the visual language.

---

## BALANCE OBSERVATIONS

### Balance 1: Inter-Round Heal Is Flat
**Current:** 30% heal between every round regardless of difficulty.
**Observation:** In R1-R3 (easy), players rarely take much damage, so 30% heal is wasted. In R6-R7 (brutal), players are often at 20-40 HP and 30% heal only gets them to 50-70 HP. They enter the hardest rounds already weakened.
**Recommendation:** Scale heal with round: 20% for R1-R3, 30% for R4-R5, 40% for R6-R7. This makes late-round survival more dependent on the current round's skill rather than accumulated attrition.

### Balance 2: Timed Bomb Is Disproportionately Deadly
**Current:** 1.5x blast radius (24 studs), 1.3x damage (52), 3s ground fuse, 3-layer destruction depth.
**Observation:** The 24-stud radius is enormous — nearly impossible to escape if you're anywhere near it when it lands. Combined with 52 damage, a single timed bomb does over half HP. In late rounds with reduced warn scale (0.6-0.72), the initial warning is barely visible before it lands and starts the fuse.
**Recommendation:** Either reduce timed radius to 1.3x (20.8 studs) or increase fuse time to 4s to give players more reaction time. The bomb should be "high damage if you don't move" not "unavoidable death."

### Balance 3: Missile Targets Random Player
**Current:** `pickMissileTarget` selects a random alive player.
**Observation:** In a 6-player game, a player could be targeted multiple rounds in a row by pure chance. In a 2-player endgame, one player gets missiles 50% of rounds.
**Recommendation:** Track last missile target and exclude them from the pool for the next missile. If only 1 player alive, missile still targets them (no choice). Simple bias-avoidance without complex state.

### Balance 4: Cluster Mini-Bombs Explode on Timer Not Impact
**Current:** Mini-bombs explode after `math.random(8,14)/10` seconds (0.8-1.4s) regardless of whether they've landed.
**Observation:** A mini-bomb that bounces high might explode mid-air above a player, or one that lands immediately might sit for 0.8s doing nothing. The timing disconnect confuses players.
**Recommendation:** Use Touched event on mini-bombs as a secondary trigger (explode on terrain contact after 0.3s delay), keeping the timer as a fallback for minis that fly off the map.

---

## STRUCTURAL OBSERVATIONS (Not Bugs, But Worth Noting)

### S1. Map Modifiers Are Unannounced in Gameplay
**Current:** `applyMapModifier` runs "craters", "thin_bridges", etc. but only sends a HUD event for non-normal/non-flat modifiers. Players see a brief notification but may not understand what changed about the map.
**Note:** This is acceptable for now. Map variety is a background system. Could be enhanced later with a 2-second visual callout during the drop sequence.

### S2. BombSystem Main Loop Indentation
**Current:** The `while spawning do` loop has the first line indented with extra spaces (`        local progress`). This is cosmetic but makes the code harder to read for maintenance.
**Note:** Cosmetic only. No gameplay impact.

### S3. SoundManager Uses Same Asset for LavaHiss and LavaSizzle
**Current:** Both `LavaHiss` and `LavaSizzle` point to `rbxassetid://31758982`.
**Note:** Different playback properties (volume, pitch) differentiate them at runtime, but having two distinct assets would improve audio variety.

### S4. No Victory Celebration Audio
**Current:** Victory handler plays no sound. Game over has `GameOver` sound, round survived has `RoundClear`, but winning all 7 rounds is silent apart from the visual fanfare.
**Recommendation:** Add a distinct victory sound — even reusing `RoundClear` at lower pitch and higher volume would work.

---

## PRIORITY RANKING

| # | Item | Type | Impact | Effort |
|---|------|------|--------|--------|
| 1 | B1: Missile VFX wrong args | Bug | Critical | 1 line |
| 2 | B3: Missile cleanup on game end | Bug | Medium | 2 lines |
| 3 | B2: Missile double for-loop | Bug/Perf | Low | 5 lines |
| 4 | F1: Audio per bomb type | Feel | High | 10 lines |
| 5 | B4: Cluster mini-bomb CanCollide | Bug | Medium | 1 line |
| 6 | F5: Kill feed color by bomb type | Feel | Medium | 15 lines |
| 7 | F2: Round escalation screen feedback | Feel | Medium | 20 lines |
| 8 | Balance 1: Scaled inter-round heal | Balance | Medium | 5 lines |
| 9 | B5: Timed bomb fuse visual countdown | Bug/Feel | Medium | 10 lines |
| 10 | F3: Bouncing bomb predictability | Feel | Medium | 5 lines |
| 11 | Balance 3: Missile target fairness | Balance | Low | 8 lines |
| 12 | Balance 2: Timed bomb tuning | Balance | Low | 2 lines |
| 13 | S4: Victory sound | Polish | Low | 2 lines |
| 14 | F4: Spectator camera entry | Polish | Low | 15 lines |
| 15 | Balance 4: Cluster mini impact trigger | Balance | Low | 15 lines |
