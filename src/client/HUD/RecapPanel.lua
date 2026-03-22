-- HUD/RecapPanel v2: End-of-game recap with icons, glass morphism, staggered reveals
-- Dark-glass panel with icon-decorated stat rows. "NEW BEST!" crown treatment.
-- Slides in with spring animation; each row fades in with slight delay.

local ctx -- set via init()
local Icons -- loaded via init()
local recapPanel = nil

local M = {}

function M.init(context)
    ctx = context
    Icons = require(script.Parent:WaitForChild("IconAssets"))
end

function M.destroy()
    if recapPanel then recapPanel:Destroy(); recapPanel = nil end
end

function M.create(roundsSurvived, survivalTime, deathCause, isNewBest)
    M.destroy()

    local T = Icons.Theme

    ---------- MAIN PANEL ----------
    local panel = Icons.createGlassPanel({
        Name = "RecapPanel",
        Size = UDim2.new(0, 340, 0, 290),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BG = T.PanelBG,
        Transparency = 0.12,
        Stroke = true,
        StrokeColor = isNewBest and T.StrokeAccent or T.StrokeRed,
        StrokeThickness = 2,
        StrokeTransparency = 0.1,
        CornerRadius = 14,
        ZIndex = 10,
        Parent = ctx.gui,
    })

    -- Inner padding
    local mainPad = Instance.new("UIPadding")
    mainPad.PaddingLeft = UDim.new(0, 16)
    mainPad.PaddingRight = UDim.new(0, 16)
    mainPad.PaddingTop = UDim.new(0, 12)
    mainPad.Parent = panel

    ---------- TITLE ROW (icon + text) ----------
    local titleFrame = Instance.new("Frame")
    titleFrame.Name = "TitleRow"
    titleFrame.Size = UDim2.new(1, 0, 0, 36)
    titleFrame.BackgroundTransparency = 1
    titleFrame.ZIndex = 11
    titleFrame.Parent = panel

    -- Title icon (crown for best, skull for game over)
    local titleIconId = isNewBest and Icons.Crown or Icons.Skull
    local titleFallback = isNewBest and "★" or "☠"
    local titleIcon = Icons.createIcon(titleIconId, titleFallback, UDim2.new(0, 28, 0, 28), titleFrame)
    titleIcon.Position = UDim2.new(0, 0, 0.5, 0)
    titleIcon.AnchorPoint = Vector2.new(0, 0.5)
    titleIcon.ZIndex = 12
    if titleIcon:IsA("TextLabel") then
        titleIcon.TextSize = 22
        titleIcon.TextColor3 = isNewBest and T.Gold or T.Red
    end

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -36, 1, 0)
    title.Position = UDim2.new(0, 34, 0, 0)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 22
    title.TextColor3 = isNewBest and T.Gold or T.Red
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = isNewBest and "NEW BEST!" or "GAME OVER"
    title.TextStrokeTransparency = 0.5
    title.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    title.ZIndex = 12
    title.Parent = titleFrame

    ---------- DIVIDER ----------
    local divider = Instance.new("Frame")
    divider.Name = "Divider"
    divider.Size = UDim2.new(1, 0, 0, 1)
    divider.Position = UDim2.new(0, 0, 0, 42)
    divider.BackgroundColor3 = T.StrokeDefault
    divider.BackgroundTransparency = 0.5
    divider.BorderSizePixel = 0
    divider.ZIndex = 11
    divider.Parent = panel

    ---------- STAT ROWS ----------
    local yPos = 52
    local rowElements = {} -- for staggered reveal

    local function addStatRow(iconAsset, iconFallback, label, value, color, iconColor)
        local row = Instance.new("Frame")
        row.Name = "StatRow"
        row.Size = UDim2.new(1, 0, 0, 30)
        row.Position = UDim2.new(0, 0, 0, yPos)
        row.BackgroundTransparency = 1
        row.ZIndex = 11
        row.Parent = panel

        -- Row icon
        local rowIcon = Icons.createIcon(iconAsset, iconFallback, UDim2.new(0, 18, 0, 18), row)
        rowIcon.Position = UDim2.new(0, 0, 0.5, 0)
        rowIcon.AnchorPoint = Vector2.new(0, 0.5)
        rowIcon.ZIndex = 12
        if rowIcon:IsA("TextLabel") then
            rowIcon.TextSize = 14
            rowIcon.TextColor3 = iconColor or T.WhiteDim
        end
        if rowIcon:IsA("ImageLabel") then
            rowIcon.ImageColor3 = iconColor or Color3.new(1, 1, 1)
        end

        -- Label
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.55, -24, 1, 0)
        lbl.Position = UDim2.new(0, 24, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 15
        lbl.TextColor3 = T.TextSecondary
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Text = label
        lbl.ZIndex = 12
        lbl.Parent = row

        -- Value
        local val = Instance.new("TextLabel")
        val.Size = UDim2.new(0.45, 0, 1, 0)
        val.Position = UDim2.new(0.55, 0, 0, 0)
        val.BackgroundTransparency = 1
        val.Font = Enum.Font.GothamBold
        val.TextSize = 17
        val.TextColor3 = color or T.TextPrimary
        val.TextXAlignment = Enum.TextXAlignment.Right
        val.Text = value
        val.ZIndex = 12
        val.Parent = row

        -- Mark all text for stagger
        table.insert(rowElements, {row = row, texts = {lbl, val, rowIcon}})
        yPos = yPos + 34
    end

    local st = ctx.state

    addStatRow(Icons.Star, "★", "Rounds Survived",
        tostring(roundsSurvived) .. " / 7",
        roundsSurvived >= 5 and T.Green or T.TextPrimary,
        T.Gold)

    addStatRow(Icons.Clock, "⏱", "Survival Time",
        ctx.formatTime(survivalTime or 0),
        T.Blue,
        T.Blue)

    addStatRow(Icons.Heart, "♥", "Damage Taken",
        tostring(math.floor(st.totalDamageTaken)),
        st.totalDamageTaken > 60 and T.Red or T.TextPrimary,
        T.Red)

    addStatRow(Icons.Warning, "!", "Near Misses",
        tostring(st.nearMissCount),
        st.nearMissCount >= 5 and T.Gold or T.TextPrimary,
        T.Orange)

    addStatRow(Icons.Trophy, "🏆", "Best Round",
        "R" .. st.bestRound,
        T.Gold,
        T.Gold)

    if deathCause then
        addStatRow(Icons.Bomb, "💣", "Killed By",
            tostring(deathCause),
            T.RedSoft,
            T.Red)
    end

    ---------- SLIDE-IN ANIMATION ----------
    -- Start below center + transparent
    panel.Position = UDim2.new(0.5, 0, 0.5, 50)
    panel.BackgroundTransparency = 1
    local panelStroke = panel:FindFirstChildOfClass("UIStroke")
    if panelStroke then panelStroke.Transparency = 1 end

    ctx.TweenService:Create(panel, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, 0, 0.5, 0),
        BackgroundTransparency = 0.12,
    }):Play()
    if panelStroke then
        task.delay(0.1, function()
            ctx.TweenService:Create(panelStroke, TweenInfo.new(0.3), { Transparency = 0.1 }):Play()
        end)
    end

    ---------- STAGGERED ROW REVEAL ----------
    -- Title fades in immediately
    for _, child in ipairs(titleFrame:GetDescendants()) do
        if child:IsA("TextLabel") then
            child.TextTransparency = 1
            ctx.TweenService:Create(child, TweenInfo.new(0.4), { TextTransparency = 0 }):Play()
        end
        if child:IsA("ImageLabel") then
            child.ImageTransparency = 1
            ctx.TweenService:Create(child, TweenInfo.new(0.4), { ImageTransparency = 0 }):Play()
        end
    end
    title.TextTransparency = 1
    ctx.TweenService:Create(title, TweenInfo.new(0.4), { TextTransparency = 0 }):Play()
    divider.BackgroundTransparency = 1
    ctx.TweenService:Create(divider, TweenInfo.new(0.4), { BackgroundTransparency = 0.5 }):Play()

    -- Each stat row fades in with 0.08s stagger
    for i, entry in ipairs(rowElements) do
        local delay = 0.15 + (i - 1) * 0.08
        for _, el in ipairs(entry.texts) do
            if el:IsA("TextLabel") then
                el.TextTransparency = 1
                task.delay(delay, function()
                    ctx.TweenService:Create(el, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                        TextTransparency = 0,
                    }):Play()
                end)
            elseif el:IsA("ImageLabel") then
                el.ImageTransparency = 1
                task.delay(delay, function()
                    ctx.TweenService:Create(el, TweenInfo.new(0.35), { ImageTransparency = 0 }):Play()
                end)
            end
        end
    end

    recapPanel = panel
end

return M
