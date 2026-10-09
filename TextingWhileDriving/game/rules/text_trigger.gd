@tool
class_name TextTrigger
extends Area3D
## Starts a conversation on the phone. Drop one into a level, give it a
## CollisionShape3D, and set `thread` and `node`:
## - with `after_seconds` below 0 (the default), it fires when the player's car
##   drives into its shape;
## - with `after_seconds` 0 or more, it fires that many seconds after the level
##   starts, wherever the car is (the shape isn't needed then).
## Each trigger fires once.
##
## The drag-in piece is game/world/pieces/text_trigger.tscn. It's drawn in the
## editor (PieceMarker) and invisible in the game.

## Fired when the conversation is handed to the phone.
signal triggered(thread: String, node: String)

## The contact the conversation is with (shown at the top of the phone).
@export var thread := "":
	set(value):
		thread = value
		_redraw()
## The Yarn node the conversation starts at.
@export var node := "":
	set(value):
		node = value
		_redraw()
## Which Yarn project the node is in. Empty means the game's dialogue
## (res://dialogue/Dialogue.yarnproject).
@export_file("*.yarnproject") var yarn_project := ""
## Seconds after the level starts to fire, or below 0 to fire when the car drives in.
@export var after_seconds := -1.0

var has_fired := false


func _ready() -> void:
	if Engine.is_editor_hint():
		_redraw()
		return
	body_entered.connect(_on_body_entered)
	var service := get_node_or_null("/root/PhoneService")
	if service != null:
		# Load the conversation now, not mid-drive (see PhoneService.prepare).
		service.prepare(_project())
	if after_seconds >= 0.0:
		await get_tree().create_timer(after_seconds, false, true).timeout
		fire()


## Hands the conversation to the phone (once). Also callable from other scripts.
func fire() -> void:
	if has_fired or not is_inside_tree():
		return
	has_fired = true
	var service := get_node_or_null("/root/PhoneService")
	if service != null:
		service.start_thread(thread, node, _project())
	triggered.emit(thread, node)


func _on_body_entered(body: Node3D) -> void:
	if after_seconds < 0.0 and body.is_in_group(&"player_car"):
		fire()


# The editor marker: who texts, and from which node.
func _redraw() -> void:
	PieceMarker.draw(self, Color.DEEP_SKY_BLUE, "TEXT: %s\n%s" % [thread, node])


func _project() -> String:
	return yarn_project if yarn_project != "" else "res://dialogue/Dialogue.yarnproject"
