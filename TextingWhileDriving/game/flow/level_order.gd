class_name LevelOrder
extends Resource
## The game's levels, in the order they're played. The list lives in
## game/levels/level_order.tres: open it and edit the list in the Inspector
## to add, remove or reorder levels.

## Level scenes, first to last.
@export_file("*.tscn") var levels: Array[String] = []
