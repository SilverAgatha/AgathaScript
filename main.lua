--[[
	AgathaScript UI Recreation
	This script rebuilds the provided reference interface using Roblox UI instances.
	It is designed for execution via an external exploit environment and includes:
	  * ScreenGui construction with sidebar navigation and settings panel.
	  * Toggleable visibility through a configurable keybind (default: Z).
	  * Unload button that destroys all created instances and disconnects events.

	The layout intentionally mirrors the supplied design while keeping functionality scoped
	to the requirements. Additional panels such as configuration/themes/search logic are
	represented visually only.
]]

local globalEnv = _G

local rawGetGenv = rawget(globalEnv, "getgenv")
local getgenvFunction = (type(rawGetGenv) == "function") and rawGetGenv or nil

if not getgenvFunction then
	local shared = rawget(globalEnv, "__AGATHA_GEN_ENV")
	if not shared then
		shared = {}
		rawset(globalEnv, "__AGATHA_GEN_ENV", shared)
	end
	getgenvFunction = function()
		return shared
	end
end

local robloxGame = rawget(globalEnv, "game")
local Enum = rawget(globalEnv, "Enum")
local Instance = rawget(globalEnv, "Instance")
local Color3 = rawget(globalEnv, "Color3")
local Vector2 = rawget(globalEnv, "Vector2")
local UDim2 = rawget(globalEnv, "UDim2")
local UDim = rawget(globalEnv, "UDim")
local TweenInfo = rawget(globalEnv, "TweenInfo")
local gethuiFunction = rawget(globalEnv, "gethui")

if not robloxGame or not Enum or not Instance or not Color3 or not Vector2 or not UDim2 or not UDim or not TweenInfo then
	error("AgathaScript requires Roblox GUI globals to be available.")
end

local tableClear = rawget(table, "clear")

local function clearTable(targetTable)
	if tableClear then
		tableClear(targetTable)
		return
	end
	for key in pairs(targetTable) do
		targetTable[key] = nil
	end
end

local Players = robloxGame:GetService("Players")
local UserInputService = robloxGame:GetService("UserInputService")
local TweenService = robloxGame:GetService("TweenService")
local CoreGui = robloxGame:GetService("CoreGui")

local env = getgenvFunction()
env = env or {}

if env.AgathaScript and type(env.AgathaScript) == "table" then
	local existingUnload = env.AgathaScript.Unload
	if type(existingUnload) == "function" then
		pcall(existingUnload)
	end
end

-- Shared state for this session -------------------------------------------------------
local state = {
	Connections = {},
	ToggleKey = Enum.KeyCode.Z,
	ToggleKeyName = "Z",
	Visible = true,
	CapturingKey = false,
	CurrentTab = "Settings",
}

env.AgathaScript = state

local function trackConnection(conn)
	if conn then
		table.insert(state.Connections, conn)
	end
	return conn
end

local function getParentGui()
	local success, result = pcall(function()
		return (gethuiFunction and gethuiFunction()) or CoreGui
	end)
	if success and result then
		return result
	end
	return CoreGui
end

local parentGui = getParentGui()

-- Style palette ----------------------------------------------------------------------
local palette = {
	Background = Color3.fromRGB(18, 18, 18),
	Sidebar = Color3.fromRGB(14, 14, 14),
	SidebarAccent = Color3.fromRGB(44, 44, 44),
	Section = Color3.fromRGB(24, 24, 24),
	SectionStroke = Color3.fromRGB(60, 60, 60),
	TextPrimary = Color3.fromRGB(236, 236, 236),
	TextSecondary = Color3.fromRGB(172, 172, 172),
	Accent = Color3.fromRGB(207, 71, 71),
	Highlight = Color3.fromRGB(96, 96, 96),
}

local fontPrimary = Enum.Font.GothamSemibold
local fontSecondary = Enum.Font.Gotham

-- Formatting helpers -----------------------------------------------------------------
local function formatKeyName(keyCode)
	if not keyCode or keyCode == Enum.KeyCode.Unknown or not keyCode.Name then
		return "?"
	end

	local name = keyCode.Name or tostring(keyCode)
	name = name:gsub("Enum.KeyCode.", "")
	name = name:gsub("Left", "L")
	name = name:gsub("Right", "R")
	name = name:gsub("Bracket", " Bracket")
	name = name:gsub("Plus", "+")

	if name == "Return" then
		name = "Enter"
	elseif name == "Backspace" then
		name = "Back"
	elseif name == "Slash" then
		name = "/"
	elseif name == "Period" then
		name = "."
	end

	return name:upper()
end

-- ScreenGui and root container -------------------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AgathaScriptUI"
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
screenGui.DisplayOrder = 999999
screenGui.Parent = parentGui

state.ScreenGui = screenGui

local shadow = Instance.new("Frame")
shadow.Name = "Shadow"
shadow.Parent = screenGui
shadow.AnchorPoint = Vector2.new(0.5, 0.5)
shadow.Position = UDim2.new(0.5, 6, 0.5, 10)
shadow.Size = UDim2.new(0, 722, 0, 462)
shadow.BackgroundColor3 = Color3.new(0, 0, 0)
shadow.BackgroundTransparency = 0.65
shadow.ZIndex = 0
shadow.BorderSizePixel = 0

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainContainer"
mainFrame.Parent = screenGui
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
mainFrame.Size = UDim2.new(0, 720, 0, 460)
mainFrame.BackgroundColor3 = palette.Background
mainFrame.BorderSizePixel = 0
mainFrame.ZIndex = 1

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 18)
mainCorner.Parent = mainFrame

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(34, 34, 34)
mainStroke.Thickness = 1
mainStroke.Parent = mainFrame

-- Sidebar ---------------------------------------------------------------------------
local sidebar = Instance.new("Frame")
sidebar.Name = "Sidebar"
sidebar.Parent = mainFrame
sidebar.BackgroundColor3 = palette.Sidebar
sidebar.BorderSizePixel = 0
sidebar.Position = UDim2.new(0, 0, 0, 0)
sidebar.Size = UDim2.new(0, 210, 1, 0)
sidebar.ZIndex = 2
sidebar.ClipsDescendants = true

local sidebarCorner = Instance.new("UICorner")
sidebarCorner.CornerRadius = UDim.new(0, 18)
sidebarCorner.Parent = sidebar

local sidebarPadding = Instance.new("UIPadding")
sidebarPadding.Parent = sidebar
sidebarPadding.PaddingLeft = UDim.new(0, 18)
sidebarPadding.PaddingTop = UDim.new(0, 20)
sidebarPadding.PaddingRight = UDim.new(0, 12)

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Parent = sidebar
titleLabel.Size = UDim2.new(1, -10, 0, 32)
titleLabel.BackgroundTransparency = 1
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Font = fontPrimary
titleLabel.TextSize = 22
titleLabel.TextColor3 = palette.TextPrimary
titleLabel.TextTransparency = 0
titleLabel.Text = "AgathaScript"

local searchBox = Instance.new("TextBox")
searchBox.Name = "Search"
searchBox.Parent = sidebar
searchBox.Size = UDim2.new(1, -6, 0, 34)
searchBox.Position = UDim2.new(0, 0, 0, 48)
searchBox.BackgroundColor3 = Color3.fromRGB(32, 32, 32)
searchBox.BorderSizePixel = 0
searchBox.Font = fontSecondary
searchBox.PlaceholderText = "Search"
searchBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 120)
searchBox.Text = ""
searchBox.TextSize = 16
searchBox.TextColor3 = palette.TextPrimary
searchBox.TextXAlignment = Enum.TextXAlignment.Left
searchBox.ClearTextOnFocus = false
searchBox.ClipsDescendants = true

local searchCorner = Instance.new("UICorner")
searchCorner.CornerRadius = UDim.new(0, 10)
searchCorner.Parent = searchBox

local searchPadding = Instance.new("UIPadding")
searchPadding.Parent = searchBox
searchPadding.PaddingLeft = UDim.new(0, 10)

local navContainer = Instance.new("Frame")
navContainer.Name = "NavContainer"
navContainer.Parent = sidebar
navContainer.BackgroundTransparency = 1
navContainer.Position = UDim2.new(0, 0, 0, 100)
navContainer.Size = UDim2.new(1, -6, 1, -110)

local navLayout = Instance.new("UIListLayout")
navLayout.Parent = navContainer
navLayout.Padding = UDim.new(0, 6)
navLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
navLayout.SortOrder = Enum.SortOrder.LayoutOrder

local function createNavButton(name, order)
	local button = Instance.new("TextButton")
	button.Name = name .. "Button"
	button.Parent = navContainer
	button.Size = UDim2.new(1, 0, 0, 36)
	button.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	button.BackgroundTransparency = 1
	button.BorderSizePixel = 0
	button.Text = ""
	button.AutoButtonColor = false
	button.LayoutOrder = order

	local indicator = Instance.new("Frame")
	indicator.Name = "Indicator"
	indicator.Parent = button
	indicator.Position = UDim2.new(0, -8, 0, 4)
	indicator.Size = UDim2.new(0, 3, 1, -8)
	indicator.BackgroundColor3 = palette.Accent
	indicator.BorderSizePixel = 0
	indicator.Visible = false

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Parent = button
	label.AnchorPoint = Vector2.new(0, 0.5)
	label.Position = UDim2.new(0, 6, 0.5, 0)
	label.Size = UDim2.new(1, -12, 1, -6)
	label.BackgroundTransparency = 1
	label.Text = name
	label.Font = fontSecondary
	label.TextSize = 17
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = palette.TextSecondary

	local buttonStroke = Instance.new("UIStroke")
	buttonStroke.Parent = button
	buttonStroke.Color = Color3.fromRGB(42, 42, 42)
	buttonStroke.Thickness = 1
	buttonStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	buttonStroke.Transparency = 1

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 10)
	buttonCorner.Parent = button

	return button
end

local navButtons = {
	Misc = createNavButton("Misc", 1),
	Settings = createNavButton("Settings", 2),
}

-- Content region ---------------------------------------------------------------------
local contentFrame = Instance.new("Frame")
contentFrame.Name = "Content"
contentFrame.Parent = mainFrame
contentFrame.BackgroundColor3 = palette.Section
contentFrame.BorderSizePixel = 0
contentFrame.Position = UDim2.new(0, 210, 0, 0)
contentFrame.Size = UDim2.new(1, -210, 1, 0)
contentFrame.ZIndex = 2
contentFrame.ClipsDescendants = true

local contentCorner = Instance.new("UICorner")
contentCorner.CornerRadius = UDim.new(0, 18)
contentCorner.Parent = contentFrame

local contentPadding = Instance.new("UIPadding")
contentPadding.Parent = contentFrame
contentPadding.PaddingLeft = UDim.new(0, 24)
contentPadding.PaddingRight = UDim.new(0, 24)
contentPadding.PaddingTop = UDim.new(0, 26)
contentPadding.PaddingBottom = UDim.new(0, 20)

local tabTitle = Instance.new("TextLabel")
tabTitle.Name = "TabTitle"
tabTitle.Parent = contentFrame
tabTitle.BackgroundTransparency = 1
tabTitle.Size = UDim2.new(1, 0, 0, 28)
tabTitle.TextXAlignment = Enum.TextXAlignment.Left
tabTitle.Font = fontPrimary
tabTitle.TextSize = 22
tabTitle.TextColor3 = palette.TextPrimary
tabTitle.Text = "Settings"

local tabDivider = Instance.new("Frame")
tabDivider.Name = "Divider"
tabDivider.Parent = contentFrame
tabDivider.Position = UDim2.new(0, 0, 0, 42)
tabDivider.Size = UDim2.new(1, 0, 0, 1)
tabDivider.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
tabDivider.BorderSizePixel = 0

local contentHolder = Instance.new("Frame")
contentHolder.Name = "ContentHolder"
contentHolder.Parent = contentFrame
contentHolder.BackgroundTransparency = 1
contentHolder.Position = UDim2.new(0, 0, 0, 54)
contentHolder.Size = UDim2.new(1, 0, 1, -64)

local contentLayout = Instance.new("UIListLayout")
contentLayout.Parent = contentHolder
contentLayout.Padding = UDim.new(0, 14)
contentLayout.SortOrder = Enum.SortOrder.LayoutOrder

-- Settings tab -----------------------------------------------------------------------
local settingsSection = Instance.new("Frame")
settingsSection.Name = "SettingsSection"
settingsSection.Parent = contentHolder
settingsSection.BackgroundColor3 = palette.Sidebar
settingsSection.BorderSizePixel = 0
settingsSection.Size = UDim2.new(1, 0, 0, 220)
settingsSection.AutomaticSize = Enum.AutomaticSize.Y
settingsSection.LayoutOrder = 1

local settingsCorner = Instance.new("UICorner")
settingsCorner.CornerRadius = UDim.new(0, 14)
settingsCorner.Parent = settingsSection

local settingsStroke = Instance.new("UIStroke")
settingsStroke.Color = palette.SectionStroke
settingsStroke.Thickness = 1
settingsStroke.Parent = settingsSection

local settingsPadding = Instance.new("UIPadding")
settingsPadding.Parent = settingsSection
settingsPadding.PaddingTop = UDim.new(0, 16)
settingsPadding.PaddingBottom = UDim.new(0, 16)
settingsPadding.PaddingLeft = UDim.new(0, 18)
settingsPadding.PaddingRight = UDim.new(0, 18)

local settingsLayout = Instance.new("UIListLayout")
settingsLayout.Parent = settingsSection
settingsLayout.Padding = UDim.new(0, 14)
settingsLayout.SortOrder = Enum.SortOrder.LayoutOrder

local settingsTitle = Instance.new("TextLabel")
settingsTitle.Name = "SettingsTitle"
settingsTitle.Parent = settingsSection
settingsTitle.BackgroundTransparency = 1
settingsTitle.Size = UDim2.new(1, 0, 0, 26)
settingsTitle.Font = fontPrimary
settingsTitle.TextSize = 20
settingsTitle.TextXAlignment = Enum.TextXAlignment.Left
settingsTitle.TextColor3 = palette.TextPrimary
settingsTitle.Text = "UI Settings"

local divider = Instance.new("Frame")
divider.Name = "SectionDivider"
divider.Parent = settingsSection
divider.BackgroundColor3 = Color3.fromRGB(48, 48, 48)
divider.BorderSizePixel = 0
divider.Size = UDim2.new(1, 0, 0, 1)

local keybindRow = Instance.new("Frame")
keybindRow.Name = "KeybindRow"
keybindRow.Parent = settingsSection
keybindRow.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
keybindRow.BorderSizePixel = 0
keybindRow.Size = UDim2.new(1, 0, 0, 48)
keybindRow.AutomaticSize = Enum.AutomaticSize.Y

local keybindCorner = Instance.new("UICorner")
keybindCorner.CornerRadius = UDim.new(0, 10)
keybindCorner.Parent = keybindRow

local keybindPadding = Instance.new("UIPadding")
keybindPadding.Parent = keybindRow
keybindPadding.PaddingLeft = UDim.new(0, 14)
keybindPadding.PaddingRight = UDim.new(0, 14)
keybindPadding.PaddingTop = UDim.new(0, 10)
keybindPadding.PaddingBottom = UDim.new(0, 10)

local keybindLabel = Instance.new("TextLabel")
keybindLabel.Name = "KeybindLabel"
keybindLabel.Parent = keybindRow
keybindLabel.BackgroundTransparency = 1
keybindLabel.Size = UDim2.new(0.5, -8, 1, 0)
keybindLabel.Font = fontSecondary
keybindLabel.TextSize = 16
keybindLabel.TextXAlignment = Enum.TextXAlignment.Left
keybindLabel.TextColor3 = palette.TextSecondary
keybindLabel.Text = "Menu bind"

local keybindButton = Instance.new("TextButton")
keybindButton.Name = "KeybindButton"
keybindButton.Parent = keybindRow
keybindButton.AnchorPoint = Vector2.new(1, 0.5)
keybindButton.Position = UDim2.new(1, 0, 0.5, 0)
keybindButton.Size = UDim2.new(0.4, 0, 1, -4)
keybindButton.BackgroundColor3 = Color3.fromRGB(38, 38, 38)
keybindButton.BorderSizePixel = 0
keybindButton.AutoButtonColor = false
keybindButton.Font = fontSecondary
keybindButton.TextSize = 16
keybindButton.TextColor3 = palette.TextPrimary
keybindButton.Text = "Menu bind: " .. state.ToggleKeyName

local keybindButtonCorner = Instance.new("UICorner")
keybindButtonCorner.CornerRadius = UDim.new(0, 8)
keybindButtonCorner.Parent = keybindButton

local keybindStroke = Instance.new("UIStroke")
keybindStroke.Color = Color3.fromRGB(60, 60, 60)
keybindStroke.Thickness = 1
keybindStroke.Parent = keybindButton

local unloadButton = Instance.new("TextButton")
unloadButton.Name = "UnloadButton"
unloadButton.Parent = settingsSection
unloadButton.Size = UDim2.new(1, 0, 0, 48)
unloadButton.BackgroundColor3 = palette.Accent
unloadButton.BorderSizePixel = 0
unloadButton.AutoButtonColor = false
unloadButton.Font = fontPrimary
unloadButton.TextSize = 18
unloadButton.TextColor3 = palette.TextPrimary
unloadButton.Text = "Unload"

local unloadCorner = Instance.new("UICorner")
unloadCorner.CornerRadius = UDim.new(0, 12)
unloadCorner.Parent = unloadButton

-- Misc tab (placeholder) -------------------------------------------------------------
local miscSection = Instance.new("Frame")
miscSection.Name = "MiscSection"
miscSection.Parent = contentHolder
miscSection.BackgroundColor3 = palette.Sidebar
miscSection.BorderSizePixel = 0
miscSection.Size = UDim2.new(1, 0, 0, 150)
miscSection.Visible = false
miscSection.AutomaticSize = Enum.AutomaticSize.Y
miscSection.LayoutOrder = 1

local miscCorner = Instance.new("UICorner")
miscCorner.CornerRadius = UDim.new(0, 14)
miscCorner.Parent = miscSection

local miscStroke = Instance.new("UIStroke")
miscStroke.Color = palette.SectionStroke
miscStroke.Thickness = 1
miscStroke.Parent = miscSection

local miscPadding = Instance.new("UIPadding")
miscPadding.Parent = miscSection
miscPadding.PaddingTop = UDim.new(0, 20)
miscPadding.PaddingBottom = UDim.new(0, 20)
miscPadding.PaddingLeft = UDim.new(0, 18)
miscPadding.PaddingRight = UDim.new(0, 18)

local miscLabel = Instance.new("TextLabel")
miscLabel.Name = "PlaceholderLabel"
miscLabel.Parent = miscSection
miscLabel.BackgroundTransparency = 1
miscLabel.Size = UDim2.new(1, 0, 0, 24)
miscLabel.Font = fontSecondary
miscLabel.TextSize = 16
miscLabel.TextColor3 = palette.TextSecondary
miscLabel.TextXAlignment = Enum.TextXAlignment.Left
miscLabel.Text = "No miscellaneous options available."

-- Tab management ---------------------------------------------------------------------
local function setTab(tabName)
	state.CurrentTab = tabName
	tabTitle.Text = tabName
	settingsSection.Visible = tabName == "Settings"
	miscSection.Visible = tabName == "Misc"

	for name, button in pairs(navButtons) do
		local active = (name == tabName)
		local label = button:FindFirstChild("Label")
		local indicator = button:FindFirstChild("Indicator")
		if label then
			label.TextColor3 = active and palette.TextPrimary or palette.TextSecondary
		end
		if indicator then
			indicator.Visible = active
		end
		button.BackgroundTransparency = active and 0.15 or 1

		local stroke = button:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Transparency = active and 0.4 or 1
		end
	end
end

setTab("Settings")

-- Animated hover feedback for navigation buttons ------------------------------------
local function bindNavButton(button, tabName)
	trackConnection(button.MouseEnter:Connect(function()
		if state.CurrentTab ~= tabName then
			TweenService:Create(button, TweenInfo.new(0.15, Enum.EasingStyle.Linear), {
				BackgroundTransparency = 0.55,
			}):Play()
		end
	end))

	trackConnection(button.MouseLeave:Connect(function()
		if state.CurrentTab ~= tabName then
			TweenService:Create(button, TweenInfo.new(0.15, Enum.EasingStyle.Linear), {
				BackgroundTransparency = 1,
			}):Play()
		end
	end))

	trackConnection(button.MouseButton1Click:Connect(function()
		if state.CurrentTab ~= tabName then
			setTab(tabName)
		end
	end))
end

for name, button in pairs(navButtons) do
	bindNavButton(button, name)
end

-- Keybind capture --------------------------------------------------------------------
local function updateKeybindDisplay()
	keybindButton.Text = "Menu bind: " .. state.ToggleKeyName
end

local function toggleCapture(active)
	state.CapturingKey = active
	if active then
		keybindButton.Text = "Press a key..."
		keybindButton.TextColor3 = palette.Accent
	else
		keybindButton.TextColor3 = palette.TextPrimary
		updateKeybindDisplay()
	end
end

trackConnection(keybindButton.MouseButton1Click:Connect(function()
	if state.CapturingKey then
		toggleCapture(false)
		return
	end
	toggleCapture(true)
end))

local function setToggleKey(newKey)
	state.ToggleKey = newKey
	state.ToggleKeyName = formatKeyName(newKey)
	updateKeybindDisplay()
end

-- Toggle handling --------------------------------------------------------------------
local function setVisible(isVisible)
	state.Visible = isVisible
	screenGui.Enabled = isVisible
end

local function toggleUI()
	setVisible(not state.Visible)
end

setVisible(true)

trackConnection(UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
	if input.UserInputType ~= Enum.UserInputType.Keyboard then
		return
	end

	if state.CapturingKey then
		if input.KeyCode == Enum.KeyCode.Unknown then
			return
		end

		if input.KeyCode == Enum.KeyCode.Escape then
			toggleCapture(false)
			return
		end

		toggleCapture(false)
		setToggleKey(input.KeyCode)
		return
	end

	if gameProcessedEvent then
		return
	end

	if input.KeyCode == state.ToggleKey then
		toggleUI()
	end
end))

-- Unload cleanup ---------------------------------------------------------------------
local function cleanup()
	for _, conn in ipairs(state.Connections) do
		if conn and conn.Disconnect then
			pcall(function()
				conn:Disconnect()
			end)
		end
	end
	clearTable(state.Connections)

	if screenGui then
		pcall(function()
			screenGui.Enabled = false
			screenGui.Parent = nil
			screenGui:Destroy()
		end)
	end

	if shadow then
		pcall(function()
			shadow:Destroy()
		end)
	end

	if env.AgathaScript == state then
		env.AgathaScript = nil
	end

	local status, unloadFunction = pcall(function()
		return env.unloadscript or env.unload
	end)

	if status and type(unloadFunction) == "function" then
		pcall(unloadFunction)
	end
end

state.Unload = cleanup

trackConnection(unloadButton.MouseButton1Click:Connect(function()
	cleanup()
end))

-- Fail-safe: remove UI if player leaves ----------------------------------------------
local LocalPlayer = Players.LocalPlayer
if LocalPlayer then
	trackConnection(LocalPlayer.AncestryChanged:Connect(function(_, parent)
		if not parent then
			cleanup()
		end
	end))
end

-- Public API for executors -----------------------------------------------------------
state.Toggle = toggleUI
state.SetVisibility = setVisible
state.SetToggleKey = function(keyCode)
	if keyCode and keyCode.EnumType == Enum.KeyCode then
		setToggleKey(keyCode)
	end
end

-- Final polish -----------------------------------------------------------------------
updateKeybindDisplay()
setTab("Settings")

