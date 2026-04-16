local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CyberScenarioManager = require(Shared:WaitForChild("CyberScenarioManager"))

local NOTE_MODEL_NAME = "Sticky Note"
local PROMPT_NAME = "WorldStickyNotePrompt"

local connected = {}

local function handleInspect(player)
    if not player or not player:IsA("Player") then
        return
    end

    player:SetAttribute("RecoveredAdminCredentials", true)
    CyberScenarioManager.CheckSolution(player, "world_sticky_note inspect")
end

local function getBasePart(target)
    if not target then
        return nil
    end

    if target:IsA("BasePart") then
        return target
    end

    if target:IsA("Model") then
        return target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart", true)
    end

    return nil
end

local function attachTo(instance)
    if connected[instance] then
        return
    end

    local part = getBasePart(instance)
    if not part then
        return
    end

    connected[instance] = true

    local prompt = instance:FindFirstChildWhichIsA("ProximityPrompt", true)
    if not prompt then
        prompt = Instance.new("ProximityPrompt")
        prompt.Name = PROMPT_NAME
        prompt.ActionText = "Inspect Note"
        prompt.ObjectText = NOTE_MODEL_NAME
        prompt.RequiresLineOfSight = false
        prompt.MaxActivationDistance = 10
        prompt.HoldDuration = 0
        prompt.Parent = part
    end
    prompt.Triggered:Connect(handleInspect)

    local clickDetector = instance:FindFirstChildWhichIsA("ClickDetector", true)
    if clickDetector then
        clickDetector.MouseClick:Connect(handleInspect)
    end
end

for _, descendant in ipairs(Workspace:GetDescendants()) do
    if descendant.Name == NOTE_MODEL_NAME and (descendant:IsA("Model") or descendant:IsA("BasePart")) then
        attachTo(descendant)
    end
end

Workspace.DescendantAdded:Connect(function(descendant)
    if descendant.Name == NOTE_MODEL_NAME and (descendant:IsA("Model") or descendant:IsA("BasePart")) then
        attachTo(descendant)
    end
end)

Players.PlayerRemoving:Connect(function(player)
    player:SetAttribute("RecoveredAdminCredentials", nil)
end)
