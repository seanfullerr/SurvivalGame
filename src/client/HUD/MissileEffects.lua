-- HUD/MissileEffects: Guided missile lock-on reticle, screen warnings, trail sound
-- Handles MissileLockOn and MissileUpdate remote events.

local ctx -- set via init()

local missileLockedOn = false
local missileReticle = nil
local missileLockOnTarget = nil

local M = {}

function M.init(context)
    ctx = context
end

local function createLockOnReticle()
    if missileReticle then return missileReticle end
    local bb = Instance.new("BillboardGui")
    bb.Name = "MissileLockOn"
    bb.Size = UDim2.new(0, 80, 0, 80)
    bb.StudsOffset = Vector3.new(0, 4, 0)
    bb.AlwaysOnTop = true
    bb.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local center = Instance.new("Frame")
    center.Name = "Reticle"
    center.Size = UDim2.new(0.6, 0, 0.6, 0)
    center.Position = UDim2.new(0.2, 0, 0.2, 0)
    center.Rotation = 45
    center.BackgroundColor3 = Color3.fromRGB(255, 60, 30)
    center.BackgroundTransparency = 0.3
    center.BorderSizePixel = 0
    center.Parent = bb
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.15, 0)
    corner.Parent = center
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 200, 50)
    stroke.Thickness = 2
    stroke.Parent = center

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 20)
    label.Position = UDim2.new(0, 0, 1, 4)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    label.TextColor3 = Color3.fromRGB(255, 80, 30)
    label.TextStrokeTransparency = 0.5
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.Text = "LOCKED"
    label.Parent = bb

    missileReticle = bb

    task.spawn(function()
        while missileReticle and missileReticle.Parent do
            ctx.TweenService:Create(center, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
                Rotation = 45 + 90, BackgroundTransparency = 0.1,
            }):Play()
            task.wait(0.3)
            ctx.TweenService:Create(center, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
                Rotation = 45, BackgroundTransparency = 0.4,
            }):Play()
            task.wait(0.3)
        end
    end)

    return bb
end

function M.cleanup()
    missileLockedOn = false
    missileLockOnTarget = nil
    if missileReticle then missileReticle:Destroy(); missileReticle = nil end
end

-- Call with references to showMilestone and screenShake from other modules
function M.connectEvents(showMilestoneFn, screenShakeFn)
    ctx.GameEvents:WaitForChild("MissileLockOn").OnClientEvent:Connect(function(targetName, phase)
        if phase == "lockon_start" then
            missileLockOnTarget = targetName
            local isMe = (ctx.player.Name == targetName)
            local targetPlayer = ctx.Players:FindFirstChild(targetName)
            local targetChar = targetPlayer and targetPlayer.Character

            if targetChar then
                local bb = createLockOnReticle()
                bb.Adornee = targetChar:FindFirstChild("Head") or targetChar:FindFirstChild("HumanoidRootPart")
                bb.Parent = targetChar
            end
            missileLockedOn = true

            if isMe then
                ctx.flash.BackgroundColor3 = Color3.fromRGB(255, 50, 20)
                ctx.flash.BackgroundTransparency = 0.7
                ctx.TweenService:Create(ctx.flash, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 2, true),
                    {BackgroundTransparency = 0.85}):Play()
                showMilestoneFn("MISSILE INCOMING!", Color3.fromRGB(255, 80, 30))
                screenShakeFn(1.0, 0.3)
            end

        elseif phase == "lockon_cancel" or phase == "missile_exploded" then
            M.cleanup()

        elseif phase == "missile_launched" then
            if ctx.player.Name == targetName then
                showMilestoneFn("DODGE!", Color3.fromRGB(255, 200, 50))
                screenShakeFn(0.5, 0.15)
            end
        end
    end)

    ctx.GameEvents:WaitForChild("MissileUpdate").OnClientEvent:Connect(function(pos, dir)
        ctx.SFX.PlayAt("BombWhistle", pos, {
            Volume = 0.4,
            PlaybackSpeed = 1.4 + math.random() * 0.2,
        })
    end)
end

return M
