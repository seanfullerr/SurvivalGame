# Bomb Survival — Round Structure & Game Length Analysis

---

## VERDICT: ROUND STRUCTURE

**Individual rounds (23 seconds): Well balanced.** 23 seconds is in the sweet spot for bomb survival. Short enough that no single round overstays its welcome, long enough for the exponential bomb curve to create a real arc within each round (calm start → frantic finish). The internal pacing — slow first third, exponential last third — is strong. No change needed here.

**Round count (7 rounds): Correct.** Seven rounds gives enough space for a difficulty arc without dragging. Players who die at round 3 feel "I can get further." Players who reach round 6-7 feel accomplished. Reducing to 5 would cut the climax short. Adding to 9-10 would create fatigue. Seven is right.

**Round distinctiveness: Mixed.** Rounds 1-4 feel progressively harder and distinct. Rounds 5-7 suffer from a perceptual plateau — each round is quantitatively harder but the player can't *feel* the difference as clearly. This is the main structural issue (detailed below).

---

## VERDICT: TOTAL GAME LENGTH

**3.4 minutes for a full survive: Appropriate.** This lands squarely in the 2-4 minute window that front-page Roblox survival games target. Short enough for "one more game" impulse. Long enough that surviving all 7 feels like an achievement. No change needed.

**Dead time at 21%: Acceptable, barely.** The benchmark is <20%. We're slightly over, but the inter-round time is now filled with useful information (hot zone, player count, "bombs incoming") which makes it feel shorter than raw seconds suggest. The lobby countdown (5s) is the largest single chunk of dead time.

---

## VERDICT: PLAYER ENGAGEMENT

**Engagement curve: Strong through round 4, softens after.**

The game's engagement follows this emotional arc:

| Round | Feel | Bombs/sec (late) | What's Happening |
|-------|------|-------------------|------------------|
| R1 | Relaxed | 3.4 | Learning the map. Easy. |
| R2 | Comfortable | 4.0 | More bombs but still manageable. |
| R3 | Alert | 4.5 | Missiles appear. Terrain cracking. |
| R4 | Engaged | 4.9 | Halfway. Craters visible. Effort required. |
| R5 | Intense | 5.2 | Warn time drops. Arena crumbling. |
| R6 | Intense | 5.5 | Hard to distinguish from R5. |
| R7 | Intense | 5.7 | Hard to distinguish from R6. |

The problem is clear: rounds 5, 6, and 7 all sit in the 5.2-5.7 bombs/sec range. The perceptual difference between them is too small. The qualitative changes (warn time scaling, scorch duration, darker lighting) help, but the core pressure driver — bomb frequency — plateaus.

**Climax: Present but could be sharper.** Round 7 should feel like a dramatic final stand. Currently it feels like "round 5 but slightly worse." The dark arena helps visually, but the actual gameplay pressure is only 10% higher than round 5.

---

## KEY ISSUE: THE PLATEAU PROBLEM

The difficulty formula `1.3 + (round-1) * 0.5` is linear. This means the *absolute* increase is constant (+0.5 per round), but the *percentage* increase shrinks every round:

- R1→R2: +38% harder (very noticeable)
- R2→R3: +28% harder (clear)
- R3→R4: +22% harder (noticeable)
- R4→R5: +18% harder (starting to blur)
- R5→R6: +15% harder (hard to feel)
- R6→R7: +13% harder (almost identical to R6)

Human perception works on **relative** change, not absolute. A 13% increase simply doesn't register as "harder" when you're already under heavy pressure. This is why the last three rounds feel samey.

---

## RECOMMENDED IMPROVEMENTS

### 1. Switch to Exponential Difficulty Curve

**Change:** `diff = 1.2 * 1.28^(round-1)` instead of `1.3 + (round-1) * 0.5`

This gives constant 28% jumps every round. Same starting difficulty (~1.2), but round 7 hits 5.3 instead of 4.3. The early rounds become slightly easier (more breathing room to learn), and the late rounds become noticeably harder (real crescendo).

| Round | Current | Proposed | Change |
|-------|---------|----------|--------|
| R1 | 1.3 | 1.2 | Slightly easier start |
| R2 | 1.8 | 1.5 | Gentler ramp-in |
| R3 | 2.3 | 2.0 | Similar |
| R4 | 2.8 | 2.5 | Similar |
| R5 | 3.3 | 3.2 | Nearly identical |
| R6 | 3.8 | 4.1 | Harder |
| R7 | 4.3 | 5.3 | Significantly harder |

**Effort: Trivial** — one line change in RoundManager.
**Impact: High** — fixes the plateau, makes round 7 feel genuinely different from round 5.

### 2. Reduce Lobby Countdown from 5s to 3s

The lobby countdown is the single largest dead time chunk. Players in the lobby are already committed — they don't need 5 seconds to decide. 3 seconds is enough to register "game starting" and builds more urgency.

**Effort: Trivial** — change one number in RoundManager.
**Impact: Low-Medium** — shaves 2 seconds of dead time per game, brings dead time below 20%.

### 3. Cap Difficulty at 5.5 (Safety Valve)

With exponential scaling, the formula could produce extreme values if we ever increase MAX_ROUNDS. Add `math.min(..., 5.5)` as a safety cap. At 5.5 difficulty, the bomb interval starts at 0.22s — already near-impossible for most players.

**Effort: Trivial** — add math.min wrapper.
**Impact: Future-proofing.**

---

## WHAT NOT TO CHANGE

- **Round duration (23s):** Well balanced. Don't touch it.
- **Round count (7):** Correct for 3.4-minute target. Don't add or remove rounds.
- **Inter-round timing (4.5s):** Already compressed from original 5.5s. Filled with info. Fine.
- **Bomb interval minimum (0.15s):** This is the physical floor — faster than this and bombs overlap visually. Keep it.
- **Pre-game sequence (lobby → drop → countdown):** The cinematic drop is a signature moment. Don't compress it.

---

## SUMMARY

The game's pacing is fundamentally sound. Total length is right. Round count is right. Round duration is right. The one structural issue is the linear difficulty curve creating a perceptual plateau in rounds 5-7. Switching to an exponential curve (one line change) fixes this and makes the final rounds feel like the dramatic climax they should be. Trimming the lobby to 3 seconds is a small quality-of-life improvement that brings dead time under the 20% benchmark.

The "one more game" loop is already working. These tweaks sharpen the climax to make it land harder.
