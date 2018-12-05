local ECS = require(script.Parent.Parent)

local Explode = ECS.Components.Explode

local entities = ECS.DeclareSystemDependance{Explode}

local System = {}

function System.Heartbeat(delta)	
	for i, entity in pairs(entities) do
        
        if entity:IsA("Model") and entity.PrimaryPart then
            Instance.new("Explosion", workspace).Position = entity.PrimaryPart.Position
        else
            Instance.new("Explosion", workspace).Position = entity.Position
        end
        
        ECS.RemoveComponent(entity, Explode, true)
	end
end

return System
