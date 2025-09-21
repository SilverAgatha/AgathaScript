local msg = message or "hi"

local success = false
local TextChatService = game:GetService("TextChatService")

pcall(function()
    local channels = TextChatService:WaitForChild("TextChannels")
    local channel = channels:FindFirstChild("RBXGeneral") 
                 or channels:FindFirstChild("RBXSystem") 
                 or channels:GetChildren()[1]

    if channel then
        channel:SendAsync(msg)
        success = true
    end
end)

if not success then
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local chatEvents = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")

    if chatEvents then
        local say = chatEvents:FindFirstChild("SayMessageRequest")
        if say then
            say:FireServer(msg, "All")
        else
            warn("SayMessageRequest not found in DefaultChatSystemChatEvents.")
        end
    else
        warn("No valid chat channels found in TextChatService, and DefaultChatSystemChatEvents missing.")
    end
end
