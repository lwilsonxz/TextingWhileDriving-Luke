extends SceneTree
## Tests the level flow: title screen → new game → level 1 → results → retry →
## level 2 → fail and retry → results → title, plus saving and continuing.
## Levels are finished by placing the car in each gate, like test_course.gd.
## Uses its own save file, so a player's progress is never touched.
##
##   godot --headless --path TextingWhileDriving --script res://../tools/tests/test_level_flow.gd
## Exits 1 on failure.

const TEMPLATE := "res://game/levels/level_template.tscn"
const COURSE := "res://game/levels/test_course.tscn"
const TITLE := "res://game/ui/title_screen.tscn"
const TEST_SAVE := "user://test_level_flow_save.cfg"

var flow: Node
var story: YarnInMemoryVariableStorage
var _failures := 0


func _initialize() -> void:
	await process_frame
	flow = root.get_node("GameFlow")
	story = root.get_node("PhoneService").storage
	flow.save_path = TEST_SAVE
	DirAccess.remove_absolute(TEST_SAVE)
	var order := LevelOrder.new()
	order.levels = [TEMPLATE, COURSE]
	flow.order = order

	await _test_title_and_new_game()
	await _test_finish_shows_results_and_saves()
	await _test_retry_from_results_restores_the_story()
	await _test_next_level_then_fail_and_retry()
	await _test_last_level_goes_back_to_title()
	await _test_continue()

	DirAccess.remove_absolute(TEST_SAVE)
	print("")
	print("ALL TESTS PASSED" if _failures == 0 else "%d TEST(S) FAILED" % _failures)
	quit(0 if _failures == 0 else 1)


func _test_title_and_new_game() -> void:
	print("== Title screen and New game ==")
	change_scene_to_file(TITLE)
	await _settle()
	_check(current_scene.continue_button.disabled, "Continue is off when there's no saved progress")
	current_scene.new_game_button.pressed.emit()
	await _settle()
	_check(current_scene.scene_file_path == TEMPLATE and flow.level_index == 0, "New game starts the first level")


func _test_finish_shows_results_and_saves() -> void:
	print("== Finishing a level shows the results and saves progress ==")
	story.set_value("$x", 1.0)
	await _finish_level()
	_check(flow.is_showing_results(), "the results screen shows")
	var text: String = flow._results.text()
	_check(text.contains("LEVEL COMPLETE") and text.contains("Traffic violations: 0") and text.contains("Crashes: 0")
		and text.contains("Messages sent: 0"), "with the level's numbers (got %s)" % text.replace("\n", " | "))
	_check(not root.get_node("Global").is_driving, "the car's controls are off")
	var save := ConfigFile.new()
	_check(save.load(TEST_SAVE) == OK and save.get_value("progress", "next_level") == 1
		and save.get_value("story", "variables") == {"$x": 1.0}, "progress is saved: next level 2, and the story so far")
	_check(flow.has_save(), "so there's progress to continue")


func _test_retry_from_results_restores_the_story() -> void:
	print("== Retry from the results screen ==")
	await _tap("level_restart")
	await _settle()
	_check(not flow.is_showing_results() and current_scene.scene_file_path == TEMPLATE, "R plays the level again")
	_check(not story.contains("$x"), "with the story as it was when the level started ($x unset)")
	story.set_value("$x", 1.0)
	await _finish_level()


func _test_next_level_then_fail_and_retry() -> void:
	print("== Next level, then fail it and retry ==")
	await _tap("ui_accept")
	await _settle()
	_check(current_scene.scene_file_path == COURSE and flow.level_index == 1, "Enter goes on to the next level")
	_check(story.get_value("$x") == 1.0, "the story carries over ($x = 1)")
	story.set_value("$x", 5.0)
	var state: LevelState = current_scene.get_node("LevelState")
	state.fail("test")
	await _tap("level_restart")
	await _settle()
	var fresh: LevelState = current_scene.get_node("LevelState")
	_check(fresh != state and not fresh.is_failed, "R restarts the failed level")
	_check(story.get_value("$x") == 1.0, "and undoes the failed attempt's story changes ($x back to 1)")
	_check(root.get_node("Global").is_driving, "with the controls back on")


func _test_last_level_goes_back_to_title() -> void:
	print("== The last level's results go back to the title ==")
	await _finish_level()
	_check(flow._results.text().contains("LEVEL COMPLETE"), "results show")
	_check(flow._results._next_button.text.begins_with("Back to title"), "with 'Back to title' instead of 'Next level'")
	_check(not flow.has_save(), "a finished game leaves nothing to continue")
	await _tap("ui_accept")
	await _settle()
	_check(current_scene.scene_file_path == TITLE, "Enter goes back to the title screen")


func _test_continue() -> void:
	print("== Continue picks up from the save ==")
	var save := ConfigFile.new()
	save.set_value("progress", "next_level", 1)
	save.set_value("story", "variables", {"$x": 7.0})
	save.save(TEST_SAVE)
	story.clear()
	change_scene_to_file(TITLE)
	await _settle()
	_check(not current_scene.continue_button.disabled, "Continue is on when there's saved progress")
	current_scene.continue_button.pressed.emit()
	await _settle()
	_check(current_scene.scene_file_path == COURSE, "it loads the saved next level")
	_check(story.get_value("$x") == 7.0, "with the saved story ($x = 7)")
	flow.go_to_title()
	await _settle()


# --- helpers -------------------------------------------------------------------

# Finishes the current level by putting the car in each checkpoint, in order,
# then the finish line.
func _finish_level() -> void:
	var level := current_scene
	var car: VehicleBody3D = level.get_node("car")
	var gates: Array = level.get_tree().get_nodes_in_group(Checkpoint.GROUP).filter(func(n): return level.is_ancestor_of(n))
	gates.sort_custom(func(a, b): return a.number < b.number)
	gates.append(level.get_tree().get_nodes_in_group(FinishLine.GROUP).filter(func(n): return level.is_ancestor_of(n))[0])
	var away: Vector3 = level.get_node("Spawn").global_position + Vector3(0, 0.5, 0)
	for gate in gates:
		_place(car, gate.global_position + Vector3(0, 0.5, 0))
		await _ticks(5)
		_place(car, away)
		await _ticks(5)
	await _settle()


func _place(car: VehicleBody3D, where: Vector3) -> void:
	car.global_position = where
	car.linear_velocity = Vector3.ZERO
	car.angular_velocity = Vector3.ZERO


func _tap(action: String) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame


# Waits for a scene change and the new level's start-up (LevelState waits a frame).
func _settle() -> void:
	for i in 6:
		await process_frame
	for i in 10:
		await physics_frame


func _ticks(count: int) -> void:
	for i in count:
		await physics_frame


func _check(condition: bool, label: String) -> void:
	print(("  PASS  " if condition else "  FAIL  ") + label)
	if not condition:
		_failures += 1
