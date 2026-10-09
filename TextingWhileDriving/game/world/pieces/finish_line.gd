@tool
class_name FinishLine
extends Area3D
## The finish line. Crossing it after every checkpoint finishes the level's
## Course. One per level.
##
## Invisible in the game. ART PLACEHOLDER: there's no finish line art yet (a
## banner, chequered line...); see docs/ART_PLACEHOLDERS.md.

const GROUP := &"finish_line"


func _enter_tree() -> void:
	if not Engine.is_editor_hint():
		add_to_group(GROUP)


func _ready() -> void:
	PieceMarker.draw(self, Color.WHITE, "FINISH")
