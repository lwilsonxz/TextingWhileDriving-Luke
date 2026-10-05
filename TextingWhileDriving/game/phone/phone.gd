extends Node3D
## The phone inside the car (game/phone/phone.tscn).
##
## How it works: the phone's screen is a 2D scene drawn into a SubViewport, and
## that drawing is used as the texture of a flat quad (ViewportQuad) in the car,
## so 2D UI appears on a 3D object.
##
## NOTE: the typing below is the original 2024 prototype: type "SOME DUMB
## BULLSHIT" to win. It reads raw keys, so it can only type capital letters and
## turns most punctuation into words. Roadmap step B2 replaces it with ChatView
## and the dialogue system (see game/phone/conversation/).

## The prototype's text line on the phone screen.
@onready var text = $SubViewport/PhoneScreen/Control/TextNode


func _ready():
	# Draw the screen once, then only when it changes.
	var viewport = $SubViewport
	$SubViewport.set_clear_mode(SubViewport.CLEAR_MODE_ONCE)

	# Show what the SubViewport draws on the quad in the car.
	$ViewportQuad.material_override.albedo_texture = viewport.get_texture()


## Prototype win condition: go to the victory screen.
func you_win():
	print("You Win")
	get_tree().change_scene_to_file("res://game/ui/victory_screen.tscn")


func _unhandled_input(event):
	if event is InputEventKey and event.pressed == true:
		print(event)
		# Escape quits the game.
		if event.pressed and event.keycode == KEY_ESCAPE:
			get_tree().quit()

		match(event.keycode):
			KEY_SPACE:
				text.label.text += " "
			KEY_BACKSPACE:
				print(text.label.text)
				text.label.text = text.label.text.substr(0, text.label.text.length() - 1)
			# These keys are used for other things (or were), so they don't type.
			KEY_APOSTROPHE:
				pass
			KEY_1:
				pass
			KEY_2:
				pass
			KEY_3:
				pass
			KEY_4:
				pass
			KEY_5:
				pass
			KEY_LEFT:
				pass
			KEY_RIGHT:
				pass
			KEY_UP:
				pass
			KEY_DOWN:
				pass
			_:
				# Any other key types its name, e.g. "A" (always capital) or "Comma".
				text.label.text += OS.get_keycode_string(event.key_label)

	if "SOME DUMB BULLSHIT" == $SubViewport/PhoneScreen/Control/TextNode.label.text:
		you_win()
