-- ================= 0. SINGLETON CHECK & AUTO-QUEUE =================
if _G.OWP_Hub_Running then return end
_G.OWP_Hub_Running = true

local SCRIPT_URL = "https://raw.githubusercontent.com/OWpop/jubilant-doodle/main/main.lua"
if queue_on_teleport then
    queue_on_teleport('loadstring(game:HttpGet("' .. SCRIPT_URL .. '?t="..tostring(tick())))()')
end

--[[
    PETAPETA: School of Nightmares V14.6.1 (Phase 4: Premium UI + FullBright Patch)
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

local player = Players.LocalPlayer
if not player then
	repeat task.wait() until Players.LocalPlayer
	player = Players.LocalPlayer
end
local playerGui = player:WaitForChild("PlayerGui")

local GUI_NAME = "OWP_PetaHub_V14_6_" .. tostring(math.random(10000, 99999))
local CONFIG_FILE_NAME = "OWP_PetaHub_Config.json"

-- Premium Typography & Aesthetics
local FONT_BOLD = Enum.Font.GothamBold
local CORNER_RADIUS = UDim.new(0, 8)
local STROKE_THICKNESS = 1.2

-- Dynamic Theme Palettes
local THEMES = {
    { -- 1: Dark (Default)
        Name = "Dark",
        PrimaryBg = Color3.fromRGB(20, 20, 20),
        SecondaryBg = Color3.fromRGB(35, 35, 35),
        Border = Color3.fromRGB(60, 60, 60),
        Text = Color3.fromRGB(255, 255, 255),
        AccentCyan = Color3.fromRGB(0, 200, 255),
        AccentGreen = Color3.fromRGB(46, 204, 113),
        AccentYellow = Color3.fromRGB(241, 196, 15),
        AccentRed = Color3.fromRGB(231, 76, 60),
    },
    { -- 2: Light
        Name = "Light",
        PrimaryBg = Color3.fromRGB(245, 245, 245),
        SecondaryBg = Color3.fromRGB(225, 225, 225),
        Border = Color3.fromRGB(180, 180, 180),
        Text = Color3.fromRGB(30, 30, 30),
        AccentCyan = Color3.fromRGB(0, 150, 200),
        AccentGreen = Color3.fromRGB(39, 174, 96),
        AccentYellow = Color3.fromRGB(212, 172, 13),
        AccentRed = Color3.fromRGB(192, 57, 43),
    },
    { -- 3: Blood
        Name = "Blood",
        PrimaryBg = Color3.fromRGB(15, 5, 5),
        SecondaryBg = Color3.fromRGB(30, 10, 10),
        Border = Color3.fromRGB(80, 20, 20),
        Text = Color3.fromRGB(255, 200, 200),
        AccentCyan = Color3.fromRGB(100, 200, 255),
        AccentGreen = Color3.fromRGB(46, 204, 113),
        AccentYellow = Color3.fromRGB(241, 196, 15),
        AccentRed = Color3.fromRGB(255, 50, 50),
    },
    { -- 4: Ocean
        Name = "Ocean",
        PrimaryBg = Color3.fromRGB(5, 10, 20),
        SecondaryBg = Color3.fromRGB(15, 25, 40),
        Border = Color3.fromRGB(30, 50, 80),
        Text = Color3.fromRGB(200, 230, 255),
        AccentCyan = Color3.fromRGB(0, 255, 255),
        AccentGreen = Color3.fromRGB(46, 204, 113),
        AccentYellow = Color3.fromRGB(241, 196, 15),
        AccentRed = Color3.fromRGB(231, 76, 60),
    }
}

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

-- ================= 2. Centralized State =================
local Config = {
    GuiVisible = false,
    ThemeIndex = 1,
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
    ESPBeams = {}, ESPAttachments = {}, ESPConnections = {},
    ESPUpdateRunning = false,
    NoClipConnection = nil, FullBrightConnection = nil,
    AntiVoidConnection = nil, AntiFreezeConnection = nil,
    SpeedEnforceRunning = false, SpeedEnforceCancelTime = 0,
    HiddenFires = {}, 
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
                        if k == "ThemeIndex" and (v < 1 or v > #THEMES) then continue end
                        Config[k] = v
                    end
                end
            end
        end
    end
    -- Force GUI closed on startup for the open animation
    Config.GuiVisible = false
end

local function SaveConfig()
    if not writefile then return end
    pcall(function() writefile(CONFIG_FILE_NAME, HttpService:JSONEncode(Config)) end)
end

LoadConfig()

-- ================= 4. Helper Functions =================
local function GetDictKeys(dict)
    local keys = {}
    for k in pairs(dict) do table.insert(keys, k) end
    return keys
end

local function isPlayerHoldingAnyKey()
    local function scanForKeywords(container)
        if not container then return false end
        for _, obj in ipairs(container:GetDescendants()) do
            if obj:IsA("Tool") or obj:IsA("Model") or obj:IsA("BasePart") then
                local lowerName = obj.Name:lower()
                for _, targetName in ipairs(IMPORTANT_ITEM_NAMES) do
                    if string.find(lowerName, targetName:lower()) then return true end
                end
                if string.find(lowerName, "key") then return true end
            end
        end
        return false
    end
    if scanForKeywords(player.Character) then return true end
    if scanForKeywords(player.Backpack) then return true end
    if Workspace.CurrentCamera and scanForKeywords(Workspace.CurrentCamera) then return true end
    
    if player.Character then
        for _, child in ipairs(player.Character:GetChildren()) do
            if child:IsA("Tool") then return true end
        end
    end
    return false
end

local function isItemOnGround(obj)
	if not obj then return false end
	if not obj:IsDescendantOf(Workspace) then return false end
	local parent = obj.Parent
	while parent and parent ~= Workspace do
		if parent:IsA("Model") and parent:FindFirstChild("Humanoid") then return false end
		parent = parent.Parent
	end
	if Workspace.CurrentCamera and obj:IsDescendantOf(Workspace.CurrentCamera) then return false end
	return true
end

local function isWithinRelativeBounds(targetPos, playerPos)
    local offset = targetPos - playerPos
    if math.abs(offset.Y) > RELATIVE_Y_BOUND then return false end
    if math.abs(offset.X) > RELATIVE_XZ_BOUND then return false end
    if math.abs(offset.Z) > RELATIVE_XZ_BOUND then return false end
    return true
end

-- ================= 5. Master Cache System =================
local function CheckFireText(obj, text)
    if not text then return end
    text = text:lower()
    if string.find(text, "fire") or string.find(text, "extinguish") or string.find(text, "flame") then Engine.Cache.Fires[obj] = true end
end

local function CategorizeObject(obj)
    local cls = obj.ClassName
    local lowerName = obj.Name:lower()
    
    if cls == "ProximityPrompt" then
        local action, name, object = obj.ActionText:lower(), lowerName, obj.ObjectText:lower()
        if string.find(action, "search") or string.find(name, "search") then Engine.Cache.Prompts[obj] = true end
        CheckFireText(obj, action); CheckFireText(obj, object)

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
    for _, n in ipairs(IMPORTANT_ITEM_NAMES) do
        if string.find(lowerName, n:lower()) then isKey = true; break end
    end
    if not isKey and string.find(lowerName, "key") then isKey = true end
    if isKey and (cls == "Tool" or cls == "Model" or obj:IsA("BasePart")) then Engine.Cache.Keys[obj] = true end
    if string.find(lowerName, "fire") or string.find(lowerName, "extinguish") or string.find(lowerName, "flame") then Engine.Cache.Fires[obj] = true end
end

for _, obj in ipairs(Workspace:GetDescendants()) do CategorizeObject(obj) end
Workspace.DescendantAdded:Connect(CategorizeObject)

Workspace.DescendantRemoving:Connect(function(obj)
    Engine.Cache.Keys[obj] = nil; Engine.Cache.Fires[obj] = nil; Engine.Cache.Prompts[obj] = nil
end)

-- ================= 6. Core Logic Functions =================
local function cleanEspForItem(obj)
	if not obj then return end
	if Engine.ESPBeams[obj] then Engine.ESPBeams[obj]:Destroy(); Engine.ESPBeams[obj] = nil end
	if Engine.ESPAttachments[obj] then Engine.ESPAttachments[obj]:Destroy(); Engine.ESPAttachments[obj] = nil end
	if Engine.ESPConnections[obj] then
		for _, conn in ipairs(Engine.ESPConnections[obj]) do conn:Disconnect() end
		Engine.ESPConnections[obj] = nil
	end
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
        originAttach = Instance.new("Attachment", root)
        originAttach.Name = "OWP_OriginAttach"
    end

	local targetAttach = Instance.new("Attachment", adornee)
	local beam = Instance.new("Beam")
	beam.Attachment0 = originAttach; beam.Attachment1 = targetAttach; beam.Width0 = 0.1; beam.Width1 = 0.1; beam.FaceCamera = true
    
    local t = THEMES[Config.ThemeIndex] or THEMES[1]
	beam.Color = ColorSequence.new(Config.FullBright and t.AccentCyan or t.AccentGreen)
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
    local char = player.Character
    local hum = char and char:FindFirstChild("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    
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
        if Config.BypassFire then 
            for _, obj in ipairs(GetDictKeys(Engine.Cache.Fires)) do
                if obj and obj.Parent then pcall(hideFire, obj) end
            end
        end
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

-- ================= 8. Premium UI Generation & Theme Registry =================
local activeScreenGui = nil
local activeTpButton = nil
local isBuildingUI = false

local function BuildUI()
    local guiParent = (gethui and gethui()) or game:GetService("CoreGui") or playerGui
    for _, child in ipairs(guiParent:GetChildren()) do
        if string.match(child.Name, "^OWP_PetaHub") then pcall(function() child:Destroy() end) end
    end

    local screenGui = Instance.new("ScreenGui", guiParent)
    screenGui.Name = GUI_NAME
    screenGui.ResetOnSpawn = false

    -- Loading Screen Logic
    if not _G.OWP_HasLoaded then
        local loadFrame = Instance.new("Frame", screenGui)
        loadFrame.Size = UDim2.new(1, 0, 1, 0)
        loadFrame.BackgroundColor3 = Color3.new(0, 0, 0)
        loadFrame.BackgroundTransparency = 0.3
        loadFrame.ZIndex = 9999
        
        local loadText = Instance.new("TextLabel", loadFrame)
        loadText.Size = UDim2.new(1, 0, 1, 0)
        loadText.BackgroundTransparency = 1
        loadText.Font = FONT_BOLD
        loadText.Text = "PETAPETA HUB"
        loadText.TextColor3 = Color3.new(1, 1, 1)
        loadText.TextSize = 24
        
        task.spawn(function()
            local ti = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
            TweenService:Create(loadText, ti, {TextTransparency = 0.5}):Play()
            
            task.wait(1.5)
            local fadeInfo = TweenInfo.new(0.5)
            TweenService:Create(loadFrame, fadeInfo, {BackgroundTransparency = 1}):Play()
            local fadeText = TweenService:Create(loadText, fadeInfo, {TextTransparency = 1})
            fadeText:Play()
            fadeText.Completed:Wait()
            loadFrame:Destroy()
            _G.OWP_HasLoaded = true
        end)
    end

    -- Theme Registry 
    local ThemeRegistry = {}
    local function RegisterTheme(element, property, themeKey)
        table.insert(ThemeRegistry, {Element = element, Property = property, ThemeKey = themeKey})
    end

    local function ApplyTheme(index)
        local t = THEMES[index] or THEMES[1]
        for _, entry in ipairs(ThemeRegistry) do
            if entry.Element and entry.Element.Parent then
                pcall(function()
                    TweenService:Create(entry.Element, TweenInfo.new(0.3), {[entry.Property] = t[entry.ThemeKey]}):Play()
                end)
            end
        end
        for _, beam in pairs(Engine.ESPBeams) do
            if beam and beam.Parent then
                beam.Color = ColorSequence.new(Config.FullBright and t.AccentCyan or t.AccentGreen)
            end
        end
    end

    local function RoundAndStroke(element, isMainFrame)
        local corner = Instance.new("UICorner", element)
        corner.CornerRadius = CORNER_RADIUS
        
        local stroke = Instance.new("UIStroke", element)
        stroke.Thickness = STROKE_THICKNESS
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        RegisterTheme(stroke, "Color", "Border")
    end

    local toggleButton = Instance.new("TextButton", screenGui)
    toggleButton.Size = UDim2.new(0, 90, 0, 34)
    toggleButton.Position = UDim2.new(0, 10, 0, 10)
    toggleButton.Text = "OWP HUB"
    toggleButton.Font = FONT_BOLD
    toggleButton.TextSize = 14
    toggleButton.Draggable = true
    RoundAndStroke(toggleButton)
    RegisterTheme(toggleButton, "BackgroundColor3", "PrimaryBg")
    RegisterTheme(toggleButton, "TextColor3", "Text")

    local tpButton = Instance.new("TextButton", screenGui)
    tpButton.Size = UDim2.new(0, 120, 0, 34)
    tpButton.Position = UDim2.new(0, 10, 0, 52) 
    tpButton.Font = FONT_BOLD
    tpButton.TextSize = 14
    tpButton.Text = "Teleport To Key"
    tpButton.Visible = Config.TeleportHUD
    tpButton.Draggable = true
    RoundAndStroke(tpButton)
    RegisterTheme(tpButton, "BackgroundColor3", "SecondaryBg")

    local mainFrame = Instance.new("CanvasGroup", screenGui)
    mainFrame.Size = UDim2.new(0, 240, 0, 350)
    mainFrame.Position = UDim2.new(0.5, -120, 0.1, 0)
    mainFrame.GroupTransparency = Config.GuiVisible and 0 or 1
    mainFrame.Visible = Config.GuiVisible
    mainFrame.Draggable = true
    RoundAndStroke(mainFrame, true)
    RegisterTheme(mainFrame, "BackgroundColor3", "PrimaryBg")

    local scrollFrame = Instance.new("ScrollingFrame", mainFrame)
    scrollFrame.Size = UDim2.new(1, 0, 1, -25)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.ScrollBarThickness = 3
    scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y

    local uiListLayout = Instance.new("UIListLayout", scrollFrame)
    uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    uiListLayout.Padding = UDim.new(0, 8)
    uiListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    Instance.new("UIPadding", scrollFrame).PaddingTop = UDim.new(0, 10)

    local creditLabel = Instance.new("TextLabel", mainFrame)
    creditLabel.Size = UDim2.new(1, 0, 0, 20)
    creditLabel.Position = UDim2.new(0, 0, 1, -22)
    creditLabel.BackgroundTransparency = 1
    creditLabel.Font = FONT_BOLD
    creditLabel.TextSize = 11
    creditLabel.Text = "BY: OTHERWISEPOP"
    RegisterTheme(creditLabel, "TextColor3", "Text")

    local function CreateButton(feature, order)
        local btn = Instance.new("TextButton", scrollFrame)
        btn.Size = UDim2.new(1, -24, 0, 34)
        btn.LayoutOrder = order
        btn.Font = FONT_BOLD
        btn.TextSize = 13
        btn.AutoButtonColor = false 
        RoundAndStroke(btn)
        RegisterTheme(btn, "BackgroundColor3", "SecondaryBg")
        RegisterTheme(btn, "TextColor3", "Text")

        local function updateVisuals()
            if not btn.Parent then return end 
            if feature.Type == "Toggle" then
                btn.Text = feature.Name .. ": " .. (Config[feature.Key] and "ON" or "OFF")
            elseif feature.Type == "Cycle" then
                btn.Text = feature.Name .. ": " .. tostring(feature.CycleOptions[Config[feature.Key]])
            elseif feature.Type == "ThemeCycle" then
                btn.Text = feature.Name .. ": " .. THEMES[Config[feature.Key]].Name
            end
        end
        feature._updateVisuals = updateVisuals 

        btn.MouseEnter:Connect(function() TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundTransparency = 0.2}):Play() end)
        btn.MouseLeave:Connect(function() TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundTransparency = 0}):Play() end)
        btn.MouseButton1Down:Connect(function() TweenService:Create(btn, TweenInfo.new(0.1), {Size = UDim2.new(1, -30, 0, 32)}):Play() end)
        btn.MouseButton1Up:Connect(function() TweenService:Create(btn, TweenInfo.new(0.1), {Size = UDim2.new(1, -24, 0, 34)}):Play() end)

        btn.MouseButton1Click:Connect(function()
            if feature.Type == "Toggle" then
                Config[feature.Key] = not Config[feature.Key]
            elseif feature.Type == "Cycle" or feature.Type == "ThemeCycle" then
                Config[feature.Key] = (Config[feature.Key] % #(feature.Type == "ThemeCycle" and THEMES or feature.CycleOptions)) + 1
            end
            updateVisuals()
            if feature.Action then feature.Action(Config[feature.Key]) end
            SaveConfig()
            
            if feature.Key == "TeleportHUD" and activeTpButton then
                activeTpButton.Visible = Config.TeleportHUD
            end
        end)
        updateVisuals()
    end

    -- Feature Registration Passed into UI
    local FeatureList = {
        {Name = "Theme", Key = "ThemeIndex", Type = "ThemeCycle", Action = function(val) ApplyTheme(val) end},
        {Name = "Speed", Key = "SpeedIndex", Type = "Cycle", CycleOptions = WALK_SPEEDS, Action = function(val)
            Engine.SpeedEnforceCancelTime = tick() + ENFORCE_SPEED_DURATION
            Engine.SpeedEnforceRunning = true
        end, OnCharacterAdded = function(char, hum)
            if hum then hum.WalkSpeed = WALK_SPEEDS[Config.SpeedIndex] end
            Engine.SpeedEnforceCancelTime = tick() + ENFORCE_SPEED_DURATION
            Engine.SpeedEnforceRunning = true
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
        {Name = "Teleport HUD", Key = "TeleportHUD", Type = "Toggle", Action = function(val) if activeTpButton then activeTpButton.Visible = val end end},
        {Name = "Speed Lock", Key = "SpeedLock", Type = "Toggle", Action = nil},
        {Name = "Bypass Fire", Key = "BypassFire", Type = "Toggle", Action = function(val)
            if not val then
                for obj, data in pairs(Engine.HiddenFires) do
                    if obj then pcall(function() obj.Parent = data.Parent end) end
                end
                table.clear(Engine.HiddenFires)
            end
        end},
        {Name = "Search Aura", Key = "SearchAura", Type = "Toggle", Action = nil},
        {Name = "Anti-Freeze", Key = "AntiFreeze", Type = "Toggle", Action = nil}
    }
    _G.OWP_FeatureList = FeatureList

    for order, feature in ipairs(FeatureList) do CreateButton(feature, order) end

    -- Animated Menu Toggle
    local isAnimating = false
    toggleButton.MouseButton1Click:Connect(function()
        if isAnimating then return end
        isAnimating = true
        Config.GuiVisible = not Config.GuiVisible
        SaveConfig()

        if Config.GuiVisible then
            mainFrame.Visible = true
            mainFrame.GroupTransparency = 1
            mainFrame.Size = UDim2.new(0, 220, 0, 310) 
            local tween = TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                GroupTransparency = 0,
                Size = UDim2.new(0, 240, 0, 350)
            })
            tween:Play()
            tween.Completed:Wait()
        else
            local tween = TweenService:Create(mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                GroupTransparency = 1,
                Size = UDim2.new(0, 220, 0, 310)
            })
            tween:Play()
            tween.Completed:Wait()
            mainFrame.Visible = false
        end
        isAnimating = false
    end)

    tpButton.MouseButton1Click:Connect(function()
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
                        if dist < minDistance then minDistance, closestKey, closestPos = dist, obj, pos end
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

    activeScreenGui = screenGui
    activeTpButton = tpButton
    ApplyTheme(Config.ThemeIndex)
end

-- ================= 9. Initialization, Failsafes & Hooks =================

if not isBuildingUI then
    isBuildingUI = true
    pcall(BuildUI)
    isBuildingUI = false
end

local uiMissingTime = 0
local lastBuildTime = 0

task.spawn(function()
    while task.wait(1) do
        if not activeScreenGui or not activeScreenGui.Parent then
            uiMissingTime = uiMissingTime + 1
            if not isBuildingUI and (tick() - lastBuildTime > 2) then
                isBuildingUI = true
                lastBuildTime = tick()
                local s, e = pcall(BuildUI)
                if not s then warn("[OWP HUB] Rebuild Error: " .. tostring(e)) end
                isBuildingUI = false
            end
            if uiMissingTime >= 5 then
                if Engine.NoClipConnection then 
                    warn("[OWP HUB] Safety fallback: Suspending NoClip physics.")
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
        else uiMissingTime = 0 end
    end
end)

task.spawn(function()
    while task.wait(0.1) do
        if not Config.TeleportHUD or not activeTpButton or not activeTpButton.Parent or isBuildingUI then continue end
        local t = THEMES[Config.ThemeIndex] or THEMES[1]
        local newState, newColor
        
        if tick() < Engine.TPWarningEnd then
            newState, newColor = Engine.TPWarningText, t.AccentRed
        elseif isPlayerHoldingAnyKey() then
            newState, newColor = "TP: Item Held", t.AccentCyan
        elseif tick() < Engine.TPCooldownEnd then
            newState, newColor = "TP Cooldown: " .. math.ceil(Engine.TPCooldownEnd - tick()) .. "s", t.AccentYellow
        else
            newState, newColor = "Teleport To Key", t.AccentGreen
        end
        
        if activeTpButton.Text ~= newState then
            activeTpButton.Text = newState
            activeTpButton.TextColor3 = newColor
        end
    end
end)

for _, feature in ipairs(_G.OWP_FeatureList) do
    if feature.Action and feature.Type ~= "ThemeCycle" and feature.Key ~= "TeleportHUD" and (Config[feature.Key] == true or feature.Type == "Cycle") then
        feature.Action(Config[feature.Key])
    end
end

if not _G.OWP_CharAdded_Hooked then
    _G.OWP_CharAdded_Hooked = true
    player.CharacterAdded:Connect(function(newCharacter)
        cleanupAllEsp()
        if Config.ESP and not Engine.ESPUpdateRunning then task.spawn(updateEspBeamsThrottled) end
        Engine.TPCooldownEnd, Engine.TPWarningEnd = 0, 0
        local hum = newCharacter:WaitForChild("Humanoid", 5)
        for _, feature in ipairs(_G.OWP_FeatureList) do
            if feature.OnCharacterAdded then
                feature.OnCharacterAdded(newCharacter, hum)
                if feature._updateVisuals then feature._updateVisuals() end
            end
        end
    end)
end

print("✅ PETAPETA: School of Nightmares V14.6.1 (Phase 4: Premium UI + FullBright Patch) - Loaded")
