extends Camera3D
## A third-person camera that follows its parent node (from the original
## Car-Demo). Not used by any level today; kept for a possible chase or replay
## camera ("streamer" moments).
##
## NOTE: the last line puts the camera back on the target every frame, so the
## smoothing above it has no visible effect. Revisit if this camera is used.

## How far behind the target to stay (metres).
@export var target_distance = 0
## How far above the target to stay (metres).
@export var target_height = 0
## How quickly the camera catches up. Higher is snappier.
@export var speed:=20.0
## The node being followed (the parent).
var follow_this = null
## Smoothed point the camera looks at.
var last_lookat


func _ready():
	follow_this = get_parent()
	last_lookat = follow_this.global_transform.origin


func _physics_process(delta):
	var delta_v = global_transform.origin - follow_this.global_transform.origin
	var target_pos = global_transform.origin

	# Only keep the distance on the ground plane; height is handled separately.
	delta_v.y = 0.0

	if (delta_v.length() > target_distance):
		# Too far away: move to target_distance behind, at target_height.
		delta_v = delta_v.normalized() * target_distance
		delta_v.y = target_height
		target_pos = follow_this.global_transform.origin + delta_v
	else:
		target_pos.y = follow_this.global_transform.origin.y + target_height

	global_transform.origin = global_transform.origin.lerp(target_pos, delta * speed)

	last_lookat = last_lookat.lerp(follow_this.global_transform.origin, delta * speed)

	look_at((follow_this.global_transform.origin - Vector3(0,0, .1)), Vector3.UP)
	global_transform.origin = follow_this.global_transform.origin
