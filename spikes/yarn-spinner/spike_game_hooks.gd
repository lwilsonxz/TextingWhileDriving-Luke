class_name SpikeGameHooks
extends Node
## Stand-in for game code that Yarn calls into. Uses the addon's naming
## convention so the commands and functions are auto-registered and written
## to Spike.ysls.json (which the compiler and VS Code use for type checking).

static var stop_sign_was_run := true


## <<typing seconds>>: show the "..." indicator; dialogue waits for it.
static func _yarn_command_typing(seconds: float) -> Signal:
	return (Engine.get_main_loop() as SceneTree).create_timer(seconds).timeout


## ran_stop_sign(): did the player run the last stop sign?
static func _yarn_function_ran_stop_sign() -> bool:
	return stop_sign_was_run
