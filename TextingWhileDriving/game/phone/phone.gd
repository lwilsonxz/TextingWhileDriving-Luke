extends Node3D
## The phone inside the car (game/phone/phone.tscn). Conversations play on it
## through PhoneService.
##
## How it works: the phone's screen is a ChatView (2D UI) drawn into a
## SubViewport, and that drawing is the texture of a flat quad (ViewportQuad)
## in the car, so 2D UI appears on a 3D object.
##
## A SubViewport drawn on a quad doesn't get any input by itself, so this
## script passes it on: key presses as they are (for typing), and mouse
## events moved to where the mouse points on the quad (for tapping choices).
## By default this only happens while the driver is looking at the phone
## (Settings.phone_typing_needs_glance, F8 in game).

## Size of the screen's 2D layout in pixels (the quad's shape: 0.38 × 0.8 m).
const SCREEN_SIZE := Vector2i(304, 640)
## The screen is drawn at this multiple of SCREEN_SIZE so text stays sharp up close.
const SHARPNESS := 2

## The conversation screen.
@onready var view: ChatView = $SubViewport/ChatView
@onready var _viewport: SubViewport = $SubViewport
@onready var _quad: MeshInstance3D = $ViewportQuad


func _ready() -> void:
	# Draw the 2D screen at SHARPNESS times its layout size.
	_viewport.size = SCREEN_SIZE * SHARPNESS
	_viewport.size_2d_override = SCREEN_SIZE
	_viewport.size_2d_override_stretch = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	# Show the drawing on the quad. Unshaded: a screen gives off its own light,
	# so it stays readable whatever the lighting in the car.
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = _viewport.get_texture()
	_quad.material_override = material

	var service := get_node_or_null("/root/PhoneService")
	if service != null:
		service.attach_view(view)


func _exit_tree() -> void:
	var service := get_node_or_null("/root/PhoneService")
	if service != null:
		service.detach_view(view)


## Where a point on the game window lands on the phone screen, in the screen's
## 2D pixels, or null if the mouse isn't pointing at the screen.
func screen_point(window_position: Vector2) -> Variant:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null
	# Follow the ray from the camera through the mouse until it meets the quad's
	# plane. The quad is Godot's PlaneMesh: a 2 × 2 square on its local XZ plane.
	var to_local := _quad.global_transform.affine_inverse()
	var origin := to_local * camera.project_ray_origin(window_position)
	var direction := to_local.basis * camera.project_ray_normal(window_position)
	if is_zero_approx(direction.y):
		return null
	var hit := origin - direction * (origin.y / direction.y)
	if absf(hit.x) > 1.0 or absf(hit.z) > 1.0 or origin.y / direction.y > 0.0:
		return null
	# -1..1 on the quad becomes 0..SCREEN_SIZE on the screen (local -Z is the top).
	return Vector2((hit.x + 1.0) / 2.0 * SCREEN_SIZE.x, (hit.z + 1.0) / 2.0 * SCREEN_SIZE.y)


## Where a point on the phone screen (2D pixels) is in the world. The opposite of
## screen_point(); tests use it to find where to click.
func screen_to_world(point: Vector2) -> Vector3:
	var local := Vector3(point.x / SCREEN_SIZE.x * 2.0 - 1.0, 0.0, point.y / SCREEN_SIZE.y * 2.0 - 1.0)
	return _quad.global_transform * local


# Passes keys and mouse events to the phone screen while the phone is usable.
# Anything the screen uses (a typed letter, a tapped button) is marked handled
# so it doesn't also do something else in the game.
func _input(event: InputEvent) -> void:
	if not _accepts_input():
		return
	if event is InputEventKey:
		_viewport.push_input(event)
	elif event is InputEventMouse:
		var point: Variant = screen_point(event.position)
		if point == null:
			return
		var moved: InputEventMouse = event.duplicate()
		moved.position = point
		moved.global_position = point
		_viewport.push_input(moved, true)
	else:
		return
	if _viewport.is_input_handled():
		get_viewport().set_input_as_handled()


# Whether the phone takes keys and clicks right now: while the driver looks at
# it, or always if the playtest option says typing doesn't need a glance.
func _accepts_input() -> bool:
	var settings := get_node_or_null("/root/Settings")
	if settings != null and not settings.phone_typing_needs_glance:
		return true
	var camera := get_viewport().get_camera_3d() as CarCamera
	return camera != null and camera.is_looking_at_phone()
