local Teams = game:GetService("Teams")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local distance = 1
local sidewaysOffset = 0
local loopSpeed = 0.1
local hitboxSize = 1
local isRunning = false
local hitboxEnabled = false
local noclipConnection = nil
local lastTick = 0
local targetTeam = nil

local localPlayer = Players.LocalPlayer
local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local rootPart = character:WaitForChild("HumanoidRootPart")

local connections = {}

local function setNoclip(player, enabled)
    local char = player.Character
    if not char then return end
    for _, part in pairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = not enabled
        end
    end
end

local function removeHitboxVisual(player)
    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local visual = root:FindFirstChild("HitboxVisual")
    if visual then visual:Destroy() end
    root.Size = Vector3.new(2, 2, 1)
end

local function updateHitbox(player, enabled, size)
    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    if enabled then
        root.Size = Vector3.new(2 * size, 2 * size, 1 * size)
        local visual = root:FindFirstChild("HitboxVisual")
        if not visual then
            visual = Instance.new("Part")
            visual.Name = "HitboxVisual"
            visual.Anchored = false
            visual.CanCollide = false
            visual.CastShadow = false
            visual.Material = Enum.Material.SmoothPlastic
            visual.Color = Color3.fromRGB(255, 60, 60)
            visual.Transparency = 0.6
            local weld = Instance.new("WeldConstraint")
            weld.Part0 = root
            weld.Part1 = visual
            weld.Parent = visual
            visual.Parent = root
        end
        visual.Size = root.Size
    else
        removeHitboxVisual(player)
    end
end

-- UI
local screenGui = Instance.new("ScreenGui")
screenGui.ResetOnSpawn = false
screenGui.Parent = localPlayer.PlayerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 200, 0, 420)
frame.Position = UDim2.new(0.5, -100, 0, 80)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
frame.BorderSizePixel = 0
frame.Parent = screenGui

local uiCornerFrame = Instance.new("UICorner")
uiCornerFrame.CornerRadius = UDim.new(0, 10)
uiCornerFrame.Parent = frame

-- Drag bar
local dragBar = Instance.new("Frame")
dragBar.Size = UDim2.new(1, 0, 0, 28)
dragBar.Position = UDim2.new(0, 0, 0, 0)
dragBar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
dragBar.BorderSizePixel = 0
dragBar.ZIndex = 5
dragBar.Parent = frame

local dragBarCorner = Instance.new("UICorner")
dragBarCorner.CornerRadius = UDim.new(0, 10)
dragBarCorner.Parent = dragBar

local dragBarCoverBottom = Instance.new("Frame")
dragBarCoverBottom.Size = UDim2.new(1, 0, 0, 10)
dragBarCoverBottom.Position = UDim2.new(0, 0, 1, -10)
dragBarCoverBottom.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
dragBarCoverBottom.BorderSizePixel = 0
dragBarCoverBottom.ZIndex = 5
dragBarCoverBottom.Parent = dragBar

local dragLabel = Instance.new("TextLabel")
dragLabel.Size = UDim2.new(1, 0, 1, 0)
dragLabel.BackgroundTransparency = 1
dragLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
dragLabel.Font = Enum.Font.GothamBold
dragLabel.TextSize = 12
dragLabel.Text = "⠿  Teleport Tool"
dragLabel.ZIndex = 6
dragLabel.Parent = dragBar

-- Drag logic
local draggingFrame = false
local dragStartMouse = nil
local dragStartFramePos = nil
local tweenInfo = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

dragBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        draggingFrame = true
        dragStartMouse = Vector2.new(input.Position.X, input.Position.Y)
        dragStartFramePos = frame.Position
    end
end)

local dragConn = UserInputService.InputChanged:Connect(function(input)
    if draggingFrame and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = Vector2.new(input.Position.X, input.Position.Y) - dragStartMouse
        local newX = dragStartFramePos.X.Offset + delta.X
        local newY = dragStartFramePos.Y.Offset + delta.Y
        local screenSize = workspace.CurrentCamera.ViewportSize
        newX = math.clamp(newX, 0, screenSize.X - frame.AbsoluteSize.X)
        newY = math.clamp(newY, 0, screenSize.Y - frame.AbsoluteSize.Y)
        TweenService:Create(frame, tweenInfo, { Position = UDim2.new(0, newX, 0, newY) }):Play()
    end
end)
table.insert(connections, dragConn)

local dragEndConn = UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then draggingFrame = false end
end)
table.insert(connections, dragEndConn)

local yOffset = 36

-- Team name input
local teamInput = Instance.new("TextBox")
teamInput.Size = UDim2.new(1, -20, 0, 32)
teamInput.Position = UDim2.new(0, 10, 0, yOffset)
teamInput.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
teamInput.TextColor3 = Color3.fromRGB(255, 255, 255)
teamInput.PlaceholderText = "Enter team name here..."
teamInput.PlaceholderColor3 = Color3.fromRGB(120, 120, 120)
teamInput.Font = Enum.Font.Gotham
teamInput.TextSize = 12
teamInput.Text = ""
teamInput.BorderSizePixel = 0
teamInput.ClearTextOnFocus = false
teamInput.Parent = frame

local teamInputCorner = Instance.new("UICorner")
teamInputCorner.CornerRadius = UDim.new(0, 8)
teamInputCorner.Parent = teamInput

-- Team status label
local teamStatus = Instance.new("TextLabel")
teamStatus.Size = UDim2.new(1, -20, 0, 14)
teamStatus.Position = UDim2.new(0, 10, 0, yOffset + 36)
teamStatus.BackgroundTransparency = 1
teamStatus.TextColor3 = Color3.fromRGB(120, 120, 120)
teamStatus.Font = Enum.Font.Gotham
teamStatus.TextSize = 11
teamStatus.TextXAlignment = Enum.TextXAlignment.Left
teamStatus.Text = "No team selected"
teamStatus.Parent = frame

-- Live team lookup as user types
teamInput:GetPropertyChangedSignal("Text"):Connect(function()
    local name = teamInput.Text
    local found = Teams:FindFirstChild(name)
    if found and found:IsA("Team") then
        targetTeam = found
        teamStatus.Text = "✓ Team found: " .. found.Name
        teamStatus.TextColor3 = Color3.fromRGB(0, 200, 80)
    else
        targetTeam = nil
        teamStatus.Text = name == "" and "No team selected" or "✗ Team not found"
        teamStatus.TextColor3 = name == "" and Color3.fromRGB(120, 120, 120) or Color3.fromRGB(220, 60, 60)
    end
end)

local yOff2 = yOffset + 58

-- Teleport toggle
local button = Instance.new("TextButton")
button.Size = UDim2.new(1, -20, 0, 40)
button.Position = UDim2.new(0, 10, 0, yOff2)
button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
button.TextColor3 = Color3.fromRGB(255, 255, 255)
button.Font = Enum.Font.GothamBold
button.TextSize = 15
button.Text = "Teleport: OFF"
button.BorderSizePixel = 0
button.Parent = frame

local c1 = Instance.new("UICorner")
c1.CornerRadius = UDim.new(0, 8)
c1.Parent = button

-- Slider builder
local function createSlider(parent, labelText, yPos, minVal, maxVal, defaultVal, decimals, onChange)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -20, 0, 18)
    label.Position = UDim2.new(0, 10, 0, yPos)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = labelText .. ": " .. defaultVal
    label.Parent = parent

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, -20, 0, 8)
    track.Position = UDim2.new(0, 10, 0, yPos + 22)
    track.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    track.BorderSizePixel = 0
    track.Parent = parent

    local trackCorner = Instance.new("UICorner")
    trackCorner.CornerRadius = UDim.new(1, 0)
    trackCorner.Parent = track

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((defaultVal - minVal) / (maxVal - minVal), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(0, 170, 80)
    fill.BorderSizePixel = 0
    fill.Parent = track

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = fill

    local knob = Instance.new("TextButton")
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.new((defaultVal - minVal) / (maxVal - minVal), 0, 0.5, 0)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.Text = ""
    knob.BorderSizePixel = 0
    knob.Parent = track

    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = knob

    local dragging = false
    knob.MouseButton1Down:Connect(function() dragging = true end)

    local c = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    table.insert(connections, c)

    local c2 = UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local relX = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
            local value = math.floor((minVal + (maxVal - minVal) * relX) * (10 ^ decimals) + 0.5) / (10 ^ decimals)
            fill.Size = UDim2.new(relX, 0, 1, 0)
            knob.Position = UDim2.new(relX, 0, 0.5, 0)
            label.Text = labelText .. ": " .. value
            onChange(value)
        end
    end)
    table.insert(connections, c2)
end

createSlider(frame, "Distance",    yOff2 + 52,  0,    10,   1,   1, function(val) distance = val end)
createSlider(frame, "Sideways",    yOff2 + 110, -10,  10,   0,   1, function(val) sidewaysOffset = val end)
createSlider(frame, "Speed (s)",   yOff2 + 168, 0.05, 1,    0.1, 2, function(val) loopSpeed = val end)

-- Hitbox toggle
local hitboxButton = Instance.new("TextButton")
hitboxButton.Size = UDim2.new(1, -20, 0, 30)
hitboxButton.Position = UDim2.new(0, 10, 0, yOff2 + 220)
hitboxButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
hitboxButton.TextColor3 = Color3.fromRGB(255, 255, 255)
hitboxButton.Font = Enum.Font.GothamBold
hitboxButton.TextSize = 13
hitboxButton.Text = "Hitbox Expand: OFF"
hitboxButton.BorderSizePixel = 0
hitboxButton.Parent = frame

local hbCorner = Instance.new("UICorner")
hbCorner.CornerRadius = UDim.new(0, 8)
hbCorner.Parent = hitboxButton

createSlider(frame, "Hitbox Size", yOff2 + 262, 1, 20, 1, 1, function(val)
    hitboxSize = val
    if hitboxEnabled and targetTeam then
        for _, player in pairs(targetTeam:GetPlayers()) do
            if player ~= localPlayer then updateHitbox(player, true, hitboxSize) end
        end
    end
end)

-- Unload button
local unloadButton = Instance.new("TextButton")
unloadButton.Size = UDim2.new(1, -20, 0, 30)
unloadButton.Position = UDim2.new(0, 10, 0, yOff2 + 320)
unloadButton.BackgroundColor3 = Color3.fromRGB(170, 40, 40)
unloadButton.TextColor3 = Color3.fromRGB(255, 255, 255)
unloadButton.Font = Enum.Font.GothamBold
unloadButton.TextSize = 13
unloadButton.Text = "Unload Script"
unloadButton.BorderSizePixel = 0
unloadButton.Parent = frame

local ulCorner = Instance.new("UICorner")
ulCorner.CornerRadius = UDim.new(0, 8)
ulCorner.Parent = unloadButton

-- Loop
local function startLoop()
    noclipConnection = RunService.Stepped:Connect(function()
        if not targetTeam then return end
        if tick() - lastTick < loopSpeed then return end
        lastTick = tick()
        local forwardOffset = rootPart.CFrame.LookVector * distance
        local rightOffset = rootPart.CFrame.RightVector * sidewaysOffset
        local teleportCFrame = CFrame.new(rootPart.Position + forwardOffset + rightOffset)
        for _, player in pairs(targetTeam:GetPlayers()) do
            if player ~= localPlayer then
                setNoclip(player, true)
                if hitboxEnabled then updateHitbox(player, true, hitboxSize) end
                local targetCharacter = player.Character
                if targetCharacter then
                    local targetRoot = targetCharacter:FindFirstChild("HumanoidRootPart")
                    if targetRoot then targetRoot.CFrame = teleportCFrame end
                end
            end
        end
    end)
end

local function stopLoop()
    if noclipConnection then
        noclipConnection:Disconnect()
        noclipConnection = nil
    end
    if targetTeam then
        for _, player in pairs(targetTeam:GetPlayers()) do
            if player ~= localPlayer then setNoclip(player, false) end
        end
    end
end

hitboxButton.MouseButton1Click:Connect(function()
    hitboxEnabled = not hitboxEnabled
    if hitboxEnabled then
        hitboxButton.Text = "Hitbox Expand: ON"
        hitboxButton.BackgroundColor3 = Color3.fromRGB(200, 80, 0)
        if targetTeam then
            for _, player in pairs(targetTeam:GetPlayers()) do
                if player ~= localPlayer then updateHitbox(player, true, hitboxSize) end
            end
        end
    else
        hitboxButton.Text = "Hitbox Expand: OFF"
        hitboxButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        if targetTeam then
            for _, player in pairs(targetTeam:GetPlayers()) do
                if player ~= localPlayer then removeHitboxVisual(player) end
            end
        end
    end
end)

button.MouseButton1Click:Connect(function()
    if not targetTeam then
        teamStatus.Text = "✗ Enter a team name first!"
        teamStatus.TextColor3 = Color3.fromRGB(220, 60, 60)
        return
    end
    isRunning = not isRunning
    if isRunning then
        button.Text = "Teleport: ON"
        button.BackgroundColor3 = Color3.fromRGB(0, 170, 80)
        startLoop()
    else
        button.Text = "Teleport: OFF"
        button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        stopLoop()
    end
end)

unloadButton.MouseButton1Click:Connect(function()
    stopLoop()
    if targetTeam then
        for _, player in pairs(targetTeam:GetPlayers()) do
            if player ~= localPlayer then
                setNoclip(player, false)
                removeHitboxVisual(player)
            end
        end
    end
    for _, c in pairs(connections) do c:Disconnect() end
    screenGui:Destroy()
end)
