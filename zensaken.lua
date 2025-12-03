local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local LP = Players.LocalPlayer
local RE = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Network"):WaitForChild("RemoteEvent")
local Killers = Workspace:WaitForChild("Players"):WaitForChild("Killers")

local AttackIDs = {["106300477136129"]=true,["127793641088496"]=true,["112809109188560"]=true,["109348678063422"]=true,
["105200830849301"]=true,["79391273191671"]=true,["82221759983649"]=true,["121954639447247"]=true,
["85853080745515"]=true,["84307400688050"]=true,["71834552297085"]=true,["79980897195554"]=true,
["131406927389838"]=true,["76959687420003"]=true,["95079963655241"]=true,["102228729296384"]=true,
["119942598489800"]=true,["119583605486352"]=true,["108907358619313"]=true,["117173212095661"]=true,
["12222216"]=true,["114742322778642"]=true,["105840448036441"]=true,["71805956520207"]=true,
["84116622032112"]=true,["119089145505438"]=true,["75330693422988"]=true,["86174610237192"]=true,
["89004992452376"]=true,["81702359653578"]=true,["86833981571073"]=true,["101698569375359"]=true,
["110372418055226"]=true,["115026634746636"]=true,["86494585504534"]=true,["101553872555606"]=true,
["136323728355613"]=true,["101199185291628"]=true,["125213046326879"]=true,["116581754553533"]=true,
["113037804008732"]=true,["140242176732868"]=true,["117231507259853"]=true,["107444859834748"]=true,
["80516583309685"]=true,["112395455254818"]=true,["109431876587852"]=true,["108610718831698"]=true,
["104910828105172"]=true,["754675462151"]=true,["1838561084"]=true,["1838561146"]=true,["805165833096"]=true}

local Config = {
    AutoBlock = false, BlockRange = 18, Verify = 0.11, MaxBPS = 10,
    OnlyLook = true, Loose = false, ESP = false, Cone = false,
    HDTech = false, AntiFlick = true, FlickParts = 6,
    PredictBlock = true, PredictStrength = 2.4, TurnPredict = 1.9,
    AutoPunch = false, PunchDelay = 0.07, AimPunch = true, FlingPunch = false, FlingPower = 15000,
    PredictionValue = 4, HitboxDrag = false, DragSpeed = 5.6, DragDelay = 0
}

local ActiveSwing = {}
local BlockCount = 0
local LastSec = 0
local ESPParts = {}
local ConeParts = {}
local FlickDebounce = {}
local KillerDelays = {c00lkidd=0,jason=0.013,slasher=0.01,["1x1x1x1"]=0.15,johndoe=0.33,noli=0.15,sixer=0.02,nosferatu=0}
local LastPunch = 0

local Window = Rayfield:CreateWindow({
    Name = "ZEN AB -",
    LoadingTitle = "Made By Zen",
    LoadingSubtitle = "AB",
    Theme = "Ocean",
    ConfigurationSaving = {Enabled = true, FileName = "Zen Ab"}
})

local Combat = Window:CreateTab("Combat")
local Visual = Window:CreateTab("Visuals")
local Prediction = Window:CreateTab("Predicted Block")
local Punch = Window:CreateTab("Auto Punch")

Combat:CreateToggle({Name="Auto Block",Callback=function(v)Config.AutoBlock=v end})
Combat:CreateSlider({Name="Block Range",Range={10,35},Increment=1,Suffix="st",CurrentValue=18,Callback=function(v)Config.BlockRange=v end})
Combat:CreateSlider({Name="Verify Duration",Range={0.05,0.35},Increment=0.01,Suffix="s",CurrentValue=0.11,Callback=function(v)Config.Verify=v end})
Combat:CreateToggle({Name="Only When Looking",CurrentValue=true,Callback=function(v)Config.OnlyLook=v end})
Combat:CreateToggle({Name="Loose Facing",CurrentValue=false,Callback=function(v)Config.Loose=v end})
Combat:CreateToggle({Name="HD-Tech Drag",CurrentValue=false,Callback=function(v)Config.HDTech=v end})
Combat:CreateToggle({Name="Anti-Flick Parts",CurrentValue=true,Callback=function(v)Config.AntiFlick=v end})
Combat:CreateSlider({Name="Flick Parts",Range={1,15},Increment=1,CurrentValue=6,Callback=function(v)Config.FlickParts=v end})

Prediction:CreateToggle({Name="Predicted Block",CurrentValue=true,Callback=function(v)Config.PredictBlock=v end})
Prediction:CreateSlider({Name="Forward Predict",Range={0.5,6},Increment=0.1,Suffix="x",CurrentValue=2.4,Callback=function(v)Config.PredictStrength=v end})
Prediction:CreateSlider({Name="Turn Predict",Range={0.5,5},Increment=0.1,Suffix="x",CurrentValue=1.9,Callback=function(v)Config.TurnPredict=v end})

Punch:CreateToggle({Name="Auto Punch",CurrentValue=false,Callback=function(v)Config.AutoPunch=v end})
Punch:CreateToggle({Name="Aim Punch",CurrentValue=true,Callback=function(v)Config.AimPunch=v end})
Punch:CreateToggle({Name="Fling Punch",CurrentValue=false,Callback=function(v)Config.FlingPunch=v end})
Punch:CreateSlider({Name="Fling Power",Range={5000,30000},Increment=1000,CurrentValue=15000,Callback=function(v)Config.FlingPower=v end})
Punch:CreateSlider({Name="Punch Delay",Range={0,0.3},Increment=0.01,Suffix="s",CurrentValue=0.07,Callback=function(v)Config.PunchDelay=v end})
Punch:CreateToggle({Name="Hitbox Dragging Tech",CurrentValue=false,Callback=function(v)Config.HitboxDrag=v end})
Punch:CreateSlider({Name="Drag Speed",Range={1,15},Increment=0.1,CurrentValue=5.6,Callback=function(v)Config.DragSpeed=v end})
Punch:CreateSlider({Name="Drag Delay",Range={0,0.5},Increment=0.01,Suffix="s",CurrentValue=0,Callback=function(v)Config.DragDelay=v end})

Visual:CreateToggle({Name="Disk ESP",Callback=function(v)Config.ESP=v if not v then for _,p in pairs(ESPParts)do p:Destroy()end ESPParts={}end end})
Visual:CreateToggle({Name="Facing Cone",Callback=function(v)Config.Cone=v if not v then for _,c in pairs(ConeParts)do c:Destroy()end ConeParts={}end end})

local function spawnFlick(k)
    if not Config.AntiFlick or FlickDebounce[k] then return end
    FlickDebounce[k] = true task.delay(0.4,function()FlickDebounce[k]=nil end)
    local hrp = k:FindFirstChild("HumanoidRootPart") if not hrp then return end
    task.wait(KillerDelays[k.Name:lower()] or 0)
    for i=1,Config.FlickParts do
        local p = Instance.new("Part")
        p.Size = Vector3.new(3.5,3.5,3.5)
        p.Transparency = 0.5
        p.Color = Color3.fromRGB(0,200,255)
        p.Material = Enum.Material.Neon
        p.CanCollide = false
        p.Anchored = true
        p.CFrame = hrp.CFrame * CFrame.new(0,0,-i*2.4)
        p.Parent = workspace
        Debris:AddItem(p,0.5)
    end
end

local function updateESP()
    if not Config.ESP or not LP.Character then return end
    local me = LP.Character:FindFirstChild("HumanoidRootPart") if not me then return end
    for _,k in ipairs(Killers:GetChildren()) do
        local hrp = k:FindFirstChild("HumanoidRootPart")
        if hrp then
            if not ESPParts[k] then
                local d = Instance.new("CylinderHandleAdornment")
                d.Adornee = hrp d.AlwaysOnTop = true d.Transparency = 0.5 d.Height = 0.12 d.Radius = Config.BlockRange d.Color3 = Color3.fromRGB(255,0,0) d.Parent = hrp ESPParts[k] = d
            end
            local d = ESPParts[k]
            d.Radius = Config.BlockRange
            d.CFrame = CFrame.new(0,-(hrp.Size.Y/2+0.05),0)*CFrame.Angles(math.rad(90),0,0)
            d.Color3 = (me.Position-hrp.Position).Magnitude <= Config.BlockRange and Color3.fromRGB(0,255,0) or Color3.fromRGB(255,0,0)
        end
    end
end

RunService.Heartbeat:Connect(function(dt)
    updateESP()
    if not LP.Character or not LP.Character:FindFirstChild("HumanoidRootPart") then return end
    local me = LP.Character.HumanoidRootPart
    local now = tick()
    if now - LastSec >= 1 then BlockCount = 0 LastSec = now end

    for _,killer in ipairs(Killers:GetChildren()) do
        local hrp = killer:FindFirstChild("HumanoidRootPart")
        local head = killer:FindFirstChild("Head")
        if not hrp or not head then continue end
        local dist = (me.Position - hrp.Position).Magnitude

        -- AUTO BLOCK
        if Config.AutoBlock and dist <= Config.BlockRange then
            local attacking = false
            for _,s in ipairs(killer:GetDescendants()) do
                if s:IsA("Sound") and s.Playing then
                    local id = tostring(s.SoundId:match("%d+$") or "")
                    if AttackIDs[id] then attacking = true ActiveSwing[killer] = ActiveSwing[killer] or now break end
                end
            end
            if attacking and (now - (ActiveSwing[killer] or 0)) >= Config.Verify then
                local lv = head.CFrame.LookVector
                local dir = (me.Position - head.Position).Unit
                local dot = lv:Dot(dir)
                local thresh = Config.Loose and -0.3 or 0.6
                if not Config.OnlyLook or dot > thresh then
                    if BlockCount < Config.MaxBPS then
                        RE:FireServer("UseActorAbility", {"Block"})
                        BlockCount += 1
                        if Config.HDTech then LP.Character.Humanoid:MoveTo(hrp.Position) end
                        spawnFlick(killer)
                    end
                end
            end
        end

        -- Punch
        if Config.AutoPunch and dist <= 14 and (now - LastPunch) > Config.PunchDelay then
            LastPunch = now
            task.spawn(function()
                task.wait(Config.DragDelay)
                if Config.AimPunch and head then
                    LP.Character.HumanoidRootPart.CFrame = CFrame.new(LP.Character.HumanoidRootPart.Position, head.Position + Vector3.new(0,2,0))
                end
                if Config.HitboxDrag then
                    local start = tick()
                    local conn
                    conn = RunService.Heartbeat:Connect(function()
                        if tick() - start > 1.4 then conn:Disconnect() return end
                        if hrp and LP.Character:FindFirstChild("Humanoid") then
                            LP.Character.Humanoid:MoveTo(hrp.Position + Vector3.new(0,0,math.random(-2,2)))
                        end
                    end)
                end
                if Config.FlingPunch and hrp then
                    local bv = Instance.new("BodyVelocity")
                    bv.MaxForce = Vector3.new(1e5,1e5,1e5)
                    bv.Velocity = (hrp.Position - me.Position).unit * Config.FlingPower
                    bv.Parent = hrp
                    Debris:AddItem(bv, 0.3)
                end
                RE:FireServer("UseActorAbility", {"Punch"})
            end)
        end
    end
end)
