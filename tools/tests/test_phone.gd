extends SceneTree
## Tests the phone in the car on the test course: a TextTrigger starts a
## conversation, the player taps a choice with the mouse and types the reply
## while driving, and the conversation reacts to the driving
## (running the stop sign). Also PhoneService's queue and a level ending
## mid-conversation.
##
##   godot --headless --path TextingWhileDriving --script res://../tools/tests/test_phone.gd
## Exits 1 on failure.

const LEVEL := "res://game/levels/test_course.tscn"
const TIMEOUT := 10.0
const SAMPLE := "res://game/debug/dialogue_playtest/sample/Sample.yarnproject"

var level: Node
var car: VehicleBody3D
var camera: CarCamera
var phone: Node3D
var service: Node
var settings: Node
var _failures := 0


func _initialize() -> void:
	await process_frame
	service = root.get_node("PhoneService")
	settings = root.get_node("Settings")
	# Use the default playtest options, and put the player's own back at the end.
	var saved := [settings.phone_glance, settings.phone_placement, settings.phone_type_without_looking]
	settings.set_phone_glance(CarCamera.PhoneGlance.TOGGLE)
	settings.set_phone_placement(&"dash_mount")
	settings.set_phone_type_without_looking(true)
	service.delay_scale = 0.0  # messages arrive at once (delays are tested in test_dialogue_playtest)

	await _test_trigger_tap_and_type()
	await _test_conversation_reads_driving()
	await _test_typing_without_looking_option()
	await _test_queue()
	await _test_level_ends_mid_conversation()

	settings.set_phone_glance(saved[0])
	settings.set_phone_placement(saved[1])
	settings.set_phone_type_without_looking(saved[2])
	print("")
	print("ALL TESTS PASSED" if _failures == 0 else "%d TEST(S) FAILED" % _failures)
	await _unload_level()
	quit(0 if _failures == 0 else 1)


func _test_trigger_tap_and_type() -> void:
	print("== Driving into the trigger starts Mom's conversation; tap a choice and type the reply ==")
	await _load_level()
	_check(not service.is_playing(), "the phone is quiet at the start")
	await _drive_into_trigger()
	_check(service.current_thread() == "Mom", "driving into the trigger starts Mom's conversation")
	await _wait_until(func(): return phone.view.choice_texts().size() > 0)
	_check(phone.view.transcript() == ["Mom: placeholder first message", "Mom: placeholder second message"],
		"Mom's messages arrive on the phone (got %s)" % [phone.view.transcript()])
	_check(phone.view.choice_texts().size() == 3, "3 choices: the hidden timeout choice isn't shown in the game (got %s)" % [phone.view.choice_texts()])

	camera.snap_to(CarCamera.PHONE)
	await _frames(2)
	await _click_choice(0)
	_check(phone.view.is_typing(), "clicking a choice on the phone picks it")
	_type("placeholder text the player typeX")
	_press(KEY_ENTER)
	await _frames(2)
	_check(phone.view.is_typing(), "Enter with a typo doesn't send")
	_press(KEY_BACKSPACE)
	_type("s")
	_press(KEY_ENTER)
	await _wait_until(func(): return not service.is_playing())
	var transcript: Array[String] = phone.view.transcript()
	_check(transcript.has("Me: placeholder text the player types"), "the typed message is sent")
	_check(not transcript.is_empty() and transcript[-1] == "Mom: placeholder reply", "Mom replies (got %s)" % [transcript])
	_check(service.storage.try_get_value("$mom_l1_answered").value == true, "the story variable is set")
	_check(service.messages_sent == 1 and service.replies_missed == 0, "one message sent, none missed (for the results screen)")


func _test_conversation_reads_driving() -> void:
	print("== Ignoring Mom after running the stop sign: the conversation knows ==")
	await _load_level()
	await _drive_into_trigger()
	var state: LevelState = level.get_node("LevelState")
	_check(state.violation_count(&"stop_sign") == 1, "running the stop sign is recorded (got %s)" % [state.violations])
	_check(DialogueHooks._yarn_function_ran_stop_sign() and DialogueHooks._yarn_function_violations() == state.violations.size(),
		"ran_stop_sign() and violations() read the level's record")
	# Park the car and let the 15 s reply deadline pass quickly.
	car.freeze = true
	Engine.time_scale = 30.0
	await _wait_until(func(): return not service.is_playing())
	Engine.time_scale = 1.0
	car.freeze = false
	var transcript: Array[String] = phone.view.transcript()
	_check(transcript.has("Mom: placeholder line that only appears if the player ran the stop sign"),
		"nobody answered, and the branch for running the stop sign plays (got %s)" % [transcript])
	_check(transcript.has("* placeholder system notice"), "System: lines show as notices")
	_check(service.replies_missed == 1, "the ignored reply counts as missed")


func _test_typing_without_looking_option() -> void:
	print("== Typing works without looking at the phone; F8 switches to 'only while looking' ==")
	await _load_level()
	service.start_thread("Mom", "Mom_L1_ReplyTwo", SAMPLE)
	await _wait_until(func(): return phone.view.is_typing())
	_type("placeholder forced reply")
	_press(KEY_ENTER)
	await _wait_until(func(): return not service.is_playing())
	_check(phone.view.transcript().has("Me: placeholder forced reply"), "by default, typing works while looking at the road (got %s)" % [phone.view.transcript()])

	await _tap("debug_toggle_phone_typing_glance")
	_check(not settings.phone_type_without_looking, "F8 switches the option")
	service.start_thread("Mom", "Mom_L1_ReplyTwo", SAMPLE)
	await _wait_until(func(): return phone.view.is_typing())
	_type("placeholder forced reply")
	_press(KEY_ENTER)
	await _frames(2)
	_check(phone.view.is_typing(), "with it on, keys don't reach the phone while looking at the road")
	camera.snap_to(CarCamera.PHONE)
	await _frames(2)
	_type("placeholder forced reply")
	_press(KEY_ENTER)
	await _wait_until(func(): return not service.is_playing())
	_check(not phone.view.is_typing(), "but do while looking at it")
	settings.set_phone_type_without_looking(true)


func _test_queue() -> void:
	print("== A thread started while another plays waits its turn ==")
	await _load_level()
	var started: Array[String] = []
	var on_started := func(thread, node): started.append("%s %s" % [thread, node])
	service.thread_started.connect(on_started)
	service.start_thread("Mom", "Mom_L1_Start", SAMPLE)
	service.start_thread("Dad", "Mom_L1_Ignored", SAMPLE)
	_check(service.current_thread() == "Mom" and service.queued_count() == 1, "the second thread is queued")
	await _wait_until(func(): return phone.view.choice_texts().size() > 0)
	phone.view.press_choice(1)
	camera.snap_to(CarCamera.PHONE)
	for message in ["placeholder first message to type", "placeholder second message to type", "placeholder forced reply"]:
		await _wait_until(func(): return phone.view.is_typing(), "typing: " + message)
		_type(message)
		_press(KEY_ENTER)
		await _frames(2)
	await _wait_until(func(): return started.size() == 2, "Dad's thread")
	_check(started == ["Mom Mom_L1_Start", "Dad Mom_L1_Ignored"], "then it plays (got %s)" % [started])
	await _wait_until(func(): return not service.is_playing())
	_check(phone.view.transcript()[0] == "Mom: placeholder line otherwise", "a new contact gets a fresh screen")
	service.thread_started.disconnect(on_started)


func _test_level_ends_mid_conversation() -> void:
	print("== The level ending mid-conversation leaves the phone service ready for the next ==")
	await _load_level()
	service.start_thread("Mom", "Mom_L1_Start", SAMPLE)
	service.start_thread("Dad", "Mom_L1_Ignored", SAMPLE)
	await _wait_until(func(): return phone.view.choice_texts().size() > 0)
	await _unload_level()
	await _frames(5)
	_check(not service.is_playing() and service.queued_count() == 0, "the conversation and the queue are dropped")
	await _load_level()
	service.start_thread("Mom", "Mom_L1_Ignored", SAMPLE)
	await _wait_until(func(): return not service.is_playing())
	_check(phone.view.transcript().size() == 2, "the next level's phone plays normally (got %s)" % [phone.view.transcript()])


# --- helpers -------------------------------------------------------------------

func _load_level() -> void:
	await _unload_level()
	level = load(LEVEL).instantiate()
	root.add_child(level)
	await process_frame
	car = level.get_node("car")
	camera = car.get_node("FirstPersonCamera")
	phone = car.get_node("PhoneMount/Phone")
	await _ticks(10)


func _unload_level() -> void:
	if level != null and is_instance_valid(level):
		level.queue_free()
		await process_frame
	level = null


# Full throttle from the start: through the stop sign (~80 km/h, a violation)
# and into the trigger just past it, then brake to a stop.
func _drive_into_trigger() -> void:
	var trigger: TextTrigger = level.get_node("MomTexts")
	Input.action_press("drive_accelerate")
	var ticks := 0
	while not trigger.has_fired and ticks < 60 * 15:
		await physics_frame
		ticks += 1
	Input.action_release("drive_accelerate")
	_check(trigger.has_fired, "the car reached the trigger (%.1f s)" % (ticks / 60.0))
	# Brake to a stop before the end of the straight (driving off it is a crash).
	Input.action_press("drive_reverse")
	var braking := 0
	while car.linear_velocity.length() > 1.0 and braking < 60 * 6:
		braking += 1
		await physics_frame
	Input.action_release("drive_reverse")


# Clicks the middle of choice button `index` on the phone, with the real mouse
# path: find where the button is on the 3D phone, then where that is on screen.
func _click_choice(index: int) -> void:
	var buttons: Array[Node] = phone.view.find_children("*", "Button", true, false)
	if index >= buttons.size():
		_check(false, "there's a choice button %d to click" % index)
		return
	var button: Button = buttons[index]
	var on_screen := camera.unproject_position(phone.screen_to_world(button.get_global_rect().get_center()))
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = on_screen
		event.global_position = on_screen
		Input.parse_input_event(event)
		await _frames(1)
	await _frames(2)


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


# Presses and releases an input action, as a key press would.
func _tap(action: String) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
		await _frames(1)


# Waits until `condition` returns true, or fails after TIMEOUT seconds (real time).
func _wait_until(condition: Callable, what := "") -> void:
	var started := Time.get_ticks_msec()
	while not condition.call() and Time.get_ticks_msec() - started < TIMEOUT * 1000:
		await process_frame
	if not condition.call():
		_check(false, "timed out waiting" + (" for " + what if what else ""))


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _ticks(count: int) -> void:
	for i in count:
		await physics_frame


func _check(condition: bool, label: String) -> void:
	print(("  PASS  " if condition else "  FAIL  ") + label)
	if not condition:
		_failures += 1
