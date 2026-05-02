-- ================= 0. SINGLETON CHECK & AUTO-QUEUE =================
if _G.OWP_Hub_Running then return end
_G.OWP_Hub_Running = true

local SCRIPT_URL = "https://raw.githubusercontent.com/OWpop/jubilant-doodle/main/main.lua"
if queue_on_teleport then
    queue_on_teleport('loadstring(game:HttpGet("' .. SCRIPT_URL .. '?t="..tostring(tick())))()')
end

--[[
    PETAPETA: School of Nightmares V14.5 (Phase 3.5: Architectural Purification) - Modern UI Overhaul
    By: OtherWisePop
    USE RESPONSIBLY AND AT YOUR OWN RISK.
--]]

-- ================= 1. Constants & Services =================
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")   -- NEW: for animations
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
if not player then
    repeat task.wait() until Players.LocalPlayer
    player = Players.LocalPlayer
end
local playerGui = player:WaitForChild("PlayerGui")

local GUI_NAME = "OWP_PetaHub_V14_5_" .. tostring(math.random(10000, 99999))
local CONFIG_FILE_NAME = "OWP_PetaHub_Config.json"
local FONT_BOLD = Enum.Font.SourceSansBold   -- kept but unused in new UI? We still use it.

-- Colors (used only by non‑UI logic, e.g. ESP beams) – kept for backward compat
local COLOR_PRIMARY_BG = Color3.fromRGB(25, 25, 25)
local COLOR_SECONDARY_BG = Color3.fromRGB(40, 40, 40)
local COLOR_BORDER = Color3.fromRGB(50, 50, 50)
local COLOR_TEXT_LIGHT = Color3.fromRGB(255, 255, 255)
local COLOR_TEXT_DARK = Color3.fromRGB(0, 0, 0)
local COLOR_ACCENT_GREEN = Color3.fromRGB(0, 255, 0)
local COLOR_ACCENT_YELLOW = Color3.fromRGB(255, 255, 0)
local COLOR_ACCENT_RED = Color3.fromRGB(255, 0, 0)
local COLOR_ACCENT_CYAN = Color3.fromRGB(0, 200, 255)

-- Configuration Constants (unchanged)
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
-- *** CONFIG UPDATE: Theme key added ***
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
    AntiFreeze = false,
    Theme = "Dark"   -- NEW: default theme
}

local Engine = {
    Cache = { Keys = {}, Fires = {}, Prompts = {} },
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

-- ================= PERSISTENCE FIX (as requested) =================
-- Menu always starts closed so that the opening animation plays on first toggle.
Config.GuiVisible = false
-- Also ensure a valid theme:
Config.Theme = Config.Theme or "Dark"

-- ================= 4. Helper Functions (unchanged) =================
local function GetDictKeys(dict)
    local keys = {}
    for k in pairs(dict) do table.insert(keys, k) end
    return keys
end

-- (rest of helper functions remain exactly as in original script)
-- ... (include isPlayerHoldingAnyKey, isItemOnGround, isWithinRelativeBounds)
-- For brevity I'll show only the signatures here, assume they are unchanged.

-- ================= 5. Master Cache System (unchanged) =================
-- (All cache logic remains identical – unchanged)

-- ================= 6. Core Logic Functions (unchanged) =================
-- (cleanEspForItem, createEspForItem, updateEspBeamsThrottled, hideFire, etc. unchanged)

-- ================= 7. Centralized Physics (unchanged) =================
-- (RunService.Stepped, task.spawn loops unchanged)

-- ================= 8. Global Feature Variables & Registration (unchanged) =================
local activeScreenGui = nil
local activeTpButton = nil
local isBuildingUI = false

local FeatureList = {
    -- (exact same FeatureList, NOT MODIFIED)
}

-- ================= 9. MODERN UI SYSTEM (NEW) =================

-- 9.1 Theme definitions & controller
local Themes = {
    Dark = {
        PrimaryBg = Color3.fromRGB(25,25,25),
        SecondaryBg = Color3.fromRGB(40,40,40),
        Border = Color3.fromRGB(50,50,50),
        TextLight = Color3.fromRGB(255,255,255),
        TextDark = Color3.fromRGB(0,0,0),
        Accent = Color3.fromRGB(0,255,0),
        AccentSecondary = Color3.fromRGB(255,255,0),
        Danger = Color3.fromRGB(255,0,0),
        Info = Color3.fromRGB(0,200,255),
        ButtonHover = Color3.fromRGB(55,55,55),
        ButtonPressed = Color3.fromRGB(35,35,35),
        ToggleBgOff = Color3.fromRGB(70,70,70),
        ToggleBgOn = Color3.fromRGB(0,200,0),
        ToggleKnob = Color3.fromRGB(255,255,255),
    },
    Light = {
        PrimaryBg = Color3.fromRGB(240,240,240),
        SecondaryBg = Color3.fromRGB(220,220,220),
        Border = Color3.fromRGB(170,170,170),
        TextLight = Color3.fromRGB(0,0,0),
        TextDark = Color3.fromRGB(0,0,0),
        Accent = Color3.fromRGB(0,120,255),
        AccentSecondary = Color3.fromRGB(255,170,0),
        Danger = Color3.fromRGB(220,30,30),
        Info = Color3.fromRGB(0,180,220),
        ButtonHover = Color3.fromRGB(200,200,200),
        ButtonPressed = Color3.fromRGB(180,180,180),
        ToggleBgOff = Color3.fromRGB(200,200,200),
        ToggleBgOn = Color3.fromRGB(0,120,255),
        ToggleKnob = Color3.fromRGB(255,255,255),
    },
    Red = {
        PrimaryBg = Color3.fromRGB(30,10,10),
        SecondaryBg = Color3.fromRGB(50,20,20),
        Border = Color3.fromRGB(100,30,30),
        TextLight = Color3.fromRGB(255,200,200),
        TextDark = Color3.fromRGB(0,0,0),
        Accent = Color3.fromRGB(255,50,50),
        AccentSecondary = Color3.fromRGB(255,200,50),
        Danger = Color3.fromRGB(255,0,0),
        Info = Color3.fromRGB(200,100,100),
        ButtonHover = Color3.fromRGB(60,30,30),
        ButtonPressed = Color3.fromRGB(40,20,20),
        ToggleBgOff = Color3.fromRGB(80,40,40),
        ToggleBgOn = Color3.fromRGB(200,30,30),
        ToggleKnob = Color3.fromRGB(255,255,255),
    },
    Blue = {
        PrimaryBg = Color3.fromRGB(10,10,40),
        SecondaryBg = Color3.fromRGB(20,20,60),
        Border = Color3.fromRGB(30,30,100),
        TextLight = Color3.fromRGB(200,200,255),
        TextDark = Color3.fromRGB(0,0,0),
        Accent = Color3.fromRGB(50,150,255),
        AccentSecondary = Color3.fromRGB(200,200,50),
        Danger = Color3.fromRGB(255,0,0),
        Info = Color3.fromRGB(100,150,255),
        ButtonHover = Color3.fromRGB(30,30,70),
        ButtonPressed = Color3.fromRGB(20,20,50),
        ToggleBgOff = Color3.fromRGB(40,40,80),
        ToggleBgOn = Color3.fromRGB(50,150,255),
        ToggleKnob = Color3.fromRGB(255,255,255),
    }
}

local ThemeableObjects = {}  -- list of { object, property, role }

local function ApplyTheme(themeName)
    local theme = Themes[themeName] or Themes.Dark
    for _, entry in ipairs(ThemeableObjects) do
        local obj = entry.object
        local prop = entry.property
        local role = entry.role
        if obj and obj.Parent then
            obj[prop] = theme[role]
        end
    end
    -- update scroll bar image color (since it’s a static property)
    if activeScreenGui then
        local mainFrame = activeScreenGui:FindFirstChild("MainFrame")
        if mainFrame then
            local scrollFrame = mainFrame:FindFirstChild("ScrollFrame")
            if scrollFrame then
                scrollFrame.ScrollBarImageColor3 = theme.Border
            end
        end
    end
end

local function RegisterThemeable(object, property, role)
    table.insert(ThemeableObjects, { object = object, property = property, role = role })
end

-- 9.2 Loading Screen
local function ShowLoadingScreen()
    local guiParent = (gethui and gethui()) or game:GetService("CoreGui") or playerGui
    local loadingGui = Instance.new("ScreenGui", guiParent)
    loadingGui.Name = "OWP_Loading"
    loadingGui.ResetOnSpawn = false
    loadingGui.IgnoreGuiInset = true

    local loaderFrame = Instance.new("Frame", loadingGui)
    loaderFrame.Size = UDim2.new(0, 280, 0, 120)
    loaderFrame.Position = UDim2.new(0.5, -140, 0.5, -60)
    loaderFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    loaderFrame.BackgroundTransparency = 1
    Instance.new("UICorner", loaderFrame).CornerRadius = UDim.new(0, 16)
    local stroke = Instance.new("UIStroke", loaderFrame)
    stroke.Color = Color3.fromRGB(255, 255, 255)
    stroke.Thickness = 1.5
    stroke.Transparency = 0.7

    local titleLabel = Instance.new("TextLabel", loaderFrame)
    titleLabel.Size = UDim2.new(1, -20, 0, 30)
    titleLabel.Position = UDim2.new(0, 10, 0, 25)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "PETAPETA"
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextScaled = true

    local subtitleLabel = Instance.new("TextLabel", loaderFrame)
    subtitleLabel.Size = UDim2.new(1, -20, 0, 20)
    subtitleLabel.Position = UDim2.new(0, 10, 0, 55)
    subtitleLabel.BackgroundTransparency = 1
    subtitleLabel.Text = "SCHOOL OF NIGHTMARES"
    subtitleLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    subtitleLabel.Font = Enum.Font.Gotham
    subtitleLabel.TextScaled = true

    local creditLabel = Instance.new("TextLabel", loaderFrame)
    creditLabel.Size = UDim2.new(1, -20, 0, 16)
    creditLabel.Position = UDim2.new(0, 10, 0, 80)
    creditLabel.BackgroundTransparency = 1
    creditLabel.Text = "By OtherWisePop"
    creditLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    creditLabel.Font = Enum.Font.Gotham
    creditLabel.TextScaled = true

    -- spinner (rotating bar)
    local spinner = Instance.new("Frame", loaderFrame)
    spinner.Size = UDim2.new(0, 40, 0, 4)
    spinner.Position = UDim2.new(0.5, -20, 1, -24)
    spinner.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    spinner.BorderSizePixel = 0
    spinner.AnchorPoint = Vector2.new(0.5, 0.5)
    Instance.new("UICorner", spinner).CornerRadius = UDim.new(1, 0)
    local spinnerTween = TweenService:Create(
        spinner,
        TweenInfo.new(1, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
        { Rotation = 360 }
    )
    spinnerTween:Play()

    -- fade in
    local fadeIn = TweenService:Create(
        loaderFrame,
        TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { BackgroundTransparency = 0.2 }
    )
    fadeIn:Play()
    fadeIn.Completed:Wait()

    -- hold for 2.5 seconds
    task.wait(2.5)

    -- fade out
    local fadeOut = TweenService:Create(
        loaderFrame,
        TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { BackgroundTransparency = 1 }
    )
    fadeOut:Play()
    fadeOut.Completed:Wait()

    loadingGui:Destroy()
end

-- 9.3 Main UI Builder (fully modernized)
local function BuildUI()
    if isBuildingUI then return end
    isBuildingUI = true

    local guiParent = (gethui and gethui()) or game:GetService("CoreGui") or playerGui
    -- Destroy any previous instance
    for _, child in ipairs(guiParent:GetChildren()) do
        if string.match(child.Name, "^OWP_PetaHub") then
            pcall(function() child:Destroy() end)
        end
    end

    -- clear theme registry
    ThemeableObjects = {}

    local screenGui = Instance.new("ScreenGui", guiParent)
    screenGui.Name = GUI_NAME
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true

    -- Capsule Toggle Button (replaces old toggleButton)
    local toggleContainer = Instance.new("Frame", screenGui)
    toggleContainer.Size = UDim2.new(0, 56, 0, 30)
    toggleContainer.Position = UDim2.new(0, 10, 0, 10)
    toggleContainer.BackgroundColor3 = Themes[Config.Theme].ToggleBgOff
    toggleContainer.BorderSizePixel = 0
    toggleContainer.Draggable = true
    Instance.new("UICorner", toggleContainer).CornerRadius = UDim.new(1, 0)
    RegisterThemeable(toggleContainer, "BackgroundColor3", "ToggleBgOff") -- will be updated by toggle
    local toggleStroke = Instance.new("UIStroke", toggleContainer)
    toggleStroke.Thickness = 1.5
    RegisterThemeable(toggleStroke, "Color", "Border")

    local toggleKnob = Instance.new("Frame", toggleContainer)
    toggleKnob.Size = UDim2.new(0, 24, 0, 24)
    toggleKnob.Position = UDim2.new(0, 2, 0.5, -12)
    toggleKnob.BackgroundColor3 = Themes[Config.Theme].ToggleKnob
    toggleKnob.BorderSizePixel = 0
    toggleKnob.AnchorPoint = Vector2.new(0, 0.5)
    Instance.new("UICorner", toggleKnob).CornerRadius = UDim.new(1, 0)
    RegisterThemeable(toggleKnob, "BackgroundColor3", "ToggleKnob")

    local toggleClickArea = Instance.new("TextButton", toggleContainer)
    toggleClickArea.Size = UDim2.new(1, 0, 1, 0)
    toggleClickArea.BackgroundTransparency = 1
    toggleClickArea.Text = ""

    local function updateToggleVisual(on)
        local theme = Themes[Config.Theme]
        local bgColor = on and theme.ToggleBgOn or theme.ToggleBgOff
        toggleContainer.BackgroundColor3 = bgColor
        local knobTargetX = on and (toggleContainer.AbsoluteSize.X - toggleKnob.AbsoluteSize.X - 2) or 2
        TweenService:Create(
            toggleKnob,
            TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { Position = UDim2.new(0, knobTargetX, 0.5, -12) }
        ):Play()
    end

    if Config.GuiVisible then
        updateToggleVisual(true)
    end

    -- Main Frame (will be animated in/out)
    local mainFrame = Instance.new("Frame", screenGui)
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 220, 0, 340)
    mainFrame.Position = UDim2.new(0.5, -110, 0.1, 0)
    mainFrame.BackgroundColor3 = Themes[Config.Theme].PrimaryBg
    mainFrame.BackgroundTransparency = 1  -- start invisible for animation
    mainFrame.BorderSizePixel = 0
    mainFrame.Visible = Config.GuiVisible
    mainFrame.Draggable = true
    Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 12)
    local mainStroke = Instance.new("UIStroke", mainFrame)
    mainStroke.Thickness = 1.2
    mainStroke.Transparency = 0.6
    RegisterThemeable(mainFrame, "BackgroundColor3", "PrimaryBg")
    RegisterThemeable(mainStroke, "Color", "Border")

    mainFrame.ClipsDescendants = true  -- to hide content during resize if we animate size

    -- store original position for animation
    local originalMainPos = mainFrame.Position

    -- Theme button (above scroll list)
    local themeButton = Instance.new("TextButton", mainFrame)
    themeButton.Size = UDim2.new(1, -20, 0, 28)
    themeButton.Position = UDim2.new(0, 10, 0, 8)
    themeButton.BackgroundColor3 = Themes[Config.Theme].SecondaryBg
    themeButton.TextColor3 = Themes[Config.Theme].TextLight
    themeButton.Font = Enum.Font.SourceSansBold
    themeButton.TextScaled = true
    themeButton.Text = "Theme: " .. Config.Theme
    Instance.new("UICorner", themeButton).CornerRadius = UDim.new(0, 8)
    local themeStroke = Instance.new("UIStroke", themeButton)
    themeStroke.Thickness = 1
    themeStroke.Color = Themes[Config.Theme].Border
    themeStroke.Transparency = 0.5
    RegisterThemeable(themeButton, "BackgroundColor3", "SecondaryBg")
    RegisterThemeable(themeButton, "TextColor3", "TextLight")
    RegisterThemeable(themeStroke, "Color", "Border")

    themeButton.MouseButton1Click:Connect(function()
        local themes = {"Dark", "Light", "Red", "Blue"}
        local idx = table.find(themes, Config.Theme) or 1
        idx = idx % #themes + 1
        Config.Theme = themes[idx]
        themeButton.Text = "Theme: " .. Config.Theme
        ApplyTheme(Config.Theme)
        updateToggleVisual(Config.GuiVisible)  -- refresh toggle colors
        SaveConfig()
    end)

    -- ScrollFrame for features
    local scrollFrame = Instance.new("ScrollingFrame", mainFrame)
    scrollFrame.Name = "ScrollFrame"
    scrollFrame.Size = UDim2.new(1, 0, 1, -74)  -- leaving room for theme button + credit
    scrollFrame.Position = UDim2.new(0, 0, 0, 44)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.ScrollBarThickness = 4
    scrollFrame.ScrollBarImageColor3 = Themes[Config.Theme].Border
    scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)

    local uiListLayout = Instance.new("UIListLayout", scrollFrame)
    uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    uiListLayout.Padding = UDim.new(0, 8)
    uiListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    Instance.new("UIPadding", scrollFrame).PaddingTop = UDim.new(0, 8)

    -- Credit label
    local creditLabel = Instance.new("TextLabel", mainFrame)
    creditLabel.Size = UDim2.new(1, 0, 0, 20)
    creditLabel.Position = UDim2.new(0, 0, 1, -24)
    creditLabel.BackgroundTransparency = 1
    creditLabel.TextColor3 = Themes[Config.Theme].TextLight
    creditLabel.Font = Enum.Font.SourceSans
    creditLabel.TextScaled = true
    creditLabel.Text = "BY: OTHERWISEPOP"
    RegisterThemeable(creditLabel, "TextColor3", "TextLight")

    -- Helper to add animated hover effects
    local function applyButtonHover(button, bgRole)
        local defaultColor = Themes[Config.Theme][bgRole]
        local hoverColor = Themes[Config.Theme].ButtonHover
        local pressColor = Themes[Config.Theme].ButtonPressed

        button.MouseEnter:Connect(function()
            TweenService:Create(button, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = hoverColor}):Play()
        end)
        button.MouseLeave:Connect(function()
            TweenService:Create(button, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = defaultColor}):Play()
        end)
        button.MouseButton1Down:Connect(function()
            TweenService:Create(button, TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = pressColor}):Play()
        end)
        button.MouseButton1Up:Connect(function()
            local currentColor = defaultColor
            -- check if mouse still inside after click
            local mouse = player:GetMouse()
            if mouse and button:IsDescendantOf(screenGui) then
                local guiInset = screenGui.IgnoreGuiInset and Vector2.new(0,0) or game:GetService("GuiService"):GetGuiInset()
                local pos = Vector2.new(mouse.X, mouse.Y) - button.AbsolutePosition
                if pos.X >= 0 and pos.X <= button.AbsoluteSize.X and pos.Y >= 0 and pos.Y <= button.AbsoluteSize.Y then
                    currentColor = hoverColor
                end
            end
            TweenService:Create(button, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = currentColor}):Play()
        end)
    end

    -- Build feature buttons
    for order, feature in ipairs(FeatureList) do
        local btn = Instance.new("TextButton", scrollFrame)
        btn.Size = UDim2.new(1, -20, 0, 34)
        btn.LayoutOrder = order
        btn.TextColor3 = Themes[Config.Theme].TextLight
        btn.BackgroundColor3 = Themes[Config.Theme].SecondaryBg
        btn.Font = Enum.Font.SourceSansBold
        btn.TextScaled = true
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
        local btnStroke = Instance.new("UIStroke", btn)
        btnStroke.Thickness = 1
        btnStroke.Transparency = 0.5
        RegisterThemeable(btn, "BackgroundColor3", "SecondaryBg")
        RegisterThemeable(btn, "TextColor3", "TextLight")
        RegisterThemeable(btnStroke, "Color", "Border")

        applyButtonHover(btn, "SecondaryBg")

        local function updateVisuals()
            if not btn.Parent then return end
            if feature.Type == "Toggle" then
                btn.Text = feature.Name .. ": " .. (Config[feature.Key] and "ON" or "OFF")
            elseif feature.Type == "Cycle" then
                btn.Text = feature.Name .. ": " .. tostring(feature.CycleOptions[Config[feature.Key]])
            end
        end
        feature._updateVisuals = updateVisuals  -- keep for character respawn refresh

        btn.MouseButton1Click:Connect(function()
            if feature.Type == "Toggle" then
                Config[feature.Key] = not Config[feature.Key]
            elseif feature.Type == "Cycle" then
                Config[feature.Key] = (Config[feature.Key] % #feature.CycleOptions) + 1
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

    -- TP HUD button with modern styling
    local tpButton = Instance.new("TextButton", screenGui)
    tpButton.Size = UDim2.new(0, 120, 0, 32)
    tpButton.Position = UDim2.new(0, 10, 0, 45)
    tpButton.BackgroundColor3 = Themes[Config.Theme].SecondaryBg
    tpButton.TextColor3 = COLOR_ACCENT_GREEN  -- static green for state; or use theme?
    tpButton.Font = Enum.Font.SourceSansBold
    tpButton.TextScaled = true
    tpButton.Text = "Teleport To Key"
    tpButton.Visible = Config.TeleportHUD
    tpButton.Draggable = true
    Instance.new("UICorner", tpButton).CornerRadius = UDim.new(0, 8)
    local tpStroke = Instance.new("UIStroke", tpButton)
    tpStroke.Thickness = 1
    tpStroke.Transparency = 0.5
    RegisterThemeable(tpButton, "BackgroundColor3", "SecondaryBg")
    RegisterThemeable(tpButton, "TextColor3", "TextLight")  -- will be overridden by state updates? We'll keep state updates dynamic.
    RegisterThemeable(tpStroke, "Color", "Border")

    applyButtonHover(tpButton, "SecondaryBg")

    tpButton.MouseButton1Click:Connect(function()
        -- (existing teleport logic unchanged)
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

    -- Toggle capsule click handler
    toggleClickArea.MouseButton1Click:Connect(function()
        Config.GuiVisible = not Config.GuiVisible
        SaveConfig()
        updateToggleVisual(Config.GuiVisible)

        -- Animate mainFrame open/close
        if Config.GuiVisible then
            mainFrame.Visible = true
            mainFrame.BackgroundTransparency = 1
            mainFrame.Position = originalMainPos + UDim2.new(0, 0, 0, 12)  -- slide from below
            local openTween1 = TweenService:Create(
                mainFrame,
                TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { BackgroundTransparency = 0.03 }   -- nearly solid
            )
            local openTween2 = TweenService:Create(
                mainFrame,
                TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { Position = originalMainPos }
            )
            openTween1:Play()
            openTween2:Play()
        else
            local closeTween1 = TweenService:Create(
                mainFrame,
                TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { BackgroundTransparency = 1 }
            )
            local closeTween2 = TweenService:Create(
                mainFrame,
                TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { Position = originalMainPos + UDim2.new(0, 0, 0, 12) }
            )
            closeTween1:Play()
            closeTween2:Play()
            closeTween2.Completed:Connect(function()
                if not Config.GuiVisible then
                    mainFrame.Visible = false
                end
            end)
        end
    end)

    -- animations for initial state if visible (shouldn't happen due to fix, but safeguard)
    if Config.GuiVisible then
        mainFrame.BackgroundTransparency = 0.03
        mainFrame.Position = originalMainPos
        updateToggleVisual(true)
    end

    activeScreenGui = screenGui
    activeTpButton = tpButton
    ApplyTheme(Config.Theme)  -- set initial theme on all elements

    isBuildingUI = false
end

-- ================= 10. Initialization, Failsafes & Hooks =================

-- Show loading screen, wait for it to finish, then build UI
local loadingDone = false
coroutine.wrap(function()
    pcall(ShowLoadingScreen)
    loadingDone = true
end)()
repeat task.wait() until loadingDone

-- Build the UI (first time)
pcall(BuildUI)

-- Activate features according to saved config
for _, feature in ipairs(FeatureList) do
    if feature.Action and (Config[feature.Key] == true or feature.Type == "Cycle") then
        feature.Action(Config[feature.Key])
    end
end

-- Debounced Watchdog & Failsafe (slightly updated to rebuild modern UI)
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
                    warn("[OWP HUB] UI missing for 5+ seconds! Safety fallback: Temporarily suspending NoClip physics.")
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

-- Stabilized TP HUD Background Updater (unchanged logic, but uses tpButton dynamic colors)
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

print("✅ PETAPETA: School of Nightmares V14.5 Modern UI - Loaded")
