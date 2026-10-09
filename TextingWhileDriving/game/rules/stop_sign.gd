class_name StopSign
extends TrafficRule
## A stop sign. Traffic driving through the zone must (nearly) stop before
## leaving it; driving through without slowing below `stop_speed_kmh` is a
## violation.
##
## Setting one up: the zone covers the road just before the sign. Traffic
## that must stop drives along the zone's -Z axis (the way Godot's blue arrow
## points backwards); cars going the other way are ignored.

## Slowest speed that still counts as "didn't stop" (a rolling stop below
## this is fine). 18 km/h is generous on purpose: the player is busy texting.
@export var stop_speed_kmh := 18.0

# The slowest the car went through the zone, along the direction of travel (km/h).
var _slowest_kmh := INF


func _init() -> void:
	rule = &"stop_sign"


func car_entered() -> void:
	_slowest_kmh = _forward_kmh()


func _physics_process(_delta: float) -> void:
	if car != null:
		_slowest_kmh = minf(_slowest_kmh, _forward_kmh())


func car_exited() -> void:
	_slowest_kmh = minf(_slowest_kmh, _forward_kmh())
	if _slowest_kmh <= 0.0 and _forward_kmh() <= 0.0:
		return  # went through the other way (or reversed out): not our traffic
	if _slowest_kmh > stop_speed_kmh:
		broken("Ran a stop sign")
	else:
		obeyed()


# The car's speed in the direction traffic should be moving (the zone's -Z).
func _forward_kmh() -> float:
	return speed_along_kmh(car, -global_basis.z)
