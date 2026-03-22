-- SoundManager v6: Added StreakUp sound for coin streak feedback
local SoundManager = {}

local SOUNDS = {
    -- Explosions (using verified Roblox audio)
    Explosion       = "rbxassetid://262562442",    -- Classic Roblox explosion
    SmallExplosion  = "rbxassetid://262562442",    -- Same explosion, quieter via properties

    -- Bomb warning
    BombWhistle     = "rbxassetid://12222216",     -- Falling/swoosh
    WarningBeep     = "rbxassetid://9125402735",   -- Alert beep

    -- Player feedback
    Hit             = "rbxassetid://130717600958670", -- Damage hit impact
    Death           = "rbxassetid://607665037",    -- Arcade blip down (short)

    -- Round / game flow (jingles removed - these return nil gracefully)
    RoundStart      = "",   -- Removed (user preference)
    Countdown       = "rbxassetid://406913243",    -- Simple tick (game start)
    RoundTick       = "rbxassetid://178104975",    -- Light click (inter-round)
    GameOver        = "rbxassetid://4590662766",   -- Retro game over sting
    Milestone       = "",   -- Removed (user preference)

    -- Movement
    DoubleJump      = "rbxassetid://320557563",    -- Quick swoosh

    -- Ambient
    Drop            = "rbxassetid://320557563",    -- Impact whoosh
    LavaHiss        = "rbxassetid://31758982",   -- Ambient lava bubbling
    LavaSizzle      = "rbxassetid://31758982",   -- Contact sizzle (same asset, different properties)
    RoundClear      = "rbxassetid://135165335432475", -- Round survived chime
    LandThud        = "rbxassetid://74054153559436",  -- Landing thud

    -- Collectible coins
    CoinPickup      = "rbxassetid://135165335432475", -- Coin pickup chime
    StreakUp        = "rbxassetid://135165335432475", -- Streak increment chime (same base, pitch-shifted in code)
}

-- Play a sound at a specific position in workspace (3D positional audio)
function SoundManager.PlayAt(soundName, position, properties)
    local assetId = SOUNDS[soundName]
    if not assetId or assetId == "" then return nil end

    properties = properties or {}

    local part = Instance.new("Part")
    part.Name = "SFX_" .. soundName
    part.Size = Vector3.new(1, 1, 1)
    part.Position = position
    part.Anchored = true
    part.CanCollide = false
    part.Transparency = 1
    part.Parent = game.Workspace

    local sound = Instance.new("Sound")
    sound.SoundId = assetId
    sound.Volume = properties.Volume or 0.8
    sound.PlaybackSpeed = properties.PlaybackSpeed or 1
    sound.RollOffMaxDistance = properties.MaxDistance or 120
    sound.RollOffMinDistance = properties.MinDistance or 10
    sound.Parent = part
    sound:Play()

    game:GetService("Debris"):AddItem(part, (properties.Duration or 5))
    return sound
end

-- Play a sound on a specific part (e.g., player HRP, bomb body)
function SoundManager.PlayOn(soundName, parent, properties)
    local assetId = SOUNDS[soundName]
    if not assetId or assetId == "" then return nil end

    properties = properties or {}

    local sound = Instance.new("Sound")
    sound.SoundId = assetId
    sound.Volume = properties.Volume or 0.8
    sound.PlaybackSpeed = properties.PlaybackSpeed or 1
    sound.RollOffMaxDistance = properties.MaxDistance or 100
    sound.Parent = parent
    sound:Play()

    game:GetService("Debris"):AddItem(sound, (properties.Duration or 5))
    return sound
end

-- Play a non-positional UI/global sound
function SoundManager.PlayUI(soundName, parent, properties)
    local assetId = SOUNDS[soundName]
    if not assetId or assetId == "" then return nil end

    properties = properties or {}

    local sound = Instance.new("Sound")
    sound.SoundId = assetId
    sound.Volume = properties.Volume or 0.6
    sound.PlaybackSpeed = properties.PlaybackSpeed or 1
    sound.RollOffMaxDistance = 0
    sound.Parent = parent
    sound:Play()

    game:GetService("Debris"):AddItem(sound, (properties.Duration or 5))
    return sound
end

function SoundManager.GetId(soundName)
    return SOUNDS[soundName]
end

return SoundManager
