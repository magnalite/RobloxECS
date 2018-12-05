
local NearCamera = {}
	
function NearCamera.OnAdd(e)
	NearCamera[e] = true
end	
	
function NearCamera.OnRemove(e)
	NearCamera[e] = nil
end

return NearCamera
