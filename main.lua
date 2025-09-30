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
	Footer = "AgathaScript | GlobalScript | V1.0", -- change when you version bump
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
        Library:SetFont(Enum.Font.Jura)
    end
end)

-- Tabs (only Misc + Settings per request)
local Tabs = {
	Misc = Window:AddTab("Misc", "boxes"),
	Others = Window:AddTab("Others", "code"),
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
-- Fling state
local flingPower = 10000 -- default fling multiplier
local flingRunning = false
local flingThread
local flingLastBaseVel -- used to restore velocity when disabling mid-impulse

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

-- WalkSpeed modification state
local walkSpeedConn
local originalWalkSpeed
local desiredWalkSpeed = 16 -- default Roblox walk speed; will sync with slider

local function applyWalkSpeed()
	if not (Toggles.WalkSpeedEnabled and Toggles.WalkSpeedEnabled.Value) then return end
	local character = LocalPlayer.Character
	if not character then return end
	local hum = character:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	if not originalWalkSpeed then
		originalWalkSpeed = hum.WalkSpeed
	end
	if hum.WalkSpeed ~= desiredWalkSpeed then
		hum.WalkSpeed = desiredWalkSpeed
	end
end

local function disableWalkSpeed()
	if walkSpeedConn then
		walkSpeedConn:Disconnect()
		walkSpeedConn = nil
	end
	local character = LocalPlayer.Character
	if character then
		local hum = character:FindFirstChildOfClass("Humanoid")
		if hum and originalWalkSpeed then
			hum.WalkSpeed = originalWalkSpeed
		end
	end
	originalWalkSpeed = nil
end

local function enableWalkSpeed()
	if walkSpeedConn then return end
	applyWalkSpeed()
	-- Keep enforcing in case game scripts overwrite it or on respawn
	walkSpeedConn = RunService.Stepped:Connect(function()
		if Library.Unloaded or not (Toggles.WalkSpeedEnabled and Toggles.WalkSpeedEnabled.Value) then
			disableWalkSpeed()
			return
		end
		applyWalkSpeed()
	end)
	-- Reapply on character added
	LocalPlayer.CharacterAdded:Connect(function()
		if walkSpeedConn and Toggles.WalkSpeedEnabled and Toggles.WalkSpeedEnabled.Value then
			task.wait(0.25)
			applyWalkSpeed()
		end
	end)
end

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

--------------------------------------------------
-- Fling Feature Logic
--------------------------------------------------
local function disableFling()
	if not flingRunning then return end
	flingRunning = false
	-- Restore previous or zero velocity so player isn't launched
	pcall(function()
		local hrp = getHRP()
		if hrp then
			hrpp = getHRP(); if hrpp then hrpp.AssemblyLinearVelocity = (flingLastBaseVel or Vector3.new()) end
		end
	end)
	flingThread = nil
end

local function enableFling()
	if flingRunning then return end
	flingRunning = true
	flingThread = coroutine.create(function()
		local movel = 0.1
		while flingRunning do
			-- Stop if UI unloaded or toggle turned off
			if Library.Unloaded or not (Toggles.FlingEnabled and Toggles.FlingEnabled.Value) then
				disableFling()
				break
			end
			RunService.Heartbeat:Wait()
			local hrp = getHRP()
			if hrp then
				local baseVel = hrp.AssemblyLinearVelocity
				flingLastBaseVel = baseVel -- track last stable velocity
				-- First strong fling impulse (scaled)
				hrp.AssemblyLinearVelocity = baseVel * flingPower + Vector3.new(0, flingPower, 0)
				RunService.RenderStepped:Wait()
				-- Restore base velocity briefly
				if not flingRunning then break end
				hrp = getHRP()
				if hrp then
					hrp.AssemblyLinearVelocity = baseVel
				end
				RunService.Stepped:Wait()
				if not flingRunning then break end
				hrp = getHRP()
				if hrp then
					hrp.AssemblyLinearVelocity = baseVel + Vector3.new(0, movel, 0)
				end
				movel = -movel
			end
		end
	end)
	coroutine.resume(flingThread)
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

	PlayerGroup:AddToggle("WalkSpeedEnabled", {
		Text = "Walk Speed",
		Tooltip = "Override humanoid WalkSpeed (10-200)",
		Default = false,
		Callback = function(v)
			if v then
				enableWalkSpeed()
			else
				disableWalkSpeed()
			end
		end,
	})
	:AddKeyPicker("WalkSpeedKey", {
		Mode = "Toggle",
		SyncToggleState = true,
		Text = "Walk Speed",
		Callback = function() end,
	})

	PlayerGroup:AddSlider("WalkSpeedValue", {
		Text = "Walk Speed Value",
		Default = desiredWalkSpeed,
		Min = 10,
		Max = 200,
		Rounding = 0,
		Tooltip = "Set new humanoid WalkSpeed",
		Callback = function(val)
			desiredWalkSpeed = val
			if Toggles.WalkSpeedEnabled and Toggles.WalkSpeedEnabled.Value then
				applyWalkSpeed()
			end
		end,
	})

	PlayerGroup:AddToggle("FlingEnabled", {
		Text = "Fling",
		Tooltip = "Rapid velocity pulses to fling (may be patched in some games)",
		Default = false,
		Callback = function(v)
			if v then
				enableFling()
			else
				disableFling()
			end
		end,
	})

	PlayerGroup:AddSlider("FlingPower", {
		Text = "Fling Power",
		Default = flingPower,
		Min = 1000,
		Max = 50000,
		Rounding = 0,
		Tooltip = "Scale fling velocity multiplier (higher = stronger)",
		Callback = function(val)
			flingPower = val
		end,
	})


	Options.FlightSpeed:OnChanged(function()
		flightSpeed = Options.FlightSpeed.Value
	end)
    if Options.WalkSpeedValue then
        Options.WalkSpeedValue:OnChanged(function()
            desiredWalkSpeed = Options.WalkSpeedValue.Value
            if Toggles.WalkSpeedEnabled and Toggles.WalkSpeedEnabled.Value then
                applyWalkSpeed()
            end
        end)
    end
	if Options.FlingPower then
		Options.FlingPower:OnChanged(function()
			flingPower = Options.FlingPower.Value
		end)
	end
end

--------------------------------------------------
-- Others Tab Content
--------------------------------------------------
do
	local ScriptsGroup = Tabs.Others:AddLeftGroupbox("scripts", "code")

	-- Section: Infinite Yield
	ScriptsGroup:AddLabel("Infinite Yield")
	ScriptsGroup:AddButton({
		Text = "Load Infinite Yield",
		Tooltip = "Execute Infinite Yield admin script",
		Func = function()
			local ok, err = pcall(function()
				loadstring(game:HttpGet("https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"))()
			end)
			if ok then
				Library:Notify({ Title = "Scripts", Description = "Infinite Yield loaded", Time = 3 })
			else
				Library:Notify({ Title = "Scripts", Description = "Failed: " .. tostring(err), Time = 5 })
			end
		end,
	})

	-- Section: Spolarium
	ScriptsGroup:AddLabel("Spolarium")
	ScriptsGroup:AddButton({
		Text = "Load Spolarium",
		Tooltip = "Execute Spolarium hub",
		Func = function()
			local ok, err = pcall(function()
				loadstring(game:HttpGet("https://raw.githubusercontent.com/SpolariumHub/Spolarium/refs/heads/main/MainLoader.lua"))()
			end)
			if ok then
				Library:Notify({ Title = "Scripts", Description = "Spolarium loaded", Time = 3 })
			else
				Library:Notify({ Title = "Scripts", Description = "Failed: " .. tostring(err), Time = 5 })
			end
		end,
	})

	-- AX-Premium key input + loader
	ScriptsGroup:AddInput("AXKey", {
		Text = "AX-Script",
		Placeholder = "Enter AX Premium key",
		Default = "",
		Numeric = false,
		Finished = true,
		Callback = function(val) end,
	})

	ScriptsGroup:AddButton({
		Text = "AX-Premium",
		Tooltip = "Load AX-Premium using the provided key",
		Func = function()
			local key = Options.AXKey and Options.AXKey.Value or ""
			if not key or key == "" then
				Library:Notify({ Title = "AX-Premium", Description = "Please enter a key first", Time = 3 })
				return
			end
			local ok, err = pcall(function()
				local chunk = string.format('script_key="%s";\nloadstring(game:HttpGet("https://api.luarmor.net/files/v4/loaders/104e8eb99b22ccb066698cc14d6736b4.lua"))()', key)
				loadstring(chunk)()
			end)
			if ok then
				Library:Notify({ Title = "AX-Premium", Description = "Loader executed", Time = 3 })
			else
				Library:Notify({ Title = "AX-Premium", Description = "Failed: " .. tostring(err), Time = 5 })
			end
		end,
	})

	-- Section: Chat Message (no header label to match AX style)
	ScriptsGroup:AddInput("ChatMsg", {
		Text = "Chat Message",
		Placeholder = "Enter message to send",
		Default = "",
		Numeric = false,
		Finished = true,
		Callback = function(val) end,
	})

	ScriptsGroup:AddButton({
		Text = "Send Chat Message",
		Tooltip = "Run chatmessage script with your custom message",
		Func = function()
			local msg = Options.ChatMsg and Options.ChatMsg.Value or ""
			if msg == "" then
				Library:Notify({ Title = "Chat Message", Description = "Please enter a message first", Time = 3 })
				return
			end
			local ok, err = pcall(function()
				local chunk = string.format('message=%q;\nloadstring(game:HttpGet("https://raw.githubusercontent.com/SilverAgatha/AgathaScript/main/scripts/chatmessage.lua"))()', msg)
				loadstring(chunk)()
			end)
			if ok then
				Library:Notify({ Title = "Chat Message", Description = "Script executed", Time = 3 })
			else
				Library:Notify({ Title = "Chat Message", Description = "Failed: " .. tostring(err), Time = 5 })
			end
		end,
	})
end

--------------------------------------------------
-- Settings Tab Content
--------------------------------------------------
do
	-- Menu / Interface controls
	local MenuGroup = Tabs.Settings:AddLeftGroupbox("Menu", "layout")

	MenuGroup:AddLabel("Menu Keybind")
		:AddKeyPicker("MenuKeybind", {
			Default = "Home",
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

	-- Force the Themes "Font Face" dropdown to reflect Jura instead of lingering on default "Code"
	-- Some ThemeManager builds cache the dropdown value before we override the font; we resync it here.
	pcall(function()
		if Enum.Font.Jura then
			Library:SetFont(Enum.Font.Jura) -- ensure actual font object is still Jura
			local fontOption = Options.FontFace or Options.Font or Options.FontFamily
			if fontOption then
				-- Try common casings; match against the option's list if available.
				local target = "Jura"
				if fontOption.Value ~= target then
					local list = rawget(fontOption, "List") or rawget(fontOption, "Values")
					if list then
						for _, v in ipairs(list) do
							if string.lower(v) == string.lower(target) then
								fontOption:SetValue(v)
								break
							end
						end
					else
						-- Fallback: attempt direct set
						pcall(function() fontOption:SetValue(target) end)
					end
				end
			end
		end
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
	disableWalkSpeed()
	disableFling()
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

