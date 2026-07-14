--[[
    Silent Aim v11 + 名字透视
    Author: 984297530-QQ (ESP 部分由助手整合)
]]

local Library = loadstring([[
在这里粘贴你从 https://raw.githubusercontent.com/mstudio45/LinoriaLib/main/Library.lua 复制的完整源码
]])()

local Options = Library.Options
local Toggles = Library.Toggles

Library.ShowToggleFrameInKeybinds = true
Library.ShowCustomCursor = true
Library.NotifySide = "Left"

local Window = Library:CreateWindow({
    Title = 'cr  aiscr',
    Center = true,
    AutoShow = true,
    Resizable = true,
    TabPadding = 8,
})

local Config = {
    Enabled = false,
    TargetPart = "头部",
    FOV = 150,
    MaxDistance = 200,
    HitChance = 100,
    WallCheck = true,
    DownedCheck = true,
    StaminaEnabled = false,
    ESPEnabled = false,
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local IsAiming = false
local CurrentTool = nil
local fovCircle = nil
local SilentAimRunning = false

local VisualizeEvent = nil
local DamageEvent = nil

local ESPEnabled = false
local ESPNameTags = {}
local ESPConnections = {}

local function GetRemotes()
    local events = ReplicatedStorage:FindFirstChild("Events")
    local events2 = ReplicatedStorage:FindFirstChild("Events2")
    if events then
        DamageEvent = events:FindFirstChild("ZFKLF__H")
    end
    if events2 then
        VisualizeEvent = events2:FindFirstChild("Visualize")
    end
end
GetRemotes()

local function IsValidTarget(player)
    if player == LocalPlayer then return false end
    if not player.Character then return false end
    local humanoid = player.Character:FindFirstChild("Humanoid")
    if not humanoid then return false end
    if humanoid.Health <= 0 then return false end

    if Config.DownedCheck then
        if humanoid.Health <= 15 then return false end
        local state = humanoid:GetState()
        if state == Enum.HumanoidStateType.Dead or state == Enum.HumanoidStateType.Ragdoll then
            return false
        end
        if humanoid.PlatformStand == true then
            return false
        end
    end

    if player.Character:FindFirstChildOfClass("ForceField") then
        return false
    end

    return true
end

local function IsVisible(part)
    if not Config.WallCheck then return true end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = {LocalPlayer.Character, Camera}
    local origin = Camera.CFrame.Position
    local result = Workspace:Raycast(origin, (part.Position - origin), params)
    if not result then return true end
    if result.Instance and result.Instance:IsDescendantOf(part.Parent) then return true end
    return false
end

local function GetTargetPart(character)
    local partName = Config.TargetPart
    if partName == "随机" then
        local parts = {"头部", "躯干", "左臂", "右臂", "左腿", "右腿"}
        partName = parts[math.random(1, #parts)]
    end
    local engMap = {
        ["头部"] = "Head",
        ["躯干"] = "Torso",
        ["左臂"] = "Left Arm",
        ["右臂"] = "Right Arm",
        ["左腿"] = "Left Leg",
        ["右腿"] = "Right Leg",
    }
    local engName = engMap[partName] or "Head"
    local part = character:FindFirstChild(engName)
    if not part then
        part = character:FindFirstChild("HumanoidRootPart")
    end
    return part
end

local function GetClosestTarget()
    local bestTarget = nil
    local bestDistance = Config.FOV
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local maxDist = Config.MaxDistance

    for _, player in ipairs(Players:GetPlayers()) do
        if not IsValidTarget(player) then continue end
        local targetPart = GetTargetPart(player.Character)
        if not targetPart then continue end
        if not IsVisible(targetPart) then continue end

        local worldDist = (Camera.CFrame.Position - targetPart.Position).Magnitude
        if worldDist > maxDist then continue end

        local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
        if not onScreen then continue end
        local dist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
        if dist < bestDistance then
            bestDistance = dist
            bestTarget = {
                Player = player,
                Part = targetPart,
                Position = targetPart.Position,
            }
        end
    end
    return bestTarget
end

local function CreateFOVCircle()
    if fovCircle then fovCircle:Remove() end
    fovCircle = Drawing.new("Circle")
    fovCircle.Visible = false
    fovCircle.Color = Color3.fromRGB(255, 0, 0)
    fovCircle.Thickness = 1.5
    fovCircle.Transparency = 1
    fovCircle.Filled = false
    fovCircle.NumSides = 32
    fovCircle.Radius = Config.FOV
    fovCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
end

local function UpdateFOVCircle()
    if not fovCircle then return end
    if Config.Enabled and Config.FOV > 0 then
        fovCircle.Visible = true
        fovCircle.Radius = Config.FOV
        fovCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    else
        fovCircle.Visible = false
    end
end

local StaminaTables = {}
local StaminaLoop = nil

local function UpdateStaminaTables()
    table.clear(StaminaTables)
    for _, v in pairs(getgc(true)) do
        if type(v) == "table" and rawget(v, "S") then
            table.insert(StaminaTables, v)
        end
    end
end

local function StartStamina()
    if StaminaLoop then return end
    UpdateStaminaTables()
    StaminaLoop = RunService.RenderStepped:Connect(function()
        if Config.StaminaEnabled then
            for _, tbl in pairs(StaminaTables) do
                tbl.S = 100
            end
        end
    end)
end

local function StopStamina()
    if StaminaLoop then
        StaminaLoop:Disconnect()
        StaminaLoop = nil
    end
end

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    if Config.StaminaEnabled then
        UpdateStaminaTables()
    end
end)

local function SetupVisualizeHook()
    if not VisualizeEvent or not DamageEvent then
        return
    end

    if VisualizeConnection then
        VisualizeConnection:Disconnect()
        VisualizeConnection = nil
    end

    VisualizeConnection = VisualizeEvent.Event:Connect(function(_, ShotCode, _, Gun, _, StartPos, BulletsPerShot)
        if not Config.Enabled then return end
        if not IsAiming then return end

        local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
        if not tool or Gun ~= tool then return end

        local target = GetClosestTarget()
        if not target then return end

        if Config.HitChance < 100 and math.random(1, 100) > Config.HitChance then
            return
        end

        local part = GetTargetPart(target.Player.Character)
        if not part then return end

        local hitPos = part.Position
        local bullets = {}
        for i = 1, math.clamp(#BulletsPerShot, 1, 100) do
            bullets[i] = CFrame.new(StartPos, hitPos).LookVector
        end

        task.wait(0.005)

        for i, dir in ipairs(bullets) do
            DamageEvent:FireServer("🧈", Gun, ShotCode, i, part, hitPos, dir)
        end

        if Gun:FindFirstChild("Hitmarker") then
            Gun.Hitmarker:Fire(part)
        end
    end)
end

local function OnAimDownChanged()
    if not CurrentTool then
        IsAiming = false
        return
    end
    local values = CurrentTool:FindFirstChild("Values")
    if not values then
        IsAiming = false
        return
    end
    local aimDown = values:FindFirstChild("AimDown")
    if not aimDown then
        IsAiming = false
        return
    end
    IsAiming = aimDown.Value == true
end

local function UpdateTool()
    local char = LocalPlayer.Character
    if not char then
        CurrentTool = nil
        return
    end
    CurrentTool = char:FindFirstChildOfClass("Tool")
    if CurrentTool then
        local values = CurrentTool:FindFirstChild("Values")
        if values then
            local aimDown = values:FindFirstChild("AimDown")
            if aimDown then
                if AimDownConnection then
                    AimDownConnection:Disconnect()
                    AimDownConnection = nil
                end
                AimDownConnection = aimDown:GetPropertyChangedSignal("Value"):Connect(OnAimDownChanged)
                OnAimDownChanged()
            end
        end
    else
        IsAiming = false
    end
end

local function SetupListeners()
    local char = LocalPlayer.Character
    if char then
        if ToolCheckConnection then ToolCheckConnection:Disconnect() end
        ToolCheckConnection = char.ChildAdded:Connect(function(child)
            if child:IsA("Tool") then UpdateTool() end
        end)
        UpdateTool()
    end

    LocalPlayer.CharacterAdded:Connect(function(newChar)
        task.wait(0.5)
        if ToolCheckConnection then ToolCheckConnection:Disconnect() end
        ToolCheckConnection = newChar.ChildAdded:Connect(function(child)
            if child:IsA("Tool") then UpdateTool() end
        end)
        UpdateTool()
    end)
end

local function StartSilentAim()
    if SilentAimRunning then return end
    SilentAimRunning = true
    Config.Enabled = true

    CreateFOVCircle()
    UpdateFOVCircle()
    SetupListeners()
    SetupVisualizeHook()
    if Config.StaminaEnabled then StartStamina() end
end

local function StopSilentAim()
    Config.Enabled = false
    IsAiming = false
    SilentAimRunning = false

    if fovCircle then
        fovCircle.Visible = false
    end

    if AimDownConnection then
        AimDownConnection:Disconnect()
        AimDownConnection = nil
    end
    if ToolCheckConnection then
        ToolCheckConnection:Disconnect()
        ToolCheckConnection = nil
    end
    if VisualizeConnection then
        VisualizeConnection:Disconnect()
        VisualizeConnection = nil
    end
    if StaminaLoop then
        StaminaLoop:Disconnect()
        StaminaLoop = nil
    end
end

local function CreateNameTag(player)
    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
    if not root then return end

    local tag = char:FindFirstChild("CAT_NameOnly")
    if tag then
        tag.Enabled = true
        return tag
    end

    tag = Instance.new("BillboardGui")
    tag.Name = "CAT_NameOnly"
    tag.AlwaysOnTop = true
    tag.Size = UDim2.new(0, 200, 0, 20)
    tag.StudsOffset = Vector3.new(0, 0.6, 0)
    tag.Parent = char
    tag.Adornee = root
    tag.Enabled = true

    local label = Instance.new("TextLabel")
    label.Name = "NameLabel"
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, 0, 1, 0)
    label.Text = player.Name
    label.TextColor3 = Color3.new(1, 1, 1)
    label.Font = Enum.Font.SourceSans
    label.TextSize = 7
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.TextYAlignment = Enum.TextYAlignment.Center

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 0.8
    stroke.Color = Color3.new(0, 0, 0)
    stroke.Parent = label

    label.Parent = tag
    return tag
end

local function UpdateESPPlayer(player)
    if player == LocalPlayer then return end
    if player.Character then
        CreateNameTag(player)
    end
end

local function RefreshAllESP()
    for _, player in ipairs(Players:GetPlayers()) do
        UpdateESPPlayer(player)
    end
end

local function ClearAllESP()
    for _, player in ipairs(Players:GetPlayers()) do
        local char = player.Character
        if char then
            local tag = char:FindFirstChild("CAT_NameOnly")
            if tag then tag:Destroy() end
        end
    end
    ESPNameTags = {}
end

local function StartESP()
    if ESPEnabled then return end
    ESPEnabled = true
    Config.ESPEnabled = true

    for _, conn in ipairs(ESPConnections) do
        conn:Disconnect()
    end
    ESPConnections = {}

    table.insert(ESPConnections, Players.PlayerAdded:Connect(function(player)
        player.CharacterAdded:Connect(function()
            UpdateESPPlayer(player)
        end)
        if player.Character then
            UpdateESPPlayer(player)
        end
    end))

    table.insert(ESPConnections, Players.PlayerRemoving:Connect(function(player)
        local char = player.Character
        if char then
            local tag = char:FindFirstChild("CAT_NameOnly")
            if tag then tag:Destroy() end
        end
    end))

    table.insert(ESPConnections, LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.5)
        RefreshAllESP()
    end))

    RefreshAllESP()
end

local function StopESP()
    if not ESPEnabled then return end
    ESPEnabled = false
    Config.ESPEnabled = false

    for _, conn in ipairs(ESPConnections) do
        conn:Disconnect()
    end
    ESPConnections = {}
    ClearAllESP()
end

local MainTab = Window:AddTab('静默瞄准')
local StaminaTab = Window:AddTab('体力')
local InfoTab = Window:AddTab('信息')
local ESPTab = Window:AddTab('透视')

local MainLeft = MainTab:AddLeftGroupbox('控制')
MainLeft:AddToggle('Enabled', {
    Text = '启用静默瞄准',
    Default = false,
    Tooltip = '开镜后左键子弹自动拐向 FOV 内敌人',
    Callback = function(v)
        if v then
            StartSilentAim()
        else
            StopSilentAim()
        end
        UpdateFOVCircle()
    end
})

MainLeft:AddSlider('HitChance', {
    Text = '命中率 (%)',
    Default = 100,
    Min = 1,
    Max = 100,
    Rounding = 0,
    Callback = function(v) Config.HitChance = v end
})

local TargetRight = MainTab:AddRightGroupbox('目标设置')
TargetRight:AddDropdown('TargetPart', {
    Text = '瞄准部位',
    Values = {'头部', '躯干', '左臂', '右臂', '左腿', '右腿', '随机'},
    Default = 1,
    Callback = function(v) Config.TargetPart = v end
})

TargetRight:AddSlider('FOV', {
    Text = 'FOV范围',
    Default = 150,
    Min = 10,
    Max = 800,
    Rounding = 0,
    Callback = function(v)
        Config.FOV = v
        UpdateFOVCircle()
    end
})

TargetRight:AddSlider('MaxDistance', {
    Text = '锁定距离（格）',
    Default = 200,
    Min = 10,
    Max = 500,
    Rounding = 0,
    Callback = function(v) Config.MaxDistance = v end
})

TargetRight:AddToggle('WallCheck', {
    Text = '墙壁检测',
    Default = true,
    Tooltip = '检测目标是否被墙挡住',
    Callback = function(v) Config.WallCheck = v end
})

TargetRight:AddToggle('DownedCheck', {
    Text = '不打倒地',
    Default = true,
    Tooltip = '不打血量≤15或处于倒地状态的玩家',
    Callback = function(v) Config.DownedCheck = v end
})

local StaminaLeft = StaminaTab:AddLeftGroupbox('体力')
StaminaLeft:AddToggle('StaminaEnabled', {
    Text = '无限体力',
    Default = false,
    Tooltip = '体力永不减少',
    Callback = function(v)
        Config.StaminaEnabled = v
        if v then
            UpdateStaminaTables()
            StartStamina()
        else
            StopStamina()
        end
    end
})

local ESPLeft = ESPTab:AddLeftGroupbox('名字透视')
ESPLeft:AddToggle('ESPEnabled', {
    Text = '显示玩家名字',
    Default = false,
    Tooltip = '在所有其他玩家头顶显示白色名字',
    Callback = function(v)
        if v then
            StartESP()
        else
            StopESP()
        end
    end
})

local InfoLeft = InfoTab:AddLeftGroupbox('脚本信息')
InfoLeft:AddLabel('═══════════════════════════════')
InfoLeft:AddLabel('静默瞄准 v11 + 透视')
InfoLeft:AddLabel('作者: 984297530-QQ (ESP 增强)')
InfoLeft:AddLabel('当前玩家: ' .. LocalPlayer.Name)
InfoLeft:AddLabel('═══════════════════════════════')

Library.ToggleKeybind = Options.MenuKeybind

Camera:GetPropertyChangedSignal("ViewportSize"):Connect(UpdateFOVCircle)
CreateFOVCircle()
UpdateFOVCircle()

print("脚本加载成功")
