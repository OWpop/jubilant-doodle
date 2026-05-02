-- ================= 0. SINGLETON CHECK & AUTO-QUEUE =================
if _G.OWP_Hub_Running then return end
_G.OWP_Hub_Running = true

local SCRIPT_URL = "https://raw.githubusercontent.com/OWpop/jubilant-doodle/main/main.lua"
if queue_on_teleport then
    queue_on_teleport('loadstring(game:HttpGet("' .. SCRIPT_URL .. '?t="..tostring(tick())))()')
end

--[[
    PETAPETA: School of Nightmares V14.6 (Phase 4.1: The Shell & Loader)
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
local FONT_BOLD = Enum.Font.SourceSansBold

-- Colors
local COLOR_PRIMARY_BG = Color3.fromRGB(20, 20, 20)
local COLOR_SECONDARY_BG = Color3.fromRGB(35, 35, 35)
local COLOR_BORDER = Color3.fromRGB(60, 60, 60)
local COLOR_TEXT_LIGHT = Color3.fromRGB(255, 255, 255)
local COLOR_TEXT_DARK = Color3.fromRGB(0, 0, 0)
local COLOR_ACCENT_GREEN = Color3.fromRGB(0, 255, 0)
local COLOR_ACCENT_YELLOW = Color3.fromRGB(255, 255, 0)
local COLOR_ACCENT_RED = Color3.fromRGB(255, 50, 50)
local COLOR_ACCENT_CYAN = Color3.fromRGB(0, 200, 255)

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
    Cache = {
        Keys = {},
        Fires = {},
        Prompts = {}
    },
    ESPBeams = {},
    ESPAttachments = {},
    ESPConnections = {},
    ESPUpdateRunning = false,
    NoClipConnection = nil,
    FullBrightConnection = nil,
    AntiVoidConnection = nil,
    AntiFreezeConnection = nil,
    SpeedEnforceRunning = false,
    SpeedEnforceCancelTime = 0,
    HiddenFires = {}, 
    TPCooldownEnd = 0,
    TPWarningEnd = 0,
    TPWarningText = ""
}

local initialLighting = {
	Ambient = Lighting.Ambient,
	OutdoorAmbient = Lighting.OutdoorAmbient,
	Brightness = Lighting.Brightness,
	FogEnd = Lighting.FogEnd,
	GlobalShadows = Lighting.GlobalShadows,
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
    pcall(function()
        local json = HttpService:JSONEncode(Config)
        writefile(CONFIG_FILE_NAME, json)
    end)
end

LoadConfig()

-- CRITICAL FIX: Force UI closed on initial load so it animates in nicely
Config.GuiVisible = false

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
    if string.find(text, "fire") or string.find(text, "extinguish") or string.find(text, "flame") then
        Engine.Cache.Fires[obj] = true
    end
end

local function CategorizeObject(obj)
    local cls = obj.ClassName
    local lowerName = obj.Name:lower()
    
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
    Engine.Cache.Keys[obj] = nil
    Engine.Cache.Fires[obj] = nil
    Engine.Cache.Prompts[obj] = nil
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
	beam.Attachment0 = originAttach
	beam.Attachment1 = targetAttach
	beam.Width0 = 0.1
	beam.Width1 = 0.1
	beam.FaceCamera = true
	beam.Color = ColorSequence.new(Config.FullBright and COLOR_ACCENT_CYAN or COLOR_ACCENT_GREEN)
	beam.Transparency = NumberSequence.new(Config.FullBright and 0.1 or 0.3)
	beam.LightEmission = Config.FullBright and 0.6 or 0.35
	beam.Parent = Workspace:FindFirstChildOfClass("Terrain") or Workspace

	Engine.ESPBeams[obj] = beam
	Engine.ESPAttachments[obj] = targetAttach

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
                    if not isItemOnGround(adornee) or not isWithinRelativeBounds(adornee.Position, root.Position) then
                        isValid = false
                    elseif Config.ESPDistance and (adornee.Position - root.Position).Magnitude > MAX_ESP_DISTANCE then
                        isValid = false 
                    end
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
        if obj.Parent and obj.Parent:IsA("BasePart") and obj.Parent.Size.Magnitude <= 50 then
            target = obj.Parent
        end
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

-- ================= 8. Feature Registration List =================
-- Handled globally so loops/hooks keep working even if UI is not generated.
local FeatureList = {
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
        if Engine.NoClipConnection then 
            Engine.NoClipConnection:Disconnect() 
            Engine.NoClipConnection = nil 
        end
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
            for obj, data in pairs(Engine.HiddenFires) do
                if obj then pcall(function() obj.Parent = data.Parent end) end
            end
            table.clear(Engine.HiddenFires)
        end
    end},
    {Name = "Search Aura", Key = "SearchAura", Type = "Toggle", Action = nil},
    {Name = "Anti-Freeze", Key = "AntiFreeze", Type = "Toggle", Action = nil}
}


-- ================= 9. Modern Shell & Premium Loader (Phase 4.1) =================
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

    -- === THE PREMIUM LOADER ===
    local isFirstLoad = not _G.OWP_Loader_Played
    if isFirstLoad then
        _G.OWP_Loader_Played = true
        local loaderFrame = Instance.new("Frame", screenGui)
        loaderFrame.Size = UDim2.new(1, 0, 1, 0)
        loaderFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        loaderFrame.ZIndex = 1000

        local loaderText = Instance.new("TextLabel", loaderFrame)
        loaderText.Size = UDim2.new(1, 0, 1, 0)
        loaderText.BackgroundTransparency = 1
        loaderText.Text = "PETAPETA: School of Nightmares\nBy: OTHERWISEPOP"
        loaderText.TextColor3 = COLOR_TEXT_LIGHT
        loaderText.Font = FONT_BOLD
        loaderText.TextSize = 22
        loaderText.ZIndex = 1001

        task.spawn(function()
            task.wait(5)
            local fadeInfo = TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
            TweenService:Create(loaderFrame, fadeInfo, {BackgroundTransparency = 1}):Play()
            TweenService:Create(loaderText, fadeInfo, {TextTransparency = 1}):Play()
            task.wait(1)
            loaderFrame:Destroy()
        end)
    end

    -- === EXTERNAL BUTTONS ===
    local toggleButton = Instance.new("TextButton", screenGui)
    toggleButton.Size = UDim2.new(0, 80, 0, 30)
    toggleButton.Position = UDim2.new(0, 10, 0, 10)
    toggleButton.Text = "OWP HUB"
    toggleButton.BackgroundColor3 = COLOR_TEXT_DARK
    toggleButton.TextColor3 = COLOR_TEXT_LIGHT
    toggleButton.Font = FONT_BOLD
    toggleButton.TextScaled = true
    toggleButton.Draggable = true
    
    -- Hide toggle during loader
    if isFirstLoad then
        toggleButton.Visible = false
        task.spawn(function()
            task.wait(6)
            toggleButton.Visible = true
        end)
    end

    local tpButton = Instance.new("TextButton", screenGui)
    tpButton.Size = UDim2.new(0, 120, 0, 30)
    tpButton.Position = UDim2.new(0, 10, 0, 45) 
    tpButton.BackgroundColor3 = COLOR_SECONDARY_BG
    tpButton.TextColor3 = COLOR_ACCENT_GREEN
    tpButton.Font = FONT_BOLD
    tpButton.TextScaled = true
    tpButton.Text = "Teleport To Key"
    tpButton.Visible = Config.TeleportHUD and not isFirstLoad
    tpButton.Draggable = true
    
    if isFirstLoad and Config.TeleportHUD then
        task.spawn(function()
            task.wait(6)
            tpButton.Visible = true
        end)
    end

    -- === THE MODERN SHELL ===
    local mainFrame = Instance.new("Frame", screenGui)
    mainFrame.Size = UDim2.new(0, 260, 0, 360)
    
    -- Animation Off-screen state
    local hiddenPosition = UDim2.new(0.5, -130, 0.5, 50)
    local visiblePosition = UDim2.new(0.5, -130, 0.5, -180)
    
    mainFrame.Position = hiddenPosition
    mainFrame.BackgroundColor3 = COLOR_PRIMARY_BG
    mainFrame.BackgroundTransparency = 1 -- Start transparent for fade
    mainFrame.Visible = false
    mainFrame.Active = true
    mainFrame.Draggable = true

    -- Corners & Borders
    local corner = Instance.new("UICorner", mainFrame)
    corner.CornerRadius = UDim.new(0, 8)

    local stroke = Instance.new("UIStroke", mainFrame)
    stroke.Color = COLOR_BORDER
    stroke.Thickness = 2
    stroke.Transparency = 1 -- Start transparent

    -- Header Bar
    local header = Instance.new("Frame", mainFrame)
    header.Size = UDim2.new(1, 0, 0, 35)
    header.BackgroundTransparency = 1

    local title = Instance.new("TextLabel", header)
    title.Size = UDim2.new(1, -70, 1, 0)
    title.Position = UDim2.new(0, 10, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "PETAPETA: School of Nightmares\nBY: OtherWisePop"
    title.TextColor3 = COLOR_TEXT_LIGHT
    title.TextTransparency = 1
    title.Font = FONT_BOLD
    title.TextSize = 13
    title.TextXAlignment = Enum.TextXAlignment.Left

    -- Window Controls
    local minBtn = Instance.new("TextButton", header)
    minBtn.Size = UDim2.new(0, 25, 0, 25)
    minBtn.Position = UDim2.new(1, -60, 0, 5)
    minBtn.Text = "-"
    minBtn.TextTransparency = 1
    minBtn.BackgroundTransparency = 1
    minBtn.BackgroundColor3 = COLOR_SECONDARY_BG
    minBtn.TextColor3 = COLOR_TEXT_LIGHT
    Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 4)

    local closeBtn = Instance.new("TextButton", header)
    closeBtn.Size = UDim2.new(0, 25, 0, 25)
    closeBtn.Position = UDim2.new(1, -30, 0, 5)
    closeBtn.Text = "X"
    closeBtn.TextTransparency = 1
    closeBtn.BackgroundTransparency = 1
    closeBtn.BackgroundColor3 = COLOR_SECONDARY_BG
    closeBtn.TextColor3 = COLOR_ACCENT_RED
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 4)

    -- === ANIMATION LOGIC ===
    -- Helper to tween transparency of frame and its immediate styling descendants
    local function FadeShell(targetTransparency)
        local tInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        TweenService:Create(mainFrame, tInfo, {BackgroundTransparency = targetTransparency}):Play()
        TweenService:Create(stroke, tInfo, {Transparency = targetTransparency}):Play()
        TweenService:Create(title, tInfo, {TextTransparency = targetTransparency}):Play()
        TweenService:Create(minBtn, tInfo, {BackgroundTransparency = targetTransparency, TextTransparency = targetTransparency}):Play()
        TweenService:Create(closeBtn, tInfo, {BackgroundTransparency = targetTransparency, TextTransparency = targetTransparency}):Play()
    end

    local function OpenWindow()
        mainFrame.Visible = true
        mainFrame.Position = hiddenPosition
        FadeShell(0)
        TweenService:Create(mainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = visiblePosition}):Play()
    end

    local function CloseWindow(isDestroy)
        FadeShell(1)
        local slide = TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Position = hiddenPosition})
        slide:Play()
        slide.Completed:Connect(function()
            if not Config.GuiVisible then
                mainFrame.Visible = false
                if isDestroy then screenGui:Destroy() end
            end
        end)
    end

    -- Input Handling
    toggleButton.MouseButton1Click:Connect(function()
        Config.GuiVisible = not Config.GuiVisible
        if Config.GuiVisible then OpenWindow() else CloseWindow(false) end
        SaveConfig()
    end)

    minBtn.MouseButton1Click:Connect(function()
        Config.GuiVisible = false
        CloseWindow(false)
        SaveConfig()
    end)

    closeBtn.MouseButton1Click:Connect(function()
        Config.GuiVisible = false
        CloseWindow(true) -- Triggers Watchdog to invisibly rebuild
        SaveConfig()
    end)

    -- [INTENTIONALLY LEFT EMPTY: No FeatureList buttons spawned here yet]

    -- Teleport HUD Button Actions
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

    activeScreenGui = screenGui
    activeTpButton = tpButton
end

-- ================= 10. Initialization, Failsafes & Hooks =================

-- Initial Load
if not isBuildingUI then
    isBuildingUI = true
    pcall(BuildUI)
    isBuildingUI = false
end

-- Hook up initial states
for _, feature in ipairs(FeatureList) do
    if feature.Action and (Config[feature.Key] == true or feature.Type == "Cycle") then
        feature.Action(Config[feature.Key])
    end
end

-- Debounced Watchdog & Failsafe
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
                    warn("[OWP HUB] UI missing for 5+ seconds! Safety fallback: Temporarily suspending NoClip physics to prevent falling.")
                    Engine.NoClipConnection:Disconnect()
                    Engine.NoClipConnection = nil 
                    
                    if player.Character then
                        for _, p in ipairs(player.Character:GetDescendants()) do
                            if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then 
                                pcall(function() p.CanCollide = true end) 
                            end
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

-- Stabilized TP HUD Background Updater
task.spawn(function()
    while task.wait(0.1) do
        if not Config.TeleportHUD or not activeTpButton or not activeTpButton.Parent or isBuildingUI then continue end
        
        local newState, newColor
        
        if tick() < Engine.TPWarningEnd then
            newState, newColor = Engine.TPWarningText, COLOR_ACCENT_RED
        elseif isPlayerHoldingAnyKey() then
            newState, newColor = "TP: Item Held", COLOR_ACCENT_CYAN
        elseif tick() < Engine.TPCooldownEnd then
            newState, newColor = "TP Cooldown: " .. math.ceil(Engine.TPCooldownEnd - tick()) .. "s", COLOR_ACCENT_YELLOW
        else
            newState, newColor = "Teleport To Key", COLOR_ACCENT_GREEN
        end
        
        if activeTpButton.Text ~= newState then
            activeTpButton.Text = newState
            activeTpButton.TextColor3 = newColor
        end
    end
end)

-- Teleport HUD Button Linker Fix
task.spawn(function()
    while task.wait(0.5) do
        if activeTpButton and activeTpButton.Parent then
            if _G.OWP_Loader_Played then
                activeTpButton.Visible = Config.TeleportHUD
            end
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
            -- Note: UI buttons aren't spawned yet in 4.1, so we bypass _updateVisuals
            if feature._updateVisuals and activeScreenGui then 
                pcall(feature._updateVisuals) 
            end
        end
    end
end)

print("✅ PETAPETA: School of Nightmares V14.6 (Phase 4.1: The Shell) - Loaded")
