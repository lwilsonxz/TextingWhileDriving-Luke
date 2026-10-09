class_name LevelState
extends Node
## The driving record for one level: traffic violations, crashes, and whether
## the level has been failed. One per level; traffic rules report to it, the
## dialogue reads it (ran_stop_sign(), violations(), crashes()), and it shows
## the warnings and the "level failed" screen.
##
## Drop one into a level. Rules and the dialogue find it through its group,
## so there's nothing to wire up. A level without one still drives; nothing is
## recorded.
##
## The level fails when:
## - the player breaks `max_violations` rules (if set),
## - the car crashes (if `fail_on_crash`),
## - a conversation says so (<<fail_level "reason">>).
## Press R (or Start) on the failed screen to try again.
##
## ART PLACEHOLDER: the warning text and the "level failed" screen are plain
## labels and a dark overlay made in code; see docs/ART_PLACEHOLDERS.md.

signal violation_recorded(rule: StringName, description: String)
signal crashed(impact_kmh: float)
signal failed(reason: String)
## A conversation ran <<level_event name>>. Levels connect to this to make
## things happen (a road closes, a police car appears...).
signal level_event(name: String)

## Rules and the dialogue find this node through this group.
const GROUP := &"level_state"
## How long a warning stays on screen (seconds).
const WARNING_SECONDS := 2.5

## Fail the level after this many violations. 0 = never.
@export var max_violations := 0
## Fail the level when the car crashes.
@export var fail_on_crash := false

## Every rule broken so far, oldest first: [{rule, description, time}].
var violations: Array[Dictionary] = []
## How many times the car has crashed.
var crashes := 0
var is_failed := false
var fail_reason := ""

# For each rule, whether the car broke it the last time it was checked
# (rule name -> bool). ran_stop_sign() reads this.
var _last_outcome := {}
# Seconds since the level started (counted in physics ticks).
var _time := 0.0
var _warning: Label
var _warning_left := 0.0
var _fail_panel: Control
var _fail_label: Label


## The LevelState of the level `node` is in (null if the level has none).
static func find(node: Node) -> LevelState:
	if node == null or not node.is_inside_tree():
		return null
	return node.get_tree().get_first_node_in_group(GROUP) as LevelState


func _ready() -> void:
	add_to_group(GROUP)
	_set_driving(true)  # a restart after failing turns driving back on
	_build_ui()
	# Listen for the player's car crashing, once the level has finished loading.
	await get_tree().process_frame
	var car := get_tree().get_first_node_in_group(&"player_car")
	if car != null and car.has_signal(&"crashed"):
		car.crashed.connect(record_crash)


func _physics_process(delta: float) -> void:
	_time += delta


func _process(delta: float) -> void:
	if _warning_left > 0.0:
		_warning_left -= delta
		_warning.visible = _warning_left > 0.0


## A traffic rule was broken. `description` is shown to the player
## ("Ran a stop sign").
func record_violation(rule: StringName, description: String) -> void:
	if is_failed:
		return
	violations.append({"rule": rule, "description": description, "time": _time})
	_last_outcome[rule] = true
	show_warning("TRAFFIC VIOLATION: " + description)
	violation_recorded.emit(rule, description)
	if max_violations > 0 and violations.size() >= max_violations:
		fail("Too many traffic violations (%d)" % violations.size())


## A traffic rule was checked and the car obeyed it (e.g. stopped at the sign).
func record_obeyed(rule: StringName) -> void:
	_last_outcome[rule] = false


## true if the car broke `rule` the last time it was checked.
func broke_last(rule: StringName) -> bool:
	return _last_outcome.get(rule, false)


## How many times `rule` has been broken this level (all rules if empty).
func violation_count(rule := &"") -> int:
	if rule == &"":
		return violations.size()
	return violations.filter(func(v): return v.rule == rule).size()


## The car hit something hard. Connected to the car's `crashed` signal.
func record_crash(impact_kmh: float) -> void:
	if is_failed:
		return
	crashes += 1
	show_warning("CRASH! (%d km/h)" % roundi(impact_kmh))
	crashed.emit(impact_kmh)
	if fail_on_crash:
		fail("You crashed")


## Fails the level: stops the car's controls and shows the failed screen.
func fail(reason: String) -> void:
	if is_failed:
		return
	is_failed = true
	fail_reason = reason
	_set_driving(false)
	_fail_label.text = "LEVEL FAILED\n%s\n\nPress R (or Start) to try again" % reason
	_fail_panel.visible = true
	failed.emit(reason)


## Starts the level again from scratch.
func restart() -> void:
	get_tree().reload_current_scene()


## Shows a message at the top of the screen for a couple of seconds.
func show_warning(text: String) -> void:
	_warning.text = text
	_warning.visible = true
	_warning_left = WARNING_SECONDS


## The text of the warning on screen ("" if none). Used by tests.
func warning_text() -> String:
	return _warning.text if _warning.visible else ""


# Turns the car's controls on or off (Global.is_driving). Looked up by path, not
# by the autoload's name, so test scripts can load this class directly.
func _set_driving(on: bool) -> void:
	var global := get_node_or_null("/root/Global")
	if global != null:
		global.is_driving = on


func _unhandled_input(event: InputEvent) -> void:
	if is_failed and event.is_action_pressed("level_restart"):
		restart()


# The warning line (red, top centre) and the failed screen, drawn above the HUD.
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)

	_warning = Label.new()
	_warning.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_warning.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_warning.position.y = 100
	_warning.add_theme_font_size_override("font_size", 40)
	_warning.add_theme_color_override("font_color", Color("ff3b30"))
	_warning.add_theme_color_override("font_outline_color", Color.BLACK)
	_warning.add_theme_constant_override("outline_size", 8)
	_warning.visible = false
	layer.add_child(_warning)

	_fail_panel = ColorRect.new()
	(_fail_panel as ColorRect).color = Color(0, 0, 0, 0.7)
	_fail_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fail_panel.visible = false
	layer.add_child(_fail_panel)
	_fail_label = Label.new()
	_fail_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fail_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_fail_label.add_theme_font_size_override("font_size", 36)
	_fail_panel.add_child(_fail_label)
