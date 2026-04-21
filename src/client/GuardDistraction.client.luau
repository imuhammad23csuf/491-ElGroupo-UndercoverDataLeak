local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local GuardDialogueRemote = remotes:WaitForChild("GuardDialogue")

GuardDialogueRemote.OnClientEvent:Connect(function(character, text)
    if not character then return end

    local head = character:FindFirstChild("Head")
    if not head then return end

    TextChatService:DisplayBubble(head, text)
end)