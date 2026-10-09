@tool
class_name SpeedZone
extends TrafficRule
## A speed limit for a stretch of road: going faster than `limit_kmh` (plus a
## little tolerance) anywhere inside the zone is a violation, once per visit.
##
## ART PLACEHOLDER: no speed limit sign model exists yet, so the zone is
## invisible in the game; see docs/ART_PLACEHOLDERS.md.

## The speed limit.
@export var limit_kmh := 50.0:
	set(value):
		limit_kmh = value
		if is_inside_tree():
			redraw_marker()
## How far over the limit is let off (speedometers aren't perfect).
@export var tolerance_kmh := 5.0

var _caught_this_visit := false


func _init() -> void:
	rule = &"speeding"


func marker_text() -> String:
	return "SPEED LIMIT %d" % roundi(limit_kmh)


func car_entered() -> void:
	_caught_this_visit = false


func _physics_process(_delta: float) -> void:
	if car == null or _caught_this_visit:
		return
	var kmh := car.linear_velocity.length() * 3.6
	if kmh > limit_kmh + tolerance_kmh:
		_caught_this_visit = true
		broken("Speeding: %d in a %d zone" % [roundi(kmh), roundi(limit_kmh)])


func car_exited() -> void:
	if not _caught_this_visit:
		obeyed()
