extends RefCounted
## Shared world dimensions keep roads, recovery, routes and the minimap aligned.
const ROADS = [-576,-504,-432,-360,-288,-216,-144,-72,0,72,144,216,288,360,432,504,576]
const BLOCKS = [-540,-468,-396,-324,-252,-180,-108,-36,36,108,180,252,324,396,468,540]
const HALF_EXTENT: float = 602.0
const WORLD_X: float = 640.0
const WORLD_Z: float = 1700.0
const RECOVERY_LIMIT: float = 1760.0
const MAP_SCALE: float = 77.0 / WORLD_Z
const MAP_FIT = Vector2(77.0/WORLD_X,77.0/WORLD_Z)
