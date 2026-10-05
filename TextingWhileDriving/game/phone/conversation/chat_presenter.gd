class_name ChatPresenter
extends YarnDialoguePresenter
## Plays Yarn dialogue on a ChatView, following docs/WRITING_GUIDE.md:
## - `Name: text` arrives as an incoming bubble after its #delay (typing indicator shows meanwhile)
## - `Me: text` is a typing challenge; the bubble is sent once the player types it
## - `System: text` is a small notice
## - choices are buttons; a `#timeout:N` choice is hidden and picked automatically after N seconds

signal line_presented(sender: String, text: String)
signal choices_presented(labels: Array[String])

const PLAYER := "Me"
const SYSTEM := "System"
## Delay for an incoming message with no #delay tag: grows with length, 1–3 s (guide §6).
const DEFAULT_DELAY_MIN := 1.0
const DEFAULT_DELAY_MAX := 3.0
const DEFAULT_DELAY_PER_CHARACTER := 0.04

@export var view: ChatView
## Send Me: lines without typing them (playtesting the story, not the typing).
@export var skip_typing := false
## Multiplies every #delay. 0 = messages arrive instantly.
@export var delay_scale := 1.0
## Playtest aid: also show hidden #timeout choices and choices whose condition is false.
@export var writer_mode := false


func run_line(line: YarnLine, token: YarnCancellationToken = null) -> void:
	var sender := line.character_name
	var text := line.text_without_character_name
	if sender == PLAYER:
		if not skip_typing:
			view.start_typing(text)
			var state := {"sent": false}
			var on_sent := func(_text: String): state.sent = true
			view.message_sent.connect(on_sent)
			while not state.sent and not _cancelled(token):
				await get_tree().process_frame
			view.message_sent.disconnect(on_sent)
			view.stop_typing()
			if not state.sent:
				return
		view.add_outgoing(text)
	elif sender == SYSTEM or sender == "":
		view.add_notice(text)
	else:
		var delay := _delay_for(line, text) * delay_scale
		if delay > 0.0:
			view.show_typing_indicator(sender)
			await _wait(delay, token)
			view.hide_typing_indicator()
			if _cancelled(token):
				return
		view.add_incoming(sender, text)
	line_presented.emit(sender, text)


func run_options(options: Array[YarnOption], token: YarnCancellationToken = null) -> int:
	var shown: Array = []          # what the view displays
	var option_for_button: Array[int] = []
	var timeout_option := -1
	var timeout_seconds := 0.0
	for i in options.size():
		var seconds := _tag_number(options[i].metadata, "timeout")
		if seconds > 0.0:
			timeout_option = i
			timeout_seconds = seconds
			if writer_mode:
				shown.append({"text": options[i].text_without_character_name,
					"note": "(hidden; picked automatically after %ss)" % _format_seconds(seconds)})
				option_for_button.append(i)
		elif options[i].is_available:
			shown.append({"text": options[i].text_without_character_name})
			option_for_button.append(i)
		elif writer_mode:
			shown.append({"text": options[i].text_without_character_name, "enabled": false,
				"note": "(not offered: its condition is false)"})
			option_for_button.append(i)

	var labels: Array[String] = []
	for entry in shown:
		labels.append(entry.text)
	choices_presented.emit(labels)
	view.show_choices(shown)
	if timeout_option >= 0:
		view.show_timeout(timeout_seconds)

	var state := {"choice": -1}
	var on_choice := func(button: int): state.choice = option_for_button[button]
	view.choice_selected.connect(on_choice)
	var waited := 0.0
	while state.choice < 0 and not _cancelled(token):
		await get_tree().process_frame
		waited += get_process_delta_time()
		if timeout_option >= 0 and waited >= timeout_seconds:
			state.choice = timeout_option
	view.choice_selected.disconnect(on_choice)
	view.clear_choices()
	view.hide_timeout()
	return state.choice


func _delay_for(line: YarnLine, text: String) -> float:
	var tagged := _tag_number(line.metadata, "delay")
	if tagged > 0.0:
		return tagged
	return clampf(DEFAULT_DELAY_MIN + text.length() * DEFAULT_DELAY_PER_CHARACTER,
		DEFAULT_DELAY_MIN, DEFAULT_DELAY_MAX)


## Reads `#name:N` from a line's or option's tags. Returns 0 if absent.
func _tag_number(metadata: Variant, name: String) -> float:
	if metadata == null:
		return 0.0
	for tag in metadata:
		if str(tag).begins_with(name + ":"):
			return str(tag).substr(name.length() + 1).to_float()
	return 0.0


func _format_seconds(seconds: float) -> String:
	return str(int(seconds)) if is_equal_approx(seconds, roundf(seconds)) else str(seconds)


func _wait(seconds: float, token: YarnCancellationToken) -> void:
	var left := seconds
	while left > 0.0 and not _cancelled(token):
		await get_tree().process_frame
		left -= get_process_delta_time()


## Only a real stop ends a wait. "Hurry up" requests are ignored: a typing
## challenge or a choice can't be skipped.
func _cancelled(token: YarnCancellationToken) -> bool:
	return (token != null and token.is_cancelled) or not is_inside_tree()
