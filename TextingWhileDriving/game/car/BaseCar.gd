extends VehicleBody3D
## Player car. Reads the drive_* input actions (gamepad triggers are analog)
## and turns them into engine force, brakes and steering. Everything runs in
## _physics_process on real units (m/s), so it behaves the same at any frame rate.
##
## The car's front faces -Z, so driving forward means negative engine_force.

## Below this speed (m/s) the car counts as stopped: pressing the opposite
## direction drives instead of braking.
const STOPPED_SPEED := 1.0

@export_group("Steering")
## Maximum steering angle, in radians.
@export var steer_limit := 0.6
## How fast the wheels turn towards the target angle, in radians per second.
@export var steer_speed := 1.5

@export_group("Engine")
# Defaults are tuned to feel like an ordinary road car (measured on flat ground):
# 0–100 km/h in about 9 s, top speed about 140 km/h, 100–0 km/h in about 3.3 s.

## Engine force once the car is up to speed.
@export var cruise_force := 45.0
## Extra pull from a standstill: force is cruise_force × boost ÷ speed (m/s),
## never below cruise_force or above max_force.
@export var launch_boost := 10.0
@export var reverse_boost := 3.0
@export var max_force := 65.0
## Engine force fades out over the last 15% below these speeds.
@export var top_speed_kmh := 160.0
@export var reverse_top_speed_kmh := 25.0

@export_group("Brakes")
## Brake when pressing the opposite direction to travel.
@export var brake_force := 1.2
@export var handbrake_force := 1.0
## Rear wheel grip, normally and with the handbrake on (lower = slides more).
@export var rear_grip := 3.0
@export var handbrake_rear_grip := 0.8

@export_group("Handling")
## Pushes the car into the road, per m/s of speed, for grip at high speed.
@export var downforce := 0.5


## Courses, traffic rules and triggers recognise the player's car by this group.
const GROUP := &"player_car"


func _ready() -> void:
	add_to_group(GROUP)


# F5 (debug): stop responding to the driving controls, e.g. to test typing alone.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle_driving"):
		Global.is_driving = not Global.is_driving


# Runs every physics tick (60 times a second): read the controls, then set the
# engine, brakes and steering for Godot's vehicle physics to apply.
func _physics_process(delta: float) -> void:
	var speed := linear_velocity.length()
	apply_central_force(Vector3.DOWN * downforce * speed)
	$Hud/speed.text = "%d km/h" % roundi(speed * 3.6)  # m/s to km/h

	# Start from "coasting" each tick; the controls below add to it.
	engine_force = 0.0
	brake = 0.0
	if not Global.is_driving:
		_set_rear_grip(rear_grip)
		return

	var speed_forward := forward_speed()
	var throttle := Input.get_action_strength("drive_accelerate")
	var reverse := Input.get_action_strength("drive_reverse")
	# Accelerate: if rolling backwards, brake first; otherwise drive forward.
	# Reverse: if rolling forwards, brake first; otherwise drive backwards.
	# Triggers are analog, so half pressed means half the force or braking.
	if throttle > 0.0:
		if speed_forward < -STOPPED_SPEED:
			brake = brake_force * throttle
		else:
			engine_force = -_drive_force(speed_forward, launch_boost, top_speed_kmh) * throttle
	elif reverse > 0.0:
		if speed_forward > STOPPED_SPEED:
			brake = brake_force * reverse
		else:
			engine_force = _drive_force(-speed_forward, reverse_boost, reverse_top_speed_kmh) * reverse

	# Handbrake: brakes and loosens the rear wheels' grip, so the back can slide out.
	if Input.is_action_pressed("drive_handbrake"):
		brake = handbrake_force
		_set_rear_grip(handbrake_rear_grip)
	else:
		_set_rear_grip(rear_grip)

	# Steering: -1 (full right) to +1 (full left), turned gradually rather than snapping.
	var steer_input := Input.get_action_strength("drive_steer_left") - Input.get_action_strength("drive_steer_right")
	steering = move_toward(steering, steer_input * steer_limit, steer_speed * delta)


## Speed along the direction the car faces, in m/s (negative when reversing).
func forward_speed() -> float:
	return linear_velocity.dot(-global_basis.z)


# Engine force for the current speed: extra pull when slow (launch boost), the
# cruise force once moving, fading to nothing as the car nears its top speed.
func _drive_force(speed_in_direction: float, boost: float, limit_kmh: float) -> float:
	var speed := maxf(speed_in_direction, 0.01)
	var top_speed := limit_kmh / 3.6
	var fade := clampf((top_speed - speed) / (top_speed * 0.15), 0.0, 1.0)
	return clampf(cruise_force * boost / speed, cruise_force, max_force) * fade


# Rear wheels are wheal2 and wheal3 (names from the original Car-Demo).
func _set_rear_grip(grip: float) -> void:
	$wheal2.wheel_friction_slip = grip
	$wheal3.wheel_friction_slip = grip
