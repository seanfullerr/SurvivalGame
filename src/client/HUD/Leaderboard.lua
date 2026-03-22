-- HUD/Leaderboard: In-game leaderboard display + fallback polling
-- Updates from server LeaderboardUpdate event; polls every 3s as fallback.

local ctx -- set via init()

local M = {}

function M.init(context)
    ctx = context

    ctx.GameEvents.LeaderboardUpdate.OnClientEvent:Connect(function(data)
        ctx.state.lastServerLB = tick()
        M.update(data)
    end)

    -- Fallback polling when server hasn't sent updates recently
    task.spawn(function()
        while true do
            task.wait(3)
            if tick() - ctx.state.lastServerLB > 5 then
                local data = {}
                for _, p in ipairs(ctx.Players:GetPlayers()) do
                    local char = p.Character
                    local hum = char and char:FindFirstChild("Humanoid")
                    table.insert(data, {
                        name = p.DisplayName,
                        alive = hum and hum.Health > 0 or false,
                        rounds = 0, time = 0,
                    })
                end
                M.update(data)
            end
        end
    end)
end

function M.update(data)
    for _, c in ipairs(ctx.lbEntries:GetChildren()) do
        if c:IsA("TextLabel") then c:Destroy() end
    end
    table.sort(data, function(a, b)
        if a.alive ~= b.alive then return a.alive end
        if a.rounds ~= b.rounds then return a.rounds > b.rounds end
        return a.time > b.time
    end)
    for i, entry in ipairs(data) do
        if i > 8 then break end
        local label = Instance.new("TextLabel")
        label.Name = "E" .. i
        label.Size = UDim2.new(1, 0, 0, 24)
        label.BackgroundColor3 = entry.alive and Color3.fromRGB(40, 60, 40) or Color3.fromRGB(50, 35, 35)
        label.BackgroundTransparency = 0.5
        label.LayoutOrder = i
        label.Font = Enum.Font.GothamBold
        label.TextSize = 12
        label.TextXAlignment = Enum.TextXAlignment.Left
        local roundText = entry.rounds > 0 and ("  R" .. entry.rounds) or ""
        local timeText = entry.time > 0 and (" " .. ctx.formatTime(entry.time)) or ""
        label.Text = "  " .. i .. ". " .. entry.name .. roundText .. timeText
        label.TextColor3 = entry.alive and Color3.fromRGB(100, 255, 120) or Color3.fromRGB(150, 80, 80)
        label.Parent = ctx.lbEntries
    end
end

return M
