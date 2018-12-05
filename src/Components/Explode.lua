
local Explode = {}
	
function Explode.OnAdd(e)
	Explode[e] = true
end	
	
function Explode.OnRemove(e)
	Explode[e] = nil
end

return Explode
