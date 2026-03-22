# Bomb Survival — What Feels Off (Post-Tier-1 Fixes)

Fresh analysis of every system after the v21/v12 patch. No new features — just what currently feels rough, wrong, or unsatisfying.

---

## CRITICAL: Things That Will Bother Players Immediately

### 1. Double Landing VFX — Every Jump Produces 2x Dust
Both `HUDController.connectMovementFeedback()` AND `DoubleJump.doLandingVFX()` independently listen for `Humanoid.StateChanged → Landed` and both create dust particles at the player's feet. Every single landing spawns two overlapping dust bursts from two separate scripts. On double-jumps this is especially bad — the DoubleJump script fires its finely-tuned dust system, then HUDController fires its own heavier dust system on top. The result is an over-the-top particle cloud for a basic hop that looks buggy, not polished.

**HUDController** landing: triggers at `impact > 12` (velocity-based), creates dust + ring + "Drop" sound on heavy falls.
**DoubleJump** landing: triggers at `airDuration > 0.3s` (time-based), creates dust + LandThud sound + camera settle.

Both systems are good individually — together they're a mess. One needs to own landing, not both.

### 2. Knockback Always Launches Players Airborne
`damageAndKnockback()` applies `upBoost = 0.7 + knockScale * 0.3` to every single knockback — even tiny edge-of-blast nudges where `knockScale = 0.15`. That minimum upBoost of 0.7 combined with the direction vector creates enough vertical force to pop the player into freefall on basically any hit. This triggers:
- Freefall state (can't walk/strafe to dodge next bomb)
- `PlatformStand = true` for 0.4 seconds (can't move AT ALL)
- Double-jump cooldown reset
- Landing VFX cascade (see issue #1)

Small knockbacks should slide the player horizontally. The 0.4s PlatformStand is particularly bad — in a game where bombs fall every 0.5-1.2 seconds at high difficulty, being frozen for 0.4s is nearly a death sentence. Players will feel "I couldn't do anything" rather than "I got outplayed."

### 3. Bombs Vanish Silently Between Rounds
`StopBombs` sets `spawning = false`, then after 0.3s destroys everything in `bombFolder`. In-flight bombs, ticking timed bombs with glowing fuse circles, bouncing bombs mid-arc — they all just pop out of existence. No explosion, no sound, no fade. One frame they're there, next frame gone.

This is jarring. The player was tracking 3-4 active threats and they all vanish simultaneously. It breaks immersion and makes the round transition feel abrupt rather than earned. The "round survived" feeling needs a clean punctuation mark, not a silent delete.

### 4. Lobby-Wait Doesn't Clear FadeFrame
`lobby_wait` resets many UI elements but never touches `fadeFrame.BackgroundTransparency`. The `return_to_lobby` handler starts a fade-to-black → fade-from-black cycle, but if `lobby_wait` fires during or after that cycle (it fires ~2.5s later), there's no guarantee the fade completed. If a player's character loads while fadeFromBlack is still tweening, or if the tween got cancelled by a new game cycle, they could be stuck on a semi-black or fully-black screen with "WAITING..." text they can't see.

---

## HIGH: Things That Reduce Satisfaction

### 5. Info Line During Survive Phase Is Cluttered
During the survive phase, `infoLabel` shows: `"R3 | 15s left | 1:23"` — that's round number (already shown in status + dots), seconds left (already implied by the timer), and total survival time (same as the timer display). Three pieces of redundant information crammed into a tiny 13pt label. It adds visual noise without adding clarity. The player's eyes should be on the arena, not parsing a dense info string.

### 6. Near-Miss Feedback Is Easy to Miss
Near-miss text ("CLOSE CALL!", "TOO CLOSE!") appears at screen center (Y=0.45) and fades after 0.8s. But during active gameplay, the player's focus is on the arena below center-screen. The text competes with countdownLabel, milestones, and floating damage numbers — all in the same vertical band. There's a brief white flash but it's barely visible at 0.92 transparency. The best near-miss systems in survival games use directional indicators or screen-edge effects that you notice peripherally, not centered text you have to read.

### 7. Lava Damage Creates Strobe Effect
Lava ticks every 0.5s, firing `LavaContact` each time. Each tick triggers: steam particles, orange screen flash, and (on first contact) character tint + screen shake. At 15 damage per tick from 100 HP, that's ~6-7 ticks before death = 6-7 orange flashes in 3 seconds. The rapid identical flashes create a strobe effect that's more annoying than scary. It should feel like slow, ominous melting — not a flickering lightbulb.

### 8. Hot Zone Announcement Arrives Too Late
`showHotZoneBeams(hotZone)` fires after `StartBombs` — meaning bombs are already spawning when the player first sees "HOT ZONE: NORTH-EAST." By the time they read the milestone text (1.8s display), process where NE is, and start moving, they've already taken hits. The information arrives too late to be actionable. It should appear during the inter-round countdown when players have time to reposition.

### 9. Game-Over for Dead Players Is Anticlimactic
When all players die, the server sends `game_over` with a 2-second countdown. But dead players are already in spectate mode watching the last survivor's empty corpse. They see "GAME OVER!" in the status bar, hear a retro sting, and... wait. There's no recap, no summary of their performance, no "you lasted X rounds" in a prominent way. The death screen Sub text already showed their stats, but that was when they personally died — possibly minutes ago. The game_over moment should feel like a collective "welp, we tried" moment with clear feedback.

### 10. Victory Handler Doesn't Stop Bombs
When players survive all 7 rounds, `RoundManager` fires `victory` → waits 3s → `return_to_lobby`. But `StopBombs` fires at the END of round 7's survive loop, and victory fires AFTER the 1.5s round_survived pause. So bombs are already stopped. However, any timed bombs or bouncing bombs still mid-animation from the final seconds of round 7 are killed by StopBombs's 0.3s cleanup — they vanish during the victory celebration. The player sees "VICTORY!" while active threats silently evaporate.

---

## MEDIUM: Rough Edges That Add Up

### 11. Leaderboard Shows Stale Data in Lobby
The fallback leaderboard (fires every 3s when no server update in 5s) shows all players with `rounds = 0, time = 0`. In lobby, this means every entry reads "PlayerName R0 0:00." It's not broken, but it looks unfinished. The leaderboard should either hide in lobby or show just names.

### 12. Spectate Camera Can Get Stuck After Death
The death camera animation uses `CameraType.Scriptable` for a 0.4s pull-back. If the player's character is destroyed during that 0.4s (e.g., server sends return_to_lobby), `startCF:Lerp(targetCF, alpha)` could produce bad CFrame values. The `task.delay(1.2)` then sets Custom mode, but there's a window where the camera could point at nothing. Should have a pcall or nil-check on the lerp target.

### 13. Cluster Mini-Bombs Have No Ground Warning
Standard, bouncing, and timed bombs all get shadow warnings before impact. Cluster mini-bombs spawn at the cluster's impact point and arc outward with physics — no shadow, no warning circle. Players die to threats they couldn't see coming. Mini-bombs have trails, but trails are hard to read against the busy arena. A brief 0.3s red circle under each mini-bomb would make deaths feel fair.

### 14. Milestone "WARMING UP!" at Round 2 Feels Too Early
With only 7 rounds, round 2 is the second thing that happens. Getting "WARMING UP!" after surviving one round feels patronizing rather than rewarding. Round 3 ("you've survived almost half") would be more meaningful. "HALFWAY!" at round 4 is perfect. "ALMOST THERE!" at round 6 is perfect.

### 15. Drop Sound Reuses DoubleJump Sound
`SoundManager` maps both `DoubleJump` and `Drop` to `rbxassetid://320557563` (quick swoosh). The heavy landing "Drop" sound in HUDController uses the same asset as the light, airy double-jump swoosh. This makes big falls sound identical to double-jumps, which muddies the feedback. Heavy landings should sound heavy — a thud or impact, not a swoosh.

### 16. Screen Shake Intensity Isn't Distance-Scaled Consistently
`BombLanded` on client applies distance-based shake for explosions within 70 studs. But `screenShake()` in the damage handler fires based on damage amount, not distance. A bomb that deals 20 damage from 14 studs away produces the same shake as 20 damage from 2 studs away. Close hits should feel dramatically different from grazing hits.

### 17. Timer Urgency Colors Don't Reset After Round Ends
Fixed in Tier 1 for the `round_start` handler, but the survive phase handler still sets `statusLabel.TextColor3` to red/orange during the last 10 seconds. If the round ends (round_survived) while the status is red, the "ROUND X CLEAR!" text starts green (correct) but the red color was never explicitly cancelled — it just gets overwritten. If there's any frame between the urgency set and the clear set, you'd see a red flash. Low priority but technically a race.

---

## LOW: Nice-to-Have Polish

### 18. Scorch Marks Accumulate Without Cap
Each explosion creates a Part that lingers 9 seconds. At max difficulty with bombs every 0.15s, that's ~60 scorch marks at once. They fade out, but the Part count adds up in late rounds.

### 19. FOV Kick from Double-Jump Can Stack
If the player lands and immediately double-jumps again (jump resets on land), the FOV return tween from the first jump overlaps with the FOV kick of the second jump, creating jitter.

### 20. Death Causes Don't Cover All Scenarios
`DEATH_CAUSES` table has entries for standard/bouncing/timed/cluster/fall/lava/reset but not for edge cases like dying to a bomb during the bouncing phase of a bouncing bomb (the mini-explosions during bounces use "bouncing" type, so this is fine) or dying exactly as the round ends (could show wrong round number in death text).

---

## SUMMARY: Top 5 by Impact

| # | Issue | Effort | Why It Matters |
|---|-------|--------|----------------|
| 1 | Double landing VFX (two scripts) | Low | Every single jump looks over-the-top and buggy |
| 2 | Knockback always airborne + 0.4s freeze | Low | Players feel helpless, deaths feel unfair |
| 3 | Bombs vanish silently between rounds | Medium | Breaks immersion at the most important transition |
| 4 | Lobby fadeFrame not cleared | Trivial | Potential black screen softlock |
| 5 | Info line clutter during survive | Low | Visual noise stealing attention from gameplay |
