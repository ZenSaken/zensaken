-- Zensaken | Full integrated script (merged fixes + anti-flick + full AttackIDs)
-- By: Zen (Developer seen in Credits tab)
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local HttpService = game:GetService("HttpService")

local LP = Players.LocalPlayer
local RS = ReplicatedStorage
local RSvc = RunService
local Killers = Workspace:WaitForChild("Players"):WaitForChild("Killers")

-- Hub identity
local HUB_NAME = "Zensaken"

-- Killer names (models)
local Names = {"Sixer","Slasher","Noli","JohnDoe","c00lkidd","1x1x1x1","Nosferatu"}

-- Attack sound IDs (full numeric strings)
local AttackIDs = {
    ["106300477136129"]=true,["127793641088496"]=true,["112809109188560"]=true,
    ["109348678063422"]=true,["105200830849301"]=true,["79391273191671"]=true,
    ["82221759983649"]=true,["121954639447247"]=true,["85853080745515"]=true,
    ["84307400688050"]=true,["71834552297085"]=true,["79980897195554"]=true,
    ["131406927389838"]=true,["76959687420003"]=true,["95079963655241"]=true,
    ["102228729296384"]=true,["119942598489800"]=true,["119583605486352"]=true,
    ["108907358619313"]=true,["117173212095661"]=true,["12222216"]=true,
    ["114742322778642"]=true,["105840448036441"]=true,["71805956520207"]=true,
    ["84116622032112"]=true,["119089145505438"]=true,["75330693422988"]=true,
    ["86174610237192"]=true,["89004992452376"]=true,["81702359653578"]=true,
    ["86833981571073"]=true,["101698569375359"]=true,["110372418055226"]=true,
    ["115026634746636"]=true,["86494585504534"]=true,["101553872555606"]=true,
    ["136323728355613"]=true,["101199185291628"]=true,["125213046326879"]=true,
    ["116581754553533"]=true,["113037804008732"]=true,["140242176732868"]=true,
    ["117231507259853"]=true,["107444859834748"]=true,["80516583309685"]=true,
    ["112395455254818"]=true,["109431876587852"]=true,["108610718831698"]=true,
    ["104910828105172"]=true
}

-- Remote event (network module)
local RE = RS:WaitForChild("Modules"):WaitForChild("Network"):WaitForChild("RemoteEvent")

-- ====== Anti-flick / Prediction settings (from your uploaded file) ======
local Debris = game:GetService("Debris")
local antiFlickOn = false
local antiFlickParts = 4
local antiFlickBaseOffset = 2.7
local antiFlickOffsetStep = 0
local antiFlickDelay = 0
local PRED_SECONDS_FORWARD = 0.25
local PRED_SECONDS_LATERAL  = 0.18
local PRED_MAX_FORWARD      = 6
local PRED_MAX_LATERAL      = 4
local ANG_TURN_MULTIPLIER   = 0.6
local SMOOTHING_LERP        = 0.22
local killerState = {}
local predictionStrength = 1
local predictionTurnStrength = 1
local blockPartsSizeMultiplier = 1

local killerDelayMap = {
    ["c00lkidd"] = 0,
    ["jason"]    = 0.013,
    ["slasher"]  = 0.01,
    ["1x1x1x1"]  = 0.15,
    ["johndoe"]  = 0.33,
    ["noli"]     = 0.15,
    ["nosferatu"]= 0.18, -- guessed value; adjust as needed
    ["sixer"]    = 0.08  -- guessed
}

-- ====== Config / State ======
local autoBlock = false
local facingCheckEnabled = true
local range = 11
local espOn = false
local hdTech = false
local facingVisualOn = false

local autoPunchEnabled = false
local aimOnPunchEnabled = false
local punchDelay = 0.22
local predictiveAim = 5

local lastPunchTime = 0
local lastBlock = 0
local lastDrag = 0
local cooldown = 0.35
local dragCooldown = 0.5
local dragDur = 0.3

-- internals
local heartbeatConn = nil
local renderConn = nil
local _dragConn = nil
local _hdDragDebounce = false

local facingVisuals = {}
local espParts = {}

local punchAnimSet = {
    ["87259391926321"]=true,["140703210927645"]=true,["136007065400978"]=true,
    ["129843313690921"]=true,["86709774283672"]=true,["108807732150251"]=true,
    ["138040001965654"]=true,["86096387000557"]=true
}

-- ====== Helpers ======
local function safeDisconnect(c)
    if c and c.Disconnect then
        pcall(function() c:Disconnect() end)
    end
end

local function clamp(n, a, b)
    if n < a then return a end
    if n > b then return b end
    return n
end

-- ====== Facing check & visuals ======
local function isFacing(meRoot, targetRoot)
    if not facingCheckEnabled then return true end
    if not meRoot or not targetRoot then return true end
    local vec = meRoot.Position - targetRoot.Position
    if vec.Magnitude == 0 then return true end
    return targetRoot.CFrame.LookVector:Dot(vec.Unit) > -0.3
end

local function updateFacingVisual(killer, vis)
    if not killer or not vis or not vis.Parent then return end
    local hrp = killer:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local radius = clamp(range * 0.55, 1, math.max(1, range))
    vis.Radius = radius
    vis.Height = 0.12

    local forwardDist = clamp(range * 0.65, 0.8, range)
    local yOffset = -(hrp.Size.Y/2 + 0.05)
    vis.CFrame = CFrame.new(0, yOffset, -forwardDist) * CFrame.Angles(math.rad(90), 0, 0)

    local myRoot = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    local inRange = myRoot and (hrp.Position - myRoot.Position).Magnitude <= range
    local facingOk = myRoot and isFacing(myRoot, hrp)

    if inRange and (not facingOk) then
        vis.Color3 = Color3.fromRGB(255,210,120)
        vis.Transparency = 0.35
    else
        vis.Color3 = Color3.fromRGB(120,220,150)
        vis.Transparency = 0.6
    end
end

local function addFacingVisual(k)
    if not k or facingVisuals[k] then return end
    local hrp = k:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local v = Instance.new("CylinderHandleAdornment")
    v.Name = "FacingVisual"
    v.Adornee = hrp
    v.AlwaysOnTop = true
    v.ZIndex = 10
    v.Transparency = 0.6
    v.Color3 = Color3.fromRGB(120,220,150)
    v.Parent = hrp
    facingVisuals[k] = v
    updateFacingVisual(k, v)
end

local function removeFacingVisual(k)
    local v = facingVisuals[k]
    if v and v.Parent then pcall(function() v:Destroy() end) end
    facingVisuals[k] = nil
end

-- ====== ESP creation and update (CylinderHandleAdornment) ======
local function createESPAdorn(k, name)
    local kHRP = k:FindFirstChild("HumanoidRootPart")
    if not kHRP then return nil end
    local adorn = Instance.new("CylinderHandleAdornment")
    adorn.Name = "ESP_" .. name
    adorn.Adornee = kHRP
    adorn.AlwaysOnTop = true
    adorn.ZIndex = 1
    adorn.Transparency = 0.55
    adorn.Radius = math.max(0.5, range)
    adorn.Height = 0.12
    adorn.Color3 = Color3.fromRGB(200,80,80)
    adorn.Parent = kHRP
    return adorn
end

local function updateESP()
    if not espOn or not LP.Character then return end
    local myHRP = LP.Character:FindFirstChild("HumanoidRootPart")
    if not myHRP then return end

    for _, name in ipairs(Names) do
        local k = Killers:FindFirstChild(name)
        local adorn = espParts[name]
        if k and k:FindFirstChild("HumanoidRootPart") then
            local kHRP = k.HumanoidRootPart
            if not adorn or not adorn.Parent then
                adorn = createESPAdorn(k, name)
                espParts[name] = adorn
            end
            if adorn and adorn.Parent then
                adorn.Radius = math.max(0.5, range)
                local yOffset = -(kHRP.Size.Y/2 + 0.05)
                adorn.CFrame = CFrame.new(0, yOffset, 0) * CFrame.Angles(math.rad(90), 0, 0)
                local dist = (myHRP.Position - kHRP.Position).Magnitude
                if dist <= range then
                    adorn.Color3 = Color3.fromRGB(120,220,150)
                    adorn.Transparency = 0.45
                else
                    adorn.Color3 = Color3.fromRGB(200,80,80)
                    adorn.Transparency = 0.6
                end
            end
        else
            if adorn and adorn.Parent then pcall(function() adorn:Destroy() end) end
            espParts[name] = nil
        end
    end
end

local function cleanupAllESP()
    for name, adorn in pairs(espParts) do
        if adorn and adorn.Parent then pcall(function() adorn:Destroy() end) end
        espParts[name] = nil
    end
end

-- ====== HD MoveTo Drag (safe) ======
local function startHDMoveTo(kHRP)
    if not hdTech then return end
    if _dragConn and _dragConn.Connected then return end
    if _hdDragDebounce then return end
    _hdDragDebounce = true

    if not LP.Character then _hdDragDebounce = false return end
    local humanoid = LP.Character:FindFirstChild("Humanoid")
    local myHRP = LP.Character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not myHRP then _hdDragDebounce = false return end

    local startTime = tick()
    _dragConn = RSvc.Heartbeat:Connect(function()
        if not hdTech then
            if _dragConn then _dragConn:Disconnect() _dragConn = nil end
            _hdDragDebounce = false
            return
        end
        local elapsed = tick() - startTime
        if elapsed >= dragDur then
            if _dragConn then _dragConn:Disconnect() _dragConn = nil end
            pcall(function() humanoid:Move(Vector3.new()) end)
            _hdDragDebounce = false
            return
        end

        pcall(function()
            if kHRP and kHRP.Parent then
                humanoid:MoveTo(kHRP.Position)
            else
                if _dragConn then _dragConn:Disconnect() _dragConn = nil end
                _hdDragDebounce = false
            end
        end)
    end)
end

-- ====== Anti-flick parts (spawn small parts in front of killer to prevent flick) ======
local function spawnAntiFlickParts(kHRP, count, baseOffset, step)
    if not antiFlickOn then return end
    if not kHRP or not kHRP.Parent then return end
    count = count or antiFlickParts
    baseOffset = baseOffset or antiFlickBaseOffset
    step = step or antiFlickOffsetStep

    for i = 1, count do
        local offset = baseOffset + ((i-1) * step)
        local pos = kHRP.Position + (kHRP.CFrame.LookVector * offset)
        local part = Instance.new("Part")
        part.Anchored = true
        part.CanCollide = false
        part.Size = Vector3.new(0.8 * blockPartsSizeMultiplier, 0.8 * blockPartsSizeMultiplier, 0.8 * blockPartsSizeMultiplier)
        part.Shape = Enum.PartType.Ball
        part.Material = Enum.Material.Neon
        part.Color = Color3.fromRGB(120, 180, 255)
        part.Transparency = 0.25
        part.CFrame = CFrame.new(pos)
        part.Parent = workspace
        Debris:AddItem(part, 0.45) -- short life
    end
end

-- ====== Auto Aim & Punch Helpers ======
local function getClosestKiller()
    if not LP.Character or not LP.Character:FindFirstChild("HumanoidRootPart") then return nil end
    local myPos = LP.Character.HumanoidRootPart.Position
    local best, bestDist = nil, math.huge
    local t = (predictiveAim or 5) / 10 * 0.5
    for _, n in ipairs(Names) do
        local k = Killers:FindFirstChild(n)
        if k and k:FindFirstChild("HumanoidRootPart") then
            local hrp = k.HumanoidRootPart
            local pred = hrp.Position + (hrp.Velocity or Vector3.new()) * t
            local d = (myPos - pred).Magnitude
            if d < bestDist then bestDist = d; best = {Pos = pred, HRP = hrp} end
        end
    end
    return best
end

local function aimAt(pos)
    if not LP.Character or not LP.Character:FindFirstChild("HumanoidRootPart") then return end
    local myHRP = LP.Character.HumanoidRootPart
    pcall(function()
        myHRP.CFrame = CFrame.new(myHRP.Position, pos + Vector3.new(0,2,0))
    end)
end

local function punch()
    if tick() - (lastPunchTime or 0) < (punchDelay or 0.22) then return end
    lastPunchTime = tick()

    -- aim just before firing if enabled
    if aimOnPunchEnabled then
        local t = getClosestKiller()
        if t and t.Pos then
            aimAt(t.Pos)
            task.wait(0.01)
        end
    end

    pcall(function() RE:FireServer("UseActorAbility", {"Punch"}) end)
end

local function onPunchAnim(anim)
    if not aimOnPunchEnabled then return end
    local ok, animId = pcall(function() return tostring((anim.Animation and anim.Animation.AnimationId:match("%d+$")) or "") end)
    if not ok or not animId then return end
    if punchAnimSet[animId] then
        local t = getClosestKiller()
        if t and t.Pos then aimAt(t.Pos) end
    end
end

-- ====== Main loop (Heartbeat) ======
local function startLoop()
    if heartbeatConn then heartbeatConn:Disconnect() end
    heartbeatConn = RSvc.Heartbeat:Connect(function()
        if espOn then updateESP() end

        -- Auto Punch
        if autoPunchEnabled then
            local t = getClosestKiller()
            if t and LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") and (LP.Character.HumanoidRootPart.Position - t.Pos).Magnitude <= 10 then
                punch()
            end
        end

        -- Auto Block
        if not autoBlock then return end
        local char = LP.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then return end
        local myHRP = char.HumanoidRootPart
        local block = false
        local targetHRP = nil

        for _, n in ipairs(Names) do
            local k = Killers:FindFirstChild(n)
            if k and k:FindFirstChild("HumanoidRootPart") then
                local kHRP = k.HumanoidRootPart
                if (myHRP.Position - kHRP.Position).Magnitude <= range then
                    local attacking = false
                    for _, s in ipairs(k:GetDescendants()) do
                        if s:IsA("Sound") and s.Playing then
                            local id = tostring(s.SoundId:match("%d+")) or ""
                            if AttackIDs[id] then
                                attacking = true
                                targetHRP = kHRP
                                -- anti-flick spawn + HD drag
                                if antiFlickOn then
                                    spawnAntiFlickParts(kHRP, antiFlickParts, antiFlickBaseOffset, antiFlickOffsetStep)
                                end
                                if hdTech then startHDMoveTo(kHRP) end
                                break
                            end
                        end
                    end
                    if attacking and k:FindFirstChild("Head") then
                        local look = k.Head.CFrame.LookVector
                        local dir = (myHRP.Position - k.Head.Position).Unit
                        if not facingCheckEnabled or look:Dot(dir) > -0.3 then
                            block = true
                        end
                    end
                end
            end
        end

        if block and tick() - lastBlock >= cooldown then
            lastBlock = tick()
            pcall(function() RE:FireServer("UseActorAbility", {"Block"}) end)
        end
    end)
end

-- ====== GUI (Rayfield) ======
local Window = Rayfield:CreateWindow({
   Name = HUB_NAME,
   Icon = 0,
   LoadingTitle = HUB_NAME,
   LoadingSubtitle = "AutoBlock • AutoPunch • AutoAim • HD-MoveTo",
   ShowText = HUB_NAME,
   Theme = "AmberGlow",
   ToggleUIKeybind = "K",
   DisableRayfieldPrompts = false,
   DisableBuildWarnings = false,
   ConfigurationSaving = { Enabled = true, FolderName = HUB_NAME, FileName = HUB_NAME .. "Config" },
   Discord = { Enabled = false },
   KeySystem = false
})

local MainTab = Window:CreateTab("⚔️ Main")
local PunchTab = Window:CreateTab("🥊 Punch")
local TechTab = Window:CreateTab("🛠️ Tech")
local SettingsTab = Window:CreateTab("⚙️ Settings")
local CreditsTab = Window:CreateTab("🎖️ Credits")
local EndTab = Window:CreateTab("🛑 End")

-- Main controls
MainTab:CreateSlider({ Name = "Block Range", Range = {5,50}, Increment = 1, Suffix = " studs", CurrentValue = range, Callback = function(v) range = v end })
MainTab:CreateToggle({ Name = "Auto Block 🛡️", CurrentValue = autoBlock, Callback = function(v) autoBlock = v if v then startLoop() end end })
MainTab:CreateToggle({ Name = "Facing Check 👀", CurrentValue = facingCheckEnabled, Callback = function(v) facingCheckEnabled = v end })
MainTab:CreateToggle({ Name = "Facing Visual 👁️ (in front)", CurrentValue = facingVisualOn, Callback = function(v)
    facingVisualOn = v
    if v then
        for _, k in ipairs(Killers:GetChildren()) do
            task.spawn(function()
                local h = k:FindFirstChild("HumanoidRootPart") or k:WaitForChild("HumanoidRootPart", 3)
                if h then addFacingVisual(k) end
            end)
        end
        safeDisconnect(renderConn)
        renderConn = RSvc.RenderStepped:Connect(function()
            for k, vis in pairs(facingVisuals) do
                if k and k.Parent and k:FindFirstChild("HumanoidRootPart") then
                    updateFacingVisual(k, vis)
                else
                    removeFacingVisual(k)
                end
            end
        end)
    else
        safeDisconnect(renderConn)
        for k,_ in pairs(facingVisuals) do removeFacingVisual(k) end
    end
end })
MainTab:CreateToggle({ Name = "Detection ESP 🔴 (soft)", CurrentValue = espOn, Callback = function(v) espOn = v if v then startLoop() end if not v then cleanupAllESP() end end })
MainTab:CreateToggle({ Name = "HD-Tech ⚡ (MoveTo)", CurrentValue = hdTech, Callback = function(v) hdTech = v end })

-- Punch tab
PunchTab:CreateToggle({ Name = "Auto Punch 🥊", CurrentValue = autoPunchEnabled, Callback = function(v) autoPunchEnabled = v end })
PunchTab:CreateSlider({ Name = "Punch Delay ⏱️", Range = {0.05,1}, Increment = 0.01, Suffix = "s", CurrentValue = punchDelay, Callback = function(v) punchDelay = v end })
PunchTab:CreateToggle({ Name = "Auto Aim 🎯 (only when punching)", CurrentValue = aimOnPunchEnabled, Callback = function(v) aimOnPunchEnabled = v end })
PunchTab:CreateSlider({ Name = "Predictive Aim 🔮", Range = {0,10}, Increment = 1, CurrentValue = predictiveAim, Callback = function(v) predictiveAim = v end })

-- Tech tab (HDT + anti-flick)
TechTab:CreateToggle({ Name = "Hitbox Dragging tech (HDT)", CurrentValue = false, Flag = "HitboxDraggingToggle", Callback = function(state) hdTech = state end })
TechTab:CreateToggle({ Name = "Anti-Flick Parts", CurrentValue = antiFlickOn, Callback = function(v) antiFlickOn = v end })
TechTab:CreateInput({ Name = "Anti-Flick Count", PlaceholderText = tostring(antiFlickParts), RemoveTextAfterFocusLost = false, Callback = function(txt) antiFlickParts = tonumber(txt) or antiFlickParts end })
TechTab:CreateInput({ Name = "Anti-Flick Base Offset", PlaceholderText = tostring(antiFlickBaseOffset), RemoveTextAfterFocusLost = false, Callback = function(txt) antiFlickBaseOffset = tonumber(txt) or antiFlickBaseOffset end })

-- Settings
SettingsTab:CreateParagraph({ Title = "Theme", Content = "Using AmberGlow theme. Change Theme value in script to switch." })
SettingsTab:CreateButton({ Name = "Cleanup ESP Now", Callback = function() cleanupAllESP() end })
SettingsTab:CreateDropdown({
    Name = "Change Theme",
    Options = {"Default","AmberGlow","Amethyst","Bloom","DarkBlue","Green","Light","Ocean","Serenity"},
    CurrentOption = "AmberGlow",
    Callback = function(choice)
        local map = {["Amber Glow"]="AmberGlow", ["AmberGlow"]="AmberGlow", ["Dark Blue"]="DarkBlue"}
        local themeId = map[choice] or choice
        pcall(function() Rayfield:ChangeTheme(themeId) end)
    end
})

-- Credits (Developer: Zen)
CreditsTab:CreateLabel("Developer: Zen ✨")
CreditsTab:CreateParagraph({ Title = "About Zensaken", Content = "Developer: Zen\nScripter: You\nFeatures: AutoBlock, AutoPunch, AutoAim, HD-MoveTo, Anti-Flick\nTheme: AmberGlow\nThanks for using Zensaken!" })

-- End
EndTab:CreateButton({ Name = "Destroy Hub 🛑", Callback = function()
    safeDisconnect(heartbeatConn)
    safeDisconnect(renderConn)
    safeDisconnect(_dragConn)
    cleanupAllESP()
    for k,_ in pairs(facingVisuals) do 
removeFacingVisual(k) end
    pcall(function() Rayfield:Destroy() end)
end })

-- Animation fallback
LP.CharacterAdded:Connect(function(c)
    task.wait(1)
    local h = c:FindFirstChild("Humanoid")
    if h then h.AnimationPlayed:Connect(onPunchAnim) end
end)
if LP.Character and LP.Character:FindFirstChild("Humanoid") then
    LP.Character.Humanoid.AnimationPlayed:Connect(onPunchAnim)
end

-- Start loop
startLoop()

-- Final note printed to console
pcall(function()
    print(HUB_NAME .. " loaded. AutoBlock, AutoPunch, AutoAim ready.")
end)
