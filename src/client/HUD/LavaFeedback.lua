-- HUD/LavaFeedback: Lava contact VFX — steam, flash, tint, sizzle sound
-- Debounced heavy effects every 1.5s, light sizzle every tick.

local ctx -- set via init()

local M = {}

function M.init(context)
    ctx = context
end

-- Call with references to tintCharacter and screenShake from other modules
function M.connectEvents(tintCharFn, screenShakeFn)
    ctx.GameEvents:WaitForChild("LavaContact").OnClientEvent:Connect(function(isFirstContact)
        local char = ctx.player.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        -- Light sizzle every tick
        ctx.SFX.PlayUI("LavaSizzle", ctx.camera, {
            Volume = isFirstContact and 0.5 or 0.2,
            PlaybackSpeed = 1.8 + math.random() * 0.6,
        })

        -- Persistent orange vignette while on lava
        if ctx.lowHPOverlay then
            ctx.lowHPOverlay.BackgroundColor3 = Color3.fromRGB(80, 30, 0)
            ctx.lowHPOverlay.BackgroundTransparency = 0.85
        end

        -- Heavy VFX only on first contact OR every 1.5s (debounced)
        local st = ctx.state
        local now = tick()
        if isFirstContact or not st._lastLavaHeavyVFX or (now - st._lastLavaHeavyVFX) > 1.4 then
            st._lastLavaHeavyVFX = now

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
            ctx.Debris:AddItem(att, 0.8)

            -- Orange flash
            ctx.flash.BackgroundColor3 = Color3.fromRGB(255, 120, 20)
            ctx.flash.BackgroundTransparency = isFirstContact and 0.6 or 0.82
            ctx.TweenService:Create(ctx.flash, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                {BackgroundTransparency = 1}):Play()

            if isFirstContact then
                tintCharFn(char, Color3.fromRGB(255, 140, 40), 0.3)
                screenShakeFn(0.8, 0.1)
            end
        end
    end)
end

return M
