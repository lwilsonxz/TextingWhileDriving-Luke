class_name DialoguePlaytest
extends Control
## Writers' tool: play any conversation on the phone without driving.
## Open game/debug/dialogue_playtest/dialogue_playtest.tscn and press F6.
##
## - Pick a Yarn project and a node, press Play.
## - "Skip typing" sends Me: lines automatically; "Skip delays" makes messages arrive instantly.
## - Story variables can be edited at any time, and game functions (ran_stop_sign(), ...) faked.
## - Back returns to the start of the previous node with its variables; Restart replays from the start.
## - Hidden #timeout choices and choices whose condition is false are shown greyed out, so they can be tested.
##
## ART PLACEHOLDER (writers' tool, not in the game): the panels are plain Godot
## controls laid out in code. Low priority; see docs/ART_PLACEHOLDERS.md.

## Where to look for Yarn projects, and which one to open first.
const DIALOGUE_ROOT := "res://"
const DEFAULT_PROJECT := "res://dialogue/Dialogue.yarnproject"

# The pieces that play a conversation: the phone screen (view), the bridge from
# Yarn to the screen (presenter), Yarn's dialogue runner, and where it keeps the
# story variables (storage). The runner and storage are replaced per project.
var view: ChatView
var presenter: ChatPresenter
var runner: YarnDialogueRunner
var storage: YarnInMemoryVariableStorage

var _project_path := ""
var _nodes: Array[Dictionary] = []      # {title, file, entry}
var _declared := {}                     # "$name" -> default value
var _history: Array[Dictionary] = []    # {node, variables} at each node start
var _log_lines: Array[String] = []
var _restoring := false                 # true while Back/Restart replays a node

# The controls in the left-hand panel, created in _build().
var _project_picker: OptionButton
var _filter: LineEdit
var _node_list: ItemList
var _skip_typing: CheckBox
var _skip_delays: CheckBox
var _variables_box: GridContainer
var _hooks_box: GridContainer
var _log: RichTextLabel
var _variable_editors := {}             # "$name" -> Control
var _hook_editors := {}                 # function name -> Control


func _ready() -> void:
	_build()
	# Show game commands (like <<start_thread>>) in our log instead of running them.
	DialogueHooks.command_listener = _on_command
	_rebuild_hook_editors()
	# Fill the project picker and open the real game's dialogue by default.
	var projects := _find_projects(DIALOGUE_ROOT)
	for path in projects:
		_project_picker.add_item(path.trim_prefix("res://"))
	var start := projects.find(DEFAULT_PROJECT)
	if not projects.is_empty():
		_project_picker.select(maxi(start, 0))
		select_project(projects[maxi(start, 0)])


# Put DialogueHooks back to normal so the fakes don't leak into the real game.
func _exit_tree() -> void:
	if DialogueHooks.command_listener == Callable(self, "_on_command"):
		DialogueHooks.command_listener = Callable()
	DialogueHooks.fakes.clear()


# --- public API (buttons call these; so do the tests) ---------------------------

## Loads a Yarn project: reads its nodes and variables, and makes a fresh
## dialogue runner for it (Yarn ties a runner to one project).
func select_project(path: String) -> void:
	await stop()
	_project_path = path
	for i in _project_picker.item_count:
		if "res://" + _project_picker.get_item_text(i) == path:
			_project_picker.select(i)
	_nodes = _read_nodes(path.get_base_dir())
	_declared = _read_declarations(path.get_base_dir())
	_history.clear()
	view.clear()
	# Build the new runner before freeing the old one, so the presenter always
	# has somewhere to live (it moves from the old runner to the new one).
	var old_runner := runner
	var old_storage := storage
	storage = YarnInMemoryVariableStorage.new()
	add_child(storage)
	runner = YarnDialogueRunner.new()
	runner.yarn_project = load(path)
	runner.auto_start = false
	runner.show_selected_option_as_line = false
	runner.variable_storage = storage
	add_child(runner)
	if presenter.get_parent() == null:
		runner.add_child(presenter)
	else:
		presenter.reparent(runner)
	runner.add_presenter(presenter)
	runner.node_started.connect(_on_node_started)
	runner.dialogue_completed.connect(_on_dialogue_completed)
	if old_runner != null:
		old_runner.queue_free()
		old_storage.queue_free()
	_rebuild_variable_editors()
	reset_variables()
	_refresh_node_list()
	_log_line("Loaded %s: %d nodes, %d variables" % [path.trim_prefix("res://"), _nodes.size(), _declared.size()])


## Starts a conversation from `node`, keeping the current variable values.
func play(node: String) -> void:
	await stop()
	view.clear()
	_history.clear()
	runner.start_dialogue(node)


## Stops the conversation that's playing, if any.
func stop() -> void:
	if runner != null and runner.is_running():
		await runner.stop_dialogue()


## Back to the start of the previous node, with the variables it started with.
func back() -> void:
	if _history.size() < 2:
		await restart()
		return
	_history.pop_back()
	var target: Dictionary = _history.pop_back()
	await _jump_to(target)


## Replays from the first node of this run, with the variables it started with.
func restart() -> void:
	if _history.is_empty():
		return
	var first: Dictionary = _history[0]
	_history.clear()
	await _jump_to(first)


## Puts every story variable back to its starting value from Variables.yarn.
func reset_variables() -> void:
	storage.clear()
	for variable in _declared:
		storage.set_value(variable, _declared[variable])
	_refresh_variables()


## Changes a story variable (what the editors in the "Story variables" panel do).
func set_variable(variable: String, value: Variant) -> void:
	storage.set_value(variable, value)
	_refresh_variables()


func get_variable(variable: String) -> Variant:
	return storage.get_value(variable)


## Makes a game function (e.g. ran_stop_sign()) return `value` in conversations,
## and updates its control in the "Fake game state" panel to match.
func set_fake(function: String, value: Variant) -> void:
	DialogueHooks.fakes[function] = value
	var editor: Control = _hook_editors.get(function)
	if editor is CheckBox:
		editor.set_pressed_no_signal(bool(value))
	elif editor is SpinBox:
		editor.set_value_no_signal(float(value))


func set_skip_typing(on: bool) -> void:
	_skip_typing.button_pressed = on
	presenter.skip_typing = on


func set_skip_delays(on: bool) -> void:
	_skip_delays.button_pressed = on
	presenter.delay_scale = 0.0 if on else 1.0


func is_playing() -> bool:
	return runner != null and runner.is_running()


func node_titles() -> Array[String]:
	var titles: Array[String] = []
	for node in _nodes:
		titles.append(node.title)
	return titles


func log_lines() -> Array[String]:
	return _log_lines


# --- runner events ---------------------------------------------------------------

# Every time Yarn enters a node, remember the variables at that moment so Back
# can return here. (Not when Back/Restart itself is replaying a node.)
func _on_node_started(node_name: String) -> void:
	view.set_title(node_name.get_slice("_", 0))  # "Mom_L1_Start" -> "Mom"
	if not _restoring:
		_history.append({"node": node_name, "variables": _snapshot()})
	_restoring = false
	_log_line("▶ " + node_name)
	_refresh_variables()


func _on_dialogue_completed() -> void:
	_log_line("■ end of dialogue")
	_refresh_variables()


func _on_command(command: String, args: Array) -> void:
	_log_line("<<%s %s>> (the game would run this)" % [command, " ".join(args.map(func(a): return str(a)))])


# Replays a node from the history with the variables it had then.
func _jump_to(entry: Dictionary) -> void:
	await stop()
	view.clear()
	storage.clear()
	for variable in entry.variables:
		storage.set_value(variable, entry.variables[variable])
	_history.append(entry)
	_restoring = true
	runner.start_dialogue(entry.node)


# The current value of every declared story variable.
func _snapshot() -> Dictionary:
	var values := {}
	for variable in _declared:
		values[variable] = storage.get_value(variable)
	return values


# Adds a line to the log panel (and to log_lines(), for tests).
func _log_line(text: String) -> void:
	_log_lines.append(text)
	if _log != null:
		_log.append_text(text.replace("[", "[lb]") + "\n")


# --- reading the Yarn project ---------------------------------------------------

# Every .yarnproject in the game (skipping addons), for the project picker.
func _find_projects(dir_path: String) -> Array[String]:
	var found: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return found
	for sub in dir.get_directories():
		if not sub.begins_with(".") and sub != "addons":
			found.append_array(_find_projects(dir_path.path_join(sub)))
	for file in dir.get_files():
		if file.get_extension() == "yarnproject":
			found.append(dir_path.path_join(file))
	found.sort()
	return found


# Every .yarn file in a folder and its subfolders.
func _yarn_files(dir_path: String) -> Array[String]:
	var files: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return files
	for sub in dir.get_directories():
		if not sub.begins_with("."):
			files.append_array(_yarn_files(dir_path.path_join(sub)))
	for file in dir.get_files():
		if file.get_extension() == "yarn":
			files.append(dir_path.path_join(file))
	files.sort()
	return files


## Node titles, marking entry points: nodes nothing jumps to, which the game starts.
## We read the .yarn text directly (rather than asking Yarn) because we also want
## to know which nodes are jumped to, to mark the rest as entry points.
func _read_nodes(project_dir: String) -> Array[Dictionary]:
	var nodes: Array[Dictionary] = []
	var referenced := {}  # titles that some <<jump>>, <<detour>> or <<start_thread>> points at
	var reference := RegEx.create_from_string("<<\\s*(?:jump|detour)\\s+(\\w+)|<<\\s*start_thread\\s+\\S+\\s+(\\w+)")
	for path in _yarn_files(project_dir):
		for line in FileAccess.get_file_as_string(path).split("\n"):
			var stripped := line.strip_edges()
			if stripped.begins_with("title:"):
				var title := stripped.trim_prefix("title:").strip_edges()
				if title != "Variables":
					nodes.append({"title": title, "file": path.trim_prefix(project_dir + "/")})
			for m in reference.search_all(stripped):
				referenced[m.get_string(1) if m.get_string(1) != "" else m.get_string(2)] = true
	for node in nodes:
		node.entry = not referenced.has(node.title)
	# Entry points first, then alphabetical.
	nodes.sort_custom(func(a, b): return (a.entry and not b.entry) or (a.entry == b.entry and a.title < b.title))
	return nodes


## `<<declare $name = value>>` lines (all in Variables.yarn, per the writing guide).
func _read_declarations(project_dir: String) -> Dictionary:
	var declared := {}
	var declare := RegEx.create_from_string("<<\\s*declare\\s+(\\$\\w+)\\s*=\\s*(.+?)\\s*>>")
	for path in _yarn_files(project_dir):
		for m in declare.search_all(FileAccess.get_file_as_string(path)):
			# Turn the starting value's text into a real bool, number or string.
			var raw := m.get_string(2)
			var value: Variant = raw
			if raw == "true" or raw == "false":
				value = raw == "true"
			elif raw.is_valid_float():
				value = raw.to_float()
			elif raw.begins_with("\"") and raw.ends_with("\""):
				value = raw.substr(1, raw.length() - 2)
			declared[m.get_string(1)] = value
	return declared


# --- UI ---------------------------------------------------------------------------

# Fills the node list, applying the filter box.
func _refresh_node_list() -> void:
	_node_list.clear()
	var filter := _filter.text.to_lower()
	for node in _nodes:
		if filter != "" and not node.title.to_lower().contains(filter):
			continue
		var index := _node_list.add_item(("★ " if node.entry else "    ") + node.title)
		_node_list.set_item_metadata(index, node.title)
		_node_list.set_item_tooltip(index, node.file + ("\nEntry point: the game starts this node." if node.entry else ""))


# Updates the variable editors to show the current values (the conversation may
# have changed them). Doesn't fire their change signals, and leaves a text box
# alone while someone is typing in it.
func _refresh_variables() -> void:
	for variable in _variable_editors:
		var editor: Control = _variable_editors[variable]
		var value: Variant = storage.get_value(variable)
		if editor is CheckBox:
			editor.set_pressed_no_signal(bool(value))
		elif editor is SpinBox:
			editor.set_value_no_signal(float(value))
		elif editor is LineEdit and not editor.has_focus():
			editor.text = str(value)


# One editor per declared variable: a checkbox, number box or text box,
# depending on its starting value.
func _rebuild_variable_editors() -> void:
	for child in _variables_box.get_children():
		child.queue_free()
	_variable_editors.clear()
	for variable in _declared:
		_variables_box.add_child(_small_label(variable))
		var editor := _editor_for(_declared[variable], func(value): storage.set_value(variable, value))
		_variables_box.add_child(editor)
		_variable_editors[variable] = editor
	_refresh_variables()


# One editor per game function in DialogueHooks, starting at false / 0 / "".
# Every function is faked while the playtest runs: there's no game to ask.
func _rebuild_hook_editors() -> void:
	for child in _hooks_box.get_children():
		child.queue_free()
	for function in DialogueHooks.list_functions():
		var default: Variant = false if function.type == TYPE_BOOL else (0.0 if function.type in [TYPE_INT, TYPE_FLOAT] else "")
		var is_int: bool = function.type == TYPE_INT
		DialogueHooks.fakes[function.name] = int(default) if is_int else default
		_hooks_box.add_child(_small_label(function.name + "()"))
		var editor := _editor_for(default, func(value):
			DialogueHooks.fakes[function.name] = int(value) if is_int else value)
		_hooks_box.add_child(editor)
		_hook_editors[function.name] = editor


# A control for editing a value of `value`'s type; calls on_change with the new value.
func _editor_for(value: Variant, on_change: Callable) -> Control:
	if value is bool:
		var box := CheckBox.new()
		box.button_pressed = value
		box.toggled.connect(on_change)
		return box
	if value is float or value is int:
		var spin := SpinBox.new()
		spin.min_value = -9999
		spin.max_value = 9999
		spin.step = 1
		spin.value = value
		spin.value_changed.connect(on_change)
		return spin
	var edit := LineEdit.new()
	edit.text = str(value)
	edit.custom_minimum_size.x = 120
	edit.text_submitted.connect(on_change)
	return edit


func _small_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	return label


# Creates the layout: settings and lists in a scrolling panel on the left, the
# phone (ChatView) in the middle of the rest of the screen.
func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("2c2c2e")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var split := HBoxContainer.new()
	split.set_anchors_preset(Control.PRESET_FULL_RECT)
	split.add_theme_constant_override("separation", 16)
	add_child(split)

	var margin := MarginContainer.new()
	for side in ["left", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	split.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 400
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var panel := VBoxContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(panel)

	panel.add_child(_heading("Dialogue playtest"))
	_project_picker = OptionButton.new()
	_project_picker.item_selected.connect(func(i): select_project("res://" + _project_picker.get_item_text(i)))
	panel.add_child(_project_picker)

	_filter = LineEdit.new()
	_filter.placeholder_text = "Filter nodes…"
	_filter.text_changed.connect(func(_t): _refresh_node_list())
	panel.add_child(_filter)
	_node_list = ItemList.new()
	_node_list.custom_minimum_size.y = 220
	_node_list.item_activated.connect(func(i): play(_node_list.get_item_metadata(i)))
	panel.add_child(_node_list)
	panel.add_child(_small_label("★ = entry point (the game starts it). Double-click to play."))

	var buttons := HBoxContainer.new()
	panel.add_child(buttons)
	for spec in [["Play", func(): _play_selected()], ["Back", func(): back()],
			["Restart", func(): restart()], ["Reset variables", func(): reset_variables()]]:
		var button := Button.new()
		button.text = spec[0]
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(spec[1])
		buttons.add_child(button)

	_skip_typing = CheckBox.new()
	_skip_typing.text = "Skip typing (send Me: lines automatically)"
	_skip_typing.toggled.connect(func(on): presenter.skip_typing = on)
	panel.add_child(_skip_typing)
	_skip_delays = CheckBox.new()
	_skip_delays.text = "Skip delays (messages arrive instantly)"
	_skip_delays.toggled.connect(func(on): presenter.delay_scale = 0.0 if on else 1.0)
	panel.add_child(_skip_delays)

	panel.add_child(_heading("Story variables"))
	_variables_box = GridContainer.new()
	_variables_box.columns = 2
	panel.add_child(_variables_box)

	panel.add_child(_heading("Fake game state"))
	_hooks_box = GridContainer.new()
	_hooks_box.columns = 2
	panel.add_child(_hooks_box)

	panel.add_child(_heading("Log"))
	_log = RichTextLabel.new()
	_log.custom_minimum_size.y = 160
	_log.scroll_following = true
	_log.bbcode_enabled = true
	panel.add_child(_log)

	var phone_area := CenterContainer.new()
	phone_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(phone_area)
	view = ChatView.new()
	view.custom_minimum_size = Vector2(380, 680)
	phone_area.add_child(view)

	presenter = ChatPresenter.new()
	presenter.view = view
	presenter.writer_mode = true


func _play_selected() -> void:
	var selected := _node_list.get_selected_items()
	if selected.is_empty():
		_log_line("Pick a node first.")
		return
	play(_node_list.get_item_metadata(selected[0]))


func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	return label
