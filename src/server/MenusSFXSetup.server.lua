-- MenusSFXSetup: Creates SFX sounds in SoundService for the UI Kit's GUIManager
-- These sounds are used by MenusGUI buttons (hover, press, buy feedback).
-- Runs once at server start to ensure sounds exist.

local SoundService = game:GetService("SoundService")

-- Create or find SFX SoundGroup
local sfxGroup = SoundService:FindFirstChild("SFX")
if not sfxGroup then
    sfxGroup = Instance.new("SoundGroup")
    sfxGroup.Name = "SFX"
    sfxGroup.Parent = SoundService
end

-- Sound definitions
local sounds = {
    { Name = "Press",  SoundId = "rbxassetid://10066968815",    Volume = 1   },
    { Name = "Hover",  SoundId = "rbxassetid://103003970474571", Volume = 0.5 },
    { Name = "Buy_1",  SoundId = "rbxassetid://10066947742",    Volume = 1   },
}

for _, info in ipairs(sounds) do
    if not sfxGroup:FindFirstChild(info.Name) then
        local snd = Instance.new("Sound")
        snd.Name = info.Name
        snd.SoundId = info.SoundId
        snd.Volume = info.Volume
        snd.Parent = sfxGroup
    end
end

print("[MenusSFXSetup] UI SFX sounds ready in SoundService")
