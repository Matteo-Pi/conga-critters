--!strict
-- Freezes a table and every table nested inside it, so Config can't be changed at runtime.

local function deepFreeze<T>(value: T): T
	local t = value :: any
	if type(t) == "table" and not table.isfrozen(t) then
		for _, child in t do
			deepFreeze(child)
		end
		table.freeze(t)
	end
	return value
end

return deepFreeze
