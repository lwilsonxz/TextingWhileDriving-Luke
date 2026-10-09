extends Control
## The first screen: New game, Continue (when there's saved progress), Quit.
##
## ART PLACEHOLDER: the game's name in plain text over a dark background, with
## plain buttons, made in code; see docs/ART_PLACEHOLDERS.md.

var new_game_button: Button
var continue_button: Button


func _ready() -> void:
	_build()
	var flow := get_node_or_null("/root/GameFlow")
	continue_button.disabled = flow == null or not flow.has_save()
	# The mouse may have been hidden or captured by a level; show it here.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	(continue_button if not continue_button.disabled else new_game_button).grab_focus()


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("15151a")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.add_theme_constant_override("separation", 14)
	add_child(column)

	var title := Label.new()
	title.text = "Texting While Driving"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	column.add_child(title)
	column.add_child(Control.new())  # a little space under the title

	continue_button = _button(column, "Continue", func(): get_node("/root/GameFlow").continue_game())
	new_game_button = _button(column, "New game", func(): get_node("/root/GameFlow").new_game())
	_button(column, "Quit", func(): get_tree().quit())


func _button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(280, 0)
	button.add_theme_font_size_override("font_size", 26)
	button.pressed.connect(action)
	parent.add_child(button)
	return button
