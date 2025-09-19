local message = _G.message or "hi"

local success = false
local TextChatService = game:GetService("TextChatService")

pcall(function()
    local channel = TextChatService:WaitForChild("TextChannels"):WaitForChild("RBXGeneral")
    channel:SendAsync(message)
    success = true
end)

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
        warn("Neither TextChatService nor DefaultChatSystemChatEvents found.")
    end
end
