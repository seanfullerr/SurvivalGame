-- HUD/Spectator: Spectator camera system for dead players
-- Smooth lerp between targets, click to switch, compact banner mode.

local ctx -- set via init()

local spectating = false
local specTarget = nil
local specConn = nil
local spectateLabel = nil

local M = {}

function M.init(context)
    ctx = context

    -- Spectate indicator (bottom of screen)
    spectateLabel = Instance.new("TextLabel")
    spectateLabel.Name = "SpectateIndicator"
    spectateLabel.Size = UDim2.new(0, 300, 0, 30)
    spectateLabel.Position = UDim2.new(0.5, -150, 1, -50)
    spectateLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    spectateLabel.BackgroundTransparency = 0.5
    spectateLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    spectateLabel.TextSize = 16
    spectateLabel.Font = Enum.Font.GothamBold
    spectateLabel.Text = ""
    spectateLabel.Visible = false
    spectateLabel.ZIndex = 15
    spectateLabel.Parent = ctx.gui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = spectateLabel

    -- Click to switch target
    ctx.UIS.InputBegan:Connect(function(input, processed)
        if processed then return end
        if spectating and (input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch) then
            local candidates = {}
            for _, p in ipairs(ctx.Players:GetPlayers()) do
                if p ~= ctx.player and p ~= specTarget then
                    local char = p.Character
                    if char and char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0 then
                        table.insert(candidates, p)
                    end
                end
            end
            if #candidates > 0 then
                specTarget = candidates[math.random(#candidates)]
                ctx.state._specLerpTarget = nil -- trigger smooth lerp
                local sub = ctx.deathScreen:FindFirstChild("Sub")
                if sub then sub.Text = "Spectating " .. specTarget.DisplayName .. " | Click to switch" end
            end
        end
    end)
end

local function findAlivePlayer()
    for _, p in ipairs(ctx.Players:GetPlayers()) do
        if p ~= ctx.player then
            local char = p.Character
            if char then
                local hum = char:FindFirstChild("Humanoid")
                if hum and hum.Health > 0 then return p end
            end
        end
    end
    return nil
end

function M.start()
    local target = findAlivePlayer()
    if not target or not target.Character then return end
    spectating = true; specTarget = target

    local sub = ctx.deathScreen:FindFirstChild("Sub")
    if sub then sub.Text = "Spectating " .. target.DisplayName .. " | Click to switch" end

    if specConn then specConn:Disconnect() end
    specConn = ctx.RunService.RenderStepped:Connect(function(dt)
        if not spectating then return end
        if not specTarget or not specTarget.Character then
            local newTarget = findAlivePlayer()
            if newTarget and newTarget.Character then
                specTarget = newTarget
                ctx.state._specLerpTarget = nil
                local sub2 = ctx.deathScreen:FindFirstChild("Sub")
                if sub2 then sub2.Text = "Spectating " .. newTarget.DisplayName .. " | Click to switch" end
            else M.stop(); return end
        end

        local hrp = specTarget.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            local st = ctx.state
            if st._specLerpTarget and st._specLerpTarget ~= specTarget then
                -- Smooth lerp to new target
                st._specLerpTarget = specTarget
                ctx.camera.CameraType = Enum.CameraType.Scriptable
                local startCF = ctx.camera.CFrame
                task.spawn(function()
                    local elapsed = 0
                    local lerpTime = 0.35
                    while elapsed < lerpTime and spectating and specTarget == st._specLerpTarget do
                        local d = ctx.RunService.RenderStepped:Wait()
                        elapsed = elapsed + d
                        local alpha = math.min(elapsed / lerpTime, 1)
                        alpha = 1 - (1 - alpha)^3
                        local targetHRP = specTarget.Character and specTarget.Character:FindFirstChild("HumanoidRootPart")
                        if targetHRP then
                            local goalCF = CFrame.new(targetHRP.Position + Vector3.new(0, 8, 12), targetHRP.Position)
                            ctx.camera.CFrame = startCF:Lerp(goalCF, alpha)
                        end
                    end
                    if spectating then
                        ctx.camera.CameraType = Enum.CameraType.Custom
                        ctx.camera.CameraSubject = specTarget.Character:FindFirstChild("Humanoid")
                    end
                end)
            elseif not st._specLerpTarget then
                st._specLerpTarget = specTarget
                ctx.camera.CameraSubject = specTarget.Character:FindFirstChild("Humanoid")
            end

            -- Update spectate info with live round data
            if st._spectatingCompact then
                local sub2 = ctx.deathScreen:FindFirstChild("Sub")
                if sub2 then
                    local roundInfo = "Round " .. st.currentRound .. " / " .. ctx.MAX_ROUNDS
                    sub2.Text = "Spectating " .. specTarget.DisplayName .. " | " .. roundInfo .. " | Click to switch"
                end
            end
        end
    end)
end

function M.stop()
    local st = ctx.state
    st._spectatingCompact = false
    st._specLerpTarget = nil
    spectating = false; specTarget = nil
    spectateLabel.Visible = false
    if specConn then specConn:Disconnect(); specConn = nil end
    local char = ctx.player.Character
    if char then
        local hum = char:FindFirstChild("Humanoid")
        if hum then ctx.camera.CameraSubject = hum end
    end
end

function M.isSpectating()
    return spectating
end

return M
