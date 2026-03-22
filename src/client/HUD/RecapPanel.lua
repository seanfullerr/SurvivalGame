-- HUD/RecapPanel: End-of-game recap showing stats (rounds, time, damage, near misses)
-- Slides in with animation. Shows "NEW BEST!" title when applicable.

local ctx -- set via init()
local recapPanel = nil

local M = {}

function M.init(context)
    ctx = context
end

function M.destroy()
    if recapPanel then recapPanel:Destroy(); recapPanel = nil end
end

function M.create(roundsSurvived, survivalTime, deathCause, isNewBest)
    M.destroy()

    local panel = Instance.new("Frame")
    panel.Name = "RecapPanel"
    panel.Size = UDim2.new(0, 320, 0, 260)
    panel.Position = UDim2.new(0.5, -160, 0.5, -130)
    panel.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    panel.BackgroundTransparency = 0.15
    panel.BorderSizePixel = 0
    panel.Parent = ctx.gui
    local panelCorner = Instance.new("UICorner")
    panelCorner.CornerRadius = UDim.new(0, 12)
    panelCorner.Parent = panel
    local panelStroke = Instance.new("UIStroke")
    panelStroke.Color = Color3.fromRGB(255, 80, 40)
    panelStroke.Thickness = 2
    panelStroke.Parent = panel

    -- Title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 36)
    title.Position = UDim2.new(0, 0, 0, 8)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 22
    title.TextColor3 = isNewBest and Color3.fromRGB(255, 220, 50) or Color3.fromRGB(255, 100, 60)
    title.Text = isNewBest and "NEW BEST!" or "GAME OVER"
    title.TextStrokeTransparency = 0.5
    title.Parent = panel

    -- Stats rows
    local yPos = 50
    local function addStat(label, value, color)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -32, 0, 28)
        row.Position = UDim2.new(0, 16, 0, yPos)
        row.BackgroundTransparency = 1
        row.Parent = panel
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.6, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 16
        lbl.TextColor3 = Color3.fromRGB(180, 180, 200)
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Text = label
        lbl.Parent = row
        local val = Instance.new("TextLabel")
        val.Size = UDim2.new(0.4, 0, 1, 0)
        val.Position = UDim2.new(0.6, 0, 0, 0)
        val.BackgroundTransparency = 1
        val.Font = Enum.Font.GothamBold
        val.TextSize = 18
        val.TextColor3 = color or Color3.fromRGB(255, 255, 255)
        val.TextXAlignment = Enum.TextXAlignment.Right
        val.Text = value
        val.Parent = row
        yPos = yPos + 32
    end

    local st = ctx.state
    addStat("Rounds Survived", tostring(roundsSurvived) .. " / 7",
        roundsSurvived >= 5 and Color3.fromRGB(80, 255, 120) or Color3.fromRGB(255, 255, 255))
    addStat("Survival Time", ctx.formatTime(survivalTime or 0))
    addStat("Damage Taken", tostring(math.floor(st.totalDamageTaken)),
        st.totalDamageTaken > 60 and Color3.fromRGB(255, 100, 100) or Color3.fromRGB(255, 255, 255))
    addStat("Near Misses", tostring(st.nearMissCount),
        st.nearMissCount >= 5 and Color3.fromRGB(255, 220, 80) or Color3.fromRGB(255, 255, 255))
    addStat("Best Round", "R" .. st.bestRound, Color3.fromRGB(255, 200, 50))
    if deathCause then
        addStat("Killed By", tostring(deathCause), Color3.fromRGB(255, 80, 60))
    end

    -- Slide-in animation
    panel.Position = UDim2.new(0.5, -160, 0.5, 40)
    panel.BackgroundTransparency = 1
    ctx.TweenService:Create(panel, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, -160, 0.5, -130),
        BackgroundTransparency = 0.15,
    }):Play()
    for _, child in ipairs(panel:GetDescendants()) do
        if child:IsA("TextLabel") then
            child.TextTransparency = 1
            ctx.TweenService:Create(child, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                TextTransparency = 0,
            }):Play()
        end
    end

    recapPanel = panel
end

return M
