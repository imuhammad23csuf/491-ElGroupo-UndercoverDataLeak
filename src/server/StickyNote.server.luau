local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CyberScenarioManager = require(Shared:WaitForChild("CyberScenarioManager"))

local NOTE_MODEL_NAME = "Sticky Note"
local connected = {}

local function handleInspect(player)
    if not player or not player:IsA("Player") then
        return
    end

    player:SetAttribute("RecoveredAdminCredentials", true)
    CyberScenarioManager.CheckSolution(player, "world_sticky_note inspect")
    require(game.ServerScriptService.Server.DecisionTracker).LogDecision(player, "FoundStickyNotePassword", true)
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

    for _, descendant in ipairs(instance:GetDescendants()) do
        if descendant:IsA("ProximityPrompt") then
            descendant:Destroy()
        end
    end

    local clickDetector = instance:FindFirstChildWhichIsA("ClickDetector", true)
    if not clickDetector then
        clickDetector = Instance.new("ClickDetector")
        clickDetector.MaxActivationDistance = 12
        clickDetector.Parent = part
    end

    clickDetector.MouseClick:Connect(handleInspect)
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
