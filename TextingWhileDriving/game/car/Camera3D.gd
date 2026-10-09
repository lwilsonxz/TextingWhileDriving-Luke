class_name CarCamera
extends Camera3D
## The driver's camera. Each view is a position and rotation inside the car;
## the camera glides between them.
##
## Where the driver looks is the core mechanic, so other systems (the phone UI,
## later traffic or story events) can ask is_looking_at_phone() or listen to
## view_changed instead of reading input themselves. Looking away never takes
## control away: the car and the phone both work at all times (see the
## "Texting and driving" decision in docs/ROADMAP.md).

signal view_changed(view: StringName)

enum PhoneGlance {
	TOGGLE, ## press to look at the phone, press again to look back at the road
	HOLD,   ## look at the phone only while the button is held
}

const ROAD := &"road"
const REAR := &"rear"
const LEFT_WINDOW := &"left_window"
const PHONE := &"phone"

## Default position and rotation (radians) of each view, relative to the car.
## The phone view is re-aimed by PhoneMount at wherever the phone is.
const VIEWS := {
	ROAD: {"position": Vector3(-0.283, 1.199, 0.459), "rotation": Vector3(0, 0, 0)},
	REAR: {"position": Vector3(0, 2, 5), "rotation": Vector3(0, 0, 0)},
	LEFT_WINDOW: {"position": Vector3(-0.285, 1.199, 0.459), "rotation": Vector3(0, 1.5, 0)},
	PHONE: {"position": Vector3(-0.27, 1.199, 0.459), "rotation": Vector3(-0.7, -0.85, 0)},
}

## How the phone button works. Both are worth playtesting (docs/ROADMAP.md, B1).
@export var phone_glance := PhoneGlance.TOGGLE
## Follow Settings.phone_glance (F6 in game switches it). Turn off to pin it.
@export var follow_settings := true
## How quickly the camera reaches a new view. Higher is snappier.
@export var glide_speed := 6.0

var view := ROAD
## This camera's own copy of VIEWS, so each car can aim its phone view.
var views := VIEWS.duplicate(true)
## Field of view for views that don't set their own.
var _base_fov := 75.0


func _ready() -> void:
	# Use the playtest setting for toggle vs hold, and follow it if F6 changes it.
	var settings := get_node_or_null("/root/Settings")
	if follow_settings and settings != null:
		phone_glance = settings.phone_glance
		settings.changed.connect(func(setting):
			if setting == &"phone_glance":
				phone_glance = settings.phone_glance)
	_base_fov = fov
	_snap_to(view)


## Changes where a view looks from and to, and optionally its field of view
## in degrees (PhoneMount uses this to aim and zoom the phone view).
func set_view_pose(view_name: StringName, view_position: Vector3, view_rotation: Vector3, view_fov := 0.0) -> void:
	views[view_name] = {"position": view_position, "rotation": view_rotation}
	if view_fov > 0.0:
		views[view_name].fov = view_fov


## Switches to a view; the camera then glides there.
func set_view(new_view: StringName) -> void:
	if new_view == view or not views.has(new_view):
		return
	view = new_view
	view_changed.emit(view)


## True while the driver's eyes are on the phone (and so off the road).
func is_looking_at_phone() -> bool:
	return view == PHONE


## Jumps straight to a view without gliding (spawning, tests).
func snap_to(new_view: StringName) -> void:
	set_view(new_view)
	_snap_to(view)


# Each frame: react to the view buttons, then move a little closer to the
# current view's position, rotation and zoom.
func _process(delta: float) -> void:
	_read_input()
	var target: Dictionary = views[view]
	var weight := 1.0 - exp(-glide_speed * delta)  # same glide at any frame rate
	position = position.lerp(target.position, weight)
	quaternion = quaternion.slerp(Quaternion.from_euler(target.rotation), weight)
	fov = lerpf(fov, target.get("fov", _base_fov), weight)


# The view buttons. Pressing a view's button again returns to the road.
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


# Jumps the camera to a view instantly.
func _snap_to(view_name: StringName) -> void:
	position = views[view_name].position
	quaternion = Quaternion.from_euler(views[view_name].rotation)
	fov = views[view_name].get("fov", _base_fov)
