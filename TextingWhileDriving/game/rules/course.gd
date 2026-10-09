class_name Course
extends Node3D
## A drive from the start to the finish line through checkpoints, in order.
##
## It finds the level's Checkpoint pieces (sorted by their `number`) and its
## FinishLine by itself, wherever they are in the level, so there's nothing to
## wire up. Only the player's car counts. Crossing the finish before every
## checkpoint does nothing (so a loop can start just past its finish line).
## The timer runs on physics ticks, so it's exact at any frame rate.
##
## ART PLACEHOLDER: the timer/checkpoint HUD is a plain label made in code; see
## docs/ART_PLACEHOLDERS.md.

## The car passed a checkpoint in the right order. `index` counts from 1.
signal checkpoint_reached(index: int, total: int)
## The car crossed the finish line but still has checkpoints to go.
signal finish_blocked(checkpoints_missed: int)
## The car finished. Level flow (roadmap B4) listens for this.
signal finished(seconds: float)

## Show the timer and checkpoint count in the top-left corner.
@export var show_hud := true

## How many checkpoints have been passed, i.e. the index of the next one to hit.
var next_checkpoint := 0
## Seconds since the level started (stops at the finish).
var elapsed := 0.0
var is_finished := false

var _checkpoints: Array[Checkpoint] = []
var _hud: Label


## LevelState finds the level's Course through this group.
const GROUP := &"course"


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	# Pieces join their groups as they enter the tree, before any _ready runs.
	# Only take the ones in this level (another level could be loaded too).
	var level := owner if owner != null else get_parent()
	for node in get_tree().get_nodes_in_group(Checkpoint.GROUP):
		if level.is_ancestor_of(node):
			_checkpoints.append(node)
	_checkpoints.sort_custom(func(a, b): return a.number < b.number)
	for i in _checkpoints.size():
		if i > 0 and _checkpoints[i].number == _checkpoints[i - 1].number:
			push_warning("Course: two checkpoints are number %d" % _checkpoints[i].number)
		_checkpoints[i].body_entered.connect(_on_checkpoint_entered.bind(i))
	var finishes := get_tree().get_nodes_in_group(FinishLine.GROUP).filter(func(n): return level.is_ancestor_of(n))
	if finishes.size() != 1:
		push_warning("Course: the level needs exactly one FinishLine (found %d)" % finishes.size())
	for finish in finishes:
		finish.body_entered.connect(_on_finish_entered)
	if show_hud:
		_build_hud()
	_update_hud()


func checkpoint_count() -> int:
	return _checkpoints.size()


func _physics_process(delta: float) -> void:
	if not is_finished:
		elapsed += delta
		_update_hud()


## Only the next checkpoint in order counts; skipping ahead or going back does nothing.
func _on_checkpoint_entered(body: Node3D, index: int) -> void:
	if is_finished or not body.is_in_group(&"player_car") or index != next_checkpoint:
		return
	next_checkpoint += 1
	checkpoint_reached.emit(next_checkpoint, _checkpoints.size())
	_update_hud()


func _on_finish_entered(body: Node3D) -> void:
	if is_finished or not body.is_in_group(&"player_car"):
		return
	if next_checkpoint < _checkpoints.size():
		finish_blocked.emit(_checkpoints.size() - next_checkpoint)
		return
	is_finished = true
	finished.emit(elapsed)
	_update_hud()


func _update_hud() -> void:
	if _hud == null:
		return
	# Minutes:seconds with one decimal, e.g. 1:07.3
	var time := "%d:%04.1f" % [int(elapsed) / 60, fmod(elapsed, 60.0)]
	if is_finished:
		_hud.text = "Finished in %s" % time
	else:
		_hud.text = "%s    Checkpoints %d/%d" % [time, next_checkpoint, _checkpoints.size()]


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = Label.new()
	_hud.position = Vector2(16, 12)
	_hud.add_theme_font_size_override("font_size", 28)
	_hud.add_theme_color_override("font_outline_color", Color.BLACK)
	_hud.add_theme_constant_override("outline_size", 6)
	layer.add_child(_hud)
