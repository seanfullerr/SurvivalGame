-- CoinSpawner v4: Reduced density, top-floor bias, smaller coins, cleaner UX
-- Spawns coins on valid map tiles (mid/high tiers, avoids lava)
-- Server-authoritative .Touched collection with debounce + collected flag
-- Rewards routed via CoinManager using AwardCoinPickup BindableEvent
-- Streak system: consecutive pickups within timeout earn multiplied rewards

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local ContentProvider = game:GetService("ContentProvider")
local Config = require(RS:WaitForChild("GameConfig"))
local MapManager = require(RS:WaitForChild("MapManager"))
local GameEvents = RS:WaitForChild("GameEvents")
local binds = RS:WaitForChild("Binds")

-- Preload coin pickup sound so the first collection isn't silent
local COIN_SOUND_ID = "rbxassetid://6895079853"
task.spawn(function()
    local preloadSound = Instance.new("Sound")
    preloadSound.SoundId = COIN_SOUND_ID
    preloadSound.Parent = game:GetService("SoundService")
    pcall(function()
        ContentProvider:PreloadAsync({preloadSound})
    end)
    task.wait(0.5)
    preloadSound:Destroy()
    print("[CoinSpawner] Sound asset preloaded")
end)

---------- CONFIGURATION (from GameConfig, with fallbacks) ----------
local COIN_COUNT = Config.COIN_COUNT or 20
local COIN_RESPAWN_TIME = Config.COIN_RESPAWN_TIME or 12
local COIN_RESPAWN_JITTER = Config.COIN_RESPAWN_JITTER or 3
local COIN_VALUE = Config.COIN_PICKUP_VALUE or 1
local CLUSTER_CHANCE = Config.COIN_CLUSTER_CHANCE or 0.15
local CLUSTER_MIN = 2
local CLUSTER_MAX = 4

-- Streak config
local STREAK_TIMEOUT = Config.COIN_STREAK_TIMEOUT or 2.5
local STREAK_MAX = Config.COIN_STREAK_MAX_MULTIPLIER or 5

---------- STATE ----------
local coinFolder = nil
local activeCoins = {}   -- coin Part -> data table
local heartbeatConn = nil
local collectionDebounce = {}  -- userId -> tick

-- Streak state per player: { count = number, lastPickup = number }
local playerStreaks = {}

---------- STREAK HELPERS ----------
local function getStreak(userId)
    if not playerStreaks[userId] then
        playerStreaks[userId] = { count = 0, lastPickup = 0 }
    end
    return playerStreaks[userId]
end

local function resetStreak(userId)
    playerStreaks[userId] = { count = 0, lastPickup = 0 }
end

local function updateStreak(userId)
    local streak = getStreak(userId)
    local now = tick()
    if streak.count > 0 and (now - streak.lastPickup) <= STREAK_TIMEOUT then
        streak.count = math.min(streak.count + 1, STREAK_MAX)
    else
        streak.count = 1
    end
    streak.lastPickup = now
    return streak.count
end

-- Clean up streak data when player leaves
Players.PlayerRemoving:Connect(function(player)
    playerStreaks[player.UserId] = nil
    collectionDebounce[player.UserId] = nil
end)

---------- SPAWN WEIGHTING ----------
local function getSpawnWeight(tier, gx, gz)
    local weight = 0.6  -- mid tier: lower weight so coins favor top floor
    if tier == "high" then
        weight = 3.5    -- strongly favor top floor for early-round visibility
    elseif tier == "low" then
        weight = 0.2    -- rare spawns in valleys
    end

    local G, T = Config.GRID, Config.TILE
    local nearLava = false
    for dx = -2, 2 do
        if nearLava then break end
        for dz = -2, 2 do
            if not (dx == 0 and dz == 0) then
                local nx, nz = gx + dx, gz + dz
                if nx >= 0 and nx < G and nz >= 0 and nz < G then
                    local wx = (nx - G / 2 + 0.5) * T
                    local wz = (nz - G / 2 + 0.5) * T
                    local isLava = MapManager.IsOverLava(wx, wz)
                    if isLava then
                        weight = weight * 1.4
                        nearLava = true
                        break
                    end
                end
            end
        end
    end

    return weight
end

---------- VALID SPAWN POSITIONS ----------
local function getValidSpawnPositions()
    local positions = {}
    local tierMap = MapManager.GetTierMap()
    if not tierMap then return positions end

    local G, T = Config.GRID, Config.TILE
    for gx = 1, G - 2 do
        for gz = 1, G - 2 do
            local tier = tierMap[gx] and tierMap[gx][gz]
            if tier and tier ~= "low" then
                local worldX = (gx - G / 2 + 0.5) * T
                local worldZ = (gz - G / 2 + 0.5) * T
                local isLava = MapManager.IsOverLava(worldX, worldZ)
                if not isLava then
                    local surfaceY = MapManager.GetSurfaceY(worldX, worldZ)
                    table.insert(positions, {
                        worldX = worldX,
                        worldZ = worldZ,
                        surfaceY = surfaceY,
                        weight = getSpawnWeight(tier, gx, gz),
                        gx = gx,
                        gz = gz,
                    })
                end
            end
        end
    end
    return positions
end

---------- WEIGHTED RANDOM SELECTION ----------
local function weightedSelect(positions, count)
    local selected = {}
    local remaining = {}
    for i, p in ipairs(positions) do
        table.insert(remaining, { idx = i, pos = p, weight = p.weight })
    end

    for _ = 1, math.min(count, #remaining) do
        local totalWeight = 0
        for _, r in ipairs(remaining) do totalWeight = totalWeight + r.weight end
        if totalWeight <= 0 then break end

        local roll = math.random() * totalWeight
        local cumulative = 0
        for j, r in ipairs(remaining) do
            cumulative = cumulative + r.weight
            if roll <= cumulative then
                table.insert(selected, r.pos)
                table.remove(remaining, j)
                break
            end
        end
    end
    return selected
end

---------- CREATE COIN VISUAL ----------
local function createCoin(worldX, surfaceY, worldZ)
    local coin = Instance.new("Part")
    coin.Name = "PickupCoin"
    coin.Shape = Enum.PartType.Cylinder
    coin.Size = Vector3.new(0.5, 2.8, 2.8)
    -- Upright coin: rotate so flat face points sideways (visible from player POV)
    coin.CFrame = CFrame.new(worldX, surfaceY + 3, worldZ)
    coin.Anchored = true
    coin.CanCollide = false
    coin.Material = Enum.Material.SmoothPlastic
    coin.Color = Color3.fromRGB(255, 210, 50)

    local light = Instance.new("PointLight")
    light.Color = Color3.fromRGB(255, 220, 80)
    light.Brightness = 0.4
    light.Range = 6
    light.Parent = coin

    local sound = Instance.new("Sound")
    sound.SoundId = COIN_SOUND_ID
    sound.Volume = 0.5
    sound.PlaybackSpeed = 0.9 + math.random() * 0.2
    sound.RollOffMaxDistance = 40
    sound.Parent = coin

    return coin
end

---------- PICKUP BURST VFX ----------
local function playPickupBurst(position)
    local anchor = Instance.new("Part")
    anchor.Size = Vector3.new(0.5, 0.5, 0.5)
    anchor.Position = position
    anchor.Anchored = true
    anchor.CanCollide = false
    anchor.Transparency = 1
    anchor.Parent = workspace

    local emitter = Instance.new("ParticleEmitter")
    emitter.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 220, 50)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 180, 30)),
    })
    emitter.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1.0),
        NumberSequenceKeypoint.new(1, 0.1),
    })
    emitter.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.2),
        NumberSequenceKeypoint.new(0.6, 0.5),
        NumberSequenceKeypoint.new(1, 1),
    })
    emitter.Lifetime = NumberRange.new(0.3, 0.6)
    emitter.Speed = NumberRange.new(8, 16)
    emitter.SpreadAngle = Vector2.new(360, 360)
    emitter.Rate = 0
    emitter.LightEmission = 0.8
    emitter.Parent = anchor

    emitter:Emit(12)
    Debris:AddItem(anchor, 1.0)
end

---------- COLLECTION HANDLER ----------
local function onCoinTouched(coin, hit)
    local data = activeCoins[coin]
    if not data or data.collected then return end

    local character = hit.Parent
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end
    local player = Players:GetPlayerFromCharacter(character)
    if not player then return end

    -- Per-player debounce (0.15s) to prevent double-collection at high velocity
    local userId = player.UserId
    local now = tick()
    if collectionDebounce[userId] and (now - collectionDebounce[userId]) < 0.15 then return end
    collectionDebounce[userId] = now

    -- Mark collected (server-authoritative, prevents any race)
    data.collected = true

    -- Update streak and calculate multiplied reward
    local streakCount = updateStreak(userId)
    local multiplier = streakCount
    local totalAward = COIN_VALUE * multiplier

    -- Sound
    local snd = coin:FindFirstChildOfClass("Sound")
    if snd then
        -- Pitch up slightly with streak for satisfying audio feedback
        snd.PlaybackSpeed = 0.9 + math.min(streakCount - 1, 4) * 0.08 + math.random() * 0.1
        snd:Play()
    end

    -- Burst VFX
    playPickupBurst(coin.Position)

    -- Award coins via BindableEvent -> CoinManager
    local awardBind = binds:FindFirstChild("AwardCoinPickup")
    if awardBind then
        local reason = "Coin Pickup"
        if streakCount >= 2 then
            reason = streakCount .. "x Streak Pickup"
        end
        awardBind:Fire(player, totalAward, reason)
    end

    -- Notify client HUD of coin earned (amount + total)
    GameEvents.CoinUpdate:FireClient(player, totalAward, nil, "Pickup")

    -- Notify client of streak state (for streak UI)
    if streakCount >= 2 then
        GameEvents.CoinStreak:FireClient(player, streakCount, multiplier)
    end

    -- Hide coin
    coin.Transparency = 1
    local light = coin:FindFirstChildOfClass("PointLight")
    if light then light.Enabled = false end

    -- Schedule respawn with jitter
    local jitter = (math.random() * 2 - 1) * COIN_RESPAWN_JITTER
    local respawnDelay = math.max(COIN_RESPAWN_TIME + jitter, 3)
    task.delay(respawnDelay, function()
        if not coin.Parent or not coinFolder or not coinFolder.Parent then return end
        data.collected = false
        coin.Transparency = 0
        if light then light.Enabled = true end
        data.spinSpeed = 1.5 + math.random() * 1.0
        data.bobAmp = 0.3 + math.random() * 0.2
        data.bobOffset = math.random() * math.pi * 2
    end)
end

---------- SPIN + BOB ANIMATION (single Heartbeat loop) ----------
local function startAnimation()
    if heartbeatConn then heartbeatConn:Disconnect() end
    heartbeatConn = RunService.Heartbeat:Connect(function()
        local t = tick()
        for coin, data in pairs(activeCoins) do
            if coin.Parent and not data.collected and not data.dropping then
                local angle = t * (data.spinSpeed or 2.0)
                local bob = math.sin(t * 2 + (data.bobOffset or 0)) * (data.bobAmp or 0.35)
                coin.CFrame = CFrame.new(data.worldX, data.baseY + bob, data.worldZ)
                    * CFrame.Angles(0, angle, 0)
            end
        end
    end)
end

---------- SPAWN COINS ON MAP ----------
local function spawnCoins()
    -- Clean up previous round
    if coinFolder then coinFolder:Destroy() end
    activeCoins = {}
    collectionDebounce = {}
    if heartbeatConn then heartbeatConn:Disconnect(); heartbeatConn = nil end

    -- Reset all streaks on map rebuild (new round)
    for userId, _ in pairs(playerStreaks) do
        resetStreak(userId)
    end

    coinFolder = Instance.new("Folder")
    coinFolder.Name = "PickupCoins"
    coinFolder.Parent = workspace

    local positions = getValidSpawnPositions()
    if #positions == 0 then
        warn("[CoinSpawner] No valid spawn positions found")
        return
    end

    local baseSpawns = weightedSelect(positions, COIN_COUNT)
    local spawnPoints = {}

    for _, pos in ipairs(baseSpawns) do
        table.insert(spawnPoints, pos)

        if math.random() < CLUSTER_CHANCE then
            local clusterSize = math.random(CLUSTER_MIN - 1, CLUSTER_MAX - 1)
            for _ = 1, clusterSize do
                local offsetX = math.random(-2, 2) * Config.TILE
                local offsetZ = math.random(-2, 2) * Config.TILE
                local cx = pos.worldX + offsetX
                local cz = pos.worldZ + offsetZ
                local isLava = MapManager.IsOverLava(cx, cz)
                if not isLava then
                    local sy = MapManager.GetSurfaceY(cx, cz)
                    if sy and sy > Config.TIER_LOW_Y then
                        table.insert(spawnPoints, {
                            worldX = cx, worldZ = cz, surfaceY = sy,
                            gx = pos.gx, gz = pos.gz,
                        })
                    end
                end
            end
        end
    end

    -- Start animation loop first (coins will join as they appear)
    startAnimation()

    -- Stagger coin spawns: each coin drops from ~5 studs above with a bounce
    local TweenService = game:GetService("TweenService")
    local STAGGER_DELAY = 3.5 / math.max(#spawnPoints, 1) -- spread evenly across 3.5s
    local DROP_HEIGHT = 5 -- studs above target to start

    task.spawn(function()
        for i, pos in ipairs(spawnPoints) do
            if not coinFolder or not coinFolder.Parent then return end -- round ended early

            local targetY = pos.surfaceY + 3
            local coin = createCoin(pos.worldX, pos.surfaceY + DROP_HEIGHT, pos.worldZ)
            coin.Transparency = 0.6 -- slightly translucent while falling
            coin.Parent = coinFolder

            activeCoins[coin] = {
                collected = false,
                gx = pos.gx,
                gz = pos.gz,
                worldX = pos.worldX,
                worldZ = pos.worldZ,
                baseY = targetY,
                spinSpeed = 1.5 + math.random() * 1.0,
                bobAmp = 0.3 + math.random() * 0.2,
                bobOffset = math.random() * math.pi * 2,
                dropping = true, -- flag so heartbeat doesn't fight the tween
            }

            coin.Touched:Connect(function(hit)
                onCoinTouched(coin, hit)
            end)

            -- Drop tween: fall down with a bounce ease + fade to full opacity
            local dropTween = TweenService:Create(coin, TweenInfo.new(0.45, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {
                CFrame = CFrame.new(pos.worldX, targetY, pos.worldZ) * coin.CFrame.Rotation,
                Transparency = 0,
            })
            dropTween:Play()
            dropTween.Completed:Connect(function()
                local data = activeCoins[coin]
                if data then data.dropping = false end
            end)

            if i < #spawnPoints then
                task.wait(STAGGER_DELAY)
            end
        end
    end)

    print("[CoinSpawner v4] Spawning " .. #spawnPoints .. " coins with drop animation (" .. #baseSpawns .. " base + clusters)")
end

---------- CLEANUP HANDLER ----------
local function cleanupCoins()
    if heartbeatConn then heartbeatConn:Disconnect(); heartbeatConn = nil end
    if coinFolder then coinFolder:Destroy(); coinFolder = nil end
    activeCoins = {}
    collectionDebounce = {}
end

---------- LISTEN FOR ROUND EVENTS ----------
binds:WaitForChild("SpawnMapCoins").Event:Connect(function()
    task.delay(1.0, function()
        spawnCoins()
    end)
end)

binds:WaitForChild("CleanupMapCoins").Event:Connect(function()
    cleanupCoins()
end)

-- Fallback: also watch for Map folder if coins need spawning outside the round flow
workspace.ChildAdded:Connect(function(child)
    if child.Name == "Map" and not coinFolder then
        task.delay(1.0, function()
            spawnCoins()
        end)
    end
end)

if workspace:FindFirstChild("Map") and not coinFolder then
    task.delay(1.0, function()
        spawnCoins()
    end)
end

print("[CoinSpawner v4] Ready — reduced density, top-floor bias, cleaner UX")
