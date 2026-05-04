-- ================= 0. SINGLETON CHECK & AUTO-QUEUE =================
local SCRIPT_URL = "https://raw.githubusercontent.com/OWpop/jubilant-doodle/main/main.lua"
if queue_on_teleport then
    queue_on_teleport('loadstring(game:HttpGet("' .. SCRIPT_URL .. '?t="..tostring(tick())))()')
end

if _G.OWP_Hub_Running and _G.OWP_PetaHub_Unload then
    pcall(_G.OWP_PetaHub_Unload)
end
_G.OWP_Hub_Running = true

local isUnloaded = false
local scriptConnections = {}

--[[
    PETAPETA: School of Nightmares V15.18 (Dynamic TP Raycast Fix)
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

local GUI_NAME = "OWP_PetaHub_V15_18_" .. tostring(math.random(10000, 99999))
local CONFIG_FILE_NAME = "OWP_PetaHub_Config.json"
local FONT = Enum.Font.SourceSans
local FONT_BOLD = Enum.Font.SourceSansBold
local FONT_SEMIBOLD = Enum.Font.SourceSansSemibold

-- Colors (Static Dark Glass Scheme)
local C_BG_MAIN = Color3.fromRGB(15, 15, 15)
local C_BG_TITLE = Color3.fromRGB(20, 20, 20)
local C_BG_ROW = Color3.fromRGB(25, 25, 25)
local C_BORDER = Color3.fromRGB(50, 50, 50)
local C_TEXT_WHITE = Color3.fromRGB(255, 255, 255)
local C_TEXT_DIM = Color3.fromRGB(150, 150, 150)
local C_TEXT_DARK = Color3.fromRGB(0, 0, 0)
local C_ACCENT_GREEN = Color3.fromRGB(0, 255, 0)
local C_ACCENT_YELLOW = Color3.fromRGB(255, 255, 0)
local C_ACCENT_RED = Color3.fromRGB(255, 0, 0)
local C_ACCENT_CYAN = Color3.fromRGB(0, 200, 255)
local C_TOGGLE_ON_BG = Color3.fromRGB(60, 20, 20)
local C_TOGGLE_OFF_BG = Color3.fromRGB(40, 40, 40)
local C_TOGGLE_OFF_PILL = Color3.fromRGB(80, 80, 80)

-- Sizes and Positions
local TOGGLE_BUTTON_SIZE = UDim2.new(0, 100, 0, 32)
local TOGGLE_BUTTON_POS = UDim2.new(0, 10, 0, 10)
local MENU_WIDTH = 320
local MENU_HEIGHT_OPEN = 360
local MENU_HEIGHT_MINIMIZED = 35
local MAIN_FRAME_POS_CENTER = UDim2.new(0.5, -MENU_WIDTH / 2, 0.1, 0)
local ANIM_TWEEN_INFO = TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local TOGGLE_TWEEN_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- Configuration Constants
local WALK_SPEEDS = {16, 20, 30, 40, 50}
local IMPORTANT_ITEM_NAMES = {"key", "key_neon", "key_ver2"}
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
    Cache = {Keys = {}, Fires = {}, Prompts = {}},
    ESPBeams = {}, ESPAttachments = {}, ESPConnections = {}, ESPUpdateRunning = false,
    NoClipConnection = nil, FullBrightConnection = nil, AntiVoidConnection = nil, AntiFreezeConnection = nil,
    SpeedEnforceRunning = false, SpeedEnforceCancelTime = 0, HiddenFires = {},
    TPCooldownEnd = 0, TPWarningEnd = 0, TPWarningText = "",
    MenuMinimized = false,
    SavedMenuPosition = MAIN_FRAME_POS_CENTER
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
        writefile(CONFIG_FILE_NAME, HttpService:JSONEncode(Config))
    end)
end

LoadConfig()

-- Strict Config Validation (Prevents nil/type corruption)
if type(Config.SpeedIndex) ~= "number" or Config.SpeedIndex < 1 or Config.SpeedIndex > #WALK_SPEEDS then
    Config.SpeedIndex = 2
end

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

local function restoreLighting()
    Lighting.Ambient = initialLighting.Ambient
    Lighting.OutdoorAmbient = initialLighting.OutdoorAmbient
    Lighting.Brightness = initialLighting.Brightness
    Lighting.FogEnd = initialLighting.FogEnd
    Lighting.GlobalShadows = initialLighting.GlobalShadows
end

local function updateEspVisuals()
    local beamColor = Config.FullBright and C_ACCENT_CYAN or C_ACCENT_GREEN
    local transparency = Config.FullBright and 0.1 or 0.3
    local lightEmission = Config.FullBright and 0.6 or 0.35
    for obj, beam in pairs(Engine.ESPBeams) do
        if beam and beam.Parent then
            beam.Color = ColorSequence.new(beamColor)
            beam.Transparency = NumberSequence.new(transparency)
            beam.LightEmission = lightEmission
        end
    end
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
        CheckFireText(obj, action); CheckFireText(obj, object)
        table.insert(scriptConnections, obj:GetPropertyChangedSignal("ActionText"):Connect(function()
            local a = obj.ActionText:lower()
            if string.find(a, "search") then Engine.Cache.Prompts[obj] = true end
            CheckFireText(obj, a)
        end))
        table.insert(scriptConnections, obj:GetPropertyChangedSignal("ObjectText"):Connect(function() CheckFireText(obj, obj.ObjectText) end))
    elseif cls == "BillboardGui" or cls == "SurfaceGui" or cls == "TextLabel" then
        if cls == "TextLabel" then
            CheckFireText(obj, obj.Text)
            table.insert(scriptConnections, obj:GetPropertyChangedSignal("Text"):Connect(function() CheckFireText(obj, obj.Text) end))
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
table.insert(scriptConnections, Workspace.DescendantAdded:Connect(CategorizeObject))
table.insert(scriptConnections, Workspace.DescendantRemoving:Connect(function(obj)
    Engine.Cache.Keys[obj] = nil; Engine.Cache.Fires[obj] = nil; Engine.Cache.Prompts[obj] = nil
end))

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
    beam.Color = ColorSequence.new(Config.FullBright and C_ACCENT_CYAN or C_ACCENT_GREEN)
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
        if isUnloaded then break end
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
table.insert(scriptConnections, RunService.Stepped:Connect(function()
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
end))

task.spawn(function()
    while task.wait(0.1) do
        if isUnloaded then break end
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

-- ================= 8. Feature Registration List (Data-Driven Sections) =================
local FeatureList = {
    {Name = "Speed", Key = "SpeedIndex", Type = "Cycle", CycleOptions = {1, 2, 3, 4, 5}, Section = "All Mode",
    Action = function(val)
        Engine.SpeedEnforceCancelTime = tick() + ENFORCE_SPEED_DURATION
        Engine.SpeedEnforceRunning = true
    end,
    OnCharacterAdded = function(char, hum)
        if hum then hum.WalkSpeed = WALK_SPEEDS[Config.SpeedIndex] end
        Engine.SpeedEnforceCancelTime = tick() + ENFORCE_SPEED_DURATION
        Engine.SpeedEnforceRunning = true
    end},

    {Name = "NoClip", Key = "NoClip", Type = "Toggle", Section = "All Mode",
    Action = function(val)
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
    end,
    OnCharacterAdded = function(char, hum)
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

    {Name = "Full Bright", Key = "FullBright", Type = "Toggle", Section = "All Mode",
    Action = function(val)
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
            restoreLighting()
        end
        if Config.ESP then updateEspVisuals() end
    end},

    {Name = "ESP", Key = "ESP", Type = "Toggle", Section = "All Mode",
    Action = function(val)
        if val then if not Engine.ESPUpdateRunning then task.spawn(updateEspBeamsThrottled) end else cleanupAllEsp() end
    end},

    {Name = "ESP Distance", Key = "ESPDistance", Type = "Toggle", Section = "All Mode",
    Action = function(val)
        if Config.ESP and not Engine.ESPUpdateRunning then task.spawn(updateEspBeamsThrottled) end
    end},

    {Name = "Anti-Void", Key = "AntiVoid", Type = "Toggle", Section = "All Mode",
    Action = function(val)
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

    {Name = "Teleport HUD", Key = "TeleportHUD", Type = "Toggle", Section = "All Mode",
    Action = function(val) if _G.OWP_TP_Button then _G.OWP_TP_Button.Visible = val end end},

    {Name = "Speed Lock", Key = "SpeedLock", Type = "Toggle", Section = "All Mode", Action = nil},
    {Name = "Search Locker", Key = "SearchAura", Type = "Toggle", Section = "All Mode", Action = nil},
    {Name = "Anti-Freeze", Key = "AntiFreeze", Type = "Toggle", Section = "All Mode", Action = nil},

    {Name = "Bypass Fire", Key = "BypassFire", Type = "Toggle", Section = "Super Hard Mode",
    Action = function(val)
        if not val then
            for obj, data in pairs(Engine.HiddenFires) do
                if obj then pcall(function() obj.Parent = data.Parent end) end
            end
            table.clear(Engine.HiddenFires)
        end
    end}
}

-- ================= 9. UI Generation =================
local activeScreenGui = nil
local activeMainFrame = nil
local isBuildingUI = false

local function BuildUI()
    local guiParent = (gethui and gethui()) or game:GetService("CoreGui") or playerGui
    for _, child in ipairs(guiParent:GetChildren()) do
        if string.match(child.Name, "^OWP_PetaHub") then pcall(function() child:Destroy() end) end
    end

    local screenGui = Instance.new("ScreenGui", guiParent)
    screenGui.Name = GUI_NAME
    screenGui.ResetOnSpawn = false

    -- Toggle Button Glassmorphism
    local toggleButton = Instance.new("TextButton", screenGui)
    toggleButton.Size = TOGGLE_BUTTON_SIZE
    toggleButton.Position = TOGGLE_BUTTON_POS
    toggleButton.Text = "OWP HUB"
    toggleButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    toggleButton.BackgroundTransparency = 0.3
    toggleButton.TextColor3 = C_TEXT_WHITE
    toggleButton.Font = FONT_BOLD
    toggleButton.TextScaled = true
    toggleButton.TextXAlignment = Enum.TextXAlignment.Center
    toggleButton.Draggable = true
    toggleButton.ClipsDescendants = true

    local glassStroke = Instance.new("UIStroke", toggleButton)
    glassStroke.Color = Color3.fromRGB(80, 80, 80)
    glassStroke.Transparency = 0.5
    glassStroke.Thickness = 1.5
    Instance.new("UICorner", toggleButton).CornerRadius = UDim.new(0, 12)

    local bottomAccent = Instance.new("Frame", toggleButton)
    bottomAccent.Size = UDim2.new(1, 0, 0, 2)
    bottomAccent.Position = UDim2.new(0, 0, 1, 0)
    bottomAccent.AnchorPoint = Vector2.new(0, 1)
    bottomAccent.BackgroundColor3 = C_ACCENT_RED
    bottomAccent.BackgroundTransparency = 0.3
    bottomAccent.BorderSizePixel = 0

    -- Teleport HUD Button Glassmorphism
    local tpButton = Instance.new("TextButton", screenGui)
    tpButton.Size = UDim2.new(0, 130, 0, 32)
    tpButton.Position = UDim2.new(0, 10, 0, 48)
    tpButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    tpButton.BackgroundTransparency = 0.3
    tpButton.TextColor3 = C_ACCENT_GREEN
    tpButton.Font = FONT_BOLD
    tpButton.TextScaled = true
    tpButton.Text = "Teleport To Key"
    tpButton.Visible = Config.TeleportHUD
    tpButton.Draggable = true
    tpButton.TextXAlignment = Enum.TextXAlignment.Center
    tpButton.ClipsDescendants = true

    local tpGlassStroke = Instance.new("UIStroke", tpButton)
    tpGlassStroke.Color = Color3.fromRGB(80, 80, 80)
    tpGlassStroke.Transparency = 0.5
    tpGlassStroke.Thickness = 1.5
    Instance.new("UICorner", tpButton).CornerRadius = UDim.new(0, 12)

    -- Main Hub Frame
    local mainFrame = Instance.new("Frame", screenGui)
    mainFrame.Size = UDim2.new(0, MENU_WIDTH, 0, MENU_HEIGHT_OPEN)
    mainFrame.Position = UDim2.new(0, -MENU_WIDTH - 30, Engine.SavedMenuPosition.Y.Scale, Engine.SavedMenuPosition.Y.Offset)
    mainFrame.BackgroundColor3 = C_BG_MAIN
    mainFrame.BorderSizePixel = 0
    mainFrame.ClipsDescendants = true
    Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 8)
    Instance.new("UIStroke", mainFrame).Color = C_BORDER

    -- Title Bar
    local titleBar = Instance.new("Frame", mainFrame)
    titleBar.Size = UDim2.new(1, 0, 0, MENU_HEIGHT_MINIMIZED)
    titleBar.BackgroundColor3 = C_BG_TITLE
    titleBar.BorderSizePixel = 0

    local dragInput, dragStart, startPos
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragStart = input.Position; startPos = mainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragStart = nil end
            end)
        end
    end)
    titleBar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    table.insert(scriptConnections, RunService.Heartbeat:Connect(function()
        if dragStart and dragInput and Config.GuiVisible then
            local delta = dragInput.Position - dragStart
            mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            Engine.SavedMenuPosition = mainFrame.Position
        end
    end))

    Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 8)

    local titleText = Instance.new("TextLabel", titleBar)
    titleText.Size = UDim2.new(0, 185, 1, 0)
    titleText.Position = UDim2.new(0, 10, 0, 0)
    titleText.BackgroundTransparency = 1
    titleText.Text = "PETAPETA: SCHOOL OF NIGHTMARES"
    titleText.TextColor3 = C_TEXT_WHITE
    titleText.Font = FONT_BOLD
    titleText.TextSize = 13
    titleText.TextXAlignment = Enum.TextXAlignment.Left

    local authorText = Instance.new("TextLabel", titleBar)
    authorText.Size = UDim2.new(0, 65, 1, 0)
    authorText.Position = UDim2.new(0, 190, 0, 0)
    authorText.BackgroundTransparency = 1
    authorText.Text = "BY: OtherWisePop"
    authorText.TextColor3 = C_TEXT_DIM
    authorText.Font = FONT_SEMIBOLD
    authorText.TextSize = 10
    authorText.TextXAlignment = Enum.TextXAlignment.Left

    local controlsFrame = Instance.new("Frame", titleBar)
    controlsFrame.Size = UDim2.new(0, 60, 1, 0)
    controlsFrame.Position = UDim2.new(1, 0, 0, 0)
    controlsFrame.AnchorPoint = Vector2.new(1, 0)
    controlsFrame.BackgroundTransparency = 1

    local controlsLayout = Instance.new("UIListLayout", controlsFrame)
    controlsLayout.FillDirection = Enum.FillDirection.Horizontal
    controlsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    controlsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    controlsLayout.Padding = UDim.new(0, 5)
    controlsLayout.SortOrder = Enum.SortOrder.LayoutOrder

    local minBtn = Instance.new("TextButton", controlsFrame)
    minBtn.LayoutOrder = 1
    minBtn.Size = UDim2.new(0, 24, 0, 24)
    minBtn.BackgroundTransparency = 1
    minBtn.Text = "-"
    minBtn.TextColor3 = C_TEXT_DIM
    minBtn.Font = FONT_BOLD
    minBtn.TextSize = 16

    local closeBtn = Instance.new("TextButton", controlsFrame)
    closeBtn.LayoutOrder = 2
    closeBtn.Size = UDim2.new(0, 24, 0, 24)
    closeBtn.BackgroundTransparency = 1
    closeBtn.Text = "X"
    closeBtn.TextColor3 = C_TEXT_DIM
    closeBtn.Font = FONT_BOLD
    closeBtn.TextSize = 14

    Instance.new("UIPadding", controlsFrame).PaddingRight = UDim.new(0, 5)

    local scrollFrame = Instance.new("ScrollingFrame", mainFrame)
    scrollFrame.Size = UDim2.new(1, 0, 1, -MENU_HEIGHT_MINIMIZED)
    scrollFrame.Position = UDim2.new(0, 0, 0, MENU_HEIGHT_MINIMIZED)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 2
    scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)

    local uiListLayout = Instance.new("UIListLayout", scrollFrame)
    uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    uiListLayout.Padding = UDim.new(0, 4)
    uiListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    Instance.new("UIPadding", scrollFrame).PaddingTop = UDim.new(0, 8)
    Instance.new("UIPadding", scrollFrame).PaddingBottom = UDim.new(0, 8)

    local function CreateSectionHeader(sectionName, layoutOrder)
        local container = Instance.new("Frame", scrollFrame)
        container.Size = UDim2.new(1, -20, 0, 34)
        container.LayoutOrder = layoutOrder
        container.BackgroundTransparency = 1
        container.BorderSizePixel = 0

        local accentBar = Instance.new("Frame", container)
        accentBar.Size = UDim2.new(0, 2, 0, 14)
        accentBar.Position = UDim2.new(0, 12, 0.5, 0)
        accentBar.AnchorPoint = Vector2.new(0, 0.5)
        accentBar.BackgroundColor3 = C_ACCENT_RED
        accentBar.BorderSizePixel = 0
        Instance.new("UICorner", accentBar).CornerRadius = UDim.new(1, 0)

        local label = Instance.new("TextLabel", container)
        label.Size = UDim2.new(1, -30, 1, 0)
        label.Position = UDim2.new(0, 22, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = string.upper(sectionName)
        label.TextColor3 = C_TEXT_WHITE
        label.Font = FONT_SEMIBOLD
        label.TextSize = 16
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextYAlignment = Enum.TextYAlignment.Center

        local divider = Instance.new("Frame", container)
        divider.Size = UDim2.new(1, -24, 0, 1)
        divider.Position = UDim2.new(0, 12, 1, -2)
        divider.BackgroundColor3 = C_BORDER
        divider.BackgroundTransparency = 0.3
        divider.BorderSizePixel = 0
    end

    local function CreateButton(feature, order)
        local row = Instance.new("TextButton", scrollFrame)
        row.Size = UDim2.new(1, -20, 0, 36)
        row.LayoutOrder = order
        row.BackgroundColor3 = C_BG_ROW
        row.Text = ""
        row.AutoButtonColor = false
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

        local title = Instance.new("TextLabel", row)
        title.Size = UDim2.new(0.6, 0, 1, 0)
        title.Position = UDim2.new(0, 12, 0, 0)
        title.BackgroundTransparency = 1
        title.Text = feature.Name
        title.TextColor3 = C_TEXT_WHITE
        title.Font = FONT_SEMIBOLD
        title.TextSize = 16
        title.TextXAlignment = Enum.TextXAlignment.Left

        local indicatorBG = Instance.new("Frame", row)
        indicatorBG.AnchorPoint = Vector2.new(1, 0.5)
        indicatorBG.Position = UDim2.new(1, -10, 0.5, 0)
        Instance.new("UICorner", indicatorBG).CornerRadius = UDim.new(1, 0)

        local pillCircle = nil
        local valueText = nil

        if feature.Type == "Toggle" then
            indicatorBG.Size = UDim2.new(0, 44, 0, 22)
            pillCircle = Instance.new("Frame", indicatorBG)
            pillCircle.Size = UDim2.new(0, 18, 0, 18)
            pillCircle.AnchorPoint = Vector2.new(0, 0.5)
            Instance.new("UICorner", pillCircle).CornerRadius = UDim.new(1, 0)
        elseif feature.Type == "Cycle" then
            indicatorBG.Size = UDim2.new(0, 50, 0, 24)
            valueText = Instance.new("TextLabel", indicatorBG)
            valueText.Size = UDim2.new(1, 0, 1, 0)
            valueText.BackgroundTransparency = 1
            valueText.TextColor3 = C_TEXT_WHITE
            valueText.Font = FONT_BOLD
            valueText.TextSize = 14
        end

        local function updateVisuals(animate)
            if not row.Parent then return end 
            if feature.Type == "Toggle" then
                local isOn = Config[feature.Key]
                local targetBgColor = isOn and C_TOGGLE_ON_BG or C_TOGGLE_OFF_BG
                local targetCircleColor = isOn and C_ACCENT_RED or C_TOGGLE_OFF_PILL
                local targetPos = isOn and UDim2.new(1, -20, 0.5, 0) or UDim2.new(0, 2, 0.5, 0)

                if animate then
                    TweenService:Create(indicatorBG, TOGGLE_TWEEN_INFO, {BackgroundColor3 = targetBgColor}):Play()
                    TweenService:Create(pillCircle, TOGGLE_TWEEN_INFO, {BackgroundColor3 = targetCircleColor, Position = targetPos}):Play()
                else
                    indicatorBG.BackgroundColor3 = targetBgColor
                    pillCircle.BackgroundColor3 = targetCircleColor
                    pillCircle.Position = targetPos
                end
            elseif feature.Type == "Cycle" then
                indicatorBG.BackgroundColor3 = C_TOGGLE_OFF_BG
                local val = Config[feature.Key]
                valueText.Text = (feature.Key == "SpeedIndex") and tostring(WALK_SPEEDS[val] or val) or tostring(val)
            end
        end
        feature._updateVisuals = function() updateVisuals(false) end 

        row.MouseButton1Click:Connect(function()
            if feature.Type == "Toggle" then
                Config[feature.Key] = not Config[feature.Key]
            elseif feature.Type == "Cycle" then
                local options = feature.CycleOptions
                local current = Config[feature.Key]
                local idx = 1
                for i, v in ipairs(options) do
                    if v == current then idx = i; break end
                end
                idx = (idx % #options) + 1
                Config[feature.Key] = options[idx]
            end
            updateVisuals(true)
            if feature.Action then feature.Action(Config[feature.Key]) end
            SaveConfig()
            if feature.Key == "TeleportHUD" and _G.OWP_TP_Button then
                _G.OWP_TP_Button.Visible = Config.TeleportHUD
            end
        end)

        row.MouseEnter:Connect(function() TweenService:Create(row, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(35, 35, 35)}):Play() end)
        row.MouseLeave:Connect(function() TweenService:Create(row, TweenInfo.new(0.2), {BackgroundColor3 = C_BG_ROW}):Play() end)

        updateVisuals(false)
    end

    local lastSection = nil
    local layoutCounter = 0
    for _, feature in ipairs(FeatureList) do
        if feature.Section ~= lastSection then
            layoutCounter = layoutCounter + 1
            CreateSectionHeader(feature.Section, layoutCounter)
            lastSection = feature.Section
        end
        layoutCounter = layoutCounter + 1
        CreateButton(feature, layoutCounter)
    end

    local function ToggleMenu()
        Config.GuiVisible = not Config.GuiVisible
        if Config.GuiVisible then
            TweenService:Create(mainFrame, ANIM_TWEEN_INFO, {Position = Engine.SavedMenuPosition}):Play()
        else
            Engine.SavedMenuPosition = mainFrame.Position
            local offscreenPos = UDim2.new(0, -MENU_WIDTH - 30, Engine.SavedMenuPosition.Y.Scale, Engine.SavedMenuPosition.Y.Offset)
            TweenService:Create(mainFrame, ANIM_TWEEN_INFO, {Position = offscreenPos}):Play()
        end
        SaveConfig()
    end

    toggleButton.MouseButton1Click:Connect(ToggleMenu)
    closeBtn.MouseButton1Click:Connect(function() if Config.GuiVisible then ToggleMenu() end end)

    minBtn.MouseButton1Click:Connect(function()
        Engine.MenuMinimized = not Engine.MenuMinimized
        local targetHeight = Engine.MenuMinimized and MENU_HEIGHT_MINIMIZED or MENU_HEIGHT_OPEN
        TweenService:Create(mainFrame, ANIM_TWEEN_INFO, {Size = UDim2.new(0, MENU_WIDTH, 0, targetHeight)}):Play()
    end)

    tpButton.MouseButton1Click:Connect(function()
        if tick() < Engine.TPCooldownEnd or tick() < Engine.TPWarningEnd then return end
        if isPlayerHoldingAnyKey() then Engine.TPWarningText, Engine.TPWarningEnd = "❌ Clear Hands!", tick() + 1.5 return end
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if not root then Engine.TPWarningText, Engine.TPWarningEnd = "❌ Not Ready", tick() + 1.5 return end
        
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
            --[SAFE TELEPORT FIX] Dynamic Y calculation via downward raycast
            local rayOrigin = Vector3.new(closestPos.X, closestPos.Y + 12, closestPos.Z)
            local rayDirection = Vector3.new(0, -20, 0)
            local rayParams = RaycastParams.new()
            rayParams.FilterDescendantsInstances = {player.Character}
            rayParams.FilterType = Enum.RaycastFilterType.Exclude

            local rayResult = Workspace:Raycast(rayOrigin, rayDirection, rayParams)
            local safeY = closestPos.Y + 3.5 -- Fallback if raycast misses

            if rayResult and rayResult.Instance then
                safeY = rayResult.Position.Y + 3.0 -- Safe HRP standing height above floor
            end

            local finalPos = Vector3.new(closestPos.X, safeY, closestPos.Z)
            pcall(function()
                root.CFrame = CFrame.new(finalPos) * root.CFrame.Rotation
            end)

            Engine.TPCooldownEnd = tick() + TELEPORT_COOLDOWN
        else
            Engine.TPWarningText, Engine.TPWarningEnd = "❌ No Keys Found", tick() + 1.5
        end
    end)

    activeScreenGui = screenGui
    activeMainFrame = mainFrame
    _G.OWP_TP_Button = tpButton
end

-- ================= 10. Initialization, Failsafes & Hooks =================
if not isBuildingUI then
    isBuildingUI = true
    pcall(BuildUI)
    isBuildingUI = false
end

local uiMissingTime = 0
local lastBuildTime = 0
task.spawn(function()
    while task.wait(1) do
        if isUnloaded then break end
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

task.spawn(function()
    while task.wait(0.1) do
        if isUnloaded then break end
        if not Config.TeleportHUD or not _G.OWP_TP_Button or not _G.OWP_TP_Button.Parent or isBuildingUI then continue end
        local newState, newColor
        if tick() < Engine.TPWarningEnd then
            newState, newColor = Engine.TPWarningText, C_ACCENT_RED
        elseif isPlayerHoldingAnyKey() then
            newState, newColor = "TP: Item Held", C_ACCENT_CYAN
        elseif tick() < Engine.TPCooldownEnd then
            newState, newColor = "TP Cooldown: " .. math.ceil(Engine.TPCooldownEnd - tick()) .. "s", C_ACCENT_YELLOW
        else
            newState, newColor = "Teleport To Key", C_ACCENT_GREEN
        end
        if _G.OWP_TP_Button.Text ~= newState then
            _G.OWP_TP_Button.Text = newState
            _G.OWP_TP_Button.TextColor3 = newColor
        end
    end
end)

table.insert(scriptConnections, player.CharacterAdded:Connect(function(newCharacter)
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
end))

for _, feature in ipairs(FeatureList) do
    if feature.Action and (Config[feature.Key] == true or feature.Type == "Cycle") then
        feature.Action(Config[feature.Key])
    end
end

-- ================= 11. Graceful Unload Logic =================
_G.OWP_PetaHub_Unload = function()
    isUnloaded = true
    for _, conn in ipairs(scriptConnections) do
        if type(conn) == "table" and conn.Disconnect then
            pcall(function() conn:Disconnect() end)
        elseif typeof(conn) == "RBXScriptConnection" then
            pcall(function() conn:Disconnect() end)
        end
    end
    if Engine.NoClipConnection then Engine.NoClipConnection:Disconnect() end
    if Engine.FullBrightConnection then Engine.FullBrightConnection:Disconnect() end
    if Engine.AntiVoidConnection then Engine.AntiVoidConnection:Disconnect() end
    if Engine.AntiFreezeConnection then Engine.AntiFreezeConnection:Disconnect() end
    restoreLighting()
    if player.Character then
        for _, p in ipairs(player.Character:GetDescendants()) do
            if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then pcall(function() p.CanCollide = true end) end
        end
    end
    cleanupAllEsp()
    local guiTarget = (gethui and gethui()) or game:GetService("CoreGui") or playerGui
    for _, child in ipairs(guiTarget:GetChildren()) do
        if string.match(child.Name, "^OWP_PetaHub") then pcall(function() child:Destroy() end) end
    end
end

print("✅ PETAPETA: School of Nightmares V15.18 (Dynamic TP Raycast Fix) - Loaded")
