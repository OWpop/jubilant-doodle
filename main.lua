-- ================= 0. SINGLETON CHECK & AUTO-QUEUE =================
if _G.OWP_Hub_Running then return end
_G.OWP_Hub_Running = true

local SCRIPT_URL = "https://raw.githubusercontent.com/OWpop/jubilant-doodle/main/main.lua"
if queue_on_teleport then
    queue_on_teleport('loadstring(game:HttpGet("' .. SCRIPT_URL .. '?t="..tostring(tick())))()')
end

--[[
    PETAPETA: School of Nightmares V15.0 (Phase 4: Premium UI & Theme Engine)
    By: OtherWisePop
    USE RESPONSIBLY AND AT YOUR OWN RISK.
--]]

-- ================= 1. Constants & Services =================
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
if not player then
	repeat task.wait() until Players.LocalPlayer
	player = Players.LocalPlayer
end
local playerGui = player:WaitForChild("PlayerGui")

local GUI_NAME = "OWP_PetaHub_V15_0_" .. tostring(math.random(10000, 99999))
local CONFIG_FILE_NAME = "OWP_PetaHub_Config.json"

local FONT_REGULAR = Enum.Font.Gotham
local FONT_BOLD = Enum.Font.GothamBold
local FONT_SEMIBOLD = Enum.Font.GothamSemibold

-- Configuration Constants
local WALK_SPEEDS = {16, 20, 30, 40, 50}
local IMPORTANT_ITEM_NAMES = { "key", "key_neon", "key_ver2" }
local MAX_ESP_DISTANCE = 400
local TELEPORT_COOLDOWN = 10 
local TELEPORT_VERTICAL_OFFSET = 3.5
local RELATIVE_Y_BOUND = 250  
local RELATIVE_XZ_BOUND = 2500 
local ESP_UPDATE_INTERVAL = 0.1 
local VOID_THRESHOLD = -100 
local VOID_TELEPORT_HEIGHT = 50 
local ENFORCE_SPEED_DURATION = 8 

-- Status Colors (Used specifically for TP warnings)
local STATUS_GREEN = Color3.fromRGB(46, 204, 113)
local STATUS_YELLOW = Color3.fromRGB(241, 196, 15)
local STATUS_RED = Color3.fromRGB(231, 76, 60)
local STATUS_CYAN = Color3.fromRGB(52, 152, 219)

-- ================= 2. Centralized State =================
-- Config MUST start with GuiVisible = false as requested
local Config = {
    GuiVisible = false, 
    Theme = "Dark",
    SpeedIndex = 2,
    NoClip = false,
    FullBright = false,
    ESP = false,
    ESPDistance = false,
    AntiVoid = false,
    TeleportHUD = false,
    SpeedLock = false,
    BypassFire = false,
    SearchAura = false,
    AntiFreeze = false
}

local Engine = {
    Cache = { Keys = {}, Fires = {}, Prompts = {} },
    ESPBeams = {}, ESPAttachments = {}, ESPConnections = {}, ESPUpdateRunning = false,
    NoClipConnection = nil, FullBrightConnection = nil, AntiVoidConnection = nil, AntiFreezeConnection = nil,
    SpeedEnforceRunning = false, SpeedEnforceCancelTime = 0, HiddenFires = {}, 
    TPCooldownEnd = 0, TPWarningEnd = 0, TPWarningText = ""
}

local initialLighting = {
	Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
	Brightness = Lighting.Brightness, FogEnd = Lighting.FogEnd, GlobalShadows = Lighting.GlobalShadows,
}

-- ================= 3. State Persistence =================
local function LoadConfig()
    if not isfile or not readfile then return end
    if isfile(CONFIG_FILE_NAME) then
        local success, content = pcall(readfile, CONFIG_FILE_NAME)
        if success and content then
            local decodeSuccess, decoded = pcall(function() return HttpService:JSONDecode(content) end)
            if decodeSuccess and type(decoded) == "table" then
                for k, v in pairs(decoded) do
                    if Config[k] ~= nil and type(Config[k]) == type(v) then
                        if k == "SpeedIndex" and (v < 1 or v > #WALK_SPEEDS) then continue end
                        Config[k] = v
                    end
                end
            end
        end
    end
end

local function SaveConfig()
    if not writefile then return end
    pcall(function() writefile(CONFIG_FILE_NAME, HttpService:JSONEncode(Config)) end)
end

LoadConfig()

-- Force GuiVisible false on initial injection to allow animation
Config.GuiVisible = false 

-- ================= 4. Helper Functions =================
local function Tween(obj, props, time)
    local tw = TweenService:Create(obj, TweenInfo.new(time or 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
    tw:Play()
    return tw
end

local function GetDictKeys(dict)
    local keys = {}
    for k in pairs(dict) do table.insert(keys, k) end
    return keys
end

local function isPlayerHoldingAnyKey()
    local function scan(container)
        if not container then return false end
        for _, obj in ipairs(container:GetDescendants()) do
            if obj:IsA("Tool") or obj:IsA("Model") or obj:IsA("BasePart") then
                local lowerName = obj.Name:lower()
                for _, n in ipairs(IMPORTANT_ITEM_NAMES) do if string.find(lowerName, n:lower()) then return true end end
                if string.find(lowerName, "key") then return true end
            end
        end
        return false
    end
    if scan(player.Character) then return true end
    if scan(player.Backpack) then return true end
    if Workspace.CurrentCamera and scan(Workspace.CurrentCamera) then return true end
    if player.Character then for _, child in ipairs(player.Character:GetChildren()) do if child:IsA("Tool") then return true end end end
    return false
end

local function isItemOnGround(obj)
	if not obj or not obj:IsDescendantOf(Workspace) then return false end
	local p = obj.Parent
	while p and p ~= Workspace do
		if p:IsA("Model") and p:FindFirstChild("Humanoid") then return false end
		p = p.Parent
	end
	if Workspace.CurrentCamera and obj:IsDescendantOf(Workspace.CurrentCamera) then return false end
	return true
end

local function isWithinRelativeBounds(tPos, pPos)
    local off = tPos - pPos
    if math.abs(off.Y) > RELATIVE_Y_BOUND or math.abs(off.X) > RELATIVE_XZ_BOUND or math.abs(off.Z) > RELATIVE_XZ_BOUND then return false end
    return true
end

-- ================= 5. Master Cache System =================
local function CheckFireText(obj, text)
    if not text then return end
    if string.find(text:lower(), "fire") or string.find(text:lower(), "extinguish") or string.find(text:lower(), "flame") then Engine.Cache.Fires[obj] = true end
end

local function CategorizeObject(obj)
    local cls, lowerName = obj.ClassName, obj.Name:lower()
    
    if cls == "ProximityPrompt" then
        local action, name, object = obj.ActionText:lower(), lowerName, obj.ObjectText:lower()
        if string.find(action, "search") or string.find(name, "search") then Engine.Cache.Prompts[obj] = true end
        CheckFireText(obj, action)
        CheckFireText(obj, object)
        obj:GetPropertyChangedSignal("ActionText"):Connect(function()
            local a = obj.ActionText:lower()
            if string.find(a, "search") then Engine.Cache.Prompts[obj] = true end
            CheckFireText(obj, a)
        end)
        obj:GetPropertyChangedSignal("ObjectText"):Connect(function() CheckFireText(obj, obj.ObjectText) end)

    elseif cls == "BillboardGui" or cls == "SurfaceGui" or cls == "TextLabel" then
        if cls == "TextLabel" then
            CheckFireText(obj, obj.Text)
            obj:GetPropertyChangedSignal("Text"):Connect(function() CheckFireText(obj, obj.Text) end)
        end
    end

    local isKey = false
    for _, n in ipairs(IMPORTANT_ITEM_NAMES) do if string.find(lowerName, n:lower()) then isKey = true; break end end
    if not isKey and string.find(lowerName, "key") then isKey = true end
    if isKey and (cls == "Tool" or cls == "Model" or obj:IsA("BasePart")) then Engine.Cache.Keys[obj] = true end
    if string.find(lowerName, "fire") or string.find(lowerName, "extinguish") or string.find(lowerName, "flame") then Engine.Cache.Fires[obj] = true end
end

for _, obj in ipairs(Workspace:GetDescendants()) do CategorizeObject(obj) end
Workspace.DescendantAdded:Connect(CategorizeObject)
Workspace.DescendantRemoving:Connect(function(obj) Engine.Cache.Keys[obj] = nil; Engine.Cache.Fires[obj] = nil; Engine.Cache.Prompts[obj] = nil end)

-- ================= 6. Core Logic Functions =================
local function cleanEspForItem(obj)
	if not obj then return end
	if Engine.ESPBeams[obj] then Engine.ESPBeams[obj]:Destroy(); Engine.ESPBeams[obj] = nil end
	if Engine.ESPAttachments[obj] then Engine.ESPAttachments[obj]:Destroy(); Engine.ESPAttachments[obj] = nil end
	if Engine.ESPConnections[obj] then for _, c in ipairs(Engine.ESPConnections[obj]) do c:Disconnect() end; Engine.ESPConnections[obj] = nil end
end
local function cleanupAllEsp()
	local objectsToClean = {}
	for obj, _ in pairs(Engine.ESPBeams) do table.insert(objectsToClean, obj) end
	for _, obj in ipairs(objectsToClean) do cleanEspForItem(obj) end
	Engine.ESPBeams, Engine.ESPAttachments, Engine.ESPConnections = {}, {}, {}
end

local function createEspForItem(obj)
	if not obj or Engine.ESPBeams[obj] or not obj.Parent then return end
	local adornee = obj:FindFirstChild("Handle") or obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
	if not adornee or not adornee:IsA("BasePart") or not adornee.Parent then return end

	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not isItemOnGround(adornee) or not isWithinRelativeBounds(adornee.Position, root.Position) then return end
	if Config.ESPDistance and (adornee.Position - root.Position).Magnitude > MAX_ESP_DISTANCE then return end

    local originAttach = root:FindFirstChild("OWP_OriginAttach")
    if not originAttach then 
        originAttach = Instance.new("Attachment", root); originAttach.Name = "OWP_OriginAttach"
    end

	local targetAttach = Instance.new("Attachment", adornee)
	local beam = Instance.new("Beam")
	beam.Attachment0 = originAttach; beam.Attachment1 = targetAttach; beam.Width0 = 0.1; beam.Width1 = 0.1; beam.FaceCamera = true
	beam.Color = ColorSequence.new(Config.FullBright and COLOR_ACCENT_CYAN or COLOR_ACCENT_GREEN)
	beam.Transparency = NumberSequence.new(Config.FullBright and 0.1 or 0.3)
	beam.LightEmission = Config.FullBright and 0.6 or 0.35
	beam.Parent = Workspace:FindFirstChildOfClass("Terrain") or Workspace

	Engine.ESPBeams[obj] = beam; Engine.ESPAttachments[obj] = targetAttach
	local connections = {}
	table.insert(connections, obj.Destroying:Connect(function() cleanEspForItem(obj) end))
	table.insert(connections, adornee.Destroying:Connect(function() cleanEspForItem(obj) end))
	if obj:IsA("Tool") or obj:IsA("Model") then
		table.insert(connections, obj.AncestryChanged:Connect(function(_, newParent)
			if not newParent or not (newParent:IsDescendantOf(Workspace)) then cleanEspForItem(obj) end
		end))
	end
	Engine.ESPConnections[obj] = connections
end

local function updateEspBeamsThrottled()
	if Engine.ESPUpdateRunning then return end
	Engine.ESPUpdateRunning = true

	while Config.ESP do
        task.wait(ESP_UPDATE_INTERVAL)
        pcall(function()
            local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            if not root or not root.Parent then return end

            local itemsToClean = {}
            for obj, beam in pairs(Engine.ESPBeams) do
                local targetAttachment = Engine.ESPAttachments[obj]
                local adornee = targetAttachment and targetAttachment.Parent
                local isValid = targetAttachment and adornee and adornee.Parent and adornee:IsA("BasePart")
                if isValid then
                    if not isItemOnGround(adornee) or not isWithinRelativeBounds(adornee.Position, root.Position) then isValid = false
                    elseif Config.ESPDistance and (adornee.Position - root.Position).Magnitude > MAX_ESP_DISTANCE then isValid = false end
                end
                if not isValid then table.insert(itemsToClean, obj) end
            end
            for _, objToClean in ipairs(itemsToClean) do cleanEspForItem(objToClean) end
            for _, obj in ipairs(GetDictKeys(Engine.Cache.Keys)) do pcall(createEspForItem, obj) end
        end)
	end
	Engine.ESPUpdateRunning = false
	cleanupAllEsp()
end

local function hideFire(obj)
    local target = obj
    if obj:IsA("ProximityPrompt") or obj:IsA("ParticleEmitter") or obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") then
        if obj.Parent and obj.Parent:IsA("BasePart") and obj.Parent.Size.Magnitude <= 50 then target = obj.Parent end
    end
    if Engine.HiddenFires[target] then return end
    Engine.HiddenFires[target] = {Parent = target.Parent}
    target.Parent = nil
end

-- ================= 7. Centralized Physics & Background Engine =================
RunService.Stepped:Connect(function()
    local char, hum, root = player.Character, nil, nil
    if char then hum = char:FindFirstChild("Humanoid"); root = char:FindFirstChild("HumanoidRootPart") end
    if hum and root then
        local desiredSpeed = WALK_SPEEDS[Config.SpeedIndex]
        if Config.AntiFreeze then
            if root.Anchored then pcall(function() root.Anchored = false end) end
            if hum.PlatformStand then pcall(function() hum.PlatformStand = false end) end
            if hum.Sit then pcall(function() hum.Sit = false end) end
        end
        if Config.SpeedLock then
            if hum.WalkSpeed ~= desiredSpeed then hum.WalkSpeed = desiredSpeed end
        elseif Engine.SpeedEnforceRunning then
            if tick() < Engine.SpeedEnforceCancelTime then
                if hum.WalkSpeed ~= desiredSpeed then hum.WalkSpeed = desiredSpeed end
            else Engine.SpeedEnforceRunning = false end
        elseif Config.AntiFreeze and hum.WalkSpeed == 0 then
            pcall(function() hum.WalkSpeed = desiredSpeed end)
        end
    end
end)

task.spawn(function()
    while task.wait(0.1) do
        if Config.BypassFire then for _, obj in ipairs(GetDictKeys(Engine.Cache.Fires)) do if obj and obj.Parent then pcall(hideFire, obj) end end end
        if Config.SearchAura then
            local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            if root then
                for _, prompt in ipairs(GetDictKeys(Engine.Cache.Prompts)) do
                    if prompt and prompt.Parent and prompt.Enabled then
                        local part = prompt.Parent
                        if part:IsA("BasePart") and (part.Position - root.Position).Magnitude <= (prompt.MaxActivationDistance + 1.5) then
                            pcall(function() fireproximityprompt(prompt, 1, true) end)
                        end
                    end
                end
            end
        end
    end
end)

-- ================= 8. Feature Registration List =================
local FeatureList = {
    {Name = "Speed", Key = "SpeedIndex", Type = "Cycle", CycleOptions = WALK_SPEEDS, Action = function(val)
        Engine.SpeedEnforceCancelTime = tick() + ENFORCE_SPEED_DURATION
        Engine.SpeedEnforceRunning = true
    end, OnCharacterAdded = function(char, hum)
        if hum then hum.WalkSpeed = WALK_SPEEDS[Config.SpeedIndex] end
        Engine.SpeedEnforceCancelTime = tick() + ENFORCE_SPEED_DURATION; Engine.SpeedEnforceRunning = true
    end},
    
    {Name = "NoClip", Key = "NoClip", Type = "Toggle", Action = function(val)
        if val then
            if not Engine.NoClipConnection then
                Engine.NoClipConnection = RunService.Stepped:Connect(function()
                    if player.Character then
                        for _, p in ipairs(player.Character:GetDescendants()) do
                            if p:IsA("BasePart") then pcall(function() p.CanCollide = false end) end
                        end
                    end
                end)
            end
        else
            if Engine.NoClipConnection then Engine.NoClipConnection:Disconnect(); Engine.NoClipConnection = nil end
            if player.Character then
                for _, p in ipairs(player.Character:GetDescendants()) do
                    if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then pcall(function() p.CanCollide = true end) end
                end
            end
        end
    end, OnCharacterAdded = function(char, hum)
        if Engine.NoClipConnection then Engine.NoClipConnection:Disconnect(); Engine.NoClipConnection = nil end
        if Config.NoClip then
            task.spawn(function()
                task.wait(0.5) 
                if Config.NoClip and not Engine.NoClipConnection then
                    Engine.NoClipConnection = RunService.Stepped:Connect(function()
                        if player.Character then
                            for _, p in ipairs(player.Character:GetDescendants()) do
                                if p:IsA("BasePart") then pcall(function() p.CanCollide = false end) end
                            end
                        end
                    end)
                end
            end)
        end
    end},
    
    {Name = "Full Bright", Key = "FullBright", Type = "Toggle", Action = function(val)
        if val then
            Engine.FullBrightConnection = RunService.RenderStepped:Connect(function()
                Lighting.Ambient = Color3.fromRGB(255, 255, 255)
                Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
                Lighting.Brightness = 2.5
                Lighting.FogEnd = 1000000
                Lighting.GlobalShadows = false
            end)
        else
            if Engine.FullBrightConnection then Engine.FullBrightConnection:Disconnect(); Engine.FullBrightConnection = nil end
            Lighting.Ambient, Lighting.OutdoorAmbient, Lighting.Brightness, Lighting.FogEnd, Lighting.GlobalShadows = 
                initialLighting.Ambient, initialLighting.OutdoorAmbient, initialLighting.Brightness, initialLighting.FogEnd, initialLighting.GlobalShadows
        end
    end},
    
    {Name = "ESP", Key = "ESP", Type = "Toggle", Action = function(val)
        if val then if not Engine.ESPUpdateRunning then task.spawn(updateEspBeamsThrottled) end else cleanupAllEsp() end
    end},
    
    {Name = "ESP Distance", Key = "ESPDistance", Type = "Toggle", Action = function(val)
        if Config.ESP and not Engine.ESPUpdateRunning then task.spawn(updateEspBeamsThrottled) end
    end},
    
    {Name = "Anti-Void", Key = "AntiVoid", Type = "Toggle", Action = function(val)
        if Engine.AntiVoidConnection then Engine.AntiVoidConnection:Disconnect(); Engine.AntiVoidConnection = nil end
        if val then
            Engine.AntiVoidConnection = RunService.Heartbeat:Connect(function()
                local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                if root and root.Position.Y < VOID_THRESHOLD then
                    pcall(function() root.CFrame = CFrame.new(root.Position + Vector3.new(0, VOID_TELEPORT_HEIGHT - root.Position.Y, 0)) end)
                end
            end)
        end
    end},
    
    {Name = "Teleport HUD", Key = "TeleportHUD", Type = "Toggle", Action = nil},
    {Name = "Speed Lock", Key = "SpeedLock", Type = "Toggle", Action = nil},
    {Name = "Bypass Fire", Key = "BypassFire", Type = "Toggle", Action = function(val)
        if not val then
            for obj, data in pairs(Engine.HiddenFires) do if obj then pcall(function() obj.Parent = data.Parent end) end end
            table.clear(Engine.HiddenFires)
        end
    end},
    {Name = "Search Aura", Key = "SearchAura", Type = "Toggle", Action = nil},
    {Name = "Anti-Freeze", Key = "AntiFreeze", Type = "Toggle", Action = nil}
}


-- ================= 9. UI THEME ENGINE & FACTORY =================
local activeScreenGui, activeTpButton = nil, nil
local isBuildingUI = false
local isMinimized = false

local THEMES = {
    Dark = { BG = Color3.fromRGB(30, 30, 35), SecBG = Color3.fromRGB(45, 45, 50), Border = Color3.fromRGB(60, 60, 65), Text = Color3.fromRGB(240, 240, 240), Accent = Color3.fromRGB(0, 210, 150) },
    Light = { BG = Color3.fromRGB(240, 240, 245), SecBG = Color3.fromRGB(220, 220, 225), Border = Color3.fromRGB(180, 180, 185), Text = Color3.fromRGB(30, 30, 30), Accent = Color3.fromRGB(0, 120, 255) },
    Red = { BG = Color3.fromRGB(25, 15, 15), SecBG = Color3.fromRGB(45, 25, 25), Border = Color3.fromRGB(80, 30, 30), Text = Color3.fromRGB(255, 220, 220), Accent = Color3.fromRGB(255, 60, 60) },
    Blue = { BG = Color3.fromRGB(15, 20, 35), SecBG = Color3.fromRGB(25, 35, 55), Border = Color3.fromRGB(40, 60, 90), Text = Color3.fromRGB(220, 235, 255), Accent = Color3.fromRGB(60, 160, 255) }
}

-- Registry to instantly tween all components on theme change
local ThemeRegistry = { Backgrounds = {}, SecBackgrounds = {}, Texts = {}, Strokes = {}, Toggles = {} }

local function ApplyTheme(themeName)
    if not THEMES[themeName] then themeName = "Dark" end
    local T = THEMES[themeName]
    
    for _, obj in ipairs(ThemeRegistry.Backgrounds) do if obj.Parent then Tween(obj, {BackgroundColor3 = T.BG}, 0.3) end end
    for _, obj in ipairs(ThemeRegistry.SecBackgrounds) do if obj.Parent then Tween(obj, {BackgroundColor3 = T.SecBG}, 0.3) end end
    for _, obj in ipairs(ThemeRegistry.Texts) do if obj.Parent then Tween(obj, {TextColor3 = T.Text}, 0.3) end end
    for _, obj in ipairs(ThemeRegistry.Strokes) do if obj.Parent then Tween(obj, {Color = T.Border}, 0.3) end end
    
    for _, tog in ipairs(ThemeRegistry.Toggles) do
        if not tog.Pill.Parent then continue end
        if Config[tog.Key] then Tween(tog.Pill, {BackgroundColor3 = T.Accent}, 0.3)
        else Tween(tog.Pill, {BackgroundColor3 = T.SecBG}, 0.3) end
    end
    
    -- Specific override for Toggle UI Button to match accent
    local summonBtn = activeScreenGui and activeScreenGui:FindFirstChild("ToggleButton")
    if summonBtn then Tween(summonBtn, {BackgroundColor3 = T.Accent, TextColor3 = Color3.fromRGB(255,255,255)}, 0.3) end
end

local function BuildUI()
    local guiParent = (gethui and gethui()) or game:GetService("CoreGui") or playerGui
    for _, child in ipairs(guiParent:GetChildren()) do
        if string.match(child.Name, "^OWP_PetaHub") then pcall(function() child:Destroy() end) end
    end
    
    -- Reset Registry
    ThemeRegistry = { Backgrounds = {}, SecBackgrounds = {}, Texts = {}, Strokes = {}, Toggles = {} }

    local screenGui = Instance.new("ScreenGui", guiParent)
    screenGui.Name = GUI_NAME
    screenGui.ResetOnSpawn = false

    -- [PREMIUM LOADER] Only runs once per execution
    if not _G.OWP_LoaderPlayed then
        local loader = Instance.new("Frame", screenGui)
        loader.Size = UDim2.new(1, 0, 1, 0)
        loader.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
        loader.ZIndex = 9999
        
        local loaderText = Instance.new("TextLabel", loader)
        loaderText.Size = UDim2.new(1, 0, 1, 0)
        loaderText.BackgroundTransparency = 1
        loaderText.Text = "PETAPETA: School of Nightmares\nBy: OTHERWISEPOP"
        loaderText.TextColor3 = Color3.fromRGB(255, 255, 255)
        loaderText.Font = FONT_BOLD
        loaderText.TextSize = 24
        
        task.spawn(function()
            task.wait(4)
            Tween(loaderText, {TextTransparency = 1}, 1)
            local fade = Tween(loader, {BackgroundTransparency = 1}, 1)
            fade.Completed:Wait()
            loader:Destroy()
            _G.OWP_LoaderPlayed = true
        end)
    end

    -- 1. Summon Button (Top Left)
    local toggleButton = Instance.new("TextButton", screenGui)
    toggleButton.Name = "ToggleButton"
    toggleButton.Size = UDim2.new(0, 90, 0, 35)
    toggleButton.Position = UDim2.new(0, 15, 0, 15)
    toggleButton.Text = "OWP HUB"
    toggleButton.Font = FONT_BOLD
    toggleButton.TextSize = 14
    toggleButton.Draggable = true
    Instance.new("UICorner", toggleButton).CornerRadius = UDim.new(0, 8)

    -- 2. Teleport Action HUD
    local tpButton = Instance.new("TextButton", screenGui)
    tpButton.Name = "TPHUDButton"
    tpButton.Size = UDim2.new(0, 140, 0, 35)
    tpButton.Position = UDim2.new(0, 15, 0, 60) 
    tpButton.BackgroundColor3 = COLOR_SECONDARY_BG
    tpButton.TextColor3 = COLOR_ACCENT_GREEN
    tpButton.Font = FONT_BOLD
    tpButton.TextSize = 14
    tpButton.Text = "Teleport To Key"
    tpButton.Visible = Config.TeleportHUD
    tpButton.Draggable = true
    Instance.new("UICorner", tpButton).CornerRadius = UDim.new(0, 8)
    local tpStroke = Instance.new("UIStroke", tpButton); tpStroke.Thickness = 2
    table.insert(ThemeRegistry.SecBackgrounds, tpButton)
    table.insert(ThemeRegistry.Strokes, tpStroke)

    -- 3. Main Window Frame
    local mainFrame = Instance.new("Frame", screenGui)
    mainFrame.Size = UDim2.new(0, 260, 0, 420)
    mainFrame.Position = UDim2.new(0.5, -130, 0.1, 0)
    mainFrame.Visible = Config.GuiVisible
    mainFrame.ClipsDescendants = true -- Required for Minimize animation
    mainFrame.Active = true
    mainFrame.Draggable = true
    Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 10)
    local mainStroke = Instance.new("UIStroke", mainFrame); mainStroke.Thickness = 2
    table.insert(ThemeRegistry.Backgrounds, mainFrame)
    table.insert(ThemeRegistry.Strokes, mainStroke)

    -- 4. Header Bar
    local header = Instance.new("Frame", mainFrame)
    header.Size = UDim2.new(1, 0, 0, 40)
    header.BackgroundTransparency = 1
    
    local title = Instance.new("TextLabel", header)
    title.Size = UDim2.new(1, -70, 1, 0)
    title.Position = UDim2.new(0, 15, 0, 0)
    title.BackgroundTransparency = 1
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = "OWP HUB"
    title.Font = FONT_BOLD
    title.TextSize = 16
    table.insert(ThemeRegistry.Texts, title)

    -- Window Controls
    local minBtn = Instance.new("TextButton", header)
    minBtn.Size = UDim2.new(0, 30, 0, 30)
    minBtn.Position = UDim2.new(1, -65, 0, 5)
    minBtn.BackgroundTransparency = 1
    minBtn.Text = "—"
    minBtn.Font = FONT_BOLD
    minBtn.TextSize = 18
    table.insert(ThemeRegistry.Texts, minBtn)

    local closeBtn = Instance.new("TextButton", header)
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -35, 0, 5)
    closeBtn.BackgroundTransparency = 1
    closeBtn.Text = "X"
    closeBtn.Font = FONT_BOLD
    closeBtn.TextSize = 18
    table.insert(ThemeRegistry.Texts, closeBtn)

    -- 5. Scrolling Content
    local scrollFrame = Instance.new("ScrollingFrame", mainFrame)
    scrollFrame.Size = UDim2.new(1, 0, 1, -90) -- Leaves 40 for header, 50 for footer
    scrollFrame.Position = UDim2.new(0, 0, 0, 40)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.ScrollBarThickness = 2
    scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    
    local layout = Instance.new("UIListLayout", scrollFrame)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 8)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    Instance.new("UIPadding", scrollFrame).PaddingTop = UDim.new(0, 5)

    -- Feature Row Builder (The Sliding Switch)
    local function CreateRow(feature, order)
        local row = Instance.new("Frame", scrollFrame)
        row.Size = UDim2.new(1, -30, 0, 36)
        row.BackgroundTransparency = 1
        row.LayoutOrder = order

        local label = Instance.new("TextLabel", row)
        label.Size = UDim2.new(0.6, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Text = feature.Name
        label.Font = FONT_SEMIBOLD
        label.TextSize = 14
        table.insert(ThemeRegistry.Texts, label)

        if feature.Type == "Toggle" then
            -- Sliding Pill Container
            local pill = Instance.new("TextButton", row)
            pill.Size = UDim2.new(0, 44, 0, 22)
            pill.Position = UDim2.new(1, -44, 0.5, -11)
            pill.Text = ""
            Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)
            
            -- Inner Knob
            local knob = Instance.new("Frame", pill)
            knob.Size = UDim2.new(0, 18, 0, 18)
            knob.AnchorPoint = Vector2.new(0, 0.5)
            knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

            table.insert(ThemeRegistry.Toggles, {Pill = pill, Knob = knob, Key = feature.Key})

            local function updateToggleVisual()
                if Config[feature.Key] then
                    Tween(knob, {Position = UDim2.new(1, -20, 0.5, 0)}, 0.25)
                    Tween(pill, {BackgroundColor3 = THEMES[Config.Theme].Accent}, 0.25)
                else
                    Tween(knob, {Position = UDim2.new(0, 2, 0.5, 0)}, 0.25)
                    Tween(pill, {BackgroundColor3 = THEMES[Config.Theme].SecBG}, 0.25)
                end
            end
            feature._updateVisuals = updateToggleVisual

            pill.MouseButton1Click:Connect(function()
                Config[feature.Key] = not Config[feature.Key]
                updateToggleVisual()
                if feature.Action then feature.Action(Config[feature.Key]) end
                SaveConfig()
                if feature.Key == "TeleportHUD" and activeTpButton then activeTpButton.Visible = Config.TeleportHUD end
            end)
            updateToggleVisual()

        elseif feature.Type == "Cycle" then
            -- Interactive Number Pill
            local pill = Instance.new("TextButton", row)
            pill.Size = UDim2.new(0, 50, 0, 24)
            pill.Position = UDim2.new(1, -50, 0.5, -12)
            pill.Font = FONT_BOLD
            pill.TextSize = 14
            Instance.new("UICorner", pill).CornerRadius = UDim.new(0, 6)
            table.insert(ThemeRegistry.SecBackgrounds, pill)
            table.insert(ThemeRegistry.Texts, pill)

            local function updateCycleVisual()
                pill.Text = tostring(feature.CycleOptions[Config[feature.Key]])
            end
            feature._updateVisuals = updateCycleVisual

            pill.MouseButton1Click:Connect(function()
                -- Pulse Animation
                Tween(pill, {Size = UDim2.new(0, 45, 0, 20), Position = UDim2.new(1, -47, 0.5, -10)}, 0.1).Completed:Wait()
                
                Config[feature.Key] = (Config[feature.Key] % #feature.CycleOptions) + 1
                updateCycleVisual()
                if feature.Action then feature.Action(Config[feature.Key]) end
                SaveConfig()
                
                -- Pop Back
                Tween(pill, {Size = UDim2.new(0, 50, 0, 24), Position = UDim2.new(1, -50, 0.5, -12), BackgroundColor3 = THEMES[Config.Theme].Accent}, 0.1).Completed:Wait()
                Tween(pill, {BackgroundColor3 = THEMES[Config.Theme].SecBG}, 0.3)
            end)
            updateCycleVisual()
        end
    end

    for order, feature in ipairs(FeatureList) do CreateRow(feature, order) end

    -- 6. Theme Selector Footer
    local footer = Instance.new("Frame", mainFrame)
    footer.Size = UDim2.new(1, 0, 0, 50)
    footer.Position = UDim2.new(0, 0, 1, -50)
    footer.BackgroundTransparency = 1

    local themeLayout = Instance.new("UIListLayout", footer)
    themeLayout.FillDirection = Enum.FillDirection.Horizontal
    themeLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    themeLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    themeLayout.Padding = UDim.new(0, 15)

    for themeName, colors in pairs(THEMES) do
        local btn = Instance.new("TextButton", footer)
        btn.Size = UDim2.new(0, 20, 0, 20)
        btn.Text = ""
        btn.BackgroundColor3 = colors.Accent
        Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)
        
        btn.MouseButton1Click:Connect(function()
            Config.Theme = themeName
            ApplyTheme(themeName)
            SaveConfig()
        end)
    end

    -- 7. Window Control Actions
    toggleButton.MouseButton1Click:Connect(function()
        Config.GuiVisible = not Config.GuiVisible
        if Config.GuiVisible then
            mainFrame.Size = UDim2.new(0, 260, 0, 0)
            mainFrame.Visible = true
            Tween(mainFrame, {Size = UDim2.new(0, 260, 0, 420)}, 0.3)
        else
            Tween(mainFrame, {Size = UDim2.new(0, 260, 0, 0)}, 0.3).Completed:Connect(function()
                mainFrame.Visible = false
            end)
        end
        SaveConfig()
    end)

    closeBtn.MouseButton1Click:Connect(function()
        Config.GuiVisible = false
        Tween(mainFrame, {Size = UDim2.new(0, 260, 0, 0)}, 0.3).Completed:Connect(function()
            mainFrame.Visible = false
        end)
        SaveConfig()
    end)

    minBtn.MouseButton1Click:Connect(function()
        isMinimized = not isMinimized
        if isMinimized then
            Tween(mainFrame, {Size = UDim2.new(0, 260, 0, 40)}, 0.3)
        else
            Tween(mainFrame, {Size = UDim2.new(0, 260, 0, 420)}, 0.3)
        end
    end)

    activeScreenGui = screenGui
    activeTpButton = tpButton
    
    -- Initialize the final theme
    ApplyTheme(Config.Theme)
end

-- ================= 10. Initialization, Failsafes & Hooks =================

if not isBuildingUI then
    isBuildingUI = true
    pcall(BuildUI)
    isBuildingUI = false
end

-- Fire initial actions silently without triggering UI rebuilding
for _, feature in ipairs(FeatureList) do
    if feature.Action and (Config[feature.Key] == true or feature.Type == "Cycle") then
        feature.Action(Config[feature.Key])
    end
end

-- Watchdog
local uiMissingTime = 0
local lastBuildTime = 0
task.spawn(function()
    while task.wait(1) do
        if not activeScreenGui or not activeScreenGui.Parent then
            uiMissingTime = uiMissingTime + 1
            if not isBuildingUI and (tick() - lastBuildTime > 2) then
                isBuildingUI = true
                lastBuildTime = tick()
                pcall(BuildUI)
                isBuildingUI = false
            end
            if uiMissingTime >= 5 then
                if Engine.NoClipConnection then 
                    Engine.NoClipConnection:Disconnect()
                    Engine.NoClipConnection = nil 
                    if player.Character then
                        for _, p in ipairs(player.Character:GetDescendants()) do
                            if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then pcall(function() p.CanCollide = true end) end
                        end
                    end
                    uiMissingTime = -9999
                end
            end
        else
            uiMissingTime = 0
        end
    end
end)

-- TP HUD Background Updater
task.spawn(function()
    while task.wait(0.1) do
        if not Config.TeleportHUD or not activeTpButton or not activeTpButton.Parent or isBuildingUI then continue end
        
        local newState, newColor
        if tick() < Engine.TPWarningEnd then newState, newColor = Engine.TPWarningText, STATUS_RED
        elseif isPlayerHoldingAnyKey() then newState, newColor = "TP: Item Held", STATUS_CYAN
        elseif tick() < Engine.TPCooldownEnd then newState, newColor = "TP Cooldown: " .. math.ceil(Engine.TPCooldownEnd - tick()) .. "s", STATUS_YELLOW
        else newState, newColor = "Teleport To Key", STATUS_GREEN end
        
        if activeTpButton.Text ~= newState then
            activeTpButton.Text = newState
            activeTpButton.TextColor3 = newColor
        end
    end
end)

-- TP Action Logic (Wired directly to the activeTpButton component dynamically generated by Watchdog)
task.spawn(function()
    while task.wait(1) do
        if activeTpButton and not getattr(activeTpButton, "_tpConnectionSet") then
            -- Safe injection using custom property to avoid double bindings on rebuild
            setfenv(1, setmetatable({getattr = function(obj, key) return rawget(obj, key) end}, {__index = getfenv(1)}))
            pcall(function() rawset(activeTpButton, "_tpConnectionSet", true) end)
            
            activeTpButton.MouseButton1Click:Connect(function()
                if tick() < Engine.TPCooldownEnd or tick() < Engine.TPWarningEnd then return end
                if isPlayerHoldingAnyKey() then
                    Engine.TPWarningText, Engine.TPWarningEnd = "❌ Clear Hands!", tick() + 1.5
                    return
                end
                local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                if not root then Engine.TPWarningText, Engine.TPWarningEnd = "❌ Not Ready", tick() + 1.5; return end

                local closestKey, closestPos, minDistance = nil, nil, math.huge
                for _, obj in ipairs(GetDictKeys(Engine.Cache.Keys)) do
                    if isItemOnGround(obj) then
                        local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
                        if part then
                            local pos = part.Position
                            if isWithinRelativeBounds(pos, root.Position) then
                                local dist = (pos - root.Position).Magnitude
                                if dist < minDistance then
                                    minDistance = dist
                                    closestKey = obj
                                    closestPos = pos
                                end
                            end
                        end
                    end
                end

                if closestKey and closestPos then
                    pcall(function() root.CFrame = CFrame.new(closestPos + Vector3.new(0, TELEPORT_VERTICAL_OFFSET, 0)) * root.CFrame.Rotation end)
                    Engine.TPCooldownEnd = tick() + TELEPORT_COOLDOWN
                else
                    Engine.TPWarningText, Engine.TPWarningEnd = "❌ No Keys Found", tick() + 1.5
                end
            end)
        end
    end
end)

player.CharacterAdded:Connect(function(newCharacter)
    cleanupAllEsp()
    if Config.ESP and not Engine.ESPUpdateRunning then task.spawn(updateEspBeamsThrottled) end
    Engine.TPCooldownEnd, Engine.TPWarningEnd = 0, 0
    
    local hum = newCharacter:WaitForChild("Humanoid", 5)
    for _, feature in ipairs(FeatureList) do
        if feature.OnCharacterAdded then
            feature.OnCharacterAdded(newCharacter, hum)
            if feature._updateVisuals then feature._updateVisuals() end
        end
    end
end)

print("✅ PETAPETA: School of Nightmares V15.0 (Phase 4: Premium UI & Theme Engine) - Loaded")
