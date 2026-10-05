extends SceneTree
## Drives the car on flat ground with simulated input and checks the controls.
## Each scenario starts from rest at the same spot. Time is counted in physics
## ticks (60 per second), so the results must not depend on the rendering frame
## rate; the test runs every scenario at several frame-rate caps and checks the
## numbers match.
##
##   godot --headless --path TextingWhileDriving --script res://../tools/tests/test_car.gd
## Exits 1 on failure.

const LEVEL := "res://game/debug/car_test/flat_ground.tscn"
const TICKS_PER_SECOND := 60
const FRAME_RATE_CAPS := [0, 30, 144]

var car: VehicleBody3D
var _spawn: Transform3D
var _failures := 0


func _initialize() -> void:
	var level: Node = load(LEVEL).instantiate()
	root.add_child(level)
	await process_frame
	car = level.get_node("car")
	_spawn = car.global_transform

	var runs: Array[Dictionary] = []
	for cap in FRAME_RATE_CAPS:
		Engine.max_fps = cap
		runs.append(await _measure())
	Engine.max_fps = 0

	var r: Dictionary = runs[0]
	print("Measured (no frame cap):")
	for key in r:
		print("  %-34s %7.2f" % [key, r[key]])
	print("")
	_check(r.accelerate_2s_distance_m > 15.0, "accelerating for 2 s drives forward (%.1f m)" % r.accelerate_2s_distance_m)
	_check(r.accelerate_2s_speed_kmh > 50.0, "and reaches a useful speed (%.0f km/h)" % r.accelerate_2s_speed_kmh)
	_check(r.reverse_while_moving_speed_kmh < r.accelerate_2s_speed_kmh * 0.5,
		"reverse while moving forward brakes hard (%.0f → %.0f km/h in 1 s)" % [r.accelerate_2s_speed_kmh, r.reverse_while_moving_speed_kmh])
	_check(r.reverse_from_rest_speed_kmh < -5.0, "reverse from rest drives backwards (%.0f km/h)" % r.reverse_from_rest_speed_kmh)
	_check(r.reverse_from_rest_speed_kmh > -32.0, "but no faster than the reverse top speed (30 km/h)")
	_check(r.accelerate_while_reversing_speed_kmh > r.reverse_from_rest_speed_kmh * 0.5,
		"accelerate while reversing brakes first (%.0f → %.0f km/h)" % [r.reverse_from_rest_speed_kmh, r.accelerate_while_reversing_speed_kmh])
	_check(r.accelerate_10s_speed_kmh < 152.0, "forward speed stops at the top speed (%.0f km/h after 10 s)" % r.accelerate_10s_speed_kmh)
	_check(r.steer_left_degrees > 20.0, "steering left turns left (%.0f°)" % r.steer_left_degrees)
	_check(r.steer_right_degrees < -20.0, "steering right turns right (%.0f°)" % r.steer_right_degrees)
	_check(absf(r.steer_left_degrees + r.steer_right_degrees) < 5.0, "left and right turn equally")
	_check(r.half_throttle_speed_kmh < r.accelerate_2s_speed_kmh * 0.8, "half throttle (analog trigger) is slower than full (%.0f km/h)" % r.half_throttle_speed_kmh)
	_check(r.handbrake_speed_kmh < r.accelerate_2s_speed_kmh, "handbrake slows the car (%.0f km/h)" % r.handbrake_speed_kmh)
	_check(r.not_driving_speed_kmh < 1.0, "with driving toggled off, the throttle does nothing")

	for i in range(1, runs.size()):
		var same := true
		for key in r:
			if absf(runs[i][key] - r[key]) > 0.05:
				same = false
				print("    %s: %.2f with no cap vs %.2f at %d fps" % [key, r[key], runs[i][key], FRAME_RATE_CAPS[i]])
		_check(same, "identical results capped at %d fps" % FRAME_RATE_CAPS[i])

	await _test_camera()

	print("")
	print("ALL TESTS PASSED" if _failures == 0 else "%d TEST(S) FAILED" % _failures)
	level.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _measure() -> Dictionary:
	var r := {}
	await _reset()
	await _hold({"drive_accelerate": 1.0}, 2.0)
	r.accelerate_2s_distance_m = (car.global_position - _spawn.origin).dot(-_spawn.basis.z)
	r.accelerate_2s_speed_kmh = _speed_kmh()
	await _hold({"drive_reverse": 1.0}, 1.0)
	r.reverse_while_moving_speed_kmh = _speed_kmh()

	await _reset()
	await _hold({"drive_reverse": 1.0}, 3.0)
	r.reverse_from_rest_speed_kmh = _speed_kmh()
	await _hold({"drive_accelerate": 1.0}, 1.0)
	r.accelerate_while_reversing_speed_kmh = _speed_kmh()

	for side in ["left", "right"]:
		await _reset()
		await _hold({"drive_accelerate": 1.0}, 1.0)
		await _hold({"drive_accelerate": 0.4, "drive_steer_" + side: 1.0}, 1.0)
		r["steer_%s_degrees" % side] = rad_to_deg(car.global_basis.get_euler().y - _spawn.basis.get_euler().y)

	await _reset()
	await _hold({"drive_accelerate": 1.0}, 10.0)
	r.accelerate_10s_speed_kmh = _speed_kmh()

	await _reset()
	await _hold({"drive_accelerate": 0.5}, 2.0)
	r.half_throttle_speed_kmh = _speed_kmh()

	await _reset()
	await _hold({"drive_accelerate": 1.0}, 2.0)
	await _hold({"drive_handbrake": 1.0}, 1.0)
	r.handbrake_speed_kmh = _speed_kmh()

	await _reset()
	root.get_node("Global").is_driving = false
	await _hold({"drive_accelerate": 1.0}, 1.0)
	r.not_driving_speed_kmh = absf(_speed_kmh())
	root.get_node("Global").is_driving = true
	return r


func _test_camera() -> void:
	print("")
	print("Camera:")
	var camera: CarCamera = car.get_node("FirstPersonCamera")
	_check(camera.current, "the driver's camera is the active camera")
	var changes: Array[StringName] = []
	camera.view_changed.connect(func(v): changes.append(v))

	camera.phone_glance = CarCamera.PhoneGlance.TOGGLE
	await _tap("camera_phone_view")
	_check(camera.is_looking_at_phone(), "toggle mode: pressing the phone button looks at the phone")
	await create_timer(1.5).timeout
	var target := Quaternion.from_euler(CarCamera.VIEWS[CarCamera.PHONE].rotation)
	_check(camera.quaternion.angle_to(target) < 0.05, "the camera glides to the phone view")
	await _tap("camera_phone_view")
	_check(camera.view == CarCamera.ROAD, "pressing again looks back at the road")

	camera.phone_glance = CarCamera.PhoneGlance.HOLD
	Input.action_press("camera_phone_view")
	await _frames(3)
	_check(camera.is_looking_at_phone(), "hold mode: looks at the phone while held")
	Input.action_release("camera_phone_view")
	await _frames(3)
	_check(camera.view == CarCamera.ROAD, "hold mode: releasing looks back at the road")

	await _tap("camera_rear_view")
	_check(camera.view == CarCamera.REAR, "rear view button")
	await _tap("camera_front_view")
	_check(camera.view == CarCamera.ROAD, "front view button returns to the road")
	_check(changes == [CarCamera.PHONE, CarCamera.ROAD, CarCamera.PHONE, CarCamera.ROAD, CarCamera.REAR, CarCamera.ROAD],
		"view_changed fires once per change (got %s)" % [changes])
	camera.phone_glance = CarCamera.PhoneGlance.TOGGLE


## Sends a real press and release, delivered at the start of a frame like
## player input. (Input.action_press from a coroutine can land after _process
## has run, so "just pressed" would be missed.)
func _tap(action: String) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
		await _frames(2)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _reset() -> void:
	car.global_transform = _spawn
	car.linear_velocity = Vector3.ZERO
	car.angular_velocity = Vector3.ZERO
	car.steering = 0.0
	await _ticks(60)
	car.linear_velocity = Vector3.ZERO
	car.angular_velocity = Vector3.ZERO
	await _ticks(10)


func _hold(actions: Dictionary, seconds: float) -> void:
	for action in actions:
		Input.action_press(action, actions[action])
	await _ticks(int(seconds * TICKS_PER_SECOND))
	for action in actions:
		Input.action_release(action)


func _ticks(count: int) -> void:
	for i in count:
		await physics_frame


## Speed along the car's facing direction (negative when reversing).
func _speed_kmh() -> float:
	return car.forward_speed() * 3.6


func _check(condition: bool, label: String) -> void:
	print(("  PASS  " if condition else "  FAIL  ") + label)
	if not condition:
		_failures += 1
