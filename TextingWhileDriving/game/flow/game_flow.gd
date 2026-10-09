extends Node
## Strings the levels together into a game. Autoloaded as `GameFlow`.
##
##   title screen → New game → level 1 → finish → results → level 2 → ... → title
##
## - The level order is game/levels/level_order.tres (designers edit it).
## - Finishing a level shows the results screen (time, violations, crashes,
##   messages) and saves progress: which level is next, and every story
##   variable. "Continue" on the title screen picks up from there.
## - Retrying a level (from the results or the "level failed" screen) puts the
##   story variables back to what they were when the level started, so a
##   failed attempt's choices don't stick.
##
## A level played on its own (F6 in the editor, or a test) works too and shows
## its results, but doesn't save: only a run started from the title screen
## (New game / Continue) saves progress. If the level is in the level order,
## "Next level" still goes on from it.

## The player finished a level. `summary` is what the results screen shows.
signal level_finished(summary: Dictionary)

const TITLE_SCREEN := "res://game/ui/title_screen.tscn"
const SAVE_FILE := "user://save.cfg"

## The levels, in order.
var order: LevelOrder = preload("res://game/levels/level_order.tres")
## Where progress is saved. Tests point this somewhere else.
var save_path := SAVE_FILE
## Where the current level is in the order (-1 when it isn't in the order).
var level_index := -1
## true during a run started with New game or Continue (only runs save progress).
var in_run := false

# The story variables as they were when the current level started (for retries).
var _snapshot := {}
var _results: ResultsScreen


func _ready() -> void:
	_results = ResultsScreen.new()
	_results.next_pressed.connect(next_level)
	_results.retry_pressed.connect(restart_level)
	add_child(_results)


## Starts from the first level with fresh story variables.
func new_game() -> void:
	_story().clear()
	in_run = true
	_go_to(0)


## true if there's saved progress to continue from.
func has_save() -> bool:
	var file := ConfigFile.new()
	if file.load(save_path) != OK:
		return false
	var next: int = file.get_value("progress", "next_level", -1)
	return next >= 0 and next < order.levels.size()


## Picks up from the saved progress: the next level, with the story so far.
func continue_game() -> void:
	var file := ConfigFile.new()
	if file.load(save_path) != OK:
		new_game()
		return
	_story().from_save_data(file.get_value("story", "variables", {}))
	in_run = true
	_go_to(file.get_value("progress", "next_level", 0))


## Called by the level's LevelState when the level starts. Remembers where we
## are in the order and the story so far (for retries).
func level_started(level: Node) -> void:
	_results.hide_results()
	level_index = order.levels.find(level.scene_file_path)
	_snapshot = _story().to_save_data().duplicate(true)


## Called by the level's LevelState when the car crosses the finish line.
## Shows the results and saves progress.
func level_completed(summary: Dictionary) -> void:
	var is_last := level_index < 0 or level_index >= order.levels.size() - 1
	summary.is_last_level = is_last
	if in_run and level_index >= 0:
		_save(level_index + 1)
	_results.show_results(summary)
	level_finished.emit(summary)


## Goes on to the next level, or back to the title screen after the last one.
func next_level() -> void:
	_results.hide_results()
	if level_index >= 0 and level_index + 1 < order.levels.size():
		_go_to(level_index + 1)
	else:
		go_to_title()


## Plays the current level again, with the story as it was when it started.
func restart_level() -> void:
	_results.hide_results()
	_story().from_save_data(_snapshot.duplicate(true))
	get_tree().reload_current_scene()


func go_to_title() -> void:
	_results.hide_results()
	level_index = -1
	in_run = false
	get_tree().change_scene_to_file(TITLE_SCREEN)


## true while the results screen is up.
func is_showing_results() -> bool:
	return _results.visible


# --- inside -------------------------------------------------------------------

func _go_to(index: int) -> void:
	level_index = index
	get_tree().change_scene_to_file(order.levels[index])


# Writes which level is next and every story variable to the save file.
func _save(next_level_index: int) -> void:
	var file := ConfigFile.new()
	file.set_value("progress", "next_level", next_level_index)
	file.set_value("story", "variables", _story().to_save_data())
	file.save(save_path)


# The story variables live in PhoneService (they're the dialogue's variables).
func _story() -> YarnInMemoryVariableStorage:
	return get_node("/root/PhoneService").storage
