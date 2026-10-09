extends SceneTree
## Tests the level template and the drag-in level pieces: the car starts at
## the Spawn, the Course finds checkpoints by number wherever they are, the
## template is drivable start to finish, and pieces draw nothing in the game.
## (Their editor markers are checked by opening a level in the editor; see
## docs/LEVEL_GUIDE.md.)
##
##   godot --headless --path TextingWhileDriving --script res://../tools/tests/test_level_pieces.gd
## Exits 1 on failure.

const TEMPLATE := "res://game/levels/level_template.tscn"
const CHECKPOINT := "res://game/world/pieces/checkpoint.tscn"

var level: Node
var car: VehicleBody3D
var course: Course
var _failures := 0


func _initialize() -> void:
	await process_frame
	await _test_spawn_places_the_car()
	await _test_checkpoints_sorted_by_number()
	await _test_template_drives_start_to_finish()
	print("")
	print("ALL TESTS PASSED" if _failures == 0 else "%d TEST(S) FAILED" % _failures)
	await _unload()
	quit(0 if _failures == 0 else 1)


func _test_spawn_places_the_car() -> void:
	print("== The car starts at the Spawn piece ==")
	level = load(TEMPLATE).instantiate()
	var spawn: Node3D = level.get_node("Spawn")
	spawn.position = Vector3(6, 0, -30)  # on the template's road
	spawn.rotation.y = PI / 2  # facing -X
	level.get_node("car").position = Vector3(-50, 5, 50)
	await _add_level()
	_check(car.global_position.distance_to(Vector3(6, SpawnPoint.LIFT, -30)) < 0.6,
		"the car is moved to the spawn (at %s)" % car.global_position)
	_check((-car.global_basis.z).dot(Vector3.LEFT) > 0.99, "facing the way the spawn points")
	var markers := level.find_children(PieceMarker.NODE_NAME, "", true, false)
	_check(markers.is_empty(), "pieces draw no editor markers in the game (found %d)" % markers.size())


func _test_checkpoints_sorted_by_number() -> void:
	print("== The Course orders checkpoints by number, wherever they are ==")
	level = load(TEMPLATE).instantiate()
	# The template has Checkpoint1 (number 1) under Course. Add number 3 first,
	# then number 2, outside the Course node.
	for n in [3, 2]:
		var cp: Checkpoint = load(CHECKPOINT).instantiate()
		cp.number = n
		cp.name = "Extra%d" % n
		level.add_child(cp)
	await _add_level()
	var numbers := course._checkpoints.map(func(c): return c.number)
	_check(numbers == [1, 2, 3], "found 3 checkpoints, in order 1, 2, 3 (got %s)" % [numbers])


func _test_template_drives_start_to_finish() -> void:
	print("== The template is drivable from the start to the finish ==")
	level = load(TEMPLATE).instantiate()
	await _add_level()
	var events: Array[String] = []
	course.checkpoint_reached.connect(func(i, total): events.append("checkpoint %d/%d" % [i, total]))
	course.finished.connect(func(seconds): events.append("finished"))
	Input.action_press("drive_accelerate")
	var ticks := 0
	while not course.is_finished and ticks < 60 * 15:
		await physics_frame
		ticks += 1
	Input.action_release("drive_accelerate")
	# Stop before the end of the road.
	Input.action_press("drive_reverse")
	while car.linear_velocity.length() > 1.0 and ticks < 60 * 25:
		await physics_frame
		ticks += 1
	Input.action_release("drive_reverse")
	_check(events == ["checkpoint 1/1", "finished"], "through the checkpoint, then the finish (got %s, car at %s)" % [events, car.global_position])
	var state: LevelState = level.get_node("LevelState")
	_check(state.violations.is_empty() and state.crashes == 0, "without a violation or crash (got %s)" % [state.violations])


# --- helpers -------------------------------------------------------------------

func _add_level() -> void:
	var fresh := level
	level = null
	await _unload_others(fresh)
	level = fresh
	root.add_child(level)
	car = level.get_node("car")
	course = level.get_node("Course")
	await process_frame
	await process_frame
	for i in 20:
		await physics_frame


# Frees every level but `keep` (each test builds its own).
func _unload_others(keep: Node) -> void:
	for child in root.get_children():
		if child != keep and (child.scene_file_path == TEMPLATE):
			child.queue_free()
	await process_frame


func _unload() -> void:
	if level != null and is_instance_valid(level):
		level.queue_free()
		await process_frame
	level = null


func _check(condition: bool, label: String) -> void:
	print(("  PASS  " if condition else "  FAIL  ") + label)
	if not condition:
		_failures += 1
