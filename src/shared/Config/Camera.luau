--!strict
-- Camera limits (spec 3.1). The server copies these to StarterPlayer at boot, so every player gets them on join.
-- Visible walls round the hub and biomes are built taller than the zoom limit so no camera angle sees over them
-- (spec 16); if CameraMaxZoomDistance goes up, raise the walls in the place file to match.

local Types = require(script.Parent.Parent.Types)
local deepFreeze = require(script.Parent.Parent.Util.DeepFreeze)

local Camera: Types.CameraConfig = {
	CameraMaxZoomDistance = 80, -- studs; starting value, tune at C01-M3 with 300-critter lines
}

return deepFreeze(Camera)
