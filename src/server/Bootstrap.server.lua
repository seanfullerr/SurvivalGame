-- Bootstrap.server.lua
-- Runs first on the server (all other scripts yield on WaitForChild("Binds")).
-- Creates the Binds folder in ReplicatedStorage with every BindableEvent and
-- BindableFunction that the other server scripts depend on.

local RS = game:GetService("ReplicatedStorage")

-- Safety: if something already created Binds (e.g. from an old Studio save),
-- don't create a duplicate.
if RS:FindFirstChild("Binds") then
    print("[Bootstrap] Binds already exists — skipping creation")
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
