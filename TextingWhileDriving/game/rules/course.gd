class_name Course
extends Node3D
## A drive from the start to the finish line through checkpoints, in order.
##
## Checkpoints are the Area3D children of the `Checkpoints` node, in tree order;
## `Finish` is an Area3D. Only the player's car counts. Crossing the finish before
## every checkpoint does nothing (so a loop can start just past its finish line).
## The timer runs on physics ticks, so it's exact at any frame rate.

signal checkpoint_reached(index: int, total: int)
signal finish_blocked(checkpoints_missed: int)
signal finished(seconds: float)

@export var checkpoints_path := NodePath("Checkpoints")
@export var finish_path := NodePath("Finish")
@export var show_hud := true

var next_checkpoint := 0
var elapsed := 0.0
var is_finished := false

var _checkpoints: Array[Area3D] = []
var _hud: Label


func _ready() -> void:
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
