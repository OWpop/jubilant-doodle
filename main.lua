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

--[[
    PETAPETA: School of Nightmares V16.0 (Refactored Core)
    By: OtherWisePop
    USE RESPONSIBLY AND AT YOUR OWN RISK.
--]]

-- ================= 1. INLINE MODULES =================

-- 1A. ConnectionManager — Scoped lifecycle, no leaks
local ConnectionManager = {}
ConnectionManager.__index = ConnectionManager

function ConnectionManager.new(name)
    return setmetatable({
        _name = name or "Unnamed",
        _connections = {},
        _isConnected = true
    }, ConnectionManager)
end

function ConnectionManager:Connect(signal, callback)
    if not self._isConnected then
        warn(("[ConnectionManager:%s] Attempted to connect after disposal"):format(self._name))
        return nil
    end
    local conn = signal:Connect(callback)
    table.insert(self._connections, conn)
    return conn
end

function ConnectionManager:DisconnectAll()
    for _, conn in ipairs(self._connections) do
        if conn and typeof(conn) == "RBXScriptConnection" then
            pcall(function() conn:Disconnect() end)
        end
    end
    table.clear(self._connections)
end

function ConnectionManager:Destroy()
    self:DisconnectAll()
    self._isConnected = false
end

-- 1B. SmartCache — Precision categorization, direct iteration, no allocation
local SmartCache = {}
SmartCache.__index = SmartCache

local CACHE_KEY_NAMES = {"key", "key_neon", "key_ver2"}
local CACHE_FIRE_KEYWORDS = {"fire", "extinguish", "flame"}
local CACHE_SEARCH_KEYWORDS = {"search"}

function SmartCache.new(workspaceRef)
    local self = setmetatable({
        _workspace = workspaceRef or workspace,
        _keys = {},
        _shards = {},
        _fires = {},
        _prompts = {},
        _connections = ConnectionManager.new("SmartCache"),
        _objectConnections = {}
    }, SmartCache)

    self:_init()
    return self
end

function SmartCache:_isKeyName(name)
    local lower = name:lower()
    for _, target in ipairs(CACHE_KEY_NAMES) do
        if string.find(lower, target:lower()) then return true end
    end
    return string.find(lower, "key") ~= nil
end

function SmartCache:_isShardName(name)
    local lower = name:lower()
    return string.find(lower, "shard") ~= nil or string.find(lower, "cursed") ~= nil or string.find(lower, "orb") ~= nil
end

function SmartCache:_hasKeyword(name, keywords)
    local lower = name:lower()
    for _, kw in ipairs(keywords) do
        if string.find(lower, kw) then return true end
    end
    return false
end

function SmartCache:_checkFireText(obj, text)
    if not text then return end
    if self:_hasKeyword(text, CACHE_FIRE_KEYWORDS) then
        self._fires[obj] = true
    end
end

function SmartCache:_bindObject(obj)
    local cls = obj.ClassName
    local name = obj.Name
    local lowerName = name:lower()

    if cls == "ProximityPrompt" then
        local action = obj.ActionText:lower()
        local objectText = obj.ObjectText:lower()

        if self:_hasKeyword(action, CACHE_SEARCH_KEYWORDS) or self:_hasKeyword(lowerName, CACHE_SEARCH_KEYWORDS) then
            self._prompts[obj] = true
        end

        self:_checkFireText(obj, action)
        self:_checkFireText(obj, objectText)

        local objConn = ConnectionManager.new("Obj_" .. tostring(obj))
        self._objectConnections[obj] = objConn

        objConn:Connect(obj:GetPropertyChangedSignal("ActionText"), function()
            local a = obj.ActionText:lower()
            if self:_hasKeyword(a, CACHE_SEARCH_KEYWORDS) then self._prompts[obj] = true end
            self:_checkFireText(obj, a)
        end)

        objConn:Connect(obj:GetPropertyChangedSignal("ObjectText"), function()
            self:_checkFireText(obj, obj.ObjectText)
        end)

    elseif cls == "TextLabel" then
        self:_checkFireText(obj, obj.Text)
        local objConn = ConnectionManager.new("Obj_" .. tostring(obj))
        self._objectConnections[obj] = objConn
        objConn:Connect(obj:GetPropertyChangedSignal("Text"), function()
            self:_checkFireText(obj, obj.Text)
        end)
    end

    local isKey = self:_isKeyName(name)
    local isShard = not isKey and self:_isShardName(name)

    if isKey and (cls == "Tool" or cls == "Model" or obj:IsA("BasePart")) then
        self._keys[obj] = true
    elseif isShard and (cls == "Tool" or cls == "Model" or obj:IsA("BasePart")) then
        self._shards[obj] = true
    end

    if self:_hasKeyword(name, CACHE_FIRE_KEYWORDS) then
        self._fires[obj] = true
    end
end

function SmartCache:_unbindObject(obj)
    self._keys[obj] = nil
    self._shards[obj] = nil
    self._fires[obj] = nil
    self._prompts[obj] = nil

    if self._objectConnections[obj] then
        self._objectConnections[obj]:Destroy()
        self._objectConnections[obj] = nil
    end
end

function SmartCache:_init()
    for _, obj in ipairs(self._workspace:GetDescendants()) do
        self:_bindObject(obj)
    end

    self._connections:Connect(self._workspace.DescendantAdded, function(obj)
        self:_bindObject(obj)
    end)

    self._connections:Connect(self._workspace.DescendantRemoving, function(obj)
        self:_unbindObject(obj)
    end)
end

function SmartCache:ForEachKey(callback)
    for obj, _ in pairs(self._keys) do
        if obj.Parent then
            local ok, err = pcall(callback, obj)
            if not ok then warn("[SmartCache] Key iterator error: " .. tostring(err)) end
        else
            self._keys[obj] = nil
        end
    end
end

function SmartCache:ForEachShard(callback)
    for obj, _ in pairs(self._shards) do
        if obj.Parent then
            local ok, err = pcall(callback, obj)
            if not ok then warn("[SmartCache] Shard iterator error: " .. tostring(err)) end
        else
            self._shards[obj] = nil
        end
    end
end

function SmartCache:ForEachFire(callback)
    for obj, _ in pairs(self._fires) do
        if obj.Parent then
            local ok, err = pcall(callback, obj)
            if not ok then warn("[SmartCache] Fire iterator error: " .. tostring(err)) end
        else
            self._fires[obj] = nil
        end
    end
end

function SmartCache:ForEachPrompt(callback)
    for obj, _ in pairs(self._prompts) do
        if obj.Parent and obj:IsA("ProximityPrompt") then
            local ok, err = pcall(callback, obj)
            if not ok then warn("[SmartCache] Prompt iterator error: " .. tostring(err)) end
        else
            self._prompts[obj] = nil
        end
    end
end

function SmartCache:Destroy()
    self._connections:Destroy()
    for obj, conn in pairs(self._objectConnections) do
        conn:Destroy()
    end
    table.clear(self._keys)
    table.clear(self._shards)
    table.clear(self._fires)
    table.clear(self._prompts)
    table.clear(self._objectConnections)
end

-- 1C. InventoryTracker — Event-driven, zero polling
local InventoryTracker = {}
InventoryTracker.__index = InventoryTracker

local INV_KEY_NAMES = {"key", "key_neon", "key_ver2"}

function InventoryTracker.new(player, onStateChanged)
    local self = setmetatable({
        _player = player,
        _isHolding = false,
        _onStateChanged = onStateChanged or function() end,
        _connections = ConnectionManager.new("InventoryTracker")
    }, InventoryTracker)
-- 1C. InventoryTracker — Event-driven with graceful fallback
local InventoryTracker = {}
InventoryTracker.__index = InventoryTracker

local INV_KEY_NAMES = {"key", "key_neon", "key_ver2"}

function InventoryTracker.new(player, onStateChanged)
    local self = setmetatable({
        _player = player,
        _isHolding = false,
        _onStateChanged = onStateChanged or function() end,
        _connections = ConnectionManager.new("InventoryTracker"),
        _fallbackPoll = nil
    }, InventoryTracker)

    self:_startTracking()
    return self
end

function InventoryTracker:_hasKeyName(name)
    local lower = name:lower()
    for _, target in ipairs(INV_KEY_NAMES) do
        if string.find(lower, target:lower()) then return true end
    end
    return string.find(lower, "key") ~= nil
end

function InventoryTracker:_scanContainer(container)
    if not container then return false end
    for _, obj in ipairs(container:GetChildren()) do
        if obj:IsA("Tool") or obj:IsA("Model") or obj:IsA("BasePart") then
            if self:_hasKeyName(obj.Name) then return true end
        end
    end
    return false
end

function InventoryTracker:_reevaluate()
    local char = self._player.Character
    local backpack = self._player.Backpack
    local camera = workspace.CurrentCamera

    local newState = false
    if char and self:_scanContainer(char) then newState = true end
    if not newState and backpack and self:_scanContainer(backpack) then newState = true end
    if not newState and camera and self:_scanContainer(camera) then newState = true end

    if newState ~= self._isHolding then
        self._isHolding = newState
        self._onStateChanged(newState)
    end
end

function InventoryTracker:_watchContainer(container)
    if not container then return end
    self._connections:Connect(container.ChildAdded, function(child)
        if self:_hasKeyName(child.Name) or child:IsA("Tool") then
            task.defer(function() self:_reevaluate() end)
        end
    end)
    self._connections:Connect(container.ChildRemoved, function(child)
        if self:_hasKeyName(child.Name) or child:IsA("Tool") then
            task.defer(function() self:_reevaluate() end)
        end
    end)
end

function InventoryTracker:_setupHumanoidEvents(hum, char)
    -- Graceful fallback: ToolEquipped may not exist on all Humanoid implementations
    local hasToolEvents = pcall(function()
        return hum.ToolEquipped ~= nil and hum.ToolUnequipped ~= nil
    end)

    if hasToolEvents and hum.ToolEquipped then
        self._connections:Connect(hum.ToolEquipped, function()
            task.defer(function() self:_reevaluate() end)
        end)
        self._connections:Connect(hum.ToolUnequipped, function()
            task.defer(function() self:_reevaluate() end)
        end)
    else
        -- Fallback: poll character tools when ToolEquipped is unavailable
        if self._fallbackPoll then
            task.cancel(self._fallbackPoll)
            self._fallbackPoll = nil
        end
        self._fallbackPoll = task.spawn(function()
            while self._isHolding ~= nil do
                task.wait(0.5)
                if not self._player or not self._player.Parent then break end
                self:_reevaluate()
            end
        end)
    end
end

function InventoryTracker:_startTracking()
    self:_reevaluate()

    self:_watchContainer(self._player.Backpack)
    self:_watchContainer(workspace.CurrentCamera)

    self._connections:Connect(self._player.CharacterAdded, function(char)
        self:_watchContainer(char)
        local hum = char:WaitForChild("Humanoid", 5)
        if hum then
            self:_setupHumanoidEvents(hum, char)
        end
        self:_reevaluate()
    end)

    if self._player.Character then
        self:_watchContainer(self._player.Character)
        local hum = self._player.Character:FindFirstChild("Humanoid")
        if hum then
            self:_setupHumanoidEvents(hum, self._player.Character)
        end
    end
end

function InventoryTracker:IsHoldingKey()
    return self._isHolding
end

function InventoryTracker:Destroy()
    if self._fallbackPoll then
        task.cancel(self._fallbackPoll)
        self._fallbackPoll = nil
    end
    self._connections:Destroy()
    self._isHolding = false
end
    
                task.defer(function() self:_reevaluate() end)
            end)
            self._connections:Connect(hum.ToolUnequipped, function()
                task.defer(function() self:_reevaluate() end)
            end)
        end
    end
end

function InventoryTracker:IsHoldingKey()
    return self._isHolding
end

function InventoryTracker:Destroy()
    self._connections:Destroy()
    self._isHolding = false
end

-- 1D. CharacterPartCache — Zero-allocation physics loop
local CharacterPartCache = {}
CharacterPartCache.__index = CharacterPartCache

function CharacterPartCache.new(player)
    local self = setmetatable({
        _player = player,
        _parts = {},
        _connections = ConnectionManager.new("CharacterPartCache"),
        _charConnections = nil,
        _currentChar = nil
    }, CharacterPartCache)

    self:_startTracking()
    return self
end

function CharacterPartCache:_clear()
    table.clear(self._parts)
    if self._charConnections then
        self._charConnections:Destroy()
        self._charConnections = nil
    end
end

function CharacterPartCache:_addPart(part)
    if not part:IsA("BasePart") then return end
    table.insert(self._parts, part)
end

function CharacterPartCache:_removePart(part)
    if not part:IsA("BasePart") then return end
    for i, p in ipairs(self._parts) do
        if p == part then
            table.remove(self._parts, i)
            return
        end
    end
end

function CharacterPartCache:_bindCharacter(char)
    self:_clear()
    self._currentChar = char

    local charConn = ConnectionManager.new("Char_" .. tostring(char))
    self._charConnections = charConn

    for _, desc in ipairs(char:GetDescendants()) do
        self:_addPart(desc)
    end

    charConn:Connect(char.DescendantAdded, function(c)
        self:_addPart(c)
    end)

    charConn:Connect(char.DescendantRemoving, function(c)
        self:_removePart(c)
    end)

    charConn:Connect(char.Destroying, function()
        self:_clear()
        self._currentChar = nil
    end)
end

function CharacterPartCache:_startTracking()
    if self._player.Character then
        self:_bindCharacter(self._player.Character)
    end

    self._connections:Connect(self._player.CharacterAdded, function(char)
        self:_bindCharacter(char)
    end)
end

function CharacterPartCache:GetParts()
    return self._parts
end

function CharacterPartCache:ForEach(callback)
    for _, part in ipairs(self._parts) do
        local ok, err = pcall(callback, part)
        if not ok then warn("[CharacterPartCache] callback error: " .. tostring(err)) end
    end
end

function CharacterPartCache:Destroy()
    self:_clear()
    self._connections:Destroy()
end

-- 1E. FeatureScheduler — Declarative tick system with optional jitter
local FeatureScheduler = {}
FeatureScheduler.__index = FeatureScheduler

function FeatureScheduler.new()
    return setmetatable({
        _tasks = {},
        _isRunning = false,
        _masterThread = nil
    }, FeatureScheduler)
end

function FeatureScheduler:Register(name, configKey, tickRate, conditionFn, actionFn)
    table.insert(self._tasks, {
        name = name,
        configKey = configKey,
        tickRate = tickRate,
        condition = conditionFn or function() return true end,
        action = actionFn,
        nextTick = 0,
        jitter = 0
    })
end

function FeatureScheduler:SetJitter(name, maxJitter)
    for _, task in ipairs(self._tasks) do
        if task.name == name then
            task.jitter = maxJitter
            return
        end
    end
end

function FeatureScheduler:Start()
    if self._isRunning then return end
    self._isRunning = true

    self._masterThread = task.spawn(function()
        while self._isRunning do
            local now = tick()
            local minWait = 0.05

            for _, task in ipairs(self._tasks) do
                if now >= task.nextTick then
                    local shouldRun = Config[task.configKey] and task.condition()
                    if shouldRun then
                        local ok, err = pcall(task.action)
                        if not ok then
                            warn(("[FeatureScheduler] %s error: %s"):format(task.name, tostring(err)))
                        end
                    end
                    local jitter = 0
                    if task.jitter > 0 then
                        jitter = math.random() * task.jitter
                    end
                    task.nextTick = now + task.tickRate + jitter
                end
                local timeToNext = task.nextTick - now
                if timeToNext < minWait and timeToNext > 0 then
                    minWait = timeToNext
                end
            end

            task.wait(minWait)
        end
    end)
end

function FeatureScheduler:Stop()
    self._isRunning = false
    self._masterThread = nil
end

function FeatureScheduler:Destroy()
    self:Stop()
    table.clear(self._tasks)
end

-- ================= 2. CONSTANTS & SERVICES =================
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

local GUI_NAME = "OWP_PetaHub_V16_0_" .. tostring(math.random(10000, 99999))
local CONFIG_FILE_NAME = "OWP_PetaHub_Config.json"
local CONFIG_VERSION = 1
local FONT = Enum.Font.SourceSans
local FONT_BOLD = Enum.Font.SourceSansBold
local FONT_SEMIBOLD = Enum.Font.SourceSansSemibold

-- Colors
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

-- Sizes
local TOGGLE_BUTTON_SIZE = UDim2.new(0, 100, 0, 32)
local TOGGLE_BUTTON_POS = UDim2.new(0, 10, 0, 10)
local MENU_WIDTH = 320
local MENU_HEIGHT_OPEN = 360
local MENU_HEIGHT_MINIMIZED = 35
local MAIN_FRAME_POS_CENTER = UDim2.new(0.5, -MENU_WIDTH / 2, 0.1, 0)
local ANIM_TWEEN_INFO = TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local TOGGLE_TWEEN_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- Config Constants
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

-- ================= 3. CENTRALIZED STATE =================
local Config = {
    __version = CONFIG_VERSION,
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
    ESPBeams = {},
    ESPAttachments = {},
    ESPConnections = {},
    ESPUpdateRunning = false,
    FullBrightConnection = nil,
    AntiVoidConnection = nil,
    SpeedEnforceRunning = false,
    SpeedEnforceCancelTime = 0,
    HiddenFires = {},
    TPCooldownEnd = 0,
    TPWarningEnd = 0,
    TPWarningText = "",
    MenuMinimized = false,
    SavedMenuPosition = MAIN_FRAME_POS_CENTER,
    Terrain = nil,
    _dragConnection = nil
}

local initialLighting = {
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    Brightness = Lighting.Brightness,
    FogEnd = Lighting.FogEnd,
    GlobalShadows = Lighting.GlobalShadows,
}

-- ================= 4. MODULE INSTANCES =================
local GlobalConnections = ConnectionManager.new("Global")
local Cache = SmartCache.new(Workspace)
local Inventory = InventoryTracker.new(player)
local PartCache = CharacterPartCache.new(player)
local Scheduler = FeatureScheduler.new()

Engine.Terrain = Workspace:FindFirstChildOfClass("Terrain") or Workspace

-- ================= 5. STATE PERSISTENCE =================
local function LoadConfig()
    if not isfile or not readfile then return end
    if isfile(CONFIG_FILE_NAME) then
        local success, content = pcall(readfile, CONFIG_FILE_NAME)
        if success and content then
            local decodeSuccess, decoded = pcall(function() return HttpService:JSONDecode(content) end)
            if decodeSuccess and type(decoded) == "table" then
                if decoded.__version ~= CONFIG_VERSION then
                    warn("[OWP HUB] Config version mismatch, using defaults with migration")
                    decoded.__version = CONFIG_VERSION
                end

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
Config.GuiVisible = false

-- ================= 6. HELPER FUNCTIONS =================
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

-- ================= 7. CORE LOGIC FUNCTIONS =================
local function cleanEspForItem(obj)
    if not obj then return end
    if Engine.ESPBeams[obj] then
        Engine.ESPBeams[obj]:Destroy()
        Engine.ESPBeams[obj] = nil
    end
    if Engine.ESPAttachments[obj] then
        Engine.ESPAttachments[obj]:Destroy()
        Engine.ESPAttachments[obj] = nil
    end
    if Engine.ESPConnections[obj] then
        for _, conn in ipairs(Engine.ESPConnections[obj]) do
            conn:Disconnect()
        end
        Engine.ESPConnections[obj] = nil
    end
end

local function cleanupAllEsp()
    local objectsToClean = {}
    for obj, _ in pairs(Engine.ESPBeams) do
        table.insert(objectsToClean, obj)
    end
    for _, obj in ipairs(objectsToClean) do
        cleanEspForItem(obj)
    end
    Engine.ESPBeams = {}
    Engine.ESPAttachments = {}
    Engine.ESPConnections = {}
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
    beam.Parent = Engine.Terrain

    Engine.ESPBeams[obj] = beam
    Engine.ESPAttachments[obj] = targetAttach

    local connections = {}
    table.insert(connections, obj.Destroying:Connect(function() cleanEspForItem(obj) end))
    table.insert(connections, adornee.Destroying:Connect(function() cleanEspForItem(obj) end))
    if obj:IsA("Tool") or obj:IsA("Model") then
        table.insert(connections, obj.AncestryChanged:Connect(function(_, newParent)
            if not newParent or not newParent:IsDescendantOf(Workspace) then cleanEspForItem(obj) end
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
            Cache:ForEachKey(function(obj) pcall(createEspForItem, obj) end)
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

-- ================= 8. SCHEDULER REGISTRATIONS =================
-- Physics & State: Single Stepped connection using cached parts
GlobalConnections:Connect(RunService.Stepped, function()
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
            else
                Engine.SpeedEnforceRunning = false
            end
        elseif Config.AntiFreeze and hum.WalkSpeed == 0 then
            pcall(function() hum.WalkSpeed = desiredSpeed end)
        end

        if Config.NoClip then
            PartCache:ForEach(function(p)
                pcall(function() p.CanCollide = false end)
            end)
        end
    end
end)

-- 10Hz scheduled tasks
Scheduler:Register("FireBypass", "BypassFire", 0.1,
    function() return true end,
    function()
        Cache:ForEachFire(function(obj)
            if obj and obj.Parent then pcall(hideFire, obj) end
        end)
    end
)

Scheduler:Register("SearchAura", "SearchAura", 0.1,
    function() return player.Character ~= nil end,
    function()
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if not root then return end
        Cache:ForEachPrompt(function(prompt)
            if prompt and prompt.Parent and prompt.Enabled then
                local part = prompt.Parent
                if part:IsA("BasePart") and (part.Position - root.Position).Magnitude <= (prompt.MaxActivationDistance + 1.5) then
                    pcall(function() fireproximityprompt(prompt, 1, true) end)
                end
            end
        end)
    end
)

Scheduler:Register("TPHUD", "TeleportHUD", 0.1,
    function() return _G.OWP_TP_Button and _G.OWP_TP_Button.Parent end,
    function()
        local btn = _G.OWP_TP_Button
        if not btn then return end
        local newState, newColor
        if tick() < Engine.TPWarningEnd then
            newState, newColor = Engine.TPWarningText, C_ACCENT_RED
        elseif Inventory:IsHoldingKey() then
            newState, newColor = "TP: Item Held", C_ACCENT_CYAN
        elseif tick() < Engine.TPCooldownEnd then
            newState, newColor = "TP Cooldown: " .. math.ceil(Engine.TPCooldownEnd - tick()) .. "s", C_ACCENT_YELLOW
        else
            newState, newColor = "Teleport To Key", C_ACCENT_GREEN
        end
        if btn.Text ~= newState then
            btn.Text = newState
            btn.TextColor3 = newColor
        end
    end
)

-- Optional anti-cheat evasion jitter
-- Scheduler:SetJitter("SearchAura", 0.02)
-- Scheduler:SetJitter("FireBypass", 0.02)

Scheduler:Start()

-- ================= 9. FEATURE REGISTRATION LIST =================
local FeatureList = {
    {Name = "Speed", Key = "SpeedIndex", Type = "Cycle", CycleOptions = WALK_SPEEDS, Section = "All Mode",
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
        if not val then
            if player.Character then
                PartCache:ForEach(function(p)
                    if p.Name ~= "HumanoidRootPart" then
                        pcall(function() p.CanCollide = true end)
                    end
                end)
            end
        end
    end,
    OnCharacterAdded = function(char, hum)
        if not Config.NoClip then
            PartCache:ForEach(function(p)
                if p.Name ~= "HumanoidRootPart" then
                    pcall(function() p.CanCollide = true end)
                end
            end)
        end
    end},

    {Name = "Full Bright", Key = "FullBright", Type = "Toggle", Section = "All Mode",
    Action = function(val)
        if Engine.FullBrightConnection then
            Engine.FullBrightConnection:Disconnect()
            Engine.FullBrightConnection = nil
        end

        if val then
            Engine.FullBrightConnection = RunService.RenderStepped:Connect(function()
                Lighting.Ambient = Color3.fromRGB(255, 255, 255)
                Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
                Lighting.Brightness = 2.5
                Lighting.FogEnd = 1000000
                Lighting.GlobalShadows = false
            end)
        else
            restoreLighting()
        end
        if Config.ESP then updateEspVisuals() end
    end},

    {Name = "ESP", Key = "ESP", Type = "Toggle", Section = "All Mode",
    Action = function(val)
        if val then
            if not Engine.ESPUpdateRunning then task.spawn(updateEspBeamsThrottled) end
        else
            cleanupAllEsp()
        end
    end},

    {Name = "ESP Distance", Key = "ESPDistance", Type = "Toggle", Section = "All Mode",
    Action = function(val)
        if Config.ESP and not Engine.ESPUpdateRunning then task.spawn(updateEspBeamsThrottled) end
    end},

    {Name = "Anti-Void", Key = "AntiVoid", Type = "Toggle", Section = "All Mode",
    Action = function(val)
        if Engine.AntiVoidConnection then
            Engine.AntiVoidConnection:Disconnect()
            Engine.AntiVoidConnection = nil
        end
        if val then
            Engine.AntiVoidConnection = RunService.Heartbeat:Connect(function()
                local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                if root and root.Position.Y < VOID_THRESHOLD then
                    pcall(function()
                        root.CFrame = CFrame.new(root.Position + Vector3.new(0, VOID_TELEPORT_HEIGHT - root.Position.Y, 0))
                    end)
                end
            end)
        end
    end},

    {Name = "Teleport HUD", Key = "TeleportHUD", Type = "Toggle", Section = "All Mode",
    Action = function(val)
        if _G.OWP_TP_Button then _G.OWP_TP_Button.Visible = val end
    end},

    {Name = "Speed Lock", Key = "SpeedLock", Type = "Toggle", Section = "All Mode", Action = nil},

    {Name = "Search Locker", Key = "SearchAura", Type = "Toggle", Section = "All Mode", Action = nil},

    {Name = "Anti-Freeze", Key = "AntiFreeze", Type = "Toggle", Section = "All Mode", Action = nil},

    {Name = "Bypass Fire", Key = "BypassFire", Type = "Toggle", Section = "Super Hard Mode",
    Action = function(val)
        if not val then
            for obj, data in pairs(Engine.HiddenFires) do
                if obj and obj.Parent == nil then
                    pcall(function() obj.Parent = data.Parent end)
                end
            end
            table.clear(Engine.HiddenFires)
        end
    end}
}

-- ================= 10. UI GENERATION =================
local activeScreenGui = nil
local activeMainFrame = nil
local isBuildingUI = false

local function BuildUI()
    local guiParent = (gethui and gethui()) or game:GetService("CoreGui") or playerGui

    for _, child in ipairs(guiParent:GetChildren()) do
        if string.match(child.Name, "^OWP_PetaHub") then
            pcall(function() child:Destroy() end)
        end
    end

    local screenGui = Instance.new("ScreenGui", guiParent)
    screenGui.Name = GUI_NAME
    screenGui.ResetOnSpawn = false

    -- Toggle Button
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

    -- Teleport HUD Button
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
            dragStart = input.Position
            startPos = mainFrame.Position
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

    if Engine._dragConnection then
        pcall(function() Engine._dragConnection:Disconnect() end)
        Engine._dragConnection = nil
    end

    Engine._dragConnection = RunService.Heartbeat:Connect(function()
        if dragStart and dragInput and Config.GuiVisible then
            local delta = dragInput.Position - dragStart
            mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            Engine.SavedMenuPosition = mainFrame.Position
        end
    end)

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

    -- Scrolling Frame
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

    -- Section Header
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

    -- Feature Button
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
                valueText.Text = tostring(feature.CycleOptions[Config[feature.Key]])
            end
        end
        feature._updateVisuals = function() updateVisuals(false) end

        row.MouseButton1Click:Connect(function()
            if feature.Type == "Toggle" then
                Config[feature.Key] = not Config[feature.Key]
            elseif feature.Type == "Cycle" then
                Config[feature.Key] = (Config[feature.Key] % #feature.CycleOptions) + 1
            end
            updateVisuals(true)
            if feature.Action then feature.Action(Config[feature.Key]) end
            SaveConfig()

            if feature.Key == "TeleportHUD" and _G.OWP_TP_Button then
                _G.OWP_TP_Button.Visible = Config.TeleportHUD
            end
        end)

        row.MouseEnter:Connect(function()
            TweenService:Create(row, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(35, 35, 35)}):Play()
        end)
        row.MouseLeave:Connect(function()
            TweenService:Create(row, TweenInfo.new(0.2), {BackgroundColor3 = C_BG_ROW}):Play()
        end)

        updateVisuals(false)
    end

    -- Dynamic Header & Button Injection
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
    closeBtn.MouseButton1Click:Connect(function()
        if Config.GuiVisible then ToggleMenu() end
    end)

    minBtn.MouseButton1Click:Connect(function()
        Engine.MenuMinimized = not Engine.MenuMinimized
        local targetHeight = Engine.MenuMinimized and MENU_HEIGHT_MINIMIZED or MENU_HEIGHT_OPEN
        TweenService:Create(mainFrame, ANIM_TWEEN_INFO, {Size = UDim2.new(0, MENU_WIDTH, 0, targetHeight)}):Play()
    end)

    tpButton.MouseButton1Click:Connect(function()
        if tick() < Engine.TPCooldownEnd or tick() < Engine.TPWarningEnd then return end
        if Inventory:IsHoldingKey() then
            Engine.TPWarningText, Engine.TPWarningEnd = "Clear Hands!", tick() + 1.5
            return
        end
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if not root then
            Engine.TPWarningText, Engine.TPWarningEnd = "Not Ready", tick() + 1.5
            return
        end

        local closestKey, closestPos, minDistance = nil, nil, math.huge
        Cache:ForEachKey(function(obj)
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
        end)

        if closestKey and closestPos then
            pcall(function()
                root.CFrame = CFrame.new(closestPos + Vector3.new(0, TELEPORT_VERTICAL_OFFSET, 0)) * root.CFrame.Rotation
            end)
            Engine.TPCooldownEnd = tick() + TELEPORT_COOLDOWN
        else
            Engine.TPWarningText, Engine.TPWarningEnd = "No Keys Found", tick() + 1.5
        end
    end)

    activeScreenGui = screenGui
    activeMainFrame = mainFrame
    _G.OWP_TP_Button = tpButton

    -- UI REBUILD STATE SYNC: Re-apply active feature states so background logic matches UI
    for _, feature in ipairs(FeatureList) do
        if feature.Action and Config[feature.Key] == true then
            feature.Action(true)
        end
        if feature._updateVisuals then
            feature._updateVisuals()
        end
    end
end

-- ================= 11. INITIALIZATION, FAILSAFES & HOOKS =================
if not isBuildingUI then
    isBuildingUI = true
    pcall(BuildUI)
    isBuildingUI = false
end

local uiMissingTime = 0
local lastBuildTime = 0
GlobalConnections:Connect(RunService.Heartbeat, function()
    if isUnloaded then return end
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
            if Config.NoClip then
                warn("[OWP HUB] UI missing for 5+ seconds! Safety fallback: Temporarily suspending NoClip physics.")
                if player.Character then
                    PartCache:ForEach(function(p)
                        if p.Name ~= "HumanoidRootPart" then
                            pcall(function() p.CanCollide = true end)
                        end
                    end)
                end
                uiMissingTime = -9999
            end
        end
    else
        uiMissingTime = 0
    end
end)

GlobalConnections:Connect(player.CharacterAdded, function(newCharacter)
    cleanupAllEsp()
    if Config.ESP and not Engine.ESPUpdateRunning then
        task.spawn(updateEspBeamsThrottled)
    end
    Engine.TPCooldownEnd, Engine.TPWarningEnd = 0, 0

    local hum = newCharacter:WaitForChild("Humanoid", 5)
    for _, feature in ipairs(FeatureList) do
        if feature.OnCharacterAdded then
            feature.OnCharacterAdded(newCharacter, hum)
            if feature._updateVisuals then
                feature._updateVisuals()
            end
        end
    end
end)

-- Initial feature activation
for _, feature in ipairs(FeatureList) do
    if feature.Action and (Config[feature.Key] == true or feature.Type == "Cycle") then
        feature.Action(Config[feature.Key])
    end
end

-- ================= 12. GRACEFUL UNLOAD =================
_G.OWP_PetaHub_Unload = function()
    isUnloaded = true

    Scheduler:Destroy()
    GlobalConnections:Destroy()

    if Engine.FullBrightConnection then
        Engine.FullBrightConnection:Disconnect()
        Engine.FullBrightConnection = nil
    end
    if Engine.AntiVoidConnection then
        Engine.AntiVoidConnection:Disconnect()
        Engine.AntiVoidConnection = nil
    end
    if Engine._dragConnection then
        Engine._dragConnection:Disconnect()
        Engine._dragConnection = nil
    end

    restoreLighting()

    if player.Character then
        PartCache:ForEach(function(p)
            if p.Name ~= "HumanoidRootPart" then
                pcall(function() p.CanCollide = true end)
            end
        end)
    end

    cleanupAllEsp()
    Inventory:Destroy()
    PartCache:Destroy()
    Cache:Destroy()

    local guiTarget = (gethui and gethui()) or game:GetService("CoreGui") or playerGui
    for _, child in ipairs(guiTarget:GetChildren()) do
        if string.match(child.Name, "^OWP_PetaHub") then
            pcall(function() child:Destroy() end)
        end
    end
end

print("PETAPETA: School of Nightmares V16.0 (Refactored Core) - Loaded")
