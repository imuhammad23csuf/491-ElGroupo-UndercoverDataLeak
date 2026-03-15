local player = game.Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local humanoid
local animate
local crouching = false

local function setupCharacter(character)
    humanoid = character:WaitForChild("Humanoid")
end

if player.Character then
    setupCharacter(player.Character)
end

player.CharacterAdded:Connect(setupCharacter)

-- Crouch when holding LeftShift
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if input.KeyCode == Enum.KeyCode.LeftShift then
        crouching = true
        humanoid.WalkSpeed = 6

        local animation = Instance.new("Animation")
        animation.AnimationId = "rbxassetid://89110259028624"

        animate = humanoid:LoadAnimation(animation)
        animate:Play()
    end
end)

-- Stop crouch when releasing LeftShift
UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.LeftShift then
        crouching = false
        humanoid.WalkSpeed = 16

        if animate then
            animate:Stop()
        end
    end
end)

-- Stop animation when not moving
RunService.RenderStepped:Connect(function()
    if crouching and humanoid then
        if humanoid.MoveDirection.Magnitude < 0.1 then
            if animate and animate.IsPlaying then
                animate:Stop()
            end
        else
            if animate and not animate.IsPlaying then
                animate:Play()
            end
        end
    end
end)