-- HUD/Celebrations: Round-survived and victory celebration VFX
-- Confetti bursts, screen flashes, heal floats, victory text.

local ctx -- set via init()

local M = {}

function M.init(context)
    ctx = context
end

-- Confetti particle burst on player
local function confettiBurst(count, lifetime, speed, spread)
    local char = ctx.player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local att = Instance.new("Attachment"); att.Parent = hrp
    local confetti = Instance.new("ParticleEmitter")
    confetti.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 220, 50)),
        ColorSequenceKeypoint.new(0.3, Color3.fromRGB(255, 100, 200)),
        ColorSequenceKeypoint.new(0.6, Color3.fromRGB(100, 255, 120)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 180, 255)),
    })
    confetti.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, count > 40 and 1.5 or 1.0),
        NumberSequenceKeypoint.new(1, 0),
    })
    confetti.Transparency = NumberSequence.new(0, 1)
    confetti.Lifetime = NumberRange.new(lifetime[1], lifetime[2])
    confetti.Speed = NumberRange.new(speed[1], speed[2])
    confetti.SpreadAngle = Vector2.new(180, spread)
    confetti.Acceleration = Vector3.new(0, count > 40 and -15 or -18, 0)
    confetti.RotSpeed = NumberRange.new(-200, 200)
    confetti.Rate = 0; confetti.Parent = att
    confetti:Emit(count)
    ctx.Debris:AddItem(att, count > 40 and 3 or 2)
end

-- Round survived celebration
function M.roundSurvived(roundNum, aliveCount, showMilestoneFn, punchHPBarFn)
    local st = ctx.state
    -- Personal best tracking
    if roundNum > st.bestRound then
        st.bestRound = roundNum
        if st.bestRound >= 2 then
            task.delay(0.8, function()
                showMilestoneFn("NEW BEST! Round " .. st.bestRound, Color3.fromRGB(255, 220, 50))
            end)
        end
    end
    st._lastLavaHeavyVFX = nil

    -- 1) Chime — pitch rises each round
    task.delay(0.2, function()
        ctx.SFX.PlayUI("RoundClear", ctx.camera, {
            Volume = 0.4,
            PlaybackSpeed = 1.0 + (roundNum - 1) * 0.025,
        })
    end)

    -- 2) Status text punch
    ctx.statusLabel.Text = "ROUND " .. roundNum .. " / " .. ctx.MAX_ROUNDS .. " CLEAR!"
    ctx.statusLabel.TextColor3 = Color3.fromRGB(80, 255, 120)
    ctx.statusLabel.TextSize = 38
    ctx.TweenService:Create(ctx.statusLabel, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        TextSize = 30
    }):Play()
    task.delay(0.6, function()
        ctx.TweenService:Create(ctx.statusLabel, TweenInfo.new(0.4), {
            TextColor3 = Color3.fromRGB(255, 255, 255), TextSize = 28,
        }):Play()
    end)

    -- 3) Info line
    local healPct = 30
    ctx.infoLabel.Text = aliveCount .. " alive | +" .. healPct .. " HP"
    ctx.infoLabel.TextColor3 = Color3.fromRGB(120, 255, 140)
    task.delay(1.0, function()
        ctx.TweenService:Create(ctx.infoLabel, TweenInfo.new(0.3), {
            TextColor3 = Color3.fromRGB(200, 200, 200),
        }):Play()
    end)

    -- 4) Green flash
    ctx.flash.BackgroundColor3 = Color3.fromRGB(60, 255, 80)
    ctx.flash.BackgroundTransparency = 0.55
    ctx.TweenService:Create(ctx.flash, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {BackgroundTransparency = 1}):Play()

    -- 5) Floating "+HP"
    local healFloat = Instance.new("TextLabel")
    healFloat.Size = UDim2.new(0, 200, 0, 40)
    healFloat.Position = UDim2.new(0.5, -100, 0.42, 0)
    healFloat.BackgroundTransparency = 1
    healFloat.Font = Enum.Font.GothamBold; healFloat.TextSize = 34
    healFloat.TextColor3 = Color3.fromRGB(80, 255, 120)
    healFloat.TextStrokeTransparency = 0.5
    healFloat.TextStrokeColor3 = Color3.fromRGB(0, 60, 10)
    healFloat.Text = "+" .. healPct .. " HP"
    healFloat.ZIndex = 18; healFloat.Parent = ctx.gui
    ctx.TweenService:Create(healFloat, TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, -100, 0.35, 0),
        TextTransparency = 1, TextStrokeTransparency = 1,
    }):Play()
    ctx.Debris:AddItem(healFloat, 1.2)

    -- 6) HP bar green flash
    if ctx.hpBar and ctx.hpBar.Visible then
        local fill = ctx.hpBar:FindFirstChild("Fill")
        if fill then
            local origColor = fill.BackgroundColor3
            fill.BackgroundColor3 = Color3.fromRGB(80, 255, 120)
            ctx.TweenService:Create(fill, TweenInfo.new(0.5), {BackgroundColor3 = origColor}):Play()
        end
        punchHPBarFn()
    end

    -- 7) Confetti
    confettiBurst(30, {0.6, 1.4}, {10, 25}, 70)
end

-- Victory celebration (all rounds survived)
function M.victory(aliveCount, survivalTime)
    local st = ctx.state

    -- All dots green
    local roundDotsFrame = ctx.topBar:FindFirstChild("RoundDots")
    if roundDotsFrame then
        for i = 1, ctx.MAX_ROUNDS do
            local dot = roundDotsFrame:FindFirstChild("Dot" .. i)
            if dot then
                dot.BackgroundColor3 = Color3.fromRGB(80, 255, 120)
                dot.BackgroundTransparency = 0
            end
        end
    end

    -- Big "VICTORY!" text
    ctx.countdownLabel.Text = "VICTORY!"
    ctx.countdownLabel.TextColor3 = Color3.fromRGB(255, 220, 50)
    ctx.countdownLabel.TextTransparency = 0
    ctx.countdownLabel.TextSize = 50
    ctx.TweenService:Create(ctx.countdownLabel, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        TextSize = 120
    }):Play()

    -- Victory chimes
    ctx.SFX.PlayUI("RoundClear", ctx.camera, {Volume = 0.6, PlaybackSpeed = 0.8})
    task.delay(0.4, function() ctx.SFX.PlayUI("RoundClear", ctx.camera, {Volume = 0.5, PlaybackSpeed = 1.2}) end)

    ctx.statusLabel.Text = "ALL " .. ctx.MAX_ROUNDS .. " ROUNDS SURVIVED!"
    ctx.statusLabel.TextColor3 = Color3.fromRGB(255, 220, 80)
    ctx.infoLabel.Text = aliveCount .. " survivors | " .. ctx.formatTime(survivalTime or 0)
    ctx.infoLabel.TextColor3 = Color3.fromRGB(200, 255, 200)

    -- Gold flash
    ctx.flash.BackgroundColor3 = Color3.fromRGB(255, 220, 50)
    ctx.flash.BackgroundTransparency = 0.4
    ctx.TweenService:Create(ctx.flash, TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {BackgroundTransparency = 1}):Play()

    -- Big confetti
    confettiBurst(50, {1.0, 2.0}, {15, 35}, 90)

    -- Fade out victory text
    task.delay(2, function()
        ctx.TweenService:Create(ctx.countdownLabel, TweenInfo.new(0.8), {TextTransparency = 1}):Play()
    end)
end

return M
