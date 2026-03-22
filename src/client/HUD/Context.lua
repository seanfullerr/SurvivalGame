-- HUD/Context: Shared services, GUI refs, state, and utility functions
-- All HUD modules require this to access common dependencies.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

local ok, SFX = pcall(require, RS:WaitForChild("SoundManager"))
if not ok then warn("[HUD] SoundManager failed"); SFX = nil end

local GameEvents = RS:WaitForChild("GameEvents")
local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui"):WaitForChild("GameHUD")
local camera = workspace.CurrentCamera

-- GUI element refs (cached once)
local topBar = gui:WaitForChild("TopBar")
local statusLabel = topBar:WaitForChild("Status")
local timerDisplay = topBar:WaitForChild("TimerDisplay")
local infoLabel = topBar:WaitForChild("Info")
local flash = gui:WaitForChild("Flash")
local deathScreen = gui:WaitForChild("Death")
local milestoneLabel = gui:WaitForChild("Milestone")
local countdownLabel = gui:WaitForChild("CountdownLabel")
local leaderboard = gui:WaitForChild("Leaderboard")
local lbEntries = leaderboard:WaitForChild("Entries")
local hpBar = gui:WaitForChild("HPBar")
local hpFill = hpBar:WaitForChild("Fill")
local hpText = hpBar:WaitForChild("HPText")
local lowHPOverlay = gui:WaitForChild("LowHPOverlay")
local nearMissLabel = gui:WaitForChild("NearMiss")

-- Mutable state shared across modules
local state = {
    currentRound = 0,
    hasPlayedFirstDrop = false,
    survivalStart = nil,
    bestTime = 0,
    bestRound = 0,
    isAlive = false,
    roundsThisSession = 0,
    lastServerLB = 0,
    lastDeathCause = nil,
    totalDamageTaken = 0,
    nearMissCount = 0,
    lastExplosionPos = nil,
    _lastLavaHeavyVFX = nil,
    _spectatingCompact = false,
    _specLerpTarget = nil,
    _deathScreenActive = false,  -- true while death screen should stay visible
}

-- Cache of each body part's TRUE original color (before damage tinting)
local charOrigColors = {}

local function captureOrigColors(char)
    if not char then return end
    -- Clear in-place (don't reassign — other modules hold a reference to this table)
    for k in pairs(charOrigColors) do charOrigColors[k] = nil end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            charOrigColors[part] = part.Color
        end
    end
end

-- Capture on every spawn
player.CharacterAdded:Connect(function(char)
    task.defer(function() captureOrigColors(char) end)
end)
if player.Character then
    task.defer(function() captureOrigColors(player.Character) end)
end

---------- CONSTANTS ----------
local MAX_ROUNDS = 7

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

---------- UTILITIES ----------
local function formatTime(s)
    return string.format("%d:%02d", math.floor(s / 60), math.floor(s % 60))
end

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
    if obj:IsA("TextLabel") then
        local targetSize = obj.TextSize
        obj.TextSize = targetSize * 0.7
        TweenService:Create(obj, TweenInfo.new(duration, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            {TextSize = targetSize}):Play()
    end
end

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

---------- ARENA LIGHTING ----------
local originalAmbient = Lighting.Ambient
local originalBrightness = Lighting.Brightness
local originalOutdoorAmbient = Lighting.OutdoorAmbient
local inArena = false

local function setArenaLighting(roundNum)
    if not inArena then return end
    local progress = math.clamp((roundNum - 1) / 6, 0, 1)
    local darkCurve = progress * progress * progress
    local ambientR = math.floor(128 - darkCurve * 100)
    local ambientG = math.floor(128 - darkCurve * 105)
    local ambientB = math.floor(128 - darkCurve * 110)
    local brightness = 2 - darkCurve * 1.5
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

-- Export everything modules need
return {
    -- Services
    Players = Players,
    RS = RS,
    TweenService = TweenService,
    Debris = Debris,
    RunService = RunService,
    UIS = UIS,
    Lighting = Lighting,
    SFX = SFX,

    -- Core refs
    GameEvents = GameEvents,
    player = player,
    gui = gui,
    camera = camera,

    -- GUI elements
    topBar = topBar,
    statusLabel = statusLabel,
    timerDisplay = timerDisplay,
    infoLabel = infoLabel,
    flash = flash,
    deathScreen = deathScreen,
    milestoneLabel = milestoneLabel,
    countdownLabel = countdownLabel,
    leaderboard = leaderboard,
    lbEntries = lbEntries,
    hpBar = hpBar,
    hpFill = hpFill,
    hpText = hpText,
    lowHPOverlay = lowHPOverlay,
    nearMissLabel = nearMissLabel,
    fadeFrame = fadeFrame,

    -- State (mutable, shared by reference)
    state = state,
    charOrigColors = charOrigColors,
    captureOrigColors = captureOrigColors,

    -- Constants
    MAX_ROUNDS = MAX_ROUNDS,
    DEATH_CAUSES = DEATH_CAUSES,

    -- Utilities
    formatTime = formatTime,
    fadeIn = fadeIn,
    scalePopIn = scalePopIn,
    fadeToBlack = fadeToBlack,
    fadeFromBlack = fadeFromBlack,
    setArenaLighting = setArenaLighting,
    restoreLobbyLighting = restoreLobbyLighting,
    setInArena = function(v) inArena = v end,
}
