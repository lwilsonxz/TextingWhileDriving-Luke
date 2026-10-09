extends SceneTree
## Tests the test course: checkpoint order, the finish line, the timer and HUD,
## and the stop sign. Checkpoint rules are tested by placing the car in each
## gate; the stop sign by actually driving through it.
##
##   godot --headless --path TextingWhileDriving --script res://../tools/tests/test_course.gd
## Exits 1 on failure.

const LEVEL := "res://game/levels/test_course.tscn"

var level: Node
var car: VehicleBody3D
var course: Course
var _failures := 0
var _events: Array[String] = []


func _initialize() -> void:
	await _load_level()
	print("== Checkpoints and finish ==")
	_check(course.checkpoint_count() == 3, "the course has 3 checkpoints")
	await _put_car_in("Course/Finish")
	_check(_events == ["blocked 3"], "crossing the finish first doesn't count (got %s)" % [_events])
	await _put_car_in("Course/Checkpoints/Checkpoint2")
	_check(course.next_checkpoint == 0, "checkpoint 2 before checkpoint 1 doesn't count")
	for i in 3:
		await _put_car_in("Course/Checkpoints/Checkpoint%d" % (i + 1))
	_check(course.next_checkpoint == 3, "checkpoints 1, 2, 3 in order count")
	_check(_events.slice(1) == ["checkpoint 1/3", "checkpoint 2/3", "checkpoint 3/3"],
		"checkpoint_reached fires for each (got %s)" % [_events.slice(1)])
	await _put_car_in("Course/Finish")
	_check(course.is_finished and _events.back().begins_with("finished"), "then crossing the finish finishes the course")
	_check(_hud_text().begins_with("Finished in"), "the HUD shows the result (got \"%s\")" % _hud_text())
	var time_at_finish := course.elapsed
	await _ticks(30)
	_check(course.elapsed == time_at_finish, "the timer stops at the finish")

	print("== Stop sign ==")
	level.queue_free()
	await process_frame
	await _load_level()
	var state: LevelState = level.get_node("LevelState")
	_check(state.violations.is_empty() and state.warning_text() == "", "no violation at the start")
	# Full throttle until just past the stop sign (~80 m ahead; about 80 km/h by then). Not much
	# further: without steering the car runs off the end of the straight and crashes.
	var sign_z: float = level.get_node("StopSign").global_position.z
	Input.action_press("drive_accelerate")
	var ticks := 0
	while car.global_position.z > sign_z - 10 and ticks < 60 * 12:
		await physics_frame
		ticks += 1
	Input.action_release("drive_accelerate")
	_check(car.global_position.z < level.get_node("StopSign").global_position.z - 5,
		"the car drove past the stop sign (z %.0f)" % car.global_position.z)
	_check(state.violation_count(&"stop_sign") == 1 and state.warning_text() == "TRAFFIC VIOLATION: Ran a stop sign",
		"running the stop sign at speed is a violation (warning: \"%s\")" % state.warning_text())

	print("")
	print("ALL TESTS PASSED" if _failures == 0 else "%d TEST(S) FAILED" % _failures)
	level.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


# Loads a fresh copy of the course and records the Course's signals in _events.
func _load_level() -> void:
	level = load(LEVEL).instantiate()
	root.add_child(level)
	await process_frame
	car = level.get_node("car")
	course = level.get_node("Course")
	_events.clear()
	course.checkpoint_reached.connect(func(i, total): _events.append("checkpoint %d/%d" % [i, total]))
	course.finish_blocked.connect(func(missed): _events.append("blocked %d" % missed))
	course.finished.connect(func(seconds): _events.append("finished %.1f" % seconds))
	await _ticks(30)


## Moves the car into a gate (and back out to a spot clear of all gates).
func _put_car_in(gate_path: String) -> void:
	var gate: Node3D = level.get_node(gate_path)
	_place_car(gate.global_position + Vector3(0, -2.5, 0))
	await _ticks(5)
	_place_car(Vector3(48, 0.5, -84))  # middle of the loop, away from the road
	await _ticks(5)


func _place_car(where: Vector3) -> void:
	car.global_position = where
	car.linear_velocity = Vector3.ZERO
	car.angular_velocity = Vector3.ZERO


# The text currently shown on the course HUD.
func _hud_text() -> String:
	for child in course.get_children():
		if child is CanvasLayer:
			return (child.get_child(0) as Label).text
	return ""


func _ticks(count: int) -> void:
	for i in count:
		await physics_frame


func _check(condition: bool, label: String) -> void:
	print(("  PASS  " if condition else "  FAIL  ") + label)
	if not condition:
		_failures += 1
