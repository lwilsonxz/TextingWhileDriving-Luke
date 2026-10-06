extends Area3D
## A stop sign. If the car drives through without (nearly) stopping, it shows
## "TRAFFIC VIOLATION!" on the car's HUD.
##
## How it works: the Area3D covers the road at the sign. While the car is inside,
## we track its speed along the direction of travel; when it leaves, if it never
## dropped below ENFORCEMENT_THRESHOLD, it ran the sign.
##
## Setting one up: the CollisionShape3D's blue (+Z) axis must point back towards
## oncoming traffic, and the area's body_entered / body_exited signals must be
## connected to the functions below (roadmap C1 makes this a drag-in piece).
##
## NOTE: roadmap step B3 turns this into a general TrafficRule. Known limits:
## it tracks one car at a time, prints every frame while the car is inside, and
## writes straight to the car's HUD label.

## Which way traffic should be moving through the sign: the collision shape's +Z
## axis. Speeds along it are negative when driving towards the sign as intended.
var stop_sign_unit_vector: Vector3
## The car currently inside the area (null when empty).
var contained_body
## Speed (m/s) along stop_sign_unit_vector that still counts as "stopped".
## Driving through faster than 5 m/s (18 km/h) without slowing is a violation.
const ENFORCEMENT_THRESHOLD = -5.0
## The slowest the car went while inside (the most negative = fastest through).
var min_stop_sign_projected_speed: float
@onready var collision_shape_3d = $CollisionShape3D


func _ready():
	# TODO - obtain actual normal vector that accounts for rotation etc.
	stop_sign_unit_vector = collision_shape_3d.global_transform.basis.z


## The car's speed along the sign's direction (m/s, negative = towards the sign).
## NOTE: uses contained_body, not the body argument.
func get_body_projected_speed(body):
	return stop_sign_unit_vector.dot(contained_body.get_linear_velocity())


func _process(delta):
	if contained_body:
		var stop_sign_projected_speed: float = get_body_projected_speed(contained_body)
		print("Projected Speed: " + str(stop_sign_projected_speed))
		min_stop_sign_projected_speed = min(min_stop_sign_projected_speed, stop_sign_projected_speed)


func _on_body_entered(body):
	contained_body = body
	min_stop_sign_projected_speed = get_body_projected_speed(contained_body)


func _on_body_exited(body):
	if min_stop_sign_projected_speed < ENFORCEMENT_THRESHOLD:
		print("=========== TRAFFIC VIOLATION !!! ===========")
		print("Body min speed: " + str(min_stop_sign_projected_speed))
		body.get_node("Hud/traffic_violation").text = "TRAFFIC VIOLATION!"

	contained_body = null
	min_stop_sign_projected_speed = 0.0
