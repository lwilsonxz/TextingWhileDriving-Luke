class_name ResultsScreen
extends CanvasLayer
## The screen shown when the player finishes a level: time, traffic violations,
## crashes, and how the texting went. Next level (Enter / A) or retry
## (R / Start). GameFlow owns it and fills it in.
##
## ART PLACEHOLDER: a dark overlay with plain text and buttons, made in code;
## see docs/ART_PLACEHOLDERS.md.

signal next_pressed
signal retry_pressed

var _title: Label
var _body: Label
var _next_button: Button
var _retry_button: Button


func _ready() -> void:
	layer = 20  # above the HUD and the "level failed" screen
	_build()
	hide_results()


## Fills in and shows the screen. `summary` keys: seconds, violations (an
## array of {rule, description}), crashes, messages_sent, replies_missed,
## is_last_level.
func show_results(summary: Dictionary) -> void:
	_title.text = "LEVEL COMPLETE"
	var lines: Array[String] = []
	lines.append("Time: %s" % format_time(summary.get("seconds", 0.0)))
	var violations: Array = summary.get("violations", [])
	lines.append("Traffic violations: %d" % violations.size())
	for v in violations:
		lines.append("    %s" % v.description)
	lines.append("Crashes: %d" % summary.get("crashes", 0))
	lines.append("Messages sent: %d" % summary.get("messages_sent", 0))
	lines.append("Replies missed: %d" % summary.get("replies_missed", 0))
	_body.text = "\n".join(lines)
	_next_button.text = "Back to title (Enter)" if summary.get("is_last_level", false) else "Next level (Enter)"
	visible = true
	_next_button.grab_focus()


func hide_results() -> void:
	visible = false


## The text on screen, for tests.
func text() -> String:
	return _title.text + "\n" + _body.text


## Minutes:seconds with one decimal, e.g. 1:07.3
static func format_time(seconds: float) -> String:
	return "%d:%04.1f" % [int(seconds) / 60, fmod(seconds, 60.0)]


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		next_pressed.emit()
	elif event.is_action_pressed("level_restart"):
		get_viewport().set_input_as_handled()
		retry_pressed.emit()


func _build() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.75)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 16)
	shade.add_child(column)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 44)
	column.add_child(_title)
	_body = Label.new()
	_body.add_theme_font_size_override("font_size", 26)
	column.add_child(_body)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 24)
	column.add_child(buttons)
	_retry_button = Button.new()
	_retry_button.text = "Retry (R)"
	_retry_button.pressed.connect(func(): retry_pressed.emit())
	buttons.add_child(_retry_button)
	_next_button = Button.new()
	_next_button.pressed.connect(func(): next_pressed.emit())
	buttons.add_child(_next_button)
