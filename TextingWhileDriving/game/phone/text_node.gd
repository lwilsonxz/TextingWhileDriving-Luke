extends Node2D
## The old prototype's text box: one read-only line that phone.gd types into.
## Replaced by ChatView (game/phone/conversation/) once the in-car phone moves
## over to it in roadmap step B2.

## The line of text shown on the phone.
@onready var label = $Container/Label
