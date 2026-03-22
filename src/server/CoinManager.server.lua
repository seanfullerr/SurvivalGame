-- Handles: coin earning per round, DataStore persistence, leaderstats display
-- Coins: 5 per round survived, 50 bonus for full survive (all 7 rounds)

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RS = game:GetService("ReplicatedStorage")
local GameEvents = RS:WaitForChild("GameEvents")
local Config = require(RS:WaitForChild("GameConfig"))

-- DataStore (wrapped in pcall for Studio testing)
local coinStore = nil
pcall(function()
    coinStore = DataStoreService:GetDataStore("BombSurvival_Coins_v1")
end)

local playerCoins = {}  -- userId → coin count
local playerBestRound = {}  -- userId → best round survived

---------- LEADERSTATS ----------
local function setupLeaderstats(player)
    local ls = Instance.new("Folder")
    ls.Name = "leaderstats"
    ls.Parent = player

    local coins = Instance.new("IntValue")
    coins.Name = "Coins"
    coins.Value = 0
    coins.Parent = ls

    local best = Instance.new("IntValue")
    best.Name = "Best Round"
    best.Value = 0
    best.Parent = ls
end

---------- DATA PERSISTENCE ----------
local function loadData(player)
    local userId = player.UserId
    local data = {coins = 0, bestRound = 0}

    if coinStore then
        local ok, result = pcall(function()
            return coinStore:GetAsync("player_" .. userId)
        end)
        if ok and result then
            data = result
        end
    end

    playerCoins[userId] = data.coins or 0
    playerBestRound[userId] = data.bestRound or 0

    -- Update leaderstats
    local ls = player:FindFirstChild("leaderstats")
    if ls then
        local coinsVal = ls:FindFirstChild("Coins")
        if coinsVal then coinsVal.Value = playerCoins[userId] end
        local bestVal = ls:FindFirstChild("Best Round")
        if bestVal then bestVal.Value = playerBestRound[userId] end
    end

    print("[CoinManager] Loaded " .. player.Name .. ": " .. playerCoins[userId] .. " coins, best R" .. playerBestRound[userId])
end

local function saveData(player)
    local userId = player.UserId
    if not playerCoins[userId] then return end

    if coinStore then
        local ok, err = pcall(function()
            coinStore:SetAsync("player_" .. userId, {
                coins = playerCoins[userId],
                bestRound = playerBestRound[userId] or 0,
            })
        end)
        if not ok then
            warn("[CoinManager] Save failed for " .. player.Name .. ": " .. tostring(err))
        end
    end
end

---------- COIN AWARD ----------
local function awardCoins(player, amount, reason)
    local userId = player.UserId
    if not playerCoins[userId] then playerCoins[userId] = 0 end
    playerCoins[userId] = playerCoins[userId] + amount

    -- Update leaderstats
    local ls = player:FindFirstChild("leaderstats")
    if ls then
        local coinsVal = ls:FindFirstChild("Coins")
        if coinsVal then coinsVal.Value = playerCoins[userId] end
    end

    -- Notify client
    GameEvents.CoinUpdate:FireClient(player, amount, playerCoins[userId], reason)
end

---------- PLAYER CONNECTIONS ----------
Players.PlayerAdded:Connect(function(player)
    setupLeaderstats(player)
    task.spawn(function()
        loadData(player)
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    saveData(player)
    playerCoins[player.UserId] = nil
    playerBestRound[player.UserId] = nil
end)

-- Save all on shutdown
game:BindToClose(function()
    for _, player in ipairs(Players:GetPlayers()) do
        saveData(player)
    end
end)

---------- LISTEN FOR ROUND EVENTS ----------
GameEvents.RoundUpdate.OnServerEvent:Connect(function() end)  -- placeholder

-- Listen for round_survived to award coins
-- We hook into the existing BindableEvents
local binds = RS:WaitForChild("Binds")

-- Award coins when round survived (server-side tracking)
local roundCoinTracker = {}  -- userId → last round coins were awarded for

GameEvents.RoundUpdate.OnServerEvent:Connect(function() end)

-- We need to listen to RoundUpdate on the server... but it's FireAllClients (server→client)
-- So we need a different approach: hook into the RoundManager's round completion

-- Use the AwardRoundCoins BindableEvent created by Bootstrap
-- (do NOT create a new one — Bootstrap owns all Binds instances)
local coinBind = binds:WaitForChild("AwardRoundCoins")

coinBind.Event:Connect(function(roundNumber, survivors, isVictory)
    local COINS_PER_ROUND = 5
    local VICTORY_BONUS = 50

    for _, player in ipairs(survivors) do
        local userId = player.UserId
        awardCoins(player, COINS_PER_ROUND, "Survived Round " .. roundNumber)

        if isVictory then
            awardCoins(player, VICTORY_BONUS, "VICTORY BONUS!")
        end

        -- Update best round
        if roundNumber > (playerBestRound[userId] or 0) then
            playerBestRound[userId] = roundNumber
            local ls = player:FindFirstChild("leaderstats")
            if ls then
                local bestVal = ls:FindFirstChild("Best Round")
                if bestVal then bestVal.Value = roundNumber end
            end
        end
    end
end)

print("[CoinManager v1] Ready — coins, DataStore, leaderstats!")
