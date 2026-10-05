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
## The bodies are placeholders until the prototype's PhoneService (roadmap A5)
## and traffic rules (B3) exist. The playtest scene fakes functions through
## `fakes` and shows commands through `command_listener`.

## Function name (without the prefix) -> value to return instead of asking the game.
static var fakes := {}
## Called as (command_name, args) whenever a command runs. Used by the playtest's log.
static var command_listener := Callable()


## true if the player ran the most recent stop sign.
static func _yarn_function_ran_stop_sign() -> bool:
	if fakes.has("ran_stop_sign"):
		return fakes.ran_stop_sign
	push_warning("DialogueHooks.ran_stop_sign() is not implemented yet")
	return false


## Number of traffic violations so far this level.
static func _yarn_function_violations() -> int:
	if fakes.has("violations"):
		return fakes.violations
	push_warning("DialogueHooks.violations() is not implemented yet")
	return 0


## <<start_thread Thread Node>>: start another conversation, e.g. a second contact texts in.
static func _yarn_command_start_thread(thread: String, node: String) -> void:
	if command_listener.is_valid():
		command_listener.call("start_thread", [thread, node])
		return
	push_warning("DialogueHooks <<start_thread %s %s>> is not implemented yet" % [thread, node])


## The game's functions, for tools: [{name, type}] where type is a Variant.Type.
static func list_functions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var script: Script = load("res://game/phone/dialogue_hooks.gd")
	for method in script.get_script_method_list():
		if method.name.begins_with("_yarn_function_"):
			result.append({"name": method.name.trim_prefix("_yarn_function_"), "type": method["return"].type})
	result.sort_custom(func(a, b): return a.name < b.name)
	return result
