-- HUD/CameraEffects: Screen shake, camera punch, knockback tilt
-- Lightweight camera manipulation for impact feedback.

local ctx -- set via init()

local M = {}

function M.init(context)
    ctx = context
end

-- Continuous random shake that decays over duration
function M.screenShake(intensity, duration)
    task.spawn(function()
        local elapsed = 0
        while elapsed < duration do
            local decay = 1 - (elapsed / duration)
            local dt = ctx.RunService.RenderStepped:Wait()
            ctx.camera.CFrame = ctx.camera.CFrame * CFrame.new(
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

-- Sharp downward hit then spring back (impact feel)
function M.cameraPunch(intensity)
    task.spawn(function()
        local orig = ctx.camera.CFrame
        ctx.camera.CFrame = orig * CFrame.new(0, -intensity * 0.8, 0)
        ctx.RunService.RenderStepped:Wait()
        ctx.RunService.RenderStepped:Wait()
        ctx.camera.CFrame = orig * CFrame.new(0, intensity * 0.2, 0)
        ctx.RunService.RenderStepped:Wait()
        ctx.camera.CFrame = orig * CFrame.new(0, -intensity * 0.1, 0)
        ctx.RunService.RenderStepped:Wait()
        ctx.camera.CFrame = orig
    end)
end

-- Tilt camera away from explosion direction
function M.knockbackTilt(explosionPos)
    local char = ctx.player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local dir = (hrp.Position - explosionPos).Unit
    local camCF = ctx.camera.CFrame
    local localDir = camCF:VectorToObjectSpace(dir)
    local tiltX = localDir.Z * 3
    local tiltZ = -localDir.X * 3
    task.spawn(function()
        ctx.camera.CFrame = ctx.camera.CFrame * CFrame.Angles(math.rad(tiltX), 0, math.rad(tiltZ))
        task.wait(0.1)
    end)
end

return M
