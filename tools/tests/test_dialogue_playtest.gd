extends SceneTree
## End-to-end test of the dialogue playtest scene and the phone conversation UI,
## using the sample conversation (a copy of docs/writing/template.yarn).
##
## From the repo root (import the project once first):
##   godot --headless --path TextingWhileDriving --script res://../tools/tests/test_dialogue_playtest.gd
## Exits 1 on failure.

const SAMPLE := "res://game/debug/dialogue_playtest/sample/Sample.yarnproject"
const TIMEOUT := 10.0

var playtest: DialoguePlaytest
var _failures := 0


func _initialize() -> void:
	await process_frame
	playtest = load("res://game/debug/dialogue_playtest/dialogue_playtest.tscn").instantiate()
	root.add_child(playtest)
	await process_frame
	await playtest.select_project(SAMPLE)
	playtest.set_skip_delays(true)

	await _test_lists_nodes()
	await _test_choice_typing_and_reply()
	await _test_back_restores_variables()
	await _test_faked_hook_and_hidden_timeout_choice()
	await _test_timeout_picks_automatically()
	await _test_unavailable_choice_is_shown_greyed_out()
	await _test_skip_typing()
	await _test_player_mode_hides_writer_aids()
	await _test_delays()

	print("")
	print("ALL TESTS PASSED" if _failures == 0 else "%d TEST(S) FAILED" % _failures)
	DialogueHooks.fakes.clear()
	playtest.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _test_lists_nodes() -> void:
	print("== Lists the project's nodes, entry points first ==")
	var titles := playtest.node_titles()
	_check(titles.size() == 4, "4 nodes (got %s)" % [titles])
	_check(not titles.is_empty() and titles[0] == "Mom_L1_Start", "Mom_L1_Start, the only entry point, is first")


func _test_choice_typing_and_reply() -> void:
	print("== Choose, type the Me: line (with a typo), send, get the reply ==")
	playtest.play("Mom_L1_Start")
	await _wait_until(func(): return playtest.view.choice_texts().size() > 0)
	_check(playtest.view.transcript() == ["Mom: placeholder first message", "Mom: placeholder second message"],
		"both incoming messages shown (got %s)" % [playtest.view.transcript()])
	var choices := playtest.view.choice_texts()
	_check(choices.size() == 4, "4 choices in writer mode (got %s)" % [choices])
	_check(choices.size() == 4 and choices[3].contains("hidden; picked automatically after 15s"),
		"the hidden timeout choice is shown, explained")

	playtest.view.press_choice(0)
	await _wait_until(func(): return playtest.view.is_typing())
	_check(playtest.view.is_typing(), "choosing starts the typing challenge")
	_type("placeholder text the player typeX")
	_press(KEY_ENTER)
	await process_frame
	_check(playtest.view.is_typing(), "Enter with a typo doesn't send")
	_press(KEY_BACKSPACE)
	_type("s")
	_press(KEY_ENTER)
	await _wait_until(func(): return not playtest.is_playing())
	var transcript := playtest.view.transcript()
	_check(transcript.has("Me: placeholder text the player types"), "the typed message is sent")
	_check(not transcript.is_empty() and transcript[-1] == "Mom: placeholder reply", "Mom replies (got %s)" % [transcript])
	_check(playtest.get_variable("$mom_l1_answered") == true, "<<set>> in the choice ran")


func _test_back_restores_variables() -> void:
	print("== Back returns to the previous node with its variables ==")
	await playtest.back()
	await _wait_until(func(): return playtest.view.choice_texts().size() > 0)
	_check(playtest.get_variable("$mom_l1_answered") == false, "variable restored to its value at that node")
	_check(playtest.view.transcript().size() == 2, "the conversation restarts from that node")
	await playtest.stop()


func _test_faked_hook_and_hidden_timeout_choice() -> void:
	print("== Faked game function + picking the hidden timeout choice by hand ==")
	playtest.set_fake("ran_stop_sign", true)
	playtest.reset_variables()
	playtest.play("Mom_L1_Start")
	await _wait_until(func(): return playtest.view.choice_texts().size() > 0)
	playtest.view.press_choice(3)
	await _wait_until(func(): return not playtest.is_playing())
	var transcript := playtest.view.transcript()
	_check(transcript.has("Mom: placeholder line that only appears if the player ran the stop sign"),
		"the faked ran_stop_sign() = true changes the branch (got %s)" % [transcript])
	_check(transcript.has("* placeholder system notice"), "System: line shown as a notice")
	_check(playtest.get_variable("$mom_trust") == 2.0, "timeout choice's <<set>> ran ($mom_trust = 2)")
	playtest.set_fake("ran_stop_sign", false)


func _test_timeout_picks_automatically() -> void:
	print("== The timeout choice is picked when nobody answers ==")
	playtest.reset_variables()
	playtest.play("Mom_L1_Start")
	await _wait_until(func(): return playtest.view.choice_texts().size() > 0)
	Engine.time_scale = 30.0  # the sample waits 15 s
	await _wait_until(func(): return not playtest.is_playing())
	Engine.time_scale = 1.0
	_check(playtest.view.transcript().has("Mom: placeholder line otherwise"), "nobody answered, so the timeout branch ran")


func _test_unavailable_choice_is_shown_greyed_out() -> void:
	print("== A choice whose condition is false is greyed out in writer mode ==")
	playtest.reset_variables()
	playtest.set_variable("$mom_trust", 1.0)
	playtest.play("Mom_L1_Start")
	await _wait_until(func(): return playtest.view.choice_texts().size() > 0)
	var choices := playtest.view.choice_texts()
	_check(choices.size() == 4 and choices[2].contains("not offered: its condition is false"),
		"label three is explained as not offered (got %s)" % [choices])
	await playtest.stop()


func _test_skip_typing() -> void:
	print("== Skip typing sends Me: lines automatically ==")
	playtest.reset_variables()
	playtest.set_skip_typing(true)
	playtest.play("Mom_L1_Start")
	await _wait_until(func(): return playtest.view.choice_texts().size() > 0)
	playtest.view.press_choice(1)
	await _wait_until(func(): return not playtest.is_playing())
	var transcript := playtest.view.transcript()
	_check(transcript.has("Me: placeholder first message to type") and transcript.has("Me: placeholder second message to type"),
		"both Me: lines sent without typing")
	_check(transcript.has("Me: placeholder forced reply"), "the forced reply in the next node is sent too")
	_check(playtest.log_lines().has("▶ Mom_L1_ReplyTwo"), "the log shows which node is playing")
	playtest.set_skip_typing(false)


func _test_player_mode_hides_writer_aids() -> void:
	print("== Outside writer mode (the real phone), hidden choices stay hidden ==")
	playtest.presenter.writer_mode = false
	playtest.reset_variables()
	playtest.set_variable("$mom_trust", 1.0)
	playtest.play("Mom_L1_Start")
	await _wait_until(func(): return playtest.view.choice_texts().size() > 0)
	var choices := playtest.view.choice_texts()
	_check(choices == ["Placeholder label one", "Placeholder label two"],
		"only the choices the player can pick are shown (got %s)" % [choices])
	await playtest.stop()
	playtest.presenter.writer_mode = true


func _test_delays() -> void:
	print("== #delay makes messages arrive later ==")
	playtest.reset_variables()
	playtest.set_skip_delays(false)
	var started := Time.get_ticks_msec()
	playtest.play("Mom_L1_Start")
	await create_timer(1.0).timeout
	_check(playtest.view.transcript().is_empty(), "nothing yet after 1 s (first message has #delay:2)")
	await _wait_until(func(): return playtest.view.transcript().size() == 2)
	var elapsed := (Time.get_ticks_msec() - started) / 1000.0
	_check(elapsed >= 2.9 and elapsed < 4.0, "both messages after about 2 + 1 s (took %.1f s)" % elapsed)
	await playtest.stop()
	playtest.set_skip_delays(true)


# --- helpers -------------------------------------------------------------------

# Types text as key presses (the character each key would produce).
func _type(text: String) -> void:
	for c in text:
		var event := InputEventKey.new()
		event.pressed = true
		event.unicode = c.unicode_at(0)
		Input.parse_input_event(event)


# Presses a single key (Enter, Backspace, ...).
func _press(key: Key) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = key
	event.physical_keycode = key
	Input.parse_input_event(event)


# Waits until `condition` returns true, or fails after TIMEOUT seconds.
func _wait_until(condition: Callable) -> void:
	var waited := 0.0
	while not condition.call() and waited < TIMEOUT:
		await process_frame
		waited += root.get_process_delta_time() / maxf(Engine.time_scale, 1.0)
	if not condition.call():
		_check(false, "timed out waiting")


func _check(condition: bool, label: String) -> void:
	print(("  PASS  " if condition else "  FAIL  ") + label)
	if not condition:
		_failures += 1
