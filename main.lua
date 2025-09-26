--[[
	AgathaScript UI
	Minimal recreation of style similar to reference screenshot (dark theme, sidebar, group boxes)
	Includes:
	  - Sidebar with two pages: Misc, Settings
	  - Search bar (filters visible controls by label text)
	  - Group boxes containing sample controls (toggle, button, dropdown skeleton)
	  - Simple theming + hover/active states
	  - Draggable main window
	  - Keybind (RightShift) to toggle UI visibility
	Notes:
	  * This is a pure Lua (Roblox) implementation intended for execution via an exploit executor.
	  * No external libraries required.
	  * Extend by using the ComponentFactory functions at bottom (AddToggle, AddButton, AddDropdown placeholder).
]]

local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

-- Destroy previous instance if re-injected
if CoreGui:FindFirstChild("AgathaScriptUI") then
	CoreGui.AgathaScriptUI:Destroy()
end

local THEME = {
	Background = Color3.fromRGB(15,15,15),
	Accent = Color3.fromRGB(60,60,60),
	Accent2 = Color3.fromRGB(40,40,40),
	Highlight = Color3.fromRGB(90,90,90),
	Primary = Color3.fromRGB(255,255,255),
	PrimaryDim = Color3.fromRGB(180,180,180),
	Green = Color3.fromRGB(90,200,90),
	Red = Color3.fromRGB(200,80,80),
	ScrollBar = Color3.fromRGB(70,70,70)
}

local function applyStroke(inst, thickness, color)
	local ui = Instance.new("UIStroke")
	ui.Thickness = thickness or 1
	ui.Color = color or THEME.Accent
	ui.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ui.Parent = inst
	return ui
end

local function roundify(inst, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 6)
	c.Parent = inst
	return c
end

-- Root ScreenGui
local screen = Instance.new("ScreenGui")
screen.Name = "AgathaScriptUI"
screen.ResetOnSpawn = false
screen.Parent = CoreGui

-- Main window
local mainFrame = Instance.new("Frame")
mainFrame.Name = "Main"
mainFrame.Size = UDim2.new(0, 760, 0, 430)
mainFrame.Position = UDim2.new(0.5, -380, 0.5, -215)
mainFrame.BackgroundColor3 = THEME.Background
mainFrame.Parent = screen
roundify(mainFrame, 8)
applyStroke(mainFrame, 1, THEME.Accent2)

-- Top bar (for dragging + search)
local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.Size = UDim2.new(1, 0, 0, 46)
topBar.BackgroundColor3 = THEME.Accent2
topBar.Parent = mainFrame
roundify(topBar, 8)

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Size = UDim2.new(0, 150, 1, 0)
title.Position = UDim2.new(0, 14, 0, 0)
title.Font = Enum.Font.GothamBold
title.Text = "AX-SCRIPTS"
title.TextSize = 20
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = THEME.Primary
title.Parent = topBar

local searchBox = Instance.new("TextBox")
searchBox.PlaceholderText = "Search"
searchBox.Text = ""
searchBox.Font = Enum.Font.Gotham
searchBox.TextSize = 14
searchBox.TextColor3 = THEME.Primary
searchBox.PlaceholderColor3 = THEME.PrimaryDim
searchBox.BackgroundColor3 = THEME.Background
searchBox.Size = UDim2.new(0, 240, 0, 30)
searchBox.Position = UDim2.new(1, -260, 0.5, -15)
searchBox.Parent = topBar
roundify(searchBox, 6)
applyStroke(searchBox, 1, THEME.Accent)

-- Sidebar
local sideBar = Instance.new("Frame")
sideBar.Name = "Sidebar"
sideBar.BackgroundColor3 = THEME.Accent2
sideBar.Size = UDim2.new(0, 150, 1, -46)
sideBar.Position = UDim2.new(0,0,0,46)
sideBar.Parent = mainFrame

local sideList = Instance.new("UIListLayout")
sideList.SortOrder = Enum.SortOrder.LayoutOrder
sideList.Padding = UDim.new(0,4)
sideList.Parent = sideBar

local pages = {}
local currentPage = nil

local pageContainer = Instance.new("Frame")
pageContainer.Name = "Pages"
pageContainer.BackgroundTransparency = 1
pageContainer.Size = UDim2.new(1, -150, 1, -46)
pageContainer.Position = UDim2.new(0,150,0,46)
pageContainer.Parent = mainFrame

local function createPage(name)
	local page = Instance.new("ScrollingFrame")
	page.Name = name
	page.Visible = false
	page.Size = UDim2.new(1, -20, 1, -20)
	page.Position = UDim2.new(0,10,0,10)
	page.CanvasSize = UDim2.new(0,0,0,0)
	page.ScrollBarThickness = 4
	page.BackgroundTransparency = 1
	page.ScrollBarImageColor3 = THEME.ScrollBar
	page.Parent = pageContainer

	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0,10)
	list.Parent = page

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0,4)
	pad.PaddingTop = UDim.new(0,4)
	pad.PaddingRight = UDim.new(0,4)
	pad.Parent = page

	list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		page.CanvasSize = UDim2.new(0,0,0,list.AbsoluteContentSize.Y + 20)
	end)

	pages[name] = page
	return page
end

local function selectPage(name)
	if currentPage == name then return end
	for n,p in pairs(pages) do
		p.Visible = (n == name)
	end
	currentPage = name
	-- update sidebar highlight
	for _,b in ipairs(sideBar:GetChildren()) do
		if b:IsA("TextButton") then
			b.BackgroundColor3 = (b.Name == name) and THEME.Highlight or THEME.Accent2
		end
	end
end

local function makeSidebarButton(name, order)
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Size = UDim2.new(1,0,0,36)
	btn.BackgroundColor3 = THEME.Accent2
	btn.AutoButtonColor = false
	btn.Text = name
	btn.Font = Enum.Font.Gotham
	btn.TextColor3 = THEME.Primary
	btn.TextSize = 16
	btn.LayoutOrder = order or 0
	btn.Parent = sideBar
	applyStroke(btn,1,THEME.Accent)
	btn.MouseEnter:Connect(function()
		if currentPage ~= name then
			TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = THEME.Accent}):Play()
		end
	end)
	btn.MouseLeave:Connect(function()
		if currentPage ~= name then
			TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = THEME.Accent2}):Play()
		end
	end)
	btn.MouseButton1Click:Connect(function()
		selectPage(name)
	end)
	return btn
end

-- Component Helpers
local ComponentFactory = {}

local function newGroup(parent, titleText)
	local group = Instance.new("Frame")
	group.Name = titleText
	group.Size = UDim2.new(1, -10, 0, 140)
	group.BackgroundColor3 = THEME.Accent2
	group.Parent = parent
	roundify(group,8)
	applyStroke(group,1,THEME.Accent)

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0,6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = group

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0,8)
	pad.PaddingLeft = UDim.new(0,8)
	pad.PaddingRight = UDim.new(0,8)
	pad.Parent = group

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.Text = titleText
	title.TextSize = 16
	title.TextColor3 = THEME.Primary
	title.Size = UDim2.new(1,0,0,18)
	title.Parent = group

	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		group.Size = UDim2.new(1, -10, 0, layout.AbsoluteContentSize.Y + 16)
	end)

	return group
end

local function makeButton(text, callback)
	local btn = Instance.new("TextButton")
	btn.Name = text
	btn.Size = UDim2.new(1,0,0,30)
	btn.BackgroundColor3 = THEME.Background
	btn.AutoButtonColor = false
	btn.Font = Enum.Font.Gotham
	btn.Text = text
	btn.TextSize = 14
	btn.TextColor3 = THEME.Primary
	roundify(btn,6)
	applyStroke(btn,1,THEME.Accent)
	btn.MouseEnter:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundColor3 = THEME.Accent}):Play()
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = THEME.Background}):Play()
	end)
	btn.MouseButton1Click:Connect(function()
		if callback then
			pcall(callback)
		end
	end)
	return btn
end

local function makeToggle(text, default, callback)
	local holder = Instance.new("Frame")
	holder.Name = text
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1,0,0,30)

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Gotham
	label.Text = text
	label.TextSize = 14
	label.TextColor3 = THEME.Primary
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Size = UDim2.new(1,-50,1,0)
	label.Parent = holder

	local button = Instance.new("TextButton")
	button.Name = "Switch"
	button.AutoButtonColor = false
	button.BackgroundColor3 = THEME.Background
	button.Size = UDim2.new(0,40,0,22)
	button.Position = UDim2.new(1,-44,0.5,-11)
	button.Font = Enum.Font.Gotham
	button.Text = ""
	button.TextSize = 14
	button.TextColor3 = THEME.Primary
	button.Parent = holder
	roundify(button, 6)
	applyStroke(button,1,THEME.Accent)

	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.Size = UDim2.new(0,18,0,18)
	knob.Position = UDim2.new(0,2,0.5,-9)
	knob.BackgroundColor3 = THEME.Red
	knob.Parent = button
	roundify(knob,6)

	local state = default or false
	local function render()
		if state then
			TweenService:Create(knob, TweenInfo.new(0.15), {Position = UDim2.new(1,-20,0.5,-9), BackgroundColor3 = THEME.Green}):Play()
		else
			TweenService:Create(knob, TweenInfo.new(0.15), {Position = UDim2.new(0,2,0.5,-9), BackgroundColor3 = THEME.Red}):Play()
		end
	end
	render()

	button.MouseButton1Click:Connect(function()
		state = not state
		render()
		if callback then pcall(callback, state) end
	end)

	return holder, function() return state end, function(v) state=v; render(); if callback then pcall(callback,state) end end
end

local function makeDropdown(text, items, defaultIndex, callback)
	-- Simple collapsed dropdown placeholder (no open list for brevity)
	local holder = Instance.new("Frame")
	holder.Name = text
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1,0,0,30)

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1,0,1,0)
	btn.BackgroundColor3 = THEME.Background
	btn.AutoButtonColor = false
	btn.Font = Enum.Font.Gotham
	btn.TextSize = 14
	btn.TextColor3 = THEME.Primary
	btn.TextXAlignment = Enum.TextXAlignment.Left
	btn.Text = text..": "..(items[defaultIndex or 1] or "...")
	roundify(btn,6)
	applyStroke(btn,1,THEME.Accent)
	btn.Parent = holder

	local index = defaultIndex or 1
	btn.MouseButton1Click:Connect(function()
		index = index + 1
		if index > #items then index = 1 end
		btn.Text = text..": "..items[index]
		if callback then pcall(callback, items[index], index) end
	end)

	return holder
end

function ComponentFactory.AddGroup(pageName, groupTitle)
	local page = pages[pageName]
	if not page then return end
	return newGroup(page, groupTitle)
end

function ComponentFactory.AddButton(group, text, callback)
	local btn = makeButton(text, callback)
	btn.Parent = group
	return btn
end

function ComponentFactory.AddToggle(group, text, default, callback)
	local holder = select(1, makeToggle(text, default, callback))
	holder.Parent = group
	return holder
end

function ComponentFactory.AddDropdown(group, text, items, defaultIndex, callback)
	local dd = makeDropdown(text, items, defaultIndex, callback)
	dd.Parent = group
	return dd
end

-- Pages
createPage("Misc")
createPage("Settings")

-- Sidebar buttons
makeSidebarButton("Misc",1)
makeSidebarButton("Settings",2)

selectPage("Misc")

-- Populate Misc Page
do
	local g1 = ComponentFactory.AddGroup("Misc","Movement")
	ComponentFactory.AddToggle(g1, "Speed Boost", false, function(on)
		-- placeholder logic
	end)
	ComponentFactory.AddToggle(g1, "Jump Boost", false)
	ComponentFactory.AddButton(g1, "Teleport Spawn", function()
		local plr = game.Players.LocalPlayer
		if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
			plr.Character.HumanoidRootPart.CFrame = CFrame.new(0,50,0)
		end
	end)

	local g2 = ComponentFactory.AddGroup("Misc","Visuals")
	ComponentFactory.AddDropdown(g2, "ESP Mode", {"Off","Boxes","Names"}, 1)
	ComponentFactory.AddToggle(g2, "Fullbright", false, function(on)
		if on then
			if not _G.__AS_OldLighting then
				_G.__AS_OldLighting = game.Lighting.Brightness
			end
			game.Lighting.Brightness = 4
		else
			if _G.__AS_OldLighting then
				game.Lighting.Brightness = _G.__AS_OldLighting
			end
		end
	end)
end

-- Populate Settings Page
do
	local g1 = ComponentFactory.AddGroup("Settings","Interface")
	ComponentFactory.AddButton(g1, "Destroy UI", function()
		screen:Destroy()
	end)
	ComponentFactory.AddDropdown(g1, "Theme", {"Dark"}, 1, function(choice)
		-- future theme expansion
	end)
	ComponentFactory.AddToggle(g1, "Watermark", true, function(on)
		-- placeholder
	end)
end

-- Search Filtering
local function updateSearch()
	local q = searchBox.Text:lower()
	if q == "" then
		-- show all
		for _,page in pairs(pages) do
			for _,child in ipairs(page:GetChildren()) do
				if child:IsA("Frame") then child.Visible = true end
			end
		end
	else
		local page = pages[currentPage]
		if not page then return end
		for _,child in ipairs(page:GetChildren()) do
			if child:IsA("Frame") then
				local title = child:FindFirstChild("Title")
				local nameText = title and title.Text:lower() or child.Name:lower()
				local match = nameText:find(q) ~= nil
				if not match then
					-- search inside controls labels
					for _,ctrl in ipairs(child:GetChildren()) do
						if ctrl:IsA("TextLabel") and ctrl ~= title then
							if (ctrl.Text:lower():find(q)) then match = true break end
						elseif ctrl:IsA("Frame") then
							if ctrl.Name:lower():find(q) then match = true break end
						elseif ctrl:IsA("TextButton") then
							if ctrl.Text:lower():find(q) then match = true break end
						end
					end
				end
				child.Visible = match
			end
		end
	end
end
searchBox:GetPropertyChangedSignal("Text"):Connect(updateSearch)

-- Dragging main window
do
	local dragging=false
	local dragStart, startPos
	topBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			dragStart = input.Position
			startPos = mainFrame.Position
		end
	end)
	topBar.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging=false
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = input.Position - dragStart
			mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)
end

-- Keybind to toggle UI
local toggleKey = Enum.KeyCode.RightShift
UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.KeyCode == toggleKey then
		mainFrame.Visible = not mainFrame.Visible
	end
end)

print("[AgathaScript] UI Loaded.")

