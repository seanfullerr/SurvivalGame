-- GameConfig v4: 200x200 arena, 8-stud tiles, elevation tiers, lava, coin pickups
return {
    -- MAP GRID
    GRID = 25,
    TILE = 8,

    -- ELEVATION TIERS (flat within each tier)
    TIER_HIGH_Y = 10,       -- +10 studs above ground
    TIER_MID_Y = 0,         -- ground level
    TIER_LOW_Y = -8,        -- valley floor

    -- LAYER COUNTS PER TIER (deeper tiers = fewer layers to dig through)
    LAYERS_HIGH = 5,
    LAYERS_MID = 4,
    LAYERS_LOW = 3,

    -- LAVA
    LAVA_COVERAGE = 0.30,   -- 30% of valley bedrock is lava
    LAVA_DPS = 30,           -- damage per second on lava (lethal in ~3.3s)

    -- RAMPS
    RAMP_WIDTH = 2,         -- tiles wide (16 studs)
    RAMPS_PER_CONNECTION = 2, -- 2 ramps from MID->HIGH, 2 from MID->LOW

    -- TILE VISUALS
    LAYER_COLORS = {
        {Color3.fromRGB(120,200,80), Color3.fromRGB(105,185,70)},   -- grass
        {Color3.fromRGB(145,100,50), Color3.fromRGB(125,85,40)},    -- dirt
        {Color3.fromRGB(150,150,150),Color3.fromRGB(130,130,130)},   -- stone
        {Color3.fromRGB(100,100,110),Color3.fromRGB(85,85,95)},      -- dark stone
        {Color3.fromRGB(60,60,65),   Color3.fromRGB(50,50,55)},      -- bedrock
    },
    LAYER_MATERIALS = {
        Enum.Material.Grass,
        Enum.Material.Ground,
        Enum.Material.Slate,
        Enum.Material.Basalt,
        Enum.Material.Slate,
    },

    -- GAMEPLAY
    LOBBY_SIZE = 260,
    MAX_HP = 100,
    ROUND_DURATION = 23,
    MAX_ROUNDS = 7,            -- game ends after 7 rounds (winners survive all)
    INTERMISSION = 6,
    MIN_PLAYERS = 1,           -- minimum players required to start (1 = solo/Studio-test friendly)
    LOBBY_COUNTDOWN = 12,      -- lobby countdown seconds (recap + rest + future shop time)

    -- BOMBS
    BOMB_INTERVAL_BASE = 1.2,
    BOMB_INTERVAL_MIN = 0.15,
    BOMB_DAMAGE = 40,
    BOMB_DESTROY_RADIUS = 1,       -- tile radius (was 2) — probabilistic now
    BOMB_BLAST_RADIUS = 16,
    BOMB_WARN_TIME = 1.2,
    BOMB_FALL_HEIGHT = 100,         -- taller arena needs higher drop

    -- DESTRUCTION SCALING (chance = BASE + (difficulty-1) * SCALE, capped at MAX)
    DESTROY_CHANCE_BASE = 0.24,
    DESTROY_CHANCE_SCALE = 0.08,
    DESTROY_CHANCE_MAX = 0.65,

    -- ROTATING HOT ZONE
    HOT_ZONE_MULTIPLIER = 1.4,     -- 40% more bombs in hot zone
    HOT_ZONE_SEQUENCE = {"NW", "NE", "SW", "SE", "CENTER"},

    -- COIN PICKUPS (procedural map coins)
    COIN_COUNT = 10,               -- base number of coins per map (reduced from 20 for cleaner visuals)
    COIN_RESPAWN_TIME = 10,        -- seconds before a collected coin respawns
    COIN_RESPAWN_JITTER = 3,       -- ± random jitter on respawn (prevents wave patterns)
    COIN_PICKUP_VALUE = 1,         -- coins awarded per pickup
    COIN_CLUSTER_CHANCE = 0.08,    -- 8% chance a spawn point becomes a 2-4 coin cluster (reduced from 15%)

    -- COIN STREAK / COMBO
    COIN_STREAK_TIMEOUT = 2.5,         -- seconds to collect next coin before streak resets
    COIN_STREAK_MAX_MULTIPLIER = 5,    -- maximum streak multiplier cap
}
