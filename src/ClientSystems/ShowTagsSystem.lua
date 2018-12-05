local ECS = require(script.Parent.Parent)
local ShowTags       = ECS.Components.ShowTags
local NearCamera     = ECS.Components.NearCamera

local System = {}

local entities       = ECS.DeclareSystemDependance({ShowTags, NearCamera}, System)

local TagGui = ECS.Assets.ShowTagGui:Clone()
local TagLabel = ECS.Assets.ShowTagGui.Label:Clone()
TagGui.Label:Destroy()

function System.Heartbeat(delta)
	for i, entity in pairs(entities) do
		
		local componentsToShow = ECS.ComponentsOfEntity(entity)
		
		--Add any newly attached components
		for _, component in pairs(componentsToShow) do
			if not ShowTags[entity][component] then
				ShowTags[entity][component] = TagLabel:Clone()
				ShowTags[entity][component].Parent = ShowTags[entity].gui
				ShowTags[entity][component].Text = component.Name
			end
		end
		
		--Remove any no longer attached components
		for component, label in pairs(ShowTags[entity]) do
			if component ~= "gui" and not ECS.EntityFullfillsDependence(entity, {component}) then
				ShowTags[entity][component]:Destroy()
				ShowTags[entity][component] = nil
			end
		end
		
	end
end

function System.FoundEntity(entity)
	local gui = TagGui:Clone()
	gui.Parent = entity
	gui.Adornee = entity
	ShowTags[entity] = {
		gui = gui
	}
end


function System.LostEntity(entity)
    if ShowTags[entity] then
        ShowTags[entity].gui:Destroy()
    end

	ShowTags[entity] = false
end

return System
