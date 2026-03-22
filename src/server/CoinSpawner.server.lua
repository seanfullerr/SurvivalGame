-- CoinSpawner v1: Physical collectible coins on the arena map
-- Server-authoritative: spawning, collision detection, validation, reward triggering.
-- Does NOT directly modify player data — fires AwardCoinPickup for CoinManager.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(RS:WaitForChild("GameConfig"))
local MapManager = require(RS:WaitForChild("MapManager"))
local SFX = require(RS:WaitForChild("SoundManager"))
local GameEvents = RS:WaitForChild("GameEvents")
local binds = RS:WaitForChild("Binds")

local activeCoins = {}      -- id -> {part, collected, spawnPos, baseY}
local coinFolder = nil
local spinConn = nil
local nextId = 0
local collectCD = {}        -- userId -> last collect tick

-- Config values (with defaults)
local COUNT     = Config.COIN_SPAWN_COUNT or 15
local REWARD    = Config.COIN_REWARD or 2
local RESPAWN   = Config.COIN_RESPAWN_TIME or 10
local SPIN_SPD  = Config.COIN_SPIN_SPEED or 2
local BOB_AMP   = Config.COIN_BOB_HEIGHT or 0.5

---------- COIN PART CREATION ----------
local function makeCoin(pos, id)
    local coin = Instance.new("Part")
    coin.Name = "MapCoin_" .. id
    coin.Shape = Enum.PartType.Cylinder
    coin.Size = Vector3.new(0.4, 2.5, 2.5)
    coin.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
    coin.Anchored = true
    coin.CanCollide = false
    coin.Material = Enum.Material.Neon
    coin.Color = Color3.fromRGB(255, 200, 50)
    coin.Parent = coinFolder

    -- Gold glow
    local light = Instance.new("PointLight")
    light.Color = Color3.fromRGB(255, 200, 50)
    light.Brightness = 1.0
    light.Range = 14
    light.Parent = coin

    -- Billboard "$" indicator
    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0, 28, 0, 28)
    bb.StudsOffset = Vector3.new(0, 2.5, 0)
    bb.AlwaysOnTop = false
    bb.Parent = coin

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 18
    lbl.TextColor3 = Color3.fromRGB(255, 220, 50)
    lbl.TextStrokeTransparency = 0.3
    lbl.TextStrokeColor3 = Color3.fromRGB(100, 70, 0)
    lbl.Text = "$"
    lbl.Parent = bb

    return coin
end

---------- RANDOM POSITION ON MAP SURFACE ----------
local function randomCoinPos()
    local half = MapManager.GetBounds()
    local inset = 0.15
    local lo = -half * (1 - inset * 2)
    local hi =  half * (1 - inset * 2)

    for _ = 1, 25 do
        local rx = lo + math.random() * (hi - lo)
        local rz = lo + math.random() * (hi - lo)

        -- Skip lava cells
        if MapManager.IsOverLava(rx, rz) then continue end

        -- Prefer mid/high tiers (avoid valleys near lava)
        local tier = MapManager.GetTierAt(rx, rz)
        if tier == "low" then continue end

        -- Need a valid surface
        local surfY = MapManager.GetSurfaceY(rx, rz)
        if not surfY or surfY < -20 then continue end

        -- Min spacing between coins (15 studs)
        local tooClose = false
        for _, d in pairs(activeCoins) do
            if d.part and d.part.Parent and not d.collected then
                local dx = rx - d.spawnPos.X
                local dz = rz - d.spawnPos.Z
                if dx * dx + dz * dz < 225 then tooClose = true; break end
            end
        end
        if tooClose then continue end

        return Vector3.new(rx, surfY + 2.5, rz)
    end
    return nil
end

---------- COLLECTION LOGIC ----------
local function onTouch(id, hit)
    local d = activeCoins[id]
    if not d or d.collected then return end

    local char = hit.Parent
    if not char then return end
    local player = Players:GetPlayerFromCharacter(char)
    if not player then return end

    -- Per-player debounce (0.3s)
    local now = tick()
    if collectCD[player.UserId] and now - collectCD[player.UserId] < 0.3 then return end
    collectCD[player.UserId] = now

    -- Mark collected immediately (prevents double-collect)
    d.collected = true

    -- Award via CoinManager (keeps DataStore + leaderstats in sync)
    local awardBind = binds:FindFirstChild("AwardCoinPickup")
    if awardBind then
        awardBind:Fire(player, REWARD, "Coin Pickup!")
    end

    -- Notify all clients for pickup VFX
    local pickupEvent = GameEvents:FindFirstChild("CoinPickup")
    if pickupEvent then
        pickupEvent:FireAllClients(d.spawnPos, player.UserId)
    end

    -- Pickup sound (3D positional)
    SFX.PlayAt("CoinPickup", d.spawnPos, {Volume = 0.6, MaxDistance = 60})

    -- Destroy the coin part
    if d.part and d.part.Parent then d.part:Destroy() end

    -- Respawn after delay
    if RESPAWN > 0 then
        task.delay(RESPAWN, function()
            if not coinFolder or not coinFolder.Parent then return end
            spawnOne()
        end)
    end
end

---------- SPAWN ----------
function spawnOne()
    local pos = randomCoinPos()
    if not pos then return end

    nextId = nextId + 1
    local id = nextId
    local part = makeCoin(pos, id)

    activeCoins[id] = {
        part = part,
        collected = false,
        spawnPos = pos,
        baseY = pos.Y,
    }

    part.Touched:Connect(function(hit) onTouch(id, hit) end)
end

local function spawnAll()
    for _ = 1, COUNT do spawnOne() end
    print("[CoinSpawner] Spawned " .. COUNT .. " map coins")
end

---------- SPIN + BOB ANIMATION (single Heartbeat for all coins) ----------
local function startAnim()
    if spinConn then spinConn:Disconnect() end
    spinConn = RunService.Heartbeat:Connect(function()
        local t = tick()
        for _, d in pairs(activeCoins) do
            if d.part and d.part.Parent and not d.collected then
                local angle = t * SPIN_SPD * math.pi * 2
                local bob = math.sin(t * 2) * BOB_AMP
                d.part.CFrame = CFrame.new(d.spawnPos.X, d.baseY + bob, d.spawnPos.Z)
                    * CFrame.Angles(0, angle, math.rad(90))
            end
        end
    end)
end

local function stopAnim()
    if spinConn then spinConn:Disconnect(); spinConn = nil end
end

---------- CLEANUP ----------
local function cleanup()
    stopAnim()
    for _, d in pairs(activeCoins) do
        if d.part and d.part.Parent then d.part:Destroy() end
    end
    activeCoins = {}
    collectCD = {}
    if coinFolder and coinFolder.Parent then coinFolder:Destroy() end
    coinFolder = nil
end

---------- BINDABLE EVENT HOOKS ----------
binds:WaitForChild("SpawnMapCoins").Event:Connect(function()
    cleanup()
    coinFolder = Instance.new("Folder")
    coinFolder.Name = "MapCoins"
    coinFolder.Parent = workspace
    spawnAll()
    startAnim()
end)

binds:WaitForChild("CleanupMapCoins").Event:Connect(function()
    cleanup()
end)

-- Cleanup debounce on player leave
Players.PlayerRemoving:Connect(function(p)
    collectCD[p.UserId] = nil
end)

print("[CoinSpawner v1] Ready — collectible map coins!")
