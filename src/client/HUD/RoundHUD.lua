-- HUD/RoundHUD: Countdown, timer, milestones, round dots, timer urgency
-- Manages the top-bar round progression display and inter-round countdowns.

local ctx -- set via init()

local timerConn = nil
local _milestoneVersion = 0

local milestones = {
    {round = 3, text = "WARMING UP!", color = Color3.fromRGB(130, 230, 255)},
    {round = 4, text = "HALFWAY!", color = Color3.fromRGB(100, 255, 100)},
    {round = 6, text = "ALMOST THERE!", color = Color3.fromRGB(255, 200, 50)},
}

local M = {}

function M.init(context)
    ctx = context
end

---------- TIMER ----------
function M.startTimer()
    ctx.state.survivalStart = tick()
    ctx.state.isAlive = true
    if timerConn then timerConn:Disconnect() end
    timerConn = ctx.RunService.Heartbeat:Connect(function()
        local st = ctx.state
        if st.survivalStart and st.isAlive then
            local elapsed = tick() - st.survivalStart
            ctx.timerDisplay.Text = ctx.formatTime(elapsed)
            if elapsed > 25 then
                local pulse = math.abs(math.sin(tick() * 3))
                ctx.timerDisplay.TextColor3 = Color3.fromRGB(255, 200 + pulse * 55, 200 + pulse * 55):Lerp(
                    Color3.fromRGB(255, 180, 80), pulse * 0.5)
            else
                ctx.timerDisplay.TextColor3 = Color3.fromRGB(255, 255, 255)
            end
        end
    end)
end

function M.stopTimer()
    ctx.state.isAlive = false
    if timerConn then timerConn:Disconnect(); timerConn = nil end
    ctx.timerDisplay.TextColor3 = Color3.fromRGB(255, 255, 255)
end

---------- MILESTONES ----------
function M.showMilestone(text, color)
    _milestoneVersion = _milestoneVersion + 1
    local thisVersion = _milestoneVersion
    ctx.milestoneLabel.Text = text
    ctx.milestoneLabel.TextColor3 = color
    ctx.milestoneLabel.TextTransparency = 1
    ctx.milestoneLabel.Position = UDim2.new(0.5, 0, 0.28, 0)
    ctx.TweenService:Create(ctx.milestoneLabel, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {TextTransparency = 0, Position = UDim2.new(0.5, 0, 0.25, 0)}):Play()
    task.delay(1.8, function()
        if _milestoneVersion ~= thisVersion then return end
        ctx.TweenService:Create(ctx.milestoneLabel, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {TextTransparency = 1, Position = UDim2.new(0.5, 0, 0.22, 0)}):Play()
    end)
end

function M.clearMilestone()
    _milestoneVersion = _milestoneVersion + 1
    ctx.milestoneLabel.TextTransparency = 1
end

---------- COUNTDOWN ----------
function M.showCountdownNumber(num)
    local color = num == 3 and Color3.fromRGB(255, 100, 100)
        or num == 2 and Color3.fromRGB(255, 200, 80)
        or Color3.fromRGB(100, 255, 100)
    ctx.countdownLabel.Text = tostring(num)
    ctx.countdownLabel.TextColor3 = color
    ctx.countdownLabel.TextTransparency = 0
    ctx.countdownLabel.TextSize = 60
    ctx.TweenService:Create(ctx.countdownLabel, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {TextSize = 140}):Play()
    task.delay(0.5, function()
        ctx.TweenService:Create(ctx.countdownLabel, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {TextTransparency = 1, TextSize = 80}):Play()
    end)
    ctx.SFX.PlayUI("Countdown", ctx.camera, {Volume = 0.12, PlaybackSpeed = 1.05 + (4 - num) * 0.05})
end

---------- ROUND DOTS ----------
function M.updateRoundDots(completedRound)
    local roundDotsFrame = ctx.topBar:FindFirstChild("RoundDots")
    if not roundDotsFrame then return end
    for i = 1, ctx.MAX_ROUNDS do
        local dot = roundDotsFrame:FindFirstChild("Dot" .. i)
        if dot then
            if i < completedRound then
                dot.BackgroundColor3 = Color3.fromRGB(80, 255, 120)
                dot.BackgroundTransparency = 0.1
            elseif i == completedRound then
                dot.BackgroundColor3 = Color3.fromRGB(255, 240, 100)
                dot.BackgroundTransparency = 0
                ctx.TweenService:Create(dot, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                    Size = UDim2.new(0, 18, 0, 8)
                }):Play()
                task.delay(0.4, function()
                    ctx.TweenService:Create(dot, TweenInfo.new(0.3), {Size = UDim2.new(0, 14, 0, 6)}):Play()
                end)
            else
                dot.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
                dot.BackgroundTransparency = 0.4
                dot.Size = UDim2.new(0, 14, 0, 6)
            end
        end
    end
end

function M.resetRoundDots()
    local roundDotsFrame = ctx.topBar:FindFirstChild("RoundDots")
    if not roundDotsFrame then return end
    for i = 1, ctx.MAX_ROUNDS do
        local dot = roundDotsFrame:FindFirstChild("Dot" .. i)
        if dot then
            dot.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
            dot.BackgroundTransparency = 0.4
            dot.Size = UDim2.new(0, 14, 0, 6)
        end
    end
end

---------- TIMER URGENCY ----------
function M.timerUrgency(secondsLeft)
    if secondsLeft == 10 then
        ctx.statusLabel.TextColor3 = Color3.fromRGB(255, 200, 60)
        ctx.TweenService:Create(ctx.statusLabel, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            TextSize = 32
        }):Play()
        task.delay(0.15, function()
            ctx.TweenService:Create(ctx.statusLabel, TweenInfo.new(0.2), {TextSize = 28}):Play()
        end)
        ctx.SFX.PlayUI("Countdown", ctx.camera, {Volume = 0.1, PlaybackSpeed = 1.0})
    elseif secondsLeft <= 5 and secondsLeft > 0 then
        ctx.statusLabel.TextColor3 = Color3.fromRGB(255, 60, 40)
        ctx.timerDisplay.TextColor3 = Color3.fromRGB(255, 50, 30)
        ctx.TweenService:Create(ctx.timerDisplay, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            TextSize = 36
        }):Play()
        task.delay(0.12, function()
            ctx.TweenService:Create(ctx.timerDisplay, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                TextSize = 28, TextColor3 = Color3.fromRGB(255, 180, 80)
            }):Play()
        end)
        ctx.SFX.PlayUI("Countdown", ctx.camera, {
            Volume = 0.12 + (5 - secondsLeft) * 0.03,
            PlaybackSpeed = 1.1 + (5 - secondsLeft) * 0.05,
        })
        if secondsLeft <= 3 and ctx.flash then
            ctx.flash.BackgroundColor3 = Color3.fromRGB(255, 200, 40)
            ctx.flash.BackgroundTransparency = 0.85
            ctx.TweenService:Create(ctx.flash, TweenInfo.new(0.4), {BackgroundTransparency = 1}):Play()
        end
    end
end

---------- ROUND TRANSITION PUNCH ----------
function M.roundTransitionPunch(roundNum, cameraPunchFn)
    local intensity = math.clamp(roundNum / ctx.MAX_ROUNDS, 0.2, 1.0)

    ctx.flash.BackgroundColor3 = Color3.fromRGB(255, 240, 180)
    ctx.flash.BackgroundTransparency = 0.7 - intensity * 0.25
    ctx.TweenService:Create(ctx.flash, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {BackgroundTransparency = 1}):Play()

    ctx.statusLabel.TextSize = 36
    ctx.TweenService:Create(ctx.statusLabel, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        TextSize = 20
    }):Play()

    if intensity > 0.4 then cameraPunchFn(intensity * 0.6) end

    local origBG = ctx.topBar.BackgroundTransparency
    ctx.topBar.BackgroundTransparency = math.max(0, origBG - 0.3)
    ctx.TweenService:Create(ctx.topBar, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        BackgroundTransparency = origBG
    }):Play()
end

---------- ROUND-SPECIFIC MILESTONES ----------
function M.checkRoundMilestones(roundNum, diff)
    -- Round escalation callouts
    if roundNum >= 7 then
        M.showMilestone("FINAL STAND", Color3.fromRGB(200, 30, 30))
    elseif roundNum >= 6 then
        M.showMilestone("DANGER ZONE", Color3.fromRGB(255, 60, 30))
    elseif roundNum >= 5 then
        M.showMilestone("INTENSITY RISING", Color3.fromRGB(255, 160, 40))
    end
end

function M.checkCountdownMilestones(roundNum, countdown, diff)
    if countdown == 3 then
        for _, m in ipairs(milestones) do
            if roundNum == m.round then M.showMilestone(m.text, m.color); break end
        end
        if diff >= 4.0 then
            M.showMilestone("DANGER: EXTREME", Color3.fromRGB(255, 50, 50))
        elseif diff >= 3.0 then
            M.showMilestone("DANGER: HIGH", Color3.fromRGB(255, 160, 30))
        end
    end
end

return M
