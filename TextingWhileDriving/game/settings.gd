extends Node
## Game options that playtesters can switch while playing, saved between sessions
## (in user://settings.cfg). Autoloaded as `Settings`.
##
## While playing: F6 switches the phone glance between toggle and hold,
## F7 moves the phone to the next placement, F8 switches whether the phone only
## takes typing and clicks while the driver looks at it. A short note shows what
## changed.

signal changed(setting: StringName)

const FILE := "user://settings.cfg"

## How the "look at phone" button works (see CarCamera.PhoneGlance).
var phone_glance := 0
## Where the phone sits in the car (a key of PhoneMount.PLACEMENTS).
var phone_placement := &"dash_mount"
## true (the default): the phone takes keys and clicks at all times, like the car
## takes the driving controls; the player chooses where to look (see the
## "Texting and driving" decision in docs/ROADMAP.md).
## false: the phone only takes them while the driver looks at it (a playtest variant).
var phone_type_without_looking := true

var _note: Label
var _note_time_left := 0.0


func _ready() -> void:
	_load()
	_build_note()


## Changes the phone glance mode, saves it, and tells listeners (the car camera).
func set_phone_glance(mode: int) -> void:
	phone_glance = mode
	_save()
	changed.emit(&"phone_glance")


## Changes the phone placement, saves it, and tells listeners (the phone mount).
func set_phone_placement(placement: StringName) -> void:
	phone_placement = placement
	_save()
	changed.emit(&"phone_placement")


## Changes whether the phone takes typing without looking at it, and saves it.
func set_phone_type_without_looking(without_looking: bool) -> void:
	phone_type_without_looking = without_looking
	_save()
	changed.emit(&"phone_type_without_looking")


# F6 / F7 / F8: cycle to the next option and show what it is now.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_cycle_phone_glance"):
		set_phone_glance((phone_glance + 1) % CarCamera.PhoneGlance.size())
		show_note("Phone glance: %s" % CarCamera.PhoneGlance.keys()[phone_glance].to_lower())
	elif event.is_action_pressed("debug_cycle_phone_placement"):
		var names: Array = PhoneMount.PLACEMENTS.keys()
		var next: int = (names.find(phone_placement) + 1) % names.size()
		set_phone_placement(names[next])
		show_note("Phone placement: %s (%d of %d)" % [String(phone_placement).replace("_", " "), next + 1, names.size()])
	elif event.is_action_pressed("debug_toggle_phone_typing_glance"):
		set_phone_type_without_looking(not phone_type_without_looking)
		show_note("Typing: %s" % ("works without looking" if phone_type_without_looking else "only while looking at the phone"))


## Shows a short message at the top of the screen for a couple of seconds.
func show_note(text: String) -> void:
	_note.text = text
	_note.visible = true
	_note_time_left = 2.5


# Hides the note once its time is up.
func _process(delta: float) -> void:
	if _note_time_left > 0.0:
		_note_time_left -= delta
		if _note_time_left <= 0.0:
			_note.visible = false


# Reads saved settings, if any. Unknown or missing values keep their defaults.
func _load() -> void:
	var file := ConfigFile.new()
	if file.load(FILE) != OK:
		return
	phone_glance = file.get_value("phone", "glance", phone_glance)
	var placement := StringName(file.get_value("phone", "placement", phone_placement))
	if PhoneMount.PLACEMENTS.has(placement):
		phone_placement = placement
	phone_type_without_looking = file.get_value("phone", "type_without_looking", phone_type_without_looking)


# Writes the settings to user://settings.cfg (in Godot's per-user data folder).
func _save() -> void:
	var file := ConfigFile.new()
	file.set_value("phone", "glance", phone_glance)
	file.set_value("phone", "placement", String(phone_placement))
	file.set_value("phone", "type_without_looking", phone_type_without_looking)
	file.save(FILE)


# The on-screen note, drawn above everything else (CanvasLayer 10).
func _build_note() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_note = Label.new()
	_note.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_note.position.y = 56
	_note.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_note.add_theme_font_size_override("font_size", 26)
	_note.add_theme_color_override("font_outline_color", Color.BLACK)
	_note.add_theme_constant_override("outline_size", 6)
	_note.visible = false
	layer.add_child(_note)
