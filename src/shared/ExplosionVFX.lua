-- ExplosionVFX v5: GRAND cartoony explosions with radial propagation
-- All effects are custom ParticleEmitters — no default Roblox Fire/Sparkles
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local VFX = {}

-- Helper: create a quick neon flash sphere
local function makeGlow(pos, startSize, endSize, color, lightColor, brightness, lightRange, duration, parent)
    local glow = Instance.new("Part")
    glow.Shape = Enum.PartType.Ball
    glow.Size = Vector3.new(startSize, startSize, startSize)
    glow.Position = pos
    glow.Anchored = true
    glow.CanCollide = false
    glow.Color = color
    glow.Material = Enum.Material.Neon
    glow.Transparency = 0
    glow.Parent = parent

    local lt = Instance.new("PointLight")
    lt.Color = lightColor
    lt.Brightness = brightness
    lt.Range = lightRange
    lt.Parent = glow

    local expandTime = duration * 0.3
    local shrinkTime = duration * 0.7

    TweenService:Create(glow,
        TweenInfo.new(expandTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Size = Vector3.new(endSize, endSize, endSize)}
    ):Play()
    task.delay(expandTime, function()
        if glow and glow.Parent then
            TweenService:Create(glow,
                TweenInfo.new(shrinkTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                {Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1}
            ):Play()
            TweenService:Create(lt, TweenInfo.new(shrinkTime), {Brightness = 0}):Play()
        end
    end)
    Debris:AddItem(glow, duration + 0.1)
    return glow
end

-- Helper: shockwave ring
local function makeRing(pos, endDiameter, color, thickness, duration, parent)
    local ring = Instance.new("Part")
    ring.Name = "Shockwave"
    ring.Shape = Enum.PartType.Cylinder
    ring.Size = Vector3.new(thickness, 2, 2)
    ring.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
    ring.Anchored = true
    ring.CanCollide = false
    ring.Color = color
    ring.Material = Enum.Material.Neon
    ring.Transparency = 0.15
    ring.Parent = parent

    TweenService:Create(ring,
        TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Size = Vector3.new(thickness * 0.2, endDiameter, endDiameter), Transparency = 1}
    ):Play()
    Debris:AddItem(ring, duration + 0.1)
end

-- ========== MAIN GRAND EXPLOSION ==========
function VFX.Explode(position, radius, parent, bombType)
    parent = parent or game.Workspace
    bombType = bombType or "standard"

    -- Color tinting by bomb type
    local tint = {
        standard = {core = Color3.fromRGB(255, 245, 150), outer = Color3.fromRGB(255, 180, 80), light = Color3.fromRGB(255, 200, 60), ring = Color3.fromRGB(255, 200, 100)},
        bouncing = {core = Color3.fromRGB(150, 255, 150), outer = Color3.fromRGB(80, 220, 80), light = Color3.fromRGB(100, 255, 60), ring = Color3.fromRGB(120, 255, 100)},
        timed    = {core = Color3.fromRGB(255, 200, 150), outer = Color3.fromRGB(255, 120, 60), light = Color3.fromRGB(255, 160, 40), ring = Color3.fromRGB(255, 150, 80)},
        cluster  = {core = Color3.fromRGB(220, 180, 255), outer = Color3.fromRGB(180, 100, 255), light = Color3.fromRGB(200, 140, 255), ring = Color3.fromRGB(190, 150, 255)},

        missile  = {core = Color3.fromRGB(255, 180, 80), outer = Color3.fromRGB(255, 100, 30), light = Color3.fromRGB(255, 150, 40), ring = Color3.fromRGB(255, 200, 80)},    }
    local c = tint[bombType] or tint.standard
    local sizeMult = (bombType == "timed") and 1.3 or 1.0

    -- 1) DOUBLE GLOW FLASH (bright core + softer outer pulse)
    makeGlow(position, 2 * sizeMult, radius * 0.6 * sizeMult,
        c.core, c.light,
        14, radius * 3.5, 0.4, parent)
    task.delay(0.03, function()
        makeGlow(position, 4 * sizeMult, radius * 0.9 * sizeMult,
            c.outer, c.light,
            6, radius * 2, 0.5, parent)
    end)

    -- 2) DOUBLE SHOCKWAVE (fast inner + slower outer)
    makeRing(position, radius * 2.2 * sizeMult, c.ring, 0.35, 0.25, parent)
    task.delay(0.06, function()
        makeRing(position, radius * 3 * sizeMult, c.outer, 0.2, 0.4, parent)
    end)

    -- 3) GROUND CRACK RING (dark expanding ring on the ground)
    local crack = Instance.new("Part")
    crack.Shape = Enum.PartType.Cylinder
    crack.Size = Vector3.new(0.15, 1, 1)
    crack.CFrame = CFrame.new(position + Vector3.new(0, -0.3, 0)) * CFrame.Angles(0, 0, math.rad(90))
    crack.Anchored = true
    crack.CanCollide = false
    crack.Color = Color3.fromRGB(50, 40, 25)
    crack.Material = Enum.Material.SmoothPlastic
    crack.Transparency = 0.3
    crack.Parent = parent
    TweenService:Create(crack,
        TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Size = Vector3.new(0.05, radius * 1.6, radius * 1.6), Transparency = 1}
    ):Play()
    Debris:AddItem(crack, 0.6)

    -- 4) PARTICLE HUB
    local hub = Instance.new("Part")
    hub.Name = "VFXHub"
    hub.Size = Vector3.new(1, 1, 1)
    hub.Position = position
    hub.Anchored = true
    hub.CanCollide = false
    hub.Transparency = 1
    hub.Parent = parent

    -- HOT CORE BURST (bright yellow->orange sparks radiating outward, MORE particles)
    local core = Instance.new("ParticleEmitter")
    core.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 200)),
        ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 230, 80)),
        ColorSequenceKeypoint.new(0.6, Color3.fromRGB(255, 150, 30)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 60, 5)),
    })
    core.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 5),
        NumberSequenceKeypoint.new(0.1, 3.5),
        NumberSequenceKeypoint.new(0.5, 1.5),
        NumberSequenceKeypoint.new(1, 0),
    })
    core.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(0.3, 0.1),
        NumberSequenceKeypoint.new(1, 1),
    })
    core.Lifetime = NumberRange.new(0.2, 0.55)
    core.Speed = NumberRange.new(30, 60)
    core.SpreadAngle = Vector2.new(180, 180)
    core.RotSpeed = NumberRange.new(-350, 350)
    core.LightEmission = 1
    core.Rate = 0
    core.Parent = hub
    core:Emit(40)

    -- FIRE COLUMN (upward rushing flames, new effect for grandness)
    local fireCol = Instance.new("ParticleEmitter")
    fireCol.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 120)),
        ColorSequenceKeypoint.new(0.3, Color3.fromRGB(255, 160, 40)),
        ColorSequenceKeypoint.new(0.7, Color3.fromRGB(230, 80, 15)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 40, 10)),
    })
    fireCol.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 3),
        NumberSequenceKeypoint.new(0.2, 5),
        NumberSequenceKeypoint.new(0.5, 3.5),
        NumberSequenceKeypoint.new(1, 0.5),
    })
    fireCol.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.1),
        NumberSequenceKeypoint.new(0.3, 0.2),
        NumberSequenceKeypoint.new(0.7, 0.6),
        NumberSequenceKeypoint.new(1, 1),
    })
    fireCol.Lifetime = NumberRange.new(0.4, 0.8)
    fireCol.Speed = NumberRange.new(20, 40)
    fireCol.SpreadAngle = Vector2.new(25, 25)
    fireCol.Acceleration = Vector3.new(0, 15, 0)
    fireCol.RotSpeed = NumberRange.new(-180, 180)
    fireCol.LightEmission = 0.95
    fireCol.Rate = 0
    fireCol.Parent = hub
    fireCol:Emit(20)

    -- EMBER TRAILS (lingering sparks that drift outward and upward)
    local embers = Instance.new("ParticleEmitter")
    embers.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 230, 100)),
        ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 160, 50)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 60, 10)),
    })
    embers.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1.4),
        NumberSequenceKeypoint.new(0.4, 1),
        NumberSequenceKeypoint.new(1, 0),
    })
    embers.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(0.5, 0.25),
        NumberSequenceKeypoint.new(1, 1),
    })
    embers.Lifetime = NumberRange.new(0.5, 1.2)
    embers.Speed = NumberRange.new(10, 28)
    embers.SpreadAngle = Vector2.new(180, 180)
    embers.Acceleration = Vector3.new(0, 10, 0)
    embers.RotSpeed = NumberRange.new(-200, 200)
    embers.LightEmission = 0.9
    embers.Rate = 0
    embers.Parent = hub
    embers:Emit(30)

    -- POOFY SMOKE (bigger, puffier cartoon clouds)
    local smoke = Instance.new("ParticleEmitter")
    smoke.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(210, 200, 185)),
        ColorSequenceKeypoint.new(0.4, Color3.fromRGB(160, 155, 140)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(100, 95, 85)),
    })
    smoke.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 2),
        NumberSequenceKeypoint.new(0.25, 5.5),
        NumberSequenceKeypoint.new(0.6, 8),
        NumberSequenceKeypoint.new(1, 9),
    })
    smoke.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.25),
        NumberSequenceKeypoint.new(0.25, 0.45),
        NumberSequenceKeypoint.new(0.65, 0.75),
        NumberSequenceKeypoint.new(1, 1),
    })
    smoke.Lifetime = NumberRange.new(0.6, 1.3)
    smoke.Speed = NumberRange.new(5, 14)
    smoke.SpreadAngle = Vector2.new(170, 170)
    smoke.Acceleration = Vector3.new(0, 8, 0)
    smoke.RotSpeed = NumberRange.new(-50, 50)
    smoke.Rate = 0
    smoke.Parent = hub
    smoke:Emit(18)

    -- DIRT CHUNKS (arcing debris with gravity)
    local dirt = Instance.new("ParticleEmitter")
    dirt.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(160, 120, 70)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(90, 70, 35)),
    })
    dirt.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 2.2),
        NumberSequenceKeypoint.new(0.3, 1.5),
        NumberSequenceKeypoint.new(1, 0.2),
    })
    dirt.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(0.5, 0.15),
        NumberSequenceKeypoint.new(1, 1),
    })
    dirt.Lifetime = NumberRange.new(0.5, 1.1)
    dirt.Speed = NumberRange.new(20, 45)
    dirt.SpreadAngle = Vector2.new(160, 160)
    dirt.Acceleration = Vector3.new(0, -55, 0)
    dirt.RotSpeed = NumberRange.new(-250, 250)
    dirt.Rate = 0
    dirt.Parent = hub
    dirt:Emit(25)

    -- STAR SPARKLES (twinkles that pulse and linger)
    local stars = Instance.new("ParticleEmitter")
    stars.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 245)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 220, 130)),
    })
    stars.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(0.15, 1.8),
        NumberSequenceKeypoint.new(0.4, 0.5),
        NumberSequenceKeypoint.new(0.6, 1.4),
        NumberSequenceKeypoint.new(1, 0),
    })
    stars.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(0.7, 0.15),
        NumberSequenceKeypoint.new(1, 1),
    })
    stars.Lifetime = NumberRange.new(0.35, 0.8)
    stars.Speed = NumberRange.new(6, 18)
    stars.SpreadAngle = Vector2.new(180, 180)
    stars.LightEmission = 1
    stars.RotSpeed = NumberRange.new(-450, 450)
    stars.Rate = 0
    stars.Parent = hub
    stars:Emit(22)

    -- RADIAL GROUND SPARKS (new — sparks that shoot along the ground outward)
    local groundSparks = Instance.new("ParticleEmitter")
    groundSparks.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 200, 80)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 130, 30)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 60, 10)),
    })
    groundSparks.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1.5),
        NumberSequenceKeypoint.new(0.3, 1),
        NumberSequenceKeypoint.new(1, 0),
    })
    groundSparks.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(0.6, 0.3),
        NumberSequenceKeypoint.new(1, 1),
    })
    groundSparks.Lifetime = NumberRange.new(0.3, 0.7)
    groundSparks.Speed = NumberRange.new(25, 50)
    groundSparks.SpreadAngle = Vector2.new(180, 20)
    groundSparks.Acceleration = Vector3.new(0, -30, 0)
    groundSparks.LightEmission = 0.85
    groundSparks.RotSpeed = NumberRange.new(-300, 300)
    groundSparks.Rate = 0
    groundSparks.Parent = hub
    groundSparks:Emit(20)

    Debris:AddItem(hub, 2.2)
end

-- ========== SMALLER EXPLOSION (bounces/cluster mini-bombs) ==========
function VFX.SmallExplode(position, parent)
    parent = parent or game.Workspace

    makeGlow(position, 1.5, 4.5,
        Color3.fromRGB(255, 230, 100), Color3.fromRGB(255, 190, 60),
        7, 18, 0.3, parent)

    makeRing(position, 10, Color3.fromRGB(255, 170, 50), 0.2, 0.2, parent)

    local hub = Instance.new("Part")
    hub.Size = Vector3.new(1, 1, 1)
    hub.Position = position
    hub.Anchored = true
    hub.CanCollide = false
    hub.Transparency = 1
    hub.Parent = parent

    -- Mini burst
    local burst = Instance.new("ParticleEmitter")
    burst.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 140)),
        ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 170, 45)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 70, 15)),
    })
    burst.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 2.5),
        NumberSequenceKeypoint.new(0.15, 1.5),
        NumberSequenceKeypoint.new(1, 0),
    })
    burst.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(0.4, 0.2),
        NumberSequenceKeypoint.new(1, 1),
    })
    burst.Lifetime = NumberRange.new(0.12, 0.35)
    burst.Speed = NumberRange.new(18, 32)
    burst.SpreadAngle = Vector2.new(180, 180)
    burst.LightEmission = 0.95
    burst.RotSpeed = NumberRange.new(-250, 250)
    burst.Rate = 0
    burst.Parent = hub
    burst:Emit(18)

    -- Mini smoke puff
    local puff = Instance.new("ParticleEmitter")
    puff.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(190, 180, 165)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(130, 125, 115)),
    })
    puff.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1.2),
        NumberSequenceKeypoint.new(0.4, 3),
        NumberSequenceKeypoint.new(1, 4),
    })
    puff.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.3),
        NumberSequenceKeypoint.new(0.5, 0.6),
        NumberSequenceKeypoint.new(1, 1),
    })
    puff.Lifetime = NumberRange.new(0.3, 0.6)
    puff.Speed = NumberRange.new(4, 10)
    puff.SpreadAngle = Vector2.new(180, 180)
    puff.Acceleration = Vector3.new(0, 6, 0)
    puff.Rate = 0
    puff.Parent = hub
    puff:Emit(8)

    -- Mini twinkle stars
    local stars = Instance.new("ParticleEmitter")
    stars.Color = ColorSequence.new(Color3.fromRGB(255, 255, 225))
    stars.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(0.25, 1),
        NumberSequenceKeypoint.new(0.55, 0.3),
        NumberSequenceKeypoint.new(1, 0),
    })
    stars.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(1, 1),
    })
    stars.Lifetime = NumberRange.new(0.2, 0.5)
    stars.Speed = NumberRange.new(5, 14)
    stars.SpreadAngle = Vector2.new(180, 180)
    stars.LightEmission = 1
    stars.RotSpeed = NumberRange.new(-350, 350)
    stars.Rate = 0
    stars.Parent = hub
    stars:Emit(10)

    Debris:AddItem(hub, 1.0)
end

return VFX
