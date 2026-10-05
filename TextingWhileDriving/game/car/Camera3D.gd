class_name CarCamera
extends Camera3D
## The driver's camera. Each view is a position and rotation inside the car;
## the camera glides between them.
##
## Looking at the phone is the core mechanic, so other systems (distraction,
## traffic rules, the phone UI) can ask is_looking_at_phone() or listen to
## view_changed instead of reading input themselves.

signal view_changed(view: StringName)

enum PhoneGlance {
	TOGGLE, ## press to look at the phone, press again to look back at the road
	HOLD,   ## look at the phone only while the button is held
}

const ROAD := &"road"
const REAR := &"rear"
const LEFT_WINDOW := &"left_window"
const PHONE := &"phone"

## Position and rotation (radians) of each view, relative to the car.
const VIEWS := {
	ROAD: {"position": Vector3(-0.283, 1.199, 0.459), "rotation": Vector3(0, 0, 0)},
	REAR: {"position": Vector3(0, 2, 5), "rotation": Vector3(0, 0, 0)},
	LEFT_WINDOW: {"position": Vector3(-0.285, 1.199, 0.459), "rotation": Vector3(0, 1.5, 0)},
	PHONE: {"position": Vector3(-0.27, 1.199, 0.459), "rotation": Vector3(-0.7, -0.85, 0)},
}

## How the phone button works. Both are worth playtesting (docs/ROADMAP.md, B1).
@export var phone_glance := PhoneGlance.TOGGLE
## How quickly the camera reaches a new view. Higher is snappier.
@export var glide_speed := 6.0

var view := ROAD


func _ready() -> void:
	_snap_to(view)


func set_view(new_view: StringName) -> void:
	if new_view == view or not VIEWS.has(new_view):
		return
	view = new_view
	view_changed.emit(view)


func is_looking_at_phone() -> bool:
	return view == PHONE


## Jumps straight to a view without gliding (spawning, tests).
func snap_to(new_view: StringName) -> void:
	set_view(new_view)
	_snap_to(view)


func _process(delta: float) -> void:
	_read_input()
	var target: Dictionary = VIEWS[view]
	var weight := 1.0 - exp(-glide_speed * delta)  # same glide at any frame rate
	position = position.lerp(target.position, weight)
	quaternion = quaternion.slerp(Quaternion.from_euler(target.rotation), weight)


func _read_input() -> void:
	if Input.is_action_just_pressed("camera_front_view"):
		set_view(ROAD)
	if Input.is_action_just_pressed("camera_rear_view"):
		set_view(ROAD if view == REAR else REAR)
	if Input.is_action_just_pressed("camera_left_window_view"):
		set_view(ROAD if view == LEFT_WINDOW else LEFT_WINDOW)
	match phone_glance:
		PhoneGlance.TOGGLE:
			if Input.is_action_just_pressed("camera_phone_view"):
				set_view(ROAD if view == PHONE else PHONE)
		PhoneGlance.HOLD:
			if Input.is_action_pressed("camera_phone_view"):
				set_view(PHONE)
			elif view == PHONE:
				set_view(ROAD)


func _snap_to(name: StringName) -> void:
	position = VIEWS[name].position
	quaternion = Quaternion.from_euler(VIEWS[name].rotation)
