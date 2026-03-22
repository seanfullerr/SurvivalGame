-- DoubleJump v16: Polished flip + organic air pose
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local KSP = game:GetService("KeyframeSequenceProvider")
local SFX = require(RS:WaitForChild("SoundManager"))

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

---------- TUNING ----------
local DOUBLE_JUMP_POWER = 64
local MAX_EXTRA_JUMPS = 1
local MIN_AIRTIME = 0.12
local MOMENTUM_CANCEL_FACTOR = 0.4
local FOV_KICK = 3

---------- STATE ----------
local extraJumpsUsed = 0
local isGrounded = true
local leftGroundTime = 0
local jumpIndicator = nil
local flipTrack = nil
local airPoseTrack = nil
local flipAnimUrl = nil
local airPoseAnimUrl = nil
local flipReady = false
local airPoseReady = false

---------- JUMP INDICATOR ----------
local function createJumpIndicator()
    local pgui = player:WaitForChild("PlayerGui")
    local sg = pgui:FindFirstChild("GameHUD")
    if not sg then return end
    local dot = Instance.new("Frame")
    dot.Name = "JumpIndicator"
    dot.Size = UDim2.new(0, 8, 0, 8)
    dot.Position = UDim2.new(0.5, 0, 1, -46)
    dot.AnchorPoint = Vector2.new(0.5, 0.5)
    dot.BackgroundColor3 = Color3.fromRGB(160, 210, 255)
    dot.BackgroundTransparency = 0.3
    dot.BorderSizePixel = 0; dot.ZIndex = 3; dot.Parent = sg
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0); corner.Parent = dot
    jumpIndicator = dot; jumpIndicator.Visible = false
end

local function updateIndicator()
    if not jumpIndicator then return end
    local canJump = (not isGrounded) and (extraJumpsUsed < MAX_EXTRA_JUMPS)
        and (tick() - leftGroundTime) >= MIN_AIRTIME
    jumpIndicator.Visible = canJump
    if canJump then
        jumpIndicator.BackgroundTransparency = 0.2
        TweenService:Create(jumpIndicator, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, -1, true),
            {BackgroundTransparency = 0.6, Size = UDim2.new(0, 10, 0, 10)}):Play()
    end
end

--=============================================
-- ANIMATION HELPERS
--=============================================
local r = math.rad
local EC = Enum.PoseEasingStyle.Cubic
local EL = Enum.PoseEasingStyle.Linear
local EIn = Enum.PoseEasingDirection.In
local EOut = Enum.PoseEasingDirection.Out
local EIO = Enum.PoseEasingDirection.InOut

local function makePose(name, cf, parent, es, ed)
    local p = Instance.new("Pose")
    p.Name = name
    p.CFrame = cf
    if es then p.EasingStyle = es end
    if ed then p.EasingDirection = ed end
    p.Parent = parent
    return p
end

--=============================================
-- FLIP ANIMATION (0.40s, organic front flip)
--=============================================
-- Arm Z axis: NEGATIVE = outward for left, POSITIVE = outward for right
-- In addFrame: left gets armS directly, right gets -armS
-- So: negative armS = arms spread OUT, positive armS = arms tuck IN
--
-- Leg X axis: POSITIVE = thigh forward, NEGATIVE = thigh backward
-- LowerLeg: NEGATIVE X = natural knee bend (shin trails behind)

local function buildFlipAnimation()
    local kfs = Instance.new("KeyframeSequence")
    kfs.Priority = Enum.AnimationPriority.Action4
    kfs.Loop = false

    -- Full-body keyframe with per-limb control + torso twist
    local function addFrame(t, o)
        local es = o.es or EC
        local ed = o.ed or EIO
        local kf = Instance.new("Keyframe"); kf.Time = t
        local hrp = makePose("HumanoidRootPart", CFrame.new(), kf, es, ed)

        -- Torso: flip rotation + optional twist
        local ltCF = CFrame.Angles(o.flip or 0, o.twist or 0, o.tilt or 0)
        local lt = makePose("LowerTorso", ltCF, hrp, es, ed)
        local ut = makePose("UpperTorso", CFrame.Angles(o.waist or 0, o.waistTwist or 0, 0), lt, es, ed)
        makePose("Head", CFrame.Angles(o.head or 0, 0, 0), ut, es, ed)

        -- Legs: allow asymmetry
        local luL = o.uLegL or o.uLeg or 0
        local ruL = o.uLegR or o.uLeg or 0
        local llL = o.lLegL or o.lLeg or 0
        local rlL = o.lLegR or o.lLeg or 0
        local lul = makePose("LeftUpperLeg", CFrame.Angles(luL, 0, 0), lt, es, ed)
        local rul = makePose("RightUpperLeg", CFrame.Angles(ruL, 0, 0), lt, es, ed)
        makePose("LeftLowerLeg", CFrame.Angles(llL, 0, 0), lul, es, ed)
        makePose("RightLowerLeg", CFrame.Angles(rlL, 0, 0), rul, es, ed)

        -- Arms: allow asymmetry, armS = spread (neg=out, pos=in for left)
        local laS = o.armSL or o.armS or 0
        local raS = o.armSR or -(o.armS or 0)
        local laP = o.armPL or o.armP or 0
        local raP = o.armPR or o.armP or 0
        local laF = o.forearmL or o.forearm or 0
        local raF = o.forearmR or o.forearm or 0
        local lua = makePose("LeftUpperArm", CFrame.Angles(laP, 0, laS), ut, es, ed)
        local rua = makePose("RightUpperArm", CFrame.Angles(raP, 0, raS), ut, es, ed)
        makePose("LeftLowerArm", CFrame.Angles(laF, 0, 0), lua, es, ed)
        makePose("RightLowerArm", CFrame.Angles(raF, 0, 0), rua, es, ed)

        kf.Parent = kfs
    end

    -- ===== KEYFRAMES (0.50s, arms trail behind rotation) =====

    -- t=0.00 | Neutral
    addFrame(0.00, {
        flip=0, twist=0, waist=0, head=0,
        uLeg=0, lLeg=0,
        armP=0, armS=0, forearm=0,
        es=EC, ed=EOut
    })

    -- t=0.04 | Anticipation — body coils down, arms lift up preparing to sweep
    addFrame(0.04, {
        flip=-r(10), twist=r(3), waist=r(10), head=r(5),
        uLeg=r(8), lLeg=r(5),
        armP=-r(25), armS=-r(10), forearm=-r(10),
        es=EC, ed=EIn
    })

    -- t=0.09 | Launch — body commits forward, arms sweep UP and BACK (trailing)
    addFrame(0.09, {
        flip=-r(50), twist=r(4), waist=r(20), head=r(12),
        uLegL=r(24), uLegR=r(18), lLegL=-r(8), lLegR=-r(5),
        armP=-r(60), armS=-r(15), forearm=-r(20),
        es=EC, ed=EIO
    })

    -- t=0.14 | Arms overhead — body tucking, arms fully extended back/up
    addFrame(0.14, {
        flip=-r(110), twist=r(3), waist=r(30), waistTwist=r(3), head=r(18),
        uLegL=r(42), uLegR=r(36), lLegL=-r(28), lLegR=-r(22),
        armP=-r(90), armS=-r(12), forearm=-r(10),
        es=EC, ed=EIO
    })

    -- t=0.20 | Half flip — upside down, arms trailing above (which is below in world)
    addFrame(0.20, {
        flip=-r(180), twist=r(2), waist=r(25), waistTwist=r(2), head=r(15),
        uLegL=r(40), uLegR=r(34), lLegL=-r(30), lLegR=-r(24),
        armP=-r(80), armS=-r(10), forearm=-r(15),
        es=EC, ed=EIO
    })

    -- t=0.27 | Past halfway — arms starting to sweep forward/down with rotation
    addFrame(0.27, {
        flip=-r(255), twist=-r(2), waist=r(14), waistTwist=-r(2), head=r(8),
        uLegL=r(22), uLegR=r(14), lLegL=-r(18), lLegR=-r(12),
        armP=-r(45), armS=-r(8), forearm=-r(12),
        es=EC, ed=EIO
    })

    -- t=0.34 | Three-quarter — arms sweeping down, body opening
    addFrame(0.34, {
        flip=-r(320), twist=-r(3), waist=r(5), head=r(2),
        uLegL=r(15), uLegR=r(6), lLegL=-r(15), lLegR=-r(8),
        armPL=-r(20), armPR=-r(18), armSL=-r(12), armSR=r(12), forearm=-r(10),
        es=EC, ed=EOut
    })

    -- t=0.42 | Arms settling — blending toward air pose
    addFrame(0.42, {
        flip=-r(354), twist=-r(2), waist=r(2), head=-r(3),
        uLegL=r(24), uLegR=r(3), lLegL=-r(38), lLegR=-r(8),
        armPL=-r(12), armPR=-r(10), armSL=-r(16), armSR=r(16), forearmL=-r(14), forearmR=-r(11),
        es=EC, ed=EOut
    })

    -- t=0.48 | Nearly done — almost air pose
    addFrame(0.48, {
        flip=-r(359), twist=-r(1), waist=r(1), waistTwist=r(2), head=-r(5),
        uLegL=r(28), uLegR=r(2), lLegL=-r(45), lLegR=-r(8),
        armPL=-r(10), armPR=-r(8), armSL=-r(18), armSR=r(18), forearmL=-r(15), forearmR=-r(12),
        es=EC, ed=EOut
    })

    -- t=0.50 | Finish — exact air pose
    addFrame(0.50, {
        flip=-r(360), twist=0, waist=r(1), waistTwist=r(2), head=-r(5),
        uLegL=r(28), uLegR=r(2), lLegL=-r(45), lLegR=-r(8),
        armPL=-r(10), armPR=-r(8), armSL=-r(18), armSR=r(18), forearmL=-r(15), forearmR=-r(12),
        es=EC, ed=EOut
    })

    local ok, url = pcall(function()
        return KSP:RegisterKeyframeSequence(kfs)
    end)
    if ok and url then
        flipAnimUrl = url
        flipReady = true
        print("[DoubleJump] Flip registered")
    else
        warn("[DoubleJump] Flip register failed: " .. tostring(url))
    end
end

--=============================================
-- AIR POSE (looping, organic falling)
--=============================================
local function buildAirPose()
    local kfs = Instance.new("KeyframeSequence")
    kfs.Priority = Enum.AnimationPriority.Action4
    kfs.Loop = true

    -- Frame 1: Left leg leads, slight torso twist left
    local kf = Instance.new("Keyframe"); kf.Time = 0
    local hrp = makePose("HumanoidRootPart", CFrame.new(), kf, EC, EIO)
    local lt = makePose("LowerTorso", CFrame.Angles(r(5), r(3), 0), hrp, EC, EIO)
    local ut = makePose("UpperTorso", CFrame.Angles(r(3), r(2), 0), lt, EC, EIO)
    makePose("Head", CFrame.Angles(-r(5), -r(2), 0), ut, EC, EIO)
    -- Arms: slightly back + out, left a bit more relaxed
    local lua = makePose("LeftUpperArm", CFrame.Angles(-r(10), 0, -r(18)), ut, EC, EIO)
    local rua = makePose("RightUpperArm", CFrame.Angles(-r(8), 0, r(18)), ut, EC, EIO)
    makePose("LeftLowerArm", CFrame.Angles(-r(15), 0, 0), lua, EC, EIO)
    makePose("RightLowerArm", CFrame.Angles(-r(12), 0, 0), rua, EC, EIO)
    -- Legs: left forward+bent, right trailing straight
    local lul = makePose("LeftUpperLeg", CFrame.Angles(r(28), 0, 0), lt, EC, EIO)
    local rul = makePose("RightUpperLeg", CFrame.Angles(r(2), 0, 0), lt, EC, EIO)
    makePose("LeftLowerLeg", CFrame.Angles(-r(45), 0, 0), lul, EC, EIO)
    makePose("RightLowerLeg", CFrame.Angles(-r(8), 0, 0), rul, EC, EIO)
    kf.Parent = kfs

    -- Frame 2 (t=0.9): Drift — legs swap, torso twists right, arms shift
    local kf2 = Instance.new("Keyframe"); kf2.Time = 0.9
    local hrp2 = makePose("HumanoidRootPart", CFrame.new(), kf2, EC, EIO)
    local lt2 = makePose("LowerTorso", CFrame.Angles(r(6), -r(3), 0), hrp2, EC, EIO)
    local ut2 = makePose("UpperTorso", CFrame.Angles(r(4), -r(2), 0), lt2, EC, EIO)
    makePose("Head", CFrame.Angles(-r(4), r(2), 0), ut2, EC, EIO)
    -- Arms: right drops a bit more, left lifts slightly
    local lua2 = makePose("LeftUpperArm", CFrame.Angles(-r(6), 0, -r(22)), ut2, EC, EIO)
    local rua2 = makePose("RightUpperArm", CFrame.Angles(-r(12), 0, r(15)), ut2, EC, EIO)
    makePose("LeftLowerArm", CFrame.Angles(-r(10), 0, 0), lua2, EC, EIO)
    makePose("RightLowerArm", CFrame.Angles(-r(18), 0, 0), rua2, EC, EIO)
    -- Legs: right now forward+bent, left trailing
    local lul2 = makePose("LeftUpperLeg", CFrame.Angles(r(3), 0, 0), lt2, EC, EIO)
    local rul2 = makePose("RightUpperLeg", CFrame.Angles(r(26), 0, 0), lt2, EC, EIO)
    makePose("LeftLowerLeg", CFrame.Angles(-r(6), 0, 0), lul2, EC, EIO)
    makePose("RightLowerLeg", CFrame.Angles(-r(42), 0, 0), rul2, EC, EIO)
    kf2.Parent = kfs

    local ok, url = pcall(function()
        return KSP:RegisterKeyframeSequence(kfs)
    end)
    if ok and url then
        airPoseAnimUrl = url
        airPoseReady = true
        print("[DoubleJump] Air pose registered")
    else
        warn("[DoubleJump] Air pose failed: " .. tostring(url))
    end
end

--=============================================
-- LOAD TRACKS
--=============================================
local function loadTracks(char)
    local hum = char:FindFirstChild("Humanoid")
    if not hum then return end
    local animator = hum:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator"); animator.Parent = hum
    end
    if flipReady then
        local a = Instance.new("Animation"); a.AnimationId = flipAnimUrl
        local ok, t = pcall(function() return animator:LoadAnimation(a) end)
        if ok and t then
            t.Priority = Enum.AnimationPriority.Action4; flipTrack = t
            print("[DoubleJump] Flip track loaded")
        end
    end
    if airPoseReady then
        local a = Instance.new("Animation"); a.AnimationId = airPoseAnimUrl
        local ok, t = pcall(function() return animator:LoadAnimation(a) end)
        if ok and t then
            t.Priority = Enum.AnimationPriority.Action4; airPoseTrack = t
            print("[DoubleJump] Air pose track loaded")
        end
    end
end

--=============================================
-- PLAY / STOP
--=============================================
local function playFlip()
    if not flipTrack then return end
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        local animator = hum:FindFirstChildOfClass("Animator")
        if animator then
            for _, t in ipairs(animator:GetPlayingAnimationTracks()) do
                if t ~= flipTrack and t ~= airPoseTrack then
                    t:Stop(0.03)
                end
            end
        end
    end
    flipTrack:Play(0.03)
    -- Seamless crossfade: flip ends at 0.40, start air pose at 0.37 with 0.15s blend
    task.delay(0.46, function()
        if airPoseTrack and not isGrounded then
            airPoseTrack:Play(0.15)
        end
    end)
end

local function stopAirPose()
    if airPoseTrack and airPoseTrack.IsPlaying then
        airPoseTrack:Stop(0.12)
    end
end

--=============================================
-- VFX
--=============================================
local function doAirRing(hrp)
    local ring = Instance.new("Part")
    ring.Shape = Enum.PartType.Cylinder
    ring.Size = Vector3.new(0.08, 2, 2)
    ring.CFrame = CFrame.new(hrp.Position + Vector3.new(0, -2.5, 0)) * CFrame.Angles(0, 0, r(90))
    ring.Anchored = true; ring.CanCollide = false
    ring.Color = Color3.fromRGB(180, 215, 255)
    ring.Material = Enum.Material.Neon; ring.Transparency = 0.1
    ring.Parent = workspace
    TweenService:Create(ring, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Size = Vector3.new(0.01, 11, 11), Transparency = 1}):Play()
    Debris:AddItem(ring, 0.35)
end

local function doKickPuff(hrp)
    local att = Instance.new("Attachment")
    att.Position = Vector3.new(0, -2.5, 0); att.Parent = hrp
    local puff = Instance.new("ParticleEmitter")
    puff.Color = ColorSequence.new(Color3.fromRGB(215, 225, 240), Color3.fromRGB(245, 245, 255))
    puff.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(0.25, 2.5),
        NumberSequenceKeypoint.new(0.6, 3.5), NumberSequenceKeypoint.new(1, 4.0),
    })
    puff.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.25, 0.3),
        NumberSequenceKeypoint.new(0.6, 0.65), NumberSequenceKeypoint.new(1, 1),
    })
    puff.Lifetime = NumberRange.new(0.12, 0.35)
    puff.Speed = NumberRange.new(5, 14)
    puff.SpreadAngle = Vector2.new(180, 25)
    puff.Acceleration = Vector3.new(0, -10, 0)
    puff.RotSpeed = NumberRange.new(-180, 180)
    puff.Rate = 0; puff.LightEmission = 0.3; puff.Parent = att
    puff:Emit(14)
    Debris:AddItem(att, 0.5)
end

local function doSpeedStreaks(hrp)
    local att = Instance.new("Attachment"); att.Parent = hrp
    local lines = Instance.new("ParticleEmitter")
    lines.Color = ColorSequence.new(Color3.fromRGB(190, 215, 240), Color3.fromRGB(230, 240, 255))
    lines.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0.03)})
    lines.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.6, 0.4), NumberSequenceKeypoint.new(1, 1),
    })
    lines.Lifetime = NumberRange.new(0.06, 0.14)
    lines.Speed = NumberRange.new(25, 45)
    lines.SpreadAngle = Vector2.new(10, 10)
    lines.EmissionDirection = Enum.NormalId.Bottom
    lines.Rate = 0; lines.LightEmission = 0.7; lines.Parent = att
    lines:Emit(10)
    Debris:AddItem(att, 0.25)
end

local function doSoftGlow(hrp)
    local glow = Instance.new("PointLight")
    glow.Color = Color3.fromRGB(180, 210, 240)
    glow.Brightness = 1.5; glow.Range = 8; glow.Parent = hrp
    TweenService:Create(glow, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        {Brightness = 0}):Play()
    Debris:AddItem(glow, 0.4)
end

local function doFOVKick()
    local origFOV = camera.FieldOfView
    TweenService:Create(camera, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {FieldOfView = origFOV + FOV_KICK}):Play()
    task.delay(0.06, function()
        TweenService:Create(camera, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
            {FieldOfView = origFOV}):Play()
    end)
end

-- Landing dust: puff of particles + thud + tiny camera settle
local lastAirTime = 0
local function doLandingVFX(hrp)
    local airDuration = tick() - lastAirTime
    if airDuration < 0.3 then return end  -- ignore tiny hops

    local intensity = math.clamp(airDuration / 1.5, 0.3, 1.0)

    -- Dust puff
    local att = Instance.new("Attachment")
    att.Position = Vector3.new(0, -2.5, 0)  -- at feet
    att.Parent = hrp

    local dust = Instance.new("ParticleEmitter")
    dust.Color = ColorSequence.new(Color3.fromRGB(180, 170, 150), Color3.fromRGB(140, 130, 120))
    dust.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.5 * intensity),
        NumberSequenceKeypoint.new(0.3, 2.5 * intensity),
        NumberSequenceKeypoint.new(1, 4 * intensity),
    })
    dust.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.4),
        NumberSequenceKeypoint.new(0.4, 0.6),
        NumberSequenceKeypoint.new(1, 1),
    })
    dust.Lifetime = NumberRange.new(0.3, 0.7)
    dust.Speed = NumberRange.new(2 * intensity, 6 * intensity)
    dust.SpreadAngle = Vector2.new(180, 10)  -- flat horizontal burst
    dust.Acceleration = Vector3.new(0, 2, 0)  -- slight rise
    dust.RotSpeed = NumberRange.new(-60, 60)
    dust.Rate = 0
    dust.LightEmission = 0.1
    dust.Parent = att
    dust:Emit(math.floor(8 * intensity))
    Debris:AddItem(att, 1.0)

    -- Thud sound (scaled by air time)
    SFX.PlayUI("LandThud", camera, {
        Volume = 0.15 * intensity,
        PlaybackSpeed = 1.1 - intensity * 0.2,  -- lower pitch for bigger falls
    })

    -- Tiny camera settle (barely perceptible downward nudge)
    if intensity > 0.5 then
        task.spawn(function()
            local orig = camera.CFrame
            camera.CFrame = orig * CFrame.new(0, -0.15 * intensity, 0)
            RunService.RenderStepped:Wait()
            camera.CFrame = orig
        end)
    end
end

local function doDoubleJumpVFX(hrp)
    playFlip()
    doAirRing(hrp)
    doKickPuff(hrp)
    doSoftGlow(hrp)
    doFOVKick()
    task.delay(0.03, function()
        if hrp and hrp.Parent then doSpeedStreaks(hrp) end
    end)
end

--=============================================
-- JUMP LOGIC
--=============================================
local function executeDoubleJump()
    local char = player.Character
    if not char then return false end
    local hum = char:FindFirstChild("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp or hum.Health <= 0 then return false end
    if isGrounded then return false end
    if (tick() - leftGroundTime) < MIN_AIRTIME then return false end
    if extraJumpsUsed >= MAX_EXTRA_JUMPS then return false end

    extraJumpsUsed = extraJumpsUsed + 1
    local vel = hrp.AssemblyLinearVelocity
    local yVel = vel.Y
    local cancelledY = yVel < 0 and yVel * MOMENTUM_CANCEL_FACTOR or yVel * 0.3
    hrp.AssemblyLinearVelocity = Vector3.new(vel.X, cancelledY + DOUBLE_JUMP_POWER, vel.Z)

    SFX.PlayUI("DoubleJump", camera, {Volume = 0.45, PlaybackSpeed = 1.8})
    doDoubleJumpVFX(hrp)
    if jumpIndicator then jumpIndicator.Visible = false end
    return true
end

---------- STATE TRACKING ----------
local function onCharacterAdded(char)
    local hum = char:WaitForChild("Humanoid")
    extraJumpsUsed = 0; isGrounded = true; leftGroundTime = 0
    flipTrack = nil; airPoseTrack = nil
    loadTracks(char)

    hum.StateChanged:Connect(function(_, newState)
        if newState == Enum.HumanoidStateType.Landed
            or newState == Enum.HumanoidStateType.Running then
            isGrounded = true; extraJumpsUsed = 0
            stopAirPose()
            updateIndicator()
            -- Landing dust + thud
            local chr = player.Character
            if chr then
                local hrpLand = chr:FindFirstChild("HumanoidRootPart")
                if hrpLand then doLandingVFX(hrpLand) end
            end
        elseif newState == Enum.HumanoidStateType.Jumping
            or newState == Enum.HumanoidStateType.Freefall then
            isGrounded = false
            leftGroundTime = tick()
            lastAirTime = tick()
            updateIndicator()
            task.delay(MIN_AIRTIME, function()
                if not isGrounded and extraJumpsUsed < MAX_EXTRA_JUMPS then
                    updateIndicator()
                end
            end)
        end
    end)

    hum:GetPropertyChangedSignal("FloorMaterial"):Connect(function()
        if hum.FloorMaterial ~= Enum.Material.Air then
            isGrounded = true; extraJumpsUsed = 0
            stopAirPose()
            updateIndicator()
        end
    end)
end

---------- INPUT ----------
UIS.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
        executeDoubleJump()
    end
end)

UIS.JumpRequest:Connect(function()
    executeDoubleJump()
end)

---------- INIT ----------
buildFlipAnimation()
buildAirPose()

player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then onCharacterAdded(player.Character) end

task.spawn(function()
    player:WaitForChild("PlayerGui"):WaitForChild("GameHUD", 10)
    task.wait(0.2)
    createJumpIndicator()
end)

print("[DoubleJump v18] Ready — polished flip + organic air pose!")
