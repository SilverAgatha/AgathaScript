print("AgathaScript UI Executor Script started")
local player = game.Players.LocalPlayer or game:GetService("Players").LocalPlayer
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local FlightEnabled = false
local FlightKey = Enum.KeyCode.F
local FlightSpeed = 200

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AgathaScriptUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local ContentFrames = {}
local miscFrame = Instance.new("Frame")
ContentFrames["Misc"] = miscFrame
miscFrame.Name = "Misc"
miscFrame.Size = UDim2.new(0, 300, 0, 300)
miscFrame.Position = UDim2.new(0, 50, 0, 50)
miscFrame.BackgroundTransparency = 0.3
miscFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
miscFrame.Visible = true
miscFrame.ZIndex = 10
miscFrame.Parent = screenGui

local FlightButton = Instance.new("TextButton")
FlightButton.Name = "FlightButton"
FlightButton.Size = UDim2.new(1, -40, 0, 40)
FlightButton.Position = UDim2.new(0, 20, 0, 110)
FlightButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
FlightButton.Text = "Flight: OFF"
FlightButton.Font = Enum.Font.SourceSans
FlightButton.TextSize = 18
FlightButton.TextColor3 = Color3.fromRGB(200, 200, 200)
FlightButton.BorderSizePixel = 0
FlightButton.LayoutOrder = 3
FlightButton.ZIndex = 11
FlightButton.Parent = ContentFrames["Misc"]

local KeybindLabel = Instance.new("TextLabel")
KeybindLabel.Name = "KeybindLabel"
KeybindLabel.Size = UDim2.new(0.5, -25, 0, 40)
KeybindLabel.Position = UDim2.new(0, 20, 0, 160)
KeybindLabel.BackgroundTransparency = 1
KeybindLabel.Text = "Keybind:"
KeybindLabel.Font = Enum.Font.SourceSans
KeybindLabel.TextSize = 18
KeybindLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
KeybindLabel.LayoutOrder = 4
KeybindLabel.ZIndex = 11
KeybindLabel.Parent = ContentFrames["Misc"]

local KeybindButton = Instance.new("TextButton")
KeybindButton.Name = "KeybindButton"
KeybindButton.Size = UDim2.new(0.5, -25, 0, 40)
KeybindButton.Position = UDim2.new(0.5, 5, 0, 160)
KeybindButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
KeybindButton.Text = "F"
KeybindButton.Font = Enum.Font.SourceSans
KeybindButton.TextSize = 18
KeybindButton.TextColor3 = Color3.fromRGB(200, 200, 200)
KeybindButton.BorderSizePixel = 0
KeybindButton.LayoutOrder = 5
KeybindButton.ZIndex = 11
KeybindButton.Parent = ContentFrames["Misc"]

KeybindButton.MouseButton1Click:Connect(function()
    KeybindButton.Text = "..."
    local conn
    conn = UserInputService.InputBegan:Connect(function(input, processed)
        if not processed and input.UserInputType == Enum.UserInputType.Keyboard then
            FlightKey = input.KeyCode
            KeybindButton.Text = input.KeyCode.Name
            conn:Disconnect()
        end
    end)
end)

local SpeedLabel = Instance.new("TextLabel")
SpeedLabel.Name = "SpeedLabel"
SpeedLabel.Size = UDim2.new(1, -40, 0, 30)
SpeedLabel.Position = UDim2.new(0, 20, 0, 210)
SpeedLabel.BackgroundTransparency = 1
SpeedLabel.Text = "Flight Speed: " .. tostring(FlightSpeed)
SpeedLabel.Font = Enum.Font.SourceSans
SpeedLabel.TextSize = 16
SpeedLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
SpeedLabel.LayoutOrder = 6
SpeedLabel.ZIndex = 11
SpeedLabel.Parent = ContentFrames["Misc"]

local SpeedSlider = Instance.new("Frame")
SpeedSlider.Name = "SpeedSlider"
SpeedSlider.Size = UDim2.new(1, -40, 0, 20)
SpeedSlider.Position = UDim2.new(0, 20, 0, 240)
SpeedSlider.BackgroundTransparency = 1
SpeedSlider.LayoutOrder = 7
SpeedSlider.ZIndex = 11
SpeedSlider.Parent = ContentFrames["Misc"]

local SliderBar = Instance.new("Frame")
SliderBar.Name = "SliderBar"
SliderBar.Size = UDim2.new(1, 0, 0, 6)
SliderBar.Position = UDim2.new(0, 0, 0.5, -3)
SliderBar.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
SliderBar.BorderSizePixel = 0
SliderBar.ZIndex = 12
SliderBar.Parent = SpeedSlider

local SliderKnob = Instance.new("Frame")
SliderKnob.Name = "SliderKnob"
SliderKnob.Size = UDim2.new(0, 16, 0, 16)
SliderKnob.Position = UDim2.new((FlightSpeed-50)/950, -8, 0.5, -8)
SliderKnob.BackgroundColor3 = Color3.fromRGB(120, 120, 120)
SliderKnob.BorderSizePixel = 0
SliderKnob.ZIndex = 13
SliderKnob.Parent = SpeedSlider

local dragging = false
SliderKnob.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local x = UserInputService:GetMouseLocation().X - SliderBar.AbsolutePosition.X
        local percent = math.clamp(x / SliderBar.AbsoluteSize.X, 0, 1)
        FlightSpeed = math.floor(50 + percent * (1000-50))
        SliderKnob.Position = UDim2.new(percent, -8, 0.5, -8)
        SpeedLabel.Text = "Flight Speed: " .. tostring(FlightSpeed)
    end
end)

local function setFlight(enabled)
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local hrp = char.HumanoidRootPart
    if enabled then
        if not hrp:FindFirstChild("AgathaFlight") then
            local bv = Instance.new("BodyVelocity")
            bv.Name = "AgathaFlight"
            bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
            bv.Velocity = Vector3.new(0, 0, 0)
            bv.Parent = hrp
        end
    else
        if hrp:FindFirstChild("AgathaFlight") then
            hrp.AgathaFlight:Destroy()
        end
    end
end

FlightButton.MouseButton1Click:Connect(function()
    FlightEnabled = not FlightEnabled
    FlightButton.Text = "Flight: " .. (FlightEnabled and "ON" or "OFF")
    setFlight(FlightEnabled)
end)

UserInputService.InputBegan:Connect(function(input, processed)
    if not processed and input.KeyCode == FlightKey then
        FlightEnabled = not FlightEnabled
        FlightButton.Text = "Flight: " .. (FlightEnabled and "ON" or "OFF")
        setFlight(FlightEnabled)
    end
end)

RunService.RenderStepped:Connect(function()
    if FlightEnabled then
        local char = player.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            local hrp = char.HumanoidRootPart
            local bv = hrp:FindFirstChild("AgathaFlight")
            if bv then
                local move = Vector3.new(0, 0, 0)
                local cam = workspace.CurrentCamera
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                    move = move + cam.CFrame.LookVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                    move = move - cam.CFrame.LookVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                    move = move - cam.CFrame.RightVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                    move = move + cam.CFrame.RightVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                    move = move + Vector3.new(0, 1, 0)
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
                    move = move - Vector3.new(0, 1, 0)
                end
                if move.Magnitude > 0 then
                    move = move.Unit
                end
                bv.Velocity = move * FlightSpeed
            end
        end
    end
end)