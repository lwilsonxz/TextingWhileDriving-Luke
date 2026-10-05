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
## and traffic rules (B3) exist.


## true if the player ran the most recent stop sign.
static func _yarn_function_ran_stop_sign() -> bool:
	push_warning("DialogueHooks.ran_stop_sign() is not implemented yet")
	return false


## Number of traffic violations so far this level.
static func _yarn_function_violations() -> int:
	push_warning("DialogueHooks.violations() is not implemented yet")
	return 0


## <<start_thread Thread Node>>: start another conversation, e.g. a second contact texts in.
static func _yarn_command_start_thread(thread: String, node: String) -> void:
	push_warning("DialogueHooks <<start_thread %s %s>> is not implemented yet" % [thread, node])
