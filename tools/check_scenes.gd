extends SceneTree
## Smoke test: loads every scene in the game, runs it for a few frames, and
## fails if any engine or script error is logged. Catches broken paths after
## moving files, missing resources, and errors in _ready().
##
## From the repo root (import the project once first so resources exist):
##   godot --headless --path TextingWhileDriving --import
##   godot --headless --path TextingWhileDriving --script res://../tools/check_scenes.gd
## Exits 1 if any scene fails.

const FRAMES_PER_SCENE := 10

## Scenes that are parts of other scenes and can't run on their own. They are
## still loaded and instantiated, just not added to the tree.
const NOT_STANDALONE := [
	"res://game/car/follow_camera/camera_3d.tscn",  # follows its parent node
]

## Errors from the headless dummy renderer are artifacts of running without a GPU.
const IGNORED_ERROR_SOURCES := ["servers/rendering/dummy/"]


class ErrorCounter extends Logger:
	var errors: Array[String] = []
	var _mutex := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		for source in IGNORED_ERROR_SOURCES:
			if file.contains(source):
				return
		if error_type == ERROR_TYPE_WARNING:
			return
		_mutex.lock()
		errors.append("%s (%s:%d in %s)" % [rationale if rationale != "" else code, file, line, function])
		_mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass

	func take() -> Array[String]:
		_mutex.lock()
		var result := errors.duplicate()
		errors.clear()
		_mutex.unlock()
		return result


func _initialize() -> void:
	var counter := ErrorCounter.new()
	OS.add_logger(counter)
	await process_frame

	var scenes: Array[String] = []
	_find_scenes("res://", scenes)
	var failed := 0
	for path in scenes:
		counter.take()
		var packed: PackedScene = load(path)
		var errors: Array[String] = []
		if packed == null:
			errors.append("couldn't load")
		else:
			var node := packed.instantiate()
			if node == null:
				errors.append("couldn't instantiate")
			elif path in NOT_STANDALONE:
				node.free()
			else:
				root.add_child(node)
				for i in FRAMES_PER_SCENE:
					await process_frame
				node.queue_free()
				await process_frame
		errors.append_array(counter.take())
		if errors.is_empty():
			print("  OK    " + path)
		else:
			failed += 1
			print("  FAIL  " + path)
			for error in errors:
				print("          " + error)

	print("")
	print("%d of %d scenes OK." % [scenes.size() - failed, scenes.size()])
	OS.remove_logger(counter)
	quit(1 if failed > 0 else 0)


func _find_scenes(dir_path: String, into: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		if not sub.begins_with(".") and sub != "addons":
			_find_scenes(dir_path.path_join(sub), into)
	for file in dir.get_files():
		if file.get_extension() == "tscn":
			into.append(dir_path.path_join(file))
	into.sort()
