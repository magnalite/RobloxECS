
local ShowTags = {}
	
function ShowTags.OnAdd(e)
	ShowTags[e] = false
end	
	
function ShowTags.OnRemove(e)
	ShowTags[e] = nil
end

return ShowTags
