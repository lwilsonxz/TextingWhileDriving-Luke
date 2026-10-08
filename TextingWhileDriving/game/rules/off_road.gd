class_name OffRoadRule
extends TrafficRule
## Leaving the road: the car spends more than `grace_seconds` off the road
## tiles of a GridMap. Works over the whole level, so it needs no zone shape.
## Counted once per trip off the road.
##
## "On the road" means a road tile under the car. A tile is 12 m square, so
## its grassy edges count as road; good enough until the road kit has
## separate kerb pieces.

## The GridMap with the level's roads.
@export var roads: GridMap
## Seconds off the road before it counts (cutting a corner is fine).
@export var grace_seconds := 1.0

var _off_road_for := 0.0
var _counted := false


func _init() -> void:
	rule = &"off_road"


func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group(&"player_car") as Node3D
	if player == null or roads == null:
		return
	if is_on_road(player.global_position):
		_off_road_for = 0.0
		_counted = false
		return
	_off_road_for += delta
	if _off_road_for > grace_seconds and not _counted:
		_counted = true
		broken("Left the road")


## true if there's a road tile under `point` (world position).
func is_on_road(point: Vector3) -> bool:
	var cell := roads.local_to_map(roads.to_local(point))
	# The road may be a level or two below the car's cell (tiles sit at y = -1).
	for below in 3:
		if roads.get_cell_item(cell - Vector3i(0, below, 0)) != GridMap.INVALID_CELL_ITEM:
			return true
	return false
