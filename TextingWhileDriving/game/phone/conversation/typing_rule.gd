class_name TypingRule
extends RefCounted
## Decides whether what the player typed matches the message they have to send.
##
## Exact match for now (docs/ROADMAP.md, Decisions: typing strictness). Typo-tolerant
## variants for playtests (ignore case, allow N mistakes, ...) belong here, so the
## phone UI never needs to change.


static func matches(target: String, typed: String) -> bool:
	return typed == target


## How many characters at the start of `typed` are correct, for colouring progress.
static func correct_prefix_length(target: String, typed: String) -> int:
	var length := mini(target.length(), typed.length())
	for i in length:
		if target[i] != typed[i]:
			return i
	return length
