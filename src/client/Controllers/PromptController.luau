-- Prompts with an OwnerId attribute (the land signs and obstacles,
-- LandService) only show for that farm's owner: everyone else's copy is
-- switched off here, on their own screen.
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local PromptController = {}

local function check(prompt: Instance)
	if not prompt:IsA("ProximityPrompt") then
		return
	end
	local owner = prompt:GetAttribute("OwnerId")
	if owner then
		prompt.Enabled = owner == player.UserId
	end
end

function PromptController.Start()
	local world = workspace:WaitForChild("World")
	world.DescendantAdded:Connect(check)
	for _, descendant in world:GetDescendants() do
		check(descendant)
	end
end

return PromptController
