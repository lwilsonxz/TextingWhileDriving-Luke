extends Node
## Game-wide state that any script can read. Autoloaded as `Global`.
##
## Keep this small: options that players change belong in Settings, and
## per-level state belongs in the level.

## When false the car ignores the driving controls (engine off, brakes released).
## Toggled with F5 (debug_toggle_driving). It dates from the keyboard-only
## prototype, where you had to stop driving to type.
var is_driving = true


# Escape quits the game (a prototype shortcut until there's a pause menu).
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()
