-- RoundManager v16: No platform, countdown at lobby, scatter on drop
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local ok, Config = pcall(require, RS:WaitForChild("GameConfig"))
local ok2, MapManager = pcall(require, RS:WaitForChild("MapManager"))
if not (ok and ok2) then warn("[RoundManager] Module load failed"); return end

local GameEvents = RS:WaitForChild("GameEvents")
local binds = RS:WaitForChild("Binds")

local roundNumber = 0
local playerStats = {}

local function waitForPlayers()
    while #Players:GetPlayers() < 1 do task.wait(1) end
end

local function getDifficulty(round)
    return math.min(1.2 * 1.28 ^ (round - 1), 5.5)
end

local function getHotZone(round)
    local zones = Config.HOT_ZONE_SEQUENCE or {"NW", "NE", "SW", "SE", "CENTER"}
    return zones[((round - 1) % #zones) + 1]
end

local function getDestroyChance(difficulty)
    local base = Config.DESTROY_CHANCE_BASE or 0.24
    local scale = Config.DESTROY_CHANCE_SCALE or 0.08
    local max = Config.DESTROY_CHANCE_MAX or 0.65
    return math.min(base + (difficulty - 1) * scale, max)
end

---------- MAP MODIFIERS ----------
local MAP_MODIFIERS = {"normal", "craters", "elevated_center", "thin_bridges", "flat"}

local function applyMapModifier(modifier)
    local mapFolder = workspace:FindFirstChild("Map")
    if not mapFolder then return end

    if modifier == "craters" then
        local G, T = Config.GRID, Config.TILE
        local center = G / 2
        local craterRadius = G * 0.3
        for layer = 1, 2 do
            local lf = mapFolder:FindFirstChild("Layer" .. layer)
            if lf then
                for x = 0, G-1 do
                    for z = 0, G-1 do
                        local dist = math.sqrt((x - center)^2 + (z - center)^2)
                        if dist > craterRadius - 1.5 and dist < craterRadius + 1.5 then
                            local tile = lf:FindFirstChild("T" .. layer .. "_" .. x .. "_" .. z)
                            if tile and math.random() < 0.6 then tile:Destroy() end
                        end
                    end
                end
            end
        end
    elseif modifier == "thin_bridges" then
        local G, T = Config.GRID, Config.TILE
        for layer = 1, 2 do
            local lf = mapFolder:FindFirstChild("Layer" .. layer)
            if lf then
                for x = 0, G-1 do
                    for z = 0, G-1 do
                        local keepRow = (x % 9 <= 1)
                        local keepCol = (z % 9 <= 1)
                        if not keepRow and not keepCol then
                            local tile = lf:FindFirstChild("T" .. layer .. "_" .. x .. "_" .. z)
                            if tile then tile:Destroy() end
                        end
                    end
                end
            end
        end
    elseif modifier == "elevated_center" then
        local G, T = Config.GRID, Config.TILE
        local center = G / 2
        for layer = 1, Config.LAYERS_HIGH do
            local lf = mapFolder:FindFirstChild("Layer" .. layer)
            if lf then
                for x = 0, G-1 do
                    for z = 0, G-1 do
                        local dist = math.sqrt((x - center)^2 + (z - center)^2)
                        if dist < G * 0.25 then
                            local tile = lf:FindFirstChild("T" .. layer .. "_" .. x .. "_" .. z)
                            if tile then
                                local boost = math.max(0, (1 - dist / (G * 0.25))) * 8
                                tile.Position = tile.Position + Vector3.new(0, boost, 0)
                            end
                        end
                    end
                end
            end
        end
    end
end


---------- HOT ZONE VISUALIZATION ----------
local hotZoneFolder = nil

local function clearHotZone()
    if hotZoneFolder and hotZoneFolder.Parent then hotZoneFolder:Destroy() end
    hotZoneFolder = nil
end

local function showHotZoneBeams(zone)
    clearHotZone()
    hotZoneFolder = Instance.new("Folder")
    hotZoneFolder.Name = "HotZoneVis"
    hotZoneFolder.Parent = workspace

    local half = Config.GRID * Config.TILE / 2
    local tw = game:GetService("TweenService")

    local x1, z1, x2, z2
    if zone == "NW" then     x1, z1, x2, z2 = -half, -half, 0, 0
    elseif zone == "NE" then x1, z1, x2, z2 = 0, -half, half, 0
    elseif zone == "SW" then x1, z1, x2, z2 = -half, 0, 0, half
    elseif zone == "SE" then x1, z1, x2, z2 = 0, 0, half, half
    elseif zone == "CENTER" then
        local q = half * 0.5
        x1, z1, x2, z2 = -q, -q, q, q
    else return end

    local width = x2 - x1
    local depth = z2 - z1
    local cx = (x1 + x2) / 2
    local cz = (z1 + z2) / 2

    local tierSurfaces = {
        {name = "HIGH", y = Config.TIER_HIGH_Y + Config.TILE},
        {name = "MID",  y = Config.TIER_MID_Y + Config.TILE},
        {name = "LOW",  y = Config.TIER_LOW_Y + Config.TILE},
    }

    local plateCount = 3

    for _, tier in ipairs(tierSurfaces) do
        local plateW = width / plateCount
        local plateD = depth / plateCount

        -- LAYER 1: Stylized sparkle wisps — cartoony rising heat embers
        for gx = 0, plateCount - 1 do
            for gz = 0, plateCount - 1 do
                local px = x1 + plateW * (gx + 0.5)
                local pz = z1 + plateD * (gz + 0.5)

                local plate = Instance.new("Part")
                plate.Name = "HeatPlate_" .. tier.name
                plate.Size = Vector3.new(plateW, 0.2, plateD)
                plate.Position = Vector3.new(px, tier.y + 0.1, pz)
                plate.Anchored = true; plate.CanCollide = false
                plate.Transparency = 1
                plate.Parent = hotZoneFolder

                local wisp = Instance.new("ParticleEmitter")
                wisp.Name = "HeatWisp"
                wisp.Texture = "rbxasset://textures/particles/sparkles_main.dds"
                wisp.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 200, 80)),
                    ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 130, 40)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 60, 20)),
                })
                wisp.Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 1),
                    NumberSequenceKeypoint.new(0.1, 0.5),
                    NumberSequenceKeypoint.new(0.5, 0.65),
                    NumberSequenceKeypoint.new(1, 1),
                })
                wisp.Size = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 0.3),
                    NumberSequenceKeypoint.new(0.3, 1.2),
                    NumberSequenceKeypoint.new(1, 0.1),
                })
                wisp.Speed = NumberRange.new(2, 5)
                wisp.EmissionDirection = Enum.NormalId.Top
                wisp.SpreadAngle = Vector2.new(20, 20)
                wisp.Lifetime = NumberRange.new(1.5, 2.8)
                wisp.Rate = 4
                wisp.RotSpeed = NumberRange.new(-60, 60)
                wisp.Rotation = NumberRange.new(0, 360)
                wisp.LightEmission = 0.6
                wisp.LightInfluence = 0.4
                wisp.Parent = plate
            end
        end

        -- LAYER 2: Stylized fire-shape ground glow (ambient shimmer)
        local glowPlate = Instance.new("Part")
        glowPlate.Name = "HeatGlow_" .. tier.name
        glowPlate.Size = Vector3.new(width, 0.2, depth)
        glowPlate.Position = Vector3.new(cx, tier.y + 0.1, cz)
        glowPlate.Anchored = true; glowPlate.CanCollide = false
        glowPlate.Transparency = 1
        glowPlate.Parent = hotZoneFolder

        local glow = Instance.new("ParticleEmitter")
        glow.Name = "GroundGlow"
        glow.Texture = "rbxasset://textures/particles/fire_main.dds"
        glow.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 160, 50)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 90, 20)),
        })
        glow.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.85),
            NumberSequenceKeypoint.new(0.3, 0.7),
            NumberSequenceKeypoint.new(1, 1),
        })
        glow.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 3.0),
            NumberSequenceKeypoint.new(0.5, 5.0),
            NumberSequenceKeypoint.new(1, 2.0),
        })
        glow.Speed = NumberRange.new(0.5, 1.5)
        glow.EmissionDirection = Enum.NormalId.Top
        glow.SpreadAngle = Vector2.new(30, 30)
        glow.Lifetime = NumberRange.new(1.0, 2.0)
        glow.Rate = 8
        glow.RotSpeed = NumberRange.new(-20, 20)
        glow.Rotation = NumberRange.new(0, 360)
        glow.LightEmission = 0.5
        glow.LightInfluence = 0.5
        glow.Parent = glowPlate

        -- LAYER 3: Warm pulsing PointLight
        local lightPart = Instance.new("Part")
        lightPart.Name = "HeatLight_" .. tier.name
        lightPart.Size = Vector3.new(1, 1, 1)
        lightPart.Position = Vector3.new(cx, tier.y + 4, cz)
        lightPart.Anchored = true; lightPart.CanCollide = false
        lightPart.Transparency = 1
        lightPart.Parent = hotZoneFolder

        local light = Instance.new("PointLight")
        light.Color = Color3.fromRGB(255, 120, 30)
        light.Brightness = 0.7
        light.Range = 55
        light.Parent = lightPart
        tw:Create(light, TweenInfo.new(2.0, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            {Brightness = 0.3}):Play()
    end
end


---------- LOBBY SPAWNS ----------
local function setLobbySpawns(enabled)
    local ls = workspace:FindFirstChild("LobbySpawns")
    if ls then for _, sp in ipairs(ls:GetChildren()) do sp.Enabled = enabled end end
end

local function sendLeaderboard(survivors, roundNum, survivalTime)
    local lbData = {}
    for _, p in ipairs(Players:GetPlayers()) do
        local stats = playerStats[p.UserId] or {rounds = 0, survivalTime = 0}
        table.insert(lbData, {name = p.DisplayName, rounds = stats.rounds, time = stats.survivalTime, alive = false})
    end
    for _, p in ipairs(survivors) do
        for _, entry in ipairs(lbData) do
            if entry.name == p.DisplayName then entry.alive = true; break end
        end
    end
    GameEvents.LeaderboardUpdate:FireAllClients(lbData)
end

---------- MAIN GAME LOOP ----------
while true do
    setLobbySpawns(true)
    waitForPlayers()
    MapManager.BuildMap()
    roundNumber = 0

    local modifier = MAP_MODIFIERS[math.random(#MAP_MODIFIERS)]
    applyMapModifier(modifier)
    if modifier ~= "normal" and modifier ~= "flat" then
        GameEvents.RoundUpdate:FireAllClients("map_modifier", modifier)
    end

        -- LOBBY WAIT (A3: countdown so players know when game starts)
    local lobbyCountdown = 3
    for lcd = lobbyCountdown, 1, -1 do
        GameEvents.RoundUpdate:FireAllClients("lobby_wait", lcd, lobbyCountdown, #Players:GetPlayers())
        task.wait(1)
    end

    -- Mark players in-game + generate scatter positions
    setLobbySpawns(false)
    binds.StartGame:Fire()
    task.wait(0.5)

    -- DROP: client snaps to black, we teleport behind it, client fades in
    GameEvents.RoundUpdate:FireAllClients("drop", 1, 0, 1)
    task.wait(0.15)  -- brief wait to ensure client screen is black
    binds.ScatterPlayers:Fire()
    task.wait(2.0)   -- wait for hold (0.6s) + fade-in (1.0s) + buffer

    -- COUNTDOWN on the arena: 3, 2, 1 (players can see the map)
    for i = 3, 1, -1 do
        GameEvents.RoundUpdate:FireAllClients("countdown", i, i, 1)
        task.wait(1)
    end

    -- GO!
    GameEvents.RoundUpdate:FireAllClients("countdown_go", 0, 0, 1)
    task.wait(0.5)

    local gameOver = false
    local sessionStartTime = tick()

    while not gameOver do
        roundNumber = roundNumber + 1
        local difficulty = getDifficulty(roundNumber)
        -- Scaled heal: gentler early (attrition matters less), stronger late (survival depends on this round)
        local healPct = roundNumber >= 6 and 0.40 or (roundNumber >= 4 and 0.30 or 0.20)
        binds.HealPlayers:Fire(healPct)
        local survivalTime = math.floor(tick() - sessionStartTime)

        -- Skip inter-round countdown for round 1 (player already saw 3,2,1,GO)
        if roundNumber > 1 then
            local preAlive = binds.GetAlivePlayers:Invoke()
            local nextHotZone = getHotZone(roundNumber)
            for cd = 3, 1, -1 do
                GameEvents.RoundUpdate:FireAllClients("round_start", roundNumber, cd, difficulty, survivalTime, #preAlive, cd == 3 and nextHotZone or nil)
                task.wait(1)
            end
        end

        local roundDuration = Config.ROUND_DURATION
        local hotZone = getHotZone(roundNumber)
        local destroyChance = getDestroyChance(difficulty)
        binds.StartBombs:Fire(difficulty, hotZone, destroyChance, roundNumber)

        GameEvents.RoundUpdate:FireAllClients("hot_zone", hotZone, roundNumber, difficulty)
        showHotZoneBeams(hotZone)

        local allDead = false
        for i = roundDuration, 1, -1 do
            survivalTime = math.floor(tick() - sessionStartTime)
            local alivePlayers = binds.GetAlivePlayers:Invoke()
            GameEvents.RoundUpdate:FireAllClients("survive", roundNumber, i, difficulty, survivalTime, #alivePlayers)
            if #alivePlayers == 0 and #Players:GetPlayers() > 0 then allDead = true; break end
            task.wait(1)
        end

        binds.StopBombs:Fire()
        local survivors = binds.GetAlivePlayers:Invoke()

        for _, p in ipairs(survivors) do
            if not playerStats[p.UserId] then playerStats[p.UserId] = {rounds = 0, survivalTime = 0} end
            playerStats[p.UserId].rounds = roundNumber
            playerStats[p.UserId].survivalTime = survivalTime
        end
        sendLeaderboard(survivors, roundNumber, survivalTime)
        survivalTime = math.floor(tick() - sessionStartTime)

        if allDead or #survivors == 0 then
            for i = 2, 1, -1 do
                GameEvents.RoundUpdate:FireAllClients("game_over", roundNumber, i, difficulty, survivalTime)
                task.wait(1)
            end
            setLobbySpawns(true)
            clearHotZone()
            GameEvents.RoundUpdate:FireAllClients("return_to_lobby")
            task.wait(0.5)
            binds.ResetPlayers:Fire()
            playerStats = {}; gameOver = true
        else
            GameEvents.RoundUpdate:FireAllClients("round_survived", #survivors, roundNumber, difficulty, survivalTime)
            -- Award coins for surviving this round
            local coinBind = binds:FindFirstChild("AwardRoundCoins")
            if coinBind then coinBind:Fire(roundNumber, survivors, false) end
            task.wait(1.5)

            -- WIN CONDITION: survived all rounds
            if roundNumber >= (Config.MAX_ROUNDS or 7) then
                GameEvents.RoundUpdate:FireAllClients("victory", #survivors, roundNumber, difficulty, survivalTime)
                -- Victory bonus coins
                local coinBindV = binds:FindFirstChild("AwardRoundCoins")
                if coinBindV then coinBindV:Fire(roundNumber, survivors, true) end
                                -- Full heal during victory so players don't die to residual lava/fall damage
                binds.HealPlayers:Fire(1.0)
                task.wait(3)
                setLobbySpawns(true)
                clearHotZone()
                GameEvents.RoundUpdate:FireAllClients("return_to_lobby")
                task.wait(0.5)
                binds.ResetPlayers:Fire()
                task.wait(1)  -- buffer for character to fully load before next game
                playerStats = {}; gameOver = true
            end
        end
    end
    task.wait(2)
end
