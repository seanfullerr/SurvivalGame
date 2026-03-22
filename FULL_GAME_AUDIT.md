# Bomb Survival — Full Prototype Audit

---

## Strengths

**Solid structural foundation.** The 3-tier elevation system with procedural blob placement, winding channels, and ramps creates a different layout every session. The tier system (HIGH/MID/LOW) provides natural terrain variety, and the bedrock floor guarantees players never fall through the map. This is a strong base to build on.

**Bomb variety is well-designed.** Four distinct bomb types (standard, bouncing, timed, cluster) with unique colors, trails, and behaviors. Each creates a different dodge pattern: standard is "read and sidestep," bouncing is "track the trajectory," timed is "evacuate the zone," cluster is "scatter from the area." The color-coded system (black/orange, green, red, purple) is immediately readable.

**Progressive destruction creates real tension.** The probabilistic tile destruction system (24% to 65% scaling) means the map transforms visibly across rounds. Players watch grass give way to dirt, then stone, then eventually bedrock. This visual degradation tells a story about how intense the session has been.

**Death and damage feedback is strong.** Red screen flash scaled to damage, camera shake proportional to hit, character tint, death VFX with smoke/sparks, cause-specific death messages ("Melted in lava!" vs "Blown up by a timed bomb!"), and spectator camera. The HUD includes near-miss feedback, heal pop-ups, and milestone callouts. This is polished work.

**The scatter spawn system is fair.** Random MID/HIGH positions with 20-stud spacing prevents early-round unfairness. Avoiding LOW tier spawns means no one starts on lava.

---

## Top Issues Limiting Engagement

### 1. Lava Is a Non-Threat (Critical)

Lava DPS is 5, meaning 2.5 damage per 0.5s tick. At 100 HP, it takes **20 full seconds** of standing on lava to die. Players can casually walk across lava pools, take a couple ticks of chip damage, and never feel threatened. For comparison, a single standard bomb deals 40 damage instantly. Lava should feel like touching a hot stove — immediate, punishing, "get off NOW." At 5 DPS it feels like a warm puddle.

**Recommendation:** Increase LAVA_DPS to 25-35. This creates 12-17 damage per tick, killing in 3-4 seconds. Players who fall onto exposed lava have a narrow window to escape but will panic doing it. This makes lava a real hazard that changes decision-making.

### 2. Rounds Feel Identical After Round 3 (High)

The difficulty curve hits its steepest climb in rounds 1-3 (diff 1.3 → 2.3), then flattens toward the cap of 4.5. Rounds 8, 9, and 10 are mathematically identical. The bomb interval, destroy chance, and heal amount don't change. Players who survive round 5 have already mastered the current challenge — there's nothing new to push against.

**Recommendation:** Introduce per-round mechanical escalations, not just number tweaks. Round 3: first timed bomb guaranteed. Round 5: hot zone becomes 2x multiplier instead of 1.4x. Round 7: heal drops to 15%. Round 9: two hot zones active simultaneously. Each round should have a "new thing" that changes how you play.

### 3. No Strategic Reason to Use LOW Tier (High)

LOW tier has fewer destructible layers (2 vs 3-4), lava pools, and lower elevation — all downsides. There's no upside to being there. Players who understand the map will always stay on HIGH/MID. LOW tier is dead space.

**Recommendation:** Add a reward for LOW tier risk. Options: healing pools in LOW tier (non-lava cells restore 2 HP/sec), lava-adjacent cells grant brief damage immunity ("heat shield" buff for 3 seconds after leaving LOW), or place collectible score multipliers in LOW valleys.

### 4. The 35-Second Round Is Too Long (Medium)

With 65-168 bombs per round, a 35-second round creates extended periods where the player is just dodging repetitively without any change in state. The mid-round barrage (5 rapid bombs at 50% progress) is a good idea but happens once and then the round continues for another 17 seconds of the same pattern.

**Recommendation:** Shorten rounds to 20-25 seconds but make them denser. Alternatively, add 2-3 micro-events per round: a 3-second "meteor shower" (8 bombs in 1 second), a "calm eye" (5-second bomb pause where the hot zone shifts), or a "lava surge" (existing lava pools briefly expand their damage radius).

### 5. Healing Is Invisible and Passive (Medium)

30% heal between rounds (30 HP) happens automatically with no player action. There's no decision to make, no risk to take. The heal just happens. This is a missed opportunity for engagement.

**Recommendation:** Replace passive healing with visible health pickups that spawn on the map between rounds. 3-5 green orbs at random positions, first-come-first-served. This creates a mini-objective during the inter-round pause: do you rush for health (risky, might be far away) or play it safe at your current position? This single change adds a decision point to every inter-round moment.

---

## Detailed Recommendations by Area

### Map & Terrain

**Tile size (8 studs) is appropriate.** A player character is roughly 5 studs wide, so an 8-stud tile gives enough room to stand but is small enough that destruction feels impactful. No change needed.

**The 200x200 arena is slightly too large for solo play.** At 16 studs/sec walk speed, crossing the full arena takes 12.5 seconds. With bombs dropping everywhere, a single player can inhabit maybe 25% of the map effectively. The remaining 75% has bombs falling on empty tiles with no one to threaten.

Suggestion: For solo/low player count, dynamically shrink the effective bomb area. When only 1-2 players remain, concentrate bomb targeting within 60 studs of any living player rather than the full arena. This keeps pressure high without changing map size.

**Ramps need improvement.** Currently 2 ramps per tier boundary, 2 tiles wide. With only 2 access points between MID and HIGH, chokepoints form. Players who lose their ramp to destruction have no way back up.

Suggestion: Increase to 3-4 ramps per connection. Add "jump-up ledges" — single-tile walls between tiers that are climbable with double-jump. This gives more vertical mobility options and rewards the double-jump mechanic.

**Map modifiers are strong but underused.** The craters, thin_bridges, elevated_center, and flat modifiers create good variety. However, "normal" and "flat" are in the pool and are basically the same experience.

Suggestion: Remove "flat" from the pool, it's "normal" without tiers. Replace with a "swiss_cheese" modifier that pre-destroys random Layer 1 tiles (15% coverage), creating an already-damaged starting map that accelerates the destruction narrative.

### Lava & Hazards

**Lava pool placement is good.** 30% of LOW tier bedrock creates enough coverage to be meaningful without making LOW entirely lava. The flood-fill merging into organic pools eliminates the grid pattern.

**Lava visibility is now solid** with the PointLight system (0.6 → 3.0 dynamic brightness), ember particles, heat haze, and crack decals. The visual reveal arc (subtle underglow → exposed pools) aligns with the destruction curve.

**Missing hazard: edge danger.** The arena has no boundary feedback. Players can walk to the very edge and look over a void. There's no wall, no warning, no visual cue that says "the arena ends here."

Suggestion: Add a 1-tile border of "crumbling edge" tiles with reduced opacity (0.3 transparency) and a decal. These break with any bomb impact (100% destroy chance), creating a naturally shrinking boundary. Players near the edge see through the semi-transparent tiles to the void below.

**Lava damage on bedrock contact needs tuning.** Currently, the lava damage threshold is `lavaData.y + 3`. With the new architecture, a player on bedrock at Y=-16 has HRP at ~Y=-13, and lava top is at Y=-17. The check `-13 < -17 + 3 = -14` is FALSE, meaning players on solid bedrock adjacent to lava take no damage. This is correct for standing beside lava, but players who actually fall INTO a lava recess (no bedrock tile, terrain at Y=-17) will have HRP at ~Y=-14 to -15, which IS less than -14. The 1-stud tolerance is tight. Consider widening to `lavaData.y + 4` to catch players standing in the recess more reliably.

### Gameplay Difficulty & Round Structure

**The difficulty formula works well for rounds 1-5:**

| Round | Diff | Bomb Interval | Bombs/Round | Destroy% |
|-------|------|--------------|-------------|----------|
| 1 | 1.3 | 0.92-0.15s | ~65 | 26% |
| 3 | 2.3 | 0.52-0.15s | ~104 | 34% |
| 5 | 3.3 | 0.36-0.15s | ~136 | 42% |

The jump from R1 (65 bombs) to R5 (136 bombs) is a clear escalation. The destroy chance doubling creates visible map degradation.

**Bomb damage at 40 is well-tuned.** 3 hits to kill means players can survive mistakes but can't tank repeated hits. The scaling damage (distance-based: 100% at center, 50% at edge) rewards positioning.

**Timed bombs are the most interesting design.** Their 3-second fuse with expanding warning ring creates a "do I stay or go?" moment. The 1.5x blast radius and 3 depth layers make them the primary terrain shaper. However, they're only 9-18% of bombs.

Suggestion: Guarantee 1 timed bomb per round starting at round 2. By round 5, guarantee 2 per round. Timed bombs create the best moments — lean into them.

**The mid-round barrage is a good concept** but it fires 5 standard bombs in 0.75 seconds, which all land in roughly the same area. This creates one big dodge moment followed by 17 more seconds of normal pacing.

Suggestion: Split the barrage into two waves: 3 bombs at 40% progress, 3 bombs at 70% progress. This creates two tension spikes per round instead of one, breaking the monotony of the back half.

**Inter-round timing is too fast.** The 2-second gap between rounds (heal + countdown) doesn't give players time to reposition, survey the damage, or plan. The destruction that happened in the last round is important information — players need a moment to see it.

Suggestion: Increase inter-round pause to 4-5 seconds. Use 2 seconds for the heal phase (show "HEAL +30" text, play heal VFX), then 2-3 seconds of countdown. This breathing room is critical for maintaining engagement over 5+ rounds.

### Player Movement & Game Feel

**Walk speed (16 studs/sec) is appropriate.** The dodge math works: blast radius is 16 studs, warn time is 1.2 seconds, so a player at the blast edge has exactly enough time to walk out. Players at blast center need to react within 0.6 seconds (double-jump helps here). This creates tight, skill-testing dodges.

**Double-jump is well-implemented** with flip animation, air pose, jump indicator dot, FOV kick, and landing dust. The 64-power jump with 1 extra jump gives good vertical mobility.

**Missing: dash or sprint.** The game has "walk and dash movement" referenced in the brief, but I see no dash implementation in the DoubleJump or HUDController scripts. If dash exists, it's not in the current codebase. If it doesn't exist, it should.

Suggestion: Add a short dash (tap Shift) that gives 2x speed for 0.3 seconds with a 3-second cooldown. This creates a "panic button" for close calls and rewards reactive players. Show cooldown as a small bar under the HP bar. Add a brief speed-line VFX during the dash.

**Knockback from bombs is well-tuned** (distance-scaled, with upward boost and PlatformStand stagger). The 0.3s LinearVelocity duration feels punchy without being frustrating.

**Landing feedback exists but could be enhanced.** The DoubleJump script handles landing dust, but there's no screen-space landing indicator. When falling from HIGH to LOW tier (18 studs), the landing should feel heavier.

Suggestion: Scale landing camera shake and particle intensity by fall distance. Falls over 12 studs get a stronger "thud" sound and a brief 0.1s FOV squeeze.

### Visual / VFX & Feedback

**Bomb warnings are excellent.** Growing red ring + yellow center dot + pulsing light + warning beep. The shadow-then-bomb sequence (shadow appears immediately, bomb trail follows 20% later) gives players a two-stage read: "danger incoming" → "here it comes."

**Explosion VFX is dedicated (14,985 chars in ExplosionVFX module)** with smoke, sparks, shockwave ring, and scorch marks. Scorch marks fade over 8 seconds, which provides terrain "memory" — players can see where bombs have landed.

**Missing: hot zone visualization.** The HUD announces the hot zone ("NW", "SE", etc.) but there's no in-world visual for it. Players must mentally map "NW" to a quadrant. This is a significant readability gap — the hot zone is the most important strategic information in the game, and it's communicated via text only.

Suggestion: Add a subtle colored overlay on the hot zone area. A semi-transparent red plane at Y = surface + 0.2 covering the hot quadrant, with a slow pulse animation. OR, add glowing border lines at the hot zone boundary (4 orange neon beams forming the quadrant edge). Either approach makes the danger zone instantly readable from anywhere on the map.

**Missing: destruction progress indicator.** Players can't easily tell how many layers remain at their position. They see grass break to reveal dirt, but there's no UI cue for "2 layers left" vs "bedrock exposed."

Suggestion: Add a small tile-health indicator that shows when looking at the ground beneath you. A 3-dot display near the crosshair: green dot = intact layer, empty dot = destroyed. This helps players make risk decisions about where to stand.

**Near-miss feedback exists** (the `showNearMiss()` function triggers when `dmg == 0` within NEAR_MISS_MULT range). This is great for tension. Consider adding a brief time-slow effect (0.9x speed for 0.15 seconds) on near-miss to amplify the "that was close" feeling.

### Spawn & Post-Death Behavior

**Scatter spawn is well-designed.** MID/HIGH only, 20-stud spacing, 20% edge inset. The lobby countdown (3, 2, 1 while at lobby, then teleport to map) builds anticipation without wasting time.

**Spectate-until-round-ends is the right call.** Dead players watch survivors rather than staring at a death screen. The click-to-switch spectator target is good.

**Post-death camera pull-back is good** (Scriptable camera, 18 studs out + 12 up over 0.8 seconds). The 2.5-second delay before spectating gives time to process the death.

**Missing: death replay or highlight.** When you die, you see smoke/sparks at your position and then the camera pulls back. But you don't see what killed you. A 1-second slow-motion replay of the killing bomb hitting your position would make deaths feel fair and educational.

Suggestion: On death, briefly freeze the camera on the killing bomb (if it still exists) for 0.5 seconds before the pull-back. For lava deaths, zoom the camera to the lava pool you stepped in. For fall deaths, show the edge you fell from. This teaches players what to avoid.

**Missing: return-to-lobby transition.** The `return_to_lobby` event fires and players are teleported back. There's no visual transition — one frame you're on a destroyed arena, the next you're at the lobby. This is jarring.

Suggestion: Add a 1-second black fade-out before the teleport and a 0.5-second fade-in at the lobby. Simple TweenService on a black frame.

### Core Loop & Engagement

**The full loop is: Lobby (2s) → Countdown (3.5s) → Drop (1s) → [Rounds × (2s heal + 35s survive)] → Game Over (3s) → Lobby.**

**Strengths:** The countdown builds anticipation. The scatter drop is a fun "where will I land?" moment. Round milestones (WARMING UP, SURVIVOR, UNSTOPPABLE) give intermediate goals. The leaderboard provides social comparison.

**Weakness: Dead time between sessions is ~8 seconds** (3s game over + 0.5s transition + 2s lobby + 0.5s start + 3s countdown = 9 seconds of not playing). For a survival game, this is acceptable but could be tightened.

**Weakness: No persistent progression.** Each session starts fresh. There's no XP, no unlockables, no "you beat your record" outside of the session. The bestRoundLabel exists in HUD but appears to track session-only.

Suggestion: Add a simple persistent stat: "Personal Best: Round X" saved to player data. Display it in the lobby. This single number gives players a reason to try again. Implementation: DataStoreService with a single integer per player.

**Weakness: Single-player loop lacks social pressure.** In multiplayer, the "last survivor" mechanic and kill feed create drama. Solo players just dodge until they die. There's no audience, no rivalry.

Suggestion: Add a "ghost replay" system. Record the previous session's player position every 0.5 seconds, then replay it as a transparent ghost character in the next session. Players race against their own ghost, creating competition even in single-player. Low-effort implementation: store a table of Vector3 positions, replay with a translucent character model.

---

## Map Depth & Vertical Layer Assessment

### Are 3 Elevation Tiers Enough?

**Yes, with caveats.** Three tiers create clear zones (safe high ground, neutral middle, dangerous low ground) that are readable at a glance. Adding a 4th tier would increase vertical complexity but risks making navigation confusing in a fast-paced survival game where attention should be on dodging, not pathfinding.

**The real issue isn't tier count — it's that the vertical dimension is underutilized.** HIGH, MID, and LOW tiers are functionally identical except for surface Y and layer count. A player on HIGH tier plays the same game as one on MID tier. The tiers don't create meaningfully different experiences.

### How to Make Existing Tiers More Distinct

**HIGH tier should be "safe but exposed."** Bombs land here first (highest surface Y means shortest fall time from BOMB_FALL_HEIGHT). Add a slight bomb targeting bias toward HIGH tier (+15% chance). HIGH has the most layers to dig through, which is its defensive advantage, but the warning time is shorter, which is its offensive disadvantage.

**MID tier should be "balanced and contested."** It's the default, the neutral ground. The hot zone mechanic already creates pressure here. No changes needed conceptually, but add health pickups that prefer MID tier positions.

**LOW tier should be "risky but rewarding."** With lava as a hazard and fewer layers, LOW is currently pure downside. Adding LOW-exclusive rewards (score multipliers, healing, defensive buffs) would make it a meaningful choice. The danger/reward tradeoff is the core of what makes positioning interesting.

### Should the Map Go Deeper?

**No.** Adding more vertical layers (e.g., underground caves beneath bedrock) would require: new navigation systems (ladders, tunnels), additional VFX for underground lighting, more complex destruction logic, and significantly more development time. The return on investment is low for a solo developer.

Instead, invest vertical depth into the **destruction narrative** — the existing 2-4 destructible layers already create a "going deeper" feeling as the round progresses. The grass-to-dirt-to-stone-to-bedrock sequence tells a compelling vertical story without requiring new tier levels.

### One Addition That Would Add Depth Without New Tiers

**Floating platforms.** At round 3+, spawn 3-5 small floating platforms (4x4 stud, Neon material, slow vertical bob) above MID and HIGH areas. These are single-use safe spots: the first bomb that hits within 8 studs of a platform destroys it. Players who double-jump onto a platform get a brief elevated vantage point to survey the arena. This adds a vertical element without restructuring the tier system. Low implementation cost (a Part with BodyPosition, destroyed on nearby explosion).

---

## Priority Action Items

### High Impact, Low Effort (Do First)

1. **Increase LAVA_DPS to 25-35.** One number change in GameConfig. Transforms lava from ignorable to terrifying.
2. **Add hot zone world visualization.** 4 neon beam parts forming the quadrant boundary. Massive readability improvement.
3. **Shorten rounds to 22-25 seconds.** One number change. Tightens pacing immediately.
4. **Increase inter-round pause to 4-5 seconds.** Gives breathing room for strategic repositioning.
5. **Split mid-round barrage into two waves.** Small BombSystem edit. Two tension peaks per round.
6. **Add lobby-to-game and game-to-lobby fade transitions.** Simple black frame tween. Eliminates jarring teleport cuts.

### High Impact, Medium Effort

7. **Add health pickup orbs between rounds.** Replaces passive healing with an active mini-objective.
8. **Add dash/sprint ability.** Creates a panic-dodge tool that adds skill expression.
9. **Guarantee timed bombs per round** (1 at R2, 2 at R5). Ensures the best bomb type appears consistently.
10. **Add LOW tier reward** (healing zones or score multiplier). Makes the dangerous tier worth visiting.
11. **Player-proximity bomb targeting** for low player counts. Concentrates pressure.
12. **Add arena edge crumbling tiles.** Natural boundary that shrinks over time.

### Medium Impact, Higher Effort

13. **Persistent best-round tracking** via DataStore. Gives long-term motivation.
14. **Ghost replay of previous session.** Solo-player competition driver.
15. **Floating platforms** at round 3+. Vertical variety without structural changes.
16. **Per-round mechanical escalations** (new mechanics at R3, R5, R7). Keeps late rounds distinct.

---

## Trade-offs & Warnings

**Performance:** The current VFX system (31 lights, 62 emitters, 10 sounds for lava alone) is within budget for mid-tier devices. Adding hot zone beams (4 parts) and health orbs (3-5 parts) is negligible. Floating platforms (5 parts with BodyPosition) add minimal load. Ghost replay (translucent character model + position table) needs testing on low-end — the replay model could use a SimplifiedMesh to reduce draw calls.

**Readability vs. clutter:** Hot zone beams, health orbs, and floating platforms all add visual elements. Keep colors distinct: hot zone = orange/red beams, health orbs = green glow, floating platforms = cyan/white. No two systems should share a color.

**Difficulty balance:** Increasing lava DPS and shortening rounds simultaneously could make the game too hard for new players. Test these independently. Start with lava DPS increase alone, then shorten rounds after confirming the lava change feels right.

**Scope creep:** The ghost replay system and persistent progression are feature additions that extend beyond "polish." They're worth doing but should come after the numerical tuning and VFX additions are locked in. Get the moment-to-moment feeling right first, then add meta-game layers.
