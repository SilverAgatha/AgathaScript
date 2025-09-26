--[[
  Advanced UI recreation approximating the style / layout of the provided screenshot.
  Focus: VISUAL FIDELITY (colors, spacing, typography feel, panel layout, nav, status bar).
  No gameplay / exploit features implemented; all controls are placeholders.

  Notes:
  * Color + spacing choices are hand‑tuned by eye from the screenshot (may refine further).
  * Brand text kept generic. Replace as desired.
  * Pure Luau (Roblox) – expects Gotham family fonts.
  * Built for easy extension: factories for sections, buttons, toggles below.
]]

-- Destroy previous instance if re-run
local existing = game:GetService("CoreGui"):FindFirstChild("AgathaUI") or game.Players.LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("AgathaUI")
if existing then existing:Destroy() end

local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AgathaUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = playerGui

-- Theme palette (eyeballed from screenshot)
local colors = {
    bgWindow        = Color3.fromRGB(11,11,11),
    bgSidebar       = Color3.fromRGB(9,9,9),
    navIdle         = Color3.fromRGB(20,20,20),
    navHover        = Color3.fromRGB(34,34,34),
    navActive       = Color3.fromRGB(26,26,26),
    panel           = Color3.fromRGB(25,25,25),
    panelBorder     = Color3.fromRGB(45,45,45),
    controlIdle     = Color3.fromRGB(38,38,38),
    controlDisabled = Color3.fromRGB(31,31,31),
    highlight       = Color3.fromRGB(54,54,54),
    strokeSoft      = Color3.fromRGB(60,60,60),
    accent          = Color3.fromRGB(255,170,0),
    text            = Color3.fromRGB(230,230,230),
    textDim         = Color3.fromRGB(150,150,150),
    textFaint       = Color3.fromRGB(110,110,110),
    toggleOn        = Color3.fromRGB(240,240,240),
    toggleTrack     = Color3.fromRGB(34,34,34),
    toggleTrackOn   = Color3.fromRGB(46,46,46)
}

-- Main window
local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 740, 0, 540)
Main.Position = UDim2.new(0.5, -370, 0.5, -270)
Main.BackgroundColor3 = colors.bgWindow
Main.BorderSizePixel = 0
Main.Parent = ScreenGui

-- Soft shadow
local shadow = Instance.new("ImageLabel")
shadow.Name = "Shadow"
shadow.ZIndex = 0
shadow.BackgroundTransparency = 1
shadow.Image = "rbxassetid://5028857084"
shadow.ImageTransparency = 0.4
shadow.ScaleType = Enum.ScaleType.Slice
shadow.SliceCenter = Rect.new(24,24,276,276)
shadow.Size = UDim2.new(1, 32, 1, 32)
shadow.Position = UDim2.new(0, -16, 0, -16)
shadow.Parent = Main

-- Dragging logic
 do
    local dragging, dragStart, startPos
    local dragTarget = Main
    local UIS = game:GetService("UserInputService")
    dragTarget.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = dragTarget.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            dragTarget.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
 end

-- Sidebar
local Sidebar = Instance.new("Frame")
Sidebar.Name = "Sidebar"
Sidebar.Size = UDim2.new(0, 185, 1, 0)
Sidebar.BackgroundColor3 = colors.bgSidebar
Sidebar.BorderSizePixel = 0
Sidebar.Parent = Main

local sideLayout = Instance.new("UIListLayout")
sideLayout.SortOrder = Enum.SortOrder.LayoutOrder
sideLayout.Padding = UDim.new(0, 4)
sideLayout.Parent = Sidebar

local sidePadding = Instance.new("UIPadding")
sidePadding.PaddingTop = UDim.new(0, 52)
sidePadding.PaddingLeft = UDim.new(0, 8)
sidePadding.PaddingRight = UDim.new(0, 8)
sidePadding.Parent = Sidebar

-- Title bar
local TitleBar = Instance.new("Frame")
TitleBar.Name = "TitleBar"
TitleBar.Size = UDim2.new(1, 0, 0, 50)
TitleBar.BackgroundColor3 = colors.bgSidebar
TitleBar.BorderSizePixel = 0
TitleBar.Parent = Main

local TitleText = Instance.new("TextLabel")
TitleText.Name = "Title"
TitleText.BackgroundTransparency = 1
TitleText.Position = UDim2.new(0, 12, 0, 0)
TitleText.Size = UDim2.new(0, 160, 1, 0)
TitleText.Font = Enum.Font.GothamSemibold
TitleText.Text = "AX-SCRIPTS"
TitleText.TextColor3 = colors.text
TitleText.TextSize = 20
TitleText.TextXAlignment = Enum.TextXAlignment.Left
TitleText.Parent = TitleBar

-- Search box (visual only)
local SearchBox = Instance.new("Frame")
SearchBox.Name = "Search"
SearchBox.Size = UDim2.new(0, 300, 0, 32)
SearchBox.Position = UDim2.new(0, 200, 0, 9)
SearchBox.BackgroundColor3 = colors.panel
SearchBox.BorderSizePixel = 0
SearchBox.Parent = TitleBar
local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0,6)
uiCorner.Parent = SearchBox
local SearchText = Instance.new("TextLabel")
SearchText.BackgroundTransparency = 1
SearchText.Size = UDim2.new(1,-16,1,0)
SearchText.Position = UDim2.new(0,8,0,0)
SearchText.Font = Enum.Font.Gotham
SearchText.Text = "Search"
SearchText.TextColor3 = colors.textDim
SearchText.TextSize = 14
SearchText.TextXAlignment = Enum.TextXAlignment.Left
SearchText.Parent = SearchBox

-- Nav button factory
local function createNavButton(text)
    local btn = Instance.new("TextButton")
    btn.Name = text .. "Button"
    btn.Size = UDim2.new(1, 0, 0, 38)
    btn.AutoButtonColor = false
    btn.Text = text
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 14
    btn.TextColor3 = colors.text
    btn.BackgroundColor3 = colors.navIdle
    btn.BorderSizePixel = 0
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(28,28,28)
    stroke.Thickness = 1
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Transparency = 0.7
    stroke.Parent = btn
    btn.MouseEnter:Connect(function()
        if not btn:GetAttribute("ActiveTab") then
            btn.BackgroundColor3 = colors.navHover
        end
    end)
    btn.MouseLeave:Connect(function()
        if not btn:GetAttribute("ActiveTab") then
            btn.BackgroundColor3 = colors.navIdle
        end
    end)
    return btn
end

-- Content area
local ContentHolder = Instance.new("Frame")
ContentHolder.Name = "ContentHolder"
ContentHolder.Position = UDim2.new(0, 185, 0, 50)
ContentHolder.Size = UDim2.new(1, -185, 1, -70)
ContentHolder.BackgroundColor3 = colors.bgWindow
ContentHolder.BorderSizePixel = 0
ContentHolder.Parent = Main

-- Bottom status bar
local StatusBar = Instance.new("Frame")
StatusBar.Name = "StatusBar"
StatusBar.Size = UDim2.new(1, 0, 0, 20)
StatusBar.Position = UDim2.new(0,0,1,-20)
StatusBar.BackgroundColor3 = colors.bgSidebar
StatusBar.BorderSizePixel = 0
StatusBar.Parent = Main
local StatusText = Instance.new("TextLabel")
StatusText.BackgroundTransparency = 1
StatusText.Size = UDim2.new(1,-12,1,0)
StatusText.Position = UDim2.new(0,6,0,0)
StatusText.Font = Enum.Font.Gotham
StatusText.TextSize = 12
StatusText.TextColor3 = colors.textDim
StatusText.Text = "Ink Game | UI Preview | Placeholder"
StatusText.TextXAlignment = Enum.TextXAlignment.Left
StatusText.Parent = StatusBar

-- Tabs registry
local Tabs = {}
local currentTab

local function showTab(name)
    if currentTab == name then return end
    currentTab = name
    for tabName, data in pairs(Tabs) do
        local active = (tabName == name)
        data.Frame.Visible = active
        data.Button:SetAttribute("ActiveTab", active)
        if active then
            data.Button.BackgroundColor3 = colors.navActive
        else
            data.Button.BackgroundColor3 = colors.navIdle
        end
    end
end

-- Factories -----------------------------------------------------------------
local function createSection(parent, titleText, sizeY)
    local section = Instance.new("Frame")
    section.Name = (titleText:gsub("%s","")) .. "Section"
    section.Size = UDim2.new(1, -12, 0, sizeY or 180)
    section.BackgroundColor3 = colors.panel
    section.BorderSizePixel = 0
    section.Parent = parent
    local stroke = Instance.new("UIStroke")
    stroke.Color = colors.panelBorder
    stroke.Thickness = 1
    stroke.Parent = section
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0,6)
    corner.Parent = section
    local header = Instance.new("TextLabel")
    header.Name = "Header"
    header.BackgroundTransparency = 1
    header.Position = UDim2.new(0,12,0,6)
    header.Size = UDim2.new(1,-24,0,20)
    header.Font = Enum.Font.GothamSemibold
    header.TextSize = 15
    header.TextColor3 = colors.text
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.Text = titleText
    header.Parent = section
    return section
end

local function createPlaceholderControl(parent, labelText)
    local btn = Instance.new("TextButton")
    btn.Name = (labelText:gsub("%s","")) .. "Control"
    btn.AutoButtonColor = false
    btn.Text = labelText
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 13
    btn.TextColor3 = colors.textDim
    btn.BackgroundColor3 = colors.controlIdle
    btn.BorderSizePixel = 0
    btn.Size = UDim2.new(1, -24, 0, 30)
    btn.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0,4)
    corner.Parent = btn
    local stroke = Instance.new("UIStroke")
    stroke.Color = colors.strokeSoft
    stroke.Transparency = 0.6
    stroke.Thickness = 1
    stroke.Parent = btn
    btn.MouseEnter:Connect(function()
        btn.BackgroundColor3 = colors.highlight
    end)
    btn.MouseLeave:Connect(function()
        btn.BackgroundColor3 = colors.controlIdle
    end)
    return btn
end

local function createToggle(parent, labelText, default)
    local holder = Instance.new("Frame")
    holder.Name = (labelText:gsub("%s","")) .. "Toggle"
    holder.Size = UDim2.new(1, -24, 0, 28)
    holder.BackgroundTransparency = 1
    holder.Parent = parent
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1,-60,1,0)
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextSize = 13
    label.Text = labelText
    label.TextColor3 = colors.text
    label.Parent = holder
    local track = Instance.new("Frame")
    track.Name = "Track"
    track.Size = UDim2.new(0, 42, 0, 20)
    track.Position = UDim2.new(1,-46,0.5,-10)
    track.BackgroundColor3 = colors.toggleTrack
    track.BorderSizePixel = 0
    track.Parent = holder
    local trackCorner = Instance.new("UICorner")
    trackCorner.CornerRadius = UDim.new(1,0)
    trackCorner.Parent = track
    local knob = Instance.new("Frame")
    knob.Name = "Knob"
    knob.Size = UDim2.new(0, 18, 0, 18)
    knob.Position = UDim2.new(0,1,0,1)
    knob.BackgroundColor3 = colors.toggleOn
    knob.BorderSizePixel = 0
    knob.Parent = track
    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1,0)
    knobCorner.Parent = knob
    local state = default and true or false
    local function apply()
        if state then
            track.BackgroundColor3 = colors.toggleTrackOn
            knob.Position = UDim2.new(1,-19,0,1)
        else
            track.BackgroundColor3 = colors.toggleTrack
            knob.Position = UDim2.new(0,1,0,1)
        end
    end
    apply()
    track.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            state = not state
            apply()
        end
    end)
    return holder
end

local function registerTab(tabName)
    local btn = createNavButton(tabName)
    btn.Parent = Sidebar
    local frame = Instance.new("Frame")
    frame.Name = tabName .. "Tab"
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 1
    frame.Visible = false
    frame.Parent = ContentHolder

    local scroll = Instance.new("ScrollingFrame")
    scroll.Name = "ScrollArea"
    scroll.Size = UDim2.new(1, -16, 1, -16)
    scroll.Position = UDim2.new(0, 8, 0, 8)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.CanvasSize = UDim2.new(0,0,0,0)
    scroll.ScrollBarThickness = 4
    scroll.ScrollBarImageColor3 = Color3.fromRGB(70,70,70)
    scroll.Parent = frame

    local list = Instance.new("UIListLayout")
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Padding = UDim.new(0,10)
    list.Parent = scroll
    list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scroll.CanvasSize = UDim2.new(0,0,0,list.AbsoluteContentSize.Y + 12)
    end)

    -- Columns (simulate 2-col layout for some tabs)
    local columnsHolder = Instance.new("Frame")
    columnsHolder.Name = "Columns"
    columnsHolder.Size = UDim2.new(1,0,0,0)
    columnsHolder.BackgroundTransparency = 1
    columnsHolder.Parent = scroll
    local colLayout = Instance.new("UIListLayout")
    colLayout.FillDirection = Enum.FillDirection.Horizontal
    colLayout.Padding = UDim.new(0,12)
    colLayout.SortOrder = Enum.SortOrder.LayoutOrder
    colLayout.Parent = columnsHolder

    local function makeCol()
        local col = Instance.new("Frame")
        col.Name = "Col"
        col.Size = UDim2.new(0.5, -6, 1, 0)
        col.BackgroundTransparency = 1
        col.Parent = columnsHolder
        local stack = Instance.new("UIListLayout")
        stack.SortOrder = Enum.SortOrder.LayoutOrder
        stack.Padding = UDim.new(0,12)
        stack.Parent = col
        return col
    end

    local leftCol = makeCol()
    local rightCol = makeCol()

    if tabName == "Games" then
        local s1 = createSection(leftCol, "Red Light, Green Light", 260)
        createToggle(s1, "God Mode", true)
        createPlaceholderControl(s1, "Finish Red Light, Green Light")
        local s2 = createSection(rightCol, "Lights Out", 120)
        createToggle(s2, "Safe Zone", true)
        local s3 = createSection(rightCol, "Hide N' Seek", 300)
        createToggle(s3, "Show Exit Doors (Yellow)", true)
        createToggle(s3, "Show Doors (Cir/Tri/Sqr)", true)
        createToggle(s3, "Show Players (Red/Blue)", false)
    else
        local only = createSection(leftCol, tabName .. " (Empty)", 140)
        createPlaceholderControl(only, "Placeholder Button")
        createToggle(only, "Placeholder Toggle", false)
    end

    btn.MouseButton1Click:Connect(function()
        showTab(tabName)
    end)

    Tabs[tabName] = { Button = btn, Frame = frame }
end

-- Register nav tabs (full list from screenshot)
local navOrder = {"Games","Auto-Win","Combat","Misc","Players","Peabert","Settings"}
for _,name in ipairs(navOrder) do
    registerTab(name)
end

-- Default tab
showTab("Games")

-- Center on resize
local function center()
    Main.Position = UDim2.new(0.5, -Main.AbsoluteSize.X/2, 0.5, -Main.AbsoluteSize.Y/2)
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    if workspace.CurrentCamera then
        workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(center)
    end
end)
center()

-- Global toggle (RightControl)
local UIS = game:GetService("UserInputService")
UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.RightControl then
        ScreenGui.Enabled = not ScreenGui.Enabled
    end
end)

-- End of file
--[[
  Minimal UI recreation (only Misc + Settings tabs) inspired by provided screenshot.
  No features / functionality beyond tab switching.
  Drop this in a LocalScript (e.g., StarterPlayerScripts) or execute to build the GUI.
]]

-- Safety: destroy existing instance if re-run
local existing = game:GetService("CoreGui"):FindFirstChild("AgathaUI") or game.Players.LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("AgathaUI")
if existing then existing:Destroy() end

local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AgathaUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = playerGui

-- Theme palette (approx.)
local colors = {
	background = Color3.fromRGB(15,15,15),
	sidebar    = Color3.fromRGB(10,10,10),
	panel      = Color3.fromRGB(22,22,22),
	panelBorder= Color3.fromRGB(40,40,40),
	accent     = Color3.fromRGB(255,170,0), -- subtle accent (unused now)
	text       = Color3.fromRGB(220,220,220),
	textDim    = Color3.fromRGB(140,140,140),
	highlight  = Color3.fromRGB(60,60,60)
}

-- Main container
local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 720, 0, 520)
Main.Position = UDim2.new(0.5, -360, 0.5, -260)
Main.BackgroundColor3 = colors.background
Main.BorderSizePixel = 0
Main.Parent = ScreenGui

-- Shadow (simple)
local shadow = Instance.new("ImageLabel")
shadow.Name = "Shadow"
shadow.ZIndex = 0
shadow.BackgroundTransparency = 1
shadow.Image = "rbxassetid://5028857084" -- soft shadow image
shadow.ImageTransparency = 0.35
shadow.ScaleType = Enum.ScaleType.Slice
shadow.SliceCenter = Rect.new(24,24,276,276)
shadow.Size = UDim2.new(1, 32, 1, 32)
shadow.Position = UDim2.new(0, -16, 0, -16)
shadow.Parent = Main

-- Dragging
do
	local dragging, dragStart, startPos
	local inputConn, dragConn
	local dragTarget = Main
	local UIS = game:GetService("UserInputService")
	dragTarget.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = dragTarget.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)
	UIS.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			dragTarget.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)
end

-- Sidebar
local Sidebar = Instance.new("Frame")
Sidebar.Name = "Sidebar"
Sidebar.Size = UDim2.new(0, 180, 1, 0)
Sidebar.BackgroundColor3 = colors.sidebar
Sidebar.BorderSizePixel = 0
Sidebar.Parent = Main

local sideLayout = Instance.new("UIListLayout")
sideLayout.SortOrder = Enum.SortOrder.LayoutOrder
sideLayout.Padding = UDim.new(0, 4)
sideLayout.Parent = Sidebar

local sidePadding = Instance.new("UIPadding")
sidePadding.PaddingTop = UDim.new(0, 60)
sidePadding.PaddingLeft = UDim.new(0, 8)
sidePadding.PaddingRight = UDim.new(0, 8)
sidePadding.Parent = Sidebar

-- Title Bar
local TitleBar = Instance.new("Frame")
TitleBar.Name = "TitleBar"
TitleBar.Size = UDim2.new(1, 0, 0, 48)
TitleBar.BackgroundColor3 = colors.sidebar
TitleBar.BorderSizePixel = 0
TitleBar.Parent = Main

local TitleText = Instance.new("TextLabel")
TitleText.Name = "Title"
TitleText.BackgroundTransparency = 1
TitleText.Position = UDim2.new(0, 12, 0, 0)
TitleText.Size = UDim2.new(0, 160, 1, 0)
TitleText.Font = Enum.Font.GothamSemibold
TitleText.Text = "AgathaScript"
TitleText.TextColor3 = colors.text
TitleText.TextSize = 20
TitleText.TextXAlignment = Enum.TextXAlignment.Left
TitleText.Parent = TitleBar

-- Faux search box (visual only)
local SearchBox = Instance.new("Frame")
SearchBox.Name = "Search"
SearchBox.Size = UDim2.new(0, 280, 0, 32)
SearchBox.Position = UDim2.new(0, 200, 0, 8)
SearchBox.BackgroundColor3 = colors.panel
SearchBox.BorderSizePixel = 0
SearchBox.Parent = TitleBar
local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0,6)
uiCorner.Parent = SearchBox
local SearchText = Instance.new("TextLabel")
SearchText.BackgroundTransparency = 1
SearchText.Size = UDim2.new(1,-16,1,0)
SearchText.Position = UDim2.new(0,8,0,0)
SearchText.Font = Enum.Font.Gotham
SearchText.Text = "Search"
SearchText.TextColor3 = colors.textDim
SearchText.TextSize = 14
SearchText.TextXAlignment = Enum.TextXAlignment.Left
SearchText.Parent = SearchBox

-- Utility for making nav buttons
local function createNavButton(text)
	local btn = Instance.new("TextButton")
	btn.Name = text .. "Button"
	btn.Size = UDim2.new(1, 0, 0, 36)
	btn.AutoButtonColor = false
	btn.Text = text
	btn.Font = Enum.Font.Gotham
	btn.TextSize = 14
	btn.TextColor3 = colors.textDim
	btn.BackgroundColor3 = colors.panel
	btn.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0,4)
	corner.Parent = btn
	btn.MouseEnter:Connect(function()
		if not btn:GetAttribute("ActiveTab") then
			btn.BackgroundColor3 = colors.highlight
		end
	end)
	btn.MouseLeave:Connect(function()
		if not btn:GetAttribute("ActiveTab") then
			btn.BackgroundColor3 = colors.panel
		end
	end)
	return btn
end

-- Content area
local ContentHolder = Instance.new("Frame")
ContentHolder.Name = "ContentHolder"
ContentHolder.Position = UDim2.new(0, 180, 0, 48)
ContentHolder.Size = UDim2.new(1, -180, 1, -48)
ContentHolder.BackgroundColor3 = colors.background
ContentHolder.BorderSizePixel = 0
ContentHolder.Parent = Main

-- Tabs table
local Tabs = {}
local currentTab

local function showTab(name)
	if currentTab == name then return end
	currentTab = name
	for tabName, data in pairs(Tabs) do
		local active = (tabName == name)
		data.Frame.Visible = active
		data.Button:SetAttribute("ActiveTab", active)
		if active then
			data.Button.TextColor3 = colors.text
			data.Button.BackgroundColor3 = colors.highlight
		else
			data.Button.TextColor3 = colors.textDim
			data.Button.BackgroundColor3 = colors.panel
		end
	end
end

local function registerTab(tabName)
	local btn = createNavButton(tabName)
	btn.Parent = Sidebar
	local frame = Instance.new("Frame")
	frame.Name = tabName .. "Tab"
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.BackgroundTransparency = 1
	frame.Visible = false
	frame.Parent = ContentHolder

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "ScrollArea"
	scroll.Size = UDim2.new(1, -16, 1, -16)
	scroll.Position = UDim2.new(0, 8, 0, 8)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.CanvasSize = UDim2.new(0,0,0,0)
	scroll.ScrollBarThickness = 4
	scroll.ScrollBarImageColor3 = Color3.fromRGB(70,70,70)
	scroll.Parent = frame

	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0,8)
	list.Parent = scroll
	list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		scroll.CanvasSize = UDim2.new(0,0,0,list.AbsoluteContentSize.Y + 8)
	end)

	-- Placeholder panel inside each tab (visual only)
	local placeholder = Instance.new("Frame")
	placeholder.Name = "PlaceholderPanel"
	placeholder.Size = UDim2.new(1, 0, 0, 140)
	placeholder.BackgroundColor3 = colors.panel
	placeholder.BorderSizePixel = 0
	placeholder.Parent = scroll
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0,8)
	corner.Parent = placeholder
	local border = Instance.new("UIStroke")
	border.Color = colors.panelBorder
	border.Thickness = 1
	border.Parent = placeholder
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.new(0,12,0,8)
	title.Size = UDim2.new(1,-24,0,20)
	title.Font = Enum.Font.GothamSemibold
	title.TextSize = 16
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = colors.text
	title.Text = tabName .. " (Empty)"
	title.Parent = placeholder
	local subtitle = Instance.new("TextLabel")
	subtitle.BackgroundTransparency = 1
	subtitle.Position = UDim2.new(0,12,0,32)
	subtitle.Size = UDim2.new(1,-24,0,18)
	subtitle.Font = Enum.Font.Gotham
	subtitle.TextSize = 13
	subtitle.TextXAlignment = Enum.TextXAlignment.Left
	subtitle.TextColor3 = colors.textDim
	subtitle.Text = "No features yet. This is a placeholder panel."
	subtitle.Parent = placeholder

	btn.MouseButton1Click:Connect(function()
		showTab(tabName)
	end)

	Tabs[tabName] = { Button = btn, Frame = frame }
end

-- Register only requested tabs
registerTab("Misc")
registerTab("Settings")

-- Activate default
showTab("Misc")

-- Resize logic to keep centered if screen size changes
local GuiService = game:GetService("GuiService")
local function center()
	local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280,720)
	Main.Position = UDim2.new(0.5, -Main.AbsoluteSize.X/2, 0.5, -Main.AbsoluteSize.Y/2)
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(center)
	end
end)
center()

-- Optional: Press RightControl to toggle UI visibility
local UIS = game:GetService("UserInputService")
UIS.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.RightControl then
		ScreenGui.Enabled = not ScreenGui.Enabled
	end
end)

-- Done.

