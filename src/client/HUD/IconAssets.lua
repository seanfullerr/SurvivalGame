-- HUD/IconAssets: Centralized icon asset IDs and UI theme constants
-- Icons reference the "Free Icon Pack v3.1" — replace placeholder IDs
-- with actual rbxassetid:// values after uploading PNGs to Roblox Creator Hub.
-- Until uploaded, all HUD elements use text fallbacks ($ for coin, etc.)

local Icons = {}

---------- ASSET IDS (replace 0 with real rbxassetid after upload) ----------
-- Upload the 64px versions for HUD use (smaller = faster load)
Icons.Coin       = "rbxassetid://0"   -- Currency/Coin/Golden/Coin_Golden_1_64.png
Icons.Heart      = "rbxassetid://0"   -- Main/Heart/Red/Heart_Red_1_64.png
Icons.Skull      = "rbxassetid://0"   -- Player/Skull/White/Skull_White_1_64.png
Icons.Bomb       = "rbxassetid://0"   -- Item/Bomb/Black/Bomb_Black_1_64.png
Icons.Star       = "rbxassetid://0"   -- Main/Star/Golden/Star_Golden_1_64.png
Icons.Clock      = "rbxassetid://0"   -- Item/Clock/Golden/Clock_Golden_1_64.png
Icons.Shield     = "rbxassetid://0"   -- Item/Shield/Blue/Shield_Blue_1_64.png
Icons.Trophy     = "rbxassetid://0"   -- Item/Trophy/Golden/Trophy_Golden_1_64.png
Icons.Warning    = "rbxassetid://0"   -- Main/Warning/Red/Warning_Red_1_64.png
Icons.Crown      = "rbxassetid://0"   -- Item/Crown/Golden/Crown_Golden_1_64.png
Icons.Fire       = "rbxassetid://0"   -- Main/Fire/Red/Fire_Red_1_64.png
Icons.Upgrade    = "rbxassetid://0"   -- Main/Upgrade/Green/Upgrade_Green_1_64.png
Icons.Sword      = "rbxassetid://0"   -- Item/Sword/Blue/Sword_Blue_1_64.png

---------- THEME COLORS ----------
Icons.Theme = {
    -- Panel backgrounds (dark glass)
    PanelBG          = Color3.fromRGB(12, 12, 20),
    PanelBGLight     = Color3.fromRGB(20, 20, 35),
    PanelTransparency = 0.2,

    -- Accent colors
    Gold             = Color3.fromRGB(255, 210, 50),
    GoldDim          = Color3.fromRGB(200, 160, 40),
    Red              = Color3.fromRGB(255, 70, 50),
    RedSoft          = Color3.fromRGB(255, 100, 80),
    Green            = Color3.fromRGB(80, 255, 120),
    GreenDim         = Color3.fromRGB(60, 200, 90),
    Blue             = Color3.fromRGB(100, 180, 255),
    White            = Color3.fromRGB(240, 240, 255),
    WhiteDim         = Color3.fromRGB(180, 180, 200),
    Orange           = Color3.fromRGB(255, 160, 50),

    -- Stroke
    StrokeDefault    = Color3.fromRGB(60, 60, 80),
    StrokeAccent     = Color3.fromRGB(255, 200, 80),
    StrokeRed        = Color3.fromRGB(255, 60, 40),

    -- Text
    TextPrimary      = Color3.fromRGB(255, 255, 255),
    TextSecondary    = Color3.fromRGB(180, 180, 200),
    TextMuted        = Color3.fromRGB(120, 120, 140),
}

---------- HELPER: Create icon ImageLabel (with text fallback) ----------
-- Returns an ImageLabel if assetId is valid, otherwise a TextLabel fallback.
function Icons.createIcon(assetId, fallbackText, size, parent)
    local hasAsset = assetId and assetId ~= "rbxassetid://0" and assetId ~= ""

    if hasAsset then
        local img = Instance.new("ImageLabel")
        img.Size = size or UDim2.new(0, 20, 0, 20)
        img.BackgroundTransparency = 1
        img.Image = assetId
        img.ScaleType = Enum.ScaleType.Fit
        img.Parent = parent
        return img
    else
        local lbl = Instance.new("TextLabel")
        lbl.Size = size or UDim2.new(0, 20, 0, 20)
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 16
        lbl.TextColor3 = Icons.Theme.Gold
        lbl.Text = fallbackText or "?"
        lbl.Parent = parent
        return lbl
    end
end

---------- HELPER: Create standard glass panel ----------
function Icons.createGlassPanel(props)
    local panel = Instance.new("Frame")
    panel.Name = props.Name or "GlassPanel"
    panel.Size = props.Size or UDim2.new(0, 200, 0, 40)
    panel.Position = props.Position or UDim2.new(0.5, -100, 0.5, -20)
    panel.AnchorPoint = props.AnchorPoint or Vector2.new(0, 0)
    panel.BackgroundColor3 = props.BG or Icons.Theme.PanelBG
    panel.BackgroundTransparency = props.Transparency or Icons.Theme.PanelTransparency
    panel.BorderSizePixel = 0
    panel.ZIndex = props.ZIndex or 5
    if props.Parent then panel.Parent = props.Parent end

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, props.CornerRadius or 8)
    corner.Parent = panel

    if props.Stroke then
        local stroke = Instance.new("UIStroke")
        stroke.Color = props.StrokeColor or Icons.Theme.StrokeDefault
        stroke.Thickness = props.StrokeThickness or 1.5
        stroke.Transparency = props.StrokeTransparency or 0.3
        stroke.Parent = panel
    end

    return panel
end

return Icons
