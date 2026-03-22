# Top 3 Polish Priorities — Bomb Survival

---

## 1. Bomb Threat Readability (Warning → Impact → Aftermath)

### What feels off
The bomb lifecycle — shadow appears, bomb falls, explosion happens, tiles break — has all the right *pieces* but they don't feel connected into one clear "threat arc." Right now:

- The warning shadow grows from a tiny ring to full size over 1.2s, which is readable, but the bomb body falls independently (starts 0.2s after shadow, arrives 0.8s later). These two things are technically synced but don't *feel* unified because there's no visual link between the shadow on the ground and the bomb in the sky.
- The explosion VFX (glow ball, shockwave ring, debris) fires all at once and resolves in ~1s. It's competent but flat — every bomb explodes the same way regardless of type. A cluster bomb, a timed bomb, and a standard bomb all produce the same visual punch.
- Tile destruction (tiles fly outward, shrink, fade) happens simultaneously with the explosion VFX but reads as a separate event rather than a *consequence* of the blast. There's no stagger or ripple — tiles at the edge of the blast break at the same instant as tiles at the center.

### Why it matters
Bomb readability is the *core skill expression* of the game. The entire gameplay loop is: see threat → move → survive. If the threat isn't crystal-clear, the player dies and feels cheated rather than outplayed. If the explosion doesn't feel powerful, surviving it doesn't feel satisfying. This is the single highest-leverage thing to polish because it directly affects every second of active gameplay.

### What "great" looks like
A player should be able to glance at the arena and instantly understand: where bombs are landing, which ones are most dangerous, and how much time they have. The explosion should feel like a *moment* — a half-second where the screen communicates "something big just happened here." Tile destruction should ripple outward from the blast center so it reads as a shockwave, not an instant grid deletion.

### How to improve it

**A. Connect the shadow to the bomb with a vertical beam.** A thin, semi-transparent red Neon part from the shadow dot up toward the bomb body. This creates a visual column that says "bomb falling HERE." The beam shrinks as the bomb gets closer, creating urgency. Simple Part + Tween, no new systems.

**B. Stagger tile destruction by distance from blast center.** Currently all tiles in radius break simultaneously. Instead: tiles at distance 0 break at t=0, distance 1 at t=0.08, distance 2 at t=0.15. This creates a visible ripple/shockwave radiating outward. Just add a `task.delay(dist * 0.08)` before each `destroyTile` call in `DestroyAt`.

**C. Differentiate explosion VFX by bomb type.** The `explodeAt` function in BombSystem already knows the bomb type but passes the same visual to ExplosionVFX. Add subtle color tinting:
- Standard: orange flash (current)
- Bouncing: green-tinted flash
- Timed: brighter/larger flash (it's 1.5x radius, make it feel it)
- Cluster minis: smaller, snappier pops (already somewhat different, but could be more distinct)

This is a color/size parameter change in the existing VFX call, not a new system.

**D. Add a brief camera punch on nearby explosions.** `BombLanded` already does screen shake scaled by distance. But the shake is uniform random. Replace with a single sharp downward "punch" (camera CFrame offset for 2 frames, then spring back) for nearby blasts. This reads as impact rather than earthquake. Modify the existing `screenShake` function.

---

## 2. Survival Tension Arc (Round Pacing + Escalation Feel)

### What feels off
Each round is 23 seconds with bombs falling, but the *feeling* of escalation is mechanical rather than visceral. The difficulty formula (`1.3 + (round-1)*0.5`, capped at 4.5) correctly increases bomb frequency and destruction chance, but the player doesn't *feel* rounds getting harder until they suddenly die. There's no building dread.

Specific gaps:
- **Inter-round transition is dead air.** After "ROUND SURVIVED!", there's a 4-second countdown with "Bombs in Xs" text and no other feedback. The player just... stands there. No music shift, no visual change, no environmental cue that things are about to get worse.
- **Mid-round has no crescendo.** Bombs fall at a steady rate throughout the round. The last 5 seconds feel the same as the first 5 seconds. The `timerUrgency` function does red-tint the timer text and pulse at 5s, but this is a tiny UI element — not a *felt* change in the world.
- **Round survival confetti is the only positive feedback.** It fires once at round end. There's no micro-reward during the round itself (e.g., a close dodge, surviving a cluster bomb, lasting past the halfway point).

### Why it matters
Tension is what makes survival games replayable. Without a felt escalation, each round blurs into the next and the player disengages. The game currently has the *mechanics* of escalation (more bombs, more destruction) but not the *feel* of it. Players should be leaning forward in their chair by round 3, not just watching numbers tick.

### What "great" looks like
The player *feels* each round getting harder before they consciously process it. The air feels different. The ground looks different. The transitions between rounds build anticipation ("oh no, here comes round 4"). Mid-round has identifiable "phases" — calm opening, building middle, intense finale — even though mechanically it's the same system.

### How to improve it

**A. Darken ambient lighting as rounds progress.** Use `game.Lighting.Ambient` and `game.Lighting.Brightness` to subtly shift the world tone. Round 1: bright, cheerful. Round 4+: slightly darker, warmer (amber tint), more dramatic shadows. This is 4 lines in RoundManager at each `round_start` — tween the Lighting properties. Completely reversible on `return_to_lobby`.

**B. Accelerate bomb rate within each round.** Currently `BOMB_INTERVAL` is constant within a round. Instead, start each round at the normal interval and compress it by 15-20% over the last 8 seconds. This creates a natural crescendo where the final seconds feel frantic even at lower difficulties. Change the interval calc in BombSystem's timer loop to: `interval = baseInterval * (1 - progress * 0.2)` where progress = elapsed/duration.

**C. Add a "round incoming" environmental cue.** When the inter-round countdown hits 2 seconds, briefly shake the camera (tiny, subtle — 0.1 intensity for 0.3s) and play a low rumble. This is the game saying "brace yourself." One `screenShake` call and one new low-frequency sound asset. Not a new system — just hooking into the existing `round_start` handler at `b == 2`.

**D. Surface the difficulty to the player.** The difficulty bar (`diffBar`) exists in the HUD but it's a tiny 3px-tall bar that's easy to miss. On round 4+, add a brief "DANGER LEVEL: HIGH" milestone text (using the existing `showMilestone` function). No new UI — just a conditional call when difficulty crosses thresholds like 3.0 and 4.0.

---

## 3. Player Death Experience (From "I Died" to "I Want to Try Again")

### What feels off
Death is the most common outcome in a bomb survival game, which means the death experience is arguably *the most repeated moment in the entire game*. Currently:

- **Death sound** was recently changed to an arcade blip (0.5s) — better than before, but still feels disconnected from the visual. The sound plays, the screen flashes white, particles burst, camera pulls back... these all happen but don't feel choreographed into one moment.
- **Death screen** fades in with "Eliminated!" text and cause of death, but it sits there passively while the player spectates. There's no prompt, no encouragement, no "here's how you did" moment. Just... waiting.
- **Spectating** is functional (camera follows a survivor) but there's no UI indication of who you're spectating, no way to switch targets, and no visual distinction between "I'm alive" and "I'm spectating someone else." The player can feel lost.
- **The gap between dying and the next game** is psychologically critical. Right now it's: die → spectate → game over screen → fade → lobby → wait → next game. That's a lot of dead time where the player has no agency and might leave.

### Why it matters
Every mobile/casual game designer knows: the moment after failure determines whether the player retries or quits. If death feels punishing, slow, or boring, players leave. If death feels quick, clear, and immediately followed by a reason to try again, players stay. This game's retention will live and die (literally) on this 5-10 second window.

### What "great" looks like
Death feels like a punchline, not a punishment. It's quick, clear, maybe even slightly funny. The player immediately understands what killed them, sees their stats, and feels pulled toward "one more try." Spectating feels like entertainment, not purgatory. The transition back to the next game is fast and exciting.

### How to improve it

**A. Tighten the death sequence timing.** Currently: death VFX (particles + flash) → 0.8s camera pull-back → 1.0s hold → spectate starts at 2.5s. That's too slow. Compress to: death VFX → 0.4s quick zoom-out → 0.5s hold → spectate at 1.2s. The player should be watching a survivor within 1.5 seconds of dying. Adjust the `task.delay(2.5)` in the PlayerDied handler and the camera lerp duration.

**B. Add stats to the death screen.** Below "Eliminated!" and the cause, show: "Survived X rounds | Xs alive | Best: Ys". The data already exists (`currentRound`, `survivalStart`, `bestTime`). This turns a dead moment into a micro-reward — the player sees their progress and wants to beat it. Just add 1-2 TextLabels to the existing death screen.

**C. Add spectate target indicator.** When spectating, show a small TextLabel at the bottom: "Spectating: [PlayerName]". This takes the confusion out of suddenly watching someone else's POV. One TextLabel, updated in the existing spectate loop.

**D. Shorten game-over to lobby transition.** Currently the game-over screen shows for several seconds, then fades to lobby, then waits for next game. Compress the game-over hold to 2 seconds max. Add "Next game in Xs" to the lobby status to give the player something to anticipate. The lobby wait should feel like a loading screen for the next round, not idle time.
