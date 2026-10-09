@tool
class_name SpawnPoint
extends Marker3D
## Where the player's car starts, and which way it faces (the blue arrow,
## -Z, is forward). Put one on the road; when the level starts, the car is
## moved here.

## Lifts the car this far above the spawn point so its wheels don't start in the road.
const LIFT := 0.5


func _ready() -> void:
	if Engine.is_editor_hint():
		PieceMarker.draw(self, Color.LIME_GREEN, "START", true, Vector3(2, 1.5, 4.5))
		return
	# Wait until the whole level (and the car) is ready.
	_place_car.call_deferred()


## Puts the player's car on the spawn point, standing still. Only a car in the
## same level counts (tests can have several levels loaded).
func _place_car() -> void:
	var level := owner if owner != null else get_parent()
	var car: RigidBody3D = null
	for node in get_tree().get_nodes_in_group(&"player_car"):
		if level.is_ancestor_of(node):
			car = node
			break
	if car == null:
		push_warning("SpawnPoint: no player car in the level")
		return
	car.global_transform = Transform3D(global_basis.orthonormalized(), global_position + Vector3.UP * LIFT)
	car.linear_velocity = Vector3.ZERO
	car.angular_velocity = Vector3.ZERO
