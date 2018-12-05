local CollectionService = game:GetService("CollectionService")
local RunService        = game:GetService("RunService")

local ECS = {}
ECS.Started = false

--Find and register all components
function ECS.CollectComponents()
	ECS.Components = {}
	ECS.Assets = game.ReplicatedStorage.Assets
	ECS.EntitiesWithComponents = {}
	ECS.Entities = {}
	
	local loadedComponents = 0
	
	for _, component in pairs(script.Components:GetChildren()) do
		local name = component.Name
		
		ECS.Components[name] = require(component)
		ECS.Components[name].Name = name
		
		loadedComponents = loadedComponents + 1
	end
	
	print("ECS: ✔️ Registered", loadedComponents, "components.")
end

--Find initially spawned entities
function ECS.FindInitialEntities()
	
	for name, component in pairs(ECS.Components) do
		
		local entities = CollectionService:GetTagged(name)
		
		for _, entity in pairs(entities) do
			ECS.EntityComponentAdded(entity, component)
		end
	end
end

--Add a component to entity (this is cached and may be spammed safely)
function ECS.AddComponent(entity, component, useTag)
	if component[entity] == nil then
		if useTag then
			CollectionService:AddTag(entity, component.Name)
		else
			ECS.EntityComponentAdded(entity, component)
		end
	end
end

--Remove a component from entity (this is cached and may be spammed safely)
function ECS.RemoveComponent(entity, component, useTag)
	if component[entity] ~= nil then
		if useTag then
			CollectionService:RemoveTag(entity, component.Name)
		else
			ECS.EntityComponentRemoved(entity, component)
		end
	end
end

--Initiate listening for tags
function ECS.StartTagListen()
	
	for name, component in pairs(ECS.Components) do
		CollectionService:GetInstanceAddedSignal(name):Connect(function(entity)
			ECS.EntityComponentAdded(entity, component)
		end)
	end
	
	for name, component in pairs(ECS.Components) do
		CollectionService:GetInstanceRemovedSignal(name):Connect(function(entity)
			ECS.EntityComponentRemoved(entity, component)
		end)
	end
end

--Event for when a component is added to an entity
function ECS.EntityComponentAdded(entity, component)
	
	if ECS.Entities[entity] then
		table.insert(ECS.Entities[entity], component)
	else
		ECS.Entities[entity] = {component}
	end
	
	component.OnAdd(entity)
	
	local dependentCollections = ECS.SystemDependence[component]
	
	
	if not dependentCollections then
		return
	end
	
	for _, dependence in pairs(dependentCollections) do
		local list       = ECS.EntitiesWithComponents[dependence]
		
		if list and ECS.EntityFullfillsDependence(entity, dependence) then
		
			local alreadyExists
			
			for _, e in pairs(list) do
				if e == entity then
					alreadyExists = true
					break
				end
			end
			
			if not alreadyExists then
				table.insert(list, entity)
				
				if ECS.SystemFromDependence[dependence] then
					ECS.SystemFromDependence[dependence].FoundEntity(entity)
				end
			end
		end
	end
end

--Event for when a component is removed from an entity
function ECS.EntityComponentRemoved(entity, component)
	
	for i, c in pairs(ECS.Entities[entity]) do
		if c == component then
			table.remove(ECS.Entities[entity], i)
		end
	end
	
	local dependentCollections = ECS.SystemDependence[component]
	
	if dependentCollections then

		for _, dependence in pairs(dependentCollections) do
			local list = ECS.EntitiesWithComponents[dependence]
			
			if list then
				for index, e in pairs(list) do
					if e == entity then
						table.remove(list, index)
						
						if ECS.SystemFromDependence[dependence] then
							ECS.SystemFromDependence[dependence].LostEntity(entity)
						end
						
						break
					end
				end
			end
		end
	end
	
	component.OnRemove(entity)
end

--Find and register all systems
function ECS.CollectSystems()
	ECS.Systems = {}
	ECS.SystemInst = {}
	ECS.SystemDependence = {}
	ECS.SystemFromDependence = {}
	ECS.DependenceFromSystem = {}

	local loadedSystems = 0

	if RunService:IsServer() then
		for _, system in pairs(script.ServerSystems:GetChildren()) do
			loadedSystems = loadedSystems + 1
			ECS.Systems[system.Name] = require(system)
			ECS.SystemInst[system.Name] = system
			ECS.WatchSystemUpdates(system)
		end
		print("ECS: ✔️ Registered", loadedSystems, " server systems.")
	end

	if RunService:IsServer() then
		for _, system in pairs(script.ClientSystems:GetChildren()) do
			loadedSystems = loadedSystems + 1
			ECS.Systems[system.Name] = require(system)
			ECS.WatchSystemUpdates(system)
		end
		print("ECS: ✔️ Registered", loadedSystems, " client systems.")
	end
end

function ECS.WatchSystemUpdates(systemInst)
	local signal
	signal = systemInst.Changed:Connect(function()
		ECS.HotReloadSystem(systemInst)	
	end)
end

--OOOOH This seems dangerous
function ECS.HotReloadSystem(systemInst)
	local system = ECS.Systems[systemInst.Name]
	local oldDependence = ECS.DependenceFromSystem[system]

	if oldDependence then
		for _, entity in pairs(ECS.EntitiesWithComponents[oldDependence]) do
			system.LostEntity(entity)
		end
	end

	local newsystemInst = systemInst:Clone()
	newsystemInst.Parent = systemInst.Parent

	ECS.Systems[systemInst.Name] = require(newsystemInst)

	local newsystem = ECS.Systems[systemInst.Name]
	local dependence = ECS.DependenceFromSystem[newsystem]

	if dependence then
		for _, entity in pairs(ECS.EntitiesWithComponents[dependence]) do
			newsystem.FoundEntity(entity)
		end
	end

	if oldDependence then
		ECS.RenewSystemDependance(newsystem, oldDependence, dependence, ECS.DependenceFromSystem[system])
	end

	newsystemInst:Destroy()
	print("ECS: 🔥 Hot reloaded", systemInst.Name, "🔥")
end

--Attach systems to Heartbeat
function ECS.InitiateSystems()
	RunService.Heartbeat:Connect(ECS.Heartbeat)
	print("ECS: 🚀 Liftoff!")
end

--Internal Heartbeat event
function ECS.Heartbeat(delta)
	for name, system in pairs(ECS.Systems) do
		system.Heartbeat(delta)
	end
end

--Check if an entity is suitable for a system
function ECS.EntityFullfillsDependence(entity, dependence)
	for i = 1, #dependence do	
		if dependence[i][entity] == nil then
			return false
		end
	end
	
	return true
end

--Declare what components a system needs
function ECS.DeclareSystemDependance(dependence, system)
	for _, component in pairs(dependence) do
		ECS.SystemDependence[component] = ECS.SystemDependence[component] or {}
		table.insert(ECS.SystemDependence[component], dependence)
		
		if system then
			ECS.SystemFromDependence[dependence] = system
			ECS.DependenceFromSystem[system] = dependence
		end
	end
	
	return ECS.CalculateEntitiesFromDependence(dependence)
end

function ECS.RenewSystemDependance(system, oldDependence, newDependence, isExtended)

	for _, component in pairs(oldDependence) do
		ECS.SystemDependence[component] = ECS.SystemDependence[component] or {}

		for i, v in pairs(ECS.SystemDependence[component]) do
			if v == oldDependence then
				table.remove(ECS.SystemDependence[component], i)
				break
			end
		end
	end


	for _, component in pairs(newDependence) do
		ECS.SystemDependence[component] = ECS.SystemDependence[component] or {}
		table.insert(ECS.SystemDependence[component], newDependence)

	end

	ECS.EntitiesWithComponents[oldDependence] = nil 
end

--Collect the entities which fulfill systems component dependence
function ECS.CalculateEntitiesFromDependence(dependence)
	local initialList = CollectionService:GetTagged(dependence[1].Name)
	local finalList = {}
	
	for _, entity in pairs(initialList) do 
		
		if ECS.EntityFullfillsDependence(entity, dependence) then
			table.insert(finalList, entity)
		end
	end
	
	ECS.EntitiesWithComponents[dependence] = finalList
	--print(#finalList, dependence[1].Name)
	return finalList
end

--Returns a list of the components attach to entity
function ECS.ComponentsOfEntity(entity)
	return ECS.Entities[entity]
end

--Start the ECS system automatically
--Will prevent startup twice within the same environment
--To force past this pass bypassStartedCheck as true
function ECS.AutoInitiate(bypassStartedCheck)

	if ECS.Started and not bypassStartedCheck then
		print("ECS: 📡 In flight! (Extra startup prevented)")
		return
	end

	ECS.Started = true
	ECS.CollectComponents()
	ECS.CollectSystems()
	ECS.FindInitialEntities()
	ECS.StartTagListen()
	ECS.InitiateSystems()
end

return ECS


