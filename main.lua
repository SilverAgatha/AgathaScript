--[[
  AgathaScript UI (Minimal)
  Library: Obsidian (https://docs.mspaint.cc/obsidian)
  Tabs: Misc, Settings
  Keep this file lightweight; add new elements / features in separate modules later.
]]

---@diagnostic disable: undefined-global, deprecated

-- Safeguard: prevent re-execution creating duplicate UIs
pcall(function()
	if Library and Library.Unload then
		Library:Unload()
	end
end)

local REPO = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local function fetch(path)
	return game:HttpGet(REPO .. path)
end

local Library = loadstring(fetch("Library.lua"))()
local ThemeManager = loadstring(fetch("addons/ThemeManager.lua"))()
local SaveManager = loadstring(fetch("addons/SaveManager.lua"))()

-- Basic window
local Window = Library:CreateWindow({
	Title = "AgathaScript",
	Footer = "v0.1", -- change when you version bump
	Icon = 95816097006870, -- placeholder icon id; swap for your own asset if desired
	NotifySide = "Right",
	Center = false,
	AutoShow = true,
	ShowCustomCursor = true,
})

-- Set global font to Jura (fallback to Code if unavailable)
pcall(function()
    if Enum.Font.Jura then
        Library:SetFont(Enum.Font.Jura)
    else
        Library:SetFont(Enum.Font.Code)
    end
end)

-- Tabs (only Misc + Settings per request)
local Tabs = {
	Misc = Window:AddTab("Misc", "boxes"),
	Settings = Window:AddTab("Settings", "settings"),
}

-- Shortcuts to dynamic option containers populated by the library
local Options = Library.Options
local Toggles = Library.Toggles

--------------------------------------------------
-- Flight Feature Logic (Player Tab)
--------------------------------------------------
-- Simple flight implementation controlled by a toggle & speed slider.
-- Keeps UI and logic separated: UI sets Toggles / Options; logic reacts here.
local flightSpeed = 150 -- default; will sync with slider value
local flightConn
local flightForce -- VectorForce for anti-gravity
local flightAttachment
local inputConns = {}
local keyDown = {}

-- Services (moved above feature functions for clarity)
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- NoClip state (RunService.Stepped like reference implementation)
local noclipConn
local noclipModifiedParts = {}
local function disableNoClip()
	if noclipConn then
		noclipConn:Disconnect()
		noclipConn = nil
	end
	for part, original in pairs(noclipModifiedParts) do
		if part and part.Parent and part:IsA("BasePart") then
			part.CanCollide = original
		end
	end
	for k in pairs(noclipModifiedParts) do
		noclipModifiedParts[k] = nil
	end
end
local function enableNoClip()
	if noclipConn then return end
	noclipConn = RunService.Stepped:Connect(function()
		if Library.Unloaded or not (Toggles.NoClipEnabled and Toggles.NoClipEnabled.Value) then
			disableNoClip()
			return
		end
		local character = LocalPlayer.Character
		if not character then return end
		-- Iterate direct children first (faster), then descendants if needed
		for _, child in ipairs(character:GetChildren()) do
			if child:IsA("BasePart") then
				if noclipModifiedParts[child] == nil then
					noclipModifiedParts[child] = child.CanCollide
				end
				child.CanCollide = false
			end
		end
		-- Some rigs (R15) have MeshParts nested; ensure all are covered
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") and not noclipModifiedParts[part] then
				noclipModifiedParts[part] = part.CanCollide
				part.CanCollide = false
			end
		end
	end)
end

-- (Services already declared above)

local function getHRP()
	local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function disableFlight()
	if flightConn then
		flightConn:Disconnect()
		flightConn = nil
	end
	local hrp = getHRP()
	if hrp then
		-- Reset velocity so player drops naturally
		hrp.AssemblyLinearVelocity = Vector3.new()
	end
	-- Cleanup anti-gravity force
	if flightForce then
		flightForce:Destroy()
		flightForce = nil
	end
	if flightAttachment then
		flightAttachment:Destroy()
		flightAttachment = nil
	end
end

local function enableFlight()
	if flightConn then return end
	local hrp = getHRP()
	if not hrp then return end

	-- Set up anti-gravity support so we don't slowly sink
	if not flightAttachment then
		flightAttachment = Instance.new("Attachment")
		flightAttachment.Name = "AgathaFlightAttachment"
		flightAttachment.Parent = hrp
	end
	if not flightForce then
		flightForce = Instance.new("VectorForce")
		flightForce.Attachment0 = flightAttachment
		flightForce.Force = Vector3.new(0, workspace.Gravity * hrp.AssemblyMass, 0)
		flightForce.RelativeTo = Enum.ActuatorRelativeTo.World
		flightForce.Name = "AgathaFlightForce"
		flightForce.Parent = hrp
	end
	flightConn = RunService.RenderStepped:Connect(function(dt)
		-- Reacquire HRP in case of respawn
		hrp = getHRP()
		if not hrp then return end
		if Library.Unloaded or not (Toggles.FlightEnabled and Toggles.FlightEnabled.Value) then
			disableFlight()
			return
		end

		local cam = workspace.CurrentCamera
		if not cam then return end

		-- Free-direction camera-based movement (includes camera pitch)
		local camCF = cam.CFrame
		local forward = camCF.LookVector
		local right = camCF.RightVector
		local moveDir = Vector3.zero
		if keyDown.W then moveDir = moveDir + forward end
		if keyDown.S then moveDir = moveDir - forward end
		if keyDown.A then moveDir = moveDir - right end
		if keyDown.D then moveDir = moveDir + right end
		if keyDown.Space then moveDir = moveDir + Vector3.new(0, 1, 0) end
		if keyDown.LeftControl then moveDir = moveDir + Vector3.new(0, -1, 0) end -- Ctrl only for descending
		if moveDir.Magnitude > 0 then
			moveDir = moveDir.Unit
			hrp.AssemblyLinearVelocity = moveDir * flightSpeed
		else
			hrp.AssemblyLinearVelocity = Vector3.new()
		end

		-- Keep anti-gravity force updated if mass / gravity changes
		if flightForce and hrp then
			flightForce.Force = Vector3.new(0, workspace.Gravity * hrp.AssemblyMass, 0)
		end
	end)
end

-- Input handling (created once)
do
	local began = UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe then return end
		if input.KeyCode ~= Enum.KeyCode.Unknown then
			keyDown[input.KeyCode.Name] = true
		end
	end)
	local ended = UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode ~= Enum.KeyCode.Unknown then
			keyDown[input.KeyCode.Name] = nil
		end
	end)
	table.insert(inputConns, began)
	table.insert(inputConns, ended)
end

--------------------------------------------------
-- Misc Tab Content
--------------------------------------------------
do
	local PlayerGroup = Tabs.Misc:AddLeftGroupbox("Player", "user")

	PlayerGroup:AddToggle("FlightEnabled", {
		Text = "Flight",
		Tooltip = "Enable basic omnidirectional flight (WASD + Space + Ctrl)",
		Default = false,
		Callback = function(v)
			if v then
				enableFlight()
			else
				disableFlight()
			end
		end,
	})
	:AddKeyPicker("FlightKey", {
		-- No default keybind per request
		Mode = "Toggle",
		SyncToggleState = true,
		Text = "Flight",
		Callback = function() end,
	})

	PlayerGroup:AddSlider("FlightSpeed", {
		Text = "Flight Speed",
		Default = flightSpeed,
		Min = 50,
		Max = 1000,
		Rounding = 0,
		Tooltip = "Adjust flight velocity (studs/second approximation)",
		Callback = function(val)
			flightSpeed = val
		end,
	})

	PlayerGroup:AddToggle("NoClipEnabled", {
		Text = "NoClip",
		Tooltip = "Walk through most map geometry (may not bypass server checks)",
		Default = false,
		Callback = function(v)
			if v then
				enableNoClip()
			else
				disableNoClip()
			end
		end,
	})
	:AddKeyPicker("NoClipKey", {
		Mode = "Toggle",
		SyncToggleState = true,
		Text = "NoClip",
		Callback = function() end,
	})

	Options.FlightSpeed:OnChanged(function()
		flightSpeed = Options.FlightSpeed.Value
	end)
end

--------------------------------------------------
-- Settings Tab Content
--------------------------------------------------
do
	-- Menu / Interface controls
	local MenuGroup = Tabs.Settings:AddLeftGroupbox("Menu", "layout")

	MenuGroup:AddLabel("Menu Keybind")
		:AddKeyPicker("MenuKeybind", {
			Default = "Z",
			NoUI = true, -- hide from keybind list UI (we expose our own control label above)
			Text = "Menu Keybind",
		})

	MenuGroup:AddToggle("ShowCustomCursor", {
		Text = "Custom Cursor",
		Default = true,
		Callback = function(v) Library.ShowCustomCursor = v end,
	})

	MenuGroup:AddDropdown("NotificationSide", {
		Values = { "Left", "Right" },
		Default = "Right",
		Text = "Notification Side",
		Callback = function(side) Library:SetNotifySide(side) end,
	})

	MenuGroup:AddDivider()
	MenuGroup:AddButton({
		Text = "Unload UI",
		Tooltip = "Destroys the UI and disconnects hooks",
		Func = function()
			Library:Unload()
		end,
	})

	-- Optional theme + config integration (kept minimal)
	ThemeManager:SetLibrary(Library)
	SaveManager:SetLibrary(Library)

	-- Re-apply Jura font after ThemeManager initialization so theme menu reflects it
	pcall(function()
		if Enum.Font.Jura then
			Library:SetFont(Enum.Font.Jura)
		end
	end)
	SaveManager:IgnoreThemeSettings() -- do not persist theme values in configs
	SaveManager:SetIgnoreIndexes({ "MenuKeybind" })

	ThemeManager:SetFolder("AgathaScript")
	SaveManager:SetFolder("AgathaScript")

	-- Build config + theme sections inside Settings tab (appears as groupboxes)
	SaveManager:BuildConfigSection(Tabs.Settings)
	ThemeManager:ApplyToTab(Tabs.Settings)

	-- Apply saved autoload config if any
	pcall(function()
		SaveManager:LoadAutoloadConfig()
	end)
end

-- Assign toggle key AFTER keypicker is created
Library.ToggleKeybind = Options.MenuKeybind

--------------------------------------------------
-- Unload callback (cleanup custom connections here if added later)
--------------------------------------------------
Library:OnUnload(function()
	-- Cleanup flight
	disableFlight()
	disableNoClip()
	for _, c in ipairs(inputConns) do
		pcall(function() c:Disconnect() end)
	end
	print("[AgathaScript] UI unloaded")
end)

-- Final notify so user knows it loaded
Library:Notify({ Title = "AgathaScript", Description = "UI Loaded", Time = 3 })

--[[
Next Steps:
 - Add real feature toggles under the Misc tab
 - Separate feature logic into /scripts modules to keep UI lean
 - Expand Settings (e.g., Theme presets, performance options) as needed
]]

