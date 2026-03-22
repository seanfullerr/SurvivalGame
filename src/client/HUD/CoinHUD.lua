-- HUD/CoinHUD: Coin display positioned left of HP bar + earn animations + streak indicator
-- Shows real-time coin count with flash + floating "+X" popup on earn.
-- Streak indicator shows "Nx STREAK!" with escalating color when chaining coins.

local ctx -- set via init()

local coinDisplay, coinIcon
local streakLabel  -- shows "2x STREAK!" etc.
local streakTween  -- current streak fade tween
local streakHideThread  -- delayed hide thread

local M = {}

function M.init(context)
    ctx = context

    -- Coin display label (bottom-center, left of HP bar)
    coinDisplay = Instance.new("TextLabel")
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
    coinDisplay.Parent = ctx.gui

    local coinCorner = Instance.new("UICorner")
    coinCorner.CornerRadius = UDim.new(0, 6)
    coinCorner.Parent = coinDisplay
    local coinPadding = Instance.new("UIPadding")
    coinPadding.PaddingRight = UDim.new(0, 8)
    coinPadding.PaddingLeft = UDim.new(0, 24)
    coinPadding.Parent = coinDisplay

    -- "$" icon on left side
    coinIcon = Instance.new("TextLabel")
    coinIcon.Size = UDim2.new(0, 22, 1, 0)
    coinIcon.Position = UDim2.new(0, 0, 0, 0)
    coinIcon.BackgroundTransparency = 1
    coinIcon.Font = Enum.Font.GothamBold
    coinIcon.TextSize = 16
    coinIcon.TextColor3 = Color3.fromRGB(255, 200, 50)
    coinIcon.Text = "$"
    coinIcon.ZIndex = 6
    coinIcon.Parent = coinDisplay

    ---------- STREAK INDICATOR ----------
    streakLabel = Instance.new("TextLabel")
    streakLabel.Name = "StreakLabel"
    streakLabel.Size = UDim2.new(0, 160, 0, 28)
    streakLabel.Position = UDim2.new(0.5, -195, 1, -48)
    streakLabel.AnchorPoint = Vector2.new(1, 0.5)
    streakLabel.BackgroundColor3 = Color3.fromRGB(40, 25, 0)
    streakLabel.BackgroundTransparency = 0.4
    streakLabel.BorderSizePixel = 0
    streakLabel.Font = Enum.Font.GothamBold
    streakLabel.TextSize = 14
    streakLabel.TextColor3 = Color3.fromRGB(255, 200, 80)
    streakLabel.TextStrokeTransparency = 0.3
    streakLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    streakLabel.Text = ""
    streakLabel.TextXAlignment = Enum.TextXAlignment.Center
    streakLabel.TextTransparency = 1
    streakLabel.BackgroundTransparency = 1
    streakLabel.ZIndex = 6
    streakLabel.Parent = ctx.gui

    local streakCorner = Instance.new("UICorner")
    streakCorner.CornerRadius = UDim.new(0, 6)
    streakCorner.Parent = streakLabel

    -- Initialize from leaderstats
    task.spawn(function()
        local ls = ctx.player:WaitForChild("leaderstats", 10)
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
    ctx.GameEvents:WaitForChild("CoinUpdate").OnClientEvent:Connect(function(amount, total, reason)
        if total then
            coinDisplay.Text = tostring(total)
        end
        -- Flash gold
        ctx.TweenService:Create(coinDisplay, TweenInfo.new(0.15), {
            TextColor3 = Color3.fromRGB(255, 255, 150),
            BackgroundTransparency = 0.15,
        }):Play()
        task.delay(0.3, function()
            ctx.TweenService:Create(coinDisplay, TweenInfo.new(0.4), {
                TextColor3 = Color3.fromRGB(255, 220, 50),
                BackgroundTransparency = 0.5,
            }):Play()
        end)
        -- Floating "+X" popup
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
        popup.Parent = ctx.gui
        ctx.TweenService:Create(popup, TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = UDim2.new(0.5, -195, 1, -65),
            TextTransparency = 1,
            TextStrokeTransparency = 1,
        }):Play()
        ctx.Debris:AddItem(popup, 1.2)
    end)

    ---------- STREAK EVENT HANDLER ----------
    ctx.GameEvents:WaitForChild("CoinStreak").OnClientEvent:Connect(function(streakCount, multiplier)
        -- Color escalates with streak: gold -> orange -> red-orange -> bright red
        local streakColors = {
            [2] = Color3.fromRGB(255, 220, 80),   -- warm gold
            [3] = Color3.fromRGB(255, 180, 50),   -- orange-gold
            [4] = Color3.fromRGB(255, 140, 40),   -- orange
            [5] = Color3.fromRGB(255, 100, 30),   -- red-orange (max)
        }
        local bgColors = {
            [2] = Color3.fromRGB(40, 25, 0),
            [3] = Color3.fromRGB(50, 25, 0),
            [4] = Color3.fromRGB(60, 20, 0),
            [5] = Color3.fromRGB(70, 15, 0),
        }
        local textColor = streakColors[math.min(streakCount, 5)] or streakColors[5]
        local bgColor = bgColors[math.min(streakCount, 5)] or bgColors[5]

        streakLabel.Text = streakCount .. "x STREAK!"
        streakLabel.TextColor3 = textColor
        streakLabel.BackgroundColor3 = bgColor

        -- Cancel any pending hide
        if streakHideThread then
            task.cancel(streakHideThread)
            streakHideThread = nil
        end

        -- Pop-in animation
        streakLabel.TextSize = 10
        streakLabel.TextTransparency = 0
        streakLabel.BackgroundTransparency = 0.4
        ctx.TweenService:Create(streakLabel, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            TextSize = 16 + math.min(streakCount - 2, 3) * 2,
        }):Play()

        -- Play streak sound
        ctx.SFX.PlayUI("StreakUp", ctx.camera, {
            Volume = 0.3 + math.min(streakCount - 2, 3) * 0.05,
            PlaybackSpeed = 0.9 + math.min(streakCount - 2, 3) * 0.1,
        })

        -- Auto-hide after streak timeout + small buffer
        streakHideThread = task.delay(3.0, function()
            if streakLabel then
                ctx.TweenService:Create(streakLabel, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                    TextTransparency = 1,
                    BackgroundTransparency = 1,
                }):Play()
            end
            streakHideThread = nil
        end)
    end)

    -- Map coin pickup VFX: gold particle burst at collection point
    ctx.GameEvents:WaitForChild("CoinPickup").OnClientEvent:Connect(function(pos, collectorId)
        local vfxPart = Instance.new("Part")
        vfxPart.Size = Vector3.new(1, 1, 1)
        vfxPart.Position = pos
        vfxPart.Anchored = true
        vfxPart.CanCollide = false
        vfxPart.Transparency = 1
        vfxPart.Parent = workspace

        local emitter = Instance.new("ParticleEmitter")
        emitter.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 220, 50)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 180, 30)),
        })
        emitter.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1.0),
            NumberSequenceKeypoint.new(1, 0),
        })
        emitter.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(0.7, 0.3),
            NumberSequenceKeypoint.new(1, 1),
        })
        emitter.Lifetime = NumberRange.new(0.4, 0.8)
        emitter.Speed = NumberRange.new(8, 16)
        emitter.SpreadAngle = Vector2.new(360, 360)
        emitter.Rate = 0
        emitter.LightEmission = 1
        emitter.LightInfluence = 0.2
        emitter.Parent = vfxPart

        emitter:Emit(15)
        ctx.Debris:AddItem(vfxPart, 1.5)
    end)
end

return M
