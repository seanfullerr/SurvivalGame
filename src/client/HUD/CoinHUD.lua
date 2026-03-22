-- HUD/CoinHUD: Coin display positioned left of HP bar + earn animations
-- Shows real-time coin count with flash + floating "+X" popup on earn.
-- Also handles pickup VFX for collectible map coins.

local ctx -- set via init()

local coinDisplay, coinIcon

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
        coinDisplay.Text = tostring(total)
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

    -- Map coin pickup VFX: gold particle burst at collection point
    ctx.GameEvents:WaitForChild("CoinPickup").OnClientEvent:Connect(function(pos, collectorId)
        local vfxPart = Instance.new("Part")
        vfxPart.Size = Vector3.new(1, 1, 1)
        vfxPart.Position = pos
        vfxPart.Anchored = true
        vfxPart.CanCollide = false
        vfxPart.Transparency = 1
        vfxPart.Parent = workspace

        -- Gold sparkle burst
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
        emitter.Rate = 0  -- burst only
        emitter.LightEmission = 1
        emitter.LightInfluence = 0.2
        emitter.Parent = vfxPart

        -- Emit burst
        emitter:Emit(15)

        -- Cleanup after particles fade
        ctx.Debris:AddItem(vfxPart, 1.5)
    end)
end

return M
