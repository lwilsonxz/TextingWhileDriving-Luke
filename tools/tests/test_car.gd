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

	var samples: Array[Dictionary] = []
	for cap in FRAME_RATE_CAPS:
		Engine.max_fps = cap
		samples.append(await _measure_sample())
	Engine.max_fps = 0
	var r := await _measure()

	print("Measured (no frame cap):")
	for key in r:
		print("  %-34s %7.2f" % [key, r[key]])
	print("")
	# Targets: roughly an ordinary road car (see BaseCar.gd).
	_check(r.zero_to_100_seconds > 7.0 and r.zero_to_100_seconds < 12.0, "0–100 km/h takes 7–12 s (%.1f s)" % r.zero_to_100_seconds)
	_check(r.speed_after_20s_kmh > 120.0 and r.speed_after_20s_kmh <= 162.0, "after 20 s: 120–160 km/h (%.0f km/h)" % r.speed_after_20s_kmh)
	_check(r.brake_100_to_0_seconds > 2.5 and r.brake_100_to_0_seconds < 5.0, "braking from 100 km/h stops in 2.5–5 s (%.1f s, %.0f m)" % [r.brake_100_to_0_seconds, r.brake_100_to_0_meters])
	_check(r.reverse_10s_kmh < -15.0 and r.reverse_10s_kmh > -27.0, "reverse tops out around 25 km/h (%.0f km/h)" % r.reverse_10s_kmh)
	_check(r.accelerate_while_reversing_kmh > r.reverse_10s_kmh * 0.5,
		"accelerate while reversing brakes first (%.0f → %.0f km/h)" % [r.reverse_10s_kmh, r.accelerate_while_reversing_kmh])
	_check(r.steer_left_degrees > 20.0, "steering left turns left (%.0f°)" % r.steer_left_degrees)
	_check(r.steer_right_degrees < -20.0, "steering right turns right (%.0f°)" % r.steer_right_degrees)
	_check(absf(r.steer_left_degrees + r.steer_right_degrees) < 5.0, "left and right turn equally")
	_check(r.half_throttle_5s_kmh < r.full_throttle_5s_kmh * 0.8,
		"half throttle (analog trigger) is slower than full (%.0f vs %.0f km/h)" % [r.half_throttle_5s_kmh, r.full_throttle_5s_kmh])
	_check(r.handbrake_kmh < r.full_throttle_5s_kmh * 0.8, "handbrake slows the car (%.0f km/h)" % r.handbrake_kmh)
	_check(r.not_driving_kmh < 1.0, "with driving toggled off, the throttle does nothing")

	print("")
	print("Frame-rate independence (a short drive at each frame-rate cap):")
	print("  %s" % [samples[0]])
	for i in range(1, samples.size()):
		var same := true
		for key in samples[0]:
			if absf(samples[i][key] - samples[0][key]) > 0.05:
				same = false
				print("    %s: %.2f with no cap vs %.2f at %d fps" % [key, samples[0][key], samples[i][key], FRAME_RATE_CAPS[i]])
		_check(same, "identical results capped at %d fps" % FRAME_RATE_CAPS[i])

	await _test_camera()

	print("")
	print("ALL TESTS PASSED" if _failures == 0 else "%d TEST(S) FAILED" % _failures)
	level.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


## A short drive using every control, repeated at each frame-rate cap.
func _measure_sample() -> Dictionary:
	var r := {}
	await _reset()
	await _hold({"drive_accelerate": 1.0}, 4.0)
	r.speed_kmh = _speed_kmh()
	await _hold({"drive_accelerate": 0.5, "drive_steer_left": 1.0}, 1.0)
	r.heading_degrees = rad_to_deg(car.global_basis.get_euler().y)
	await _hold({"drive_reverse": 1.0}, 1.0)
	r.after_braking_kmh = _speed_kmh()
	await _hold({"drive_handbrake": 1.0}, 1.0)
	r.x = car.global_position.x
	r.z = car.global_position.z
	return r


## Realistic-driving measurements (run once; they take about a minute of game time).
func _measure() -> Dictionary:
	var r := {}

	await _reset()
	r.zero_to_100_seconds = 99.0
	Input.action_press("drive_accelerate")
	for tick in 20 * TICKS_PER_SECOND:
		await physics_frame
		if r.zero_to_100_seconds == 99.0 and _speed_kmh() >= 100.0:
			r.zero_to_100_seconds = (tick + 1) / float(TICKS_PER_SECOND)
	Input.action_release("drive_accelerate")
	r.speed_after_20s_kmh = _speed_kmh()

	await _reset()
	Input.action_press("drive_accelerate")
	while _speed_kmh() < 100.0:
		await physics_frame
	Input.action_release("drive_accelerate")
	var braking_from := car.global_position
	var ticks := 0
	Input.action_press("drive_reverse")
	while car.forward_speed() > 0.3 and ticks < 10 * TICKS_PER_SECOND:
		await physics_frame
		ticks += 1
	Input.action_release("drive_reverse")
	r.brake_100_to_0_seconds = ticks / float(TICKS_PER_SECOND)
	r.brake_100_to_0_meters = (car.global_position - braking_from).length()

	await _reset()
	await _hold({"drive_reverse": 1.0}, 10.0)
	r.reverse_10s_kmh = _speed_kmh()
	await _hold({"drive_accelerate": 1.0}, 1.0)
	r.accelerate_while_reversing_kmh = _speed_kmh()

	for side in ["left", "right"]:
		await _reset()
		await _hold({"drive_accelerate": 1.0}, 4.0)
		await _hold({"drive_accelerate": 0.4, "drive_steer_" + side: 1.0}, 1.0)
		r["steer_%s_degrees" % side] = rad_to_deg(car.global_basis.get_euler().y - _spawn.basis.get_euler().y)

	await _reset()
	await _hold({"drive_accelerate": 1.0}, 5.0)
	r.full_throttle_5s_kmh = _speed_kmh()
	await _hold({"drive_handbrake": 1.0}, 1.0)
	r.handbrake_kmh = _speed_kmh()

	await _reset()
	await _hold({"drive_accelerate": 0.5}, 5.0)
	r.half_throttle_5s_kmh = _speed_kmh()

	await _reset()
	root.get_node("Global").is_driving = false
	await _hold({"drive_accelerate": 1.0}, 1.0)
	r.not_driving_kmh = absf(_speed_kmh())
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
	var target := Quaternion.from_euler(camera.views[CarCamera.PHONE].rotation)
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

	print("")
	print("Phone placements and playtest settings:")
	var settings := root.get_node("Settings")
	var saved_glance: int = settings.phone_glance
	var saved_placement: StringName = settings.phone_placement
	var mount: PhoneMount = car.get_node("PhoneMount")
	var center := Vector2(root.size) / 2.0
	for placement in PhoneMount.PLACEMENTS:
		mount.apply(placement)
		camera.snap_to(CarCamera.PHONE)
		await _frames(2)
		var screen := mount.screen_center()
		var on_screen := camera.unproject_position(screen)
		var off_center := (on_screen - center).length() / center.y
		_check(not camera.is_position_behind(screen) and off_center < 0.15,
			"%s: the phone glance centres the phone (%.0f%% off centre)" % [placement, off_center * 100])
		camera.snap_to(CarCamera.ROAD)

	settings.set_phone_glance(CarCamera.PhoneGlance.TOGGLE)
	await _tap("debug_cycle_phone_glance")
	_check(camera.phone_glance == CarCamera.PhoneGlance.HOLD, "F6 switches the phone glance to hold")
	await _tap("debug_cycle_phone_glance")
	_check(camera.phone_glance == CarCamera.PhoneGlance.TOGGLE, "and back to toggle")
	settings.set_phone_placement(&"dash_mount")
	await _frames(1)
	var before := mount.position
	await _tap("debug_cycle_phone_placement")
	_check(settings.phone_placement == &"vent_mount" and mount.placement == &"vent_mount" and mount.position != before,
		"F7 moves the phone to the next placement (now %s)" % settings.phone_placement)
	var saved := ConfigFile.new()
	saved.load(settings.FILE)
	_check(saved.get_value("phone", "placement", "") == "vent_mount", "settings are saved for next time")
	settings.set_phone_glance(saved_glance)
	settings.set_phone_placement(saved_placement)


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
