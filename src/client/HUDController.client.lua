[OUTPUT] -- HUDController v22: Timer hero, death polish, smooth animations
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

-- Arena-only lighting (darken as rounds progress)
local originalAmbient = Lighting.Ambient
local originalBrightness = Lighting.Brightness
local originalOutdoorAmbient = Lighting.OutdoorAmbient
local inArena = false

local function setArenaLighting(roundNum)
    if not inArena then return end
    -- A2: Progressive darkness with dramatic round 7 drop
    local progress = math.clamp((roundNum - 1) / 6, 0, 1) -- 0 at round 1, ~1 at round 7
    -- Exponential curve: gentle darkening early, dramatic late
    local darkCurve = progress * progress * progress  -- cubic: 0, 0.005, 0.037, 0.125, 0.296, 0.579, 1.0
    local ambientR = math.floor(128 - darkCurve * 100)  -- 128 -> 28 (darker R7)
    local ambientG = math.floor(128 - darkCurve * 105)  -- 128 -> 23
    local ambientB = math.floor(128 - darkCurve * 110) -- 128 -> 18 (slight warm tint)
    local brightness = 2 - darkCurve * 1.5              -- 2.0 -> 0.5 (dimmer R7)
    local outdoorR = math.floor(128 - darkCurve * 90)
    local outdoorG = math.floor(128 - darkCurve * 80)
    local outdoorB = math.floor(128 - darkCurve * 95)
    
    TweenService:Create(Lighting, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Ambient = Color3.fromRGB(ambientR, ambientG, ambientB),
        Brightness = brightness,
        OutdoorAmbient = Color3.fromRGB(outdoorR, outdoorG, outdoorB),
    }):Play()
end

local function restoreLobbyLighting()
    inArena = false
    TweenService:Create(Lighting, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Ambient = originalAmbient,
        Brightness = originalBrightness,
        OutdoorAmbient = originalOutdoorAmbient,
    }):Play()
end

local ok, SFX = pcall(require, RS:WaitForChild("SoundManager"))
if not ok then warn("[HUD] SoundManager failed"); return end

local GameEvents = RS:WaitForChild("GameEvents")
local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui"):WaitForChild("GameHUD")
local camera = workspace.CurrentCamera

-- Cache of each body part's TRUE original color (captured before any damage tinting).
-- Keyed by part instance so we always revert to the real pre-damage color even
-- after multiple consecutive hits have stacked red on top of red.
local charOrigColors = {}

local function captureOrigColors(char)
    if not char then return end
    charOrigColors = {}
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            charOrigColors[part] = part.Color
        end
    end
end

-- Capture on every spawn so the cache is always fresh
player.CharacterAdded:Connect(function(char)
    -- Defer one frame to let the character finish loading its appearance
    task.defer(function() captureOrigColors(char) end)
end)
if player.Character then
    task.defer(function() captureOrigColors(player.Character) end)
end

-- GUI refs (updated for v14 layout)
local topBar = gui:WaitForChild("TopBar")
local statusLabel = topBar:WaitForChild("Status")
local timerDisplay = topBar:WaitForChild("TimerDisplay")
local infoLabel = topBar:WaitForChild("Info")
local flash = gui:WaitForChild("Flash")
local deathScreen = gui:WaitForChild("Death")

-- Spectate indicator (bottom of screen)
local spectateLabel = Instance.new("TextLabel")
spectateLabel.Name = "SpectateIndicator"
spectateLabel.Size = UDim2.new(0, 300, 0, 30)
spectateLabel.Position = UDim2.new(0.5, -150, 1, -50)
spectateLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
spectateLabel.BackgroundTransparency = 0.5
spectateLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
spectateLabel.TextSize = 16
spectateLabel.Font = Enum.Font.GothamBold
spectateLabel.Text = ""
spectateLabel.Visible = false
spectateLabel.ZIndex = 15
spectateLabel.Parent = gui
local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 8); corner.Parent = spectateLabel
-- Round progression dots
local MAX_ROUNDS = 7
local roundDotsFrame = topBar:FindFirstChild("RoundDots")
local function updateRoundDots(completedRound)
    if not roundDotsFrame then return end
    for i = 1, MAX_ROUNDS do
        local dot = roundDotsFrame:FindFirstChild("Dot" .. i)
        if dot then
            if i < completedRound then
                -- Completed: bright green
                dot.BackgroundColor3 = Color3.fromRGB(80, 255, 120)
                dot.BackgroundTransparency = 0.1
            elseif i == completedRound then
                -- Current: bright white/yellow, pulse
                dot.BackgroundColor3 = Color3.fromRGB(255, 240, 100)
                dot.BackgroundTransparency = 0
                TweenService:Create(dot, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                    Size = UDim2.new(0, 18, 0, 8)
                }):Play()
                task.delay(0.4, function()
                    TweenService:Create(dot, TweenInfo.new(0.3), {Size = UDim2.new(0, 14, 0, 6)}):Play()
                end)
            else
                -- Future: dim grey
                dot.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
                dot.BackgroundTransparency = 0.4
                dot.Size = UDim2.new(0, 14, 0, 6)
            end
        end
    end
end

local function resetRoundDots()
    if not roundDotsFrame then return end
    for i = 1, MAX_ROUNDS do
        local dot = roundDotsFrame:FindFirstChild("Dot" .. i)
        if dot then
            dot.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
            dot.BackgroundTransparency = 0.4
            dot.Size = UDim2.new(0, 14, 0, 6)
        end
    end
end

local milestoneLabel = gui:WaitForChild("Milestone")
local countdownLabel = gui:WaitForChild("CountdownLabel")
local leaderboard = gui:WaitForChild("Leaderboard")
local lbEntries = leaderboard:WaitForChild("Entries")
local hpBar = gui:WaitForChild("HPBar")
local hpFill = hpBar:WaitForChild("Fill")
local hpText = hpBar:WaitForChild("HPText")
local lowHPOverlay = gui:WaitForChild("LowHPOverlay")
local nearMissLabel = gui:WaitForChild("NearMiss")



-- Fade transition frame (black overlay for teleport transitions)
local fadeFrame = Instance.new("Frame")
fadeFrame.Name = "FadeFrame"
fadeFrame.Size = UDim2.new(1, 0, 1, 0)
fadeFrame.Position = UDim2.new(0, 0, 0, 0)
fadeFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
fadeFrame.BackgroundTransparency = 1
fadeFrame.BorderSizePixel = 0
fadeFrame.ZIndex = 20
fadeFrame.Parent = gui

local activeFadeTween = nil
local fadeGuard = false

local function fadeToBlack(duration, callback)
    if fadeGuard then return end
    fadeGuard = true
    if activeFadeTween then activeFadeTween:Cancel() end
    fadeFrame.BackgroundTransparency = 1
    local tw = TweenService:Create(fadeFrame, TweenInfo.new(duration or 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        {BackgroundTransparency = 0})
    activeFadeTween = tw
    tw:Play()
    tw.Completed:Connect(function()
        fadeGuard = false
        if callback then callback() end
    end)
end

local function fadeFromBlack(duration)
    fadeGuard = false
    if activeFadeTween then activeFadeTween:Cancel() end
    fadeFrame.BackgroundTransparency = 0
    local tw = TweenService:Create(fadeFrame, TweenInfo.new(duration or 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {BackgroundTransparency = 1})
    activeFadeTween = tw
    tw:Play()
    tw.Completed:Connect(function() activeFadeTween = nil end)
end

-- State
local hpConn = nil
local moveConns = {}
local velConn = nil
local currentRound = 0
local hasPlayedFirstDrop = false

        fadeFrame.BackgroundTransparency = 1 -- prevent black screen softlocklocal survivalStart = nil
local bestTime = 0
local bestRound = 0 -- Personal best round this session
local isAlive = false
local roundsThisSession = 0
local lastServerLB = 0
local lastDeathCause = nil
local totalDamageTaken = 0
local nearMissCount = 0
local killFeedLabels = {}

---------- COIN HUD ----------
-- Positioned left of HP bar (bottom-center) where players naturally look
-- Leaderstats (top-right) handles social display; this is the gameplay-feel counter
local coinDisplay = Instance.new("TextLabel")
coinDisplay.Name = "CoinDisplay"
coinDisplay.Size = UDim2.new(0, 110, 0, 26)
coinDisplay.Position = UDim2.new(0.5, -195, 1, -18)
coinDisplay.AnchorPoint = Vector2.new(1, 0.5)
coinDisplay.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
coinDisplay.BackgroundTransparency = 0.5
coinDisplay.BorderSizePixel = 0
coinDisplay.Font = Enum.Font.GothamBold
coinDisplay.TextSize = 16
coinDisplay.TextColor3 = Color3.fromRGB(255, 220, 50)
coinDisplay.TextStrokeTransparency = 0.5
coinDisplay.TextStrokeColor3 = Color3.fromRGB(80, 60, 0)
coinDisplay.Text = "0"
coinDisplay.TextXAlignment = Enum.TextXAlignment.Right
coinDisplay.ZIndex = 5
coinDisplay.Parent = gui
local coinCorner = Instance.new("UICorner")
coinCorner.CornerRadius = UDim.new(0, 6)
coinCorner.Parent = coinDisplay
local coinPadding = Instance.new("UIPadding")
coinPadding.PaddingRight = UDim.new(0, 8)
coinPadding.PaddingLeft = UDim.new(0, 24)
coinPadding.Parent = coinDisplay
-- "$" icon on left side
local coinIcon = Instance.new("TextLabel")
coinIcon.Size = UDim2.new(0, 22, 1, 0)
coinIcon.Position = UDim2.new(0, 0, 0, 0)
coinIcon.BackgroundTransparency = 1
coinIcon.Font = Enum.Font.GothamBold
coinIcon.TextSize = 16
coinIcon.TextColor3 = Color3.fromRGB(255, 200, 50)
coinIcon.Text = "$"
coinIcon.ZIndex = 6
coinIcon.Parent = coinDisplay

-- Initialize from leaderstats
task.spawn(function()
    local ls = player:WaitForChild("leaderstats", 10)
    if ls then
        local coinsVal = ls:WaitForChild("Coins", 5)
        if coinsVal then
            coinDisplay.Text = tostring(coinsVal.Value)
            coinsVal.Changed:Connect(function(newVal)
                coinDisplay.Text = tostring(newVal)
            end)
        end
    end
end)

-- Coin earn animation: flash + floating popup
GameEvents:WaitForChild("CoinUpdate").OnClientEvent:Connect(function(amount, total, reason)
    coinDisplay.Text = tostring(total)
    -- Flash gold
    TweenService:Create(coinDisplay, TweenInfo.new(0.15), {
        TextColor3 = Color3.fromRGB(255, 255, 150),
        BackgroundTransparency = 0.15,
    }):Play()
    task.delay(0.3, function()
        TweenService:Create(coinDisplay, TweenInfo.new(0.4), {
            TextColor3 = Color3.fromRGB(255, 220, 50),
            BackgroundTransparency = 0.5,
        }):Play()
    end)
    -- Floating "+X" popup rises from coin display
    local popup = Instance.new("TextLabel")
    popup.Size = UDim2.new(0, 140, 0, 22)
    popup.Position = UDim2.new(0.5, -195, 1, -40)
    popup.AnchorPoint = Vector2.new(1, 0.5)
    popup.BackgroundTransparency = 1
    popup.Font = Enum.Font.GothamBold
    popup.TextSize = 15
    popup.TextColor3 = Color3.fromRGB(255, 220, 80)
    popup.TextStrokeTransparency = 0.4
    popup.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    popup.Text = "+" .. amount
    popup.TextXAlignment = Enum.TextXAlignment.Right
    popup.ZIndex = 6
    popup.Parent = gui
    TweenService:Create(popup, TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, -195, 1, -65),
        TextTransparency = 1,
        TextStrokeTransparency = 1,
    }):Play()
    game:GetService("Debris"):AddItem(popup, 1.2)
end)

---------- RECAP PANEL ----------
local recapPanel = nil

local function destroyRecapPanel()
    if recapPanel then recapPanel:Destroy(); recapPanel = nil end
end

local function createRecapPanel(roundsSurvived, survivalTime, deathCause, isNewBest)
    destroyRecapPanel()
    
    local panel = Instance.new("Frame")
    panel.Name = "RecapPanel"
    panel.Size = UDim2.new(0, 320, 0, 260)
    panel.Position = UDim2.new(0.5, -160, 0.5, -130)
    panel.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    panel.BackgroundTransparency = 0.15
    panel.BorderSizePixel = 0
    panel.Parent = gui
    local panelCorner = Instance.new("UICorner")
    panelCorner.CornerRadius = UDim.new(0, 12)
    panelCorner.Parent = panel
    local panelStroke = Instance.new("UIStroke")
    panelStroke.Color = Color3.fromRGB(255, 80, 40)
    panelStroke.Thickness = 2
    panelStroke.Parent = panel
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 36)
    title.Position = UDim2.new(0, 0, 0, 8)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 22
    title.TextColor3 = isNewBest and Color3.fromRGB(255, 220, 50) or Color3.fromRGB(255, 100, 60)
    title.Text = isNewBest and "NEW BEST!" or "GAME OVER"
    title.TextStrokeTransparency = 0.5
    title.Parent = panel
    
    -- Stats container
    local yPos = 50
    local function addStat(label, value, color)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -32, 0, 28)
        row.Position = UDim2.new(0, 16, 0, yPos)
        row.BackgroundTransparency = 1
        row.Parent = panel
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.6, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 16
        lbl.TextColor3 = Color3.fromRGB(180, 180, 200)
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Text = label
        lbl.Parent = row
        local val = Instance.new("TextLabel")
        val.Size = UDim2.new(0.4, 0, 1, 0)
        val.Position = UDim2.new(0.6, 0, 0, 0)
        val.BackgroundTransparency = 1
        val.Font = Enum.Font.GothamBold
        val.TextSize = 18
        val.TextColor3 = color or Color3.fromRGB(255, 255, 255)
        val.TextXAlignment = Enum.TextXAlignment.Right
        val.Text = value
        val.Parent = row
        yPos = yPos + 32
    end
    
    addStat("Rounds Survived", tostring(roundsSurvived) .. " / 7", roundsSurvived >= 5 and Color3.fromRGB(80, 255, 120) or Color3.fromRGB(255, 255, 255))
    addStat("Survival Time", formatTime(survivalTime or 0))
    addStat("Damage Taken", tostring(math.floor(totalDamageTaken)), totalDamageTaken > 60 and Color3.fromRGB(255, 100, 100) or Color3.fromRGB(255, 255, 255))
    addStat("Near Misses", tostring(nearMissCount), nearMissCount >= 5 and Color3.fromRGB(255, 220, 80) or Color3.fromRGB(255, 255, 255))
    addStat("Best Round", "R" .. bestRound, Color3.fromRGB(255, 200, 50))
    if deathCause then
        addStat("Killed By", tostring(deathCause), Color3.fromRGB(255, 80, 60))
    end
    
    -- Slide-in animation
    panel.Position = UDim2.new(0.5, -160, 0.5, 40)
    panel.BackgroundTransparency = 1
    TweenService:Create(panel, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, -160, 0.5, -130),
        BackgroundTransparency = 0.15,
    }):Play()
    for _, child in ipairs(panel:GetDescendants()) do
        if child:IsA("TextLabel") then
            local targetColor = child.TextColor3
            child.TextTransparency = 1
            TweenService:Create(child, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                TextTransparency = 0,
            }):Play()
        end
    end
    
    recapPanel = panel
end

---------- UTILITIES ----------
local function formatTime(s)
    return string.format("%d:%02d", math.floor(s / 60), math.floor(s % 60))
end

local DEATH_CAUSES = {
    standard = "Caught by a bomb!",
    bouncing = "Hit by a bouncing bomb!",
    timed = "Blown up by a timed bomb!",
    cluster = "Shredded by cluster bomb!",
    fall = "Fell off the map!",
    lava = "Melted in lava!",
    reset = "Reset during round",
    missile = "Locked on by a guided missile!",
}

---------- SMOOTH UI HELPERS ----------
local function fadeIn(obj, duration, props)
    duration = duration or 0.3
    props = props or {}
    if obj:IsA("TextLabel") or obj:IsA("TextButton") then
        props.TextTransparency = props.TextTransparency or 0
    end
    TweenService:Create(obj, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

local function scalePopIn(obj, duration)
    duration = duration or 0.3
    -- Uses TextSize scaling for text elements
    if obj:IsA("TextLabel") then
        local targetSize = obj.TextSize
        obj.TextSize = targetSize * 0.7
        TweenService:Create(obj, TweenInfo.new(duration, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            {TextSize = targetSize}):Play()
    end
end

---------- SURVIVAL TIMER ----------
local timerConn
local function startTimer()
    survivalStart = tick(); isAlive = true
    if timerConn then timerConn:Disconnect() end
    timerConn = RunService.Heartbeat:Connect(function()
        if survivalStart and isAlive then
            local elapsed = tick() - survivalStart
            timerDisplay.Text = formatTime(elapsed)
            -- Pulse timer color when time is running low in round (> 25s)
            if elapsed > 25 then
                local pulse = math.abs(math.sin(tick() * 3))
                timerDisplay.TextColor3 = Color3.fromRGB(255, 200 + pulse * 55, 200 + pulse * 55):Lerp(
                    Color3.fromRGB(255, 180, 80), pulse * 0.5)
            else
                timerDisplay.TextColor3 = Color3.fromRGB(255, 255, 255)
            end
        end
    end)
end
local function stopTimer()
    isAlive = false
    if timerConn then timerConn:Disconnect(); timerConn = nil end
    timerDisplay.TextColor3 = Color3.fromRGB(255, 255, 255)
end

---------- MILESTONES ----------
local milestones = {
    {round = 3, text = "WARMING UP!", color = Color3.fromRGB(130, 230, 255)},
    {round = 4, text = "HALFWAY!", color = Color3.fromRGB(100, 255, 100)},
    {round = 6, text = "ALMOST THERE!", color = Color3.fromRGB(255, 200, 50)},
}

local _milestoneVersion = 0
local function showMilestone(text, color)
    _milestoneVersion = _milestoneVersion + 1
    local thisVersion = _milestoneVersion
    milestoneLabel.Text = text; milestoneLabel.TextColor3 = color
    milestoneLabel.TextTransparency = 1
    milestoneLabel.Position = UDim2.new(0.5, 0, 0.28, 0)
    TweenService:Create(milestoneLabel, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {TextTransparency = 0, Position = UDim2.new(0.5, 0, 0.25, 0)}):Play()
    task.delay(1.8, function()
        if _milestoneVersion ~= thisVersion then return end -- stale, skip fade-out
        TweenService:Create(milestoneLabel, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {TextTransparency = 1, Position = UDim2.new(0.5, 0, 0.22, 0)}):Play()
    end)
end

local function clearMilestone()
    _milestoneVersion = _milestoneVersion + 1
    milestoneLabel.TextTransparency = 1
end

---------- COUNTDOWN ANIMATION ----------
local function showCountdownNumber(num)
    local color = num == 3 and Color3.fromRGB(255, 100, 100)
        or num == 2 and Color3.fromRGB(255, 200, 80)
        or Color3.fromRGB(100, 255, 100)
    countdownLabel.Text = tostring(num); countdownLabel.TextColor3 = color
    countdownLabel.TextTransparency = 0; countdownLabel.TextSize = 60
    TweenService:Create(countdownLabel, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {TextSize = 140}):Play()
    task.delay(0.5, function()
        TweenService:Create(countdownLabel, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {TextTransparency = 1, TextSize = 80}):Play()
    end)
    SFX.PlayUI("Countdown", camera, {Volume = 0.12, PlaybackSpeed = 1.05 + (4 - num) * 0.05})
end

---------- LEADERBOARD ----------
local function updateLeaderboard(data)
    for _, c in ipairs(lbEntries:GetChildren()) do
        if c:IsA("TextLabel") then c:Destroy() end
    end
    table.sort(data, function(a, b)
        if a.alive ~= b.alive then return a.alive end
        if a.rounds ~= b.rounds then return a.rounds > b.rounds end
        return a.time > b.time
    end)
    for i, entry in ipairs(data) do
        if i > 8 then break end
        local label = Instance.new("TextLabel")
        label.Name = "E" .. i; label.Size = UDim2.new(1, 0, 0, 24)
        label.BackgroundColor3 = entry.alive and Color3.fromRGB(40, 60, 40) or Color3.fromRGB(50, 35, 35)
        label.BackgroundTransparency = 0.5; label.LayoutOrder = i
        label.Font = Enum.Font.GothamBold; label.TextSize = 12
        label.TextXAlignment = Enum.TextXAlignment.Left
        local roundText = entry.rounds > 0 and ("  R" .. entry.rounds) or ""
        local timeText = entry.time > 0 and (" " .. formatTime(entry.time)) or ""
        label.Text = "  " .. i .. ". " .. entry.name .. roundText .. timeText
        label.TextColor3 = entry.alive and Color3.fromRGB(100, 255, 120) or Color3.fromRGB(150, 80, 80)
        label.Parent = lbEntries
    end
end

GameEvents.LeaderboardUpdate.OnClientEvent:Connect(function(data)
    lastServerLB = tick(); updateLeaderboard(data)
end)

task.spawn(function()
    while true do
        task.wait(3)
        if tick() - lastServerLB > 5 then
            local data = {}
            for _, p in ipairs(Players:GetPlayers()) do
                local char = p.Character; local hum = char and char:FindFirstChild("Humanoid")
                table.insert(data, {name = p.DisplayName, alive = hum and hum.Health > 0 or false, rounds = 0, time = 0})
            end
            updateLeaderboard(data)
        end
    end
end)

---------- KILL FEED ----------
local function showKillFeed(playerName, cause)
    local causeText = DEATH_CAUSES[cause] or "was eliminated"
    -- F5: Color-code kill feed by bomb type for visual language reinforcement
    local killColors = {
        standard = Color3.fromRGB(255, 170, 80),
        bouncing = Color3.fromRGB(100, 230, 120),
        timed = Color3.fromRGB(255, 90, 70),
        cluster = Color3.fromRGB(200, 140, 255),
        missile = Color3.fromRGB(255, 130, 50),
        lava = Color3.fromRGB(255, 100, 30),
        fall = Color3.fromRGB(180, 180, 200),
    }
    local killColor = killColors[cause] or Color3.fromRGB(255, 120, 120)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0, 260, 0, 22)
    label.Position = UDim2.new(0, 14, 0.65, #killFeedLabels * 26)
    label.BackgroundTransparency = 0.7; label.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    label.Font = Enum.Font.GothamBold; label.TextSize = 11
    label.TextColor3 = killColor
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextStrokeTransparency = 0.6
    label.Text = "  " .. playerName .. " " .. causeText:lower()
    label.TextTransparency = 1; label.ZIndex = 7; label.Parent = gui
    -- Fade in
    TweenService:Create(label, TweenInfo.new(0.25), {TextTransparency = 0}):Play()
    table.insert(killFeedLabels, label)
    -- Round corner
    local kfCorner = Instance.new("UICorner")
    kfCorner.CornerRadius = UDim.new(0, 3)
    kfCorner.Parent = label
    -- Fade out after 6s
    task.delay(6, function()
        TweenService:Create(label, TweenInfo.new(0.5), {TextTransparency = 1, BackgroundTransparency = 1}):Play()
        task.delay(0.6, function()
            if label and label.Parent then label:Destroy() end
            local idx = table.find(killFeedLabels, label)
            if idx then table.remove(killFeedLabels, idx) end
        end)
    end)
    while #killFeedLabels > 5 do
        local old = table.remove(killFeedLabels, 1)
        if old and old.Parent then old:Destroy() end
    end
end

---------- SPECTATOR CAMERA ----------
local spectating = false; local specTarget = nil; local specConn = nil; local stopSpectating
local _spectatingCompact = false
local _specLerpTarget = nil
local function findAlivePlayer()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player then
            local char = p.Character
            if char then local hum = char:FindFirstChild("Humanoid")
                if hum and hum.Health > 0 then return p end
            end
        end
    end
    return nil
end
local function startSpectating()
    local target = findAlivePlayer()
    if not target or not target.Character then return end
    spectating = true; specTarget = target
    local sub = deathScreen:FindFirstChild("Sub")
    if sub then sub.Text = "Spectating " .. target.DisplayName .. " | Click to switch" end
    if specConn then specConn:Disconnect() end
    specConn = RunService.RenderStepped:Connect(function(dt)
        if not spectating then return end
        if not specTarget or not specTarget.Character then
            local newTarget = findAlivePlayer()
            if newTarget and newTarget.Character then
                specTarget = newTarget
                _specLerpTarget = nil
                local sub = deathScreen:FindFirstChild("Sub")
                if sub then sub.Text = "Spectating " .. newTarget.DisplayName .. " | Click to switch" end
            else stopSpectating(); return end
        end
        local hrp = specTarget.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            -- S3: Smooth camera lerp instead of instant snap
            if _specLerpTarget and _specLerpTarget ~= specTarget then
                -- Target changed: lerp camera to new position
                _specLerpTarget = specTarget
                camera.CameraType = Enum.CameraType.Scriptable
                local startCF = camera.CFrame
                task.spawn(function()
                    local elapsed = 0
                    local lerpTime = 0.35
                    while elapsed < lerpTime and spectating and specTarget == _specLerpTarget do
                        local d = RunService.RenderStepped:Wait()
                        elapsed = elapsed + d
                        local alpha = math.min(elapsed / lerpTime, 1)
                        alpha = 1 - (1 - alpha)^3
                        local targetHRP = specTarget.Character and specTarget.Character:FindFirstChild("HumanoidRootPart")
                        if targetHRP then
                            local goalCF = CFrame.new(targetHRP.Position + Vector3.new(0, 8, 12), targetHRP.Position)
                            camera.CFrame = startCF:Lerp(goalCF, alpha)
                        end
                    end
                    if spectating then
                        camera.CameraType = Enum.CameraType.Custom
                        camera.CameraSubject = specTarget.Character:FindFirstChild("Humanoid")
                    end
                end)
            elseif not _specLerpTarget then
                _specLerpTarget = specTarget
                camera.CameraSubject = specTarget.Character:FindFirstChild("Humanoid")
            end
            
            -- S3: Update spectate info with live round data
            if _spectatingCompact then
                local sub = deathScreen:FindFirstChild("Sub")
                if sub then
                    local roundInfo = "Round " .. currentRound .. " / " .. MAX_ROUNDS
                    sub.Text = "Spectating " .. specTarget.DisplayName .. " | " .. roundInfo .. " | Click to switch"
                end
            end
        end
    end)
end
stopSpectating = function()

    _spectatingCompact = false; _specLerpTarget = nil    spectating = false; specTarget = nil
    spectateLabel.Visible = false
    if specConn then specConn:Disconnect(); specConn = nil end
    local char = player.Character
    if char then local hum = char:FindFirstChild("Humanoid")
        if hum then camera.CameraSubject = hum end
    end
end
UIS.InputBegan:Connect(function(input, processed)
    if processed then return end
    if spectating and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
        local candidates = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player and p ~= specTarget then
                local char = p.Character
                if char and char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0 then
                    table.insert(candidates, p)
                end
            end
        end
        if #candidates > 0 then
            specTarget = candidates[math.random(#candidates)]
            _specLerpTarget = nil -- trigger smooth lerp to new target
            local sub = deathScreen:FindFirstChild("Sub")
            if sub then sub.Text = "Spectating " .. specTarget.DisplayName .. " | Click to switch" end
        end
    end
end)

---------- SCREEN SHAKE ----------
local function screenShake(intensity, duration)
    task.spawn(function()
        local elapsed = 0
        while elapsed < duration do
            local decay = 1 - (elapsed / duration)
            local dt = RunService.RenderStepped:Wait()
            camera.CFrame = camera.CFrame * CFrame.new(
                (math.random()-0.5)*intensity*decay,
                (math.random()-0.5)*intensity*decay, 0
            ) * CFrame.Angles(
                math.rad((math.random()-0.5)*intensity*decay*2),
                math.rad((math.random()-0.5)*intensity*decay*2), 0
            )
            elapsed = elapsed + dt
        end
    end)
end

-- Camera punch: sharp downward hit then spring back (feels like impact)
local function cameraPunch(intensity)
    task.spawn(function()
        local orig = camera.CFrame
        -- Sharp down punch
        camera.CFrame = orig * CFrame.new(0, -intensity * 0.8, 0)
        RunService.RenderStepped:Wait()
        RunService.RenderStepped:Wait()
        -- Spring back with overshoot
        camera.CFrame = orig * CFrame.new(0, intensity * 0.2, 0)
        RunService.RenderStepped:Wait()
        camera.CFrame = orig * CFrame.new(0, -intensity * 0.1, 0)
        RunService.RenderStepped:Wait()
        -- Settle
        camera.CFrame = orig
    end)
end

---------- KNOCKBACK CAMERA TILT ----------
local function knockbackTilt(explosionPos)
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local dir = (hrp.Position - explosionPos).Unit
    local camCF = camera.CFrame
    local localDir = camCF:VectorToObjectSpace(dir)
    local tiltX = localDir.Z * 3
    local tiltZ = -localDir.X * 3
    task.spawn(function()
        camera.CFrame = camera.CFrame * CFrame.Angles(math.rad(tiltX), 0, math.rad(tiltZ))
        task.wait(0.1)
    end)
end

---------- HIT VFX ----------

-- Smoothly fade all character parts back to their pre-damage original colors.
local function resetCharTint(char, tweenTime)
    if not char then return end
    tweenTime = tweenTime or 0.5
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            local origColor = charOrigColors[part]
            if origColor and part.Parent then
                TweenService:Create(part,
                    TweenInfo.new(tweenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    {Color = origColor}):Play()
            end
        end
    end
end

-- Tint character and revert to TRUE original colors after duration.
-- Using the charOrigColors cache prevents stacked hits from locking the
-- character red permanently (the old bug: orig was already red on 2nd hit).
local function tintCharacter(char, color, duration)
    if not char then return end
    -- Lazily capture original colors in case CharacterAdded fired before the cache was ready
    if not next(charOrigColors) then captureOrigColors(char) end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            part.Color = color
            local origColor = charOrigColors[part] or color
            task.delay(duration, function()
                if part and part.Parent then
                    TweenService:Create(part, TweenInfo.new(0.4), {Color = origColor}):Play()
                end
            end)
        end
    end
end

local function hitParticles(char, intensity)
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local att = Instance.new("Attachment"); att.Parent = hrp
    local sparks = Instance.new("ParticleEmitter")
    sparks.Color = ColorSequence.new(Color3.fromRGB(255, 120, 40), Color3.fromRGB(255, 220, 80))
    sparks.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1.5*intensity), NumberSequenceKeypoint.new(1, 0)})
    sparks.Transparency = NumberSequence.new(0, 1)
    sparks.Lifetime = NumberRange.new(0.2, 0.5)
    sparks.Speed = NumberRange.new(10*intensity, 22*intensity)
    sparks.SpreadAngle = Vector2.new(180, 180)
    sparks.LightEmission = 0.7; sparks.Rate = 0; sparks.Parent = att
    sparks:Emit(math.floor(12*intensity)); Debris:AddItem(att, 1)
end

---------- DIRECTIONAL DAMAGE ----------
local function showDirectionalDamage(explosionPos)
    local char = player.Character; if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    local dir = (explosionPos - hrp.Position)
    local camCF = camera.CFrame
    local localDir = camCF:VectorToObjectSpace(dir)
    local absX, absZ = math.abs(localDir.X), math.abs(localDir.Z)
    local side = absX > absZ and (localDir.X > 0 and "Right" or "Left") or (localDir.Z < 0 and "Top" or "Bottom")
    local ind = gui:FindFirstChild("DmgInd_" .. side)
    if ind then
        ind.BackgroundTransparency = 0.3
        TweenService:Create(ind, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {BackgroundTransparency = 1}):Play()
    end
end
local function showDirectionalNearMiss(explosionPos)
    local char = player.Character; if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    local dir = (explosionPos - hrp.Position)
    local camCF = camera.CFrame
    local localDir = camCF:VectorToObjectSpace(dir)
    local absX, absZ = math.abs(localDir.X), math.abs(localDir.Z)
    local side = absX > absZ and (localDir.X > 0 and "Right" or "Left") or (localDir.Z < 0 and "Top" or "Bottom")
    local ind = gui:FindFirstChild("DmgInd_" .. side)
    if ind then
        -- Yellow flash instead of red (near-miss feel)
        local origColor = ind.BackgroundColor3
        ind.BackgroundColor3 = Color3.fromRGB(255, 230, 50)
        ind.BackgroundTransparency = 0.4
        TweenService:Create(ind, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {BackgroundTransparency = 1}):Play()
        task.delay(0.5, function()
            ind.BackgroundColor3 = origColor
        end)
    end
end


---------- NEAR MISS ----------
local nearMissTexts = {"CLOSE CALL!", "TOO CLOSE!", "WHEW!", "BARELY!"}
local function showNearMiss()
    nearMissLabel.Text = nearMissTexts[math.random(#nearMissTexts)]
    nearMissLabel.TextTransparency = 0; nearMissLabel.TextSize = 20
    nearMissLabel.Position = UDim2.new(0.5, 0, 0.45, 0)
    TweenService:Create(nearMissLabel, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {TextSize = 36}):Play()
    flash.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    flash.BackgroundTransparency = 0.92
    TweenService:Create(flash, TweenInfo.new(0.15), {BackgroundTransparency = 1}):Play()
    task.delay(0.8, function()
        TweenService:Create(nearMissLabel, TweenInfo.new(0.4), {TextTransparency = 1}):Play()
    end)
end

---------- HEAL FEEDBACK ----------
local function showHealFeedback(healAmt)
    -- Screen flash (green)
    flash.BackgroundColor3 = Color3.fromRGB(80, 255, 80)
    flash.BackgroundTransparency = 0.85
    TweenService:Create(flash, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {BackgroundTransparency = 1}):Play()

    -- Character heal glow: brief green flash then fade back to true original colors.
    -- This also clears any lingering red tint from damage (fixes the visual UX bug).
    local char = player.Character
    if char then
        -- Ensure original colors are captured (safety net)
        if not next(charOrigColors) then captureOrigColors(char) end
        -- Flash green for one frame to signal healing
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                part.Color = Color3.fromRGB(100, 255, 130)
            end
        end
        -- Smoothly fade back to original — 0.7 s gives a satisfying "recovery" feel
        task.delay(0.08, function()
            resetCharTint(char, 0.7)
        end)
    end

    -- Floating "+HP" label
    local healLabel = Instance.new("TextLabel")
    healLabel.Size = UDim2.new(0, 100, 0, 30)
    healLabel.Position = UDim2.new(0.5, 0, 1, -50)
    healLabel.AnchorPoint = Vector2.new(0.5, 1)
    healLabel.BackgroundTransparency = 1
    healLabel.Font = Enum.Font.GothamBold; healLabel.TextSize = 20
    healLabel.TextColor3 = Color3.fromRGB(80, 255, 80)
    healLabel.TextStrokeTransparency = 0.3
    healLabel.Text = "+" .. healAmt .. " HP"
    healLabel.ZIndex = 6; healLabel.Parent = gui
    TweenService:Create(healLabel, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Position = UDim2.new(0.5, 0, 1, -110), TextTransparency = 1, TextStrokeTransparency = 1}):Play()
    Debris:AddItem(healLabel, 1.2)
end

---------- LAST SURVIVOR ----------
local function showLastSurvivor()
    showMilestone("LAST ONE STANDING!", Color3.fromRGB(255, 220, 50))
    flash.BackgroundColor3 = Color3.fromRGB(255, 220, 50)
    flash.BackgroundTransparency = 0.8
    TweenService:Create(flash, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
end

---------- HP BAR ----------
local function updateHPBar()
    local char = player.Character; if not char then return end
    local hum = char:FindFirstChild("Humanoid"); if not hum then return end
    local hp = math.max(0, hum.Health); local maxHP = hum.MaxHealth; local pct = hp / maxHP
    TweenService:Create(hpFill, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.new(math.max(0.001, pct) * (1 - 6/320), 0, 1, -4),
        BackgroundColor3 = pct > 0.5 and Color3.fromRGB(80, 220, 80)
            or pct > 0.25 and Color3.fromRGB(255, 180, 40)
            or Color3.fromRGB(255, 50, 30)
    }):Play()
    hpText.Text = math.floor(hp) .. " / " .. math.floor(maxHP)
    hpBar.Visible = (hp > 0)
    if pct <= 0.25 and pct > 0 then
        TweenService:Create(hpFill, TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 2, true),
            {BackgroundColor3 = Color3.fromRGB(255, 0, 0)}):Play()
    end
    if lowHPOverlay then
        local t = pct <= 0.3 and math.clamp(0.7 + pct, 0.7, 0.92) or 1
        TweenService:Create(lowHPOverlay, TweenInfo.new(0.4), {BackgroundTransparency = t}):Play()
    end
end

local function connectHPBar(char)
    if not char then return end
    if hpConn then hpConn:Disconnect(); hpConn = nil end
    local hum = char:WaitForChild("Humanoid", 5)
    if hum then hpConn = hum:GetPropertyChangedSignal("Health"):Connect(updateHPBar); updateHPBar() end
end


---------- LANDING IMPACT (v15: scaled dust, lower threshold, takeoff puff) ----------


----------
local lastYVel = 0
local function connectMovementFeedback(char)

    -- Disconnect previous movement connections
    for _, c in ipairs(moveConns) do c:Disconnect() end
    moveConns = {}
    if velConn then velConn:Disconnect(); velConn = nil end
    local hum = char:WaitForChild("Humanoid", 5)
    local hrp = char:WaitForChild("HumanoidRootPart", 5)
    if not hum or not hrp then return end
    
    -- LANDING: camera shake for heavy impacts (dust handled by DoubleJump)
    table.insert(moveConns, hum.StateChanged:Connect(function(_, newState)
        if newState == Enum.HumanoidStateType.Landed then
            local impact = math.abs(lastYVel)
            
            -- HEAVY LANDING (big falls, impact > 35): screen shake + sound
            if impact > 35 then
                local heavyI = math.clamp(impact / 80, 0.3, 1.5)
                screenShake(heavyI * 0.5, 0.1)
            end
        end
        
        -- TAKEOFF PUFF: small dust cloud when jumping off ground
        if newState == Enum.HumanoidStateType.Jumping then
            local att = Instance.new("Attachment")
            att.Position = Vector3.new(0, -2.5, 0); att.Parent = hrp
            local puff = Instance.new("ParticleEmitter")
            puff.Color = ColorSequence.new(Color3.fromRGB(180, 175, 160))
            puff.Size = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.3),
                NumberSequenceKeypoint.new(0.5, 1.2),
                NumberSequenceKeypoint.new(1, 1.8),
            })
            puff.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.3),
                NumberSequenceKeypoint.new(0.4, 0.55),
                NumberSequenceKeypoint.new(1, 1),
            })
            puff.Lifetime = NumberRange.new(0.1, 0.25)
            puff.Speed = NumberRange.new(2, 6)
            puff.SpreadAngle = Vector2.new(180, 15)
            puff.Acceleration = Vector3.new(0, -5, 0)
            puff.Rate = 0; puff.LightEmission = 0.1; puff.Parent = att
            puff:Emit(6)
            Debris:AddItem(att, 0.4)
        end
    end))
    
    -- Track Y velocity for impact calculation
    velConn = RunService.Heartbeat:Connect(function()
        if hrp and hrp.Parent then lastYVel = hrp.AssemblyLinearVelocity.Y end
    end)
end

-- Movement feedback reconnects via main CharacterAdded handler above
if player.Character then connectMovementFeedback(player.Character) end

---------- FLOATING DAMAGE NUMBERS ----------
local function showFloatingDamage(dmg)
    local char = player.Character; if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    local bb = Instance.new("BillboardGui")
    bb.Name = "DmgNumber"; bb.Adornee = hrp; bb.Size = UDim2.new(0, 80, 0, 40)
    bb.StudsOffset = Vector3.new(math.random(-15, 15) / 10, 2.5, 0)
    bb.AlwaysOnTop = true; bb.Parent = hrp
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0); lbl.BackgroundTransparency = 1
    lbl.Text = "-" .. tostring(math.floor(dmg))
    lbl.TextColor3 = dmg >= 35 and Color3.fromRGB(255, 50, 30) or Color3.fromRGB(255, 180, 40)
    lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0); lbl.TextStrokeTransparency = 0.3
    lbl.Font = Enum.Font.GothamBlack; lbl.TextSize = dmg >= 35 and 28 or 22
    lbl.TextScaled = false; lbl.Parent = bb
    -- Animate: float up + fade
    local startOffset = bb.StudsOffset
    TweenService:Create(bb, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        StudsOffset = startOffset + Vector3.new(0, 3, 0)
    }):Play()
    TweenService:Create(lbl, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        TextTransparency = 1, TextStrokeTransparency = 1
    }):Play()
    task.delay(0.3, function()
        TweenService:Create(lbl, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            TextSize = lbl.TextSize * 1.3
        }):Play()
        task.delay(0.15, function()
            TweenService:Create(lbl, TweenInfo.new(0.1), {TextSize = lbl.TextSize / 1.3}):Play()
        end)
    end)
    game:GetService("Debris"):AddItem(bb, 1.3)
end

---------- HP BAR PUNCH ----------
local function punchHPBar()
    -- Quick scale-up then settle back — makes the bar feel reactive
    local orig = hpBar.Size
    hpBar.Size = UDim2.new(orig.X.Scale * 1.08, orig.X.Offset, orig.Y.Scale * 1.15, orig.Y.Offset)
    TweenService:Create(hpBar, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = orig
    }):Play()
end

---------- TIMER URGENCY ----------
local lastUrgencyTick = 0
local function timerUrgency(secondsLeft)
    -- At 10s: color shift + single pulse
    -- At 5s and below: red + rapid pulse + sound tick each second
    if secondsLeft == 10 then
        statusLabel.TextColor3 = Color3.fromRGB(255, 200, 60)
        TweenService:Create(statusLabel, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            TextSize = 32
        }):Play()
        task.delay(0.15, function()
            TweenService:Create(statusLabel, TweenInfo.new(0.2), {TextSize = 28}):Play()
        end)
        SFX.PlayUI("Countdown", camera, {Volume = 0.1, PlaybackSpeed = 1.0})
    elseif secondsLeft <= 5 and secondsLeft > 0 then
        statusLabel.TextColor3 = Color3.fromRGB(255, 60, 40)
        -- Pulse the timer display
        timerDisplay.TextColor3 = Color3.fromRGB(255, 50, 30)
        TweenService:Create(timerDisplay, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            TextSize = 36
        }):Play()
        task.delay(0.12, function()
            TweenService:Create(timerDisplay, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                TextSize = 28, TextColor3 = Color3.fromRGB(255, 180, 80)
            }):Play()
        end)
        SFX.PlayUI("Countdown", camera, {Volume = 0.12 + (5 - secondsLeft) * 0.03, PlaybackSpeed = 1.1 + (5 - secondsLeft) * 0.05})
        -- Screen edge flash at 3s and below
        if secondsLeft <= 3 and flash then
            flash.BackgroundColor3 = Color3.fromRGB(255, 200, 40)
            flash.BackgroundTransparency = 0.85
            TweenService:Create(flash, TweenInfo.new(0.4), {BackgroundTransparency = 1}):Play()
        end
    end
end


---------- ROUND TRANSITION PUNCH ----------
local function roundTransitionPunch(roundNum)
    -- Quick white-gold flash that scales with round danger
    local intensity = math.clamp(roundNum / MAX_ROUNDS, 0.2, 1.0)
    
    -- Screen flash: gold tint, stronger each round
    flash.BackgroundColor3 = Color3.fromRGB(255, 240, 180)
    flash.BackgroundTransparency = 0.7 - intensity * 0.25
    TweenService:Create(flash, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {BackgroundTransparency = 1}):Play()
    
    -- Status text punches in big then settles
    statusLabel.TextSize = 36
    TweenService:Create(statusLabel, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        TextSize = 20
    }):Play()
    
    -- Camera micro-punch (subtle, just enough to feel the transition)
    if intensity > 0.4 then
        cameraPunch(intensity * 0.6)
    end
    
    -- TopBar border flash: brief bright edge
    local origBG = topBar.BackgroundTransparency
    topBar.BackgroundTransparency = math.max(0, origBG - 0.3)
    TweenService:Create(topBar, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        BackgroundTransparency = origBG
    }):Play()
end

---------- EVENTS ----------
local lastExplosionPos = nil

GameEvents.PlayerDamaged.OnClientEvent:Connect(function(dmg)
    if dmg == 0 then nearMissCount = nearMissCount + 1; showNearMiss(); if lastExplosionPos then showDirectionalNearMiss(lastExplosionPos) end; return end
    if dmg == -1 then showLastSurvivor(); return end
    if dmg < 0 then showHealFeedback(math.abs(dmg)); return end
    
    totalDamageTaken = totalDamageTaken + dmg
    local intensity = math.clamp(dmg / 25, 0.5, 2.5)
    SFX.PlayUI("Hit", camera, {Volume = 0.4 + intensity*0.2, PlaybackSpeed = 0.8 + math.random()*0.4})
    flash.BackgroundColor3 = Color3.fromRGB(255, 40, 20)
    flash.BackgroundTransparency = math.clamp(0.15 + dmg/60, 0.2, 0.55)
    TweenService:Create(flash, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {BackgroundTransparency = 1}):Play()
    screenShake(intensity * 1.5, 0.25 + intensity * 0.1)
    tintCharacter(player.Character, Color3.fromRGB(255, 60, 60), 0.2)
    hitParticles(player.Character, intensity)

    showFloatingDamage(dmg)
    punchHPBar()    if lastExplosionPos then
        showDirectionalDamage(lastExplosionPos)
        knockbackTilt(lastExplosionPos)
    end
end)

GameEvents.PlayerDied.OnClientEvent:Connect(function(cause)
    stopTimer()
    lastDeathCause = cause or "standard"
    SFX.PlayUI("Death", camera, {Volume = 0.45})
    
    -- === DEATH VFX: particle burst at death position ===
    local char = player.Character
    local deathPos = nil
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            deathPos = hrp.Position
            -- Smoke + spark burst
            local att = Instance.new("Attachment"); att.Parent = hrp
            local smoke = Instance.new("ParticleEmitter")
            smoke.Color = ColorSequence.new(Color3.fromRGB(80, 80, 80), Color3.fromRGB(40, 40, 40))
            smoke.Size = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1.5),
                NumberSequenceKeypoint.new(0.5, 3),
                NumberSequenceKeypoint.new(1, 4),
            })
            smoke.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.3),
                NumberSequenceKeypoint.new(0.5, 0.6),
                NumberSequenceKeypoint.new(1, 1),
            })
            smoke.Lifetime = NumberRange.new(0.6, 1.2)
            smoke.Speed = NumberRange.new(5, 15)
            smoke.SpreadAngle = Vector2.new(180, 180)
            smoke.Acceleration = Vector3.new(0, 8, 0)
            smoke.RotSpeed = NumberRange.new(-100, 100)
            smoke.Rate = 0; smoke.LightEmission = 0; smoke.Parent = att
            smoke:Emit(20)
            
            local sparks = Instance.new("ParticleEmitter")
            sparks.Color = ColorSequence.new(Color3.fromRGB(255, 180, 40), Color3.fromRGB(255, 80, 20))
            sparks.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0)})
            sparks.Transparency = NumberSequence.new(0, 1)
            sparks.Lifetime = NumberRange.new(0.3, 0.8)
            sparks.Speed = NumberRange.new(12, 30)
            sparks.SpreadAngle = Vector2.new(180, 180)
            sparks.LightEmission = 0.8; sparks.Rate = 0; sparks.Parent = att
            sparks:Emit(15)
            Debris:AddItem(att, 1.5)
        end
    end
    
    -- White flash then fade to dark red
    flash.BackgroundColor3 = Color3.fromRGB(255, 255, 255); flash.BackgroundTransparency = 0
    TweenService:Create(flash, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {BackgroundTransparency = 1, BackgroundColor3 = Color3.fromRGB(255, 40, 20)}):Play()
    screenShake(4, 0.4)
    
    -- === CAMERA PULL-BACK: zoom out and look down at death spot ===
    if deathPos then
        task.spawn(function()
            camera.CameraType = Enum.CameraType.Scriptable
            local startCF = camera.CFrame
            local pullDir = (startCF.Position - deathPos).Unit
            local targetCF = CFrame.new(deathPos + pullDir * 18 + Vector3.new(0, 12, 0), deathPos)
            -- Quick snap zoom-out over 0.4s
            local elapsed = 0
            while elapsed < 0.4 do
                local dt = RunService.RenderStepped:Wait()
                elapsed = elapsed + dt
                local alpha = math.min(elapsed / 0.4, 1)
                alpha = 1 - (1 - alpha)^3 -- ease-out cubic
                camera.CFrame = startCF:Lerp(targetCF, alpha)
            end
            -- Brief hold then spectate
            task.wait(0.5)
        end)
    end
    
    -- Death screen with smooth fade
    deathScreen.Visible = true; deathScreen.BackgroundTransparency = 1
    TweenService:Create(deathScreen, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {BackgroundTransparency = 0.4}):Play()
    local dt = deathScreen:FindFirstChild("Text")
    if dt then
        dt.TextTransparency = 1; dt.TextSize = 30
        TweenService:Create(dt, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            {TextTransparency = 0, TextSize = 44}):Play()
    end
    local sub = deathScreen:FindFirstChild("Sub")
    if sub then
        local causeText = DEATH_CAUSES[lastDeathCause] or "Eliminated!"
        local survTime = survivalStart and (tick() - survivalStart) or 0
        local timeText = survivalStart and formatTime(survTime) or "0:00"
        sub.Text = causeText .. " | " .. timeText .. " alive | Round " .. currentRound
        sub.TextTransparency = 1
        task.delay(0.3, function()
            TweenService:Create(sub, TweenInfo.new(0.4), {TextTransparency = 0}):Play()
        end)
    end
    hpBar.Visible = false
        -- Quick spectate transition (~1.2s after death)
    task.delay(1.2, function()
        camera.CameraType = Enum.CameraType.Custom
        startSpectating()
    end)
    
    -- S3: Shrink death screen to compact banner after 2s (free up screen for spectating)
    task.delay(2.0, function()
        if not deathScreen.Visible then return end
        local dt = deathScreen:FindFirstChild("Text")
        local sub = deathScreen:FindFirstChild("Sub")
        -- Shrink to top banner
        TweenService:Create(deathScreen, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
            Size = UDim2.new(1, 0, 0, 44),
            Position = UDim2.new(0, 0, 0, 0),
            BackgroundTransparency = 0.3,
        }):Play()
        if dt then
            TweenService:Create(dt, TweenInfo.new(0.3), {TextSize = 16}):Play()
            dt.Text = "YOU DIED"
        end
        if sub then
            -- Show live spectate info with round context
            sub.TextSize = 13
            _spectatingCompact = true
        end
    end)
end)

GameEvents.BombLanded.OnClientEvent:Connect(function(pos)
    lastExplosionPos = pos
    local char = player.Character; if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    local dist = (hrp.Position - pos).Magnitude
    if dist < 70 then
        local s = math.clamp((70 - dist) / 70, 0, 1)
        local pitchBoost = s * 0.4
        SFX.PlayUI("Explosion", camera, {Volume = s * 0.5, PlaybackSpeed = 0.85 + pitchBoost + math.random()*0.2})
        if dist < 30 then
            cameraPunch(s * 1.5)
        else
            screenShake(s * 0.8, 0.12)
        end
    end
end)

---------- LAVA CONTACT FEEDBACK ----------
GameEvents:WaitForChild("LavaContact").OnClientEvent:Connect(function(isFirstContact)
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    -- A1: Debounced lava VFX — heavy effects only every 1.5s, light sizzle every tick
    -- Light sizzle every tick (quiet, varied pitch — organic feel without strobe)
    SFX.PlayUI("LavaSizzle", camera, {
        Volume = isFirstContact and 0.5 or 0.2,
        PlaybackSpeed = 1.8 + math.random() * 0.6,
    })
    
    -- Persistent orange vignette while on lava (replaces per-tick flash)
    if lowHPOverlay then
        lowHPOverlay.BackgroundColor3 = Color3.fromRGB(80, 30, 0)
        lowHPOverlay.BackgroundTransparency = 0.85
    end
    
    -- Heavy VFX only on first contact OR every 1.5s (debounced)
    local now = tick()
    if isFirstContact or not _lastLavaHeavyVFX or (now - _lastLavaHeavyVFX) > 1.4 then
        _lastLavaHeavyVFX = now
        
        -- Steam burst at feet
        local att = Instance.new("Attachment")
        att.Position = Vector3.new(0, -2.5, 0)
        att.Parent = hrp
        local steam = Instance.new("ParticleEmitter")
        steam.Color = ColorSequence.new(Color3.fromRGB(255, 200, 150), Color3.fromRGB(200, 200, 200))
        steam.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, isFirstContact and 1.5 or 0.8),
            NumberSequenceKeypoint.new(0.5, isFirstContact and 3.0 or 1.5),
            NumberSequenceKeypoint.new(1, isFirstContact and 4.0 or 2.0),
        })
        steam.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.3),
            NumberSequenceKeypoint.new(0.5, 0.6),
            NumberSequenceKeypoint.new(1, 1),
        })
        steam.Lifetime = NumberRange.new(0.3, 0.6)
        steam.Speed = NumberRange.new(4, 12)
        steam.SpreadAngle = Vector2.new(180, 30)
        steam.Acceleration = Vector3.new(0, 15, 0)
        steam.RotSpeed = NumberRange.new(-80, 80)
        steam.LightEmission = 0.3
        steam.Rate = 0
        steam.Parent = att
        steam:Emit(isFirstContact and 15 or 8)
        Debris:AddItem(att, 0.8)
        
        -- Orange flash (only on heavy ticks, not every 0.5s)
        flash.BackgroundColor3 = Color3.fromRGB(255, 120, 20)
        flash.BackgroundTransparency = isFirstContact and 0.6 or 0.82
        TweenService:Create(flash, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {BackgroundTransparency = 1}):Play()
        
        if isFirstContact then
            tintCharacter(char, Color3.fromRGB(255, 140, 40), 0.3)
            screenShake(0.8, 0.1)
        end
    end
end)


player.CharacterAdded:Connect(function(char)
    task.wait(0.1)
    -- Clean up stale UI/camera state from previous character
    stopSpectating()
    camera.CameraType = Enum.CameraType.Custom
    camera.CameraSubject = char:FindFirstChild("Humanoid")
    deathScreen.Visible = false
    if lowHPOverlay then
        lowHPOverlay.BackgroundTransparency = 1
    end
    -- Reconnect HP bar and movement feedback
    connectHPBar(char)
    connectMovementFeedback(char)
end)
if player.Character then connectHPBar(player.Character) end


---------- GUIDED MISSILE CLIENT EFFECTS ----------
local missileLockedOn = false
local missileReticle = nil
local missileLockOnTarget = nil

-- Create lock-on reticle (follows targeted player's head)
local function createLockOnReticle()
    if missileReticle then return end
    local bb = Instance.new("BillboardGui")
    bb.Name = "MissileLockOn"
    bb.Size = UDim2.new(0, 80, 0, 80)
    bb.StudsOffset = Vector3.new(0, 4, 0)
    bb.AlwaysOnTop = true
    bb.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    -- Red diamond reticle (diagonal frame)
    local center = Instance.new("Frame")
    center.Name = "Reticle"
    center.Size = UDim2.new(0.6, 0, 0.6, 0)
    center.Position = UDim2.new(0.2, 0, 0.2, 0)
    center.Rotation = 45
    center.BackgroundColor3 = Color3.fromRGB(255, 60, 30)
    center.BackgroundTransparency = 0.3
    center.BorderSizePixel = 0
    center.Parent = bb
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.15, 0)
    corner.Parent = center
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 200, 50)
    stroke.Thickness = 2
    stroke.Parent = center
    
    -- "LOCKED" text below reticle
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 20)
    label.Position = UDim2.new(0, 0, 1, 4)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    label.TextColor3 = Color3.fromRGB(255, 80, 30)
    label.TextStrokeTransparency = 0.5
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.Text = "LOCKED"
    label.Parent = bb
    
    missileReticle = bb
    
    -- Pulse animation on the reticle
    task.spawn(function()
        while missileReticle and missileReticle.Parent do
            TweenService:Create(center, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
                Rotation = 45 + 90,
                BackgroundTransparency = 0.1,
            }):Play()
            task.wait(0.3)
            TweenService:Create(center, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
                Rotation = 45,
                BackgroundTransparency = 0.4,
            }):Play()
            task.wait(0.3)
        end
    end)
    
    return bb
end


local function cleanupMissileEffects()
    missileLockedOn = false
    missileLockOnTarget = nil
    if missileReticle then missileReticle:Destroy(); missileReticle = nil end
end

-- Handle missile lock-on events
GameEvents:WaitForChild("MissileLockOn").OnClientEvent:Connect(function(targetName, phase)
    if phase == "lockon_start" then
        missileLockOnTarget = targetName
        local isMe = (player.Name == targetName)
        
        -- Find target player
        local targetPlayer = Players:FindFirstChild(targetName)
        local targetChar = targetPlayer and targetPlayer.Character
        
        if targetChar then
            -- Reticle above target's head
            local bb = createLockOnReticle()
            bb.Adornee = targetChar:FindFirstChild("Head") or targetChar:FindFirstChild("HumanoidRootPart")
            bb.Parent = targetChar
            

        end
        
        missileLockedOn = true
        
        -- If I'm the target: screen warning
        if isMe then
            -- Red pulsing vignette
            flash.BackgroundColor3 = Color3.fromRGB(255, 50, 20)
            flash.BackgroundTransparency = 0.7
            TweenService:Create(flash, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 2, true),
                {BackgroundTransparency = 0.85}):Play()
            
            -- "MISSILE INCOMING!" milestone
            showMilestone("MISSILE INCOMING!", Color3.fromRGB(255, 80, 30))
            
            -- Camera subtle shake
            screenShake(1.0, 0.3)
        end
        
    elseif phase == "lockon_cancel" or phase == "missile_exploded" then
        cleanupMissileEffects()
        
    elseif phase == "missile_launched" then
        -- Escalate warning for target player
        if player.Name == targetName then
            showMilestone("DODGE!", Color3.fromRGB(255, 200, 50))
            screenShake(0.5, 0.15)
        end
    end
end)

-- Handle missile position updates (for distant players to see trail)
GameEvents:WaitForChild("MissileUpdate").OnClientEvent:Connect(function(pos, dir)
    -- Positional rocket sound that follows the missile
    SFX.PlayAt("BombWhistle", pos, {
        Volume = 0.4,
        PlaybackSpeed = 1.4 + math.random() * 0.2,
    })
end)

---------- ROUND UPDATES ----------
GameEvents.RoundUpdate.OnClientEvent:Connect(function(phase, a, b, diff, survivalTime, aliveCount, hotZoneInfo)
    
    if phase == "player_eliminated" then
        showKillFeed(a, b); return
    end
    
    if phase == "return_to_lobby" then
        cleanupMissileEffects()
        restoreLobbyLighting()
        destroyRecapPanel()
        clearMilestone()
        TweenService:Create(camera, TweenInfo.new(0.5), {FieldOfView = 70}):Play()
        -- Fade to black before lobby transition
        fadeToBlack(0.6, function()
            stopSpectating()
            camera.CameraType = Enum.CameraType.Custom
            deathScreen.Visible = false
            hpBar.Visible = false
            -- Fade back in after a short hold
            task.delay(0.3, function() fadeFromBlack(0.5) end)
        end)
        return
    end
    
    if phase == "map_modifier" then
        local modNames = {craters = "CRATERS", elevated_center = "HIGH GROUND", thin_bridges = "BRIDGES"}
        local modName = modNames[a] or a:upper()
        showMilestone("MAP: " .. modName, Color3.fromRGB(200, 200, 255))
        return
    end
    
    if phase == "hot_zone" then
        -- a = zone name ("NW","NE","SW","SE","CENTER"), b = round number
        local zoneNames = {NW="NORTH-WEST", NE="NORTH-EAST", SW="SOUTH-WEST", SE="SOUTH-EAST", CENTER="CENTER"}
        local zoneName = zoneNames[a] or a
        showMilestone("HOT ZONE: " .. zoneName, Color3.fromRGB(255, 140, 50))
        return
    end
        
    if phase == "lobby_wait" then
        cleanupMissileEffects()
        restoreLobbyLighting()
        destroyRecapPanel()
        clearMilestone()
        stopSpectating(); stopTimer()
        totalDamageTaken = 0; nearMissCount = 0; lastDeathCause = nil
        TweenService:Create(camera, TweenInfo.new(0.5), {FieldOfView = 70}):Play()

        -- Full UI state reset
        statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        statusLabel.TextSize = 20
        countdownLabel.TextSize = 100
        if lowHPOverlay then
            lowHPOverlay.BackgroundColor3 = Color3.fromRGB(30, 0, 0)
            lowHPOverlay.BackgroundTransparency = 1
        end
        flash.BackgroundTransparency = 1
        spectateLabel.Visible = false
        resetRoundDots()
        totalDamageTaken = 0; nearMissCount = 0
        deathScreen.Visible = false; countdownLabel.TextTransparency = 1

        deathScreen.Size = UDim2.new(1, 0, 1, 0); deathScreen.Position = UDim2.new(0, 0, 0, 0)
        _spectatingCompact = false; _specLerpTarget = nil        statusLabel.Text = a > 0 and ("NEXT GAME IN " .. a .. "s") or "WAITING..."
        -- Lobby countdown audio ticks
        if a > 0 and a <= 3 then
            SFX.PlayUI("RoundTick", camera, {Volume = 0.3 + (4 - a) * 0.1, PlaybackSpeed = 0.9 + (4 - a) * 0.1})
        end
        timerDisplay.Text = ""
        infoLabel.Text = (diff and diff > 0) and (diff .. " player" .. (diff > 1 and "s" or "") .. " in lobby") or "Waiting for players..."
        infoLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
        hpBar.Visible = false; roundsThisSession = 0; hasPlayedFirstDrop = false
        fadeFrame.BackgroundTransparency = 1 -- ensure no stale black screen
        _lastLavaHeavyVFX = nil
        cleanupMissileEffects()

    elseif phase == "countdown" then
        deathScreen.Visible = false
        statusLabel.Text = "GET READY!"
        infoLabel.Text = ""
        showCountdownNumber(a)
        
    elseif phase == "drop" then
        stopSpectating()
        inArena = true
        statusLabel.Text = ""
        infoLabel.Text = ""
        countdownLabel.TextTransparency = 1
        -- Instant black (hides teleport completely), then smooth reveal
        fadeGuard = false
        if activeFadeTween then activeFadeTween:Cancel(); activeFadeTween = nil end
        fadeFrame.BackgroundTransparency = 0
        -- Hold black while teleport settles, then gentle fade in
        task.delay(0.6, function()
            fadeFromBlack(1.0)
        end)
        
    elseif phase == "countdown_go" then
        countdownLabel.Text = "GO!"
        countdownLabel.TextColor3 = Color3.fromRGB(100, 255, 120)
        countdownLabel.TextTransparency = 0; countdownLabel.TextSize = 100
        TweenService:Create(countdownLabel, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            {TextSize = 160}):Play()
        task.delay(0.6, function()
            TweenService:Create(countdownLabel, TweenInfo.new(0.4), {TextTransparency = 1}):Play()
        end)
        statusLabel.Text = "GO!"
        infoLabel.Text = "Survive!"
        hpBar.Visible = true; startTimer()
        updateRoundDots(1)
        
    elseif phase == "round_start" then
        currentRound = a; roundsThisSession = a

        -- Clear stale GO! text and reset UI state from previous round
        countdownLabel.TextTransparency = 1
        statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        statusLabel.TextSize = 20
        statusLabel.Text = "ROUND " .. a .. " / " .. MAX_ROUNDS
        infoLabel.Text = ""
        updateRoundDots(a)
        
        -- F2: Round escalation intensity callout (R5+)
        if a >= 7 then
            showMilestone("FINAL STAND", Color3.fromRGB(200, 30, 30))
            screenShake(1.2, 0.3)
        elseif a >= 6 then
            showMilestone("DANGER ZONE", Color3.fromRGB(255, 60, 30))
            screenShake(0.8, 0.2)
        elseif a >= 5 then
            showMilestone("INTENSITY RISING", Color3.fromRGB(255, 160, 40))
        end
        
        -- Late-round FOV shift: subtle intensity increase through the camera
        local fovTarget = 70  -- default FOV
        if a >= 7 then fovTarget = 76
        elseif a >= 6 then fovTarget = 74
        elseif a >= 5 then fovTarget = 72
        end
        TweenService:Create(camera, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            FieldOfView = fovTarget,
        }):Play()
        
        local lateRound = (a >= 4)
        
        -- === INTER-ROUND COUNTDOWN: big visible number + escalating tick ===
        -- Smaller than game-start (80 vs 140) and amber-toned to feel distinct
        local tickColor = Color3.fromRGB(255, 200, 100)
        if b <= 2 then tickColor = Color3.fromRGB(255, 150, 60) end
        if b == 1 then tickColor = Color3.fromRGB(255, 100, 40) end
        
        countdownLabel.Text = tostring(b)
        countdownLabel.TextColor3 = tickColor
        countdownLabel.TextTransparency = 0
        countdownLabel.TextSize = 40
        TweenService:Create(countdownLabel, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            {TextSize = 80}):Play()
        task.delay(0.4, function()
            TweenService:Create(countdownLabel, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                {TextTransparency = 0.8, TextSize = 60}):Play()
        end)
        
        -- Tick sound: escalates each second (actually audible)
        local vol = ({[3] = 0.30, [2] = 0.38, [1] = 0.45})[b] or 0.3
        local pitch = ({[3] = 0.9, [2] = 1.0, [1] = 1.15})[b] or 1.0
        SFX.PlayUI("RoundTick", camera, {Volume = vol, PlaybackSpeed = pitch})
        
        if b == 3 then
            setArenaLighting(a)

            roundTransitionPunch(a)            statusLabel.TextTransparency = 0.5
            TweenService:Create(statusLabel, TweenInfo.new(0.3), {TextTransparency = 0.15}):Play()
            
            for _, m in ipairs(milestones) do
                if a == m.round then showMilestone(m.text, m.color); break end
            end
            if diff >= 4.0 then
                showMilestone("DANGER: EXTREME", Color3.fromRGB(255, 50, 50))
            elseif diff >= 3.0 then
                showMilestone("DANGER: HIGH", Color3.fromRGB(255, 160, 30))
            end
        end
        
        -- Vignette builds in last 2 seconds
        if b <= 2 then
            screenShake(0.15 + (3 - b) * 0.1, 0.2)
            if lowHPOverlay then
                lowHPOverlay.BackgroundColor3 = Color3.fromRGB(40, 20, 10)
                local vigT = lateRound and (0.78 + b * 0.05) or (0.85 + b * 0.04)
                TweenService:Create(lowHPOverlay, TweenInfo.new(0.5), {BackgroundTransparency = vigT}):Play()
            end
        end
        
        if b == 1 then
            TweenService:Create(statusLabel, TweenInfo.new(0.3), {
                TextColor3 = Color3.fromRGB(255, 200, 80)
            }):Play()
        end
        
        -- Difficulty bar (always)        
    elseif phase == "survive" then
        -- Clear inter-round countdown + tension vignette
        countdownLabel.TextTransparency = 1
        if lowHPOverlay then
            TweenService:Create(lowHPOverlay, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
        end
        statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        infoLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        statusLabel.Text = "SURVIVE!"
        statusLabel.TextColor3 = b <= 10 and Color3.fromRGB(255, 220, 80) or Color3.fromRGB(255, 255, 255)
        timerUrgency(b)

        -- (best time display removed)        -- Clean info: just seconds left (round shown in status + dots, time in timer)
        infoLabel.Text = (aliveCount and (aliveCount .. " alive | ") or "") .. b .. "s remaining"
        -- Color code info based on alive count
        if aliveCount then
            if aliveCount <= 2 then
                infoLabel.TextColor3 = Color3.fromRGB(255, 180, 80)
            elseif aliveCount <= 5 then
                infoLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
            else
                infoLabel.TextColor3 = Color3.fromRGB(150, 200, 150)
            end
        end        if diff and diff >= 3.0 and lowHPOverlay then
            local vignetteT = math.clamp(0.85 + (4.0 - diff) * 0.05, 0.8, 0.9)
            lowHPOverlay.BackgroundColor3 = Color3.fromRGB(30, 0, 0)
            TweenService:Create(lowHPOverlay, TweenInfo.new(0.5), {BackgroundTransparency = vignetteT}):Play()
        end
        
    elseif phase == "round_survived" then
        if lowHPOverlay then lowHPOverlay.BackgroundColor3 = Color3.fromRGB(30, 0, 0) end
        -- Personal best tracking
        if b > bestRound then
            bestRound = b
            if bestRound >= 2 then
                task.delay(0.8, function() showMilestone("NEW BEST! Round " .. bestRound, Color3.fromRGB(255, 220, 50)) end)
            end
        end
        _lastLavaHeavyVFX = nil
        -- Timer keeps running (total survival time, not per-round)
        -- (best time tracking removed)
        
        updateRoundDots(b)
        -- === ROUND CLEAR: The dopamine moment ===
        -- 1) Bright chime — pitch rises slightly each round (escalating triumph)
        task.delay(0.2, function()
            SFX.PlayUI("RoundClear", camera, {
                Volume = 0.4,
                PlaybackSpeed = 1.0 + (b - 1) * 0.025,
            })
        end)
        
        -- 2) Status text PUNCHES in: scale up → settle
        statusLabel.Text = "ROUND " .. b .. " / " .. MAX_ROUNDS .. " CLEAR!"
        statusLabel.TextColor3 = Color3.fromRGB(80, 255, 120)
        statusLabel.TextSize = 38
        TweenService:Create(statusLabel, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            TextSize = 30
        }):Play()
        task.delay(0.6, function()
            TweenService:Create(statusLabel, TweenInfo.new(0.4), {
                TextColor3 = Color3.fromRGB(255, 255, 255),
                TextSize = 28,
            }):Play()
        end)
        
        -- 3) Info line: show survivors + heal info
        local healPct = 30
        infoLabel.Text = a .. " alive | +" .. healPct .. " HP"
        infoLabel.TextColor3 = Color3.fromRGB(120, 255, 140)
        task.delay(1.0, function()
            TweenService:Create(infoLabel, TweenInfo.new(0.3), {
                TextColor3 = Color3.fromRGB(200, 200, 200),
            }):Play()
        end)
        
        -- 4) Healing PULSE: bright green wash across screen (unmissable)
        flash.BackgroundColor3 = Color3.fromRGB(60, 255, 80)
        flash.BackgroundTransparency = 0.55
        TweenService:Create(flash, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {BackgroundTransparency = 1}):Play()
        
        -- 5) Centered floating "+HP" label (screen space, can't miss it)
        local healFloat = Instance.new("TextLabel")
        healFloat.Size = UDim2.new(0, 200, 0, 40)
        healFloat.Position = UDim2.new(0.5, -100, 0.42, 0)
        healFloat.BackgroundTransparency = 1
        healFloat.Font = Enum.Font.GothamBold; healFloat.TextSize = 34
        healFloat.TextColor3 = Color3.fromRGB(80, 255, 120)
        healFloat.TextStrokeTransparency = 0.5
        healFloat.TextStrokeColor3 = Color3.fromRGB(0, 60, 10)
        healFloat.Text = "+" .. healPct .. " HP"
        healFloat.ZIndex = 18; healFloat.Parent = gui
        TweenService:Create(healFloat, TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = UDim2.new(0.5, -100, 0.35, 0),
            TextTransparency = 1,
            TextStrokeTransparency = 1,
        }):Play()
        Debris:AddItem(healFloat, 1.2)
        
        -- 6) HP bar green flash
        if hpBar and hpBar.Visible then
            local fill = hpBar:FindFirstChild("Fill")
            if fill then
                local origColor = fill.BackgroundColor3
                fill.BackgroundColor3 = Color3.fromRGB(80, 255, 120)
                TweenService:Create(fill, TweenInfo.new(0.5), {BackgroundColor3 = origColor}):Play()
            end
            punchHPBar()
        end
        
        -- 7) Confetti burst (kept, slightly boosted)
        local char = player.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local att = Instance.new("Attachment"); att.Parent = hrp
                local confetti = Instance.new("ParticleEmitter")
                confetti.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 220, 50)),
                    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(100, 255, 120)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 180, 255)),
                })
                confetti.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1.0), NumberSequenceKeypoint.new(1, 0)})
                confetti.Transparency = NumberSequence.new(0, 1)
                confetti.Lifetime = NumberRange.new(0.6, 1.4); confetti.Speed = NumberRange.new(10, 25)
                confetti.SpreadAngle = Vector2.new(180, 70); confetti.Acceleration = Vector3.new(0, -18, 0)
                confetti.RotSpeed = NumberRange.new(-200, 200); confetti.Rate = 0; confetti.Parent = att
                confetti:Emit(30); Debris:AddItem(att, 2)
            end
        end
        
    elseif phase == "victory" then
        -- === VICTORY: Players survived all rounds! ===
        stopTimer()
        restoreLobbyLighting()
        
        -- All dots go green
        if roundDotsFrame then
            for i = 1, MAX_ROUNDS do
                local dot = roundDotsFrame:FindFirstChild("Dot" .. i)
                if dot then
                    dot.BackgroundColor3 = Color3.fromRGB(80, 255, 120)
                    dot.BackgroundTransparency = 0
                end
            end
        end
        
        -- Big "VICTORY!" text
        countdownLabel.Text = "VICTORY!"
        countdownLabel.TextColor3 = Color3.fromRGB(255, 220, 50)
        countdownLabel.TextTransparency = 0
        countdownLabel.TextSize = 50
        TweenService:Create(countdownLabel, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            TextSize = 120
        }):Play()
        
        -- Victory chime (triumphant, lower pitch for gravitas)
        SFX.PlayUI("RoundClear", camera, {Volume = 0.6, PlaybackSpeed = 0.8})
        task.delay(0.4, function() SFX.PlayUI("RoundClear", camera, {Volume = 0.5, PlaybackSpeed = 1.2}) end)
        statusLabel.Text = "ALL " .. MAX_ROUNDS .. " ROUNDS SURVIVED!"
        statusLabel.TextColor3 = Color3.fromRGB(255, 220, 80)
        infoLabel.Text = a .. " survivors | " .. formatTime(survivalTime or 0)
        infoLabel.TextColor3 = Color3.fromRGB(200, 255, 200)
        
        -- Victory chime
        SFX.PlayUI("RoundClear", camera, {Volume = 0.6, PlaybackSpeed = 0.85})
        task.delay(0.3, function()
            SFX.PlayUI("RoundClear", camera, {Volume = 0.5, PlaybackSpeed = 1.1})
        end)
        
        -- Gold screen flash
        flash.BackgroundColor3 = Color3.fromRGB(255, 220, 50)
        flash.BackgroundTransparency = 0.4
        TweenService:Create(flash, TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {BackgroundTransparency = 1}):Play()
        
        -- Confetti burst (bigger than round survived)
        local char = player.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local att = Instance.new("Attachment"); att.Parent = hrp
                local confetti = Instance.new("ParticleEmitter")
                confetti.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 220, 50)),
                    ColorSequenceKeypoint.new(0.3, Color3.fromRGB(255, 100, 200)),
                    ColorSequenceKeypoint.new(0.6, Color3.fromRGB(100, 255, 120)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 180, 255)),
                })
                confetti.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 0)})
                confetti.Transparency = NumberSequence.new(0, 1)
                confetti.Lifetime = NumberRange.new(1.0, 2.0); confetti.Speed = NumberRange.new(15, 35)
                confetti.SpreadAngle = Vector2.new(180, 90); confetti.Acceleration = Vector3.new(0, -15, 0)
                confetti.RotSpeed = NumberRange.new(-200, 200); confetti.Rate = 0; confetti.Parent = att
                confetti:Emit(50); Debris:AddItem(att, 3)
            end
        end
        
        -- Fade out victory text after 2s
        task.delay(2, function()
            TweenService:Create(countdownLabel, TweenInfo.new(0.8), {TextTransparency = 1}):Play()
        end)
        
    elseif phase == "game_over" then
        stopTimer()
        clearMilestone()
        -- Update personal best
        if a > bestRound then bestRound = a end
        statusLabel.Text = "GAME OVER!"
        infoLabel.Text = "Restarting " .. b .. "s"
        SFX.PlayUI("GameOver", camera, {Volume = 0.4})
        hpBar.Visible = false
        -- Show the recap panel with stats
        local survTime = survivalStart and (tick() - survivalStart) or 0
        createRecapPanel(a, survTime, lastDeathCause, a >= bestRound and a > 0)
 
        if lowHPOverlay then
            lowHPOverlay.BackgroundColor3 = Color3.fromRGB(180, 0, 0)
            TweenService:Create(lowHPOverlay, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
        end
    end
end)

---------- INITIAL STATE ----------
hpBar.Visible = false
timerDisplay.Text = "0:00"
infoLabel.Text = "Lobby"
countdownLabel.TextTransparency = 1

print("[HUDController v22] Ready — Tier1 polish, no double-punch, clean resets!")

[OUTPUT] 