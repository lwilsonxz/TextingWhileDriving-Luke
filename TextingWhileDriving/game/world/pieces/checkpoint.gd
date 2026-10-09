@tool
class_name Checkpoint
extends Area3D
## A gate the car must drive through, in order: 1, then 2, then 3... The
## level's Course finds every checkpoint by itself and sorts them by `number`,
## so they can sit anywhere in the scene.
##
## Invisible in the game. ART PLACEHOLDER: there's no checkpoint art yet (an
## arch, flags, cones...); see docs/ART_PLACEHOLDERS.md.

## Checkpoints and the finish line add themselves to these groups.
const GROUP := &"checkpoint"

## The order the car must pass them in, starting from 1.
@export var number := 1:
	set(value):
		number = value
		_redraw()


func _enter_tree() -> void:
	if not Engine.is_editor_hint():
		add_to_group(GROUP)


func _ready() -> void:
	_redraw()


func _redraw() -> void:
	PieceMarker.draw(self, Color.GOLD, "CHECKPOINT %d" % number)
