class_name SpikePresenter
extends YarnDialoguePresenter
## Records everything a dialogue runner sends it, and picks options with a
## callable, so the spike can assert on what a real phone UI would receive.

var thread_name := ""
## Shared across presenters so parallel threads can be checked for interleaving.
var arrival_log: Array = []
var lines: Array[Dictionary] = []
var option_sets: Array = []
## (options: Array[YarnOption]) -> int
var choose: Callable


func run_line(line: YarnLine, _token: YarnCancellationToken = null) -> void:
	lines.append({
		"character": line.character_name,
		"text": line.text_without_character_name,
		"metadata": line.metadata,
		"msec": Time.get_ticks_msec(),
	})
	arrival_log.append("%s|%s" % [thread_name, line.text_without_character_name])
	await get_tree().process_frame


func run_options(options: Array[YarnOption], _token: YarnCancellationToken = null) -> int:
	var recorded: Array[Dictionary] = []
	for option in options:
		recorded.append({
			"text": option.text_without_character_name,
			"metadata": option.metadata,
			"available": option.is_available,
		})
	option_sets.append(recorded)
	return choose.call(options)
