-- BombSystem v14: Distinct bomb visuals, fall trails, mid-round pauses, steeper curve
local RS = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local ok1, Config = pcall(require, RS:WaitForChild("GameConfig"))
local ok2, MapManager = pcall(require, RS:WaitForChild("MapManager"))
local ok3, VFX = pcall(require, RS:WaitForChild("ExplosionVFX"))
local ok4, SFX = pcall(require, RS:WaitForChild("SoundManager"))
if not (ok1 and ok2 and ok3 and ok4) then
    warn("[BombSystem] Failed to load modules:", ok1, ok2, ok3, ok4)
    return
end

local binds = RS:WaitForChild("Binds")
local damagePlayer = binds:WaitForChild("DamagePlayer")
local GameEvents = RS:WaitForChild("GameEvents")
local bombTemplate = ServerStorage:WaitForChild("BombTemplate")
local spawning = false

local bombFolder = workspace:FindFirstChild("Bombs")
if not bombFolder then
    bombFolder = Instance.new("Folder"); bombFolder.Name = "Bombs"; bombFolder.Parent = workspace
end

---------- BOMB VISUAL CONFIGS ----------
-- Each bomb type has distinct color, glow, and trail so players learn to read them
local BOMB_VISUALS = {
    standard = {
        bodyColor = Color3.fromRGB(50, 50, 55),
        glowColor = Color3.fromRGB(255, 160, 40),
        trailColor1 = Color3.fromRGB(255, 200, 80),
        trailColor2 = Color3.fromRGB(200, 100, 20),
    },
    bouncing = {
        bodyColor = Color3.fromRGB(40, 180, 60),
        glowColor = Color3.fromRGB(80, 255, 100),
        trailColor1 = Color3.fromRGB(100, 255, 120),
        trailColor2 = Color3.fromRGB(40, 180, 60),
    },
    timed = {
        bodyColor = Color3.fromRGB(200, 50, 50),
        glowColor = Color3.fromRGB(255, 60, 40),
        trailColor1 = Color3.fromRGB(255, 80, 40),
        trailColor2 = Color3.fromRGB(200, 30, 10),
    },
    cluster = {
        bodyColor = Color3.fromRGB(140, 60, 200),
        glowColor = Color3.fromRGB(200, 120, 255),
        trailColor1 = Color3.fromRGB(220, 150, 255),
        trailColor2 = Color3.fromRGB(140, 60, 200),
    },
}

local NEAR_MISS_MULT = 1.3

---------- HOT ZONE ----------
local currentHotZone = "NW"
local currentDestroyChance = Config.DESTROY_CHANCE_BASE or 0.40
local currentWarnScale = 1.0
local currentScorchLifetime = 9

---------- HELPERS ----------
local function randomArenaPos()
    local half = MapManager.GetBounds() - 3
    local x = math.random(-half, half)
    local z = math.random(-half, half)

    -- Hot zone bias: re-roll some bombs into the hot zone for ~1.4x density
    local inHotZone = false
    if currentHotZone == "NW" then inHotZone = (x < 0 and z < 0)
    elseif currentHotZone == "NE" then inHotZone = (x >= 0 and z < 0)
    elseif currentHotZone == "SW" then inHotZone = (x < 0 and z >= 0)
    elseif currentHotZone == "SE" then inHotZone = (x >= 0 and z >= 0)
    elseif currentHotZone == "CENTER" then
        inHotZone = (math.abs(x) < half * 0.5 and math.abs(z) < half * 0.5)
    end

    if not inHotZone and math.random() < 0.28 then
        if currentHotZone == "NW" then x = math.random(-half, -1); z = math.random(-half, -1)
        elseif currentHotZone == "NE" then x = math.random(0, half); z = math.random(-half, -1)
        elseif currentHotZone == "SW" then x = math.random(-half, -1); z = math.random(0, half)
        elseif currentHotZone == "SE" then x = math.random(0, half); z = math.random(0, half)
        elseif currentHotZone == "CENTER" then
            local ch = math.floor(half * 0.5)
            x = math.random(-ch, ch); z = math.random(-ch, ch)
        end
    end

    return Vector3.new(x, 0, z)
end

local function applyKnockback(hrp, direction, force)
    local att = hrp:FindFirstChild("KnockbackAtt")
    if not att then
        att = Instance.new("Attachment"); att.Name = "KnockbackAtt"; att.Parent = hrp
    end
    local lv = Instance.new("LinearVelocity")
    lv.Attachment0 = att
    lv.VectorVelocity = direction * force
    lv.MaxForce = 1e6
    lv.RelativeTo = Enum.ActuatorRelativeTo.World
    lv.Parent = hrp
    Debris:AddItem(lv, 0.3)
end

local function damageAndKnockback(center, radius, damage, knockForce, bombType)
    knockForce = knockForce or 80
    bombType = bombType or "standard"

    -- Raycast params: only hit map terrain, not players/bombs/VFX
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Include
    local mapFolder = workspace:FindFirstChild("Map")
    local filterList = {}
    if mapFolder then table.insert(filterList, mapFolder) end
    local ramps = mapFolder and mapFolder:FindFirstChild("Ramps")
    if ramps then table.insert(filterList, ramps) end
    rayParams.FilterDescendantsInstances = filterList

    for _, player in ipairs(Players:GetPlayers()) do
        local char = player.Character
        if not char then continue end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end
        local hum = char:FindFirstChild("Humanoid")
        local offset = hrp.Position - center
        local dist = offset.Magnitude

        -- Line-of-sight check: raycast from explosion to player
        local losBlocked = false
        if dist > 2 and dist <= radius * NEAR_MISS_MULT then
            local direction = offset.Unit * dist
            local rayOrigin = center + Vector3.new(0, 1, 0)
            local result = workspace:Raycast(rayOrigin, direction, rayParams)
            if result and result.Distance < dist - 3 then
                losBlocked = true
            end
        end

        if dist <= radius then
            local dmgScale = 1 - (dist / radius) * 0.5
            -- If terrain blocks line-of-sight, heavy damage reduction (splash through walls)
            if losBlocked then dmgScale = dmgScale * 0.15 end
            -- Pass bomb type as 3rd arg so client can show death cause
            damagePlayer:Fire(player, math.floor(damage * dmgScale), bombType)
            local knockScale = math.clamp(1 - (dist / radius), 0.15, 1)
            if losBlocked then knockScale = knockScale * 0.2 end
            local dir = offset.Magnitude > 0.5 and offset.Unit or Vector3.new(0, 1, 0)
            -- Light hits: horizontal slide. Heavy hits: launch airborne
            local upBoost = knockScale > 0.4 and (0.3 + knockScale * 0.5) or 0.1
            local pushDir = (dir + Vector3.new(0, upBoost, 0)).Unit
            applyKnockback(hrp, pushDir, knockForce * knockScale)
            if hum then
                -- Scale stun with hit severity: 0.15s graze, 0.3s direct hit
                -- Uses timestamp to prevent stun-lock from overlapping bombs
                local stunTime = 0.15 + knockScale * 0.15
                local stunId = tick()
                hum:SetAttribute("StunUntil", stunId + stunTime)
                hum.PlatformStand = true
                task.delay(stunTime + 0.02, function()
                    if hum and hum.Parent then
                        local currentStun = hum:GetAttribute("StunUntil") or 0
                        -- Only release stun if no newer stun was applied
                        if currentStun <= stunId + stunTime + 0.05 then
                            hum.PlatformStand = false
                        end
                    end
                end)
            end
        elseif dist <= radius * NEAR_MISS_MULT then
            -- Only show near-miss if player has line-of-sight to explosion
            if not losBlocked then
                GameEvents.PlayerDamaged:FireClient(player, 0)
            end
        end
    end
end

---------- BOMB CLONE WITH TRAIL ----------
local function cloneBombAt(targetX, targetZ, landY, fallHeight, fallTime, bombType)
    bombType = bombType or "standard"
    local vis = BOMB_VISUALS[bombType] or BOMB_VISUALS.standard

    local bomb = bombTemplate:Clone()
    bomb.Name = "ActiveBomb"
    local body = bomb.PrimaryPart
    body.Color = vis.bodyColor
    bomb:SetPrimaryPartCFrame(CFrame.new(targetX, fallHeight, targetZ))
    bomb.Parent = bombFolder

    -- Glow light matching bomb type
    local light = body:FindFirstChildOfClass("PointLight")
    if light then light.Color = vis.glowColor; light.Brightness = 2; light.Range = 14 end

    -- FALL TRAIL: ParticleEmitter so players can track incoming bombs
    local trail = Instance.new("ParticleEmitter")
    trail.Color = ColorSequence.new(vis.trailColor1, vis.trailColor2)
    trail.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1.5),
        NumberSequenceKeypoint.new(1, 0),
    })
    trail.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.2),
        NumberSequenceKeypoint.new(1, 1),
    })
    trail.Lifetime = NumberRange.new(0.2, 0.5)
    trail.Speed = NumberRange.new(0, 2)
    trail.Rate = 25
    trail.LightEmission = 0.6
    trail.Parent = body

    local goalCF = CFrame.new(targetX, landY, targetZ)
    local offsets = {}
    for _, part in ipairs(bomb:GetDescendants()) do
        if part:IsA("BasePart") and part ~= body then
            offsets[part] = body.CFrame:ToObjectSpace(part.CFrame)
        end
    end
    local conn
    conn = RunService.Heartbeat:Connect(function()
        if not body or not body.Parent then conn:Disconnect() return end
        for part, off in pairs(offsets) do
            if part and part.Parent then part.CFrame = body.CFrame:ToWorldSpace(off) end
        end
    end)

    local fallTween = TweenService:Create(body,
        TweenInfo.new(fallTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        {CFrame = goalCF}
    )
    fallTween:Play()
    SFX.PlayOn("BombWhistle", body, {Volume = 0.5, PlaybackSpeed = 1.1 + math.random() * 0.3})

    return bomb, body, conn, fallTween
end

---------- SHADOW (immediate, grows as bomb falls) ----------
local function createShadow(targetX, targetZ)
    local surfaceY = MapManager.GetSurfaceY(targetX, targetZ)
    local targetSize = Config.BOMB_BLAST_RADIUS * 2
    local warnPos = Vector3.new(targetX, surfaceY + 0.15, targetZ)

    local warnFolder = Instance.new("Folder"); warnFolder.Name = "BombWarning"; warnFolder.Parent = bombFolder

    -- Shadow appears immediately at small size, grows to full
    local ring = Instance.new("Part")
    ring.Name = "WarnRing"; ring.Shape = Enum.PartType.Cylinder
    ring.Size = Vector3.new(0.12, 2, 2)
    ring.CFrame = CFrame.new(warnPos) * CFrame.Angles(0, 0, math.rad(90))
    ring.Anchored = true; ring.CanCollide = false
    ring.Color = Color3.fromRGB(255, 40, 40); ring.Material = Enum.Material.Neon; ring.Transparency = 0.2
    ring.Parent = warnFolder
    TweenService:Create(ring,
        TweenInfo.new((Config.BOMB_WARN_TIME * currentWarnScale), Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Size = Vector3.new(0.12, targetSize, targetSize)}):Play()
    TweenService:Create(ring,
        TweenInfo.new(0.15, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        {Transparency = 0.6}):Play()

    local fill = Instance.new("Part")
    fill.Name = "WarnFill"; fill.Shape = Enum.PartType.Cylinder
    fill.Size = Vector3.new(0.08, 1, 1)
    fill.CFrame = CFrame.new(warnPos + Vector3.new(0, -0.03, 0)) * CFrame.Angles(0, 0, math.rad(90))
    fill.Anchored = true; fill.CanCollide = false
    fill.Color = Color3.fromRGB(255, 100, 40); fill.Material = Enum.Material.Neon; fill.Transparency = 0.7
    fill.Parent = warnFolder
    TweenService:Create(fill,
        TweenInfo.new((Config.BOMB_WARN_TIME * currentWarnScale), Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Size = Vector3.new(0.08, targetSize * 0.85, targetSize * 0.85)}):Play()

    local dot = Instance.new("Part")
    dot.Name = "WarnDot"; dot.Shape = Enum.PartType.Ball
    dot.Size = Vector3.new(1.5, 0.3, 1.5); dot.Position = warnPos + Vector3.new(0, 0.05, 0)
    dot.Anchored = true; dot.CanCollide = false
    dot.Color = Color3.fromRGB(255, 255, 80); dot.Material = Enum.Material.Neon; dot.Transparency = 0.1
    dot.Parent = warnFolder
    TweenService:Create(dot,
        TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        {Transparency = 0.5, Size = Vector3.new(2.2, 0.3, 2.2)}):Play()

    local warnLight = Instance.new("PointLight")
    warnLight.Color = Color3.fromRGB(255, 60, 30); warnLight.Brightness = 0; warnLight.Range = 12
    warnLight.Parent = dot
    TweenService:Create(warnLight,
        TweenInfo.new((Config.BOMB_WARN_TIME * currentWarnScale), Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        {Brightness = 3}):Play()

    SFX.PlayAt("WarningBeep", warnPos, {Volume = 0.35, PlaybackSpeed = 1.2})
    Debris:AddItem(warnFolder, 8)
    -- TRACKING BEAM: vertical line from shadow to sky, shows where bomb will land
    local beam = Instance.new("Part")
    beam.Name = "TrackBeam"
    beam.Size = Vector3.new(0.3, Config.BOMB_FALL_HEIGHT, 0.3)
    beam.CFrame = CFrame.new(warnPos + Vector3.new(0, Config.BOMB_FALL_HEIGHT / 2, 0))
    beam.Anchored = true; beam.CanCollide = false
    beam.Color = Color3.fromRGB(255, 80, 40); beam.Material = Enum.Material.Neon
    beam.Transparency = 0.7
    beam.Parent = warnFolder
    -- Beam shrinks vertically as bomb falls, creating urgency
    TweenService:Create(beam,
        TweenInfo.new((Config.BOMB_WARN_TIME * currentWarnScale), Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        {Size = Vector3.new(0.3, 2, 0.3), CFrame = CFrame.new(warnPos + Vector3.new(0, 1, 0)), Transparency = 0.3}
    ):Play()


    return warnFolder
end

---------- SCORCH MARK ----------
local function createScorchMark(pos)
    local mark = Instance.new("Part")
    mark.Name = "ScorchMark"; mark.Shape = Enum.PartType.Cylinder
    mark.Size = Vector3.new(0.08, 10, 10)
    mark.CFrame = CFrame.new(pos.X, pos.Y + 0.1, pos.Z) * CFrame.Angles(0, 0, math.rad(90))
    mark.Anchored = true; mark.CanCollide = false
    mark.Color = Color3.fromRGB(40, 35, 30); mark.Material = Enum.Material.Slate; mark.Transparency = 0.4
    mark.Parent = bombFolder
    local fadeDelay = currentScorchLifetime * 0.45
    local fadeDur = currentScorchLifetime * 0.45
    task.delay(fadeDelay, function()
        if mark and mark.Parent then
            TweenService:Create(mark, TweenInfo.new(fadeDur, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                {Transparency = 1}):Play()
            Debris:AddItem(mark, fadeDur + 0.5)
        end
    end)
    Debris:AddItem(mark, currentScorchLifetime)
end
---------- EXPLODE ----------
local function explodeAt(pos, radius, damage, knockForce, doTerrain, depthLayers, bombType)
    VFX.Explode(pos, radius, bombFolder, bombType)
    -- F1: Bomb-type-specific explosion audio (pitch/volume varies for pattern recognition)
    local explosionPitch = {
        standard = 0.95 + math.random() * 0.15,   -- baseline
        bouncing = 1.3 + math.random() * 0.2,      -- snappy, higher
        timed = 0.7 + math.random() * 0.1,         -- deep, heavy
        cluster = 1.1 + math.random() * 0.2,       -- light pop
        missile = 0.6 + math.random() * 0.1,       -- deep boom
    }
    local explosionVol = {
        standard = 1.0, bouncing = 0.85, timed = 1.2, cluster = 0.7, missile = 1.1,
    }
    local pitch = explosionPitch[bombType] or explosionPitch.standard
    local vol = explosionVol[bombType] or 1.0
    SFX.PlayAt("Explosion", pos, {Volume = vol, PlaybackSpeed = pitch})
    damageAndKnockback(pos, radius, damage, knockForce, bombType)
    if doTerrain ~= false then
        MapManager.DestroyAt(pos, Config.BOMB_DESTROY_RADIUS, depthLayers or 2, currentDestroyChance)
    end
    createScorchMark(pos)
    GameEvents.BombLanded:FireAllClients(pos)
end

---------- HAZARD TYPES ----------

local function spawnStandardBomb()
    local target = randomArenaPos()
    local shadow = createShadow(target.X, target.Z)
    task.delay((Config.BOMB_WARN_TIME * currentWarnScale) * 0.2, function()
        local surfaceY = MapManager.GetSurfaceY(target.X, target.Z)
        local bomb, body, conn, fallTween = cloneBombAt(
            target.X, target.Z, surfaceY, Config.BOMB_FALL_HEIGHT, (Config.BOMB_WARN_TIME * currentWarnScale) * 0.8, "standard"
        )
        fallTween.Completed:Connect(function()
            conn:Disconnect()
            local pos = Vector3.new(target.X, surfaceY, target.Z)
            explodeAt(pos, Config.BOMB_BLAST_RADIUS, Config.BOMB_DAMAGE, 45, true, 2, "standard")
            task.delay(0.1, function()
                if bomb and bomb.Parent then bomb:Destroy() end
                if shadow and shadow.Parent then shadow:Destroy() end
            end)
        end)
        Debris:AddItem(bomb, 8)
    end)
end

local function spawnBouncingBomb()
    local target = randomArenaPos()
    local shadow = createShadow(target.X, target.Z)
    task.delay((Config.BOMB_WARN_TIME * currentWarnScale) * 0.2, function()
        local surfaceY = MapManager.GetSurfaceY(target.X, target.Z)
        local bomb, body, conn, fallTween = cloneBombAt(
            target.X, target.Z, surfaceY, Config.BOMB_FALL_HEIGHT, (Config.BOMB_WARN_TIME * currentWarnScale) * 0.8, "bouncing"
        )
        fallTween.Completed:Connect(function()
            conn:Disconnect()
            if shadow and shadow.Parent then shadow:Destroy() end
            body.Anchored = false
            body.AssemblyLinearVelocity = Vector3.new(math.random(-10, 10), 30, math.random(-10, 10))
            VFX.SmallExplode(body.Position, bombFolder)
            SFX.PlayAt("SmallExplosion", body.Position, {Volume = 0.6})
            body.Material = Enum.Material.Neon
            local glow = Instance.new("PointLight")
            glow.Color = Color3.fromRGB(80, 255, 80); glow.Brightness = 3; glow.Range = 14; glow.Parent = body
            local bTrail = Instance.new("ParticleEmitter")
            bTrail.Color = ColorSequence.new(Color3.fromRGB(100, 255, 120), Color3.fromRGB(50, 180, 60))
            bTrail.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 0)})
            bTrail.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1)})
            bTrail.Lifetime = NumberRange.new(0.3, 0.6); bTrail.Speed = NumberRange.new(0, 2)
            bTrail.Rate = 30; bTrail.LightEmission = 0.8; bTrail.Parent = body
            local bounces = math.random(2, 3)
            for b = 1, bounces do
                task.wait(0.6)
                if not body or not body.Parent then return end
                VFX.SmallExplode(body.Position, bombFolder)
                SFX.PlayAt("SmallExplosion", body.Position, {Volume = 0.5, PlaybackSpeed = 1.3 + math.random() * 0.3})
                body.AssemblyLinearVelocity = Vector3.new(math.random(-8, 8), math.random(18, 28), math.random(-8, 8))
            end
            task.wait(0.5)
            if not body or not body.Parent then return end
            explodeAt(body.Position, Config.BOMB_BLAST_RADIUS * 0.8, Config.BOMB_DAMAGE * 0.7, 70, true, 2, "bouncing")
            if bomb and bomb.Parent then bomb:Destroy() end
        end)
        Debris:AddItem(bomb, 10)
    end)
end

local function spawnTimedBomb()
    local target = randomArenaPos()
    local shadow = createShadow(target.X, target.Z)
    task.delay((Config.BOMB_WARN_TIME * currentWarnScale) * 0.2, function()
        local surfaceY = MapManager.GetSurfaceY(target.X, target.Z)
        local bomb, body, conn, fallTween = cloneBombAt(
            target.X, target.Z, surfaceY, Config.BOMB_FALL_HEIGHT, (Config.BOMB_WARN_TIME * currentWarnScale) * 0.8, "timed"
        )
        fallTween.Completed:Connect(function()
            conn:Disconnect()
            if shadow and shadow.Parent then shadow:Destroy() end
            body.Anchored = true

            -- Fuse warning
            local fuseRadius = Config.BOMB_BLAST_RADIUS * 1.3 * 2
            local fuseY = body.Position.Y - 2
            local fuseWarn = Instance.new("Folder"); fuseWarn.Name = "TimedWarn"; fuseWarn.Parent = bombFolder
            local fuseRing = Instance.new("Part")
            fuseRing.Shape = Enum.PartType.Cylinder
            fuseRing.Size = Vector3.new(0.12, fuseRadius, fuseRadius)
            fuseRing.CFrame = CFrame.new(body.Position.X, fuseY, body.Position.Z) * CFrame.Angles(0, 0, math.rad(90))
            fuseRing.Anchored = true; fuseRing.CanCollide = false
            fuseRing.Color = Color3.fromRGB(255, 40, 40); fuseRing.Material = Enum.Material.Neon; fuseRing.Transparency = 0.3
            fuseRing.Parent = fuseWarn
            TweenService:Create(fuseRing, TweenInfo.new(0.15, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Transparency = 0.7}):Play()
            local fuseFill = Instance.new("Part")
            fuseFill.Shape = Enum.PartType.Cylinder
            fuseFill.Size = Vector3.new(0.08, fuseRadius * 0.9, fuseRadius * 0.9)
            fuseFill.CFrame = CFrame.new(body.Position.X, fuseY - 0.05, body.Position.Z) * CFrame.Angles(0, 0, math.rad(90))
            fuseFill.Anchored = true; fuseFill.CanCollide = false
            fuseFill.Color = Color3.fromRGB(255, 80, 30); fuseFill.Material = Enum.Material.Neon; fuseFill.Transparency = 0.8
            fuseFill.Parent = fuseWarn
            TweenService:Create(fuseFill, TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Transparency = 0.3, Color = Color3.fromRGB(255, 30, 10), Size = Vector3.new(0.08, 1, 1)}):Play()
            local fuseLight = Instance.new("PointLight")
            fuseLight.Color = Color3.fromRGB(255, 50, 20); fuseLight.Brightness = 1; fuseLight.Range = 20; fuseLight.Parent = fuseRing
            TweenService:Create(fuseLight, TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Brightness = 6}):Play()
            Debris:AddItem(fuseWarn, 5)
            local flashCount = 6
            for f = 1, flashCount do
                if not body or not body.Parent then break end
                body.Material = Enum.Material.Neon; body.Color = Color3.fromRGB(255, 255, 100)
                task.wait(0.25)
                if not body or not body.Parent then break end
                body.Material = Enum.Material.SmoothPlastic; body.Color = Color3.fromRGB(200, 50, 50)
                task.wait(0.25)
            end
            if fuseWarn and fuseWarn.Parent then fuseWarn:Destroy() end
            if not body or not body.Parent then return end
            explodeAt(body.Position, Config.BOMB_BLAST_RADIUS * 1.3, Config.BOMB_DAMAGE * 1.3, 120, true, 3, "timed")
            if bomb and bomb.Parent then bomb:Destroy() end
        end)
        Debris:AddItem(bomb, 12)
    end)
end

local function spawnClusterBomb()
    local target = randomArenaPos()
    local shadow = createShadow(target.X, target.Z)
    task.delay((Config.BOMB_WARN_TIME * currentWarnScale) * 0.2, function()
        local surfaceY = MapManager.GetSurfaceY(target.X, target.Z)
        local bomb, body, conn, fallTween = cloneBombAt(
            target.X, target.Z, surfaceY, Config.BOMB_FALL_HEIGHT, (Config.BOMB_WARN_TIME * currentWarnScale) * 0.8, "cluster"
        )
        body.Size = Vector3.new(5.5, 5.5, 5.5)
        fallTween.Completed:Connect(function()
            conn:Disconnect()
            if shadow and shadow.Parent then shadow:Destroy() end
            local pos = Vector3.new(target.X, surfaceY, target.Z)
            VFX.SmallExplode(pos, bombFolder)
            SFX.PlayAt("SmallExplosion", pos, {Volume = 0.7})
            damageAndKnockback(pos, Config.BOMB_BLAST_RADIUS * 0.5, Config.BOMB_DAMAGE * 0.3, 50, "cluster")
            createScorchMark(pos)
            GameEvents.BombLanded:FireAllClients(pos)
            if bomb and bomb.Parent then bomb:Destroy() end
            local count = math.random(4, 5)
            for i = 1, count do
                task.delay(0.05 * i, function()
                    local mini = Instance.new("Part")
                    mini.Name = "MiniBomb"; mini.Shape = Enum.PartType.Ball
                    mini.Size = Vector3.new(2, 2, 2)
                    mini.Color = Color3.fromRGB(200, 120, 255)
                    mini.Material = Enum.Material.Neon; mini.Position = pos + Vector3.new(0, 3, 0)
                    mini.CanCollide = false
                    mini.Parent = bombFolder
                    local mg = Instance.new("PointLight")
                    mg.Color = Color3.fromRGB(200, 120, 255); mg.Brightness = 2; mg.Range = 10; mg.Parent = mini
                    local mt = Instance.new("ParticleEmitter")
                    mt.Color = ColorSequence.new(Color3.fromRGB(220, 150, 255), Color3.fromRGB(160, 80, 200))
                    mt.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0)})
                    mt.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1)})
                    mt.Lifetime = NumberRange.new(0.2, 0.4); mt.Speed = NumberRange.new(0, 1)
                    mt.Rate = 20; mt.LightEmission = 0.7; mt.Parent = mini
                    mini.AssemblyLinearVelocity = Vector3.new(math.random(-25, 25), math.random(20, 35), math.random(-25, 25))
                    -- S4: Brief ground warning for mini-bomb (predict landing from velocity)
                    local vel = mini.AssemblyLinearVelocity
                    local spawnPos = mini.Position
                    -- Simple trajectory prediction: estimate where it'll be when it starts falling
                    local tPeak = vel.Y / 196.2  -- time to reach apex (gravity ~196.2)
                    local predX = spawnPos.X + vel.X * tPeak * 1.2
                    local predZ = spawnPos.Z + vel.Z * tPeak * 1.2
                    local surfY = MapManager.GetSurfaceY(predX, predZ)
                    -- Create brief red warning circle
                    local warn = Instance.new("Part")
                    warn.Name = "MiniWarn"; warn.Shape = Enum.PartType.Cylinder
                    warn.Size = Vector3.new(0.15, 6, 6)  -- flat disc
                    warn.CFrame = CFrame.new(predX, surfY + 0.15, predZ) * CFrame.Angles(0, 0, math.rad(90))
                    warn.Anchored = true; warn.CanCollide = false
                    warn.Color = Color3.fromRGB(200, 80, 255); warn.Material = Enum.Material.Neon
                    warn.Transparency = 0.3
                    warn.Parent = bombFolder
                    TweenService:Create(warn, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                        Transparency = 1, Size = Vector3.new(0.1, 3, 3)
                    }):Play()
                    Debris:AddItem(warn, 0.6)
                    task.delay(math.random(8, 14) / 10, function()
                        if not mini or not mini.Parent then return end
                        local mPos = mini.Position
                        VFX.SmallExplode(mPos, bombFolder)
                        SFX.PlayAt("SmallExplosion", mPos, {Volume = 0.7, PlaybackSpeed = 1.1 + math.random() * 0.3})
                        damageAndKnockback(mPos, Config.BOMB_BLAST_RADIUS * 0.5, Config.BOMB_DAMAGE * 0.4, 55, "cluster")
                        MapManager.DestroyAt(mPos, 1, 1, currentDestroyChance)
                        createScorchMark(mPos)
                        GameEvents.BombLanded:FireAllClients(mPos)
                        mini:Destroy()
                    end)
                    Debris:AddItem(mini, 5)
                end)
            end
        end)
        Debris:AddItem(bomb, 10)
    end)
end

---------- HAZARD PICKER ----------
local function pickHazard(difficulty)
    local roll = math.random()
    local bouncingChance = math.clamp(0.08 + difficulty * 0.03, 0, 0.25)
    local timedChance = math.clamp(0.05 + difficulty * 0.03, 0, 0.20)
    local clusterChance = math.clamp(0.03 + difficulty * 0.04, 0, 0.20)
    if roll < clusterChance then return spawnClusterBomb
    elseif roll < clusterChance + timedChance then return spawnTimedBomb
    elseif roll < clusterChance + timedChance + bouncingChance then return spawnBouncingBomb
    else return nil end
end

---------- GUIDED MISSILE SYSTEM ----------
-- A homing missile that targets a specific player, forcing movement.
-- Uses stepped re-targeting (updates direction every 0.4s) for readable, jukeble tracking.
-- Max 1 missile active at a time. Self-destructs after 4 seconds.

local missileActive = false
local lastMissileTarget = nil
local MISSILE_SPEED = 55           -- studs/sec (faster than player's 16-20, can't outrun straight)
local MISSILE_RETARGET = 0.4       -- seconds between direction corrections
local MISSILE_LIFETIME = 4.0       -- max seconds before self-destruct
local MISSILE_LOCKON_TIME = 1.5    -- warning before launch
local MISSILE_DAMAGE = 48          -- reduced from 55: fair with matador dodge          -- slightly higher than standard bomb (40)
local MISSILE_BLAST_RADIUS = 14    -- reduced from 20: makes dodge possible with skill    -- bigger blast than standard (16)
local MISSILE_KNOCKBACK = 100      -- strong knockback

local function pickMissileTarget()
    local alive = {}
    for _, p in ipairs(Players:GetPlayers()) do
        local char = p.Character
        if char then
            local hum = char:FindFirstChild("Humanoid")
            if hum and hum.Health > 0 then
                table.insert(alive, p)
            end
        end
    end
    if #alive == 0 then return nil end
    -- Fairness: avoid targeting the same player twice in a row
    if #alive > 1 and lastMissileTarget then
        local candidates = {}
        for _, p in ipairs(alive) do
            if p ~= lastMissileTarget then table.insert(candidates, p) end
        end
        if #candidates > 0 then
            local pick = candidates[math.random(#candidates)]
            lastMissileTarget = pick
            return pick
        end
    end
    local pick = alive[math.random(#alive)]
    lastMissileTarget = pick
    return pick
end

local function spawnGuidedMissile()
    if missileActive then return end
    local target = pickMissileTarget()
    if not target or not target.Character then return end

    missileActive = true

    -- PHASE 1: Lock-on warning (1.5s)
    GameEvents.MissileLockOn:FireAllClients(target.Name, "lockon_start")

    local targetHRP = target.Character:FindFirstChild("HumanoidRootPart")
    if not targetHRP then missileActive = false; return end

    for i = 1, 3 do
        task.wait(MISSILE_LOCKON_TIME / 3)
        local tChar = target.Character
        local tHRP = tChar and tChar:FindFirstChild("HumanoidRootPart")
        if not tHRP then
            GameEvents.MissileLockOn:FireAllClients(target.Name, "lockon_cancel")
            missileActive = false
            return
        end
        SFX.PlayAt("WarningBeep", tHRP.Position, {
            Volume = 0.5 + i * 0.15,
            PlaybackSpeed = 1.0 + i * 0.15,
        })
    end

    -- PHASE 2: Spawn missile
    local tChar = target.Character
    local tHRP = tChar and tChar:FindFirstChild("HumanoidRootPart")
    if not tHRP then
        GameEvents.MissileLockOn:FireAllClients(target.Name, "lockon_cancel")
        missileActive = false
        return
    end

    local launchPos = tHRP.Position + Vector3.new(math.random(-30, 30), 70, math.random(-30, 30))
    local initDir = (tHRP.Position - launchPos).Unit

    GameEvents.MissileLockOn:FireAllClients(target.Name, "missile_launched")

    local missile = Instance.new("Part")
    missile.Name = "GuidedMissile"
    missile.Size = Vector3.new(1.5, 1.5, 4)
    missile.Color = Color3.fromRGB(255, 80, 30)
    missile.Material = Enum.Material.Neon
    missile.CFrame = CFrame.new(launchPos, launchPos + initDir)
    missile.Anchored = true
    missile.CanCollide = false
    missile.Parent = bombFolder

    local glow = Instance.new("PointLight")
    glow.Color = Color3.fromRGB(255, 120, 30)
    glow.Brightness = 3; glow.Range = 25
    glow.Parent = missile

    local trail = Instance.new("ParticleEmitter")
    trail.Color = ColorSequence.new(Color3.fromRGB(255, 200, 100), Color3.fromRGB(100, 100, 100))
    trail.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1.5),
        NumberSequenceKeypoint.new(0.3, 3),
        NumberSequenceKeypoint.new(1, 5),
    })
    trail.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.2),
        NumberSequenceKeypoint.new(0.5, 0.5),
        NumberSequenceKeypoint.new(1, 1),
    })
    trail.Lifetime = NumberRange.new(0.8, 1.5)
    trail.Speed = NumberRange.new(2, 6)
    trail.SpreadAngle = Vector2.new(15, 15)
    trail.Acceleration = Vector3.new(0, 8, 0)
    trail.RotSpeed = NumberRange.new(-60, 60)
    trail.Rate = 40
    trail.LightEmission = 0.4
    trail.EmissionDirection = Enum.NormalId.Back
    trail.Parent = missile

    -- PHASE 3: Flight loop with matador mechanic
    local elapsed = 0
    local lastRetarget = 0
    local currentDir = initDir
    local step = 1/30
    local committed = false      -- true when missile stops re-targeting (close range)
    local commitTime = 0         -- when the missile committed
    local currentSpeed = MISSILE_SPEED

    while elapsed < MISSILE_LIFETIME and missile and missile.Parent do
        elapsed = elapsed + step

        -- Check distance to target for matador mechanic
        local tc = target.Character
        local th = tc and tc:FindFirstChild("HumanoidRootPart")
        local distToTarget = th and (th.Position - missile.Position).Magnitude or 999

        if not committed then
            -- Re-target every 0.4s (stepped, predictable)
            if elapsed - lastRetarget >= MISSILE_RETARGET then
                lastRetarget = elapsed
                local hu = tc and tc:FindFirstChild("Humanoid")
                if th and hu and hu.Health > 0 then
                    local toTarget = (th.Position - missile.Position)
                    if toTarget.Magnitude > 2 then
                        currentDir = toTarget.Unit
                    end
                end
                GameEvents.MissileUpdate:FireAllClients(missile.Position, currentDir)
            end

            -- MATADOR: Within 12 studs, commit direction + slow down
            if distToTarget < 16 and elapsed > 0.5 then
                committed = true
                commitTime = elapsed
                currentSpeed = MISSILE_SPEED * 0.65  -- 35% slower
                GameEvents.MissileUpdate:FireAllClients(missile.Position, currentDir)
            end
        else
            -- Committed: no re-targeting, gradually slow further
            local commitElapsed = elapsed - commitTime
            currentSpeed = MISSILE_SPEED * math.max(0.4, 0.65 - commitElapsed * 0.1)

            -- Self-destruct 1.5s after committing if no impact
            if commitElapsed > 1.5 then
                break
            end
        end

        -- Move missile
        local newPos = missile.Position + currentDir * currentSpeed * step
        missile.CFrame = CFrame.new(newPos, newPos + currentDir)

        -- Ground collision: raycast down from missile (only hit map terrain, not walls)
        local groundRayParams = RaycastParams.new()
        groundRayParams.FilterType = Enum.RaycastFilterType.Include
        local groundFilter = {}
        local mapGnd = workspace:FindFirstChild("Map")
        if mapGnd then table.insert(groundFilter, mapGnd) end
        groundRayParams.FilterDescendantsInstances = groundFilter
        local rayOrigin = newPos + Vector3.new(0, 2, 0)
        local rayResult = workspace:Raycast(rayOrigin, Vector3.new(0, -5, 0), groundRayParams)
        if rayResult and (newPos.Y - rayResult.Position.Y) < 2 then
            break
        end

        -- Forward raycast: detect terrain ahead (exclude invisible walls, lobby, players)
        local missileRayParams = RaycastParams.new()
        missileRayParams.FilterType = Enum.RaycastFilterType.Include
        local missileFilter = {}
        local mapF = workspace:FindFirstChild("Map")
        if mapF then table.insert(missileFilter, mapF) end
        missileRayParams.FilterDescendantsInstances = missileFilter
        local fwdResult = workspace:Raycast(newPos, currentDir * currentSpeed * step * 2, missileRayParams)
        if fwdResult then
            -- Hit map terrain - explode at impact point
            missile.CFrame = CFrame.new(fwdResult.Position, fwdResult.Position + currentDir)
            break
        end

        -- Absolute floor fallback
        if newPos.Y <= -10 then break end

        -- Player proximity (direct hit = 4 studs)
        -- Player proximity (direct hit = 4 studs)
        local hitPlayer = false
        for _, p in ipairs(Players:GetPlayers()) do
            local c = p.Character
            local h = c and c:FindFirstChild("HumanoidRootPart")
            if h and (h.Position - newPos).Magnitude < 4 then
                hitPlayer = true; break
            end
        end
        if hitPlayer then break end

        -- Arena bounds
        local bounds = MapManager.GetBounds()
        if math.abs(newPos.X) > bounds + 20 or math.abs(newPos.Z) > bounds + 20 then
            break
        end

        task.wait(step)
    end

    -- PHASE 4: EXPLODE (always fires if missile still exists)
    local explodePos = missile and missile.Parent and missile.Position or nil
    if missile and missile.Parent then
        missile:Destroy()
    end

    if explodePos then
        VFX.Explode(explodePos, MISSILE_BLAST_RADIUS, bombFolder, "missile")
        SFX.PlayAt("Explosion", explodePos, {Volume = 0.9, PlaybackSpeed = 0.75})
        damageAndKnockback(explodePos, MISSILE_BLAST_RADIUS, MISSILE_DAMAGE, MISSILE_KNOCKBACK, "missile")
        MapManager.DestroyAt(explodePos, 2, 2, currentDestroyChance * 1.3)
        createScorchMark(explodePos)
        GameEvents.BombLanded:FireAllClients(explodePos)
    end

    GameEvents.MissileLockOn:FireAllClients(target.Name, "missile_exploded")
    missileActive = false
end

---------- MAIN LOOP WITH MID-ROUND PAUSE ----------
binds:WaitForChild("StartBombs").Event:Connect(function(difficulty, hotZone, destroyChance, roundNum)
    spawning = true
    difficulty = difficulty or 1

    currentHotZone = hotZone or "NW"
    currentDestroyChance = destroyChance or Config.DESTROY_CHANCE_BASE or 0.40    for _, c in ipairs(bombFolder:GetChildren()) do c:Destroy() end
    roundNum = roundNum or 1

    -- A2: Late-round qualitative escalation (matched to exponential curve)
    -- R1-R3: Normal. R4: First pressure. R5: Intense. R6: Overwhelming. R7: Final stand.
    if roundNum >= 7 then
        currentWarnScale = 0.6; currentScorchLifetime = 18
    elseif roundNum >= 6 then
        currentWarnScale = 0.72; currentScorchLifetime = 14
    elseif roundNum >= 5 then
        currentWarnScale = 0.82; currentScorchLifetime = 11
    elseif roundNum >= 4 then
        currentWarnScale = 0.92; currentScorchLifetime = 10
    else
        currentWarnScale = 1.0; currentScorchLifetime = 9
    end
    local elapsed = 0
    local wave1Done = false
    local wave2Done = false

    while spawning do
                local progress = math.clamp(elapsed / Config.ROUND_DURATION, 0, 1)
        local baseInterval = Config.BOMB_INTERVAL_BASE / difficulty
        local curve = progress * progress  -- exponential: slow start, frantic finish
        local interval = baseInterval + (Config.BOMB_INTERVAL_MIN - baseInterval) * curve
        interval = math.max(interval, Config.BOMB_INTERVAL_MIN)

        -- Guided missile: periodic check (async, doesn't replace bombs)
        if not missileActive and roundNum and roundNum >= 3 then
            local missileChance = roundNum >= 5 and 0.15 or (roundNum >= 4 and 0.10 or 0.05)
            if elapsed > 3 and math.random() < missileChance * interval then
                task.spawn(spawnGuidedMissile)
            end
        end
        -- MID-ROUND PRESSURE SPIKES: two waves for sustained tension
        if not wave1Done and progress >= 0.38 then
            wave1Done = true
            for _ = 1, 3 do
                spawnStandardBomb()
                task.wait(0.15)
            end
            elapsed = elapsed + 0.45
        end
        if not wave2Done and progress >= 0.68 then
            wave2Done = true
            for _ = 1, 3 do
                local specialSpawn2 = pickHazard(difficulty)
                if specialSpawn2 then specialSpawn2() else spawnStandardBomb() end
                task.wait(0.15)
            end
            elapsed = elapsed + 0.45
        end
        local specialSpawn = pickHazard(difficulty)
        if specialSpawn then specialSpawn() else spawnStandardBomb() end

        task.wait(interval)
        elapsed = elapsed + interval
    end
end)

binds:WaitForChild("StopBombs").Event:Connect(function()
    missileActive = false
    spawning = false
    -- Quick chain-detonate visible bombs instead of silent delete
    task.delay(0.1, function()
        local bombs = {}
        for _, c in ipairs(bombFolder:GetChildren()) do
            if c:IsA("Model") and c.Name == "ActiveBomb" then
                local body = c.PrimaryPart
                if body then table.insert(bombs, {model = c, pos = body.Position}) end
            end
        end
        -- Staggered mini-explosions (fast, satisfying "all clear" feel)
        for i, b in ipairs(bombs) do
            task.delay(i * 0.04, function()
                VFX.SmallExplode(b.pos, bombFolder)
                SFX.PlayAt("SmallExplosion", b.pos, {Volume = 0.3, PlaybackSpeed = 1.2 + math.random() * 0.4})
                if b.model and b.model.Parent then b.model:Destroy() end
            end)
        end
        -- Clean up everything else (warnings, scorch marks, etc)
        task.delay(#bombs * 0.04 + 0.3, function()
            for _, c in ipairs(bombFolder:GetChildren()) do c:Destroy() end
        end)
    end)
end)

print("[BombSystem v14] Ready — hot zone bias, probabilistic destruction!")
