class_name ChatView
extends PanelContainer
## One conversation on the phone screen: message bubbles, the typing
## indicator, choice buttons, the reply countdown and the typing challenge.
##
## Knows nothing about Yarn; ChatPresenter drives it. Builds its own child
## nodes, so it can be dropped into any scene (the playtest scene and the
## in-car phone both use it).
##
## ART PLACEHOLDER: the whole look (colours, bubbles, fonts, layout, typing box,
## reply countdown bar) is a functional mock-up made in code, loosely like a
## phone messaging app. The colours and sizes are constants at the top so an
## artist's design can replace them; see docs/ART_PLACEHOLDERS.md.

## The player clicked a choice button (index into the list given to show_choices).
signal choice_selected(index: int)
## The player typed the whole message correctly and pressed Enter.
signal message_sent(text: String)

# Colours, roughly an iPhone Messages look. Change them here to restyle the phone.
const INCOMING_COLOR := Color("e9e9eb")
const OUTGOING_COLOR := Color("0a84ff")
const BACKGROUND_COLOR := Color("ffffff")
const TEXT_DARK := Color("111111")
const TEXT_LIGHT := Color("ffffff")
const MUTED := Color("8e8e93")
## Longest a message bubble gets before the text wraps (pixels). Leaves room
## for the margins on the in-car phone's 304-pixel-wide screen.
const MAX_BUBBLE_WIDTH := 220

# The child nodes, created in _build().
var _header: Label
var _scroll: ScrollContainer
var _messages: VBoxContainer
var _typing_indicator: Control
var _typing_indicator_label: Label
var _choices: VBoxContainer
var _timeout_bar: ProgressBar
var _typing_box: PanelContainer
var _typing_label: RichTextLabel
var _typing_hint: Label

# Typing challenge state: the message to type, what's been typed so far.
var _target := ""
var _typed := ""
var _typing_active := false
# Seconds left on the reply countdown bar.
var _timeout_left := 0.0
# Who sent the last bubble, so a run of messages from one person shows their name once.
var _last_sender := ""


func _ready() -> void:
	_build()


## The name at the top of the screen (who the conversation is with).
func set_title(title: String) -> void:
	_header.text = title


## Empties the screen for a new conversation.
func clear() -> void:
	for child in _messages.get_children():
		if child != _typing_indicator:
			child.queue_free()
	hide_typing_indicator()
	clear_choices()
	hide_timeout()
	stop_typing()
	_last_sender = ""


## A grey bubble on the left, with the sender's name above the first of a run.
func add_incoming(sender: String, text: String) -> void:
	if sender != _last_sender:
		var name_label := _label(sender, MUTED, 12)
		name_label.set_meta("kind", "name")
		_add_message(name_label)
	_last_sender = sender
	_add_message(_bubble(text, INCOMING_COLOR, TEXT_DARK, false))


## A blue bubble on the right: a message the player sent.
func add_outgoing(text: String) -> void:
	_last_sender = ""
	_add_message(_bubble(text, OUTGOING_COLOR, TEXT_LIGHT, true))


## Small centred grey text, for phone events like "Mom left the chat".
func add_notice(text: String) -> void:
	_last_sender = ""
	var label := _label(text, MUTED, 12)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_meta("kind", "notice")
	_add_message(label)


## "Mom is typing…" under the last message, until hide_typing_indicator().
func show_typing_indicator(sender: String) -> void:
	_typing_indicator_label.text = "%s is typing…" % sender
	_typing_indicator.visible = true
	_messages.move_child(_typing_indicator, -1)
	_scroll_to_bottom()


func hide_typing_indicator() -> void:
	_typing_indicator.visible = false


## choices: Array of {text: String, enabled: bool, note: String}. `note` is
## shown small under the text (used by the playtest to explain hidden choices).
func show_choices(choices: Array) -> void:
	clear_choices()
	for i in choices.size():
		var choice: Dictionary = choices[i]
		var button := Button.new()
		button.text = choice.text if choice.get("note", "") == "" else "%s\n%s" % [choice.text, choice.note]
		button.disabled = not choice.get("enabled", true)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.focus_mode = Control.FOCUS_NONE  # keep keyboard free for typing
		var index := i
		button.pressed.connect(func(): choice_selected.emit(index))
		_choices.add_child(button)
	_choices.visible = not choices.is_empty()


## Removes the choice buttons (after one is picked, or when time runs out).
func clear_choices() -> void:
	for child in _choices.get_children():
		child.queue_free()
	_choices.visible = false


## Presses choice `index` as if clicked. Used by tests.
func press_choice(index: int) -> void:
	choice_selected.emit(index)


## The text on each choice button currently shown. Used by tests.
func choice_texts() -> Array[String]:
	var texts: Array[String] = []
	for child in _choices.get_children():
		if not child.is_queued_for_deletion():
			texts.append((child as Button).text)
	return texts


## Shows a bar above the choices that empties over `seconds` (the reply deadline).
## It's only a display: ChatPresenter decides what happens when time runs out.
func show_timeout(seconds: float) -> void:
	_timeout_left = seconds
	_timeout_bar.max_value = seconds
	_timeout_bar.value = seconds
	_timeout_bar.visible = true


func hide_timeout() -> void:
	_timeout_left = 0.0
	_timeout_bar.visible = false


## Starts the typing challenge: the player must type `target` and press Enter.
func start_typing(target: String) -> void:
	_target = target
	_typed = ""
	_typing_active = true
	_typing_box.visible = true
	get_viewport().gui_release_focus()  # make sure keystrokes come here
	_refresh_typing()


## Hides the typing box (the message was sent, or the conversation stopped).
func stop_typing() -> void:
	_typing_active = false
	_typing_box.visible = false
	_target = ""
	_typed = ""


func is_typing() -> bool:
	return _typing_active


## Every visible message, oldest first, as "sender: text" / "Me: text" / "* notice".
## Used by tests to check what the player would see.
func transcript() -> Array[String]:
	var lines: Array[String] = []
	var sender := ""
	for child in _messages.get_children():
		if child == _typing_indicator or child.is_queued_for_deletion():
			continue
		match child.get_meta("kind", ""):
			"name":
				sender = child.text
			"incoming":
				lines.append("%s: %s" % [sender, child.get_meta("text")])
			"outgoing":
				lines.append("Me: %s" % child.get_meta("text"))
			"notice":
				lines.append("* %s" % child.text)
	return lines


# Counts the reply bar down.
func _process(delta: float) -> void:
	if _timeout_bar.visible and _timeout_left > 0.0:
		_timeout_left = maxf(_timeout_left - delta, 0.0)
		_timeout_bar.value = _timeout_left


# Typing: every key press while the typing box is open lands here. Enter sends
# (only if the text matches), Backspace deletes, anything else types a character.
# We read the character the key produced (event.unicode), so Shift, accents and
# keyboard layouts all work. Handled keys are marked handled so they don't also
# drive the car or trigger other actions.
func _input(event: InputEvent) -> void:
	if not _typing_active or not (event is InputEventKey) or not event.pressed:
		return
	if event.is_action("phone_send"):
		if TypingRule.matches(_target, _typed):
			var sent := _target
			stop_typing()
			message_sent.emit(sent)
	elif event.is_action("phone_delete"):
		_typed = _typed.left(-1)
	elif event.unicode >= 32:
		_typed += char(event.unicode)
	else:
		return
	_refresh_typing()
	get_viewport().set_input_as_handled()


# Redraws the typing box: what's typed correctly in dark text, the first mistake
# onwards in red underline, and the rest of the message still to type in grey.
func _refresh_typing() -> void:
	if not _typing_active:
		return
	var correct := TypingRule.correct_prefix_length(_target, _typed)
	var good := _typed.substr(0, correct)
	var bad := _typed.substr(correct)
	var rest := _target.substr(_typed.length()) if _typed.length() < _target.length() else ""
	_typing_label.text = "[color=#%s]%s[/color][color=#ff3b30][u]%s[/u][/color][color=#%s]%s[/color]" % [
		TEXT_DARK.to_html(false), _escape(good), _escape(bad), MUTED.to_html(false), _escape(rest)]
	if TypingRule.matches(_target, _typed):
		_typing_hint.text = "Press Enter to send"
	elif bad != "":
		_typing_hint.text = "Typo. Backspace to fix it"
	else:
		_typing_hint.text = "Type the message"


# The typing box uses BBCode for colours, so a literal "[" in a message must be
# escaped or it would be read as formatting.
func _escape(text: String) -> String:
	return text.replace("[", "[lb]")


# --- building -----------------------------------------------------------------

# Creates the screen's layout, top to bottom: contact name, scrolling messages
# (with the typing indicator kept last), reply countdown bar, choice buttons,
# and the typing box. Built in code so the view works in any scene.
func _build() -> void:
	var background := StyleBoxFlat.new()
	background.bg_color = BACKGROUND_COLOR
	background.set_corner_radius_all(24)
	background.set_content_margin_all(12)
	add_theme_stylebox_override("panel", background)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)

	_header = _label("", TEXT_DARK, 16)
	_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_header)
	column.add_child(HSeparator.new())

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)
	_messages = VBoxContainer.new()
	_messages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_messages.add_theme_constant_override("separation", 4)
	_scroll.add_child(_messages)

	_typing_indicator_label = _label("", MUTED, 12)
	_typing_indicator = _typing_indicator_label
	_typing_indicator.visible = false
	_messages.add_child(_typing_indicator)

	_timeout_bar = ProgressBar.new()
	_timeout_bar.show_percentage = false
	_timeout_bar.custom_minimum_size.y = 4
	_timeout_bar.visible = false
	column.add_child(_timeout_bar)

	_choices = VBoxContainer.new()
	_choices.visible = false
	column.add_child(_choices)

	_typing_box = PanelContainer.new()
	var box_style := StyleBoxFlat.new()
	box_style.bg_color = Color("f2f2f7")
	box_style.set_corner_radius_all(12)
	box_style.set_content_margin_all(8)
	_typing_box.add_theme_stylebox_override("panel", box_style)
	_typing_box.visible = false
	var typing_column := VBoxContainer.new()
	_typing_box.add_child(typing_column)
	_typing_label = RichTextLabel.new()
	_typing_label.bbcode_enabled = true
	_typing_label.fit_content = true
	_typing_label.scroll_active = false
	_typing_label.add_theme_font_size_override("normal_font_size", 16)
	typing_column.add_child(_typing_label)
	_typing_hint = _label("", MUTED, 11)
	typing_column.add_child(_typing_hint)
	column.add_child(_typing_box)


# A wrapping text label in the given colour and size.
func _label(text: String, color: Color, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


# One message bubble. It's a row with an empty spacer on one side, which pushes
# the bubble to the right (outgoing) or left (incoming). The "kind" and "text"
# tags let transcript() read the conversation back.
func _bubble(text: String, color: Color, text_color: Color, outgoing: bool) -> Control:
	var row := HBoxContainer.new()
	row.set_meta("kind", "outgoing" if outgoing else "incoming")
	row.set_meta("text", text)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var bubble := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(16)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	bubble.add_theme_stylebox_override("panel", style)
	var label := _label(text, text_color, 15)
	# Short messages get snug bubbles; long ones wrap at MAX_BUBBLE_WIDTH.
	label.custom_minimum_size.x = mini(MAX_BUBBLE_WIDTH, maxi(24, text.length() * 9))
	bubble.add_child(label)

	if outgoing:
		row.add_child(spacer)
		row.add_child(bubble)
	else:
		row.add_child(bubble)
		row.add_child(spacer)
	return row


# Adds a message below the others, keeping the typing indicator at the bottom.
func _add_message(node: Control) -> void:
	_messages.add_child(node)
	_messages.move_child(_typing_indicator, -1)
	_scroll_to_bottom()


# Scrolls to the newest message. Waits a frame first because the new message's
# size (and so the scroll range) is only known after layout.
func _scroll_to_bottom() -> void:
	await get_tree().process_frame
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)
