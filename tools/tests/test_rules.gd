extends SceneTree
## Tests the traffic rules, crashes and failing a level. Each scenario builds a
## small level on the flat test ground (the car, a LevelState and one rule)
## and drives through it with simulated input.
##
##   godot --headless --path TextingWhileDriving --script res://../tools/tests/test_rules.gd
## Exits 1 on failure.

const GROUND := "res://game/debug/car_test/flat_ground.tscn"
const COURSE := "res://game/levels/test_course.tscn"

var level: Node
var car: VehicleBody3D
var state: LevelState
var _start: Vector3
var _failures := 0


func _initialize() -> void:
	await process_frame
	await _test_stop_sign()
	await _test_speed_zone()
	await _test_off_road()
	await _test_crash_fails_the_level()
	await _test_too_many_violations()
	await _test_dialogue_hooks()
	await _test_restart()

	_set_driving(true)
	print("")
	print("ALL TESTS PASSED" if _failures == 0 else "%d TEST(S) FAILED" % _failures)
	await _unload()
	quit(0 if _failures == 0 else 1)


func _test_stop_sign() -> void:
	print("== Stop sign ==")
	# Stop inside the zone, then drive on: obeyed.
	await _build()
	var sign := _add_zone(StopSign.new(), Vector3(0, 0, -40), Vector3(12, 5, 30))
	await _hold("drive_accelerate", 3.0)
	await _until(func(): return sign.car != null, 5.0)
	await _stop_the_car()
	await _hold("drive_accelerate", 6.0)
	_check(sign.car == null and car.global_position.z < _start.z - 55.0, "the car stopped in the zone, then drove out of it")
	_check(state.violations.is_empty() and not state.broke_last(&"stop_sign"),
		"stopping at the sign is obeying it (violations: %s)" % [state.violations])

	# Drive straight through: violation, with a warning on screen.
	await _build()
	_add_zone(StopSign.new(), Vector3(0, 0, -40), Vector3(12, 5, 10))
	await _hold("drive_accelerate", 6.0)
	_check(state.violation_count(&"stop_sign") == 1 and state.broke_last(&"stop_sign"), "driving through is running it")
	_check(state.warning_text() == "TRAFFIC VIOLATION: Ran a stop sign", "a warning shows (\"%s\")" % state.warning_text())

	# Driving through the other way doesn't count.
	await _build()
	_add_zone(StopSign.new(), Vector3(0, 0, -40), Vector3(12, 5, 10), PI)
	await _hold("drive_accelerate", 6.0)
	_check(state.violations.is_empty(), "traffic going the other way is ignored")


func _test_speed_zone() -> void:
	print("== Speed limit ==")
	await _build()
	var fifty: SpeedZone = _add_zone(SpeedZone.new(), Vector3(0, 0, -130), Vector3(12, 5, 60))
	var fast: SpeedZone = _add_zone(SpeedZone.new(), Vector3(0, 0, -130), Vector3(12, 5, 60))
	fast.limit_kmh = 200.0
	var events: Array[String] = []
	fifty.rule_broken.connect(func(d): events.append(d))
	await _hold("drive_accelerate", 9.0)
	_check(state.violation_count(&"speeding") == 1, "flat out through a 50 zone is one speeding violation, not one per tick (got %d)" % state.violation_count(&"speeding"))
	_check(events.size() == 1 and events[0].begins_with("Speeding: ") and events[0].ends_with(" in a 50 zone"),
		"it says how fast (%s)" % [events])


func _test_off_road() -> void:
	print("== Leaving the road ==")
	await _build()
	var roads := GridMap.new()
	roads.cell_size = Vector3(12, 12, 12)
	level.add_child(roads)
	for z in range(-3, 2):  # 5 tiles of road around the start, heading -Z
		roads.set_cell_item(roads.local_to_map(_start + Vector3(0, -12, z * 12)), 0)
	var rule := OffRoadRule.new()
	rule.roads = roads
	level.add_child(rule)
	_check(rule.is_on_road(car.global_position), "the car starts on the road")
	await _hold("drive_accelerate", 4.0)
	_check(not rule.is_on_road(car.global_position), "then drives off the end of it")
	await _ticks(60 * 3)
	_check(state.violation_count(&"off_road") == 1, "leaving the road is one violation (got %d)" % state.violation_count(&"off_road"))


func _test_crash_fails_the_level() -> void:
	print("== Crashing ==")
	await _build()
	state.fail_on_crash = true
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(20, 4, 1)
	wall.add_child(shape)
	level.add_child(wall)
	wall.global_position = _start + Vector3(0, 1, -40)
	var hits: Array[float] = []
	state.crashed.connect(func(kmh): hits.append(kmh))
	await _hold("drive_accelerate", 6.0)
	_check(state.crashes == 1 and hits.size() == 1, "hitting a wall is one crash (got %d)" % state.crashes)
	_check(hits.size() == 1 and hits[0] > 30.0, "at speed (%s km/h)" % [hits])
	_check(state.is_failed and state.fail_reason == "You crashed", "with fail_on_crash, the level fails")
	_check(not root.get_node("Global").is_driving, "the controls stop working")
	_check(_fail_screen_visible(), "the failed screen shows")


func _test_too_many_violations() -> void:
	print("== Too many violations ==")
	await _build()
	state.max_violations = 2
	_add_zone(StopSign.new(), Vector3(0, 0, -40), Vector3(12, 5, 10))
	_add_zone(SpeedZone.new(), Vector3(0, 0, -130), Vector3(12, 5, 60))
	await _hold("drive_accelerate", 9.0)
	_check(state.is_failed and state.fail_reason == "Too many traffic violations (2)",
		"the second violation fails the level (\"%s\")" % state.fail_reason)
	_set_driving(true)


func _test_dialogue_hooks() -> void:
	print("== What conversations can read and do ==")
	await _build()
	state.record_violation(&"stop_sign", "Ran a stop sign")
	state.record_violation(&"speeding", "Speeding")
	state.record_crash(40.0)
	_check(DialogueHooks._yarn_function_violations() == 2, "violations()")
	_check(DialogueHooks._yarn_function_crashes() == 1, "crashes()")
	_check(DialogueHooks._yarn_function_ran_stop_sign(), "ran_stop_sign()")
	state.record_obeyed(&"stop_sign")
	_check(not DialogueHooks._yarn_function_ran_stop_sign(), "ran_stop_sign() is about the last stop sign")
	var events: Array[String] = []
	state.level_event.connect(func(n): events.append(n))
	DialogueHooks._yarn_command_level_event("mom_calls_police")
	_check(events == ["mom_calls_police"], "<<level_event>> reaches the level")
	DialogueHooks._yarn_command_fail_level("Mom stopped talking to you")
	_check(state.is_failed and state.fail_reason == "Mom stopped talking to you", "<<fail_level>> fails the level with its reason")
	_set_driving(true)


func _test_restart() -> void:
	print("== R restarts a failed level ==")
	await _unload()
	var course: Node = load(COURSE).instantiate()
	root.add_child(course)
	current_scene = course
	await _frames(3)
	var old: LevelState = course.get_node("LevelState")
	old.fail("test")
	await _tap("level_restart")
	await _frames(5)
	var fresh := LevelState.find(current_scene)
	_check(fresh != null and fresh != old and not fresh.is_failed, "the level starts again")
	_check(root.get_node("Global").is_driving, "with the controls back on")
	level = current_scene


# --- helpers -------------------------------------------------------------------

# A fresh flat level with the car at rest and a LevelState.
func _build() -> void:
	await _unload()
	level = load(GROUND).instantiate()
	state = LevelState.new()
	level.add_child(state)
	root.add_child(level)
	car = level.get_node("car")
	_start = car.global_position
	await _frames(2)
	await _ticks(30)


func _unload() -> void:
	for input in ["drive_accelerate", "drive_reverse"]:
		Input.action_release(input)
	if level != null and is_instance_valid(level):
		level.queue_free()
		await process_frame
	level = null


# Adds a rule zone `offset` from the car's start, `size` big, turned `turn` radians.
func _add_zone(rule: TrafficRule, offset: Vector3, size: Vector3, turn := 0.0) -> TrafficRule:
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = size
	rule.add_child(shape)
	level.add_child(rule)
	rule.global_position = _start + offset
	rule.rotate_y(turn)
	return rule


# Brakes until the car stands still.
func _stop_the_car() -> void:
	Input.action_press("drive_reverse")
	await _until(func(): return car.linear_velocity.length() < 0.3, 6.0)
	Input.action_release("drive_reverse")
	await _ticks(10)


func _hold(action: String, seconds: float) -> void:
	Input.action_press(action)
	await _ticks(int(seconds * 60))
	Input.action_release(action)


func _until(condition: Callable, seconds: float) -> void:
	var ticks := 0
	while not condition.call() and ticks < seconds * 60:
		await physics_frame
		ticks += 1
	if not condition.call():
		_check(false, "timed out")


func _tap(action: String) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
		await _frames(1)


func _fail_screen_visible() -> bool:
	for node in state.find_children("*", "ColorRect", true, false):
		if node.visible:
			return true
	return false


func _set_driving(on: bool) -> void:
	root.get_node("Global").is_driving = on


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _ticks(count: int) -> void:
	for i in count:
		await physics_frame


func _check(condition: bool, label: String) -> void:
	print(("  PASS  " if condition else "  FAIL  ") + label)
	if not condition:
		_failures += 1
