# Bomb Survival — Addiction & Polish Roadmap

Deep analysis of the current prototype. What makes bomb survival games addictive, what this game does well, what's holding it back, and exactly what to fix — all within existing systems.

---

## PART 1: Core Components of an Addictive Bomb Survival Game

### 1. Readable Danger → Skillful Dodge (The Core Verb)
The entire game is "see threat, dodge threat." Every system must serve this. Warnings must be instant to parse. Dodge windows must feel tight but fair. Players who die must feel they *could* have dodged if they'd been better. Players who survive must feel skilled, not lucky.

**Current state:** Strong. Shadows, tracking beams, color-coded bomb types, growing warning rings — the visual language is good. LOS damage (v14) makes elevation meaningful. The exponential bomb curve creates genuine panic in the last third.

**Gap:** Cluster mini-bombs have NO warning. Players die to invisible threats. This is the one place where death feels unfair rather than earned. Also, bomb whistles play at spawn height (100 studs up) with no spatial relationship to where the player is standing — they're just ambient noise, not useful information.

### 2. Escalating Tension Arc (Why Players Stay)
Each round must feel harder than the last, with clear "I'm being pushed to my limit" signaling. The player should feel the pressure building — not just through more bombs, but through environmental decay, audio shifts, visual mood changes, and UI urgency. The tension has to crescendo, not plateau.

**Current state:** Good foundation. Difficulty scales 1.3→4.3 over 7 rounds. Arena lighting darkens. Bomb intervals compress exponentially. Mid-round pressure spikes at 38% and 68%. Terrain destruction accumulates, creating craters and exposing lava.

**Gap:** The tension arc plateaus perceptually around round 4-5. By that point the screen is already chaotic and adding more bombs doesn't feel *different*, just *more*. The game needs qualitative escalation (the nature of the threat changes) not just quantitative (more of the same). Currently, special bomb types scale probabilistically, but the player can't feel the difference between 15% timed bombs and 20% timed bombs. Rounds 5-7 should feel dramatically different from rounds 1-3 — right now they feel like "round 3 but faster."

### 3. The Dopamine Beat (Round Survived → Heal → Go Again)
The moment between rounds is the game's "slot machine pull." The round-clear chime, the green flash, the +HP float, the brief safety — this is when the brain decides "one more round." It must feel GREAT. Short, punchy, unmissable.

**Current state:** Strong after recent polish. Chime with escalating pitch, green screen wash, +HP float, confetti, HP bar flash, status text punch. The 1.5-second window is well-timed.

**Gap:** The inter-round countdown (4 seconds with amber numbers) feels like dead time AFTER the dopamine moment. The emotional sequence should be: survive → CELEBRATION → tension building → GO. Currently it's: survive → celebration → wait → wait → wait → wait → go. Those 4 seconds of countdown with nothing happening except numbers on screen kill the momentum. The countdown should be compressed or filled with useful information (hot zone warning, player count, arena preview).

### 4. Death That Teaches (Why Players Retry)
Every death should communicate what went wrong. "I got hit by a bouncing bomb while running from a timed bomb" is a learning moment. "I died to something I couldn't see" makes players quit. The death screen, the cause text, the killcam-style camera pull — these are the game's second chance to keep the player.

**Current state:** Decent. Death screen shows cause + time + round. Camera pulls back cinematically. Kill feed shows how others died. Spectate lets you watch survivors.

**Gap:** Dead players have a degraded experience. Their timer freezes at death time (stale info). They can't see what round is active without reading the status bar through the death screen overlay. There's no "you lasted X rounds, which was the Nth longest" — no comparative context. No prompt to retry or indication of when the next game starts. The spectate camera snaps instantly between targets with no smooth transition.

### 5. Environmental Storytelling (The Arena Tells a Story)
The arena should visually tell the story of the game. Fresh green tiles at round 1. Craters and exposed stone by round 3. Lava visible through gaps by round 5. A ravaged battlefield by round 7. This environmental decay IS the difficulty — not just cosmetic. Players should look at the arena and *feel* how far they've survived.

**Current state:** Excellent mechanically. Probabilistic tile destruction with ripple effects creates organic crater patterns. Lava lights brighten as tiles above them are destroyed. Three elevation tiers with ramps create natural terrain variety. Map modifiers (craters, bridges, elevated center) add per-game variation.

**Gap:** The visual decay is subtle. By round 5, many tiles are destroyed, but bedrock is grey-on-grey and doesn't look dramatically different from intact stone tiles. The transition from "pristine arena" to "war zone" needs more visual contrast. Scorch marks fade after 9 seconds so they don't accumulate into a "history of bombardment." The lava glow brightening is a nice touch but hard to notice in the chaos.

### 6. Social Pressure & Audience (Multiplayer Juice)
In multiplayer survival, watching others die is half the fun. The kill feed, the "LAST ONE STANDING" callout, spectating survivors — these create stories. "I outlasted everyone except that one player who was insane." Being the last survivor should feel like a spotlight moment.

**Current state:** Basic. Kill feed shows eliminations. Last survivor gets a milestone + heal. Leaderboard tracks alive/dead status. Spectate lets dead players watch.

**Gap:** No "X players remaining" display during gameplay. The kill feed disappears after 4 seconds — by the time 3 players die in quick succession, the first one has faded. No dramatic "3 PLAYERS LEFT... 2 PLAYERS LEFT..." callouts that build audience tension. The leaderboard is tucked in the corner and hard to read during action.

---

## PART 2: What Works Well (Don't Touch)

These systems are solid and should not be changed:

- **Bomb type visual language**: Black/orange standard, green bouncing, red timed, purple cluster — instantly readable
- **Explosion VFX**: Grand, cartoony, and performant. Core + shockwave + smoke + dirt + stars + ground sparks. Color-tinted per type.
- **Double-jump feel**: Flip animation + air ring + FOV kick + speed streaks. Feels crisp and responsive.
- **Damage feedback stack**: Red flash + shake + tint + sparks + directional indicator + floating numbers. Layered and clear.
- **Round-survived celebration**: Chime + green wash + HP float + confetti. Punchy and satisfying.
- **LOS damage system**: Elevation now matters. Terrain provides real cover. Destroyed tiles create danger.
- **Terrain destruction ripple**: Staggered tile destruction looks organic and dramatic.
- **Knockback scaling**: Light hits slide, heavy hits launch. PlatformStand scales with severity.

---

## PART 3: Prioritized Improvements (Existing Systems Only)

### TIER S: Game-Defining Polish (Do These First)

#### S1. Compress Inter-Round Dead Time
**Current:** 4-second countdown with amber numbers after round-survived.
**Problem:** Kills momentum after the dopamine moment. Players just stand there for 4 seconds.
**Fix:** Reduce to 3 seconds. Move hot zone announcement to the countdown (b==3). Show "X PLAYERS ALIVE" at b==2. This fills the countdown with useful information instead of empty waiting.
**Impact:** Massive. The gap between rounds is where players decide to keep playing or leave. Dead time = lost players.

#### S2. Add Alive Player Count Display
**Current:** No persistent display of how many players are alive. Kill feed shows deaths but fades in 4 seconds.
**Problem:** Players can't gauge where they stand. "Am I the last one? Are there 5 others?" This information drives tension.
**Fix:** Add a small persistent "5 alive" indicator near the TopBar. Pulse it on eliminations. Show "LAST ONE STANDING" when count hits 1 (already exists as a milestone but should be more prominent).
**Impact:** High. Knowing you're one of the last 2-3 survivors is the most exciting moment in any survival game. Currently invisible.

#### S3. Improve Dead Player / Spectator Experience
**Current:** Frozen timer, death screen overlay partially blocking info, no round context.
**Problem:** Dead players have no reason to keep watching. They leave, which drains the server.
**Fix:** After 2 seconds, shrink the death screen to a small "You: R3, 1:45" banner at the top. Show current round/timer for the live game. Add smooth camera transitions between spectate targets (0.3s lerp instead of instant snap). Show "X players left | Round Y / 7" in the spectate UI.
**Impact:** High. Retaining dead players as spectators keeps lobbies full and creates social moments.

#### S4. Add Warning to Cluster Mini-Bombs
**Current:** Mini-bombs spawn and arc with physics. No shadow, no ground warning. Players die to invisible threats.
**Problem:** The only bomb type with no warning. Deaths feel unfair.
**Fix:** When each mini-bomb spawns, create a brief (0.4s) small red pulse at its predicted landing position (use velocity to estimate). Doesn't need to be perfect — even an approximate warning gives the player agency.
**Impact:** High. Fairness is the foundation of retention. One unfair death mechanic can outweigh ten polished ones.

---

### TIER A: High-Impact Feel Improvements

#### A1. Lava Damage Debounce (Anti-Strobe)
**Current:** Lava ticks every 0.5s, each tick fires steam + flash + sizzle. 6-7 identical flashes before death.
**Fix:** Fire the heavy VFX (steam burst, orange flash, tint) only every 1.5 seconds. Between ticks, show a persistent lava overlay (orange vignette at 0.9 transparency) so the player knows they're still on lava without the strobe.
**Impact:** Medium-high. The strobe is actively unpleasant and makes lava feel buggy rather than dangerous.

#### A2. Qualitative Late-Round Escalation
**Current:** Rounds 5-7 feel like "more of the same, faster." The nature of the threat doesn't change.
**Fix:** Small qualitative shifts that use existing systems: Round 5+ bombs fall faster (reduce BOMB_WARN_TIME by 15-20% in late rounds). Round 6+ scorch marks linger longer (12s instead of 9s, creating visual chaos). Round 7 "everything" round: warning beep plays double-speed, arena lighting drops to near-dark. All within existing code — just config changes per round.
**Impact:** Medium-high. Rounds 5-7 need to feel like a CLIMAX, not a plateau.

#### A3. Lobby "Next Game" Countdown
**Current:** Lobby shows "WAITING..." and "Next game starting..." with no timing info. Players don't know if it's 2 seconds or 20.
**Fix:** Show a simple "Next game in Xs" countdown in the status bar during lobby. Map build happens in parallel (it already does), so the countdown reflects actual wait time.
**Impact:** Medium. Uncertainty about wait times makes players leave. A countdown says "stay 3 more seconds."

#### A4. Near-Miss Directional Indicator
**Current:** Near-miss shows centered text ("CLOSE CALL!") that's easy to miss during action.
**Fix:** Reuse the directional damage indicator system (already exists) but in yellow/white instead of red. Player peripherally notices "something almost got me from the left" without having to read text.
**Impact:** Medium. Near-miss feedback is a dopamine driver. The current text-based system wastes this opportunity.

---

### TIER B: Polish Refinements

#### B1. Smooth Spectate Camera Transitions
**Fix:** When clicking to switch spectate targets, lerp the camera over 0.3s to the new target instead of instant snapping.

#### B2. Kill Feed Duration and Stacking
**Fix:** Increase kill feed display from 4s to 6s. Increase max visible from 3 to 5. In rapid-death scenarios (late rounds), players should see the carnage.

#### B3. Game-Over Recap for All Players
**Fix:** On game_over, show a brief results panel: "You survived X rounds (Y:ZZ) | Best: PlayerName (Z rounds)" — gives comparative context.

#### B4. Bomb Whistle Spatial Audio
**Fix:** Play the whistle on the bomb's body (already done via PlayOn), but reduce RollOffMaxDistance to 60 so distant bombs are quiet and nearby bombs are clearly "above me."

#### B5. Walking/Running Subtle Feedback
**Fix:** Tiny camera bob while sprinting (0.02 stud amplitude, tied to movement speed). Optional — don't add if it causes motion sickness concerns.

---

## PART 4: Implementation Priority Order

| Order | Item | Effort | Impact |
|-------|------|--------|--------|
| 1 | S2. Alive player count display | Low | Very High |
| 2 | S4. Cluster mini-bomb warnings | Low | Very High |
| 3 | S1. Compress inter-round to 3s + fill with info | Low | Very High |
| 4 | A1. Lava damage debounce | Low | High |
| 5 | S3. Improve spectator experience | Medium | High |
| 6 | A3. Lobby countdown | Low | Medium |
| 7 | A4. Near-miss directional indicator | Low | Medium |
| 8 | A2. Late-round qualitative escalation | Low | Medium-High |
| 9 | B1. Smooth spectate camera | Low | Medium |
| 10 | B2. Kill feed duration | Trivial | Low-Medium |
| 11 | B3. Game-over recap | Medium | Medium |
| 12 | B4. Bomb whistle spatial | Trivial | Low |

---

## PART 5: The "Perfect" Standard

For this game to feel front-page quality, every second of the player's experience must feel intentional:

**Lobby:** "Next game in 3s" → anticipation builds.
**Drop:** Black screen → arena reveal → "wow, this map has bridges."
**Round 1:** Easy. Learn the space. See bombs fall. Dodge. Feel competent.
**Round 3:** "WARMING UP!" — things are getting real. Terrain has holes. Special bombs appearing.
**Round 5:** "Oh no." Arena is cratered. Lava visible. Bombs every half-second. Heart racing.
**Round 7:** Pure survival. Dark arena. Bombs everywhere. The floor is half-gone. Every dodge feels heroic.
**Victory:** "VICTORY!" — gold explosion, confetti, pride. "I survived all 7."
**Death at R5:** Camera pulls back. "Blown up by a timed bomb! | 2:15 alive | Round 5." Watch the last survivors. "Next game in 4s." → "I can get to round 6 this time."

Every moment has purpose. Every transition is smooth. Every piece of feedback tells the player exactly what happened and what to do next. That's the standard.
