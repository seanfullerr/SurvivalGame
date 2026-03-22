-- HUDController v24: Ultra-slim orchestrator (UI revamp + bug fixes)
-- Requires modular HUD/ files, wires up GameEvents, delegates all logic.
-- Target: <12k chars for automated editing compatibility.

local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

---------- MODULES ----------
local HUD = script.Parent:WaitForChild("HUD")
local ctx = require(HUD:WaitForChild("Context"))
local RoundHUD = require(HUD:WaitForChild("RoundHUD"))
local CameraFX = require(HUD:WaitForChild("CameraEffects"))
local DmgFB = require(HUD:WaitForChild("DamageFeedback"))
local DeathSeq = require(HUD:WaitForChild("DeathSequence"))
local Spectator = require(HUD:WaitForChild("Spectator"))
local Celebrations = require(HUD:WaitForChild("Celebrations"))
local RecapPanel = require(HUD:WaitForChild("RecapPanel"))
local CoinHUD = require(HUD:WaitForChild("CoinHUD"))
local MissileFX = require(HUD:WaitForChild("MissileEffects"))
local LavaFB = require(HUD:WaitForChild("LavaFeedback"))
local Leaderboard = require(HUD:WaitForChild("Leaderboard"))

---------- INIT ALL ----------
RoundHUD.init(ctx)
CameraFX.init(ctx)
DmgFB.init(ctx)
DeathSeq.init(ctx)
Spectator.init(ctx)
Celebrations.init(ctx)
RecapPanel.init(ctx)
CoinHUD.init(ctx)
MissileFX.init(ctx)
LavaFB.init(ctx)
Leaderboard.init(ctx)

-- Wire cross-module event connections
MissileFX.connectEvents(RoundHUD.showMilestone, CameraFX.screenShake)
LavaFB.connectEvents(DmgFB.tintCharacter, CameraFX.screenShake)

---------- MENUS GUI REFERENCES (from UI Kit) ----------
-- Find MenusGUI elements to toggle visibility during gameplay
local menusGui = ctx.player:WaitForChild("PlayerGui"):FindFirstChild("MenusGUI")
local cashFrame, interactablesFolder, menusFolder
if menusGui then
    local gameGUI = menusGui:FindFirstChild("GameGUI")
    if gameGUI then
        local centerBottom = gameGUI:FindFirstChild("CenterBottom")
        if centerBottom then cashFrame = centerBottom:FindFirstChild("CashFrame") end
        local interactables = gameGUI:FindFirstChild("Interactables")
        if interactables then
            interactablesFolder = interactables:FindFirstChild("Container") or interactables
        end
    end
    menusFolder = menusGui:FindFirstChild("Menus")
end

local function setMenusVisible(visible)
    if cashFrame then cashFrame.Visible = visible end
    if interactablesFolder then interactablesFolder.Visible = visible end
    -- Close any open menu panels when hiding
    if not visible and menusFolder then
        for _, panel in ipairs(menusFolder:GetChildren()) do
            if panel:IsA("GuiObject") then panel.Visible = false end
        end
    end
end

---------- LOCAL STATE ----------
local st = ctx.state
local GE = ctx.GameEvents

---------- PLAYER DAMAGED ----------
GE.PlayerDamaged.OnClientEvent:Connect(function(dmg)
    if dmg == 0 then
        st.nearMissCount = st.nearMissCount + 1
        DmgFB.showNearMiss()
        if st.lastExplosionPos then DmgFB.showDirectionalNearMiss(st.lastExplosionPos) end
        return
    end
    if dmg == -1 then DmgFB.showLastSurvivor(RoundHUD.showMilestone); return end
    if dmg < 0 then DmgFB.showHealFeedback(math.abs(dmg)); return end

    st.totalDamageTaken = st.totalDamageTaken + dmg
    local intensity = math.clamp(dmg / 25, 0.5, 2.5)
    ctx.SFX.PlayUI("Hit", ctx.camera, {Volume = 0.4 + intensity * 0.2, PlaybackSpeed = 0.8 + math.random() * 0.4})

    ctx.flash.BackgroundColor3 = Color3.fromRGB(255, 40, 20)
    ctx.flash.BackgroundTransparency = math.clamp(0.15 + dmg / 60, 0.2, 0.55)
    ctx.TweenService:Create(ctx.flash, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {BackgroundTransparency = 1}):Play()

    CameraFX.screenShake(intensity * 1.5, 0.25 + intensity * 0.1)
    DmgFB.tintCharacter(ctx.player.Character, Color3.fromRGB(255, 60, 60), 0.2)
    DmgFB.hitParticles(ctx.player.Character, intensity)
    DmgFB.showFloatingDamage(dmg)
    DmgFB.punchHPBar()

    if st.lastExplosionPos then
        DmgFB.showDirectionalDamage(st.lastExplosionPos)
        CameraFX.knockbackTilt(st.lastExplosionPos)
    end
end)

---------- PLAYER DIED ----------
GE.PlayerDied.OnClientEvent:Connect(function(cause)
    RoundHUD.stopTimer()
    DeathSeq.show(cause, CameraFX.screenShake, Spectator.start)
end)

---------- BOMB LANDED ----------
GE.BombLanded.OnClientEvent:Connect(function(pos)
    st.lastExplosionPos = pos
    local char = ctx.player.Character; if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    local dist = (hrp.Position - pos).Magnitude
    if dist < 70 then
        local s = math.clamp((70 - dist) / 70, 0, 1)
        ctx.SFX.PlayUI("Explosion", ctx.camera, {
            Volume = s * 0.5,
            PlaybackSpeed = 0.85 + s * 0.4 + math.random() * 0.2,
        })
        if dist < 30 then CameraFX.cameraPunch(s * 1.5)
        else CameraFX.screenShake(s * 0.8, 0.12) end
    end
end)

---------- CHARACTER ADDED ----------
ctx.player.CharacterAdded:Connect(function(char)
    task.wait(0.1)
    Spectator.stop()
    ctx.camera.CameraType = Enum.CameraType.Custom
    ctx.camera.CameraSubject = char:FindFirstChild("Humanoid")
    -- Don't hide death screen while it's actively showing (death sequence or game_over recap)
    if not st._deathScreenActive and not st._gameOverRecapShown then
        ctx.deathScreen.Visible = false
    end
    if ctx.lowHPOverlay then ctx.lowHPOverlay.BackgroundTransparency = 1 end
    DmgFB.connectHPBar(char)
    DmgFB.connectMovementFeedback(char, CameraFX.screenShake)
end)
if ctx.player.Character then
    DmgFB.connectHPBar(ctx.player.Character)
    DmgFB.connectMovementFeedback(ctx.player.Character, CameraFX.screenShake)
end

---------- LOBBY RESET (shared helper) ----------
local function lobbyReset()
    DmgFB.resetCharTint(ctx.player.Character)
    MissileFX.cleanup()
    ctx.restoreLobbyLighting()
    RecapPanel.destroy()
    RoundHUD.clearMilestone()
    Spectator.stop()
    RoundHUD.stopTimer()
    ctx.TweenService:Create(ctx.camera, TweenInfo.new(0.5), {FieldOfView = 70}):Play()
    st.totalDamageTaken = 0; st.nearMissCount = 0; st.lastDeathCause = nil; st._gameOverRecapShown = false; st._deathScreenActive = false
    st._lastLavaHeavyVFX = nil
    ctx.statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    ctx.statusLabel.TextSize = 20
    ctx.countdownLabel.TextSize = 100
    if ctx.lowHPOverlay then
        ctx.lowHPOverlay.BackgroundColor3 = Color3.fromRGB(30, 0, 0)
        ctx.lowHPOverlay.BackgroundTransparency = 1
    end
    ctx.flash.BackgroundTransparency = 1
    RoundHUD.resetRoundDots()
    ctx.deathScreen.Visible = false
    ctx.countdownLabel.TextTransparency = 1
    DeathSeq.resetDeathScreen()
    ctx.hpBar.Visible = false
    ctx.fadeFrame.BackgroundTransparency = 1
end

---------- ROUND UPDATES ----------
GE.RoundUpdate.OnClientEvent:Connect(function(phase, a, b, diff, survivalTime, aliveCount, hotZoneInfo)

    if phase == "player_eliminated" then
        DmgFB.showKillFeed(a, b); return
    end

    if phase == "return_to_lobby" then
        MissileFX.cleanup()
        ctx.restoreLobbyLighting()
        RecapPanel.destroy()
        RoundHUD.clearMilestone()
        ctx.TweenService:Create(ctx.camera, TweenInfo.new(0.5), {FieldOfView = 70}):Play()
        ctx.fadeToBlack(0.6, function()
            Spectator.stop()
            ctx.camera.CameraType = Enum.CameraType.Custom
            ctx.deathScreen.Visible = false
            ctx.hpBar.Visible = false
            task.delay(0.3, function() ctx.fadeFromBlack(0.5) end)
        end)
        return
    end

    if phase == "map_modifier" then
        local modNames = {craters = "CRATERS", elevated_center = "HIGH GROUND", thin_bridges = "BRIDGES"}
        RoundHUD.showMilestone("MAP: " .. (modNames[a] or a:upper()), Color3.fromRGB(200, 200, 255))
        return
    end

    if phase == "hot_zone" then
        local zoneNames = {NW="NORTH-WEST", NE="NORTH-EAST", SW="SOUTH-WEST", SE="SOUTH-EAST", CENTER="CENTER"}
        RoundHUD.showMilestone("HOT ZONE: " .. (zoneNames[a] or a), Color3.fromRGB(255, 140, 50))
        return
    end

    if phase == "lobby_wait" then
        lobbyReset()
        setMenusVisible(true)  -- show coin total + side buttons in lobby
        st.hasPlayedFirstDrop = false; st.roundsThisSession = 0
        ctx.statusLabel.Text = a > 0 and ("NEXT GAME IN " .. a .. "s") or "WAITING..."
        if a > 0 and a <= 3 then
            ctx.SFX.PlayUI("RoundTick", ctx.camera, {Volume = 0.3 + (4 - a) * 0.1, PlaybackSpeed = 0.9 + (4 - a) * 0.1})
        end
        ctx.timerDisplay.Text = ""
        ctx.infoLabel.Text = (diff and diff > 0) and (diff .. " player" .. (diff > 1 and "s" or "") .. " in lobby") or "Waiting for players..."
        ctx.infoLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
        MissileFX.cleanup()

    elseif phase == "countdown" then
        ctx.deathScreen.Visible = false
        ctx.statusLabel.Text = "GET READY!"
        ctx.infoLabel.Text = ""
        setMenusVisible(false)  -- hide coin total + side buttons during gameplay
        RoundHUD.showCountdownNumber(a)

    elseif phase == "drop" then
        Spectator.stop()
        ctx.setInArena(true); inArena = true
        ctx.statusLabel.Text = ""; ctx.infoLabel.Text = ""
        ctx.countdownLabel.TextTransparency = 1
        ctx.fadeFrame.BackgroundTransparency = 0
        task.delay(0.6, function() ctx.fadeFromBlack(1.0) end)

    elseif phase == "countdown_go" then
        ctx.countdownLabel.Text = "GO!"
        ctx.countdownLabel.TextColor3 = Color3.fromRGB(100, 255, 120)
        ctx.countdownLabel.TextTransparency = 0; ctx.countdownLabel.TextSize = 100
        ctx.TweenService:Create(ctx.countdownLabel, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            {TextSize = 160}):Play()
        task.delay(0.6, function()
            ctx.TweenService:Create(ctx.countdownLabel, TweenInfo.new(0.4), {TextTransparency = 1}):Play()
        end)
        ctx.statusLabel.Text = "GO!"; ctx.infoLabel.Text = "Survive!"
        ctx.hpBar.Visible = true; RoundHUD.startTimer()
        RoundHUD.updateRoundDots(1)

    elseif phase == "round_start" then
        st.currentRound = a; st.roundsThisSession = a
        ctx.countdownLabel.TextTransparency = 1
        ctx.statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        ctx.statusLabel.TextSize = 20
        ctx.statusLabel.Text = "ROUND " .. a .. " / " .. ctx.MAX_ROUNDS
        ctx.infoLabel.Text = ""
        RoundHUD.updateRoundDots(a)
        RoundHUD.checkRoundMilestones(a, diff)

        -- FOV shift for late rounds
        local fovTarget = a >= 7 and 76 or a >= 6 and 74 or a >= 5 and 72 or 70
        ctx.TweenService:Create(ctx.camera, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            FieldOfView = fovTarget,
        }):Play()

        -- Inter-round countdown display
        local tickColor = b <= 1 and Color3.fromRGB(255, 100, 40)
            or b <= 2 and Color3.fromRGB(255, 150, 60)
            or Color3.fromRGB(255, 200, 100)
        ctx.countdownLabel.Text = tostring(b)
        ctx.countdownLabel.TextColor3 = tickColor
        ctx.countdownLabel.TextTransparency = 0; ctx.countdownLabel.TextSize = 40
        ctx.TweenService:Create(ctx.countdownLabel, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            {TextSize = 80}):Play()
        task.delay(0.4, function()
            ctx.TweenService:Create(ctx.countdownLabel, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                {TextTransparency = 0.8, TextSize = 60}):Play()
        end)

        local vol = ({[3] = 0.30, [2] = 0.38, [1] = 0.45})[b] or 0.3
        local pitch = ({[3] = 0.9, [2] = 1.0, [1] = 1.15})[b] or 1.0
        ctx.SFX.PlayUI("RoundTick", ctx.camera, {Volume = vol, PlaybackSpeed = pitch})

        if b == 3 then
            ctx.setArenaLighting(a)
            RoundHUD.roundTransitionPunch(a, CameraFX.cameraPunch)
            ctx.statusLabel.TextTransparency = 0.5
            ctx.TweenService:Create(ctx.statusLabel, TweenInfo.new(0.3), {TextTransparency = 0.15}):Play()
            RoundHUD.checkCountdownMilestones(a, b, diff)
        end

        -- Vignette in last 2 countdown seconds
        if b <= 2 then
            CameraFX.screenShake(0.15 + (3 - b) * 0.1, 0.2)
            if ctx.lowHPOverlay then
                ctx.lowHPOverlay.BackgroundColor3 = Color3.fromRGB(40, 20, 10)
                local vigT = (a >= 4) and (0.78 + b * 0.05) or (0.85 + b * 0.04)
                ctx.TweenService:Create(ctx.lowHPOverlay, TweenInfo.new(0.5), {BackgroundTransparency = vigT}):Play()
            end
        end

        if b == 1 then
            ctx.TweenService:Create(ctx.statusLabel, TweenInfo.new(0.3), {
                TextColor3 = Color3.fromRGB(255, 200, 80)
            }):Play()
        end

    elseif phase == "survive" then
        ctx.countdownLabel.TextTransparency = 1
        if ctx.lowHPOverlay then
            ctx.TweenService:Create(ctx.lowHPOverlay, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
        end
        ctx.statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        ctx.infoLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        ctx.statusLabel.Text = "SURVIVE!"
        ctx.statusLabel.TextColor3 = b <= 10 and Color3.fromRGB(255, 220, 80) or Color3.fromRGB(255, 255, 255)
        RoundHUD.timerUrgency(b)
        ctx.infoLabel.Text = (aliveCount and (aliveCount .. " alive | ") or "") .. b .. "s remaining"
        if aliveCount then
            ctx.infoLabel.TextColor3 = aliveCount <= 2 and Color3.fromRGB(255, 180, 80)
                or aliveCount <= 5 and Color3.fromRGB(200, 200, 200)
                or Color3.fromRGB(150, 200, 150)
        end
        if diff and diff >= 3.0 and ctx.lowHPOverlay then
            local vignetteT = math.clamp(0.85 + (4.0 - diff) * 0.05, 0.8, 0.9)
            ctx.lowHPOverlay.BackgroundColor3 = Color3.fromRGB(30, 0, 0)
            ctx.TweenService:Create(ctx.lowHPOverlay, TweenInfo.new(0.5), {BackgroundTransparency = vignetteT}):Play()
        end

    elseif phase == "round_survived" then
        if ctx.lowHPOverlay then ctx.lowHPOverlay.BackgroundColor3 = Color3.fromRGB(30, 0, 0) end
        DmgFB.resetCharTint(ctx.player.Character)
        RoundHUD.updateRoundDots(b)
        Celebrations.roundSurvived(b, a, RoundHUD.showMilestone, DmgFB.punchHPBar)

    elseif phase == "victory" then
        RoundHUD.stopTimer()
        ctx.restoreLobbyLighting()
        Celebrations.victory(a, survivalTime)

    elseif phase == "game_over" then
        RoundHUD.stopTimer()
        RoundHUD.clearMilestone()
        setMenusVisible(true)  -- show coin total during game over recap
        if a > st.bestRound then st.bestRound = a end
        ctx.statusLabel.Text = "GAME OVER!"
        ctx.infoLabel.Text = "Restarting " .. b .. "s"
        ctx.hpBar.Visible = false
        if ctx.lowHPOverlay then
            ctx.lowHPOverlay.BackgroundColor3 = Color3.fromRGB(180, 0, 0)
            ctx.TweenService:Create(ctx.lowHPOverlay, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
        end

        -- Only run recap logic on first game_over tick (highest countdown value)
        -- game_over fires multiple times (countdown 5,4,3,2,1) — ignore subsequent fires
        if not st._gameOverRecapShown then
            st._gameOverRecapShown = true
            ctx.SFX.PlayUI("GameOver", ctx.camera, {Volume = 0.4})

            local survTime = st.survivalStart and (tick() - st.survivalStart) or 0
            local recapRound, recapCause = a, st.lastDeathCause
            local recapIsBest = a >= st.bestRound and a > 0

            -- Let death screen stay visible for 2.5s so player can read cause-of-death,
            -- then fade it out and show RecapPanel. Timeline with 5s countdown:
            -- t=0: game_over fires, death screen visible
            -- t=2.5: fade out death screen
            -- t=3.0: RecapPanel slides in
            -- t=5.0: return_to_lobby destroys RecapPanel
            task.delay(2.5, function()
                if ctx.deathScreen.Visible then
                    ctx.TweenService:Create(ctx.deathScreen, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                        BackgroundTransparency = 1,
                    }):Play()
                    local dtEl = ctx.deathScreen:FindFirstChild("Text")
                    local subEl = ctx.deathScreen:FindFirstChild("Sub")
                    if dtEl then ctx.TweenService:Create(dtEl, TweenInfo.new(0.3), {TextTransparency = 1}):Play() end
                    if subEl then ctx.TweenService:Create(subEl, TweenInfo.new(0.3), {TextTransparency = 1}):Play() end
                    task.delay(0.5, function()
                        ctx.deathScreen.Visible = false
                        DeathSeq.resetDeathScreen()
                    end)
                end

                -- Show RecapPanel after death screen fades
                task.delay(0.5, function()
                    RecapPanel.create(recapRound, survTime, recapCause, recapIsBest)
                end)
            end)
        end
    end
end)

---------- INITIAL STATE ----------
ctx.hpBar.Visible = false
ctx.timerDisplay.Text = "0:00"
ctx.infoLabel.Text = "Lobby"
ctx.countdownLabel.TextTransparency = 1

print("[HUDController v24] UI revamp loaded — 12 modules + IconAssets")
