-- PlayerManager v12: No platform, scatter spawn, spectate-until-round-ends
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(RS:WaitForChild("GameConfig"))
local MapManager = require(RS:WaitForChild("MapManager"))
local GameEvents = RS:WaitForChild("GameEvents")
local SFX = require(RS:WaitForChild("SoundManager"))
local binds = RS:WaitForChild("Binds")

local alive = {}
local lavaDamageCooldown = {}
local inGame = {}
local lastHitBy = {}
local lavaFirstContact = {}

local arenaBound = (Config.GRID * Config.TILE) / 2 + 5

local function getLobbySpawn()
    local lobbySpawns = workspace:FindFirstChild("LobbySpawns")
    if not lobbySpawns then return nil end
    local spawns = lobbySpawns:GetChildren()
    if #spawns == 0 then return nil end
    return spawns[math.random(#spawns)]
end

local function isInArena(pos)
    return math.abs(pos.X) < arenaBound and math.abs(pos.Z) < arenaBound
end

local function checkLastSurvivor()
    local aliveList = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if alive[p.UserId] and inGame[p.UserId] then
            table.insert(aliveList, p)
        end
    end
    if #aliveList == 1 and #Players:GetPlayers() > 1 then
        local survivor = aliveList[1]
        local char = survivor.Character
        if char then
            local hum = char:FindFirstChild("Humanoid")
            if hum then hum.Health = math.min(hum.MaxHealth, hum.Health + 10) end
        end
        GameEvents.PlayerDamaged:FireClient(survivor, -1)
    end
end

local function setup(player)
    alive[player.UserId] = false
    inGame[player.UserId] = false
    lastHitBy[player.UserId] = nil

    player.CharacterAdded:Connect(function(char)
        local hum = char:WaitForChild("Humanoid")
        hum.MaxHealth = Config.MAX_HP; hum.Health = Config.MAX_HP

        -- If player was alive in-game and reset, treat as elimination
        if inGame[player.UserId] and alive[player.UserId] then
            alive[player.UserId] = false
            inGame[player.UserId] = false
            -- Notify others of elimination (but don't trigger death screen for the resetter)
            GameEvents.RoundUpdate:FireAllClients("player_eliminated", player.DisplayName, "reset")

            -- Teleport to a lobby spawn so they don't land on the arena
            task.delay(0.2, function()
                local hrp = char:FindFirstChild("HumanoidRootPart")
                local lobbySpawns = workspace:FindFirstChild("LobbySpawns")
                if hrp and lobbySpawns then
                    local spawns = lobbySpawns:GetChildren()
                    if #spawns > 0 then
                        local sp = spawns[math.random(#spawns)]
                        hrp.CFrame = sp.CFrame + Vector3.new(0, 3, 0)
                    end
                end
            end)

            task.delay(0.1, function() checkLastSurvivor() end)
        elseif not inGame[player.UserId] then
            alive[player.UserId] = false
        end

        -- Clean up ForceField
        task.delay(0, function()
            local ff = char:FindFirstChildOfClass("ForceField")
            if ff then ff:Destroy() end
        end)

        -- Clear lava state
        lavaDamageCooldown[player.UserId] = nil
        lavaFirstContact[player.UserId] = nil
        lastHitBy[player.UserId] = nil
    end)
end

Players.PlayerAdded:Connect(setup)
Players.PlayerRemoving:Connect(function(p)
    alive[p.UserId] = nil; inGame[p.UserId] = nil; lastHitBy[p.UserId] = nil
    lavaDamageCooldown[p.UserId] = nil
end)
for _, p in ipairs(Players:GetPlayers()) do setup(p) end

-- Take damage
binds:WaitForChild("DamagePlayer").Event:Connect(function(player, dmg, bombType)
    if not player or not player.Parent then return end
    if not alive[player.UserId] then return end
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChild("Humanoid")
    if not hum or hum.Health <= 0 then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    if not isInArena(hrp.Position) then return end

    if bombType then lastHitBy[player.UserId] = bombType end

    hum.Health = math.max(0, hum.Health - dmg)
    GameEvents.PlayerDamaged:FireClient(player, dmg)
    SFX.PlayOn("Hit", hrp, {Volume = 0.5, PlaybackSpeed = 0.9 + math.random() * 0.2})

    if hum.Health <= 0 then
        alive[player.UserId] = false
        inGame[player.UserId] = false
        hum.Health = 0
        local cause = lastHitBy[player.UserId] or "standard"
        GameEvents.PlayerDied:FireClient(player, cause)
        lastHitBy[player.UserId] = nil
        GameEvents.RoundUpdate:FireAllClients("player_eliminated", player.DisplayName, cause)
        SFX.PlayOn("Death", hrp, {Volume = 0.7})
        task.delay(0.1, function() checkLastSurvivor() end)
    end
end)

-- ResetPlayers: send everyone back to lobby
binds:WaitForChild("ResetPlayers").Event:Connect(function()
    for _, p in ipairs(Players:GetPlayers()) do
        inGame[p.UserId] = false; alive[p.UserId] = false
        lastHitBy[p.UserId] = nil
        lavaDamageCooldown[p.UserId] = nil
        lavaFirstContact[p.UserId] = nil

        local lobbySpawn = getLobbySpawn()
        if lobbySpawn then p.RespawnLocation = lobbySpawn end
        p:LoadCharacter()

        task.spawn(function()
            local char = p.Character or p.CharacterAdded:Wait()
            local hrp = char:WaitForChild("HumanoidRootPart", 5)
            local hum = char:WaitForChild("Humanoid", 5)
            -- Ensure full HP after respawn
            if hum then hum.Health = hum.MaxHealth end
            if hrp and lobbySpawn then
                task.wait(0.1)
                hrp.CFrame = lobbySpawn.CFrame + Vector3.new(0, 3, 0)
                -- Double-check teleport landed correctly after a brief wait
                task.wait(0.2)
                if hrp.Position.Y < -10 then
                    hrp.CFrame = lobbySpawn.CFrame + Vector3.new(0, 5, 0)
                end
            end
        end)
    end
end)

-- Scatter spawn system
local scatterPositions = {}

local function generateScatterSpawns(playerCount)
    scatterPositions = {}
    local safeInset = 0.2
    local halfArena = (Config.GRID * Config.TILE) / 2
    local minBound = -halfArena * (1 - safeInset * 2)
    local maxBound = halfArena * (1 - safeInset * 2)
    local minSpacing = 20

    for i = 1, playerCount do
        local bestPos = nil
        for attempt = 1, 15 do
            local rx = minBound + math.random() * (maxBound - minBound)
            local rz = minBound + math.random() * (maxBound - minBound)

            local tier = MapManager.GetTierAt(rx, rz)
            if tier == "low" then continue end

            local surfY = MapManager.GetSurfaceY(rx, rz)
            if not surfY or surfY < -20 then continue end

            local tooClose = false
            for _, existing in ipairs(scatterPositions) do
                local dist = math.sqrt((rx - existing.X)^2 + (rz - existing.Z)^2)
                if dist < minSpacing then tooClose = true; break end
            end
            if tooClose then continue end

            bestPos = Vector3.new(rx, surfY + 5, rz)
            break
        end

        if not bestPos then
            local fx = (math.random() - 0.5) * 40
            local fz = (math.random() - 0.5) * 40
            local fy = MapManager.GetSurfaceY(fx, fz) or 10
            bestPos = Vector3.new(fx, fy + 5, fz)
        end

        table.insert(scatterPositions, bestPos)
    end
    return scatterPositions
end

-- StartGame: mark in-game, keep at lobby during countdown, generate scatter positions
binds:WaitForChild("StartGame").Event:Connect(function()
    local players = Players:GetPlayers()
    generateScatterSpawns(#players)

    for i, p in ipairs(players) do
        inGame[p.UserId] = true; alive[p.UserId] = true
        lastHitBy[p.UserId] = nil
        lavaDamageCooldown[p.UserId] = nil
        lavaFirstContact[p.UserId] = nil
        -- Ensure full HP at game start (fixes HP not resetting after victory)
        local char = p.Character
        if char then
            local hum = char:FindFirstChild("Humanoid")
            if hum then hum.Health = hum.MaxHealth end
        end
    end
end)

-- ScatterPlayers: teleport to random map positions
binds:WaitForChild("ScatterPlayers").Event:Connect(function()
    local players = Players:GetPlayers()
    for i, p in ipairs(players) do
        if alive[p.UserId] and inGame[p.UserId] then
            local char = p.Character
            if char then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp and scatterPositions[i] then
                    hrp.CFrame = CFrame.new(scatterPositions[i])
                end
            end
        end
    end
end)

-- Heal
binds:WaitForChild("HealPlayers").Event:Connect(function(healPct)
    healPct = healPct or 0.65
    for _, p in ipairs(Players:GetPlayers()) do
        if alive[p.UserId] and inGame[p.UserId] then
            local char = p.Character
            if char then
                local hum = char:FindFirstChild("Humanoid")
                if hum then
                    local healAmt = math.floor(hum.MaxHealth * healPct)
                    local oldHP = hum.Health
                    hum.Health = math.min(hum.MaxHealth, hum.Health + healAmt)
                    local actualHeal = math.floor(hum.Health - oldHP)
                    if actualHeal > 0 then
                        GameEvents.PlayerDamaged:FireClient(p, -actualHeal)
                    end
                end
            end
        end
    end
end)

binds:WaitForChild("GetAlivePlayers").OnInvoke = function()
    local list = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if alive[p.UserId] and inGame[p.UserId] then table.insert(list, p) end
    end
    return list
end

-- Kill plane + lava damage
RunService.Heartbeat:Connect(function()
    for _, p in ipairs(Players:GetPlayers()) do
        if not alive[p.UserId] then continue end
        local char = p.Character
        if not char then continue end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end

        -- Lava damage
        if not lavaDamageCooldown[p.UserId] or tick() - lavaDamageCooldown[p.UserId] > 0.5 then
            local isLava, lavaData = MapManager.IsOverLava(hrp.Position.X, hrp.Position.Z)
            if isLava and lavaData and hrp.Position.Y < lavaData.y + 4 then
                lavaDamageCooldown[p.UserId] = tick()
                local lavaDps = Config.LAVA_DPS or 5
                local dmg = math.floor(lavaDps * 0.5)
                local hum = char:FindFirstChild("Humanoid")
                if hum and hum.Health > 0 then
                    lastHitBy[p.UserId] = "lava"
                    hum.Health = math.max(0, hum.Health - dmg)
                    GameEvents.PlayerDamaged:FireClient(p, dmg)

                    local isFirst = not lavaFirstContact[p.UserId]
                    lavaFirstContact[p.UserId] = true
                    GameEvents.LavaContact:FireClient(p, isFirst)                    if hum.Health <= 0 then
                        alive[p.UserId] = false; inGame[p.UserId] = false
                        GameEvents.PlayerDied:FireClient(p, "lava")
                        GameEvents.RoundUpdate:FireAllClients("player_eliminated", p.DisplayName, "lava")
                        task.delay(0.1, function() checkLastSurvivor() end)
                    end
                end
            end
        end

        -- Fall kill
        if hrp.Position.Y < -45 then
            local hum = char:FindFirstChild("Humanoid")
            if hum and hum.Health > 0 then
                hum.Health = 0; alive[p.UserId] = false; inGame[p.UserId] = false
                GameEvents.PlayerDied:FireClient(p, "fall")
                GameEvents.RoundUpdate:FireAllClients("player_eliminated", p.DisplayName, "fall")
                task.delay(0.1, function() checkLastSurvivor() end)
            end
        end
    end
end)

print("[PlayerManager v12] Ready — no platform, scatter spawn, spectate-until-round-ends")
