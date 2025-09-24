--[[
    AGTScript UI
    ---------------------------------
    Rewritten to provide a custom dark themed, tabbed interface with:
      * Header title: AGTScript
      * Tabs: Misc, Settings
      * Z key toggles entire UI visibility
      * Flight feature (toggle + keybind + speed slider) placed in Misc tab
    Note: The design is intentionally original and not an exact replica of any 3rd-party UI.
]]

-- luacheck: ignore game Enum Instance UDim UDim2 Color3 Vector3

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

-- State
local FlightEnabled = false
local FlightKey = nil
local FlightSpeed = 200 -- min 50, max 1000 in slider logic
local ToggleUIKey = Enum.KeyCode.Z
local NoclipEnabled = false
local NoclipKey = nil
-- noclip state preservation
local __noclipPrev = {} -- [part] = previous CanCollide
local __noclipDescConn = nil
local __noclipCharAddedConn = nil
-- flight humanoid state preservation
local __prevHumanoidPlatformStand = nil
local __prevHumanoidAutoRotate = nil

-- ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AGTScriptUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = player:WaitForChild("PlayerGui")

-- Main Window
local window = Instance.new("Frame")
window.Name = "Window"
window.Size = UDim2.new(0, 760, 0, 560)
window.Position = UDim2.new(0.5, -380, 0.5, -280)
window.BackgroundColor3 = Color3.fromRGB(11,11,11)
window.BorderSizePixel = 0
window.Parent = screenGui

local windowCorner = Instance.new("UICorner")
windowCorner.CornerRadius = UDim.new(0,6)
windowCorner.Parent = window

-- Header
local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1,0,0,46)
header.BackgroundColor3 = Color3.fromRGB(15,15,15)
header.BorderSizePixel = 0
header.Parent = window

local headerLine = Instance.new("Frame")
headerLine.Name = "HeaderLine"
headerLine.AnchorPoint = Vector2.new(0.5,1)
headerLine.Position = UDim2.new(0.5,0,1,0)
headerLine.Size = UDim2.new(1,0,0,1)
headerLine.BackgroundColor3 = Color3.fromRGB(40,40,40)
headerLine.BorderSizePixel = 0
headerLine.Parent = header

local title = Instance.new("TextLabel")
title.Name = "Title"
title.BackgroundTransparency = 1
title.Size = UDim2.new(0,240,1,0)
title.Position = UDim2.new(0,18,0,0)
title.Font = Enum.Font.GothamBold
title.Text = "AGTScript"
title.TextSize = 24
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.fromRGB(235,235,235)
title.Parent = header

local hint = Instance.new("TextLabel")
hint.Name = "Hint"
hint.BackgroundTransparency = 1
hint.AnchorPoint = Vector2.new(1,0)
hint.Position = UDim2.new(1,-16,0,0)
hint.Size = UDim2.new(0,200,1,0)
hint.Font = Enum.Font.Gotham
hint.Text = "Press Z to toggle UI"
hint.TextSize = 14
hint.TextXAlignment = Enum.TextXAlignment.Right
hint.TextColor3 = Color3.fromRGB(140,140,140)
hint.Parent = header

-- Sidebar
local sidebar = Instance.new("Frame")
sidebar.Name = "Sidebar"
sidebar.Position = UDim2.new(0,0,0,46)
sidebar.Size = UDim2.new(0,190,1,-46)
sidebar.BackgroundColor3 = Color3.fromRGB(17,17,17)
sidebar.BorderSizePixel = 0
sidebar.Parent = window

local sidebarLayout = Instance.new("UIListLayout")
sidebarLayout.Padding = UDim.new(0,6)
sidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder
sidebarLayout.Parent = sidebar

local sidebarPadding = Instance.new("UIPadding")
sidebarPadding.PaddingTop = UDim.new(0,12)
sidebarPadding.PaddingLeft = UDim.new(0,10)
sidebarPadding.PaddingRight = UDim.new(0,10)
sidebarPadding.Parent = sidebar

-- Content Container
local contentHolder = Instance.new("Frame")
contentHolder.Name = "ContentHolder"
contentHolder.Position = UDim2.new(0,190,0,46)
contentHolder.Size = UDim2.new(1,-190,1,-46)
contentHolder.BackgroundColor3 = Color3.fromRGB(20,20,20)
contentHolder.BorderSizePixel = 0
contentHolder.Parent = window

local contentCorner = Instance.new("UICorner")
contentCorner.CornerRadius = UDim.new(0,6)
contentCorner.Parent = contentHolder

-- Helpers
local Tabs = {}
local CurrentTab

-- track connections so we can cleanly disconnect on unload
local __connections = {}
local function safeConnect(signal, fn)
    local ok, conn = pcall(function() return signal:Connect(fn) end)
    if ok and conn then
        table.insert(__connections, conn)
        return conn
    end
    return nil
end

local function unload()
    -- stop flight and cleanup GUI
    FlightEnabled = false
    -- setFlight is declared later; guard the call in case unload is invoked early
    if type(setFlight) == "function" then
        pcall(function() setFlight(false) end)
    else
        -- fallback: attempt to remove any existing BodyVelocity named AGTFlight
        pcall(function()
            local char = player and player.Character
            if char then
                local root = char:FindFirstChild("HumanoidRootPart")
                if root then
                    local bv = root:FindFirstChild("AGTFlight")
                    if bv then
                        pcall(function() bv:Destroy() end)
                    end
                end
            end
        end)
    end
    -- ensure noclip is disabled and collisions restored
    if type(setNoclip) == "function" then
        pcall(function() setNoclip(false) end)
    else
        -- try a best-effort restore if setNoclip is missing
        pcall(function()
            for part, prev in pairs(__noclipPrev) do
                if part and part.Parent then
                    pcall(function() part.CanCollide = prev end)
                end
            end
        end)
    end
    -- clear noclip caches and disconnect noclip-specific connections
    __noclipPrev = {}
    if __noclipDescConn then pcall(function() __noclipDescConn:Disconnect() end) __noclipDescConn = nil end
    if __noclipCharAddedConn then pcall(function() __noclipCharAddedConn:Disconnect() end) __noclipCharAddedConn = nil end
    -- restore humanoid flags if they were preserved but setFlight couldn't run earlier
    pcall(function()
        local char = player and player.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                if __prevHumanoidPlatformStand ~= nil then pcall(function() hum.PlatformStand = __prevHumanoidPlatformStand end) end
                if __prevHumanoidAutoRotate ~= nil then pcall(function() hum.AutoRotate = __prevHumanoidAutoRotate end) end
            end
        end
    end)
    -- disconnect tracked connections
    for i=1, #__connections do
        local c = __connections[i]
        if c then pcall(function() c:Disconnect() end) end
        __connections[i] = nil
    end
    __connections = {}
    -- destroy the GUI
    if screenGui and screenGui.Parent then
        pcall(function() screenGui:Destroy() end)
    end
    pcall(function() print("AGTScript successfully unloaded") end)
end

local function styleButton(btn)
    btn.AutoButtonColor = false
    btn.BackgroundColor3 = Color3.fromRGB(28,28,28)
    btn.TextColor3 = Color3.fromRGB(225,225,225)
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 15
    btn.BorderSizePixel = 0
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0,5)
    corner.Parent = btn
end

local function createTab(name)
    local button = Instance.new("TextButton")
    button.Name = name .. "TabButton"
    button.Size = UDim2.new(1,0,0,40)
    button.Text = "   " .. name -- left padding for icon placeholder
    button.LayoutOrder = #Tabs + 1
    styleButton(button)
    button.Parent = sidebar

    local icon = Instance.new("Frame")
    icon.Name = "Icon"
    icon.Size = UDim2.new(0,18,0,18)
    icon.Position = UDim2.new(0,10,0.5,0)
    icon.AnchorPoint = Vector2.new(0,0.5)
    icon.BackgroundColor3 = Color3.fromRGB(85,85,85)
    icon.BorderSizePixel = 0
    icon.Parent = button
    local icCorner = Instance.new("UICorner")
    icCorner.CornerRadius = UDim.new(0,4)
    icCorner.Parent = icon

    local frame = Instance.new("Frame")
    frame.Name = name .. "Page"
    frame.Size = UDim2.new(1,0,1,0)
    frame.BackgroundTransparency = 1
    frame.Visible = false
    frame.Parent = contentHolder

    -- (removed search box to simplify UI)

    local scroll = Instance.new("ScrollingFrame")
    scroll.Name = "ScrollArea"
    -- moved up since search/top bar removed
    scroll.Position = UDim2.new(0,16,0,12)
    scroll.Size = UDim2.new(1,-32,1,-40)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 5
    scroll.CanvasSize = UDim2.new(0,0,0,0)
    scroll.Parent = frame

    local grid = Instance.new("UIGridLayout")
    grid.CellSize = UDim2.new(0.5,-12,0,230)
    grid.CellPadding = UDim2.new(0,12,0,12)
    grid.SortOrder = Enum.SortOrder.LayoutOrder
    grid.Parent = scroll

    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0,4)
    padding.PaddingTop = UDim.new(0,4)
    padding.Parent = scroll

    Tabs[name] = { Button = button, Frame = frame, GridParent = frame.ScrollArea }

    safeConnect(button.MouseEnter, function()
        if CurrentTab ~= name then
            button.BackgroundColor3 = Color3.fromRGB(38,38,38)
        end
    end)
    safeConnect(button.MouseLeave, function()
        if CurrentTab ~= name then
            button.BackgroundColor3 = Color3.fromRGB(30,30,30)
        end
    end)

    safeConnect(button.MouseButton1Click, function()
        for n,t in pairs(Tabs) do
            local active = (n == name)
            t.Frame.Visible = active
            t.Button.BackgroundColor3 = active and Color3.fromRGB(55,55,55) or Color3.fromRGB(30,30,30)
        end
        CurrentTab = name
    end)

    return frame
end

local function autoCanvas(scrollFrame, layoutObject)
    local function update()
        scrollFrame.CanvasSize = UDim2.new(0,0,0,layoutObject.AbsoluteContentSize.Y + 20)
    end
    safeConnect(layoutObject:GetPropertyChangedSignal("AbsoluteContentSize"), update)
    update()
end

local function section(parentGrid, titleText)
    local card = Instance.new("Frame")
    card.Name = titleText .. "Card"
    card.BackgroundColor3 = Color3.fromRGB(26,26,26)
    card.BorderSizePixel = 0
    card.Parent = parentGrid

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0,6)
    corner.Parent = card

    local border = Instance.new("UIStroke")
    border.Thickness = 1
    border.Color = Color3.fromRGB(40,40,40)
    border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    border.Parent = card

    local headerBar = Instance.new("TextLabel")
    headerBar.Name = "SectionTitle"
    headerBar.BackgroundTransparency = 1
    headerBar.Position = UDim2.new(0,14,0,10)
    headerBar.Size = UDim2.new(1,-28,0,22)
    headerBar.Font = Enum.Font.GothamSemibold
    headerBar.TextSize = 18
    headerBar.TextColor3 = Color3.fromRGB(230,230,230)
    headerBar.TextXAlignment = Enum.TextXAlignment.Left
    headerBar.Text = titleText
    headerBar.Parent = card

    local content = Instance.new("Frame")
    content.Name = "Content"
    content.BackgroundTransparency = 1
    content.Position = UDim2.new(0,14,0,42)
    content.Size = UDim2.new(1,-28,1,-52)
    content.Parent = card

    local list = Instance.new("UIListLayout")
    list.Name = "List"
    list.Padding = UDim.new(0,8)
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Parent = content

    return card, content
end

local function makeButton(parent, text)
    local btn = Instance.new("TextButton")
    btn.AutoButtonColor = false
    btn.Name = text:gsub("%s+","") .. "Button"
    btn.Size = UDim2.new(1,0,0,38)
    btn.Text = text
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 15
    btn.BackgroundColor3 = Color3.fromRGB(38,38,38)
    btn.TextColor3 = Color3.fromRGB(225,225,225)
    btn.BorderSizePixel = 0
    btn.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0,4)
    corner.Parent = btn
    safeConnect(btn.MouseEnter, function()
        btn.BackgroundColor3 = Color3.fromRGB(46,46,46)
    end)
    safeConnect(btn.MouseLeave, function()
        btn.BackgroundColor3 = Color3.fromRGB(38,38,38)
    end)
    return btn
end

local function makeLabel(parent, text)
    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1,0,0,18)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 14
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextColor3 = Color3.fromRGB(195,195,195)
    lbl.Text = text
    lbl.Parent = parent
    return lbl
end

local function makeToggle(parent, text, default, callback)
    local holder = Instance.new("Frame")
    holder.Name = text:gsub("%s+","") .. "Toggle"
    holder.BackgroundTransparency = 1
    holder.Size = UDim2.new(1,0,0,34)
    holder.Parent = parent

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1,-60,1,0)
    label.Font = Enum.Font.Gotham
    label.TextSize = 14
    label.TextColor3 = Color3.fromRGB(200,200,200)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = text
    label.Parent = holder

    local switch = Instance.new("TextButton")
    switch.Name = "Switch"
    switch.AutoButtonColor = false
    switch.Size = UDim2.new(0,54,0,24)
    switch.Position = UDim2.new(1,-54,0.5,0)
    switch.AnchorPoint = Vector2.new(0,0.5)
    switch.BackgroundColor3 = default and Color3.fromRGB(90,140,255) or Color3.fromRGB(50,50,50)
    switch.Text = ""
    switch.BorderSizePixel = 0
    switch.Parent = holder
    local sCorner = Instance.new("UICorner")
    sCorner.CornerRadius = UDim.new(1,0)
    sCorner.Parent = switch

    local knob = Instance.new("Frame")
    knob.Name = "Knob"
    knob.Size = UDim2.new(0,20,0,20)
    knob.Position = UDim2.new(default and 1 or 0, default and -22 or 2,0.5,0)
    knob.AnchorPoint = Vector2.new(0,0.5)
    knob.BackgroundColor3 = Color3.fromRGB(230,230,230)
    knob.BorderSizePixel = 0
    knob.Parent = switch
    local kCorner = Instance.new("UICorner")
    kCorner.CornerRadius = UDim.new(1,0)
    kCorner.Parent = knob

    local state = default
    local tweenService = game:GetService("TweenService")
    local function set(v)
        if state == v then return end
        state = v
        -- switch background updates instantly (could tween if desired)
        switch.BackgroundColor3 = v and Color3.fromRGB(90,140,255) or Color3.fromRGB(50,50,50)
        local knobGoal = UDim2.new(v and 1 or 0, v and -22 or 2, 0.5, 0)
        tweenService:Create(knob, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = knobGoal }):Play()
        callback(state)
    end
    safeConnect(switch.MouseButton1Click, function() set(not state) end)
    return {
        Set = set,
        Get = function() return state end,
        Toggle = function() set(not state) end
    }
end

local function clamp(val, lo, hi)
    if val < lo then return lo end
    if val > hi then return hi end
    return val
end

local function makeSlider(parent, text, min, max, default, callback)
    local holder = Instance.new("Frame")
    holder.Name = text .. "Slider"
    holder.BackgroundTransparency = 1
    holder.Size = UDim2.new(1,0,0,48)
    holder.Parent = parent

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Gotham
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextColor3 = Color3.fromRGB(185,185,185)
    label.Text = text .. ": " .. default
    label.Size = UDim2.new(1,0,0,20)
    label.Parent = holder

    local bar = Instance.new("Frame")
    bar.Name = "Bar"
    bar.Size = UDim2.new(1,0,0,6)
    bar.Position = UDim2.new(0,0,0,30)
    bar.BackgroundColor3 = Color3.fromRGB(60,60,60)
    bar.BorderSizePixel = 0
    bar.Parent = holder
    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(0,3)
    barCorner.Parent = bar

    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.BackgroundColor3 = Color3.fromRGB(120,120,120)
    fill.BorderSizePixel = 0
    fill.Size = UDim2.new((default-min)/(max-min),0,1,0)
    fill.Parent = bar
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0,3)
    fillCorner.Parent = fill

    local knob = Instance.new("Frame")
    knob.Name = "Knob"
    knob.Size = UDim2.new(0,14,0,14)
    knob.AnchorPoint = Vector2.new(0.5,0.5)
    knob.Position = UDim2.new(fill.Size.X.Scale,0,0.5,0)
    knob.BackgroundColor3 = Color3.fromRGB(200,200,200)
    knob.BorderSizePixel = 0
    knob.Parent = bar
    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1,0)
    knobCorner.Parent = knob

    local dragging = false
    safeConnect(knob.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
        end
    end)
    safeConnect(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    safeConnect(UserInputService.InputChanged, function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local x = (UserInputService:GetMouseLocation().X - bar.AbsolutePosition.X)
            local pct = clamp(x / bar.AbsoluteSize.X,0,1)
            fill.Size = UDim2.new(pct,0,1,0)
            knob.Position = UDim2.new(pct,0,0.5,0)
            local val = math.floor(min + (max-min)*pct)
            label.Text = text .. ": " .. val
            callback(val)
        end
    end)
end

local function makeKeybind(parent, text, initialKey, onChange)
    local holder = Instance.new("Frame")
    holder.Name = text .. "Keybind"
    holder.Size = UDim2.new(1,0,0,40)
    holder.BackgroundTransparency = 1
    holder.Parent = parent

    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(0.5,-6,1,0)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 14
    lbl.TextColor3 = Color3.fromRGB(185,185,185)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = text
    lbl.Parent = holder

    local btn = Instance.new("TextButton")
    btn.Name = "BindButton"
    btn.Size = UDim2.new(0.5,-6,1,0)
    btn.Position = UDim2.new(0.5,6,0,0)
    btn.BackgroundColor3 = Color3.fromRGB(50,50,50)
    btn.Text = initialKey.Name
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 14
    btn.TextColor3 = Color3.fromRGB(220,220,220)
    btn.BorderSizePixel = 0
    btn.Parent = holder
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0,4)
    corner.Parent = btn

    safeConnect(btn.MouseButton1Click, function()
        btn.Text = "..."
        local connection
        connection = UserInputService.InputBegan:Connect(function(inp, gp)
            if not gp and inp.UserInputType == Enum.UserInputType.Keyboard then
                onChange(inp.KeyCode)
                btn.Text = inp.KeyCode.Name
                connection:Disconnect()
            end
        end)
    end)
end

-- Build Tabs
local miscFrame = createTab("Misc")
local settingsFrame = createTab("Settings")
-- autoCanvas after sections created (grid layout auto, so handled later)

-- Misc Tab Content
-- Player Card (compact layout)
local playerCard, playerContent = section(Tabs["Misc"].GridParent, "Player")

-- Inline toggle + keybind row
-- generic inline bind + toggle row
local function makeInlineBindToggle(parent, labelText, initialKey, toggleCallback, keySetter)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1,0,0,40)
    row.BackgroundTransparency = 1
    row.Parent = parent

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Position = UDim2.new(0,0,0,0)
    label.Size = UDim2.new(0,100,1,0)
    label.Font = Enum.Font.Gotham
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextColor3 = Color3.fromRGB(200,200,200)
    label.Text = labelText
    label.Parent = row

    local keyBtn = Instance.new("TextButton")
    keyBtn.Name = labelText:gsub("%s+","") .. "KeyBtn"
    keyBtn.Size = UDim2.new(0,28,0,28)
    keyBtn.Position = UDim2.new(0,110,0.5,0)
    keyBtn.AnchorPoint = Vector2.new(0,0.5)
    keyBtn.BackgroundColor3 = Color3.fromRGB(50,50,50)
    keyBtn.Text = initialKey and initialKey.Name or "-"
    keyBtn.Font = Enum.Font.Gotham
    keyBtn.TextSize = 14
    keyBtn.TextColor3 = Color3.fromRGB(220,220,220)
    keyBtn.BorderSizePixel = 0
    keyBtn.Parent = row
    keyBtn.TextYAlignment = Enum.TextYAlignment.Center
    local kbCorner = Instance.new("UICorner")
    kbCorner.CornerRadius = UDim.new(0,6)
    kbCorner.Parent = keyBtn

    local switch = Instance.new("TextButton")
    switch.Name = "Switch"
    switch.AutoButtonColor = false
    switch.Size = UDim2.new(0,54,0,24)
    switch.Position = UDim2.new(1,-60,0.5,0)
    switch.AnchorPoint = Vector2.new(0,0.5)
    switch.BackgroundColor3 = Color3.fromRGB(50,50,50)
    switch.Text = ""
    switch.BorderSizePixel = 0
    switch.Parent = row
    local sCorner = Instance.new("UICorner")
    sCorner.CornerRadius = UDim.new(1,0)
    sCorner.Parent = switch

    local knob = Instance.new("Frame")
    knob.Name = "Knob"
    knob.Size = UDim2.new(0,18,0,18)
    knob.Position = UDim2.new(0,2,0.5,0)
    knob.AnchorPoint = Vector2.new(0,0.5)
    knob.BackgroundColor3 = Color3.fromRGB(230,230,230)
    knob.BorderSizePixel = 0
    knob.Parent = switch
    local kCorner = Instance.new("UICorner")
    kCorner.CornerRadius = UDim.new(1,0)
    kCorner.Parent = knob

    local state = false
    local tweenService = game:GetService("TweenService")
    local function set(v)
        if state == v then return end
        state = v
        switch.BackgroundColor3 = v and Color3.fromRGB(90,140,255) or Color3.fromRGB(50,50,50)
        local knobGoal = UDim2.new(v and 1 or 0, v and -20 or 2, 0.5, 0)
        tweenService:Create(knob, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = knobGoal }):Play()
        toggleCallback(v)
    end

    safeConnect(switch.MouseButton1Click, function()
        set(not state)
    end)

    safeConnect(keyBtn.MouseButton1Click, function()
        keyBtn.Text = "..."
        local conn
        conn = UserInputService.InputBegan:Connect(function(inp, gp)
            if not gp and inp.UserInputType == Enum.UserInputType.Keyboard then
                if keySetter then keySetter(inp.KeyCode) end
                keyBtn.Text = inp.KeyCode.Name
                conn:Disconnect()
            end
        end)
    end)

    return { Set = set, Get = function() return state end, Toggle = function() set(not state) end, KeyButton = keyBtn }
end

-- compact slider (smaller height)
local function makeCompactSlider(parent, text, min, max, default, callback)
    local holder = Instance.new("Frame")
    holder.Name = text .. "CompactSlider"
    holder.BackgroundTransparency = 1
    holder.Size = UDim2.new(1,0,0,34)
    holder.Parent = parent

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextColor3 = Color3.fromRGB(185,185,185)
    label.Text = text .. ": " .. default
    label.Size = UDim2.new(1,0,0,18)
    label.Parent = holder

    local bar = Instance.new("Frame")
    bar.Name = "Bar"
    bar.Size = UDim2.new(1,0,0,4)
    bar.Position = UDim2.new(0,0,0,20)
    bar.BackgroundColor3 = Color3.fromRGB(60,60,60)
    bar.BorderSizePixel = 0
    bar.Parent = holder
    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(0,2)
    barCorner.Parent = bar

    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.BackgroundColor3 = Color3.fromRGB(120,120,120)
    fill.BorderSizePixel = 0
    fill.Size = UDim2.new((default-min)/(max-min),0,1,0)
    fill.Parent = bar
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0,2)
    fillCorner.Parent = fill

    local knob = Instance.new("Frame")
    knob.Name = "Knob"
    knob.Size = UDim2.new(0,12,0,12)
    knob.AnchorPoint = Vector2.new(0.5,0.5)
    knob.Position = UDim2.new(fill.Size.X.Scale,0,0.5,0)
    knob.BackgroundColor3 = Color3.fromRGB(200,200,200)
    knob.BorderSizePixel = 0
    knob.Parent = bar
    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1,0)
    knobCorner.Parent = knob

    local dragging = false
    safeConnect(knob.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
        end
    end)
    safeConnect(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    safeConnect(UserInputService.InputChanged, function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local x = (UserInputService:GetMouseLocation().X - bar.AbsolutePosition.X)
            local pct = clamp(x / bar.AbsoluteSize.X,0,1)
            fill.Size = UDim2.new(pct,0,1,0)
            knob.Position = UDim2.new(pct,0,0.5,0)
            local val = math.floor(min + (max-min)*pct)
            label.Text = text .. ": " .. val
            callback(val)
        end
    end)
end

local flightCard, flightContent = playerCard, playerContent
local flightInline = makeInlineBindToggle(flightContent, "Flight", FlightKey, function(v)
    FlightEnabled = v
end, function(k) FlightKey = k end)
local flightToggle = flightInline
-- compact slider for speed
makeCompactSlider(flightContent, "Flight Speed", 50, 1000, FlightSpeed, function(val)
    FlightSpeed = val
end)

-- Noclip setup
local noclipCard, noclipContent = playerCard, playerContent

local function applyNoclipToCharacter(char)
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            -- preserve previous value only once
            if __noclipPrev[part] == nil then
                __noclipPrev[part] = part.CanCollide
            end
            -- set noclip
            pcall(function() part.CanCollide = false end)
        end
    end
    -- watch for parts added after enabling (e.g. accessories)
    if __noclipDescConn then
        pcall(function() __noclipDescConn:Disconnect() end)
        __noclipDescConn = nil
    end
    do
        local char = player.Character
        if char and char.DescendantAdded then
            __noclipDescConn = char.DescendantAdded:Connect(function(desc)
                if desc and desc:IsA("BasePart") then
                    if __noclipPrev[desc] == nil then
                        __noclipPrev[desc] = desc.CanCollide
                    end
                    pcall(function() desc.CanCollide = false end)
                end
            end)
        end
    end
    if __noclipDescConn then table.insert(__connections, __noclipDescConn) end
end

local function restoreNoclipFromCharacter()
    for part, prev in pairs(__noclipPrev) do
        if part and part.Parent then
            pcall(function() part.CanCollide = prev end)
        end
    end
    __noclipPrev = {}
    if __noclipDescConn then
        pcall(function() __noclipDescConn:Disconnect() end)
        __noclipDescConn = nil
    end
end

local function setNoclip(active)
    -- enable/disable noclip and handle respawns
    NoclipEnabled = active and true or false
    if NoclipEnabled then
        local char = player.Character
        if char then
            applyNoclipToCharacter(char)
        end
        -- reapply on respawn
        if __noclipCharAddedConn then
            pcall(function() __noclipCharAddedConn:Disconnect() end)
            __noclipCharAddedConn = nil
        end
        __noclipCharAddedConn = player.CharacterAdded:Connect(function(newChar)
            -- small delay to allow parts to be created
            wait(0.1)
            applyNoclipToCharacter(newChar)
        end)
        if __noclipCharAddedConn then table.insert(__connections, __noclipCharAddedConn) end
    else
        -- restore saved CanCollide states
        restoreNoclipFromCharacter()
        if __noclipCharAddedConn then
            pcall(function() __noclipCharAddedConn:Disconnect() end)
            __noclipCharAddedConn = nil
        end
        -- attempt to recover humanoid physics so player isn't stuck in ground
        pcall(function()
            local char = player.Character
            if char then
                local root = char:FindFirstChild("HumanoidRootPart")
                local hum = char:FindFirstChildOfClass("Humanoid")
                if root and root:IsA("BasePart") then
                    -- stop momentum
                    root.Velocity = Vector3.new(0,0,0)
                    -- nudge up a little to avoid getting stuck
                    root.CFrame = root.CFrame + Vector3.new(0,3,0)
                end
                if hum then
                    pcall(function() hum.PlatformStand = false end)
                end
            end
        end)
    end
end

local noclipInline = makeInlineBindToggle(flightContent, "Noclip", NoclipKey, function(v)
    setNoclip(v)
end, function(k) NoclipKey = k end)

local miscInfoCard, miscInfoContent = section(Tabs["Misc"].GridParent, "Info")
makeLabel(miscInfoContent, "Welcome to AGTScript Misc tab.")
makeLabel(miscInfoContent, "More features coming soon.")

-- Settings Tab Content
local uiCard, uiContent = section(Tabs["Settings"].GridParent, "Interface")
-- Toggle UI keybind row (small vertical keybox like flight)
local uiRow = Instance.new("Frame")
uiRow.Size = UDim2.new(1,0,0,40)
uiRow.BackgroundTransparency = 1
uiRow.Parent = uiContent

local uiLabel = Instance.new("TextLabel")
uiLabel.BackgroundTransparency = 1
uiLabel.Position = UDim2.new(0,0,0,0)
uiLabel.Size = UDim2.new(0,200,1,0)
uiLabel.Font = Enum.Font.Gotham
uiLabel.TextSize = 14
uiLabel.TextXAlignment = Enum.TextXAlignment.Left
uiLabel.TextColor3 = Color3.fromRGB(200,200,200)
uiLabel.Text = "Toggle UI Key"
uiLabel.Parent = uiRow

local uiKeyBtn = Instance.new("TextButton")
uiKeyBtn.Name = "ToggleKeyBtn"
uiKeyBtn.Size = UDim2.new(0,28,0,28)
uiKeyBtn.Position = UDim2.new(0,210,0.5,0)
uiKeyBtn.AnchorPoint = Vector2.new(0,0.5)
uiKeyBtn.BackgroundColor3 = Color3.fromRGB(50,50,50)
uiKeyBtn.Text = ToggleUIKey.Name
uiKeyBtn.Font = Enum.Font.Gotham
uiKeyBtn.TextSize = 14
uiKeyBtn.TextColor3 = Color3.fromRGB(220,220,220)
uiKeyBtn.BorderSizePixel = 0
uiKeyBtn.Parent = uiRow
local uiKbCorner = Instance.new("UICorner")
uiKbCorner.CornerRadius = UDim.new(0,6)
uiKbCorner.Parent = uiKeyBtn

safeConnect(uiKeyBtn.MouseButton1Click, function()
    uiKeyBtn.Text = "..."
    local conn
    conn = UserInputService.InputBegan:Connect(function(inp, gp)
        if not gp and inp.UserInputType == Enum.UserInputType.Keyboard then
            ToggleUIKey = inp.KeyCode
            uiKeyBtn.Text = inp.KeyCode.Name
            conn:Disconnect()
        end
    end)
end)

-- Unload Menu button (full-width rectangular row)
local unloadBtn = Instance.new("TextButton")
unloadBtn.Name = "UnloadButton"
unloadBtn.Size = UDim2.new(1,0,0,38)
unloadBtn.BackgroundColor3 = Color3.fromRGB(38,38,38)
unloadBtn.BorderSizePixel = 0
unloadBtn.Font = Enum.Font.Gotham
unloadBtn.TextSize = 15
unloadBtn.TextColor3 = Color3.fromRGB(225,225,225)
unloadBtn.Text = "Unload Menu"
unloadBtn.Parent = uiContent
local uCorner = Instance.new("UICorner")
uCorner.CornerRadius = UDim.new(0,4)
uCorner.Parent = unloadBtn
safeConnect(unloadBtn.MouseButton1Click, function()
    unload()
end)
makeLabel(uiContent, "Only Misc & Settings tabs are active.")

-- Activate first tab manually
for n,t in pairs(Tabs) do
    local active = (n=="Misc")
    t.Frame.Visible = active
    t.Button.BackgroundColor3 = active and Color3.fromRGB(55,55,55) or Color3.fromRGB(30,30,30)
    if active then CurrentTab = n end
end

-- Dragging the window by header
do
    local dragging = false
    local dragStart, startPos
    safeConnect(header.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = window.Position
        end
    end)
    safeConnect(header.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    safeConnect(UserInputService.InputChanged, function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            window.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

-- Flight Implementation
local function setFlight(active)
    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if active then
        -- preserve humanoid state
        if hum then
            if __prevHumanoidPlatformStand == nil then __prevHumanoidPlatformStand = hum.PlatformStand end
            if __prevHumanoidAutoRotate == nil then __prevHumanoidAutoRotate = hum.AutoRotate end
            pcall(function() hum.PlatformStand = true end)
            pcall(function() hum.AutoRotate = false end)
        end

        -- create or ensure BodyVelocity
        local bv = root:FindFirstChild("AGTFlight")
        if not bv then
            bv = Instance.new("BodyVelocity")
            bv.Name = "AGTFlight"
            -- stronger force to reliably counter gravity and movement
            bv.MaxForce = Vector3.new(1e6,1e6,1e6)
            bv.Velocity = Vector3.new(0,0,0)
            bv.Parent = root
        end

        -- create BodyGyro to control orientation (rotate with camera)
        local bg = root:FindFirstChild("AGTFlightGyro")
        if not bg then
            bg = Instance.new("BodyGyro")
            bg.Name = "AGTFlightGyro"
            bg.MaxTorque = Vector3.new(1e7,1e7,1e7)
            bg.P = 3000
            bg.Parent = root
        end
    else
        -- remove flight controllers
        local bv = root:FindFirstChild("AGTFlight")
        if bv then pcall(function() bv:Destroy() end) end
        local bg = root:FindFirstChild("AGTFlightGyro")
        if bg then pcall(function() bg:Destroy() end) end

        -- restore humanoid state
        if hum then
            if __prevHumanoidPlatformStand ~= nil then pcall(function() hum.PlatformStand = __prevHumanoidPlatformStand end) end
            if __prevHumanoidAutoRotate ~= nil then pcall(function() hum.AutoRotate = __prevHumanoidAutoRotate end) end
            __prevHumanoidPlatformStand = nil
            __prevHumanoidAutoRotate = nil
        end
    end
end

-- Input Handling
safeConnect(UserInputService.InputBegan, function(input, gpe)
    if gpe then return end
    if input.KeyCode == FlightKey then
        if type(flightToggle) == "table" and type(flightToggle.Toggle) == "function" then
            pcall(function() flightToggle.Toggle() end)
        end
    elseif input.KeyCode == ToggleUIKey then
        if screenGui and type(screenGui.Enabled) ~= "nil" then
            pcall(function() screenGui.Enabled = not screenGui.Enabled end)
        end
    elseif input.KeyCode == NoclipKey then
        if type(noclipInline) == "table" and type(noclipInline.Toggle) == "function" then
            pcall(function() noclipInline.Toggle() end)
        end
    end
end)

safeConnect(RunService.RenderStepped, function()
    setFlight(FlightEnabled)
    if FlightEnabled then
        local char = player.Character
        if char then
            local root = char:FindFirstChild("HumanoidRootPart")
            local bv = root and root:FindFirstChild("AGTFlight")
            if bv then
                local move = Vector3.zero
                local cam = workspace.CurrentCamera
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then move = move + cam.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then move = move - cam.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then move = move - cam.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then move = move + cam.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0,1,0) end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then move = move - Vector3.new(0,1,0) end
                if move.Magnitude > 0 then move = move.Unit end
                bv.Velocity = move * FlightSpeed
                -- if a gyro exists, orient the character to the camera's horizontal facing
                local bg = root:FindFirstChild("AGTFlightGyro")
                if bg then
                    local cam = workspace.CurrentCamera
                    if cam then
                            local look = cam.CFrame.LookVector
                            -- use full look vector (includes pitch) so the character can pitch as well as yaw
                            if look.Magnitude > 0 then
                                local target = CFrame.new(root.Position, root.Position + look)
                                pcall(function() bg.CFrame = target end)
                            end
                    end
                end
            end
        end
    end
end)

print("AGTScript UI loaded. Press Z to toggle.")