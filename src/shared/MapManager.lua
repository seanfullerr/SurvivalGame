-- MapManager v5: Indestructible bedrock, lava recesses, organic pools, VFX
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS:WaitForChild("GameConfig"))
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local MapManager = {}
local lavaPositions = {}   -- grid key -> {y, worldX, worldZ}
local lavaLights = {}      -- grid key -> PointLight (for dynamic brightness)
local isLavaAt = {}        -- [x][z] = true
local G, T = Config.GRID, Config.TILE
local halfArena = (G * T) / 2

local debrisFolder = workspace:FindFirstChild("MapDebris")
if not debrisFolder then
    debrisFolder = Instance.new("Folder")
    debrisFolder.Name = "MapDebris"
    debrisFolder.Parent = workspace
end

---------- TIER MAP ----------
local tierMap = {}
local layerCount = {}

local function generateTierMap(seed)
    math.randomseed(seed)
    tierMap = {}
    layerCount = {}

    for x = 0, G-1 do
        tierMap[x] = {}
        layerCount[x] = {}
        for z = 0, G-1 do
            tierMap[x][z] = "mid"
            layerCount[x][z] = Config.LAYERS_MID
        end
    end

    local highCount = math.random(2, 3)
    for i = 1, highCount do
        local cx = math.random(4, G-5)
        local cz = math.random(4, G-5)
        local radius = math.random(2, 4)
        for x = 0, G-1 do
            for z = 0, G-1 do
                local dist = math.sqrt((x - cx)^2 + (z - cz)^2)
                if dist < radius - 0.5 or (dist < radius + 0.5 and math.random() < 0.5) then
                    tierMap[x][z] = "high"
                    layerCount[x][z] = Config.LAYERS_HIGH
                end
            end
        end
    end

    local basinCount = math.random(1, 2)
    for i = 1, basinCount do
        local cx = math.random(3, G-4)
        local cz = math.random(3, G-4)
        local radius = math.random(3, 5)
        for x = 0, G-1 do
            for z = 0, G-1 do
                if tierMap[x][z] ~= "high" then
                    local dist = math.sqrt((x - cx)^2 + (z - cz)^2)
                    if dist < radius - 0.5 or (dist < radius + 0.5 and math.random() < 0.4) then
                        tierMap[x][z] = "low"
                        layerCount[x][z] = Config.LAYERS_LOW
                    end
                end
            end
        end
    end

    local channelCount = math.random(2, 3)
    for i = 1, channelCount do
        local cx, cz = math.random(2, G-3), math.random(2, G-3)
        local dir = math.random() * math.pi * 2
        local length = math.random(8, 14)
        for step = 0, length do
            local gx = math.floor(cx + math.cos(dir) * step + 0.5)
            local gz = math.floor(cz + math.sin(dir) * step + 0.5)
            dir = dir + (math.random() - 0.5) * 0.6
            for dx = -1, 1 do
                for dz = -1, 1 do
                    local tx, tz = gx + dx, gz + dz
                    if tx >= 0 and tx < G and tz >= 0 and tz < G then
                        if tierMap[tx][tz] ~= "high" then
                            if dx == 0 and dz == 0 then
                                tierMap[tx][tz] = "low"; layerCount[tx][tz] = Config.LAYERS_LOW
                            elseif math.random() < 0.4 then
                                tierMap[tx][tz] = "low"; layerCount[tx][tz] = Config.LAYERS_LOW
                            end
                        end
                    end
                end
            end
        end
    end

    local counts = {high = 0, mid = 0, low = 0}
    for x = 0, G-1 do for z = 0, G-1 do
        counts[tierMap[x][z]] = counts[tierMap[x][z]] + 1
    end end
    print("[MapManager] Tier distribution: HIGH=" .. counts.high
        .. " MID=" .. counts.mid .. " LOW=" .. counts.low
        .. " (total " .. G*G .. ")")
end

---------- HELPERS ----------
local function getTierY(tier)
    if tier == "high" then return Config.TIER_HIGH_Y
    elseif tier == "low" then return Config.TIER_LOW_Y
    else return Config.TIER_MID_Y end
end

local function worldToGrid(worldX, worldZ)
    local gx = math.floor((worldX + halfArena) / T)
    local gz = math.floor((worldZ + halfArena) / T)
    return math.clamp(gx, 0, G-1), math.clamp(gz, 0, G-1)
end

-- Get bedrock top Y for a given tier (= bottom of last destructible layer)
local function getBedrockTop(tier)
    local baseY = getTierY(tier)
    local layers = ({high = Config.LAYERS_HIGH, mid = Config.LAYERS_MID, low = Config.LAYERS_LOW})[tier]
    -- Bedrock occupies the last layer position; its top = last destructible bottom
    -- Destructible layers = 1 to (layers-1)
    -- Last destructible center = baseY + T/2 - (layers-2)*T, bottom = that - T/2
    return baseY + T/2 - (layers - 2) * T - T/2
end

---------- FLOOD FILL for organic pools ----------
local function findLavaPools()
    local visited = {}
    local pools = {}
    for x = 0, G-1 do visited[x] = {} end

    for x = 0, G-1 do
        for z = 0, G-1 do
            if isLavaAt[x] and isLavaAt[x][z] and not visited[x][z] then
                local pool = {}
                local queue = {{x, z}}
                visited[x][z] = true
                while #queue > 0 do
                    local cell = table.remove(queue, 1)
                    local cx, cz = cell[1], cell[2]
                    table.insert(pool, {x = cx, z = cz})
                    for _, d in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
                        local nx, nz = cx + d[1], cz + d[2]
                        if nx >= 0 and nx < G and nz >= 0 and nz < G then
                            if isLavaAt[nx] and isLavaAt[nx][nz] and not visited[nx][nz] then
                                visited[nx][nz] = true
                                table.insert(queue, {nx, nz})
                            end
                        end
                    end
                end
                table.insert(pools, pool)
            end
        end
    end
    return pools
end

---------- BUILD MAP ----------
function MapManager.BuildMap()
    local old = workspace:FindFirstChild("Map")
    if old then old:Destroy() end
    debrisFolder:ClearAllChildren()
    workspace.Terrain:Clear()
    lavaPositions = {}
    lavaLights = {}
    isLavaAt = {}

    local seed = math.random(1, 10000)
    generateTierMap(seed)

    local mapFolder = Instance.new("Folder")
    mapFolder.Name = "Map"
    mapFolder.Parent = workspace

    local terrain = workspace.Terrain

    -- Pre-roll lava positions (LOW tier only)
    math.randomseed(seed + 999)
    for x = 0, G-1 do
        isLavaAt[x] = {}
        for z = 0, G-1 do
            if tierMap[x][z] == "low" and math.random() < Config.LAVA_COVERAGE then
                isLavaAt[x][z] = true
            end
        end
    end

    -- ========== DESTRUCTIBLE LAYERS (1 to maxLayers-1) ==========
    for x = 0, G-1 do
        for z = 0, G-1 do
            local tier = tierMap[x][z]
            local baseY = getTierY(tier)
            local layers = layerCount[x][z]
            local destructibleCount = layers - 1  -- last layer = bedrock (separate)

            for layer = 1, destructibleCount do
                local lf = mapFolder:FindFirstChild("Layer" .. layer)
                if not lf then
                    lf = Instance.new("Folder"); lf.Name = "Layer" .. layer; lf.Parent = mapFolder
                end

                local tileY = baseY + T/2 - (layer - 1) * T
                local colorIdx = math.min(layer, #Config.LAYER_COLORS)
                local colors = Config.LAYER_COLORS[colorIdx]
                local mat = Config.LAYER_MATERIALS[colorIdx]

                local tile = Instance.new("Part")
                tile.Name = "T" .. layer .. "_" .. x .. "_" .. z
                tile.Size = Vector3.new(T, T, T)
                tile.Position = Vector3.new((x - G/2 + 0.5) * T, tileY, (z - G/2 + 0.5) * T)
                tile.Anchored = true
                tile.Material = mat
                tile.Color = colors[((x + z) % 2) + 1]
                tile.Parent = lf

                -- Crack decals on bottom destructible layer above lava
                if layer == destructibleCount and isLavaAt[x] and isLavaAt[x][z] then
                    local decal = Instance.new("Decal")
                    decal.Face = Enum.NormalId.Bottom
                    decal.Texture = "rbxassetid://4693722498"
                    decal.Transparency = 0.5
                    decal.Color3 = Color3.fromRGB(255, 120, 30)
                    decal.Parent = tile
                end
            end
        end
    end

    -- ========== INDESTRUCTIBLE BEDROCK FLOOR ==========
    -- Placed in "Bedrock" folder — DestroyAt never touches this folder.
    -- For lava cells: skip the bedrock tile, place terrain lava instead.
    local bedrockFolder = Instance.new("Folder")
    bedrockFolder.Name = "Bedrock"
    bedrockFolder.Parent = mapFolder

    local bedrockCount, lavaSkipCount = 0, 0
    for x = 0, G-1 do
        for z = 0, G-1 do
            local tier = tierMap[x][z]
            local baseY = getTierY(tier)
            local layers = layerCount[x][z]
            -- Bedrock position = same as old bottom layer
            local bedrockCenterY = baseY + T/2 - (layers - 1) * T
            local worldX = (x - G/2 + 0.5) * T
            local worldZ = (z - G/2 + 0.5) * T

            if isLavaAt[x] and isLavaAt[x][z] then
                -- LAVA CELL: no bedrock tile here — terrain lava fills the space
                lavaSkipCount = lavaSkipCount + 1
            else
                -- SOLID BEDROCK tile
                local rock = Instance.new("Part")
                rock.Name = "Bedrock_" .. x .. "_" .. z
                rock.Size = Vector3.new(T, T, T)
                rock.Position = Vector3.new(worldX, bedrockCenterY, worldZ)
                rock.Anchored = true
                rock.Material = Enum.Material.Basalt
                -- Dark bedrock with subtle checkerboard
                if (x + z) % 2 == 0 then
                    rock.Color = Color3.fromRGB(45, 42, 48)
                else
                    rock.Color = Color3.fromRGB(38, 35, 40)
                end
                rock.Parent = bedrockFolder
                bedrockCount = bedrockCount + 1
            end
        end
    end
    print("[MapManager] Bedrock tiles: " .. bedrockCount .. ", lava recesses: " .. lavaSkipCount)

    -- ========== ORGANIC LAVA POOLS (merged terrain in bedrock recesses) ==========
    local lavaVFXFolder = Instance.new("Folder")
    lavaVFXFolder.Name = "LavaVFX"
    lavaVFXFolder.Parent = mapFolder

    local pools = findLavaPools()
    local totalLavaCells = 0

    for _, pool in ipairs(pools) do
        local minX, maxX, minZ, maxZ = G, 0, G, 0
        for _, cell in ipairs(pool) do
            minX = math.min(minX, cell.x); maxX = math.max(maxX, cell.x)
            minZ = math.min(minZ, cell.z); maxZ = math.max(maxZ, cell.z)
        end

        -- Fill terrain lava in merged row-strips for organic shapes
        for row = minX, maxX do
            local runStart = nil
            for col = minZ, maxZ + 1 do
                local inPool = false
                for _, cell in ipairs(pool) do
                    if cell.x == row and cell.z == col then inPool = true; break end
                end

                if inPool and not runStart then
                    runStart = col
                elseif not inPool and runStart then
                    local layers = Config.LAYERS_LOW
                    local baseY = getTierY("low")
                    local bedrockCenterY = baseY + T/2 - (layers - 1) * T
                    local bedrockTop = bedrockCenterY + T/2

                    -- Lava sits 1 stud recessed from bedrock top (shallow pool)
                    local lavaTop = bedrockTop - 1
                    local lavaHeight = T - 2  -- fills most of bedrock space
                    local lavaCenterY = lavaTop - lavaHeight / 2

                    local runLen = col - runStart
                    local centerX = (row - G/2 + 0.5) * T
                    local centerZ = ((runStart + col - 1) / 2 - G/2 + 0.5) * T

                    -- Slight random offset for organic feel
                    local offX = (math.random() - 0.5) * 1.2
                    local offZ = (math.random() - 0.5) * 0.8

                    -- Oversize to merge seams between adjacent cells
                    local sizeX = T + 1.0
                    local sizeZ = runLen * T + 1.0

                    terrain:FillBlock(
                        CFrame.new(Vector3.new(centerX + offX, lavaCenterY, centerZ + offZ)),
                        Vector3.new(sizeX, lavaHeight, sizeZ),
                        Enum.Material.CrackedLava
                    )
                    runStart = nil
                end
            end
        end

        -- Per-cell: damage tracking + VFX
        for _, cell in ipairs(pool) do
            local x, z = cell.x, cell.z
            local layers = Config.LAYERS_LOW
            local baseY = getTierY("low")
            local bedrockCenterY = baseY + T/2 - (layers - 1) * T
            local bedrockTop = bedrockCenterY + T/2
            local lavaTop = bedrockTop - 1

            local worldX = (x - G/2 + 0.5) * T
            local worldZ = (z - G/2 + 0.5) * T
            local key = x .. "_" .. z

            lavaPositions[key] = {y = lavaTop, worldX = worldX, worldZ = worldZ}
            totalLavaCells = totalLavaCells + 1

            -- VFX anchor at lava surface
            local anchor = Instance.new("Part")
            anchor.Name = "LavaVFX_" .. x .. "_" .. z
            anchor.Size = Vector3.new(1, 1, 1)
            anchor.Position = Vector3.new(worldX, lavaTop + 0.5, worldZ)
            anchor.Anchored = true; anchor.CanCollide = false; anchor.Transparency = 1
            anchor.Parent = lavaVFXFolder

            -- POINT LIGHT: orange glow, starts subtle, intensifies as tiles break
            local light = Instance.new("PointLight")
            light.Color = Color3.fromRGB(255, 100, 30)
            light.Brightness = 0.6
            light.Range = 20
            light.Parent = anchor
            lavaLights[key] = light

            -- EMBER PARTICLES
            local att = Instance.new("Attachment")
            att.Parent = anchor

            local embers = Instance.new("ParticleEmitter")
            embers.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 160, 50)),
                ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 70, 15)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(100, 25, 5)),
            })
            embers.Size = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.5),
                NumberSequenceKeypoint.new(0.4, 0.3),
                NumberSequenceKeypoint.new(1, 0.05),
            })
            embers.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.2),
                NumberSequenceKeypoint.new(0.6, 0.5),
                NumberSequenceKeypoint.new(1, 1),
            })
            embers.Lifetime = NumberRange.new(2.0, 4.0)
            embers.Speed = NumberRange.new(6, 14)
            embers.SpreadAngle = Vector2.new(22, 22)
            embers.Acceleration = Vector3.new(0, 2.5, 0)
            embers.RotSpeed = NumberRange.new(-40, 40)
            embers.Rate = 6
            embers.LightEmission = 0.7
            embers.LightInfluence = 0.2
            embers.Parent = att

            -- HEAT HAZE
            local hazeAtt = Instance.new("Attachment")
            hazeAtt.Position = Vector3.new(0, 2, 0)
            hazeAtt.Parent = anchor

            local haze = Instance.new("ParticleEmitter")
            haze.Color = ColorSequence.new(Color3.fromRGB(255, 200, 150))
            haze.Size = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 2.5),
                NumberSequenceKeypoint.new(0.5, 3.5),
                NumberSequenceKeypoint.new(1, 2.0),
            })
            haze.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.92),
                NumberSequenceKeypoint.new(0.5, 0.88),
                NumberSequenceKeypoint.new(1, 1),
            })
            haze.Lifetime = NumberRange.new(2.5, 4.5)
            haze.Speed = NumberRange.new(1.5, 3.5)
            haze.SpreadAngle = Vector2.new(15, 15)
            haze.Acceleration = Vector3.new(0, 1, 0)
            haze.Rate = 1.5
            haze.LightEmission = 0.3
            haze.LightInfluence = 0.5
            haze.LockedToPart = false
            haze.Parent = hazeAtt

            -- AMBIENT SOUND every 3rd cell
            if totalLavaCells % 3 == 0 then
                local snd = Instance.new("Sound")
                snd.SoundId = "rbxassetid://31758982"
                snd.Volume = 0.12; snd.Looped = true
                snd.RollOffMaxDistance = 40; snd.RollOffMinDistance = 8
                snd.PlaybackSpeed = 0.8 + math.random() * 0.4
                snd.Parent = anchor; snd:Play()
            end
        end
    end

    print("[MapManager] Lava pools: " .. #pools .. " pools, " .. totalLavaCells .. " cells")

    -- ========== RAMPS ==========
    local rampFolder = Instance.new("Folder")
    rampFolder.Name = "Ramps"
    rampFolder.Parent = mapFolder

    local function buildRamp(x1, z1, x2, z2, fromY, toY, width)
        local steps = math.max(math.abs(x2-x1), math.abs(z2-z1))
        if steps == 0 then return end
        local heightStep = (toY - fromY) / steps
        local dx = (x2 - x1) / steps; local dz = (z2 - z1) / steps
        for s = 0, steps do
            local gx = math.floor(x1 + dx * s + 0.5)
            local gz = math.floor(z1 + dz * s + 0.5)
            local y = fromY + heightStep * s
            for w = 0, width - 1 do
                local wx, wz = gx, gz
                if math.abs(dx) > math.abs(dz) then wz = gz + w - math.floor(width/2)
                else wx = gx + w - math.floor(width/2) end
                if wx >= 0 and wx < G and wz >= 0 and wz < G then
                    local ramp = Instance.new("Part")
                    ramp.Name = "Ramp_" .. wx .. "_" .. wz .. "_" .. s
                    ramp.Size = Vector3.new(T, T * 0.5, T)
                    ramp.Position = Vector3.new((wx - G/2 + 0.5) * T, y, (wz - G/2 + 0.5) * T)
                    ramp.Anchored = true; ramp.Material = Enum.Material.Concrete
                    ramp.Color = Color3.fromRGB(160, 155, 145)
                    ramp.Parent = rampFolder
                end
            end
        end
    end

    local function findTierEdges(fromTier, toTier)
        local edges = {}
        for x = 1, G-2 do for z = 1, G-2 do
            if tierMap[x][z] == fromTier then
                for _, d in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
                    local nx, nz = x + d[1], z + d[2]
                    if nx >= 0 and nx < G and nz >= 0 and nz < G and tierMap[nx][nz] == toTier then
                        table.insert(edges, {x=x, z=z, nx=nx, nz=nz, dx=d[1], dz=d[2]})
                    end
                end
            end
        end end
        return edges
    end

    local highEdges = findTierEdges("mid", "high")
    if #highEdges > 0 then
        for i = 1, math.min(Config.RAMPS_PER_CONNECTION, #highEdges) do
            local e = highEdges[math.random(#highEdges)]
            buildRamp(e.x - e.dx*3, e.z - e.dz*3, e.nx + e.dx, e.nz + e.dz,
                getTierY("mid") + T/2, getTierY("high") + T/2, Config.RAMP_WIDTH)
        end
    end
    local lowEdges = findTierEdges("mid", "low")
    if #lowEdges > 0 then
        for i = 1, math.min(Config.RAMPS_PER_CONNECTION, #lowEdges) do
            local e = lowEdges[math.random(#lowEdges)]
            buildRamp(e.x - e.dx*2, e.z - e.dz*2, e.nx + e.dx, e.nz + e.dz,
                getTierY("mid") + T/2, getTierY("low") + T/2, Config.RAMP_WIDTH)
        end
    end
    print("[MapManager] Ramps placed")
    return mapFolder
end

---------- QUERIES ----------
function MapManager.GetTierAt(worldX, worldZ)
    local gx, gz = worldToGrid(worldX, worldZ)
    return tierMap[gx] and tierMap[gx][gz] or "mid"
end

function MapManager.GetSurfaceY(worldX, worldZ)
    local mapFolder = workspace:FindFirstChild("Map")
    if not mapFolder then return 5 end
    local gx, gz = worldToGrid(worldX, worldZ)
    local layers = (layerCount[gx] and layerCount[gx][gz]) or Config.LAYERS_MID
    local destructible = layers - 1
    -- Check destructible layers first
    for layer = 1, destructible do
        local lf = mapFolder:FindFirstChild("Layer" .. layer)
        if lf then
            local tile = lf:FindFirstChild("T" .. layer .. "_" .. gx .. "_" .. gz)
            if tile then return tile.Position.Y + T/2 end
        end
    end
    -- All destructible gone -> return bedrock top
    local tier = (tierMap[gx] and tierMap[gx][gz]) or "mid"
    return getBedrockTop(tier)
end

---------- DESTRUCTION (bedrock is NEVER destroyed) ----------
local function destroyTile(tile, worldPos, layer)
    tile.Parent = debrisFolder
    tile.Anchored = false; tile.CanCollide = false
    local dir = (tile.Position - worldPos)
    if dir.Magnitude < 0.5 then dir = Vector3.new(math.random()-0.5, 1, math.random()-0.5) end
    dir = dir.Unit
    local bv = Instance.new("BodyVelocity")
    bv.Velocity = dir * math.random(12, 25) + Vector3.new(0, math.random(8, 18), 0)
    bv.MaxForce = Vector3.new(4000, 4000, 4000)
    bv.Parent = tile; Debris:AddItem(bv, 0.25)
    TweenService:Create(tile,
        TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        {Size = Vector3.new(0.5, 0.5, 0.5), Transparency = 1}
    ):Play()
    Debris:AddItem(tile, 2)
end

-- Dynamic light: brightens as tiles above lava are destroyed
local function updateLavaLightForCell(gx, gz)
    local key = gx .. "_" .. gz
    local light = lavaLights[key]
    if not light then return end
    local mapFolder = workspace:FindFirstChild("Map")
    if not mapFolder then return end

    local layers = (layerCount[gx] and layerCount[gx][gz]) or Config.LAYERS_LOW
    local destructible = layers - 1
    local remaining = 0
    for layer = 1, destructible do
        local lf = mapFolder:FindFirstChild("Layer" .. layer)
        if lf and lf:FindFirstChild("T" .. layer .. "_" .. gx .. "_" .. gz) then
            remaining = remaining + 1
        end
    end

    -- 0.6 (all intact) -> 1.5 (half gone) -> 3.0 (fully exposed)
    local ratio = 1 - (remaining / destructible)
    local targetBrightness = 0.6 + ratio * 2.4
    local targetRange = 20 + ratio * 12

    TweenService:Create(light,
        TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Brightness = targetBrightness, Range = targetRange}
    ):Play()
end

-- DESTRUCTION: only layers 1 to (maxLayers-1). Bedrock folder untouched.
function MapManager.DestroyAt(worldPos, tileRadius, depthLayers, destroyChance)
    local mapFolder = workspace:FindFirstChild("Map")
    if not mapFolder then return end
    depthLayers = depthLayers or 2; destroyChance = destroyChance or 0.40
    local cx, cz = worldToGrid(worldPos.X, worldPos.Z)

    for dx = -tileRadius, tileRadius do
        for dz = -tileRadius, tileRadius do
            if dx*dx + dz*dz <= tileRadius*tileRadius + 1 then
                local gx, gz = cx + dx, cz + dz
                if gx >= 0 and gx < G and gz >= 0 and gz < G then
                    if math.random() < destroyChance then
                        local destroyed = 0
                        local maxLayers = (layerCount[gx] and layerCount[gx][gz]) or Config.LAYERS_MID
                        local destructible = maxLayers - 1  -- NEVER touch bedrock

                        for layer = 1, destructible do
                            if destroyed >= depthLayers then break end
                            local lf = mapFolder:FindFirstChild("Layer" .. layer)
                            if lf then
                                local tile = lf:FindFirstChild("T" .. layer .. "_" .. gx .. "_" .. gz)
                                if tile then
                                    local dist = math.sqrt(dx*dx + dz*dz)
                                    task.delay(dist * 0.08, function()
                                        if tile.Parent then
                                            destroyTile(tile, worldPos, layer)
                                        end
                                    end)
                                    destroyed = destroyed + 1
                                end
                            end
                        end

                        if isLavaAt[gx] and isLavaAt[gx][gz] then
                            updateLavaLightForCell(gx, gz)
                        end
                    end
                end
            end
        end
    end
end

function MapManager.GetBounds() return halfArena end

function MapManager.GetTileCount()
    local mapFolder = workspace:FindFirstChild("Map")
    if not mapFolder then return 0 end
    local total = 0
    for _, lf in ipairs(mapFolder:GetChildren()) do
        if lf:IsA("Folder") and lf.Name:match("^Layer") then total = total + #lf:GetChildren() end
    end
    return total
end

function MapManager.GetTierMap() return tierMap end

function MapManager.IsOverLava(worldX, worldZ)
    local gx = math.floor(worldX / T + G/2)
    local gz = math.floor(worldZ / T + G/2)
    local key = gx .. "_" .. gz
    return lavaPositions[key] ~= nil, lavaPositions[key]
end

return MapManager
