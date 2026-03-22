-- HUD/DamageFeedback v2: Hit VFX, character tinting, directional indicators,
-- near miss popup, heal feedback, floating damage numbers, HP bar management.
-- Revamped with IconAssets theming — heart icon on HP bar, improved near-miss.

local ctx -- set via init()
local Icons -- loaded via init()

local hpConn = nil
local moveConns = {}
local velConn = nil
local lastYVel = 0
local killFeedLabels = {}

-- Version counter for tint fade-back
local tintVersion = 0

local M = {}

function M.init(context)
    ctx = context
    Icons = require(script.Parent:WaitForChild("IconAssets"))
    local T = Icons.Theme

    -- Enhance the existing HP bar with a heart icon and glass styling
    task.defer(function()
        if ctx.hpBar then
            -- Glass-ify the HP bar background
            local existingCorner = ctx.hpBar:FindFirstChildOfClass("UICorner")
            if not existingCorner then
                local corner = Instance.new("UICorner")
                corner.CornerRadius = UDim.new(0, 8)
                corner.Parent = ctx.hpBar
            end

            -- Add subtle stroke
            if not ctx.hpBar:FindFirstChildOfClass("UIStroke") then
                local stroke = Instance.new("UIStroke")
                stroke.Color = T.StrokeDefault
                stroke.Thickness = 1
                stroke.Transparency = 0.4
                stroke.Parent = ctx.hpBar
            end

            -- Add heart icon left of HP bar
            local heartIcon = ctx.hpBar:FindFirstChild("HeartIcon")
            if not heartIcon then
                heartIcon = Icons.createIcon(Icons.Heart, "♥", UDim2.new(0, 20, 0, 20), ctx.hpBar)
                heartIcon.Name = "HeartIcon"
                heartIcon.Position = UDim2.new(0, -26, 0.5, 0)
                heartIcon.AnchorPoint = Vector2.new(0, 0.5)
                heartIcon.ZIndex = (ctx.hpBar.ZIndex or 5) + 1
                if heartIcon:IsA("TextLabel") then
                    heartIcon.TextSize = 18
                    heartIcon.TextColor3 = T.Red
                end
            end
        end
    end)
end

---------- CHARACTER TINTING ----------

function M.resetCharTint(char)
    if not char then return end
    tintVersion = tintVersion + 1
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            local origColor = ctx.charOrigColors[part]
            if origColor and part.Parent then
                part.Color = origColor
            end
        end
    end
end

function M.tintCharacter(char, color, intensity)
    if not char then return end
    if not next(ctx.charOrigColors) then ctx.captureOrigColors(char) end
    tintVersion = tintVersion + 1
    local myVersion = tintVersion
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            part.Color = color
        end
    end
    task.delay(0.3, function()
        if tintVersion ~= myVersion then return end
        if not char or not char.Parent then return end
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                local origColor = ctx.charOrigColors[part]
                if origColor and part.Parent then
                    ctx.TweenService:Create(part,
                        TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                        {Color = origColor}):Play()
                end
            end
        end
    end)
end

function M.hitParticles(char, intensity)
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
    sparks:Emit(math.floor(12*intensity)); ctx.Debris:AddItem(att, 1)
end

---------- DIRECTIONAL DAMAGE INDICATORS ----------

function M.showDirectionalDamage(explosionPos)
    local char = ctx.player.Character; if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    local dir = (explosionPos - hrp.Position)
    local camCF = ctx.camera.CFrame
    local localDir = camCF:VectorToObjectSpace(dir)
    local absX, absZ = math.abs(localDir.X), math.abs(localDir.Z)
    local side = absX > absZ and (localDir.X > 0 and "Right" or "Left") or (localDir.Z < 0 and "Top" or "Bottom")
    local ind = ctx.gui:FindFirstChild("DmgInd_" .. side)
    if ind then
        ind.BackgroundTransparency = 0.3
        ctx.TweenService:Create(ind, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {BackgroundTransparency = 1}):Play()
    end
end

function M.showDirectionalNearMiss(explosionPos)
    local char = ctx.player.Character; if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    local dir = (explosionPos - hrp.Position)
    local camCF = ctx.camera.CFrame
    local localDir = camCF:VectorToObjectSpace(dir)
    local absX, absZ = math.abs(localDir.X), math.abs(localDir.Z)
    local side = absX > absZ and (localDir.X > 0 and "Right" or "Left") or (localDir.Z < 0 and "Top" or "Bottom")
    local ind = ctx.gui:FindFirstChild("DmgInd_" .. side)
    if ind then
        local origColor = ind.BackgroundColor3
        ind.BackgroundColor3 = Color3.fromRGB(255, 230, 50)
        ind.BackgroundTransparency = 0.4
        ctx.TweenService:Create(ind, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {BackgroundTransparency = 1}):Play()
        task.delay(0.5, function() ind.BackgroundColor3 = origColor end)
    end
end

---------- NEAR MISS (revamped with icon) ----------

local nearMissTexts = {"CLOSE CALL!", "TOO CLOSE!", "WHEW!", "BARELY!"}

function M.showNearMiss()
    local T = Icons.Theme
    local label = ctx.nearMissLabel
    label.Text = nearMissTexts[math.random(#nearMissTexts)]
    label.TextColor3 = T.Gold
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.TextStrokeTransparency = 0.2
    label.TextTransparency = 0; label.TextSize = 20
    label.Position = UDim2.new(0.5, 0, 0.45, 0)
    ctx.TweenService:Create(label, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {TextSize = 36}):Play()
    ctx.flash.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    ctx.flash.BackgroundTransparency = 0.92
    ctx.TweenService:Create(ctx.flash, TweenInfo.new(0.15), {BackgroundTransparency = 1}):Play()
    task.delay(0.8, function()
        ctx.TweenService:Create(label, TweenInfo.new(0.4), {TextTransparency = 1}):Play()
    end)
end

---------- HEAL FEEDBACK ----------

function M.showHealFeedback(healAmt)
    local T = Icons.Theme
    ctx.flash.BackgroundColor3 = Color3.fromRGB(80, 255, 80)
    ctx.flash.BackgroundTransparency = 0.85
    ctx.TweenService:Create(ctx.flash, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {BackgroundTransparency = 1}):Play()

    local healLabel = Instance.new("TextLabel")
    healLabel.Size = UDim2.new(0, 100, 0, 30)
    healLabel.Position = UDim2.new(0.5, 0, 1, -50)
    healLabel.AnchorPoint = Vector2.new(0.5, 1)
    healLabel.BackgroundTransparency = 1
    healLabel.Font = Enum.Font.GothamBold; healLabel.TextSize = 20
    healLabel.TextColor3 = T.Green
    healLabel.TextStrokeTransparency = 0.3
    healLabel.Text = "+" .. healAmt .. " HP"
    healLabel.ZIndex = 6; healLabel.Parent = ctx.gui
    ctx.TweenService:Create(healLabel, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Position = UDim2.new(0.5, 0, 1, -110), TextTransparency = 1, TextStrokeTransparency = 1}):Play()
    ctx.Debris:AddItem(healLabel, 1.2)

    -- Pulse the heart icon green
    if ctx.hpBar then
        local heartIcon = ctx.hpBar:FindFirstChild("HeartIcon")
        if heartIcon and heartIcon:IsA("TextLabel") then
            heartIcon.TextColor3 = T.Green
            ctx.TweenService:Create(heartIcon, TweenInfo.new(0.6), {
                TextColor3 = Icons.Theme.Red,
            }):Play()
        elseif heartIcon and heartIcon:IsA("ImageLabel") then
            heartIcon.ImageColor3 = Color3.fromRGB(80, 255, 80)
            ctx.TweenService:Create(heartIcon, TweenInfo.new(0.6), {
                ImageColor3 = Color3.new(1, 1, 1),
            }):Play()
        end
    end
end

---------- FLOATING DAMAGE NUMBERS ----------

function M.showFloatingDamage(dmg)
    local char = ctx.player.Character; if not char then return end
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
    local startOffset = bb.StudsOffset
    ctx.TweenService:Create(bb, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        StudsOffset = startOffset + Vector3.new(0, 3, 0)
    }):Play()
    ctx.TweenService:Create(lbl, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        TextTransparency = 1, TextStrokeTransparency = 1
    }):Play()
    task.delay(0.3, function()
        ctx.TweenService:Create(lbl, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            TextSize = lbl.TextSize * 1.3
        }):Play()
        task.delay(0.15, function()
            ctx.TweenService:Create(lbl, TweenInfo.new(0.1), {TextSize = lbl.TextSize / 1.3}):Play()
        end)
    end)
    ctx.Debris:AddItem(bb, 1.3)
end

---------- HP BAR ----------

function M.updateHPBar()
    local char = ctx.player.Character; if not char then return end
    local hum = char:FindFirstChild("Humanoid"); if not hum then return end
    local hp = math.max(0, hum.Health); local maxHP = hum.MaxHealth; local pct = hp / maxHP
    local T = Icons.Theme

    ctx.TweenService:Create(ctx.hpFill, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.new(math.max(0.001, pct) * (1 - 6/320), 0, 1, -4),
        BackgroundColor3 = pct > 0.5 and T.Green
            or pct > 0.25 and T.Orange
            or T.Red
    }):Play()
    ctx.hpText.Text = math.floor(hp) .. " / " .. math.floor(maxHP)
    ctx.hpBar.Visible = (hp > 0)

    -- Pulse heart icon red at low HP
    if ctx.hpBar then
        local heartIcon = ctx.hpBar:FindFirstChild("HeartIcon")
        if heartIcon and pct <= 0.25 and pct > 0 then
            if heartIcon:IsA("TextLabel") then
                ctx.TweenService:Create(heartIcon, TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 2, true), {
                    TextColor3 = Color3.fromRGB(255, 0, 0),
                }):Play()
            end
        end
    end

    if pct <= 0.25 and pct > 0 then
        ctx.TweenService:Create(ctx.hpFill, TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 2, true),
            {BackgroundColor3 = Color3.fromRGB(255, 0, 0)}):Play()
    end
    if ctx.lowHPOverlay then
        local t = pct <= 0.3 and math.clamp(0.7 + pct, 0.7, 0.92) or 1
        ctx.TweenService:Create(ctx.lowHPOverlay, TweenInfo.new(0.4), {BackgroundTransparency = t}):Play()
    end
end

function M.punchHPBar()
    local orig = ctx.hpBar.Size
    ctx.hpBar.Size = UDim2.new(orig.X.Scale * 1.08, orig.X.Offset, orig.Y.Scale * 1.15, orig.Y.Offset)
    ctx.TweenService:Create(ctx.hpBar, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = orig
    }):Play()
end

function M.connectHPBar(char)
    if not char then return end
    if hpConn then hpConn:Disconnect(); hpConn = nil end
    local hum = char:WaitForChild("Humanoid", 5)
    if hum then hpConn = hum:GetPropertyChangedSignal("Health"):Connect(M.updateHPBar); M.updateHPBar() end
end

---------- LANDING IMPACT + MOVEMENT FEEDBACK ----------

function M.connectMovementFeedback(char, screenShakeFn)
    for _, c in ipairs(moveConns) do c:Disconnect() end
    moveConns = {}
    if velConn then velConn:Disconnect(); velConn = nil end
    local hum = char:WaitForChild("Humanoid", 5)
    local hrp = char:WaitForChild("HumanoidRootPart", 5)
    if not hum or not hrp then return end

    table.insert(moveConns, hum.StateChanged:Connect(function(_, newState)
        if newState == Enum.HumanoidStateType.Landed then
            local impact = math.abs(lastYVel)
            if impact > 35 then
                local heavyI = math.clamp(impact / 80, 0.3, 1.5)
                screenShakeFn(heavyI * 0.5, 0.1)
            end
        end
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
            ctx.Debris:AddItem(att, 0.4)
        end
    end))

    velConn = ctx.RunService.Heartbeat:Connect(function()
        if hrp and hrp.Parent then lastYVel = hrp.AssemblyLinearVelocity.Y end
    end)
end

---------- LAST SURVIVOR ----------

function M.showLastSurvivor(showMilestoneFn)
    showMilestoneFn("LAST ONE STANDING!", Color3.fromRGB(255, 220, 50))
    ctx.flash.BackgroundColor3 = Color3.fromRGB(255, 220, 50)
    ctx.flash.BackgroundTransparency = 0.8
    ctx.TweenService:Create(ctx.flash, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
end

---------- KILL FEED (revamped with glass panels) ----------

function M.showKillFeed(playerName, cause)
    local T = Icons.Theme
    local causeText = ctx.DEATH_CAUSES[cause] or "was eliminated"
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
    label.Size = UDim2.new(0, 270, 0, 24)
    label.Position = UDim2.new(0, 14, 0.65, #killFeedLabels * 28)
    label.BackgroundTransparency = 0.6
    label.BackgroundColor3 = T.PanelBG
    label.Font = Enum.Font.GothamBold; label.TextSize = 11
    label.TextColor3 = killColor
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextStrokeTransparency = 0.5
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.Text = "  " .. playerName .. " " .. causeText:lower()
    label.TextTransparency = 1; label.ZIndex = 7; label.Parent = ctx.gui
    ctx.TweenService:Create(label, TweenInfo.new(0.25), {TextTransparency = 0}):Play()
    table.insert(killFeedLabels, label)

    local kfCorner = Instance.new("UICorner")
    kfCorner.CornerRadius = UDim.new(0, 5)
    kfCorner.Parent = label

    task.delay(6, function()
        ctx.TweenService:Create(label, TweenInfo.new(0.5), {TextTransparency = 1, BackgroundTransparency = 1}):Play()
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

return M
