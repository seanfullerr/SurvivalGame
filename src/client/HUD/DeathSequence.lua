-- HUD/DeathSequence: Death VFX, camera pullback, death screen, compact banner
-- Handles the full PlayerDied sequence and death screen lifecycle.

local ctx -- set via init()

local M = {}

function M.init(context)
    ctx = context
end

-- Particle burst at death position (smoke + sparks)
local function deathParticles(hrp)
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
    ctx.Debris:AddItem(att, 1.5)
end

-- Camera zoom-out to look down at death spot
local function cameraPullback(deathPos)
    task.spawn(function()
        ctx.camera.CameraType = Enum.CameraType.Scriptable
        local startCF = ctx.camera.CFrame
        local pullDir = (startCF.Position - deathPos).Unit
        local targetCF = CFrame.new(deathPos + pullDir * 18 + Vector3.new(0, 12, 0), deathPos)
        local elapsed = 0
        while elapsed < 0.4 do
            local dt = ctx.RunService.RenderStepped:Wait()
            elapsed = elapsed + dt
            local alpha = math.min(elapsed / 0.4, 1)
            alpha = 1 - (1 - alpha)^3
            ctx.camera.CFrame = startCF:Lerp(targetCF, alpha)
        end
        task.wait(0.5)
    end)
end

-- Show death screen with smooth fade, then compact to banner after 2s
function M.show(cause, screenShakeFn, startSpectatingFn)
    local st = ctx.state
    st.lastDeathCause = cause or "standard"
    ctx.SFX.PlayUI("Death", ctx.camera, {Volume = 0.45})

    -- Death particles
    local char = ctx.player.Character
    local deathPos = nil
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            deathPos = hrp.Position
            deathParticles(hrp)
        end
    end

    -- White flash then dark red
    ctx.flash.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    ctx.flash.BackgroundTransparency = 0
    ctx.TweenService:Create(ctx.flash, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {BackgroundTransparency = 1, BackgroundColor3 = Color3.fromRGB(255, 40, 20)}):Play()
    screenShakeFn(4, 0.4)

    -- Camera pullback
    if deathPos then cameraPullback(deathPos) end

    -- Death screen fade
    local ds = ctx.deathScreen
    ds.Visible = true; ds.BackgroundTransparency = 1
    ctx.TweenService:Create(ds, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {BackgroundTransparency = 0.4}):Play()

    local dt = ds:FindFirstChild("Text")
    if dt then
        dt.TextTransparency = 1; dt.TextSize = 30
        ctx.TweenService:Create(dt, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            {TextTransparency = 0, TextSize = 44}):Play()
    end

    local sub = ds:FindFirstChild("Sub")
    if sub then
        local causeText = ctx.DEATH_CAUSES[st.lastDeathCause] or "Eliminated!"
        local survTime = st.survivalStart and (tick() - st.survivalStart) or 0
        sub.Text = causeText .. " | " .. ctx.formatTime(survTime) .. " alive | Round " .. st.currentRound
        sub.TextTransparency = 1
        task.delay(0.3, function()
            ctx.TweenService:Create(sub, TweenInfo.new(0.4), {TextTransparency = 0}):Play()
        end)
    end

    ctx.hpBar.Visible = false

    -- Spectate after 1.2s
    task.delay(1.2, function()
        ctx.camera.CameraType = Enum.CameraType.Custom
        startSpectatingFn()
    end)

    -- Compact banner after 2s
    task.delay(2.0, function()
        if not ds.Visible then return end
        local dtEl = ds:FindFirstChild("Text")
        local subEl = ds:FindFirstChild("Sub")
        ctx.TweenService:Create(ds, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
            Size = UDim2.new(1, 0, 0, 44),
            Position = UDim2.new(0, 0, 0, 0),
            BackgroundTransparency = 0.3,
        }):Play()
        if dtEl then
            ctx.TweenService:Create(dtEl, TweenInfo.new(0.3), {TextSize = 16}):Play()
            dtEl.Text = "YOU DIED"
        end
        if subEl then
            subEl.TextSize = 13
            st._spectatingCompact = true
        end
    end)
end

-- Reset death screen to full size (call on respawn/lobby)
function M.resetDeathScreen()
    ctx.deathScreen.Visible = false
    ctx.deathScreen.Size = UDim2.new(1, 0, 1, 0)
    ctx.deathScreen.Position = UDim2.new(0, 0, 0, 0)
    ctx.state._spectatingCompact = false
    ctx.state._specLerpTarget = nil
end

return M
