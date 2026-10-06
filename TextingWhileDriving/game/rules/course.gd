class_name Course
extends Node3D
## A drive from the start to the finish line through checkpoints, in order.
##
## Checkpoints are the Area3D children of the `Checkpoints` node, in tree order;
## `Finish` is an Area3D. Only the player's car counts. Crossing the finish before
## every checkpoint does nothing (so a loop can start just past its finish line).
## The timer runs on physics ticks, so it's exact at any frame rate.

## The car passed a checkpoint in the right order. `index` counts from 1.
signal checkpoint_reached(index: int, total: int)
## The car crossed the finish line but still has checkpoints to go.
signal finish_blocked(checkpoints_missed: int)
## The car finished. Level flow (roadmap B4) listens for this.
signal finished(seconds: float)

## Where to find the checkpoints and the finish line, relative to this node.
@export var checkpoints_path := NodePath("Checkpoints")
@export var finish_path := NodePath("Finish")
## Show the timer and checkpoint count in the top-left corner.
@export var show_hud := true

## How many checkpoints have been passed, i.e. the index of the next one to hit.
var next_checkpoint := 0
## Seconds since the level started (stops at the finish).
var elapsed := 0.0
var is_finished := false

var _checkpoints: Array[Area3D] = []
var _hud: Label


func _ready() -> void:
	# Listen to every checkpoint; each one reports its own position in the order.
	for child in get_node(checkpoints_path).get_children():
		if child is Area3D:
			child.body_entered.connect(_on_checkpoint_entered.bind(_checkpoints.size()))
			_checkpoints.append(child)
	get_node(finish_path).body_entered.connect(_on_finish_entered)
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
