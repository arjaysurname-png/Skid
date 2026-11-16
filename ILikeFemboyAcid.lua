--!nocheck
--!nolint
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

getgenv().meow_flags = getgenv().meow_flags or {}
local flags = getgenv().meow_flags
local meowState = {
    Destroyed = false,
    PriorityList = {},
    CustomSoundCache = {},
    ModDetectorChecked = {},
    CurrentTarget = nil,
    LastTargetPlayer = nil,
    LastMeleeAttack = 0,
    KnifeAt = 0,
    KnifeBurst = 0,
    IndicatorLabel = nil,
    IndicatorGui = nil,
    IndicatorFrame = nil,
    ManipulatedActive = false,
    DamageDealt = 0,
    DamageTaken = 0,
    LastHitmarkerTime = 0,

    TargetHudGui = nil,
    TargetHudFrame = nil,
    TargetHighlight = nil,
    TargetSnapline = nil,
    CrosshairLines = {},
    CrosshairOutlines = {},
    SilentFovCircle = nil,
    SilentFovOutline = nil,
    AimbotFovCircle = nil,
    TracerDrawings = {},
    OriginalCameraFov = nil,

    EspBoxes = {},
    ChamsHighlights = {},

    AppliedAdornments = {},
    AppliedSelectionBoxes = {},
    WeaponHighlight = nil,
    SavedPartProps = {},
    LastItemVisual = nil,

    OriginalSkybox = nil,
    ActiveSkybox = nil,
}

local fakePos = {
    Enabled           = false,
    Depth             = 5.8,
    WalkMode          = true,
    SurfaceCamera     = true,
    AutoNoclip        = true,
    AutoHandoff       = true,
    VisualizerEnabled = true,
    VisualizerColor   = Color3.fromRGB(0, 162, 255),
    Panic             = false,
    PanicMinX         = -5,
    PanicMaxX         = 5,
    PanicZ            = false,
    HideMeshes        = true,
    AnimationDesync   = true,
    ZeroVelocity      = true,
    CustomPitch       = 0,
    CustomYaw         = 0,
    InvertPitch       = false,
    DesyncMode        = "Position Desync V2",

    VirtualCF         = nil,
    LastMoveDir       = Vector3.zero,
    GhostBox          = nil,
    AnimTrack         = nil,
    OriginalParts     = nil,
    HandoffTicks      = 0,
    ClientCF          = nil,
    FakeCF            = nil,
}

local movementState = {
    WalkSpeedEnabled  = false,
    WalkSpeedMult     = 1.0,
    SlidingEnabled    = false,
    SlidingMult       = 1.0,
    NoclipEnabled     = false,
    FlightEnabled     = false,
    FlightSpeed       = 100,
    DoubleJump        = false,
    DoubleJumpHeight  = 1.0,
    LongJump          = false,
    LongJumpMode      = "Camera Look",
    LongJumpForce     = 150,
    LongJumpUpward    = 100,
    AutoStrafe        = false,
    AutoStrafeSpeed   = 50,
}

local staffDetectorState = {
    Enabled           = true,
    AutoHop           = false,
    AutoKick          = false,
    DetectedStaff     = {},
}

local function undergroundCaptureOriginal()
    local char = LocalPlayer and LocalPlayer.Character
    if not char then return end
    fakePos.OriginalParts = {}
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") or part:IsA("Decal") then
            table.insert(fakePos.OriginalParts, { part = part, transparency = part.Transparency })
            if fakePos.HideMeshes then
                pcall(function() part.Transparency = 1 end)
            end
        end
    end
end

local function undergroundRestoreOriginal()
    if not fakePos.OriginalParts then return end
    for _, data in ipairs(fakePos.OriginalParts) do
        if data.part and data.part.Parent then
            pcall(function() data.part.Transparency = data.transparency end)
        end
    end
    fakePos.OriginalParts = nil
end

local function playAnimDesync()
    local char = LocalPlayer and LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if not fakePos.AnimTrack then
        pcall(function()
            local anim = Instance.new("Animation")
            anim.AnimationId = "rbxassetid://10714003221"
            local track = hum:LoadAnimation(anim)
            track:Play(0, 1, 0)
            track.TimePosition = 1.48
            fakePos.AnimTrack = track
        end)
    end
end

local function stopAnimDesync()
    if fakePos.AnimTrack then
        pcall(function()
            fakePos.AnimTrack:Stop()
            fakePos.AnimTrack:Destroy()
        end)
        fakePos.AnimTrack = nil
    end
end

local function updateGhostVisualizer()
    if fakePos.Enabled and fakePos.VisualizerEnabled and fakePos.VirtualCF and not meowState.Destroyed then
        if not fakePos.GhostBox or not fakePos.GhostBox.Parent then
            local box = Instance.new("BoxHandleAdornment")
            box.Name = "_MeowFakePosGhost"
            box.Size = Vector3.new(2, 5, 1)
            box.Color3 = fakePos.VisualizerColor or Color3.fromRGB(0, 162, 255)
            box.Transparency = 0.55
            box.AlwaysOnTop = true
            box.ZIndex = 5
            box.Adornee = workspace.Terrain
            pcall(function() box.Parent = LocalPlayer:WaitForChild("PlayerGui") end)
            fakePos.GhostBox = box
        end
        fakePos.GhostBox.CFrame = fakePos.VirtualCF
        fakePos.GhostBox.Color3 = fakePos.VisualizerColor or Color3.fromRGB(0, 162, 255)
    else
        if fakePos.GhostBox then
            pcall(function() fakePos.GhostBox:Destroy() end)
            fakePos.GhostBox = nil
        end
    end
end

local function set_position_desync(source, clientCF, serverCF)
    local genv = getgenv()
    genv.position_desync_source = source
    genv.client_position = typeof(clientCF) == "CFrame" and clientCF.Position or clientCF
    genv.server_position = typeof(serverCF) == "CFrame" and serverCF.Position or serverCF
    genv.v2_tp_pos = (source == "v2" and genv.server_position) or nil
    fakePos.ClientCF = clientCF
    fakePos.FakeCF = serverCF
end

local function clear_position_desync()
    local genv = getgenv()
    local char = LocalPlayer and LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local pos = hrp and hrp.Position
    genv.position_desync_source = nil
    genv.client_position = pos
    genv.server_position = pos
    genv.v2_tp_pos = nil
    fakePos.ClientCF = nil
    fakePos.FakeCF = nil
end

getgenv().set_position_desync = set_position_desync
getgenv().clear_position_desync = clear_position_desync

local function setFakePosition(state)
    if fakePos.Enabled == state then return end
    fakePos.Enabled = state
    flags.fake_position_enabled = state
    getgenv().FakePositionEnabled = state
    getgenv().HideUndergroundEnabled = state
    meowState.ManipulatedActive = state

    local char = LocalPlayer and LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")

    if state then
        if hrp then
            fakePos.VirtualCF = hrp.CFrame
        end
        if fakePos.HideMeshes then undergroundCaptureOriginal() end
        if fakePos.AnimationDesync then playAnimDesync() end

        pcall(function()
            RunService:UnbindFromRenderStep("FakePosCameraElevation")
        end)
        RunService:BindToRenderStep("FakePosCameraElevation", 201, function()
            if fakePos.Enabled and fakePos.SurfaceCamera and not meowState.Destroyed then
                local cam = workspace.CurrentCamera
                local depth = flags.fake_position_depth or fakePos.Depth or 5.8
                if cam and depth > 0 then
                    cam.CFrame = cam.CFrame + Vector3.new(0, depth, 0)
                end
            end
        end)
    else
        pcall(function()
            RunService:UnbindFromRenderStep("FakePosCameraElevation")
        end)
        undergroundRestoreOriginal()
        stopAnimDesync()
        updateGhostVisualizer()

        if hrp and fakePos.VirtualCF then
            pcall(function()
                if fakePos.ZeroVelocity then
                    hrp.AssemblyLinearVelocity = Vector3.zero
                    hrp.AssemblyAngularVelocity = Vector3.zero
                end
                hrp.CFrame = fakePos.VirtualCF
            end)
        end
        fakePos.VirtualCF = nil
        fakePos.HandoffTicks = 0
        clear_position_desync()
    end
end

getgenv().SetFakePosition = setFakePosition
getgenv().ToggleFakePosition = function()
    setFakePosition(not fakePos.Enabled)
    return fakePos.Enabled
end
getgenv().SetFakePositionDepth = function(d)
    if type(d) == "number" then fakePos.Depth = d end
end
getgenv().SetFakePositionHideMesh = function(h)
    fakePos.HideMeshes = (h == true)
    if not fakePos.HideMeshes then
        undergroundRestoreOriginal()
    elseif fakePos.Enabled then
        undergroundCaptureOriginal()
    end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if UserInputService:GetFocusedTextBox() then return end
    local targetKey = flags.fake_position_keybind or Enum.KeyCode.X
    if input.KeyCode == targetKey then
        setFakePosition(not fakePos.Enabled)
        pcall(function()
            if Library and Library.notifications then
                Library.notifications:create_notification({
                    name = "Fake Position",
                    info = fakePos.Enabled and ("Enabled (" .. tostring(fakePos.Depth) .. " studs underground)") or "Disabled",
                    lifetime = 2
                })
            end
        end)
    end
end)

RunService.Heartbeat:Connect(function(dt)
    if not fakePos.Enabled or meowState.Destroyed then return end
    local char = LocalPlayer and LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end

    if fakePos.HandoffTicks > 0 then
        fakePos.HandoffTicks = fakePos.HandoffTicks - 1
        if fakePos.VirtualCF then
            hrp.CFrame = fakePos.VirtualCF
            set_position_desync("handoff", fakePos.VirtualCF, hrp.CFrame)
        end
        return
    end

    if not fakePos.VirtualCF then
        fakePos.VirtualCF = hrp.CFrame
    end

    local cam = Workspace.CurrentCamera
    local camLook = cam and cam.CFrame.LookVector or Vector3.new(0, 0, -1)
    local camYaw = math.atan2(-camLook.X, -camLook.Z)
    local surfaceRot = CFrame.Angles(0, camYaw, 0)

    if not fakePos.VirtualCF then
        fakePos.VirtualCF = CFrame.new(hrp.CFrame.Position) * surfaceRot
    end

    if fakePos.WalkMode then
        local moveDir = hum.MoveDirection
        if moveDir.Magnitude > 0 then
            local speed = hum.WalkSpeed * (movementState.WalkSpeedEnabled and movementState.WalkSpeedMult or 1)
            local deltaPos = moveDir * (speed * dt)
            fakePos.VirtualCF = CFrame.new(fakePos.VirtualCF.Position + deltaPos) * surfaceRot
        else
            fakePos.VirtualCF = CFrame.new(fakePos.VirtualCF.Position) * surfaceRot
        end
    else
        fakePos.VirtualCF = CFrame.new(fakePos.VirtualCF.Position) * surfaceRot
    end

    local depth = flags.fake_position_depth or fakePos.Depth or 5.8
    local undergroundPos = fakePos.VirtualCF.Position - Vector3.new(0, depth, 0)

    if fakePos.Panic then
        local minX = math.min(fakePos.PanicMinX, fakePos.PanicMaxX)
        local maxX = math.max(fakePos.PanicMinX, fakePos.PanicMaxX)
        local jx = minX + math.random() * (maxX - minX)
        local jz = fakePos.PanicZ and ((math.random() - 0.5) * (maxX - minX)) or 0
        undergroundPos = undergroundPos + Vector3.new(jx, 0, jz)
    end

    local pitchAngle = fakePos.InvertPitch and (fakePos.CustomPitch or 0) or 0
    local pitchCF = CFrame.Angles(math.rad(pitchAngle), math.rad(fakePos.CustomYaw or 0), 0)

    if fakePos.AutoNoclip then
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then
                p.CanCollide = false
            end
        end
    end

    if fakePos.ZeroVelocity then
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end

    hrp.CFrame = CFrame.new(undergroundPos) * surfaceRot * pitchCF

    set_position_desync("fake", fakePos.VirtualCF, hrp.CFrame)

    updateGhostVisualizer()
end)

RunService.Heartbeat:Connect(function()
    if not fakePos.Enabled or not fakePos.HideMeshes or meowState.Destroyed then return end
    if not fakePos.OriginalParts then return end
    for _, data in ipairs(fakePos.OriginalParts) do
        local part = data.part
        if part and part.Parent and part.Transparency ~= 1 then
            pcall(function() part.Transparency = 1 end)
        end
    end
end)

RunService.Stepped:Connect(function()
    if meowState.Destroyed then return end
    local char = LocalPlayer and LocalPlayer.Character
    if not char then return end

    if movementState.NoclipEnabled then
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then
                p.CanCollide = false
            end
        end
    end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        if movementState.WalkSpeedEnabled and movementState.WalkSpeedMult > 1.0 then
            hum.WalkSpeed = 16 * movementState.WalkSpeedMult
        end
    end
end)

RunService.Heartbeat:Connect(function()
    if not movementState.FlightEnabled or meowState.Destroyed then return end
    local char = LocalPlayer and LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local cam = Workspace.CurrentCamera
    local moveDir = Vector3.zero

    if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + cam.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - cam.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - cam.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + cam.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.new(0, 1, 0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveDir = moveDir - Vector3.new(0, 1, 0) end

    if moveDir.Magnitude > 0 then
        hrp.Velocity = moveDir.Unit * movementState.FlightSpeed
    else
        hrp.Velocity = Vector3.zero
    end
end)
UserInputService.JumpRequest:Connect(function()
    if meowState.Destroyed then return end
    local char = LocalPlayer and LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return end

    if movementState.DoubleJump then
        hum:ChangeState(Enum.HumanoidStateType.Jumping)
        hrp.Velocity = Vector3.new(hrp.Velocity.X, 50 * movementState.DoubleJumpHeight, hrp.Velocity.Z)
    end

    if movementState.LongJump then
        local cam = Workspace.CurrentCamera
        local dir = (movementState.LongJumpMode == "Camera Look" and cam and cam.CFrame.LookVector) or hrp.CFrame.LookVector
        hrp.Velocity = Vector3.new(dir.X * movementState.LongJumpForce, movementState.LongJumpUpward, dir.Z * movementState.LongJumpForce)
    end
end)

local MOD_KEYWORDS = { "mod", "admin", "staff", "owner", "developer", "tester", "creator", "contributor" }
local function checkStaffMember(player)
    if not staffDetectorState.Enabled or not player or player == LocalPlayer then return end
    task.spawn(function()
        pcall(function()
            local nameLower = player.Name:lower()
            local dispLower = (player.DisplayName or ""):lower()
            local isStaff = (player.UserId == game.CreatorId)

            if not isStaff then
                for _, kw in ipairs(MOD_KEYWORDS) do
                    if nameLower:find(kw) or dispLower:find(kw) then
                        isStaff = true
                        break
                    end
                end
            end

            if isStaff and not staffDetectorState.DetectedStaff[player.UserId] then
                staffDetectorState.DetectedStaff[player.UserId] = true
                local msg = "[Sleepy Hub] Staff / Mod detected: " .. player.Name .. " (" .. player.DisplayName .. ")"
                warn(msg)
                if Library and Library.notifications then
                    Library.notifications:create_notification({
                        name = "Staff Alert",
                        info = "Staff member detected: " .. player.Name,
                        lifetime = 8
                    })
                end
                if staffDetectorState.AutoHop then
                    pcall(function()
                        local ts = game:GetService("TeleportService")
                        ts:Teleport(game.PlaceId, LocalPlayer)
                    end)
                elseif staffDetectorState.AutoKick then
                    LocalPlayer:Kick("Preventive disconnect: Staff member joined")
                end
            end
        end)
    end)
end

Players.PlayerAdded:Connect(checkStaffMember)
task.defer(function()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then checkStaffMember(p) end
    end
end)

match_in_round = function()
    local char = LocalPlayer.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    return hum ~= nil and hum.Health > 0
end

local_fighter_alive = function()
    local char = LocalPlayer.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    return hum ~= nil and hum.Health > 0
end

status_target_name = function(target)
    if not target then return nil end
    if typeof(target) == "Instance" then
        if target:IsA("Player") then return target.DisplayName or target.Name end
        local pl = Players:GetPlayerFromCharacter(target)
        if pl then return pl.DisplayName or pl.Name end
        return target.Name
    elseif type(target) == "table" and target.Player then
        return target.Player.DisplayName or target.Player.Name
    end
    return tostring(target)
end

is_katana_user = function(model, player)
    local char = model or (player and player.Character)
    if not char then return false end
    if char:FindFirstChild("Katana") then return true end
    for _, t in ipairs(char:GetChildren()) do
        if t:IsA("Tool") and t.Name:lower():find("katana") then return true end
    end
    return false
end
manip_is_deflecting = function(fighter)
    if not fighter then return false end
    local char = (type(fighter) == "table" and fighter.Character) or (typeof(fighter) == "Instance" and fighter)
    if not char then return false end
    local katana = char:FindFirstChild("Katana")
    if katana and katana:FindFirstChild("Deflecting") and katana.Deflecting.Value == true then
        return true
    end
    return false
end

shield_blocks_shot = function(targetRoot, shooterPos)
    if not targetRoot then return false end
    local char = targetRoot.Parent
    if not char then return false end
    local shield = char:FindFirstChild("Riot Shield") or char:FindFirstChild("Shield")
    if not shield then return false end
    local targetLook = targetRoot.CFrame.LookVector
    local shotDir = (shooterPos - targetRoot.Position).Unit
    return targetLook:Dot(shotDir) < -0.2
end

ragebot_is_priority = function(player)
    if not player then return false end
    local name = typeof(player) == "Instance" and player.Name or tostring(player)
    return meowState.PriorityList[name:lower()] == true
end

ragebot_add_priority = function(player)
    if not player then return end
    local name = typeof(player) == "Instance" and player.Name or tostring(player)
    meowState.PriorityList[name:lower()] = true
end
getgenv()._Meow_AddPriority = ragebot_add_priority

silent_closest_hitbox = function(char)
    if not char then return nil end
    local mode = flags.target_hitbox or "Head"
    if mode == "Head" then
        return char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
    elseif mode == "HumanoidRootPart" or mode == "Torso" then
        return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
    elseif mode == "Random" then
        local parts = {"Head", "HumanoidRootPart", "UpperTorso", "LowerTorso"}
        return char:FindFirstChild(parts[math.random(1, #parts)]) or char:FindFirstChild("HumanoidRootPart")
    end
    return char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
end
silent_closest_part = silent_closest_hitbox
targeting_silent_part = silent_closest_hitbox
target_aim_part = silent_closest_hitbox
random_hitpart_name = function()
    local p = {"Head", "HumanoidRootPart", "Torso", "UpperTorso"}
    return p[math.random(1, #p)]
end

get_target = function()
    local myChar = LocalPlayer.Character
    if not myChar then return nil end
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end

    local bestTarget = nil
    local bestScore = math.huge
    local method = flags.target_priority or "Lowest Health"
    local fovRadius = flags.fov_radius_smoothed or 120
    local center = Camera.ViewportSize / 2

    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= LocalPlayer and pl.Character then
            local char = pl.Character
            local hum = char:FindFirstChildOfClass("Humanoid")
            local root = char:FindFirstChild("HumanoidRootPart")

            if hum and hum.Health > 0 and root and not char:FindFirstChildOfClass("ForceField") then
                if not (flags.riot_shield_check and shield_blocks_shot(root, myRoot.Position)) then
                    if not (flags.avoid_katana and manip_is_deflecting(char)) then
                        local scrPos, onScreen = Camera:WorldToViewportPoint(root.Position)
                        local fovDist = (Vector2.new(scrPos.X, scrPos.Y) - center).Magnitude

                        if not flags.silent_aim_enabled or fovDist <= fovRadius then
                            local dist = (root.Position - myRoot.Position).Magnitude
                            local health = hum.Health
                            local isPriority = ragebot_is_priority(pl)
                            local score = health

                            if method == "Distance" or method == "Closest Distance" then
                                score = dist
                            elseif method == "Crosshair" then
                                score = fovDist
                            elseif method == "FOV - Lowest Health" then
                                score = (health * 2) + fovDist
                            else
                                score = health
                            end

                            if isPriority then
                                score = score - 10000
                            end

                            if score < bestScore then
                                bestScore = score
                                bestTarget = {
                                    Player = pl,
                                    Character = char,
                                    Humanoid = hum,
                                    RootPart = root,
                                    HitPart = silent_closest_hitbox(char),
                                    Distance = dist,
                                    FOVDistance = fovDist,
                                }
                            end
                        end
                    end
                end
            end
        end
    end

    meowState.CurrentTarget = bestTarget
    if bestTarget then meowState.LastTargetPlayer = bestTarget.Player end
    return bestTarget
end

manip_set_filter = function(char) end
manip_probe = function(origin, dir, model, part)
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances = {LocalPlayer.Character, Camera}
    local res = Workspace:Raycast(origin, dir, rp)
    if not res then return 1 end
    if res.Instance and (res.Instance:IsDescendantOf(model) or res.Instance == part) then
        return 1
    end
    return 0
end
manip_resolve = function() return true end
manip_in_control = function() return flags.manip_result == true end
manip_is_underground = function() return hideUndergroundEnabled end

anti_subspace_friendly = function(mine)
    if not mine then return true end
    local creator = mine:GetAttribute("Creator") or mine:FindFirstChild("Creator")
    if creator and tostring(creator.Value or creator) == LocalPlayer.Name then
        return true
    end
    return false
end

antiaim_extended_char = function(val)
    local ok, char = pcall(function() return utf8 and utf8.char and utf8.char(val or 1114111) or "" end)
    return ok and char or "\255"
end

antiaim_pitch = function(mode, custom)
    mode = mode or flags.antiaim_pitch or "Down"
    if flags.antiaim_hidehead then return -89 end
    if mode == "Down" then return -89
    elseif mode == "Up" then return 89
    elseif mode == "Jitter" or mode == "Up & Down" then return (math.random(1, 2) == 1 and 89 or -89)
    elseif mode == "Random" then return math.random(-89, 89)
    elseif mode == "Custom" then return custom or flags.antiaim_custom_pitch or 0
    elseif mode == "Zero" then return 0 end
    return -89
end

local aaSpinAngle = 0
local aaSwayAngle = 0
local aaSwayDir = 1
local aaJitterFlip = false

antiaim_yaw = function(mode, speed, jitterRange)
    mode = mode or flags.antiaim_yaw or "Spin"
    speed = speed or flags.antiaim_spin_speed or 15
    jitterRange = jitterRange or flags.antiaim_jitter_range or 45
    local dt = 1/60

    if mode == "Backwards" then return 180
    elseif mode == "Left" then return 90
    elseif mode == "Right" then return -90
    elseif mode == "Spin" then
        aaSpinAngle = (aaSpinAngle + (speed * 10 * dt)) % 360
        return aaSpinAngle
    elseif mode == "Sway" then
        aaSwayAngle = aaSwayAngle + (speed * 4 * dt * aaSwayDir)
        if math.abs(aaSwayAngle) > 60 then aaSwayDir = -aaSwayDir end
        return 180 + aaSwayAngle
    elseif mode == "Jitter" then
        aaJitterFlip = not aaJitterFlip
        return aaJitterFlip and (180 + jitterRange) or (180 - jitterRange)
    elseif mode == "Random" then
        return math.random(-180, 180)
    elseif mode == "Custom" then
        return flags.antiaim_custom_yaw or 0
    end
    return 180
end

set_position_desync = function() meowState.ManipulatedActive = true end
clear_position_desync = function() meowState.ManipulatedActive = false end

display_font_face = function(fontName)
    fontName = fontName or flags.esp_font or "MonoSpace"
    if fontName == "ProggyTiny" then return Enum.Font.Code
    elseif fontName == "MonoSpace" then return Enum.Font.RobotoMono
    elseif fontName == "Tahoma" then return Enum.Font.Gotham end
    return Enum.Font.Code
end
apply_display_font = function(label)
    if label and label:IsA("TextLabel") then
        label.Font = display_font_face()
    end
end
spawn_world_marker = function(pos)
    meowState.LastHitmarkerTime = os.clock()
    if not (flags.world_marker_enabled ~= false) or not pos then return end
    task.spawn(function()
        local size = flags.world_marker_size or 1.0
        local length = flags.world_marker_length or 1.0
        local thickness = flags.world_marker_thickness or 0.15
        local duration = flags.world_marker_duration or 0.6
        local growth = (flags.world_marker_growth ~= false) and 1.5 or 1.0
        local markerColor = flags.world_marker_color or Color3.fromRGB(255, 60, 60)

        local anchor = Instance.new("Part")
        anchor.Name = "MeowHitmarker"
        anchor.Anchored = true
        anchor.CanCollide = false
        anchor.CanQuery = false
        anchor.Transparency = 1
        anchor.Size = Vector3.new(0.1, 0.1, 0.1)
        anchor.Position = pos
        anchor.Parent = Workspace
        local bbg = Instance.new("BillboardGui")
        bbg.Adornee = anchor
        bbg.AlwaysOnTop = true
        bbg.Size = UDim2.fromOffset(25 * size, 25 * size)
        bbg.Parent = anchor

        local function makeArm(rot)
            local arm = Instance.new("Frame")
            arm.AnchorPoint = Vector2.new(0.5, 0.5)
            arm.Position = UDim2.fromScale(0.5, 0.5)
            arm.Size = UDim2.new(0, math.max(2, 8 * thickness), 0, math.max(6, 20 * length))
            arm.Rotation = rot
            arm.BackgroundColor3 = markerColor
            arm.BorderSizePixel = 0
            arm.Parent = bbg
            return arm
        end
        makeArm(45)
        makeArm(-45)

        local tw = TweenService:Create(bbg, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.fromOffset(25 * size * growth, 25 * size * growth)
        })
        tw:Play()
        task.delay(duration, function() pcall(function() anchor:Destroy() end) end)
    end)
end
damage_label = function(text, pos) spawn_world_marker(pos) end

local function handleHitDetected(targetName, partName, damage, weaponName, hitPosition)
    if flags.hit_logs_enabled then
        local formatStr = flags.hit_logs_format or "{NAME} hit in {PART} for {DMG} with {WEAPON}"
        local logMsg = formatStr:gsub("{NAME}", tostring(targetName or "Enemy"))
                               :gsub("{PART}", tostring(partName or "Torso"))
                               :gsub("{DMG}", tostring(damage or "0"))
                               :gsub("{WEAPON}", tostring(weaponName or "Weapon"))
        print("[Meow HitLog] " .. logMsg)
    end

    if hitPosition then
        spawn_world_marker(hitPosition)
        if meowState.TriggerBulletTracer then
            meowState.TriggerBulletTracer(hitPosition)
        end
    end

    if playEventSound then playEventSound("hit") end
    if damage and tonumber(damage) then
        meowState.DamageDealt = meowState.DamageDealt + tonumber(damage)
    end
end
getgenv()._Meow_TriggerHit = handleHitDetected

local HIT_SOUND_PRESETS = {
    ["Rust"] = "rbxassetid://1255040462",
    ["Skeet"] = "rbxassetid://5633695679",
    ["Bell"] = "rbxassetid://6534947240",
    ["Bonk"] = "rbxassetid://3997129949",
    ["Neverlose"] = "rbxassetid://6607204501",
    ["Bubble"] = "rbxassetid://6534947588",
}

local KILL_SOUND_PRESETS = {
    ["Oof"] = "rbxassetid://5143383166",
    ["Fatality"] = "rbxassetid://6607204928",
    ["Headshot"] = "rbxassetid://6534948092",
    ["Skeet"] = "rbxassetid://5633695679",
}

local function playRawSound(assetId, volume, pitch)
    if not assetId or assetId == "" then return end
    task.spawn(function()
        local s = Instance.new("Sound")
        s.SoundId = assetId
        s.Volume = volume or 1.0
        s.PlaybackSpeed = pitch or 1.0
        s.Parent = SoundService
        s:Play()
        s.Ended:Connect(function() s:Destroy() end)
        task.delay(5, function() if s and s.Parent then s:Destroy() end end)
    end)
end

playEventSound = function(eventType)
    local volume = flags.sound_volume or 1.0
    local pitch = flags.sound_pitch or 1.0

    if eventType == "hit" and (flags.hit_sound_enabled ~= false) then
        local preset = flags.hit_sound_preset or "Rust"
        local asset = HIT_SOUND_PRESETS[preset] or HIT_SOUND_PRESETS["Rust"]
        if preset == "Custom ID" and flags.hit_sound_custom_id then
            asset = flags.hit_sound_custom_id
        end
        if asset then playRawSound(asset, volume, pitch) end
    elseif eventType == "kill" and flags.kill_sound_enabled then
        local preset = flags.kill_sound_preset or "Fatality"
        local asset = KILL_SOUND_PRESETS[preset] or KILL_SOUND_PRESETS["Fatality"]
        if preset == "Custom ID" and flags.kill_sound_custom_id then
            asset = flags.kill_sound_custom_id
        end
        if asset then playRawSound(asset, volume, pitch) end
    elseif eventType == "death" and flags.death_sound_enabled then
        playRawSound(KILL_SOUND_PRESETS["Oof"], volume, pitch)
    end
end
getgenv()._Meow_PlayEventSound = playEventSound

local function ensureTargetHudGui()
    if meowState.TargetHudGui and meowState.TargetHudGui.Parent then return end
    pcall(function()
        local parent = LocalPlayer:WaitForChild("PlayerGui")
        local sg = Instance.new("ScreenGui")
        sg.Name = "_MeowTargetHUD"
        sg.ResetOnSpawn = false
        sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

        local frame = Instance.new("Frame")
        frame.Name = "HUDCard"
        frame.Size = UDim2.fromOffset(420, 136)
        frame.AnchorPoint = Vector2.new(0.5, 0.5)
        frame.Position = UDim2.fromScale(0.5, 0.76)
        frame.BackgroundColor3 = Color3.fromRGB(15, 15, 17)
        frame.BorderSizePixel = 0
        frame.Visible = false
        frame.ZIndex = 120
        frame.Parent = sg

        local uisOuter = Instance.new("UIStroke")
        uisOuter.Color = Color3.fromRGB(0, 0, 0)
        uisOuter.Thickness = 1
        uisOuter.Parent = frame

        local nest1 = Instance.new("Frame")
        nest1.Position = UDim2.fromOffset(5, 5)
        nest1.Size = UDim2.new(1, -10, 1, -10)
        nest1.BackgroundTransparency = 1
        nest1.BorderSizePixel = 0
        nest1.ZIndex = 121
        nest1.Parent = frame

        local uisNest1 = Instance.new("UIStroke")
        uisNest1.Color = Color3.fromRGB(35, 35, 40)
        uisNest1.Thickness = 1
        uisNest1.Parent = nest1

        local content = Instance.new("Frame")
        content.Position = UDim2.fromOffset(5, 5)
        content.Size = UDim2.new(1, -10, 1, -10)
        content.BackgroundColor3 = Color3.fromRGB(18, 18, 20)
        content.BorderSizePixel = 0
        content.ZIndex = 122
        content.Parent = nest1

        local uisContent = Instance.new("UIStroke")
        uisContent.Color = Color3.fromRGB(28, 28, 32)
        uisContent.Thickness = 1
        uisContent.Parent = content

        local dragging, dragStart, startPos
        frame.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = frame.Position
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragging = false
                    end
                end)
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - dragStart
                frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)

        local slotPositions = {
            UDim2.fromOffset(10, 10),
            UDim2.fromOffset(10, 66),
            UDim2.new(1, -58, 0, 10),
            UDim2.new(1, -58, 0, 66),
        }

        local weaponSlots = {}
        for i = 1, 4 do
            local slotBox = Instance.new("Frame")
            slotBox.Name = "Slot" .. i
            slotBox.Position = slotPositions[i]
            slotBox.Size = UDim2.fromOffset(48, 48)
            slotBox.BackgroundColor3 = Color3.fromRGB(14, 14, 16)
            slotBox.BorderSizePixel = 0
            slotBox.ZIndex = 124
            slotBox.Parent = content

            local sStroke = Instance.new("UIStroke")
            sStroke.Color = Color3.fromRGB(32, 32, 36)
            sStroke.Thickness = 1
            sStroke.Parent = slotBox

            local sImg = Instance.new("ImageLabel")
            sImg.Name = "Icon"
            sImg.AnchorPoint = Vector2.new(0.5, 0.5)
            sImg.Position = UDim2.fromScale(0.5, 0.5)
            sImg.Size = UDim2.fromScale(0.85, 0.85)
            sImg.BackgroundTransparency = 1
            sImg.ScaleType = Enum.ScaleType.Fit
            sImg.ImageColor3 = Color3.fromRGB(180, 185, 200)
            sImg.ImageTransparency = 0.4
            sImg.ZIndex = 125
            sImg.Parent = slotBox

            weaponSlots[i] = sImg
        end

        local nameLbl = Instance.new("TextLabel")
        nameLbl.Name = "PlayerName"
        nameLbl.Position = UDim2.fromOffset(72, 10)
        nameLbl.Size = UDim2.new(1, -144, 0, 18)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Font = Enum.Font.GothamBold
        nameLbl.Text = "No Target"
        nameLbl.TextColor3 = Color3.fromRGB(240, 243, 255)
        nameLbl.TextSize = 14
        nameLbl.TextXAlignment = Enum.TextXAlignment.Center
        nameLbl.ZIndex = 125
        nameLbl.Parent = content

        local statsLbl = Instance.new("TextLabel")
        statsLbl.Name = "Stats"
        statsLbl.Position = UDim2.fromOffset(72, 30)
        statsLbl.Size = UDim2.new(1, -144, 0, 14)
        statsLbl.BackgroundTransparency = 1
        statsLbl.Font = Enum.Font.GothamMedium
        statsLbl.Text = 'level <font color="#00A2FF">N/A</font>  rank <font color="#00A2FF">N/A</font>  device <font color="#00A2FF">N/A</font>  streak <font color="#00A2FF">N/A</font>'
        statsLbl.RichText = true
        statsLbl.TextColor3 = Color3.fromRGB(160, 165, 180)
        statsLbl.TextSize = 10
        statsLbl.TextXAlignment = Enum.TextXAlignment.Center
        statsLbl.ZIndex = 125
        statsLbl.Parent = content

        local hpTrack = Instance.new("Frame")
        hpTrack.Name = "HealthTrack"
        hpTrack.Position = UDim2.fromOffset(72, 54)
        hpTrack.Size = UDim2.new(1, -144, 0, 16)
        hpTrack.BackgroundColor3 = Color3.fromRGB(14, 14, 16)
        hpTrack.BorderSizePixel = 0
        hpTrack.ZIndex = 124
        hpTrack.Parent = content
        local hpTrackStroke = Instance.new("UIStroke")
        hpTrackStroke.Color = Color3.fromRGB(30, 30, 35)
        hpTrackStroke.Thickness = 1
        hpTrackStroke.Parent = hpTrack

        local hpFill = Instance.new("Frame")
        hpFill.Name = "Fill"
        hpFill.Size = UDim2.fromScale(1, 1)
        hpFill.BackgroundColor3 = Color3.fromRGB(0, 162, 255)
        hpFill.BorderSizePixel = 0
        hpFill.ZIndex = 125
        hpFill.Parent = hpTrack

        local hpVal = Instance.new("TextLabel")
        hpVal.Name = "Value"
        hpVal.Size = UDim2.fromScale(1, 1)
        hpVal.BackgroundTransparency = 1
        hpVal.Font = Enum.Font.GothamBold
        hpVal.Text = "100 / 100"
        hpVal.TextColor3 = Color3.fromRGB(255, 255, 255)
        hpVal.TextSize = 10
        hpVal.ZIndex = 126
        hpVal.Parent = hpTrack

        local ratioTrack = Instance.new("Frame")
        ratioTrack.Name = "RatioTrack"
        ratioTrack.Position = UDim2.fromOffset(72, 78)
        ratioTrack.Size = UDim2.new(1, -144, 0, 14)
        ratioTrack.BackgroundColor3 = Color3.fromRGB(14, 14, 16)
        ratioTrack.BorderSizePixel = 0
        ratioTrack.ZIndex = 124
        ratioTrack.Parent = content

        local rTrackStroke = Instance.new("UIStroke")
        rTrackStroke.Color = Color3.fromRGB(30, 30, 35)
        rTrackStroke.Thickness = 1
        rTrackStroke.Parent = ratioTrack

        local ratioFill = Instance.new("Frame")
        ratioFill.Name = "Fill"
        ratioFill.Size = UDim2.fromScale(0.5, 1)
        ratioFill.BackgroundColor3 = Color3.fromRGB(0, 162, 255)
        ratioFill.BorderSizePixel = 0
        ratioFill.ZIndex = 125
        ratioFill.Parent = ratioTrack

        local ratioVal = Instance.new("TextLabel")
        ratioVal.Name = "Value"
        ratioVal.Size = UDim2.fromScale(1, 1)
        ratioVal.BackgroundTransparency = 1
        ratioVal.Font = Enum.Font.GothamBold
        ratioVal.Text = '<font color="#00A2FF">0 ▲</font>  <font color="#FF4560">0 ▼</font>'
        ratioVal.RichText = true
        ratioVal.TextColor3 = Color3.fromRGB(240, 240, 250)
        ratioVal.TextSize = 9.5
        ratioVal.ZIndex = 126
        ratioVal.Parent = ratioTrack

        sg.Parent = parent
        meowState.TargetHudGui = sg
        meowState.TargetHudSlots = weaponSlots
        meowState.TargetHudName = nameLbl
        meowState.TargetHudStats = statsLbl
        meowState.TargetHudHpFill = hpFill
        meowState.TargetHudHpVal = hpVal
        meowState.TargetHudRatioFill = ratioFill
        meowState.TargetHudRatioVal = ratioVal
        meowState.TargetHudFrame = frame
    end)
end

local function updateTargetVisuals()
    local target = meowState.CurrentTarget
    local hudEnabled = flags.target_hud or flags.target_hud_preview

    if hudEnabled then
        ensureTargetHudGui()
    end

    if meowState.TargetHudFrame then
        meowState.TargetHudFrame.Visible = hudEnabled and (target ~= nil or flags.target_hud_preview)
        if meowState.TargetHudFrame.Visible then
            local slots = meowState.TargetHudSlots or {}
            local nameLbl = meowState.TargetHudName
            local statsLbl = meowState.TargetHudStats
            local hpFill = meowState.TargetHudHpFill
            local hpVal = meowState.TargetHudHpVal
            local ratioFill = meowState.TargetHudRatioFill
            local ratioVal = meowState.TargetHudRatioVal

            if target and target.Player then
                local pl = target.Player
                if nameLbl then nameLbl.Text = pl.DisplayName or pl.Name end

                local level = "N/A"
                local streak = "N/A"
                local rank = "N/A"
                local device = "N/A"
                pcall(function()
                    local ls = pl:FindFirstChild("leaderstats")
                    if ls then
                        if ls:FindFirstChild("Level") then level = tostring(ls.Level.Value) end
                        if ls:FindFirstChild("Streak") then streak = tostring(ls.Streak.Value) end
                        if ls:FindFirstChild("Rank") then rank = tostring(ls.Rank.Value) end
                    end
                end)
                if statsLbl then
                    statsLbl.Text = string.format('level <font color="#00A2FF">%s</font>  rank <font color="#00A2FF">%s</font>  device <font color="#00A2FF">%s</font>  streak <font color="#00A2FF">%s</font>', level, rank, device, streak)
                end

                local hum = target.Humanoid
                if hum and hpFill and hpVal then
                    local hp = math.max(0, hum.Health)
                    local maxHp = math.max(1, hum.MaxHealth)
                    hpFill.Size = UDim2.fromScale(math.clamp(hp / maxHp, 0, 1), 1)
                    hpVal.Text = string.format("%d / %d", math.floor(hp), math.floor(maxHp))
                end

                pcall(function()
                    local rep = game:GetService("ReplicatedStorage")
                    local ItemLibrary = rep:FindFirstChild("Modules") and rep.Modules:FindFirstChild("ItemLibrary") and require(rep.Modules.ItemLibrary)
                    local weps = { "Assault Rifle", "Revolver", "Knife", "Medkit" }
                    local char = pl.Character
                    if char then
                        local tool = char:FindFirstChildOfClass("Tool")
                        if tool then weps[1] = tool.Name end
                    end
                    for i = 1, 4 do
                        local sImg = slots[i]
                        if sImg then
                            local wName = weps[i]
                            if ItemLibrary and ItemLibrary.Items and ItemLibrary.Items[wName] then
                                local itm = ItemLibrary.Items[wName]
                                local img = itm.ImageHighResolution or itm.Image
                                if type(img) == "string" and #img > 0 then
                                    sImg.Image = img
                                    sImg.ImageTransparency = 0.1
                                end
                            end
                        end
                    end
                end)
            elseif flags.target_hud_preview then
                if nameLbl then nameLbl.Text = "rage sahur" end
                if statsLbl then
                    statsLbl.Text = 'level <font color="#00A2FF">36</font>  rank <font color="#00A2FF">platinum 1</font>  device <font color="#00A2FF">virtualreality</font>  streak <font color="#00A2FF">3</font>'
                end
                if hpFill and hpVal then
                    hpFill.Size = UDim2.fromScale(70 / 150, 1)
                    hpVal.Text = "70 / 150"
                end
                if ratioVal then
                    ratioVal.Text = '<font color="#FF4560">49 ▲</font>  <font color="#FF4560">52 ▼</font>'
                end
                if ratioFill then
                    ratioFill.Size = UDim2.fromScale(49 / (49 + 52), 1)
                end
                pcall(function()
                    local rep = game:GetService("ReplicatedStorage")
                    local ItemLibrary = rep:FindFirstChild("Modules") and rep.Modules:FindFirstChild("ItemLibrary") and require(rep.Modules.ItemLibrary)
                    local previewWeps = { "Assault Rifle", "Revolver", "Knife", "Medkit" }
                    for i = 1, 4 do
                        local sImg = slots[i]
                        if sImg and ItemLibrary and ItemLibrary.Items and ItemLibrary.Items[previewWeps[i]] then
                            local itm = ItemLibrary.Items[previewWeps[i]]
                            local img = itm.ImageHighResolution or itm.Image
                            if type(img) == "string" and #img > 0 then
                                sImg.Image = img
                                sImg.ImageTransparency = 0.2
                            end
                        end
                    end
                end)
            end
        end
    end

    if flags.target_highlight and target and target.Character then
        if not meowState.TargetHighlight or not meowState.TargetHighlight.Parent then
            local hl = Instance.new("Highlight")
            hl.Name = "_MeowTargetHighlight"
            hl.Parent = LocalPlayer:WaitForChild("PlayerGui")
            meowState.TargetHighlight = hl
        end
        local hl = meowState.TargetHighlight
        hl.Adornee = target.Character
        hl.OutlineColor = flags.target_highlight_outline or Color3.fromRGB(255, 60, 60)
        hl.FillColor = flags.target_highlight_fill or Color3.fromRGB(180, 30, 30)
        hl.OutlineTransparency = 0
        hl.FillTransparency = 0.5
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Enabled = true
    elseif meowState.TargetHighlight then
        meowState.TargetHighlight.Enabled = false
        meowState.TargetHighlight.Adornee = nil
    end

    if flags.target_snapline and target and target.HitPart then
        local scrPos, onScreen = Camera:WorldToViewportPoint(target.HitPart.Position)
        if onScreen then
            if not meowState.TargetSnapline then
                pcall(function()
                    meowState.TargetSnapline = Drawing.new("Line")
                end)
            end
            local line = meowState.TargetSnapline
            if line then
                line.From = Camera.ViewportSize / 2
                line.To = Vector2.new(scrPos.X, scrPos.Y)
                line.Color = flags.target_snapline_color or Color3.fromRGB(255, 80, 80)
                line.Thickness = 1.5
                line.Transparency = 1
                line.Visible = true
            end
        elseif meowState.TargetSnapline then
            meowState.TargetSnapline.Visible = false
        end
    elseif meowState.TargetSnapline then
        meowState.TargetSnapline.Visible = false
    end
end

local function spawnBulletTracer(fromPos, toPos)
    if not flags.bullet_tracers then return end
    pcall(function()
        local line = Drawing.new("Line")
        local shadow = flags.tracer_shadows and Drawing.new("Line") or nil
        local tracer = {
            line = line,
            shadow = shadow,
            from = fromPos,
            to = toPos,
            born = os.clock(),
            hold = flags.tracer_hold or 0.6,
            fade = flags.tracer_fade or 0.4,
            travel = flags.tracer_travel or 0.15,
            color = flags.tracer_color or Color3.fromRGB(120, 180, 255),
        }
        table.insert(meowState.TracerDrawings, tracer)
    end)
end

meowState.TriggerBulletTracer = function(toPos)
    local char = LocalPlayer.Character
    local fromPos = char and char:FindFirstChild("Head") and char.Head.Position or Camera.CFrame.Position
    if fromPos and toPos then
        spawnBulletTracer(fromPos, toPos)
    end
end

local function updateBulletTracers()
    local now = os.clock()
    for idx = #meowState.TracerDrawings, 1, -1 do
        local d = meowState.TracerDrawings[idx]
        local age = now - d.born
        local totalLife = d.hold + d.fade
        if age >= totalLife then
            pcall(function() d.line:Destroy() end)
            if d.shadow then pcall(function() d.shadow:Destroy() end) end
            table.remove(meowState.TracerDrawings, idx)
        else
            local travelPct = d.travel > 0 and math.clamp(age / d.travel, 0, 1) or 1
            local currentTo = d.from:Lerp(d.to, travelPct)

            local p1, on1 = Camera:WorldToViewportPoint(d.from)
            local p2, on2 = Camera:WorldToViewportPoint(currentTo)

            if (on1 or on2) and p1.Z > 0 and p2.Z > 0 then
                local alpha = 1
                if age > d.hold then
                    alpha = math.clamp(1 - ((age - d.hold) / d.fade), 0, 1)
                end
                d.line.From = Vector2.new(p1.X, p1.Y)
                d.line.To = Vector2.new(p2.X, p2.Y)
                d.line.Color = d.color
                d.line.Thickness = 2
                d.line.Transparency = alpha
                d.line.Visible = true

                if d.shadow then
                    d.shadow.From = Vector2.new(p1.X, p1.Y)
                    d.shadow.To = Vector2.new(p2.X, p2.Y)
                    d.shadow.Color = Color3.fromRGB(0, 0, 0)
                    d.shadow.Thickness = 4
                    d.shadow.Transparency = alpha * 0.5
                    d.shadow.Visible = true
                end
            else
                d.line.Visible = false
                if d.shadow then d.shadow.Visible = false end
            end
        end
    end
end

local MeowWireframe = {
    Enabled          = false,
    Color            = Color3.fromRGB(255, 255, 255),
    ColorMiddle      = Color3.fromRGB(0, 162, 255),
    Color2           = Color3.fromRGB(0, 162, 255),
    ColorMode        = "gradient",
    GradientAxis     = { "length", "height" },
    Transparency     = 0,
    Thickness        = 1,

    ArmEnabled       = false,
    ArmColor         = Color3.fromRGB(0, 162, 255),
    ArmColor2        = Color3.fromRGB(255, 255, 255),

    ActiveWires      = {},
    Connections      = {},
    PartCache        = {},
    CurrentGun       = nil,
    CurrentArms      = nil,
}

local MEOW_BOX_EDGES = {
    {1, 2}, {2, 4}, {4, 3}, {3, 1},
    {5, 6}, {6, 8}, {8, 7}, {7, 5},
    {1, 5}, {2, 6}, {3, 7}, {4, 8}
}

function MeowWireframe:GetColor(pct)
    local col1 = self.Color or Color3.fromRGB(255, 255, 255)
    local col2 = self.Color2 or Color3.fromRGB(0, 162, 255)
    local colMid = self.ColorMiddle or col1:Lerp(col2, 0.5)
    if pct <= 0.5 then
        return col1:Lerp(colMid, math.clamp(pct * 2, 0, 1))
    else
        return colMid:Lerp(col2, math.clamp((pct - 0.5) * 2, 0, 1))
    end
end

function MeowWireframe:GetDirection()
    local axis = self.GradientAxis or {"length"}
    local tbl = {}
    for _, a in ipairs(axis) do tbl[a] = true end
    local dx = (tbl.width and 1 or 0) - (tbl["reverse width"] and 1 or 0)
    local dy = (tbl.height and 1 or 0) - (tbl["reverse height"] and 1 or 0)
    local dz = (tbl.length and 1 or 0) - (tbl["reverse length"] and 1 or 0)
    return dx, dy, dz
end

function MeowWireframe:DrawGradient(wire, data)
    local pts = data.Points
    if not pts or #pts < 2 then return end

    local minP = data.Min or Vector3.new(-1, -1, -1)
    local maxP = data.Max or Vector3.new(1, 1, 1)
    local size = maxP - minP
    local dx, dy, dz = self:GetDirection()
    local totalD = math.abs(dx) + math.abs(dy) + math.abs(dz)

    local function getPct(p)
        if totalD == 0 then return 0.5 end
        local px = size.X > 0.0001 and (p.X - minP.X) / size.X or 0.5
        local py = size.Y > 0.0001 and (p.Y - minP.Y) / size.Y or 0.5
        local pz = size.Z > 0.0001 and (p.Z - minP.Z) / size.Z or 0.5
        local v = 0.5 + ((px - 0.5) * dx + (py - 0.5) * dy + (pz - 0.5) * dz) / totalD
        return math.clamp(v, 0, 1)
    end
    local segments = 6
    for i = 1, #pts, 2 do
        local p1 = pts[i]
        local p2 = pts[i + 1]
        local pct1 = getPct(p1)
        local pct2 = getPct(p2)
        local lastP = p1
        for s = 1, segments do
            local nextP = p1 + (p2 - p1) * (s / segments)
            local t = pct1 + (pct2 - pct1) * ((s - 0.5) / segments)
            wire.Color3 = self:GetColor(t)
            wire:AddLine(lastP, nextP)
            lastP = nextP
        end
    end
end

function MeowWireframe:Rebuild(wire, part)
    local size = part.Size
    local h = size * 0.5
    local corners = {
        Vector3.new(-h.X, -h.Y, -h.Z),
        Vector3.new( h.X, -h.Y, -h.Z),
        Vector3.new(-h.X,  h.Y, -h.Z),
        Vector3.new( h.X,  h.Y, -h.Z),
        Vector3.new(-h.X, -h.Y,  h.Z),
        Vector3.new( h.X, -h.Y,  h.Z),
        Vector3.new(-h.X,  h.Y,  h.Z),
        Vector3.new( h.X,  h.Y,  h.Z),
    }

    local points = {}
    for _, edge in ipairs(MEOW_BOX_EDGES) do
        table.insert(points, corners[edge[1]])
        table.insert(points, corners[edge[2]])
    end

    local data = {
        Points = points,
        Min    = -h,
        Max    = h,
    }

    wire:Clear()
    wire.Color3 = self.Color
    wire.Transparency = self.Transparency or 0
    wire.Thickness = self.Thickness or 1
    wire.AlwaysOnTop = true
    wire.ZIndex = 10

    if self.ColorMode == "gradient" then
        self:DrawGradient(wire, data)
    else
        wire:AddLines(points)
    end
end

function MeowWireframe:Draw(part)
    if self.ActiveWires[part] then return end
    local wire = Instance.new("WireframeHandleAdornment")
    wire.Name = "MeowWireframe"
    wire.ZIndex = 10
    wire.Thickness = self.Thickness or 1
    wire.AlwaysOnTop = true
    wire.Adornee = part
    pcall(function() wire.Parent = LocalPlayer:WaitForChild("PlayerGui") end)

    self:Rebuild(wire, part)

    self.ActiveWires[part] = {
        Wire             = wire,
        OrigTransparency = part.Transparency,
        Size             = part.Size,
    }

    part.Transparency = 1
end

function MeowWireframe:Watch(part)
    if self.Connections[part] then return end
    local conns = {}

    table.insert(conns, part:GetPropertyChangedSignal("LocalTransparencyModifier"):Connect(function()
        if part.LocalTransparencyModifier >= 0.99 then
            self:Remove(part)
        else
            self:Draw(part)
        end
    end))

    table.insert(conns, part.Destroying:Connect(function()
        self:Remove(part)
    end))

    self.Connections[part] = conns
end

function MeowWireframe:Scan(container)
    if not container then return end
    for _, p in ipairs(container:GetDescendants()) do
        if p:IsA("BasePart") and p.Transparency < 1 then
            self:Watch(p)
            if p.LocalTransparencyModifier < 0.99 then
                self:Draw(p)
            end
        end
    end
end

function MeowWireframe:Remove(part)
    local entry = self.ActiveWires[part]
    if entry then
        pcall(function() entry.Wire:Destroy() end)
        self.ActiveWires[part] = nil
        if part.Parent then
            pcall(function() part.Transparency = entry.OrigTransparency or 0 end)
        end
    end
    if self.Connections[part] then
        for _, c in ipairs(self.Connections[part]) do pcall(function() c:Disconnect() end) end
        self.Connections[part] = nil
    end
end

function MeowWireframe:Clear()
    for part in pairs(self.ActiveWires) do
        self:Remove(part)
    end
    for part, conns in pairs(self.Connections) do
        for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    end
    table.clear(self.ActiveWires)
    table.clear(self.Connections)
    self.CurrentGun = nil
    self.CurrentArms = nil
end

function MeowWireframe:GetGunModel()
    pcall(function()
        local fc = rawget(getgenv(), "FighterController")
        if fc and fc.LocalFighter and fc.LocalFighter.EquippedItem then
            local vm = fc.LocalFighter.EquippedItem.ViewModel
            if vm and vm.ItemModel then return vm.ItemModel end
        end
    end)

    local vms = Camera:FindFirstChild("ViewModels") or Workspace:FindFirstChild("ViewModels")
    if vms then
        for _, vm in ipairs(vms:GetChildren()) do
            local item = vm:FindFirstChild("ItemModel") or vm:FindFirstChild("ItemVisual") or vm:FindFirstChild("Weapon")
            if item then return item end
            if #vm:GetChildren() > 0 then return vm end
        end
    end

    local char = LocalPlayer and LocalPlayer.Character
    local tool = char and char:FindFirstChildOfClass("Tool")
    if tool then return tool end
    return nil
end

function MeowWireframe:GetArmsModel()
    local vms = Camera:FindFirstChild("ViewModels") or Workspace:FindFirstChild("ViewModels")
    if vms then
        for _, vm in ipairs(vms:GetChildren()) do
            local arms = vm:FindFirstChild("Arms") or vm:FindFirstChild("LeftArm") or vm:FindFirstChild("RightArm")
            if arms then return arms.Parent end
        end
    end
    return nil
end

function MeowWireframe:Update()
    if not self.Enabled and not self.ArmEnabled then
        if self.CurrentGun or self.CurrentArms then
            self:Clear()
        end
        return
    end

    if self.Enabled then
        local gun = self:GetGunModel()
        if gun ~= self.CurrentGun then
            if self.CurrentGun then
                for part in pairs(self.ActiveWires) do
                    if part:IsDescendantOf(self.CurrentGun) then self:Remove(part) end
                end
            end
            self.CurrentGun = gun
            if self.CurrentGun then
                self:Scan(self.CurrentGun)
            end
        end
    elseif self.CurrentGun then
        for part in pairs(self.ActiveWires) do
            if part:IsDescendantOf(self.CurrentGun) then self:Remove(part) end
        end
        self.CurrentGun = nil
    end

    if self.ArmEnabled then
        local arms = self:GetArmsModel()
        if arms ~= self.CurrentArms then
            if self.CurrentArms then
                for part in pairs(self.ActiveWires) do
                    if part:IsDescendantOf(self.CurrentArms) then self:Remove(part) end
                end
            end
            self.CurrentArms = arms
            if self.CurrentArms then
                self:Scan(self.CurrentArms)
            end
        end
    elseif self.CurrentArms then
        for part in pairs(self.ActiveWires) do
            if part:IsDescendantOf(self.CurrentArms) then self:Remove(part) end
        end
        self.CurrentArms = nil
    end

    for part, entry in pairs(self.ActiveWires) do
        if part.Parent and part.Size ~= entry.Size then
            entry.Size = part.Size
            self:Rebuild(entry.Wire, part)
        end
    end
end

getgenv().MeowWireframe = MeowWireframe

local function restoreWeaponVisuals()
    MeowWireframe:Clear()
    if meowState.WeaponHighlight then
        pcall(function() meowState.WeaponHighlight:Destroy() end)
        meowState.WeaponHighlight = nil
    end
    for part, props in pairs(meowState.SavedPartProps) do
        pcall(function()
            if part and part.Parent then
                part.Material = props.Material
                part.Color = props.Color
                part.Transparency = props.Transparency
            end
        end)
    end
    table.clear(meowState.SavedPartProps)
end

local function updateWeaponVisuals()
    MeowWireframe.Enabled     = flags.item_wireframe or false
    MeowWireframe.ArmEnabled  = flags.arm_appearance or false
    MeowWireframe.Color       = flags.wireframe_color or Color3.fromRGB(255, 255, 255)
    MeowWireframe.Color2      = flags.wireframe_color2 or Color3.fromRGB(0, 162, 255)
    MeowWireframe.ColorMode   = flags.wireframe_mode or "gradient"
    MeowWireframe.Transparency = flags.wireframe_transparency or 0
    MeowWireframe.Thickness   = flags.wireframe_thickness or 1
    MeowWireframe:Update()
end