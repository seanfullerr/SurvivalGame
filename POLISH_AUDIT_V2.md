# Bomb Survival — Phase 1 Polish Audit (Complete)

Comprehensive analysis of every script, UI element, and system interaction. No new features — only smoothing what exists.

---

## TIER 1: HIGH IMPACT, LOW EFFORT

### 1. BombLanded fires BEFORE the bomb actually lands
**File:** BombSystem `cloneBombAt()`
**Issue:** `GameEvents.BombLanded:FireAllClients(pos)` fires immediately when the bomb is *created at fall height*, not when it *impacts*. The client receives the event and plays camera punch / screen shake while the bomb is still falling from 100 studs up. Then `explodeAt()` fires BombLanded *again* on actual impact — so every standard bomb triggers the client-side impact feedback TWICE.
**Fix:** Remove the BombLanded call from `cloneBombAt()`. It only needs to fire from `explodeAt()` and the cluster initial-impact path. One line removal.
**Why it matters:** Double camera punches feel glitchy and desensitize players to the feedback. This is the single biggest "something feels off" issue.

### 2. Spectate label created in code but never parented to GameHUD properly
**File:** HUDController
**Issue:** `spectateLabel` is referenced in startSpectating/stopSpectating but its creation uses `gui` as parent — which works, but it's a floating TextLabel with no consistent positioning relative to the TopBar. During spectate the death screen Sub text ALSO shows "Spectating X" — redundant double-display.
**Fix:** Either remove spectateLabel entirely (death screen Sub already handles it) or position it cleanly below the HP bar area. Pick one source of truth.
**Why it matters:** Two overlapping "Spectating: PlayerName" messages look unpolished.

### 3. Countdown "GO!" text persists too long / overlaps with survive phase
**File:** HUDController, `countdown_go` handler
**Issue:** GO! text fades out after 0.6s delay + 0.4s tween = 1.0s total. But `round_start` with b=4 fires just 0.5s after countdown_go (server does `task.wait(0.5)` then enters the round loop). So the round_start handler starts writing to countdownLabel while GO! is still fading, causing a visible flicker from "GO!" to "4".
**Fix:** In the server, extend the post-GO wait to 1.2s, OR in the client, immediately clear countdownLabel at the top of the round_start b==4 handler before writing the new number.
**Why it matters:** Flickering text between phases breaks the clean flow.

### 4. HP bar `Fill` size calculation uses hardcoded 280 but bar is now 320px wide
**File:** HUDController, `updateHPBar()`
**Issue:** `Size = UDim2.new(math.max(0.001, pct) * (1 - 6/280), 0, 1, -4)` — the `6/280` padding ratio is stale (bar was widened from 280 to 320). This makes the fill slightly too wide, potentially overlapping the rounded corner.
**Fix:** Change `6/280` to `6/320`, or better, compute it dynamically from `hpBar.AbsoluteSize.X`.
**Why it matters:** Subtle visual glitch — fill pokes out of rounded corners at high HP.

### 5. Lobby state doesn't fully reset UI elements
**File:** HUDController, `lobby_wait` handler
**Issue:** Several UI elements aren't reset on return to lobby: lowHPOverlay color (could be red from death vignette), flash frame (could have stale color), statusLabel TextSize (could be scaled from round punch). Also `countdownLabel.TextTransparency = 1` but TextSize may still be 80 from last inter-round countdown.
**Fix:** Add explicit resets: `statusLabel.TextSize = 20`, `lowHPOverlay.BackgroundColor3 = original`, `countdownLabel.TextSize = 100`.
**Why it matters:** Stale visual state bleeds between rounds, especially noticeable on fast restarts.

### 6. Leaderboard shows 0 rounds / 0 time for client-side fallback
**File:** HUDController, leaderboard fallback (runs every 3s)
**Issue:** When no server update has arrived in 5s, the fallback builds a leaderboard with `rounds = 0, time = 0` for everyone. This means in-lobby the leaderboard shows all players with "R0 0:00" which is ugly and uninformative.
**Fix:** In lobby state, either hide the leaderboard entirely, or show just names without the round/time suffix.
**Why it matters:** "R0 0:00" next to every name in lobby looks broken, not polished.

---

## TIER 2: MEDIUM IMPACT, LOW-MEDIUM EFFORT

### 7. Bouncing bomb collision is inconsistent
**File:** BombSystem, `spawnBouncingBomb()`
**Issue:** After the fall tween completes, `body.Anchored = false` lets physics take over with `AssemblyLinearVelocity`. But the bomb model may have multiple BaseParts whose offsets were maintained by a Heartbeat connection that's now disconnected. These child parts become orphaned at the impact point, creating phantom collision boxes.
**Fix:** After `conn:Disconnect()`, destroy all non-PrimaryPart children or weld them to body before unanchoring.
**Why it matters:** Players can get stuck on invisible phantom parts from bouncing bombs. Feels buggy.

### 8. Cluster mini-bombs lack warning indicators
**File:** BombSystem, `spawnClusterBomb()`
**Issue:** Standard/timed/bouncing bombs all get shadow warnings. Cluster mini-bombs just appear and explode. Players die to what they can't see coming, which feels unfair rather than challenging.
**Fix:** Add a brief (0.3s) small red circle under each mini-bomb between spawn and detonation. They already have a trail, but a ground shadow gives critical "dodge NOW" info.
**Why it matters:** Fairness is crucial for front-page retention. Deaths should feel avoidable.

### 9. Death camera pull-back uses Scriptable mode with no safe fallback
**File:** HUDController, `PlayerDied` handler
**Issue:** Camera goes `CameraType.Scriptable` for the pull-back animation. If the player character respawns or is destroyed during the 0.4s lerp, the camera can get stuck in Scriptable mode pointing at nothing. The `task.delay(1.2)` then switches to Custom for spectating, but there's a 0.8s window where the camera could be lost.
**Fix:** Add a safety check: if `startCF` or `deathPos` produces a NaN/inf CFrame (character already destroyed), skip the pull-back and go straight to spectate.
**Why it matters:** Stuck camera = player mashes reset = bad experience.

### 10. Timer urgency effects don't account for multi-round timing
**File:** HUDController, `timerUrgency()`
**Issue:** The function triggers at "10 seconds left" and "5 seconds left" in the round. But `survivalTime` passed to survive handler is total game time, not round time. The `b` parameter is seconds remaining in the current round, which IS used for urgency — this is correct. However, `statusLabel.TextColor3` gets set to orange/red by urgency but is never reset between rounds, so round N+1 starts with red status text from the previous round's final seconds.
**Fix:** Reset `statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)` at the start of each `round_start` b==4 block.
**Why it matters:** Red "ROUND 3 / 7" text at the start of a round sends the wrong signal.

### 11. Near-miss detection radius is generous but invisible
**File:** BombSystem, `NEAR_MISS_MULT = 1.3`
**Issue:** Near-miss triggers at 1.3x blast radius, which is only 4.8 studs beyond the damage zone. Players often don't realize they just dodged — the near-miss text appears but there's no directional context about WHERE the near miss was.
**Fix:** Reuse the directional damage indicator (but in white/yellow instead of red) for near-misses. Player instantly knows "that bomb to my left almost got me."
**Why it matters:** Near-miss feedback is a huge dopamine driver. Right now it's easy to miss the small text.

### 12. Heal amount hardcoded in HUD but server sends percentage
**File:** HUDController `round_survived` handler vs PlayerManager `HealPlayers`
**Issue:** HUD always shows `+30 HP` (hardcoded `local healPct = 30`). Server heals 30% of MaxHealth (which is 100, so it works out). But if MaxHP ever changes, the HUD lies. Also, the actual heal could be less than 30 if the player is near full HP, but the HUD always says +30.
**Fix:** Use the actual heal amount from the `PlayerDamaged` event (which fires with negative dmg for heals) instead of hardcoding.
**Why it matters:** Accurate feedback builds trust. Showing "+30 HP" when you only gained +12 feels wrong.

---

## TIER 3: MEDIUM IMPACT, MEDIUM-HIGH EFFORT

### 13. No audio feedback when bombs are cleaned up between rounds
**File:** BombSystem `StopBombs` handler
**Issue:** `StopBombs` instantly destroys all bombs after 0.3s. In-flight bombs, ticking timed bombs, bouncing bombs — all just vanish silently. This is jarring, especially if a timed bomb was about to explode.
**Fix:** Before cleanup, fire a "round ending" signal that triggers a quick "all clear" sound and maybe a brief white flash on client. Or let in-flight bombs finish naturally during the 1.5s round_survived window.
**Why it matters:** Abrupt silence + disappearing objects breaks immersion.

### 14. Lava damage interval (0.5s) with 15 DPS feels spammy
**File:** PlayerManager Heartbeat loop
**Issue:** Lava ticks every 0.5s for `LAVA_DPS * 0.5 = 15` damage. That's 6.67 ticks to kill from full HP. The LavaContact event fires every tick, triggering steam VFX and screen flash 13 times before death. This creates a strobe-like effect that's more annoying than dangerous-feeling.
**Fix:** Either increase the interval to 0.8s with proportionally higher damage (same DPS, fewer flashes), or debounce the VFX on client (only show steam burst every 1.5s, show a persistent lava overlay between).
**Why it matters:** Rapid identical flashes feel buggy, not dangerous. A slower, heavier tick feels more menacing.

### 15. Map modifier announcement has no visual distinction
**File:** RoundManager + HUDController
**Issue:** Map modifiers ("CRATERS", "HIGH GROUND", "BRIDGES") use the same milestone text system as round milestones. Players might not even register that the map layout has changed because it looks like any other popup.
**Fix:** Give map modifier announcements a distinct color scheme (cool blue vs warm gold for milestones) and slightly longer display time (2.5s vs 1.8s). Maybe add a subtle camera pan of the arena during the lobby-to-arena transition.
**Why it matters:** Map variety is a key replayability hook. If players don't notice it, it's wasted content.

### 16. Hot zone notification competes with round start
**File:** RoundManager game loop
**Issue:** `hot_zone` fires right after `StartBombs`, which is right after the inter-round countdown ends. The "HOT ZONE: NORTH-WEST" milestone appears while players are still processing "ROUND 3 / 7" and the survive phase starting. Information overload.
**Fix:** Show hot zone info DURING the inter-round countdown (at b==3 or b==2) instead of after it, so players have time to read it and position themselves.
**Why it matters:** Critical tactical info that arrives too late to act on is wasted.

### 17. Knockback feels floaty — no ground stick after short knockbacks
**File:** BombSystem `applyKnockback()` + PlayerManager
**Issue:** Knockback uses LinearVelocity with a 0.3s duration and always includes upward boost (0.7 + knockScale * 0.3). Even small edge-of-blast knockbacks lift the player off the ground, triggering freefall state, double-jump cooldown, and landing VFX. Small knockbacks should push horizontally without vertical lift.
**Fix:** Only apply upBoost when `knockScale > 0.4`. For light knockbacks, use mostly horizontal push. Also, `PlatformStand = true` for 0.4s is aggressive — reduce to 0.2s for light hits.
**Why it matters:** Getting knocked into freefall by a distant explosion feels disproportionate and disorienting.

### 18. Death screen info text wraps awkwardly on mobile
**File:** GameHUD Death > Sub
**Issue:** Sub label is 500x30 with TextSize 18. The death message format is: `"Caught by a bomb! | 1:45 alive | Round 5"` — that's ~40 characters. On mobile screens (<400px wide), this will clip or wrap mid-word.
**Fix:** Use `TextScaled = true` with `TextWrapped = false` on the Sub label so it auto-sizes down on small screens instead of wrapping.
**Why it matters:** Mobile is 60%+ of Roblox players. Clipped death info looks broken.

---

## TIER 4: LOWER IMPACT / NICE-TO-HAVE

### 19. Milestone thresholds don't align with MAX_ROUNDS = 7
**File:** HUDController milestones table
**Issue:** Milestones fire at rounds 3, 5, 8, 10, 15. With MAX_ROUNDS = 7, rounds 8/10/15 can never trigger. Only "WARMING UP!" (R3) and "SURVIVOR!" (R5) will ever show. The victory handler replaces what would be R7's milestone.
**Fix:** Adjust to rounds 2, 4, 6 with escalating messages, or remove the unreachable entries to keep the code clean.

### 20. Scorch marks accumulate without limit
**File:** BombSystem `createScorchMark()`
**Issue:** Each explosion creates a scorch mark Part that lingers for 9s. In late rounds with rapid bombing, dozens of scorch marks exist simultaneously. They do fade out, but the Part count adds up.
**Fix:** Cap active scorch marks at ~15-20, removing oldest when exceeded.

### 21. Camera FOV kick from double jump doesn't check if already tweening
**File:** DoubleJump `doFOVKick()`
**Issue:** If the player double-jumps immediately after landing (which resets jumps), the FOV tween from the previous jump might still be playing. Overlapping FOV tweens create jittery camera.
**Fix:** Track the FOV tween and cancel it before starting a new one, or use a debounce flag.

### 22. DoubleJump indicator dot has no mobile-friendly touch alternative
**File:** DoubleJump
**Issue:** The jump indicator is an 8px dot. On mobile, the jump button is the built-in Roblox button. The tiny dot doesn't serve the same purpose as it does on PC where players use spacebar.
**Fix:** Consider making the indicator larger on mobile (use `UIS.TouchEnabled` check) or skip it entirely for touch.

### 23. Explosion sound is same asset for both Explosion and SmallExplosion
**File:** SoundManager
**Issue:** Both use `rbxassetid://262562442`. SmallExplosion just plays quieter. They sound identical, which makes bouncing bomb bounces and cluster sub-explosions feel the same weight as full detonations.
**Fix:** Play SmallExplosion at higher pitch (PlaybackSpeed 1.3-1.5) to differentiate. Already partially done in some callers but not consistently.

---

## SUMMARY: TOP 5 ACTIONS (Ordered by Impact)

1. **Fix double BombLanded firing** — Remove the premature fire in `cloneBombAt()`. One line. Massive feel improvement.
2. **Fix GO! → round_start countdown flicker** — Clear countdownLabel at top of round_start handler or extend server wait.
3. **Reset UI state properly between rounds** — statusLabel color, textSize, lowHPOverlay color in lobby_wait.
4. **Fix HP bar fill width ratio** — Change 6/280 to 6/320.
5. **Remove duplicate spectate display** — Pick either spectateLabel or death screen Sub, not both.

These five fixes are all under 10 lines of code each and will noticeably smooth out the player experience.
