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
_G.TweenSpeedValue = 150
_G.TweenDistanceValue = 5
_G.IsTweeningBoss = false -- To prevent overlapping moves
_G.AutoHuntTimed = false
_G.TargetTimedBosses = {} -- Selected world bosses
_G.TimedBossesData = {} -- Raw data from server

_G.TimedBossConfig = {
    ["GojoBoss"] = "Limitless Sorcerer",
    ["SukunaBoss"] = "Cursed King",
    ["AizenBoss"] = "Manipulator",
    ["JinwooBoss"] = "Solo Hunter",
    ["AlucardBoss"] = "Vampire King",
    ["YujiBoss"] = "Cursed Vessel",
    ["YamatoBoss"] = "Yamato",
    ["StrongestShinobiBoss"] = "Strongest Shinobi"
}

-- */ ISLAND DATABASE */ --
_G.IslandCoordinates = {
    ["SailorIsland"] = Vector3.new(185, 1, 665),
    ["HollowIsland"] = Vector3.new(-538, 0, 1071),
    ["ShibuyaStation"] = Vector3.new(1500, 50, 150),
    ["JudgementIsland"] = Vector3.new(-1320, 76, -1202),
    ["NinjaIsland"] = Vector3.new(-1912, 22, -607),
}

-- Map BossID to their Internal Portal Name
_G.BossIslandMap = {
    ["GojoBoss"] = "ShibuyaStation",
    ["SukunaBoss"] = "ShibuyaStation",
    ["AizenBoss"] = "HollowIsland",
    ["JinwooBoss"] = "SailorIsland",
    ["AlucardBoss"] = "SailorIsland",
    ["YujiBoss"] = "ShibuyaStation",
    ["YamatoBoss"] = "JudgementIsland",
    ["StrongestShinobiBoss"] = "NinjaIsland"
}




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

-- */ GLOBAL MOVEMENT SYSTEM /* --
local noclipConn = nil
_G.ManageFollowSystem = function()
    local RunService = game:GetService("RunService")
    
    if _G.AutoTween or _G.AutoHuntTimed then
        -- 1. DYNAMIC NOCLIP (Only when hunting or moving)
        if not noclipConn then
            noclipConn = RunService.Stepped:Connect(function()
                if not (_G.AutoTween or _G.AutoHuntTimed) then 
                    if noclipConn then noclipConn:Disconnect(); noclipConn = nil end 
                    return 
                end
                pcall(function()
                    local char = LocalPlayer.Character
                    -- Noclip only if active or near boss to avoid physics snags
                    if char and _G.IsActiveHunting then
                        for _, name in ipairs({"HumanoidRootPart", "Torso", "UpperTorso", "LowerTorso", "Head"}) do
                            local p = char:FindFirstChild(name)
                            if p and p:IsA("BasePart") then p.CanCollide = false end
                        end
                    end
                end)
            end)
        end

        -- 2. DYNAMIC MOVEMENT ENGINE (SMOOTH PID-LIKE)
        local currentLoopId = tick()
        _G.MovementLoopId = currentLoopId

        local function findTargetInWorkspace(name)
            for _, v in ipairs(workspace:GetChildren()) do
                if v:IsA("Model") and (v.Name == name or string.find(v.Name, name)) and v:FindFirstChild("HumanoidRootPart") then return v end
            end
            for _, folder in ipairs({"NPCs", "Enemies", "SummonedBosses"}) do
                local f = workspace:FindFirstChild(folder)
                if f then
                    for _, v in ipairs(f:GetChildren()) do
                        if v:IsA("Model") and (v.Name == name or string.find(v.Name, name)) and v:FindFirstChild("HumanoidRootPart") then return v end
                    end
                end
            end
            return nil
        end

        task.spawn(function()
            while (_G.AutoTween or _G.AutoHuntTimed) and _G.MovementLoopId == currentLoopId do
                local dt = RunService.Heartbeat:Wait()
                pcall(function()
                    local Char = LocalPlayer.Character
                    if not Char or not Char:FindFirstChild("HumanoidRootPart") then return end
                    local myHRP = Char.HumanoidRootPart
                    local hum = Char:FindFirstChildOfClass("Humanoid")
                    
                    local Boss = nil
                    if _G.AutoHuntTimed then
                        for bossId, dispName in pairs(_G.TimedBossConfig) do
                            if table.find(_G.TargetTimedBosses, dispName) then
                                Boss = findTargetInWorkspace(bossId) or findTargetInWorkspace(dispName)
                                if Boss then break end
                            end
                        end
                    end
                    if not Boss and _G.AutoTween then
                        Boss = findTargetInWorkspace(_G.SelectedBoss)
                    end
                    
                    if Boss and Boss:FindFirstChild("HumanoidRootPart") then 
                        _G.IsActiveHunting = true
                        
                        -- PHYSICS SETUP
                        local bg = myHRP:FindFirstChild("AntiGravity") or Instance.new("BodyVelocity")
                        bg.Name = "AntiGravity"
                        bg.Parent = myHRP
                        if hum then hum.PlatformStand = true end

                        local bossHRP = Boss.HumanoidRootPart
                        local targetCF = bossHRP.CFrame * CFrame.new(0, 0, _G.TweenDistanceValue)
                        local dist = (myHRP.Position - targetCF.Position).Magnitude
                        
                        -- ROTATION: UPRIGHT
                        myHRP.CFrame = CFrame.lookAt(myHRP.Position, Vector3.new(bossHRP.Position.X, myHRP.Position.Y, bossHRP.Position.Z))

                        if dist > 3 then
                            bg.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                            local baseS = _G.TweenSpeedValue
                            local brakingZ = 30
                            local adaptS = baseS
                            if dist < brakingZ then adaptS = math.max(10, baseS * (dist / brakingZ)) end
                            bg.Velocity = (targetCF.Position - myHRP.Position).Unit * adaptS
                            if dist < 8 then myHRP.CFrame = myHRP.CFrame:Lerp(targetCF, 0.15) end
                        else
                            bg.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                            bg.Velocity = Vector3.new(0, 0, 0)
                            myHRP.CFrame = targetCF
                        end
                    else
                        -- [PULSE GLIDE NAVIGATOR - SMART TARGETING]
                        if _G.AutoHuntTimed and _G.TimedBossesData then
                            local closestId = nil
                            local minJumpDist = math.huge
                            
                            -- FIND THE NEAREST SPAWNED BOSS (Prevents Island Ping-Pong)
                            for bId, data in pairs(_G.TimedBossesData) do
                                local disp = _G.TimedBossConfig[bId]
                                if disp and table.find(_G.TargetTimedBosses, disp) and data.state == "SPAWNED" then
                                    local iName = _G.BossIslandMap[bId]
                                    local iPos = _G.IslandCoordinates[iName]
                                    if iPos then
                                        local d = (myHRP.Position - iPos).Magnitude
                                        if d < minJumpDist then
                                            minJumpDist = d
                                            closestId = bId
                                        end
                                    end
                                end
                            end

                            if closestId then
                                local iName = _G.BossIslandMap[closestId]
                                local iPos = _G.IslandCoordinates[iName]

                                if iPos and iPos ~= Vector3.new(0,0,0) then
                                    local iDist = (myHRP.Position - iPos).Magnitude
                                    -- Only jump if not already on the boss's island
                                    if iDist > 100 then
                                        _G.IsActiveHunting = true
                                        local bg = myHRP:FindFirstChild("AntiGravity") or Instance.new("BodyVelocity")
                                        bg.Name = "AntiGravity"
                                        bg.Parent = myHRP
                                        bg.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                                        bg.Velocity = Vector3.new(0,0,0)
                                        if hum then hum.PlatformStand = true end

                                        WindUI:Notify({Title = "Pulse Glide", Content = "Dashing to " .. iName .. "...", Duration = 2})
                                        
                                        -- THE PULSE LOOP (DASH -> REST -> SAVE)
                                        while (_G.AutoHuntTimed or _G.AutoTween) and (myHRP.Position - iPos).Magnitude > 30 do
                                            local cPos = myHRP.Position
                                            local dir = (iPos - cPos).Unit
                                            
                                            -- 1. THE PULSE (Move 24 studs total, 8 per step)
                                            for step = 1, 3 do
                                                myHRP.CFrame = myHRP.CFrame + (dir * 8)
                                                task.wait(0.01)
                                            end
                                            
                                            -- 2. THE SAVE (Hard-Sync position to server)
                                            myHRP.Velocity = Vector3.new(0,0,0)
                                            myHRP.Anchored = true
                                            task.wait(0.05) -- Reduced rest for smoothness
                                            myHRP.Anchored = false
                                            
                                            if not (_G.AutoHuntTimed or _G.AutoTween) then break end
                                            if findTargetInWorkspace(closestId) or findTargetInWorkspace(_G.TimedBossConfig[closestId]) then break end
                                        end
                                    end
                                end
                            end
                        end

                        -- STANDBY
                        _G.IsActiveHunting = false
                        if hum then hum.PlatformStand = false end
                        local bg = myHRP:FindFirstChild("AntiGravity")
                        if bg then bg:Destroy() end
                    end
                end)
            end
        end)
    else
        -- 3. TOTAL CLEANUP
        _G.IsActiveHunting = false
        if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
        pcall(function()
            local char = LocalPlayer.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    hrp.Anchored = false
                    hrp.Velocity = Vector3.new(0, 0, 0)
                    local bg = hrp:FindFirstChild("AntiGravity")
                    if bg then bg:Destroy() end
                end
                if hum then 
                    hum.PlatformStand = false
                    hum:ChangeState(Enum.HumanoidStateType.Running)
                end
                for _, name in ipairs({"HumanoidRootPart", "Torso", "UpperTorso", "LowerTorso", "Head"}) do
                    local p = char:FindFirstChild(name)
                    if p and p:IsA("BasePart") then p.CanCollide = true end
                end
            end
        end)
    end
end







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

local GPSSection = HomeTab:Section({ Title = "GPS Tool" })

GPSSection:Button({
    Title = "Copy My Coordinates",
    Desc = "Format: Vector3.new(x, y, z)",
    Icon = "solar:map-point-bold",
    Callback = function()
        pcall(function()
            local pos = LocalPlayer.Character.HumanoidRootPart.Position
            local formatted = "Vector3.new(" .. math.floor(pos.X) .. ", " .. math.floor(pos.Y) .. ", " .. math.floor(pos.Z) .. ")"
            setclipboard(formatted)
            WindUI:Notify({Title = "GPS", Content = "Position copied: " .. formatted})
        end)
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
    Value = { Min = 10, Max = 350, Default = 150 },
    Callback = function(value) _G.TweenSpeedValue = value end,
})

SpawnerSection:Slider({
    Title = "Follow Distance",
    Value = { Min = 2, Max = 15, Default = 5 },
    Callback = function(value) _G.TweenDistanceValue = value end,
})

-- */ TAB 4: TIMED BOSSES (WORLD BOSSES) /* --
local TimedTab = Window:Tab({ Title = "Timed Bosses", Icon = "solar:alarm-bold" })
local TimedSection = TimedTab:Section({ Title = "World Boss Targets" })

local timedBossNames = _G.TimedBossConfig


TimedSection:Dropdown({
    Title = "Select Targets",
    Multi = true,
    Values = {"Limitless Sorcerer", "Cursed King", "Manipulator", "Solo Hunter", "Vampire King", "Cursed Vessel", "Yamato", "Strongest Shinobi"},
    Value = {},
    Callback = function(v) 
        _G.TargetTimedBosses = v 
    end,
})

TimedSection:Toggle({
    Title = "Auto Hunt Timed Bosses",
    Value = false,
    Callback = function(state)
        _G.AutoHuntTimed = state
        if _G.ManageFollowSystem then
            _G.ManageFollowSystem()
        end
    end,
})


SpawnerSection:Toggle({
    Title = "Auto Follow Behind Boss",
    Value = false,
    Callback = function(state)
        _G.AutoTween = state
        if _G.ManageFollowSystem then
            _G.ManageFollowSystem()
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

-- */ WORLD BOSS SYNC LISTENER /* --
local function ListenToTimedBosses()
    local Remote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("BossTimerSync")
    if Remote then
        Remote.OnClientEvent:Connect(function(data)
            if type(data) == "table" then
                _G.TimedBossesData = data
            end
        end)
    end
end
task.spawn(ListenToTimedBosses)


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
