class_name TrafficRule
extends Area3D
## Base for traffic rules (stop sign, speed limit, staying on the road, ...).
## A rule watches the player's car and reports to the level's LevelState
## when the car breaks it (or obeys it).
##
## Most rules are zones: an Area3D with a CollisionShape3D, active while the
## car is inside. A new rule extends this, uses `car_entered` / `car_exited` /
## `_physics_process` as it needs, and calls `broken()` or `obeyed()`.

## Fired when the player's car breaks this rule.
signal rule_broken(description: String)

## Short id for the rule, e.g. &"stop_sign". Dialogue functions and tests use it.
@export var rule := &""

## The player's car while it's inside this rule's zone, else null.
var car: VehicleBody3D


func _ready() -> void:
	body_entered.connect(func(body: Node3D):
		if body.is_in_group(&"player_car"):
			car = body
			car_entered())
	body_exited.connect(func(body: Node3D):
		if body == car:
			car_exited()
			car = null)


## Called when the player's car drives into the zone. Override as needed.
func car_entered() -> void:
	pass


## Called when the player's car leaves the zone (`car` is still set). Override as needed.
func car_exited() -> void:
	pass


## Reports that the car broke the rule. `description` is shown to the player.
func broken(description: String) -> void:
	var state := LevelState.find(self)
	if state != null:
		state.record_violation(rule, description)
	rule_broken.emit(description)


## Reports that the car was checked and obeyed the rule.
func obeyed() -> void:
	var state := LevelState.find(self)
	if state != null:
		state.record_obeyed(rule)


## The car's speed along a direction, in km/h (negative when moving the other way).
static func speed_along_kmh(body: VehicleBody3D, direction: Vector3) -> float:
	return body.linear_velocity.dot(direction.normalized()) * 3.6
