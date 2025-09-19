local message = _G.message or "hi"

local success = false
local TextChatService = game:GetService("TextChatService")

-- Try new TextChatService
pcall(function()
    local channels = TextChatService:WaitForChild("TextChannels")
    local channel = channels:FindFirstChild("RBXGeneral") 
                 or channels:FindFirstChild("RBXSystem") 
                 or channels:GetChildren()[1]

    if channel then
        channel:SendAsync(message)
        success = true
    end
end)

-- Fallback to LegacyChatService
if not success then
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local chatEvents = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")

    if chatEvents then
        local say = chatEvents:FindFirstChild("SayMessageRequest")
        if say then
            say:FireServer(message, "All")
        else
            warn("SayMessageRequest not found in DefaultChatSystemChatEvents.")
        end
    else
        warn("No valid chat channels found in TextChatService, and DefaultChatSystemChatEvents missing.")
    end
end
