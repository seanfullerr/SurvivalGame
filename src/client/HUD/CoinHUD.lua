-- HUD/CoinHUD v2: Revamped coin display with icon, glass panel, streak indicator
-- Dark-glass theme consistent with new UI direction.
-- Shows real-time coin count with flash + floating "+X" popup on earn.
-- Streak indicator shows "Nx STREAK!" with escalating color when chaining coins.

local ctx -- set via init()
local Icons -- loaded via init()

local coinPanel, coinIconEl, coinDisplay
local streakLabel
local streakTween
local streakHideThread

local M = {}

function M.init(context)
    ctx = context
    Icons = require(script.Parent:WaitForChild("IconAssets"))
    local T = Icons.Theme

    -- Preload coin pickup sound on CLIENT so first collection is audible
    -- Use task.spawn but keep the temp Sound alive until preload completes
    task.spawn(function()
        local ContentProvider = game:GetService("ContentProvider")
        local preloadSound = Instance.new("Sound")
        preloadSound.SoundId = "rbxassetid://6895079853"
        -- Parent to SoundService so it actually downloads the asset
        preloadSound.Parent = game:GetService("SoundService")
        local ok, err = pcall(function()
            ContentProvider:PreloadAsync({preloadSound})
        end)
        if not ok then
            warn("[CoinHUD] Sound preload failed:", err)
        end
        -- Keep alive briefly to ensure Roblox caches the asset
        task.wait(0.5)
        preloadSound:Destroy()
    end)

    ---------- COIN PANEL (hidden — replaced by MenusGUI CashFrame) ----------
    -- We keep this as an invisible backing store for internal logic;
    -- the visible coin display is now the UI Kit's CashFrame in MenusGUI.
    coinPanel = Icons.createGlassPanel({
        Name = "CoinPanel",
        Size = UDim2.new(0, 120, 0, 32),
        Position = UDim2.new(0.5, -200, 1, -18),
        AnchorPoint = Vector2.new(1, 0.5),
        BG = T.PanelBG,
        Transparency = 1,
        ZIndex = 5,
        Parent = ctx.gui,
    })
    coinPanel.Visible = false

    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, 6)
    padding.PaddingRight = UDim.new(0, 8)
    padding.Parent = coinPanel

    ---------- COIN ICON (image or "$" fallback) ----------
    coinIconEl = Icons.createIcon(Icons.Coin, "$", UDim2.new(0, 22, 0, 22), coinPanel)
    coinIconEl.Position = UDim2.new(0, 0, 0.5, 0)
    coinIconEl.AnchorPoint = Vector2.new(0, 0.5)
    coinIconEl.ZIndex = 6

    ---------- COIN COUNT ----------
    coinDisplay = Instance.new("TextLabel")
    coinDisplay.Name = "CoinCount"
    coinDisplay.Size = UDim2.new(1, -28, 1, 0)
    coinDisplay.Position = UDim2.new(0, 26, 0, 0)
    coinDisplay.BackgroundTransparency = 1
    coinDisplay.Font = Enum.Font.GothamBold
    coinDisplay.TextSize = 16
    coinDisplay.TextColor3 = T.Gold
    coinDisplay.TextStrokeTransparency = 0.5
    coinDisplay.TextStrokeColor3 = Color3.fromRGB(80, 60, 0)
    coinDisplay.Text = "0"
    coinDisplay.TextXAlignment = Enum.TextXAlignment.Right
    coinDisplay.ZIndex = 6
    coinDisplay.Parent = coinPanel

    ---------- STREAK INDICATOR (hidden — old style, keep logic for events) ----------
    streakLabel = Icons.createGlassPanel({
        Name = "StreakPanel",
        Size = UDim2.new(0, 140, 0, 28),
        Position = UDim2.new(0.5, -200, 1, -50),
        AnchorPoint = Vector2.new(1, 0.5),
        BG = Color3.fromRGB(40, 25, 0),
        Transparency = 1,
        ZIndex = 6,
        Parent = ctx.gui,
    })
    streakLabel.Visible = false

    -- Streak text (child of the panel)
    local streakText = Instance.new("TextLabel")
    streakText.Name = "StreakText"
    streakText.Size = UDim2.new(1, 0, 1, 0)
    streakText.BackgroundTransparency = 1
    streakText.Font = Enum.Font.GothamBold
    streakText.TextSize = 14
    streakText.TextColor3 = T.Orange
    streakText.TextStrokeTransparency = 0.3
    streakText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    streakText.Text = ""
    streakText.TextTransparency = 1
    streakText.ZIndex = 7
    streakText.Parent = streakLabel

    ---------- MENUS GUI CASH FRAME SYNC ----------
    -- Find the CashFrame from the UI Kit's MenusGUI and keep it in sync
    local menusCashLabel = nil
    task.spawn(function()
        local pgui = ctx.player:WaitForChild("PlayerGui")
        local menusGui = pgui:WaitForChild("MenusGUI", 5)
        if menusGui then
            local gameGUI = menusGui:FindFirstChild("GameGUI")
            if gameGUI then
                local centerBottom = gameGUI:FindFirstChild("CenterBottom")
                if centerBottom then
                    local cashFrame = centerBottom:FindFirstChild("CashFrame")
                    if cashFrame then
                        menusCashLabel = cashFrame:FindFirstChildOfClass("TextLabel")
                    end
                end
            end
        end
    end)

    -- Helper to update both displays
    local function updateCoinDisplays(val)
        coinDisplay.Text = tostring(val)
        if menusCashLabel then
            menusCashLabel.Text = "$" .. tostring(val)
        end
    end

    ---------- LEADERSTATS SYNC ----------
    task.spawn(function()
        local ls = ctx.player:WaitForChild("leaderstats", 10)
        if ls then
            local coinsVal = ls:WaitForChild("Coins", 5)
            if coinsVal then
                updateCoinDisplays(coinsVal.Value)
                coinsVal.Changed:Connect(function(newVal)
                    updateCoinDisplays(newVal)
                end)
            end
        end
    end)

    ---------- COIN EARN ANIMATION ----------
    ctx.GameEvents:WaitForChild("CoinUpdate").OnClientEvent:Connect(function(amount, total, reason)
        if total then
            updateCoinDisplays(total)
        end

        -- Flash the panel brighter
        local stroke = coinPanel:FindFirstChildOfClass("UIStroke")
        if stroke then
            ctx.TweenService:Create(stroke, TweenInfo.new(0.15), {
                Color = Color3.fromRGB(255, 255, 150),
                Transparency = 0,
            }):Play()
            task.delay(0.3, function()
                ctx.TweenService:Create(stroke, TweenInfo.new(0.4), {
                    Color = Icons.Theme.GoldDim,
                    Transparency = 0.5,
                }):Play()
            end)
        end

        ctx.TweenService:Create(coinPanel, TweenInfo.new(0.15), {
            BackgroundTransparency = 0.1,
        }):Play()
        task.delay(0.3, function()
            ctx.TweenService:Create(coinPanel, TweenInfo.new(0.4), {
                BackgroundTransparency = 0.25,
            }):Play()
        end)

        -- Floating "+X" popup
        local popup = Instance.new("TextLabel")
        popup.Size = UDim2.new(0, 100, 0, 22)
        popup.Position = UDim2.new(0.5, -200, 1, -42)
        popup.AnchorPoint = Vector2.new(1, 0.5)
        popup.BackgroundTransparency = 1
        popup.Font = Enum.Font.GothamBold
        popup.TextSize = 15
        popup.TextColor3 = Icons.Theme.Gold
        popup.TextStrokeTransparency = 0.4
        popup.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        popup.Text = "+" .. amount
        popup.TextXAlignment = Enum.TextXAlignment.Right
        popup.ZIndex = 7
        popup.Parent = ctx.gui
        ctx.TweenService:Create(popup, TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = UDim2.new(0.5, -200, 1, -70),
            TextTransparency = 1,
            TextStrokeTransparency = 1,
        }):Play()
        ctx.Debris:AddItem(popup, 1.2)
    end)

    ---------- STREAK EVENT HANDLER ----------
    ctx.GameEvents:WaitForChild("CoinStreak").OnClientEvent:Connect(function(streakCount, multiplier)
        local streakColors = {
            [2] = Color3.fromRGB(255, 220, 80),
            [3] = Color3.fromRGB(255, 180, 50),
            [4] = Color3.fromRGB(255, 140, 40),
            [5] = Color3.fromRGB(255, 100, 30),
        }
        local bgColors = {
            [2] = Color3.fromRGB(40, 25, 0),
            [3] = Color3.fromRGB(50, 25, 0),
            [4] = Color3.fromRGB(60, 20, 0),
            [5] = Color3.fromRGB(70, 15, 0),
        }
        local textColor = streakColors[math.min(streakCount, 5)] or streakColors[5]
        local bgColor = bgColors[math.min(streakCount, 5)] or bgColors[5]

        local sText = streakLabel:FindFirstChild("StreakText")
        if sText then
            sText.Text = streakCount .. "x STREAK!"
            sText.TextColor3 = textColor
        end
        streakLabel.BackgroundColor3 = bgColor

        -- Cancel pending hide
        if streakHideThread then
            task.cancel(streakHideThread)
            streakHideThread = nil
        end

        -- Pop-in animation
        if sText then
            sText.TextSize = 10
            sText.TextTransparency = 0
            ctx.TweenService:Create(sText, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                TextSize = 14 + math.min(streakCount - 2, 3) * 2,
            }):Play()
        end
        ctx.TweenService:Create(streakLabel, TweenInfo.new(0.15), {
            BackgroundTransparency = 0.3,
        }):Play()
        local streakStroke = streakLabel:FindFirstChildOfClass("UIStroke")
        if streakStroke then
            ctx.TweenService:Create(streakStroke, TweenInfo.new(0.15), {
                Transparency = 0.4,
                Color = textColor,
            }):Play()
        end

        -- Play streak sound
        ctx.SFX.PlayUI("StreakUp", ctx.camera, {
            Volume = 0.3 + math.min(streakCount - 2, 3) * 0.05,
            PlaybackSpeed = 0.9 + math.min(streakCount - 2, 3) * 0.1,
        })

        -- Auto-hide after timeout
        streakHideThread = task.delay(3.0, function()
            if streakLabel then
                local st = streakLabel:FindFirstChild("StreakText")
                if st then
                    ctx.TweenService:Create(st, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
                end
                ctx.TweenService:Create(streakLabel, TweenInfo.new(0.5), {
                    BackgroundTransparency = 1,
                }):Play()
                local ss = streakLabel:FindFirstChildOfClass("UIStroke")
                if ss then
                    ctx.TweenService:Create(ss, TweenInfo.new(0.5), { Transparency = 1 }):Play()
                end
            end
            streakHideThread = nil
        end)
    end)

    ---------- MAP COIN PICKUP VFX ----------
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
