class_name PhoneMount
extends Node3D
## Holds the phone and puts it in one of a few places in the car, so playtesters
## can feel how placement changes the danger of looking away from the road.
## The phone is turned to face the driver, and the camera's phone view is aimed
## at it, so adding a placement only needs a position.
##
## The placement comes from Settings (F7 in game cycles through them).

## Where the driver's eyes are, relative to the car (the camera's road view).
const EYES := Vector3(-0.283, 1.199, 0.459)
## When glancing at the phone, the driver leans this far towards it (metres).
const LEAN := 0.12
## The phone glance zooms in until the phone screen fills this much of the view's
## height (stands in for the eyes focusing on it; small text should be readable).
const SCREEN_FILL := 0.6
## Height of phone.tscn's screen quad before PHONE_SCALE (metres).
const QUAD_HEIGHT := 0.8

## Phone positions relative to the car (front of the car is -Z, driver sits at -X).
const PLACEMENTS := {
	&"dash_mount": Vector3(0.02, 0.98, -0.12),     # on the dashboard, right of the wheel: a small glance
	&"vent_mount": Vector3(0.1, 0.84, -0.04),      # clipped to the centre air vent: a bit lower
	&"centre_console": Vector3(0.08, 0.6, 0.2),    # lying by the gear stick: a big look down and right
	&"lap": Vector3(-0.28, 0.72, 0.18),            # in the driver's lap: eyes fully off the road
	&"windshield": Vector3(-0.12, 1.08, -0.22),    # on top of the dash in front of the driver: barely looks away, but blocks a little road
}

## Real phone size compared with phone.tscn's screen quad (0.38 × 0.8 m).
const PHONE_SCALE := 0.2

@export var placement := &"dash_mount"
## Follow Settings.phone_placement (turn off to pin a placement in a scene).
@export var follow_settings := true


func _ready() -> void:
	# Use the playtest setting for placement, and follow it if F7 changes it.
	var settings := get_node_or_null("/root/Settings")
	if follow_settings and settings != null:
		placement = settings.phone_placement
		settings.changed.connect(func(setting):
			if setting == &"phone_placement":
				apply(settings.phone_placement))
	apply(placement)


## Moves the phone to a named placement.
func apply(new_placement: StringName) -> void:
	if not PLACEMENTS.has(new_placement):
		push_warning("Unknown phone placement '%s'" % new_placement)
		return
	placement = new_placement
	place_at(PLACEMENTS[placement])


## Moves the phone to a spot (relative to the car) and aims the camera's phone view at it.
func place_at(spot: Vector3) -> void:
	# Turn the screen (the phone's +Z side) towards the driver's eyes.
	var facing := Basis.looking_at(spot - EYES, Vector3.UP)
	transform = Transform3D(facing.scaled(Vector3.ONE * PHONE_SCALE), spot)

	var camera := get_parent().get_node_or_null("FirstPersonCamera") as CarCamera
	if camera == null:
		return
	# Aim the phone view: lean from the eyes towards the screen, then zoom so the
	# screen fills SCREEN_FILL of the view (field of view from its size and distance).
	var screen := transform * _screen_offset()
	var to_screen := (screen - EYES).normalized()
	var eye := EYES + to_screen * LEAN
	var distance := eye.distance_to(screen)
	var fov := rad_to_deg(2.0 * atan(QUAD_HEIGHT * PHONE_SCALE / SCREEN_FILL / 2.0 / distance))
	camera.set_view_pose(CarCamera.PHONE, eye, Basis.looking_at(to_screen, Vector3.UP).get_euler(), fov)


## Where the screen's centre is inside the phone scene (the quad sits above the phone's origin).
func _screen_offset() -> Vector3:
	var quad := get_node_or_null("Phone/ViewportQuad") as Node3D
	return quad.position if quad else Vector3.ZERO


## Where the middle of the phone's screen is, in world space (for tests and aiming).
func screen_center() -> Vector3:
	var phone := get_node_or_null("Phone") as Node3D
	var quad := phone.get_node_or_null("ViewportQuad") as Node3D if phone else null
	return quad.global_position if quad else global_position
