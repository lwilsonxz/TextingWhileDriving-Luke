extends Node
## Headless checks for the Yarn Spinner spike (roadmap A0).
## Run from the repo root:
##   godot --headless --path spikes/yarn-spinner --import
##   godot --headless --path spikes/yarn-spinner
## Exits with code 1 if any check fails.

const TIMEOUT_SEC := 10.0

var _failures: Array[String] = []


func _ready() -> void:
	await _check_lines_options_tags_commands_functions()
	await _check_me_lines_inside_options()
	await _check_parallel_threads_share_variables()
	await _check_save_and_load_variables()
	await _check_reimport_marker()
	print("")
	if _failures.is_empty():
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED:" % _failures.size())
		for failure in _failures:
			print("  - " + failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


# --- checks -----------------------------------------------------------------

func _check_lines_options_tags_commands_functions() -> void:
	print("\n== Lines, options, hashtags, commands, functions, hidden timeout option ==")
	var storage := _make_storage()
	var mom := _make_presenter("Mom", [], _choose_by_metadata("timeout:10"))
	var runner := _make_runner(storage, mom)
	await _run(runner, "Mom_Spike_Start")

	var texts := mom.lines.map(func(l): return l.text)
	_check(mom.lines.size() > 0 and mom.lines[0].character == "Mom", "character name is parsed (Mom)")
	_check(mom.lines.size() > 0 and mom.lines[0].text == "placeholder incoming one", "text excludes character name")
	_check(mom.lines.size() > 0 and "delay:1.5" in mom.lines[0].metadata, "line hashtag #delay:1.5 arrives as metadata (got %s)" % [mom.lines[0].metadata if mom.lines.size() > 0 else "nothing"])
	_check(mom.lines.size() > 1 and mom.lines[1].msec - mom.lines[0].msec >= 190, "custom <<typing 0.2>> command pauses dialogue (%d ms)" % [mom.lines[1].msec - mom.lines[0].msec if mom.lines.size() > 1 else -1])
	_check("placeholder only shown when the stop sign was run" in texts, "game function ran_stop_sign() is called from a condition")
	_check(mom.option_sets.size() == 1 and mom.option_sets[0].size() == 4, "all four options are delivered")
	if mom.option_sets.size() == 1 and mom.option_sets[0].size() == 4:
		var opts: Array = mom.option_sets[0]
		_check(opts[0].text == "Short label A", "option text is the short label")
		_check(not opts[2].available, "option with a false <<if>> condition is marked unavailable")
		_check("timeout:10" in opts[3].metadata, "option hashtag #timeout:10 arrives as metadata (got %s)" % [opts[3].metadata])
	_check(storage.get_value("$ignored_mom") == true, "picking the hidden timeout option runs its body ($ignored_mom = true)")
	_check(storage.get_value("$mom_messages") == 2, "<<set>> arithmetic works ($mom_messages = 2)")
	_check("placeholder reply to being ignored" in texts, "<<jump>> from the timeout option reaches Mom_Spike_Ignored")
	runner.queue_free()


func _check_me_lines_inside_options() -> void:
	print("\n== `Me:` lines inside an option (the text the player must type) ==")
	var mom := _make_presenter("Mom", [], _choose_by_text("Short label B"))
	var runner := _make_runner(_make_storage(), mom)
	await _run(runner, "Mom_Spike_Start")

	var me_lines := mom.lines.filter(func(l): return l.character == "Me")
	_check(me_lines.size() == 2, "both Me: lines are delivered after choosing B (got %d)" % me_lines.size())
	_check(me_lines.size() == 2 and me_lines[0].text == "text for option b, line one", "Me: line text is exact, including punctuation")
	_check(not mom.lines.any(func(l): return l.text == "Short label B"), "the short option label is not echoed as a line")
	_check(mom.lines.size() > 0 and mom.lines[-1].text == "placeholder reply to b", "Mom replies after the Me: lines")
	runner.queue_free()


func _check_parallel_threads_share_variables() -> void:
	print("\n== Two threads at once, one shared variable store ==")
	var storage := _make_storage()
	var log: Array = []
	var mom := _make_presenter("Mom", log, _choose_by_text("Short label A"))
	var dad := _make_presenter("Dad", log, _choose_by_text(""))
	var mom_runner := _make_runner(storage, mom)
	var dad_runner := _make_runner(storage, dad)

	var done := {"Mom": false, "Dad": false}
	mom_runner.dialogue_completed.connect(func(): done.Mom = true, CONNECT_ONE_SHOT)
	dad_runner.dialogue_completed.connect(func(): done.Dad = true, CONNECT_ONE_SHOT)
	await _settle()
	mom_runner.start_dialogue("Mom_Spike_Start")
	dad_runner.start_dialogue("Dad_Spike_Start")
	var waited := 0.0
	while not (done.Mom and done.Dad) and waited < TIMEOUT_SEC:
		await get_tree().process_frame
		waited += get_process_delta_time()

	print("  arrival order: ", log)
	_check(done.Mom and done.Dad, "both runners complete")
	var first_dad := log.find("Dad|placeholder dad one")
	var last_dad := log.find("Dad|placeholder dad three")
	var mom_between := false
	for i in range(first_dad + 1, last_dad):
		if str(log[i]).begins_with("Mom|"):
			mom_between = true
	_check(first_dad >= 0 and last_dad > first_dad and mom_between, "messages from both threads interleave (they really run in parallel)")
	_check(storage.get_value("$lied_to_mom") == true and storage.get_value("$dad_messages") == 3, "both threads write to the same store")
	mom_runner.queue_free()
	dad_runner.queue_free()


func _check_save_and_load_variables() -> void:
	print("\n== Save story variables to disk and load them into a fresh runner ==")
	var storage := _make_storage()
	var first := _make_presenter("Mom", [], _choose_by_metadata("timeout:10"))
	var runner := _make_runner(storage, first)
	await _run(runner, "Mom_Spike_Start")
	runner.queue_free()

	var names := ["$lied_to_mom", "$ignored_mom", "$mom_messages"]
	var saved := {}
	for variable in names:
		saved[variable] = storage.get_value(variable)
	var file := FileAccess.open("user://spike_save.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(saved))
	file.close()

	var loaded: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://spike_save.json"))
	var fresh_storage := _make_storage()
	for variable in loaded:
		fresh_storage.set_value(variable, loaded[variable])
	var second := _make_presenter("Mom", [], _choose_by_text(""))
	var fresh_runner := _make_runner(fresh_storage, second)
	await _run(fresh_runner, "Mom_Spike_Followup")
	_check(second.lines.size() == 1 and second.lines[0].text == "placeholder followup after being ignored", "a later conversation branches on loaded variables")
	fresh_runner.queue_free()


func _check_reimport_marker() -> void:
	var expected := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--expect-reimport="):
			expected = arg.trim_prefix("--expect-reimport=")
	if expected.is_empty():
		return
	print("\n== Edited .yarn file was recompiled on reimport ==")
	var presenter := _make_presenter("Check", [], _choose_by_text(""))
	var runner := _make_runner(_make_storage(), presenter)
	await _run(runner, "Reimport_Check")
	_check(presenter.lines.size() == 1 and presenter.lines[0].text == expected, "Reimport_Check says '%s'" % expected)
	runner.queue_free()


# --- helpers ----------------------------------------------------------------

func _make_storage() -> YarnInMemoryVariableStorage:
	var storage := YarnInMemoryVariableStorage.new()
	add_child(storage)
	return storage


func _make_presenter(thread_name: String, log: Array, choose: Callable) -> SpikePresenter:
	var presenter := SpikePresenter.new()
	presenter.thread_name = thread_name
	presenter.arrival_log = log
	presenter.choose = choose
	return presenter


func _make_runner(storage: YarnVariableStorage, presenter: SpikePresenter) -> YarnDialogueRunner:
	var runner := YarnDialogueRunner.new()
	runner.yarn_project = load("res://dialogue/Spike.yarnproject")
	runner.auto_start = false
	runner.show_selected_option_as_line = false
	runner.variable_storage = storage
	add_child(runner)
	runner.add_child(presenter)
	runner.add_presenter(presenter)
	return runner


func _run(runner: YarnDialogueRunner, node: String) -> void:
	var state := {"done": false}
	runner.dialogue_completed.connect(func(): state.done = true, CONNECT_ONE_SHOT)
	await _settle()
	runner.start_dialogue(node)
	var waited := 0.0
	while not state.done and waited < TIMEOUT_SEC:
		await get_tree().process_frame
		waited += get_process_delta_time()
	if not state.done:
		_check(false, "dialogue '%s' finished within %ds" % [node, TIMEOUT_SEC])


## Loading a runner stalls a frame; Godot then speeds game time up for a few
## frames to catch up, which shortens timers started right after. Let it settle
## so the <<typing>> timing check measures the command, not the catch-up.
func _settle() -> void:
	await get_tree().create_timer(0.5).timeout


func _choose_by_metadata(tag: String) -> Callable:
	return func(options: Array[YarnOption]) -> int:
		for i in options.size():
			if tag in options[i].metadata:
				return i
		return -1


func _choose_by_text(text: String) -> Callable:
	return func(options: Array[YarnOption]) -> int:
		for i in options.size():
			if options[i].text_without_character_name == text:
				return i
		return -1


func _check(condition: bool, label: String) -> void:
	print(("  PASS  " if condition else "  FAIL  ") + label)
	if not condition:
		_failures.append(label)
