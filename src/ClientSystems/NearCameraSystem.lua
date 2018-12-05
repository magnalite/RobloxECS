local ECS = require(script.Parent.Parent)

local NearCamera     = ECS.Components.NearCamera
local PositionListen = ECS.Components.PositionListen
local Explode      = ECS.Components.Explode

local entities = ECS.DeclareSystemDependance{PositionListen}

local System = {}

function System.Heartbeat(delta)
		
	local cameraPosition = game.Workspace.CurrentCamera.CFrame.p
	
	for i, entity in pairs(entities) do
		
		local dist = (entity.Position - cameraPosition).magnitude
		
		if dist < 50 then
            ECS.AddComponent(entity, NearCamera)
			NearCamera[entity] = dist
		else
			ECS.RemoveComponent(entity, NearCamera)
		end
	end
end

return System
