-- ================= 0. SINGLETON CHECK & AUTO-QUEUE =================
if _G.OWP_Hub_Running then return end
_G.OWP_Hub_Running = true

local SCRIPT_URL = "https://raw.githubusercontent.com/OWpop/jubilant-doodle/main/main.lua"
if queue_on_teleport then
    queue_on_teleport('loadstring(game:HttpGet("' .. SCRIPT_URL .. '?t="..tostring(tick())))()')
end

--[[
    PETAPETA: School of Nightmares V14.5 (Step 4.1: Shell & Loader)
    By: OtherWisePop
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

local GUI_NAME = "OWP_PetaHub_V14_5_" .. tostring(math.random(10000, 99999))
local CONFIG_FILE_NAME = "OWP_PetaHub_Config.json"
local FONT_BOLD = Enum.Font.SourceSansBold

-- Colors
local COLOR_PRIMARY_BG = Color3.fromRGB(20, 20, 20)
local COLOR_SECONDARY_BG = Color3.fromRGB(30, 30, 30)
local COLOR_BORDER = Color3.fromRGB(60, 60, 60)
local COLOR_TEXT_LIGHT = Color3.fromRGB(240, 240, 240)
local COLOR_TEXT_DARK = Color3.fromRGB(0, 0, 0)
local COLOR_ACCENT_GREEN = Color3.fromRGB(0, 255, 120)
local COLOR_ACCENT_RED = Color3.fromRGB(255, 60, 60)
local COLOR_ACCENT_CYAN = Color3.fromRGB(0, 200, 255)

-- ================= 2. Centralized State =================
local Config = {
    GuiVisible = false, -- Forced false on load for Step 4.1
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

-- Logic/Constants placeholders to keep architectural consistency
local WALK_SPEEDS = {16, 20, 30, 40, 50}
local IMPORTANT_ITEM_NAMES = { "key", "key_neon", "key_ver2" }
local RELATIVE_Y_BOUND = 250  
local RELATIVE_XZ_BOUND = 2500 

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
        local json = HttpService:JSONEncode(Config)
        writefile(CONFIG_FILE_NAME, json)
    end)
end

LoadConfig()
Config.GuiVisible = false -- Explicit override for Step 4.1 animation requirements

-- ================= 4. Logic Placeholders (Unchanged) =================
local function isPlayerHoldingAnyKey() return false end
local function isItemOnGround(obj) return true end
local function isWithinRelativeBounds(targetPos, playerPos) return true end
local function cleanupAllEsp() end
local function updateEspBeamsThrottled() end

-- ================= 9. UI Generation (Step 4.1: Shell & Loader) =================
local activeScreenGui = nil
local activeMainFrame = nil
local isBuildingUI = false

local function CreateLoader(guiParent)
    local loaderGui = Instance.new("ScreenGui", guiParent)
    loaderGui.Name = "OWP_PetaLoader"
    loaderGui.DisplayOrder = 100
    
    local bg = Instance.new("Frame", loaderGui)
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    bg.BorderSizePixel = 0
    
    local text = Instance.new("TextLabel", bg)
    text.Size = UDim2.new(1, 0, 0, 100)
    text.Position = UDim2.new(0, 0, 0.5, -50)
    text.BackgroundTransparency = 1
    text.TextColor3 = COLOR_TEXT_LIGHT
    text.Font = Enum.Font.SourceSansLight
    text.TextSize = 24
    text.Text = "PETAPETA: School of Nightmares\nBy: OTHERWISEPOP"
    text.TextTransparency = 1
    
    -- Fade In Text
    TweenService:Create(text, TweenInfo.new(1.5), {TextTransparency = 0}):Play()
    
    task.delay(4, function()
        -- Fade Out All
        local fadeOut = TweenService:Create(text, TweenInfo.new(1), {TextTransparency = 1})
        local fadeBg = TweenService:Create(bg, TweenInfo.new(1), {BackgroundTransparency = 1})
        fadeOut:Play()
        fadeBg:Play()
        fadeBg.Completed:Connect(function()
            loaderGui:Destroy()
        end)
    end)
end

local function BuildUI()
    local guiParent = (gethui and gethui()) or game:GetService("CoreGui") or playerGui
    for _, child in ipairs(guiParent:GetChildren()) do
        if string.match(child.Name, "^OWP_PetaHub") then pcall(function() child:Destroy() end) end
    end

    local screenGui = Instance.new("ScreenGui", guiParent)
    screenGui.Name = GUI_NAME
    screenGui.ResetOnSpawn = false
    activeScreenGui = screenGui

    -- Toggle Button
    local toggleButton = Instance.new("TextButton", screenGui)
    toggleButton.Size = UDim2.new(0, 80, 0, 30)
    toggleButton.Position = UDim2.new(0, 10, 0, 10)
    toggleButton.Text = "OWP HUB"
    toggleButton.BackgroundColor3 = COLOR_PRIMARY_BG
    toggleButton.TextColor3 = COLOR_ACCENT_GREEN
    toggleButton.Font = FONT_BOLD
    toggleButton.TextSize = 14
    Instance.new("UICorner", toggleButton).CornerRadius = UDim.new(0, 6)
    local toggleStroke = Instance.new("UIStroke", toggleButton)
    toggleStroke.Color = COLOR_BORDER
    toggleStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

    -- Main Hub Frame
    local mainFrame = Instance.new("Frame", screenGui)
    mainFrame.Size = UDim2.new(0, 300, 0, 400)
    mainFrame.Position = UDim2.new(0.5, -150, 1, 50) -- Start off-screen
    mainFrame.BackgroundColor3 = COLOR_PRIMARY_BG
    mainFrame.BorderSizePixel = 0
    mainFrame.Visible = false
    activeMainFrame = mainFrame
    
    Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 10)
    local mainStroke = Instance.new("UIStroke", mainFrame)
    mainStroke.Color = COLOR_BORDER
    mainStroke.Thickness = 1.5

    -- Header
    local header = Instance.new("Frame", mainFrame)
    header.Size = UDim2.new(1, 0, 0, 40)
    header.BackgroundColor3 = COLOR_SECONDARY_BG
    header.BorderSizePixel = 0
    Instance.new("UICorner", header).CornerRadius = UDim.new(0, 10)
    -- Cover bottom rounded corners of header
    local cover = Instance.new("Frame", header)
    cover.Size = UDim2.new(1, 0, 0.5, 0)
    cover.Position = UDim2.new(0, 0, 0.5, 0)
    cover.BackgroundColor3 = COLOR_SECONDARY_BG
    cover.BorderSizePixel = 0

    local title = Instance.new("TextLabel", header)
    title.Size = UDim2.new(1, -80, 1, 0)
    title.Position = UDim2.new(0, 40, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "PETAPETA: School of Nightmares BY: OtherWisePop"
    title.TextColor3 = COLOR_TEXT_LIGHT
    title.Font = FONT_BOLD
    title.TextSize = 12
    title.TextWrapped = true

    -- Window Controls
    local controls = Instance.new("Frame", header)
    controls.Size = UDim2.new(0, 80, 1, 0)
    controls.Position = UDim2.new(1, -80, 0, 0)
    controls.BackgroundTransparency = 1

    local closeBtn = Instance.new("TextButton", controls)
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -35, 0.5, -15)
    closeBtn.BackgroundTransparency = 1
    closeBtn.Text = "X"
    closeBtn.TextColor3 = COLOR_ACCENT_RED
    closeBtn.Font = FONT_BOLD
    closeBtn.TextSize = 18

    local minBtn = Instance.new("TextButton", controls)
    minBtn.Size = UDim2.new(0, 30, 0, 30)
    minBtn.Position = UDim2.new(0, 5, 0.5, -15)
    minBtn.BackgroundTransparency = 1
    minBtn.Text = "-"
    minBtn.TextColor3 = COLOR_TEXT_LIGHT
    minBtn.Font = FONT_BOLD
    minBtn.TextSize = 22

    -- Animation Logic
    local function ToggleMenu()
        Config.GuiVisible = not Config.GuiVisible
        if Config.GuiVisible then
            mainFrame.Visible = true
            mainFrame:TweenPosition(UDim2.new(0.5, -150, 0.5, -200), "Out", "Quart", 0.5, true)
            TweenService:Create(mainFrame, TweenInfo.new(0.5), {BackgroundTransparency = 0}):Play()
        else
            mainFrame:TweenPosition(UDim2.new(0.5, -150, 1, 50), "In", "Quart", 0.5, true, function()
                mainFrame.Visible = false
            end)
        end
        SaveConfig()
    end

    toggleButton.MouseButton1Click:Connect(ToggleMenu)
    minBtn.MouseButton1Click:Connect(ToggleMenu)
    closeBtn.MouseButton1Click:Connect(function()
        screenGui:Destroy()
        activeScreenGui = nil
    end)

    -- Draggable (Simple)
    local dragging, dragInput, dragStart, startPos
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
        end
    end)
    header.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    game:GetService("UserInputService").InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement and dragging then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    CreateLoader(guiParent)
end

-- ================= 10. Initialization & Watchdog =================
if not isBuildingUI then
    isBuildingUI = true
    pcall(BuildUI)
    isBuildingUI = false
end

task.spawn(function()
    while task.wait(1) do
        if not activeScreenGui or not activeScreenGui.Parent then
            if not isBuildingUI then
                isBuildingUI = true
                task.wait(2)
                pcall(BuildUI)
                isBuildingUI = false
            end
        end
    end
end)

print("✅ PETAPETA Step 4.1 Shell Loaded")
