
local PositionListen = {}
	
function PositionListen.OnAdd(e)
	PositionListen[e] = true
end	
	
function PositionListen.OnRemove(e)
	PositionListen[e] = nil
end

return PositionListen
