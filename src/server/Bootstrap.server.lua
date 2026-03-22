-- Bootstrap.server.lua
-- Runs first on the server (all other scripts yield on WaitForChild).
-- Creates GameEvents (RemoteEvents) and Binds (BindableEvents/Functions)
-- in ReplicatedStorage before any other script needs them.

local RS = game:GetService("ReplicatedStorage")

---------- GAME EVENTS (RemoteEvents for server↔client) ----------
if not RS:FindFirstChild("GameEvents") then
    local ge = Instance.new("Folder")
    ge.Name = "GameEvents"

    local remoteEvents = {
        "RoundUpdate",
        "PlayerDamaged",
        "PlayerDied",
        "BombLanded",
        "LeaderboardUpdate",
        "CoinUpdate",
        "LavaContact",
        "MissileLockOn",
        "MissileUpdate",
    }

    for _, name in ipairs(remoteEvents) do
        local re = Instance.new("RemoteEvent")
        re.Name = name
        re.Parent = ge
    end

    ge.Parent = RS
    print("[Bootstrap] GameEvents created — " .. #remoteEvents .. " RemoteEvents")
else
    print("[Bootstrap] GameEvents already exists — skipping")
end

---------- BINDS (BindableEvents/Functions for server↔server) ----------
if RS:FindFirstChild("Binds") then
    print("[Bootstrap] Binds already exists — skipping")
    return
end

local binds = Instance.new("Folder")
binds.Name = "Binds"

-- BindableEvents -----------------------------------------------------------
-- DamagePlayer   : BombSystem -> PlayerManager  (player, dmg, bombType)
-- ResetPlayers   : RoundManager -> PlayerManager
-- StartGame      : RoundManager -> PlayerManager
-- ScatterPlayers : RoundManager -> PlayerManager
-- HealPlayers    : RoundManager -> PlayerManager (healPct)
-- StartBombs     : RoundManager -> BombSystem   (difficulty, hotZone, destroyChance, roundNum)
-- StopBombs      : RoundManager -> BombSystem
-- AwardRoundCoins: RoundManager -> CoinManager  (roundNum, survivors, isVictory)
local bindableEvents = {
    "DamagePlayer",
    "ResetPlayers",
    "StartGame",
    "ScatterPlayers",
    "HealPlayers",
    "StartBombs",
    "StopBombs",
    "AwardRoundCoins",
}

for _, name in ipairs(bindableEvents) do
    local e = Instance.new("BindableEvent")
    e.Name = name
    e.Parent = binds
end

-- BindableFunctions --------------------------------------------------------
-- GetAlivePlayers: RoundManager invokes -> PlayerManager handles, returns list
local bindableFunctions = {
    "GetAlivePlayers",
}

for _, name in ipairs(bindableFunctions) do
    local f = Instance.new("BindableFunction")
    f.Name = name
    f.Parent = binds
end

-- Parent last so WaitForChild listeners fire only once the folder is complete
binds.Parent = RS

print(string.format(
    "[Bootstrap] Binds created — %d BindableEvents, %d BindableFunctions",
    #bindableEvents,
    #bindableFunctions
))
