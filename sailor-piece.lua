-- [[ EUGEN | SAILOR PIECE REFINED BY PRINZXZ ]] --

local cloneref = (cloneref or clonereference or function(instance) return instance end)
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local Players = cloneref(game:GetService("Players"))
local LocalPlayer = Players.LocalPlayer

local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()

-- */ Window Config /* --
local Window = WindUI:CreateWindow({
    Title = "Eugen | Sailor Piece",
    Icon = "solar:shield-check-bold",
    Folder = "EugenLogic",
    CloseBind = Enum.KeyCode.Semicolon,
    NewElements = true, -- Added from example
    HideSearchBar = false, -- Added from example
    OpenButton = {
        Title = "EUGEN",
        Icon = "solar:maximize-bold",
        Enabled = true,
        Draggable = true,
        OnlyMobile = false,
        Scale = 0.6,
        Color = ColorSequence.new(Color3.fromHex("#FF3030"), Color3.fromHex("#8B0000")),
    },
})
Window:SetUIScale(0.95)

-- */ Global States /* --
_G.SelectedBoss = "Atomic"
_G.SelectedDifficulty = "Normal"
_G.AutoSpawn = false
_G.AutoHit = false
_G.SelectedSkills = {}
_G.AutoSkillActive = false
_G.AutoTween = false
_G.TweenSpeedValue = 300
_G.TweenDistanceValue = 5
_G.IsTweeningBoss = false -- To prevent overlapping moves


-- */ Skill Mapping /* --
local skillMap = { 
    ["Skill Z"] = 1, 
    ["Skill X"] = 2, 
    ["Skill C"] = 3, 
    ["Skill V"] = 4,
    ["Skill F"] = 5 
}

-- */ Boss Remotes Map /* --
local BossConfigs = {
    ["Atomic"] = {
        Remote = ReplicatedStorage.RemoteEvents:FindFirstChild("RequestSpawnAtomic"),
        Args = function(diff) return {diff} end
    },
    ["Anos"] = {
        Remote = ReplicatedStorage.Remotes:FindFirstChild("RequestSpawnAnosBoss"),
        Args = function(diff) return {"Anos", diff} end
    },
    ["Rimuru"] = {
        Remote = ReplicatedStorage.RemoteEvents:FindFirstChild("RequestSpawnRimuru"),
        Args = function(diff) return {diff} end
    }
}

-- */ TAB 1: HOME (Dashboard) /* --
-- Adding elements directly to HomeTab without a Section to avoid collapsible "Categories"
local HomeTab = Window:Tab({ Title = "Home", Icon = "solar:home-2-bold" })

HomeTab:Button({ 
    Title = "Welcome to Eugen System",
    Desc = "Status: Functional & Secure"
})

HomeTab:Button({ 
    Title = "Owner: PrinzXz", 
    Icon = "solar:user-bold" 
})

HomeTab:Button({ 
    Title = "Version: 2.5.0 Premium", 
    Icon = "solar:verified-check-bold" 
})

HomeTab:Button({ 
    Title = "Job ID: " .. game.JobId, 
    Icon = "solar:server-bold",
    Callback = function() 
        setclipboard(game.JobId) 
        WindUI:Notify({Title = "System", Content = "JobId copied to clipboard!"}) 
    end
})

-- */ TAB 2: FARMING /* --
local FarmTab = Window:Tab({ Title = "Farming", Icon = "solar:fire-bold" })

local CombatSection = FarmTab:Section({ Title = "Auto Combat" })

CombatSection:Toggle({
    Title = "Auto Basic Attack",
    Value = false,
    Callback = function(state)
        _G.AutoHit = state
        task.spawn(function()
            while _G.AutoHit do
                pcall(function() 
                    ReplicatedStorage.CombatSystem.Remotes.RequestHit:FireServer() 
                end)
                task.wait(0.12)
            end
        end)
    end,
})

_G.SelectedSkills = {"Skill Z", "Skill C"}

CombatSection:Dropdown({
    Title = "Select Auto Skills",
    Multi = true,
    Values = {"Skill Z", "Skill X", "Skill C", "Skill V", "Skill F"},
    Value = _G.SelectedSkills,
    Callback = function(v) 
        _G.SelectedSkills = v 
    end,
})

CombatSection:Toggle({
    Title = "Activate Skills Loop",
    Value = false,
    Callback = function(state)
        _G.AutoSkillActive = state
        if state then
            task.spawn(function()
                local AbilityRemote = ReplicatedStorage:FindFirstChild("RequestAbility", true) 
                    or ReplicatedStorage:FindFirstChild("Remotes", true):FindFirstChild("RequestAbility", true)
                
                while _G.AutoSkillActive do
                    local Character = LocalPlayer.Character
                    if Character and Character:FindFirstChild("Humanoid") and Character.Humanoid.Health > 0 then
                        for _, skillName in ipairs(_G.SelectedSkills) do
                            if not _G.AutoSkillActive then break end
                            local skillID = skillMap[skillName]
                            if skillID and AbilityRemote then
                                pcall(function() AbilityRemote:FireServer(skillID) end)
                                task.wait(0.3)
                            end
                        end
                    end
                    task.wait(0.5)
                end
            end)
        end
    end,
})

-- */ TAB 3: BOSSES /* --
local BossTab = Window:Tab({ Title = "Bosses", Icon = "solar:ghost-bold" })
local SpawnerSection = BossTab:Section({ Title = "Automated Spawner" })

SpawnerSection:Dropdown({
    Title = "Select Boss",
    Values = {"Atomic", "Anos", "Rimuru"},
    Value = "Atomic",
    Callback = function(v) _G.SelectedBoss = v end,
})

SpawnerSection:Dropdown({
    Title = "Difficulty Mode",
    Values = {"Normal", "Medium", "Hard", "Extreme"},
    Value = "Normal",
    Callback = function(v) _G.SelectedDifficulty = v end,
})

SpawnerSection:Toggle({
    Title = "Auto Spawn Boss",
    Value = false,
    Callback = function(state)
        _G.AutoSpawn = state
        if state then
            task.spawn(function()
                while _G.AutoSpawn do
                    local Config = BossConfigs[_G.SelectedBoss]
                    if Config and Config.Remote then
                        pcall(function()
                            Config.Remote:FireServer(table.unpack(Config.Args(_G.SelectedDifficulty)))
                        end)
                    end
                    task.wait(7) -- Slower cooldown to avoid server kick/rate limit
                end
            end)
        end
    end,
})

SpawnerSection:Slider({
    Title = "Tween Speed",
    Value = { Min = 10, Max = 1000, Default = 10 },
    Callback = function(value) _G.TweenSpeedValue = value end,
})

SpawnerSection:Slider({
    Title = "Follow Distance",
    Value = { Min = 2, Max = 15, Default = 5 },
    Callback = function(value) _G.TweenDistanceValue = value end,
})

SpawnerSection:Toggle({
    Title = "Auto Follow Behind Boss",
    Value = false,
    Callback = function(state)
        _G.AutoTween = state
        local RunService = game:GetService("RunService")
        local noclipConn
        
        if state then
            -- 1. SAFE CORE-ONLY NOCLIP (Prevents "Bug Part" by NOT touching limbs)
            noclipConn = RunService.Stepped:Connect(function()
                if not _G.AutoTween then 
                    if noclipConn then noclipConn:Disconnect() end 
                    return 
                end
                pcall(function()
                    local char = LocalPlayer.Character
                    if char and char:FindFirstChild("HumanoidRootPart") then
                        -- 1. PHYSICS STABILIZATION (Combat-Ready)
                        local hrp = char.HumanoidRootPart
                        local hum = char:FindFirstChildOfClass("Humanoid")
                        
                        -- DISABLE GRAVITY ONLY (Instead of Anchor)
                        local bg = hrp:FindFirstChild("AntiGravity") or Instance.new("BodyVelocity")
                        bg.Name = "AntiGravity"
                        bg.MaxForce = Vector3.new(0, math.huge, 0)
                        bg.Velocity = Vector3.new(0, 0.01, 0) -- Tiny drift for physics sync
                        bg.Parent = hrp
                        
                        -- Allow Combat States
                        if hum then
                            hum.PlatformStand = false
                            hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
                            hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
                        end
                        
                        -- Targeted Noclip
                        for _, name in ipairs({"HumanoidRootPart", "Torso", "UpperTorso", "LowerTorso", "Head"}) do
                            local p = char:FindFirstChild(name)
                            if p and p:IsA("BasePart") then
                                p.CanCollide = false
                            end
                        end
                    end
                end)
            end)


            -- 2. SMOOTH LINEAR GLIDE ENGINE
            task.spawn(function()
                while _G.AutoTween do
                    local dt = RunService.Heartbeat:Wait()
                    pcall(function()
                        local targetName = _G.SelectedBoss
                        local Boss = nil
                        
                        -- Search root and common folders
                        for _, v in ipairs(workspace:GetChildren()) do
                            if v:IsA("Model") and string.find(v.Name, targetName) and v:FindFirstChild("HumanoidRootPart") then
                                Boss = v; break
                            end
                        end
                        if not Boss then
                            for _, folder in ipairs({"NPCs", "Enemies", "SummonedBosses"}) do
                                local f = workspace:FindFirstChild(folder)
                                if f then
                                    for _, v in ipairs(f:GetChildren()) do
                                        if v:IsA("Model") and string.find(v.Name, targetName) and v:FindFirstChild("HumanoidRootPart") then
                                            Boss = v; break
                                        end
                                    end
                                end
                                if Boss then break end
                            end
                        end
                        
                        local Char = LocalPlayer.Character
                        if Boss and Char and Char:FindFirstChild("HumanoidRootPart") then
                            local bossHRP = Boss.HumanoidRootPart
                            local myHRP = Char.HumanoidRootPart
                            local targetCF = bossHRP.CFrame * CFrame.new(0, 0, _G.TweenDistanceValue)
                            
                            local dist = (myHRP.Position - targetCF.Position).Magnitude
                            if dist > 1.5 then
                                local speed = _G.TweenSpeedValue
                                local moveDirection = (targetCF.Position - myHRP.Position).Unit
                                local moveStep = moveDirection * speed * dt
                                
                                if moveStep.Magnitude >= dist then
                                    myHRP.CFrame = targetCF
                                else
                                    myHRP.CFrame = myHRP.CFrame + moveStep
                                    -- Look at boss (Flat rotation)
                                    myHRP.CFrame = CFrame.new(myHRP.Position, Vector3.new(bossHRP.Position.X, myHRP.Position.Y, bossHRP.Position.Z))
                                end
                            end
                        end
                    end)
                end
            end)
        else
            -- 3. CLEANUP (Restore Character state on Toggle OFF)
            if noclipConn then noclipConn:Disconnect() end
            pcall(function()
                local char = LocalPlayer.Character
                if char then
                    local hum = char:FindFirstChild("Humanoid")
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        hrp.Anchored = false
                        local bg = hrp:FindFirstChild("AntiGravity")
                        if bg then bg:Destroy() end
                    end
                    if hum then 
                        hum.PlatformStand = false
                        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
                        hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
                        hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                    end
                    -- Only restore collision for core parts
                    for _, name in ipairs({"HumanoidRootPart", "Torso", "UpperTorso", "LowerTorso", "Head"}) do
                        local p = char:FindFirstChild(name)
                        if p and p:IsA("BasePart") then
                            p.CanCollide = true
                        end
                    end
                end
            end)
        end
    end,
})



-- */ BOSS RESULT HANDLER /* --
-- Listening to Remotes provided by user for UI Feedback
local function ListenToResults()
    local Remotes = ReplicatedStorage:FindFirstChild("RemoteEvents")
    if Remotes then
        local atomicResult = Remotes:FindFirstChild("AtomicBossResult")
        if atomicResult then
            atomicResult.OnClientEvent:Connect(function(success, message)
                WindUI:Notify({ Title = "Atomic Spawn", Content = message, Duration = 5 })
            end)
        end
        local rimuruResult = Remotes:FindFirstChild("RimuruBossResult")
        if rimuruResult then
            rimuruResult.OnClientEvent:Connect(function(success, message)
                WindUI:Notify({ Title = "Rimuru Spawn", Content = message, Duration = 5 })
            end)
        end
    end
end
task.spawn(ListenToResults)

-- */ INITIALIZATION /* --
task.spawn(function()
    task.wait(1.5) -- Wait briefly for the UI to settle
    WindUI:Notify({ 
        Title = "Eugen System", 
        Content = "Ready! Dashboard info is now visible directly.", 
        Duration = 5 
    })
end)

-- Anti-AFK Logic
local VirtualUser = game:GetService("VirtualUser")
LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)
