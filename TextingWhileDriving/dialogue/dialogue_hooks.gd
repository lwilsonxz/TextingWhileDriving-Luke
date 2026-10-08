class_name DialogueHooks
extends RefCounted
## Everything a conversation can ask the game or tell it to do.
##
## Yarn Spinner auto-registers `static func _yarn_function_<name>` and
## `static func _yarn_command_<name>` as global functions/commands, and the
## dialogue validator reads their signatures from this file. Keep them static,
## typed and documented: the `##` comment shows up in writers' autocomplete.
## When adding one, also add it to the table in docs/WRITING_GUIDE.md §8.
##
## This file must stay in the dialogue/ folder: the Yarn Spinner plugin only
## writes the hooks into Dialogue.ysls.json (writers' VS Code autocomplete)
## for scripts inside the Yarn project's folder.
##
## In the game, functions read the player's car (its driving record) and
## commands go to PhoneService. The playtest scene fakes functions through
## `fakes` and shows commands through `command_listener` instead.
##
## The game is looked up at run time (not by autoload name) because the
## dialogue validator loads this file outside the game.

## Function name (without the prefix) -> value to return instead of asking the game.
static var fakes := {}
## Called as (command_name, args) whenever a command runs. Used by the playtest's log.
static var command_listener := Callable()


## true if the player ran the most recent stop sign.
static func _yarn_function_ran_stop_sign() -> bool:
	if fakes.has("ran_stop_sign"):
		return fakes.ran_stop_sign
	var car := _game_node("player_car")
	return car != null and car.ran_last_stop_sign


## Number of traffic violations so far this level.
static func _yarn_function_violations() -> int:
	if fakes.has("violations"):
		return fakes.violations
	var car := _game_node("player_car")
	return car.violations.size() if car != null else 0


## <<start_thread Thread Node>>: start another conversation, e.g. a second contact texts in.
## It plays after the current conversation ends.
static func _yarn_command_start_thread(thread: String, node: String) -> void:
	if command_listener.is_valid():
		command_listener.call("start_thread", [thread, node])
		return
	var service := _game_node("PhoneService")
	if service == null:
		push_warning("<<start_thread %s %s>>: no PhoneService running" % [thread, node])
		return
	service.start_thread(thread, node)


# Finds a part of the running game: an autoload by name ("PhoneService"), or
# else the first node in that group ("player_car"). null outside the game.
static func _game_node(name: String) -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	var autoload := tree.root.get_node_or_null(name)
	return autoload if autoload != null else tree.get_first_node_in_group(name)


## The game's functions, for tools: [{name, type}] where type is a Variant.Type.
static func list_functions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var script: Script = load("res://dialogue/dialogue_hooks.gd")
	for method in script.get_script_method_list():
		if method.name.begins_with("_yarn_function_"):
			result.append({"name": method.name.trim_prefix("_yarn_function_"), "type": method["return"].type})
	result.sort_custom(func(a, b): return a.name < b.name)
	return result
