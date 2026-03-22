# Bomb Survival — Front-Page Roadmap

Full audit of 9 scripts (210,000+ chars), compared against Super Bomb Survival, Natural Disaster Survival, and other front-page Roblox survival games. Every system inspected.

---

## PART 1: WHAT THE GAME HAS (Current State)

**Core loop:** Lobby → scatter drop → 7 rounds of 23s each → survive or die → return to lobby. Total game length ~3.4 minutes. Solid pacing for "one more game."

**Strengths already in place:**
- 5 distinct bomb types with unique colors, trails, and behaviors
- Destructible terrain with 3 elevation tiers + lava hazards
- Double-jump with custom flip animation + air pose (very polished)
- Exponential bomb rate within each round (calm → frantic)
- Exponential difficulty curve across rounds (1.2 × 1.28^(round-1))
- LOS raycast damage system (terrain blocks = 85% reduction)
- Hot zone rotation with visual particles
- Guided missile with matador mechanic (commits + slows near player)
- Map modifiers (craters, thin bridges, elevated center)
- Spectator system with smooth camera lerp
- Death screen that shrinks to banner (non-obstructive)
- Near-miss indicators (yellow flash), directional damage (red)
- Kill feed with bomb-type color coding
- Round escalation callouts (R5: "INTENSITY RISING", R7: "FINAL STAND")
- Landing dust, movement VFX, FOV kick on double-jump
- Bomb-type-specific explosion audio
- Lobby parkour area
- Grand cartoony explosion VFX with shockwaves, ground cracks, debris

---

## PART 2: WHAT'S MISSING (vs. Front-Page Games)

These are the gaps that separate a good prototype from a front-page game. Ordered by player impact.

### CRITICAL GAP 1: No Progression System (Coins/XP/Levels)
**Why it matters:** Every front-page Roblox game has a reason to come back tomorrow. Super Bomb Survival has coins, abilities, and a shop. Without progression, players have no investment — they play 3-5 games, enjoy it, then leave permanently. The "one more game" impulse exists but there's no "one more session" pull.

**What's needed:**
- Coins earned per round survived (5 per round, 50 bonus for full survive)
- A visible coin counter on the HUD during gameplay
- DataStore persistence (coins survive between sessions)
- A simple leaderstats display (Rounds / Best Round)

**Effort: Medium.** Requires a new CoinManager server script + DataStore + HUD additions. No shop needed yet — just earning and seeing the number go up is enough for Phase 1.

### CRITICAL GAP 2: No Game-Over Recap Screen
**Why it matters:** The current game-over is a text label saying "GAME OVER! Lasted X rounds! Restarting Ys." No stats, no comparison, no "I almost beat my best." The moment between games is THE critical retention moment — it's where the player decides to stay or leave. Currently it's dead air.

**What's needed:**
- A styled panel showing: rounds survived, total survival time, damage taken, bombs dodged, personal best round
- "NEW BEST!" callout if they beat their record
- Brief 3-4 second hold before auto-returning to lobby

**Effort: Medium.** Primarily HUD work + tracking a few counters.

### CRITICAL GAP 3: No Victory Sound
**Why it matters:** Surviving all 7 rounds is the hardest achievement in the game. Currently it's visually celebrated (big text, green dots, gold color) but plays NO sound. The silence undercuts the dopamine moment. Compare to any game with a win state — audio is half the reward.

**What's needed:** A distinct victory jingle or even reusing RoundClear at lower pitch + higher volume.

**Effort: Trivial.** One line in HUDController victory handler.

### HIGH-VALUE GAP 4: No Abilities/Perks
**Why it matters:** Super Bomb Survival's core retention mechanic is abilities (shield, speed boost, stomp). They give players a sense of agency and progression. Currently, every player is identical — survival is pure positioning + jump timing. There's no way to express skill through builds or choices.

**Phase 1 suggestion (minimal scope):** Start with ONE passive ability, like "Thick Skin" (take 15% less damage). Award it after surviving 10 total rounds. This introduces the concept without building a full ability system.

**Effort: Medium-High.** Requires ability framework, but can start with 1 ability.

### HIGH-VALUE GAP 5: No Session-Best / Personal Record
**Why it matters:** The variable `bestTime` exists but is declared and never used. Players have no way to know if they're doing better than last game. A personal best overlay is one of the simplest and most effective retention tools — it turns every game into a competition against yourself.

**What's needed:** Track bestRound per session, show it subtly during gameplay ("Best: R5"), and flash "NEW RECORD!" on the recap screen.

**Effort: Low.** Variable already exists. Just needs display logic.

---

## PART 3: BUGS AND GLITCHES

### Already Fixed This Session:
- B1: Missile VFX.Explode wrong arguments (CRITICAL — was passing Folder as radius)
- B2: Missile proximity double for-loop (perf waste)
- B3: Missile lock-on effects not cleaned up on game end
- B4: Cluster mini-bombs had CanCollide=true (wrong bounce behavior)
- B5: Timed bomb fuse ring had no shrinking visual countdown

### Remaining Bugs:

**BUG R1: Stun-Lock From Overlapping Explosions (Medium)**
When two bombs land near each other, `PlatformStand = true` from the first explosion's stun can overlap with the second explosion's stun. The `task.delay(stunTime, ...)` from the first bomb sets `PlatformStand = false`, but the second bomb immediately sets it back to `true`. The result: the player ragdolls for the combined duration, feeling unfair. Fix: Use a stun counter or timestamp instead of boolean toggle.

**BUG R2: Bouncing Bomb Can Fly Off Map (Low)**
Bouncing bomb's unanchored physics means it can bounce off elevated terrain edges and fly outside the arena walls. It eventually gets Debris-cleaned after 10s, but the explosion happens far from any player, wasting a bomb. Fix: Clamp position after each bounce or add arena bounds check.

**BUG R3: Lava Damage Doesn't Track bombType Properly (Low)**
PlayerManager sets `lastHitBy = "lava"` on lava damage, but if a player was previously hit by a bomb and then touches lava for 1 tick before dying to a bomb, the death cause shows "lava" instead of the bomb. Fix: Only set lastHitBy for lava if lava actually kills the player.

**BUG R4: bestTime Variable Declared But Never Used (Trivial)**
`local bestTime = 0` at line ~7172 of HUDController. Declared, never read, never written. Dead code.

---

## PART 4: GAME FEEL & POLISH GAPS

### P1: WalkSpeed Is Default 16 (HIGH IMPACT)
**Issue:** Roblox default WalkSpeed (16) feels sluggish in a bomb survival game. Super Bomb Survival uses ~20. The arena is 200×200 studs. At WalkSpeed 16, crossing the arena takes ~12.5 seconds — that's over half a round duration (23s) to go from one side to the other. Players can't reasonably reposition.

**Fix:** Increase to 20-22. This single change will dramatically improve responsiveness and make dodging feel skill-based rather than luck-based. Test at 20 first.

**Why players love it:** Faster movement = more successful dodges = more "I'm skilled" moments = more fun.

### P2: No Footstep Feedback When Running (Medium)
**Issue:** Players get zero audio feedback from their own movement. The game has landing dust, double-jump VFX, but standard running is silent and invisible. This makes ground movement feel "floaty."

**Fix:** Add subtle footstep sounds tied to Humanoid.Running (not Heartbeat — use the animation event). No particles needed, just audio presence.

### P3: Camera FOV Is Static During Gameplay (Medium)
**Issue:** Camera FOV only changes during double-jump (brief +3 kick). During intense late rounds with bombs everywhere, the camera feels the same as R1. No visual urgency.

**Fix:** Gradually increase base FOV in late rounds: R1-4 at default, R5 at +2, R6 at +4, R7 at +6. Subtle, but it subconsciously communicates "things are more intense." Reset on round end.

### P4: No "Phew!" Moment After Round Clear (Medium)
**Issue:** Round clear plays a chime and shows text, but there's no *relief* feedback. The player's body state (tense, focused) needs a signal to briefly relax. Currently the transition from "dodging bombs" to "round clear" is just... text change.

**Fix:** On round_survived, briefly slow motion (set game time to 0.5 for 0.3s, then restore). This creates a "world stops to celebrate" feel. Alternatively: a brief white flash + camera zoom out.

### P5: Lobby Has No Urgency Cue (Low)
**Issue:** The lobby countdown is now 3 seconds. Good. But there's no audio tick during the countdown. Players not looking at their screen will miss the game start.

**Fix:** Play the existing `RoundTick` sound at each countdown tick (3, 2, 1). Already have the sound asset.

### P6: No Damage Numbers Visible to OTHER Players (Low)
**Issue:** Floating damage numbers are client-only (FireClient). Spectators watching a player take hits see no numbers. This makes spectating less engaging.

**Fix:** Use FireAllClients for damage events with player reference, so spectators see numbers on the player they're watching.

---

## PART 5: BALANCE REFINEMENTS

### B1: Timed Bomb Radius Is Enormous (24 studs)
**Context:** Standard bomb blast radius is 16 studs. Timed bomb is 1.5x = 24 studs. At 24 studs, the blast diameter is 48 studs — nearly a quarter of the arena width. Combined with 52 damage (half HP), this is the #1 cause of "unfair" deaths.

**Fix:** Reduce to 1.3x (20.8 studs). Still the biggest blast in the game, still threatening, but survivable if you react to the fuse.

### B2: Missile Target Repeat Bias
**Context:** Random target selection means the same player can be targeted by consecutive missiles. In a 2-player endgame, this is 50/50 each time.

**Fix:** Track `lastMissileTarget` and exclude from pool for next missile (unless they're the only one alive).

### B3: Hot Zone Could Be More Impactful
**Context:** Hot zone gets 40% more bombs (multiplier 1.4). This is noticeable but not dramatic enough for players to actively avoid the zone. Super Bomb Survival's equivalent makes zones visibly terrifying.

**Fix:** Increase to 1.6x for R5+ (dynamic scaling). Also consider making the hot zone particle effects more intense in late rounds.

---

## PART 6: PRIORITIZED IMPLEMENTATION PLAN

### Tier 1: Do Now (1-2 hours each, massive impact)

| # | Change | Type | Why Players Love It |
|---|--------|------|---------------------|
| 1 | **WalkSpeed 16 → 20** | Balance | Dodging feels responsive. Deaths feel earned. |
| 2 | **Victory sound** | Polish | The biggest moment deserves audio celebration. |
| 3 | **Personal best display** | Engagement | Every game becomes a competition with yourself. |
| 4 | **Lobby countdown audio ticks** | Polish | Players never miss game start. Builds anticipation. |
| 5 | **Fix stun-lock overlap (R1)** | Bug | No more unfair ragdoll chains from multiple bombs. |

### Tier 2: Do This Week (2-4 hours each, high impact)

| # | Change | Type | Why Players Love It |
|---|--------|------|---------------------|
| 6 | **Game-over recap screen** | Engagement | The retention moment. Players see growth. |
| 7 | **Coin system (earn per round)** | Progression | Reason to play again tomorrow. |
| 8 | **Late-round FOV shift** | Feel | Intensity communicated through the camera. |
| 9 | **Timed bomb radius 1.5x → 1.3x** | Balance | Fewer "impossible to dodge" deaths. |
| 10 | **Missile target fairness** | Balance | No more repeat-targeting frustration. |

### Tier 3: Do This Sprint (4-8 hours each, retention-building)

| # | Change | Type | Why Players Love It |
|---|--------|------|---------------------|
| 11 | **DataStore persistence** | Progression | Stats and coins survive sessions. |
| 12 | **leaderstats (Rounds / Best)** | Social | Players compare with friends on player list. |
| 13 | **Round-clear slow-motion** | Feel | Dopamine spike. "I survived." |
| 14 | **Footstep audio** | Polish | Movement feels grounded and present. |
| 15 | **1 starter ability (Thick Skin)** | Progression | Players have a goal + agency. |

### Tier 4: Future Polish (when core is solid)

| # | Change | Type |
|---|--------|------|
| 16 | Spectator damage numbers | Polish |
| 17 | Hot zone intensity scaling | Balance |
| 18 | Bouncing bomb arena bounds | Bug |
| 19 | Lava death cause accuracy | Bug |
| 20 | Shop UI (spend coins) | Progression |

---

## PART 7: THE ENGAGEMENT GAP — WHY THIS MATTERS

The game's **moment-to-moment gameplay is already good.** The bomb variety, terrain destruction, VFX, and difficulty curve create genuine tension and fun. The double-jump animation is polished beyond what most Roblox games have. The missile system adds a unique "oh no, it's coming for ME" mechanic that few survival games offer.

What's missing is **the meta-layer** — the reasons to play game #6, game #20, game #100. Right now the game offers:
- Play → survive → see "GAME OVER!" text → restart → exact same experience

Front-page games offer:
- Play → survive → see what you earned → see your new personal best → notice you're close to unlocking something → play again → bring your friend to show them your progress

The core loop is the engine. Progression is the fuel. The engine is built. It needs fuel.

**Recommendation:** Implement Tier 1 today (all trivial changes), Tier 2 this week, and Tier 3 before any public release. The game will be unrecognizable in quality.

---

## SUMMARY TABLE: CURRENT vs. TARGET

| System | Current State | Target State |
|--------|--------------|--------------|
| Core loop | Strong (7 rounds, good pacing) | Keep as-is |
| Bomb variety | 5 types + missile (excellent) | Keep, tune timed radius |
| Terrain | Destructible + lava (good) | Keep as-is |
| Movement | Double-jump polished, walk too slow | WalkSpeed 20, footsteps |
| Difficulty | Exponential curve (recently fixed) | Keep, already solid |
| VFX | Grand explosions, directional damage | Add round-clear slow-mo |
| Audio | Type-specific explosions, landing thuds | Add footsteps, victory sound, lobby ticks |
| HUD | HP bar, timer, round dots, kill feed | Add recap screen, personal best, coin counter |
| Progression | None | Coins + DataStore + leaderstats |
| Retention | "One more game" impulse only | Add personal bests, stats, goals |
| Fairness | Mostly good, some stun-lock issues | Fix stun overlap, tune timed bomb |
