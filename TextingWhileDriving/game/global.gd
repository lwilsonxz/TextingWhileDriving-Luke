extends Node
## Game-wide state that any script can read. Autoloaded as `Global`.
##
## Keep this small: options that players change belong in Settings, and
## per-level state belongs in the level.

## When false the car ignores the driving controls (engine off, brakes released).
## Toggled with F5 (debug_toggle_driving). It dates from the keyboard-only
## prototype, where you had to stop driving to type.
var is_driving = true
