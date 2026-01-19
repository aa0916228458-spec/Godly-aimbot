-- made by no_green_beans team (Godly trash aimbot)
local function GetService(name)
    return game:GetService(name)
end

local Services = {
    Players = GetService("Players"),
    RunService = GetService("RunService"),
    UserInputService = GetService("UserInputService"),
    TweenService = GetService("TweenService"),
    CoreGui = GetService("CoreGui"),
    Workspace = GetService("Workspace"),
    HttpService = GetService("HttpService"),
    VirtualUser = GetService("VirtualUser"),
    Debris = GetService("Debris"),
    StarterGui = GetService("StarterGui"),
    LogService = GetService("LogService")
}

local Env = {
    LocalPlayer = Services.Players.LocalPlayer,
    Camera = Services.Workspace.CurrentCamera,
    Mouse = Services.Players.LocalPlayer:GetMouse()
}

local function GetSafeParent()
    local target = Env.LocalPlayer:WaitForChild("PlayerGui", 10)
    if not target then
        target = Services.CoreGui
    end
    return target
end

local State = {
    MenuOpen = false,
    IntroComplete = false,
    Mode = "none",
    
    Aimbot = {
        IsLocking = false,
        CurrentTarget = nil
    },
    
    Config = {
        Aimbot = {
            Enabled = false,
            Part = "head (both rigs)",
            FOV = 150,
            ShowFOV = true,
            Color = Color3.fromRGB(255, 255, 255),
            Stickiness = 1,
            WallCheck = true,
            Multipoint = false,
            TeamCheck = false,
            Keybind = Enum.UserInputType.MouseButton2
        },
        Triggerbot = {
            Enabled = false,
            Delay = 0.05
        }
    },
    
    Theme = {
        Main = Color3.fromRGB(255, 255, 255),
        Secondary = Color3.fromRGB(0, 0, 0),
        Accent = Color3.fromRGB(50, 50, 50),
        TextSize = 18,
        Font = Enum.Font.GothamBold
    }
}

local PartMap = {
    ["head (both rigs)"] = {"Head"},
    ["humanoidrootpart (both rigs)"] = {"HumanoidRootPart"},
    ["torso (r6 only)"] = {"Torso"},
    ["left arm (r6 only)"] = {"Left Arm"},
    ["right arm (r6 only)"] = {"Right Arm"},
    ["left leg (r6 only)"] = {"Left Leg"},
    ["right leg (r6 only)"] = {"Right Leg"},
    ["uppertorso (r15 only)"] = {"UpperTorso"},
    ["lowertorso (r15 only)"] = {"LowerTorso"},
    ["leftupperarm (r15 only)"] = {"LeftUpperArm"},
    ["leftlowerarm (r15 only)"] = {"LeftLowerArm"},
    ["rightupperarm (r15 only)"] = {"RightUpperArm"},
    ["rightlowerarm (r15 only)"] = {"RightLowerArm"},
    ["lefthand (r15 only)"] = {"LeftHand"},
    ["righthand (r15 only)"] = {"RightHand"},
    ["leftfoot (r15 only)"] = {"LeftFoot"},
    ["rightfoot (r15 only)"] = {"RightFoot"},
    ["leftupperleg (r15 only)"] = {"LeftUpperLeg"},
    ["leftlowerleg (r15 only)"] = {"LeftLowerLeg"},
    ["rightupperleg (r15 only)"] = {"RightUpperLeg"},
    ["rightlowerleg (r15 only)"] = {"RightLowerLeg"}
}

local DropdownList = {}
for k, _ in pairs(PartMap) do table.insert(DropdownList, k) end
table.sort(DropdownList)

local MathLib = {}

function MathLib.GetDistance(v1, v2)
    return (v1 - v2).Magnitude
end

function MathLib.WorldToScreen(worldPos)
    local screen_pos, on_screen = Env.Camera:WorldToViewportPoint(worldPos)
    return Vector2.new(screen_pos.X, screen_pos.Y), on_screen
end

function MathLib.Lerp(a, b, t)
    return a + (b - a) * t
end

function MathLib.LookAt(eye, target)
    local forward = (target - eye).Unit
    local up = Vector3.new(0, 1, 0)
    
    if math.abs(forward.Y) > 0.999 then
        up = Vector3.new(1, 0, 0)
    end
    
    local right = forward:Cross(up).Unit
    local new_up = right:Cross(forward).Unit
    
    return CFrame.fromMatrix(eye, right, new_up, -forward)
end

local Selector = {}

function Selector:FindPart(character, config_string)
    if not character then return nil end
    
    local valid_names = PartMap[config_string]
    if not valid_names then
        return character:FindFirstChild("Head")
    end
    
    for _, name in ipairs(valid_names) do
        local part = character:FindFirstChild(name)
        if part then return part end
    end
    
    return nil
end

function Selector:IsVisible(part)
    local origin = Env.Camera.CFrame.Position
    local direction = part.Position - origin
    
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {Env.LocalPlayer.Character, Env.Camera}
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.IgnoreWater = true
    
    local result = Services.Workspace:Raycast(origin, direction, params)
    
    if result then
        if result.Instance:IsDescendantOf(part.Parent) then
            return true
        end
        return false
    end
    return true
end

local DrawLib = {}
DrawLib.__index = DrawLib

function DrawLib.new(type)
    local self = setmetatable({}, DrawLib)
    self.Type = type
    
    local gui = Instance.new("ScreenGui")
    gui.Name = "RealAimbot_Overlay"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.Parent = GetSafeParent()
    
    if type == "Circle" then
        local frame = Instance.new("Frame")
        frame.BackgroundTransparency = 1
        frame.AnchorPoint = Vector2.new(0.5, 0.5)
        frame.ZIndex = 1000
        frame.Parent = gui
        
        local stroke = Instance.new("UIStroke")
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Thickness = 2
        stroke.Color = State.Config.Aimbot.Color
        stroke.Parent = frame
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(1, 0)
        corner.Parent = frame
        
        self.Element = frame
        self.Stroke = stroke
        self.Screen = gui
        self.Visible = false
        self.Radius = 100
        self.Position = Vector2.new(0, 0)
        self.Color = State.Config.Aimbot.Color
    end
    
    return self
end

function DrawLib:Update()
    if not self.Element then return end
    
    if self.Type == "Circle" then
        self.Element.Visible = self.Visible
        self.Element.Size = UDim2.new(0, self.Radius * 2, 0, self.Radius * 2)
        self.Element.Position = UDim2.new(0, self.Position.X, 0, self.Position.Y)
        self.Stroke.Color = self.Color
    end
end

local UIUtils = {}

function UIUtils:Clean(str)
    if not str then return "" end
    local s = string.lower(str)
    s = string.gsub(s, "[,%.%']", "")
    return s
end

function UIUtils:Tween(obj, props, time, style, dir)
    local info = TweenInfo.new(
        time or 0.3, 
        style or Enum.EasingStyle.Quart, 
        dir or Enum.EasingDirection.Out
    )
    local anim = Services.TweenService:Create(obj, info, props)
    anim:Play()
end

function UIUtils:MakeDraggable(frame)
    local dragging, dragInput, dragStart, startPos
    
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    
    frame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end
    end)
    
    Services.UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            local goal = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            Services.TweenService:Create(frame, TweenInfo.new(0.05), {Position = goal}):Play()
        end
    end)
end

local UI = {}

function UI:Init()
    for _, v in pairs(GetSafeParent():GetChildren()) do
        if v.Name == "real_aimbot_v14" then v:Destroy() end
    end

    local screen = Instance.new("ScreenGui")
    screen.Name = "real_aimbot_v14"
    screen.Parent = GetSafeParent()
    screen.IgnoreGuiInset = true
    screen.ResetOnSpawn = false
    screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    self.Screen = screen
    self.ActiveTab = nil
end

function UI:Intro(on_finish)
    local frame = Instance.new("Frame")
    frame.Name = "Intro"
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = State.Theme.Main
    frame.ZIndex = 2000
    frame.Parent = self.Screen
    
    local title = Instance.new("TextLabel")
    title.Text = UIUtils:Clean("hello do u want a simple version or the full script")
    title.Font = State.Theme.Font
    title.TextColor3 = State.Theme.Secondary
    title.TextSize = 32
    title.Size = UDim2.new(1, 0, 0, 100)
    title.Position = UDim2.new(0, 0, 0.2, 0)
    title.BackgroundTransparency = 1
    title.ZIndex = 2001
    title.Parent = frame
    
    local function CreateBtn(text, x_pos)
        local b = Instance.new("TextButton")
        b.Text = UIUtils:Clean(text)
        b.Font = State.Theme.Font
        b.TextColor3 = State.Theme.Main
        b.BackgroundColor3 = State.Theme.Secondary
        b.TextSize = 24
        b.Size = UDim2.new(0, 300, 0, 80)
        
        if x_pos == 0.3 then 
            b.Position = UDim2.new(0.5, -320, 0.6, 0) 
        else 
            b.Position = UDim2.new(0.5, 20, 0.6, 0) 
        end
        
        b.ZIndex = 2001
        b.Parent = frame
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 12)
        return b
    end
    
    local btn_simple = CreateBtn("simple version", 0.3)
    local btn_full = CreateBtn("full version", 0.7)
    
    local arrow = Instance.new("TextLabel")
    arrow.Text = UIUtils:Clean("<-- free")
    arrow.Font = Enum.Font.PermanentMarker
    arrow.TextColor3 = State.Theme.Secondary
    arrow.TextSize = 36
    arrow.BackgroundTransparency = 1
    arrow.Size = UDim2.new(0, 150, 0, 50)
    arrow.Position = UDim2.new(1, 10, 0.5, -25)
    arrow.Rotation = -10
    arrow.ZIndex = 2002
    arrow.Parent = btn_full
    
    local function Finish(mode)
        State.Mode = mode
        
        if mode == "simple" then
            State.Config.Aimbot.Part = "head (both rigs)"
            State.Config.Aimbot.Stickiness = 1
            State.Config.Aimbot.WallCheck = true
        end
        
        UIUtils:Tween(title, {TextTransparency = 1}, 0.5)
        UIUtils:Tween(btn_simple, {BackgroundTransparency = 1, TextTransparency = 1}, 0.5)
        UIUtils:Tween(btn_full, {BackgroundTransparency = 1, TextTransparency = 1}, 0.5)
        UIUtils:Tween(arrow, {TextTransparency = 1}, 0.5)
        
        task.wait(0.6)
        UIUtils:Tween(frame, {BackgroundTransparency = 1}, 0.5)
        task.wait(0.5)
        
        frame:Destroy()
        State.IntroComplete = true
        on_finish()
    end
    
    btn_simple.MouseButton1Click:Connect(function() 
        UIUtils:Tween(btn_simple, {Size = UDim2.new(0,280,0,70)}, 0.1, Enum.EasingStyle.Bounce)
        task.wait(0.1)
        Finish("simple") 
    end)
    btn_full.MouseButton1Click:Connect(function() 
        UIUtils:Tween(btn_full, {Size = UDim2.new(0,280,0,70)}, 0.1, Enum.EasingStyle.Bounce)
        task.wait(0.1)
        Finish("full") 
    end)
end

function UI:Construct()
    local main = Instance.new("Frame")
    main.Name = "MainFrame"
    main.Size = UDim2.new(0, 600, 0, 500)
    main.Position = UDim2.new(0.5, -300, 0.5, -250)
    main.BackgroundColor3 = State.Theme.Main
    main.ClipsDescendants = true
    main.Visible = false
    main.Parent = self.Screen
    
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 6
    stroke.Color = State.Theme.Secondary
    stroke.Parent = main
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 16)
    corner.Parent = main
    
    UIUtils:MakeDraggable(main)
    self.MainWindow = main
    
    local title = Instance.new("TextLabel")
    title.Text = UIUtils:Clean("real aimbot")
    title.Font = Enum.Font.GothamBlack
    title.TextColor3 = State.Theme.Secondary
    title.TextSize = 36
    title.Size = UDim2.new(1, -40, 0, 60)
    title.Position = UDim2.new(0, 20, 0, 10)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.BackgroundTransparency = 1
    title.Parent = main
    
    local hint = Instance.new("TextLabel")
    hint.Text = UIUtils:Clean("right ctrl to close")
    hint.Font = State.Theme.Font
    hint.TextColor3 = Color3.fromRGB(150, 150, 150)
    hint.TextSize = 18
    hint.Size = UDim2.new(0, 300, 0, 60)
    hint.Position = UDim2.new(1, -320, 0, 10)
    hint.TextXAlignment = Enum.TextXAlignment.Right
    hint.BackgroundTransparency = 1
    hint.Parent = main
    
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -20, 1, -90)
    scroll.Position = UDim2.new(0, 10, 0, 80)
    scroll.BackgroundTransparency = 1
    scroll.ScrollBarThickness = 6
    scroll.ScrollBarImageColor3 = State.Theme.Secondary
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.Parent = main
    
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 15)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = scroll
    
    self.Container = scroll
    
    if State.Mode == "simple" then
        self:Label("simple settings")
        self:Toggle("enable aimbot", nil, function(v) State.Config.Aimbot.Enabled = v end)
        self:Slider("fov size", 50, 600, 150, nil, function(v) State.Config.Aimbot.FOV = v end)
        self:Label("extras")
        self:Toggle("team check", nil, function(v) State.Config.Aimbot.TeamCheck = v end)
        self:Toggle("trigger bot", nil, function(v) State.Config.Triggerbot.Enabled = v end)
    else
        self:Label("aimbot settings")
        self:Toggle("enable aimbot", nil, function(v) State.Config.Aimbot.Enabled = v end)
        self:Dropdown("body part", DropdownList, function(v) State.Config.Aimbot.Part = v end)
        self:Slider("fov size", 50, 600, 150, nil, function(v) State.Config.Aimbot.FOV = v end)
        self:Slider("stickiness", 0, 100, 100, "(suggested to put at 100%)", function(v) 
            local s = v/100
            if s < 0.01 then s = 0.01 end
            State.Config.Aimbot.Stickiness = s
        end)
        
        self:Label("safety checks")
        self:Toggle("wall check", "prevents locking through walls", function(v) State.Config.Aimbot.WallCheck = v end)
        self:Toggle("team check", nil, function(v) State.Config.Aimbot.TeamCheck = v end)
        self:Toggle("multi-point", "scans body if head is hidden", function(v) State.Config.Aimbot.Multipoint = v end)
        
        self:Label("extras")
        self:Toggle("trigger bot", "auto fires when on target", function(v) State.Config.Triggerbot.Enabled = v end)
    end
    
    self:ToggleMenu(true)
end

function UI:ToggleMenu(force)
    local main = self.MainWindow
    if not main then return end
    
    State.MenuOpen = not State.MenuOpen
    if force ~= nil then State.MenuOpen = force end
    
    if State.MenuOpen then
        main.Visible = true
        main.Size = UDim2.new(0, 600, 0, 0)
        UIUtils:Tween(main, {Size = UDim2.new(0, 600, 0, 500)}, 0.6, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)
    else
        local anim = Services.TweenService:Create(main, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Size = UDim2.new(0, 600, 0, 0)})
        anim:Play()
        anim.Completed:Connect(function()
            if not State.MenuOpen then main.Visible = false end
        end)
    end
end

function UI:Label(text)
    local l = Instance.new("TextLabel")
    l.Text = UIUtils:Clean(text)
    l.Font = Enum.Font.GothamBlack
    l.TextColor3 = Color3.fromRGB(150, 150, 150)
    l.TextSize = 20
    l.Size = UDim2.new(1, 0, 0, 40)
    l.BackgroundTransparency = 1
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = self.Container
    local p = Instance.new("UIPadding"); p.PaddingLeft = UDim.new(0, 10); p.Parent = l
end

function UI:Toggle(text, desc, cb)
    local btn = Instance.new("TextButton")
    btn.Text = ""
    btn.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
    btn.Size = UDim2.new(1, 0, 0, 60)
    btn.Parent = self.Container
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 10); c.Parent = btn
    
    local l = Instance.new("TextLabel")
    l.Text = UIUtils:Clean(text)
    l.Font = State.Theme.Font
    l.TextColor3 = State.Theme.Secondary
    l.TextSize = 22
    l.Size = UDim2.new(0.8, 0, 1, 0)
    l.Position = UDim2.new(0, 20, 0, desc and -10 or 0)
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.BackgroundTransparency = 1
    l.Parent = btn
    
    if desc then
        local d = Instance.new("TextLabel")
        d.Text = UIUtils:Clean(desc)
        d.Font = State.Theme.Font
        d.TextColor3 = Color3.fromRGB(100, 100, 100)
        d.TextSize = 14
        d.Size = UDim2.new(0.8, 0, 1, 0)
        d.Position = UDim2.new(0, 20, 0, 15)
        d.TextXAlignment = Enum.TextXAlignment.Left
        d.BackgroundTransparency = 1
        d.Parent = btn
    end
    
    local box = Instance.new("Frame")
    box.Size = UDim2.new(0, 30, 0, 30)
    box.Position = UDim2.new(1, -50, 0.5, -15)
    box.BackgroundColor3 = Color3.new(1,1,1)
    box.Parent = btn
    local s = Instance.new("UIStroke"); s.Thickness = 3; s.Color = State.Theme.Secondary; s.Parent = box
    local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0, 6); bc.Parent = box
    
    local check = Instance.new("Frame")
    check.Size = UDim2.new(0, 0, 0, 0)
    check.Position = UDim2.new(0.5, 0, 0.5, 0)
    check.BackgroundColor3 = State.Theme.Secondary
    check.Parent = box
    local cc = Instance.new("UICorner"); cc.CornerRadius = UDim.new(0, 4); cc.Parent = check
    
    local active = false
    btn.MouseButton1Click:Connect(function()
        active = not active
        if active then
            UIUtils:Tween(check, {Size = UDim2.new(1, -8, 1, -8), Position = UDim2.new(0, 4, 0, 4)}, 0.2, Enum.EasingStyle.Back)
        else
            UIUtils:Tween(check, {Size = UDim2.new(0, 0, 0, 0), Position = UDim2.new(0.5, 0, 0.5, 0)}, 0.2, Enum.EasingStyle.Back)
        end
        cb(active)
    end)
end

function UI:Slider(text, min, max, default, desc, cb)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 80)
    f.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
    f.Parent = self.Container
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 10); c.Parent = f
    
    local l = Instance.new("TextLabel")
    l.Text = UIUtils:Clean(text)
    l.Font = State.Theme.Font
    l.TextColor3 = State.Theme.Secondary
    l.TextSize = 22
    l.Size = UDim2.new(1, -20, 0, 30)
    l.Position = UDim2.new(0, 20, 0, desc and -5 or 10)
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.BackgroundTransparency = 1
    l.Parent = f
    
    if desc then
        local d = Instance.new("TextLabel")
        d.Text = UIUtils:Clean(desc)
        d.Font = State.Theme.Font
        d.TextColor3 = Color3.fromRGB(100, 100, 100)
        d.TextSize = 14
        d.Size = UDim2.new(1, -20, 0, 30)
        d.Position = UDim2.new(0, 20, 0, 18)
        d.TextXAlignment = Enum.TextXAlignment.Left
        d.BackgroundTransparency = 1
        d.Parent = f
    end
    
    local val = Instance.new("TextLabel")
    val.Text = tostring(default)
    val.Font = State.Theme.Font
    val.TextColor3 = State.Theme.Secondary
    val.TextSize = 22
    val.Size = UDim2.new(0, 60, 0, 30)
    val.Position = UDim2.new(1, -80, 0, 10)
    val.BackgroundTransparency = 1
    val.Parent = f
    
    local bar = Instance.new("TextButton")
    bar.Text = ""
    bar.AutoButtonColor = false
    bar.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
    bar.Size = UDim2.new(1, -40, 0, 10)
    bar.Position = UDim2.new(0, 20, 0, 50)
    bar.Parent = f
    local bc = Instance.new("UICorner"); bc.Parent = bar
    
    local fill = Instance.new("Frame")
    fill.BackgroundColor3 = State.Theme.Secondary
    fill.Size = UDim2.new((default-min)/(max-min), 0, 1, 0)
    fill.Parent = bar
    local fc = Instance.new("UICorner"); fc.Parent = fill
    
    local dragging = false
    local function update(input)
        local x = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        local value = math.floor(((max - min) * x) + min)
        UIUtils:Tween(fill, {Size = UDim2.new(x, 0, 1, 0)}, 0.05, Enum.EasingStyle.Linear)
        val.Text = tostring(value)
        cb(value)
    end
    
    bar.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; update(i) end end)
    Services.UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
    Services.UserInputService.InputChanged:Connect(function(i) if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then update(i) end end)
end

function UI:Dropdown(text, options, cb)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 60)
    f.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
    f.ClipsDescendants = true
    f.Parent = self.Container
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 10); c.Parent = f
    
    local btn = Instance.new("TextButton")
    btn.Text = ""
    btn.BackgroundTransparency = 1
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.Parent = f
    
    local lbl = Instance.new("TextLabel")
    lbl.Text = UIUtils:Clean(text .. ": select")
    lbl.Font = State.Theme.Font
    lbl.TextColor3 = State.Theme.Secondary
    lbl.TextSize = 22
    lbl.Size = UDim2.new(1, -50, 0, 60)
    lbl.Position = UDim2.new(0, 20, 0, 0)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.BackgroundTransparency = 1
    lbl.Parent = f
    
    local arrow = Instance.new("TextLabel")
    arrow.Text = "v"
    arrow.Font = State.Theme.Font
    arrow.TextColor3 = State.Theme.Secondary
    arrow.TextSize = 24
    arrow.Size = UDim2.new(0, 40, 0, 60)
    arrow.Position = UDim2.new(1, -40, 0, 0)
    arrow.BackgroundTransparency = 1
    arrow.Parent = f
    
    local list = Instance.new("Frame")
    list.Size = UDim2.new(1, 0, 0, 0)
    list.Position = UDim2.new(0, 0, 0, 60)
    list.BackgroundTransparency = 1
    list.Parent = f
    local layout = Instance.new("UIListLayout"); layout.Parent = list
    
    local open = false
    btn.MouseButton1Click:Connect(function()
        open = not open
        if open then
            arrow.Text = "^"
            UIUtils:Tween(f, {Size = UDim2.new(1, 0, 0, 60 + (#options * 40))}, 0.3, Enum.EasingStyle.Bounce)
        else
            arrow.Text = "v"
            UIUtils:Tween(f, {Size = UDim2.new(1, 0, 0, 60)}, 0.3, Enum.EasingStyle.Quad)
        end
    end)
    
    for _, opt in pairs(options) do
        local b = Instance.new("TextButton")
        b.Text = UIUtils:Clean("  " .. opt)
        b.Font = State.Theme.Font
        b.TextSize = 18
        b.TextColor3 = State.Theme.Secondary
        b.BackgroundColor3 = Color3.fromRGB(230, 230, 230)
        b.Size = UDim2.new(1, 0, 0, 40)
        b.TextXAlignment = Enum.TextXAlignment.Left
        b.Parent = list
        
        b.MouseButton1Click:Connect(function()
            lbl.Text = UIUtils:Clean(text .. ": " .. opt)
            open = false
            arrow.Text = "v"
            UIUtils:Tween(f, {Size = UDim2.new(1, 0, 0, 60)}, 0.3, Enum.EasingStyle.Quad)
            cb(opt)
        end)
    end
end

local Aimbot = {}
local FOV = DrawLib.new("Circle")
FOV.Color = Color3.fromRGB(255, 255, 255)

function Aimbot:Scan()
    local best = nil
    local shortest = State.Config.Aimbot.FOV
    local m = Services.UserInputService:GetMouseLocation()
    
    for _, plr in pairs(Services.Players:GetPlayers()) do
        if plr ~= Env.LocalPlayer then
            local char = plr.Character
            if char then
                local hum = char:FindFirstChild("Humanoid")
                local part = Selector:FindPart(char, State.Config.Aimbot.Part)
                
                if hum and hum.Health > 0 and part then
                    local allowed = true
                    if State.Config.Aimbot.TeamCheck then
                        if plr.Team ~= nil and plr.Team == Env.LocalPlayer.Team then allowed = false end
                    end
                    
                    if allowed then
                        local pos, on_screen = MathLib.WorldToScreen(part.Position)
                        if on_screen then
                            local dist = (pos - m).Magnitude
                            if dist <= shortest then
                                local visible = true
                                if State.Config.Aimbot.WallCheck then
                                    visible = Selector:IsVisible(part)
                                    if not visible and State.Config.Aimbot.Multipoint then
                                        visible = false
                                        for _, n in pairs({"HumanoidRootPart", "Torso", "Right Arm", "Left Arm"}) do
                                            local p = char:FindFirstChild(n)
                                            if p and Selector:IsVisible(p) then
                                                part = p
                                                visible = true
                                                break
                                            end
                                        end
                                    end
                                else
                                    visible = true
                                end
                                
                                if visible then
                                    shortest = dist
                                    best = part
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return best
end

Services.RunService.RenderStepped:Connect(function()
    if State.IntroComplete and State.Config.Aimbot.Enabled and State.Config.Aimbot.ShowFOV then
        FOV.Visible = true
        FOV.Radius = State.Config.Aimbot.FOV
        FOV.Position = Services.UserInputService:GetMouseLocation()
        FOV:Update()
    else
        FOV.Visible = false
        FOV:Update()
    end
    
    if State.Config.Triggerbot.Enabled then
        local t = Env.Mouse.Target
        if t and t.Parent:FindFirstChild("Humanoid") then
            if mouse1press then mouse1press(); task.wait(0.05); mouse1release() end
        end
    end
end)

Services.RunService:BindToRenderStep("RealAimbot_Lock", Enum.RenderPriority.Camera.Value + 1, function()
    if not State.IntroComplete or not State.Config.Aimbot.Enabled then return end
    
    local pressing = Services.UserInputService:IsMouseButtonPressed(State.Config.Aimbot.Keybind)
    
    if pressing then
        local target = Aimbot:Scan()
        if target then
            local current = Env.Camera.CFrame
            local goal = MathLib.LookAt(Env.Camera.CFrame.Position, target.Position)
            Env.Camera.CFrame = current:Lerp(goal, State.Config.Aimbot.Stickiness)
        end
    end
end)

Services.UserInputService.InputBegan:Connect(function(input, gpe)
    if input.KeyCode == Enum.KeyCode.RightControl and State.IntroComplete then
        UI:ToggleMenu()
    end
end)

UI:Init()
UI:Intro(function()
    UI:Construct()
end)