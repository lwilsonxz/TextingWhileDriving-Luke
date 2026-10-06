extends RefCounted
## Checks dialogue files against the rules in docs/WRITING_GUIDE.md.
##
## Runs the Yarn compiler (ysc) with every warning treated as an error, then
## checks the game's own conventions, which Yarn doesn't know about. Used by
## tools/validate_dialogue.gd (command line / CI) and the validator's tests.
##
## Usage:
##   var validator = load(".../dialogue_validator.gd").new()
##   var result: Dictionary = validator.run(dialogue_dir, hooks_path)
##   result.issues -> Array of {file, line, severity, code, message}
##   result.stats  -> {relative_file: {...counts...}}

const MAX_VISIBLE_CHOICES := 4
const VARIABLES_FILE := "Variables.yarn"
const PLAYER := "Me"
const ALLOWED_TAGS := ["delay", "timeout", "line"]

## Commands built into Yarn or the Yarn Spinner dialogue runner.
const BUILT_IN_COMMANDS := [
	"jump", "detour", "return", "set", "declare", "if", "elseif", "else", "endif",
	"once", "endonce", "wait", "stop", "enum", "case", "endenum", "local",
]

## Functions built into Yarn and the GDScript runtime. ysc doesn't report calls
## to unknown functions, so anything not here or in the hooks file is an error.
## Add to this list if writers need another built-in.
const BUILT_IN_FUNCTIONS := [
	"visited", "visited_count", "random", "random_range", "random_range_float", "dice",
	"round", "round_places", "floor", "ceil", "inc", "dec", "decimal", "int",
	"string", "number", "bool", "format", "format_invariant",
	"abs", "clamp", "lerp", "inverse_lerp", "smoothstep", "pow", "sqrt", "sign",
	"wrap", "mod", "length", "uppercase", "lowercase", "first_letter_caps",
	"plural", "ordinal",
]

## Words that can appear before "(" in an expression without being a function call.
const EXPRESSION_KEYWORDS := [
	"if", "elseif", "and", "or", "not", "xor", "to", "is", "eq", "neq",
	"gt", "lt", "gte", "lte", "set", "declare", "jump", "detour", "once",
]

const EASY_CHARS := "abcdefghijklmnopqrstuvwxyz0123456789 .,'-"
const MEDIUM_SYMBOLS := "?!:;\"()/&@%~^|"
const ESCAPABLE := "#[]{}\\"

var _issues: Array[Dictionary] = []
var _stats := {}
var _functions := {}  # name -> {params: Array[String], returns: String, doc: String}
var _commands := {}   # name -> {params: Array[String], doc: String}
var _titles := {}     # title -> {file, line}
var _references := {}  # title -> true (jumped to, detoured to, or started)
var _node_refs: Array[Dictionary] = []  # {target, file, line} from <<start_thread>>, checked after parsing
var _speakers := {}   # exact name -> {file, line, count}


## Checks every .yarn file under `dialogue_dir`. Steps: read the game hooks,
## run the Yarn compiler, check each file's conventions, then a few
## whole-project checks (node references, name spellings).
func run(dialogue_dir: String, hooks_path: String, ysc := "ysc") -> Dictionary:
	_issues.clear()
	_stats.clear()
	_titles.clear()
	_references.clear()
	_node_refs.clear()
	_speakers.clear()
	dialogue_dir = dialogue_dir.simplify_path()
	if not DirAccess.dir_exists_absolute(dialogue_dir):
		_add("", 0, "error", "setup", "Dialogue folder not found: %s" % dialogue_dir)
		return _result()

	_read_hooks(hooks_path)
	var files := _find_yarn_files(dialogue_dir)
	_compile(dialogue_dir, files, ysc)
	for path in files:
		_check_file(dialogue_dir, path)
	_check_node_references()
	_check_speaker_spellings()
	_drop_duplicate_compiler_issues()
	_issues.sort_custom(func(a, b): return a.file < b.file if a.file != b.file else a.line < b.line)
	return _result()


## Titles nothing jumps to. They have to be started by the game, so writers can
## check this list matches the conversations they expect levels to start.
func entry_points() -> Array[String]:
	var result: Array[String] = []
	for title in _titles:
		if not _references.has(title) and title != "Variables":
			result.append(title)
	result.sort()
	return result


func _result() -> Dictionary:
	return {"issues": _issues, "stats": _stats, "entry_points": entry_points()}


## When our own check already explains a line's problem (e.g. an unescaped
## bracket), drop the compiler's vaguer message about the same line.
func _drop_duplicate_compiler_issues() -> void:
	var explained := {}
	for issue in _issues:
		if issue.severity == "error" and not issue.code.begins_with("compiler"):
			explained["%s:%d" % [issue.file, issue.line]] = true
	_issues = _issues.filter(func(issue): return not (
		issue.code.begins_with("compiler") and explained.has("%s:%d" % [issue.file, issue.line])))


# Records a problem. `code` is a short id (e.g. "missing-me-line") used by the
# tests and shown in brackets; `message` tells the writer how to fix it.
func _add(file: String, line: int, severity: String, code: String, message: String) -> void:
	_issues.append({"file": file, "line": line, "severity": severity, "code": code, "message": message})


# --- hooks ------------------------------------------------------------------

# Finds the game's functions and commands by reading dialogue_hooks.gd as text:
# each `static func _yarn_function_*` / `_yarn_command_*` line, its parameter
# types, and the `##` comment above it (shown to writers in autocomplete).
func _read_hooks(hooks_path: String) -> void:
	_functions.clear()
	_commands.clear()
	if not FileAccess.file_exists(hooks_path):
		_add("", 0, "error", "setup", "Hooks file not found: %s" % hooks_path)
		return
	var lines := FileAccess.get_file_as_string(hooks_path).split("\n")
	var hook := RegEx.create_from_string(
		"^static func _yarn_(function|command)_(\\w+)\\(([^)]*)\\)\\s*(?:->\\s*(\\w+))?")
	var doc: PackedStringArray = []
	for raw in lines:
		var line := raw.strip_edges()
		if line.begins_with("##"):
			doc.append(line.trim_prefix("##").strip_edges())
			continue
		var m := hook.search(line)
		if m != null:
			var params: Array[String] = []
			for param in m.get_string(3).split(",", false):
				var parts := param.split(":")
				params.append(_yarn_type(parts[1].strip_edges() if parts.size() > 1 else ""))
			var entry := {"params": params, "returns": _yarn_type(m.get_string(4)), "doc": " ".join(doc)}
			if m.get_string(1) == "function":
				_functions[m.get_string(2)] = entry
			else:
				_commands[m.get_string(2)] = entry
		if not line.begins_with("##"):
			doc.clear()


# GDScript type name -> Yarn's type name.
func _yarn_type(gd_type: String) -> String:
	match gd_type:
		"bool": return "bool"
		"int", "float": return "number"
		"String", "StringName": return "string"
		"void", "": return ""
		_: return "any"


# The hooks in the .ysls.json format the Yarn compiler reads, so it knows each
# function's argument and return types.
func _definitions_json() -> String:
	var functions := []
	for name in _functions:
		var params := []
		for i in _functions[name].params.size():
			params.append({"Name": "arg%d" % i, "Type": _functions[name].params[i]})
		functions.append({
			"YarnName": name, "DefinitionName": "_yarn_function_" + name,
			"Documentation": _functions[name].doc, "FileName": "dialogue_hooks.gd",
			"Language": "gdscript", "Parameters": params,
			"ReturnType": _functions[name].returns if _functions[name].returns != "" else "any",
		})
	var commands := []
	for name in _commands:
		var params := []
		for i in _commands[name].params.size():
			params.append({"name": "arg%d" % i, "type": _commands[name].params[i], "isParamsArray": false})
		commands.append({
			"yarnName": name, "definitionName": "_yarn_command_" + name,
			"documentation": _commands[name].doc, "fileName": "dialogue_hooks.gd",
			"language": "gdscript", "async": false, "parameters": params,
		})
	return JSON.stringify({"Functions": functions, "commands": commands, "version": 2}, "  ")


# --- compiler ---------------------------------------------------------------

# Every .yarn file under `root`, sorted so reports are stable.
func _find_yarn_files(root: String) -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(root)
	if dir == null:
		return result
	for sub in dir.get_directories():
		if not sub.begins_with("."):
			result.append_array(_find_yarn_files(root.path_join(sub)))
	for file in dir.get_files():
		if file.get_extension() == "yarn":
			result.append(root.path_join(file))
	result.sort()
	return result


## Copies the dialogue into a temp folder with a definitions file generated from
## the hooks, so the compiler knows the hooks' types without the Godot plugin.
func _compile(dialogue_dir: String, files: Array[String], ysc: String) -> void:
	var temp := OS.get_temp_dir().path_join("validate_dialogue_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(temp.path_join("out"))
	for path in files:
		var target := temp.path_join(_relative(dialogue_dir, path))
		DirAccess.make_dir_recursive_absolute(target.get_base_dir())
		DirAccess.copy_absolute(path, target)
	var project := FileAccess.open(temp.path_join("Validate.yarnproject"), FileAccess.WRITE)
	project.store_string(JSON.stringify({
		"projectFileVersion": 4, "sourceFiles": ["**/*.yarn"], "baseLanguage": "en",
		"definitions": "Validate.ysls.json"}))
	project.close()
	var definitions := FileAccess.open(temp.path_join("Validate.ysls.json"), FileAccess.WRITE)
	definitions.store_string(_definitions_json())
	definitions.close()

	if OS.get_environment("DOTNET_ROLL_FORWARD").is_empty():
		# ysc 3.2.2 targets .NET 9; this lets it run when only a newer .NET is installed.
		OS.set_environment("DOTNET_ROLL_FORWARD", "Major")
	var output := []
	var exit_code := OS.execute(ysc, ["compile", temp.path_join("Validate.yarnproject"),
		"-o", temp.path_join("out")], output, true)
	var joined := "\n".join(output)
	# -1: couldn't start; 127: shell "command not found"; 9009: Windows "is not recognized".
	var not_installed := exit_code in [-1, 127, 9009]
	if not_installed:
		_add("", 0, "error", "setup", "Couldn't run the Yarn compiler '%s'. Install it with: " % ysc
			+ "dotnet tool install --global YarnSpinner.Console --version 3.2.2")
		_remove_dir(temp)
		return

	var diagnostic := RegEx.create_from_string("(ERROR|WARNING): (.+?\\.yarn): (\\d+):(\\d+) (.*)$")
	for line in joined.split("\n"):
		var m := diagnostic.search(line)
		if m == null:
			continue
		var file := _relative(temp, m.get_string(2))
		var level := "warning" if m.get_string(1) == "WARNING" else "error"
		var message := m.get_string(5)
		# Yarn only warns about real mistakes (missing jump targets, undeclared
		# variables), so its warnings count as errors. Empty nodes are harmless.
		var is_empty_node := message.contains("is empty and will not be included")
		if is_empty_node and file == VARIABLES_FILE:
			continue  # a fresh project has no variables yet
		var severity := "warning" if is_empty_node else "error"
		_add(file, m.get_string(3).to_int() + 1, severity, "compiler-" + level, message)
	if exit_code != 0 and not _issues.any(func(i): return i.code.begins_with("compiler")):
		_add("", 0, "error", "compiler-error", "The Yarn compiler failed:\n" + "\n".join(output))
	_remove_dir(temp)


# Deletes a folder and everything in it (the compiler's temp copy).
func _remove_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_remove_dir(path.path_join(sub))
	for file in dir.get_files():
		dir.remove(file)
	DirAccess.remove_absolute(path)


# "/repo/TextingWhileDriving/dialogue/L1/Mom.yarn" -> "L1/Mom.yarn"
func _relative(root: String, path: String) -> String:
	return path.simplify_path().trim_prefix(root.simplify_path()).trim_prefix("/")


# --- conventions --------------------------------------------------------------

# Checks one file line by line. Yarn files are a series of nodes: header lines
# (`title: ...`), then `---`, the body, and `===`. In the body we classify each
# line as a command (`<<...>>`), a choice (`-> ...`) or a message (`Name: ...`).
#
# Choices are tracked by indentation, like Yarn itself: a run of `->` lines at
# the same indent is one "choice set", and the more-indented lines under a choice
# are its body. `groups` holds the choice sets still open and `choices` the
# choices still open; when a line is less indented, those end and get checked
# (e.g. "did this choice have a Me: line?").
func _check_file(dialogue_dir: String, path: String) -> void:
	var file := _relative(dialogue_dir, path)
	var is_variables_file := file == VARIABLES_FILE
	var folder := file.get_base_dir()
	var thread := file.get_file().get_basename()
	var stats := {"nodes": 0, "choice_sets": 0, "choices": 0, "npc_words": 0,
		"me_words": 0, "me_characters": 0, "typing_easy": 0, "typing_medium": 0, "typing_hard": 0}
	_stats[file] = stats

	if not is_variables_file and not RegEx.create_from_string("^L[0-9]+$").search(folder):
		_add(file, 1, "warning", "file-location",
			"Dialogue files go in a level folder, e.g. L1/%s. Only %s belongs at the top." % [file.get_file(), VARIABLES_FILE])

	var lines := FileAccess.get_file_as_string(path).split("\n")
	var in_body := false
	var title := ""
	var groups: Array[Dictionary] = []   # open choice sets: {indent, choices: Array}
	var choices: Array[Dictionary] = []  # open choices: {indent, line, label, me_lines, timeout}

	for index in lines.size():
		var number := index + 1
		var raw := lines[index].replace("\r", "")
		# Header lines, before `---`.
		if not in_body:
			var header := raw.strip_edges()
			if header.begins_with("title:"):
				title = header.trim_prefix("title:").strip_edges()
				_check_title(file, number, title, thread, folder, is_variables_file)
			elif header == "---":
				in_body = true
				stats.nodes += 1
			continue

		if raw.strip_edges() == "===":
			_close_groups(file, groups, choices, -1)
			in_body = false
			title = ""
			continue

		# Checked before stripping comments, because `//` itself is the problem.
		if _find_unescaped(raw, "://") != -1:
			_add(file, number, "error", "unescaped-comment",
				"`//` starts a comment, so everything after it is dropped. Write `\\/\\/` (e.g. `http:\\/\\/`).")
		var code := _strip_comment(raw)
		if code.strip_edges().is_empty():
			continue
		var indent := _indent_width(code)
		var text := code.strip_edges()
		var is_choice := text.begins_with("->")

		# Close choices and choice sets that this line is outside of.
		while not choices.is_empty() and choices.back().indent >= indent:
			choices.pop_back()
		_close_groups(file, groups, choices, indent, is_choice)

		if text.begins_with("<<"):
			_check_command(file, number, text, is_variables_file)
			continue

		if is_variables_file:
			_add(file, number, "warning", "variables-file-content",
				"%s should only contain <<declare>> lines." % VARIABLES_FILE)

		var parts: Dictionary = _split_line(text.trim_prefix("->").trim_prefix("=>").strip_edges())
		_check_expressions(file, number, parts.condition, true)
		_check_expressions(file, number, parts.text, false)

		if is_choice:
			var timeout := _check_tags(file, number, parts.tags, "choice")
			if groups.is_empty() or groups.back().indent != indent:
				groups.append({"indent": indent, "choices": [], "line": number})
				stats.choice_sets += 1
			var choice := {"indent": indent, "line": number, "label": parts.text, "me_lines": 0, "timeout": timeout}
			groups.back().choices.append(choice)
			choices.append(choice)
			stats.choices += 1
			continue

		# A message: everything before the first colon is the sender.
		var colon: int = _find_unescaped(parts.text, ":")
		if colon <= 0:
			_add(file, number, "error", "missing-sender",
				"Every message needs a sender, like `Mom: ...` or `Me: ...`.")
			continue
		var speaker: String = parts.text.substr(0, colon).strip_edges()
		var message: String = parts.text.substr(colon + 1).strip_edges()
		if speaker.begins_with("\"") or speaker.ends_with("\""):
			_add(file, number, "error", "quoted-sender",
				"Don't put quotes around names: write `%s: ...`." % speaker.replace("\"", ""))
		else:
			_note_speaker(file, number, speaker)
		if _find_unescaped(message, "[") != -1 or _find_unescaped(message, "]") != -1:
			_add(file, number, "error", "unescaped-bracket",
				"Square brackets are formatting markup and scramble the message. Write `\\[` and `\\]`.")

		var role := "me" if speaker == PLAYER else "npc"
		_check_tags(file, number, parts.tags, role)
		var words: int = message.split(" ", false).size()
		if role == "me":
			stats.me_words += words
			var typed := _unescape(message)
			stats.me_characters += typed.length()
			stats["typing_" + _typing_tier(typed)] += 1
			# A Me: line indented under a choice counts as that choice's typed text.
			if not choices.is_empty() and choices.back().indent < indent:
				choices.back().me_lines += 1
		else:
			stats.npc_words += words

	if in_body:
		_add(file, lines.size(), "error", "unterminated-node", "The last node is missing its closing `===`.")
	_close_groups(file, groups, choices, -1)


# Node titles must be <Thread>_<Level>_<Beat> and match the file name and level
# folder, e.g. L1/Mom.yarn holds Mom_L1_*.
func _check_title(file: String, line: int, title: String, thread: String, folder: String, is_variables_file: bool) -> void:
	_titles[title] = {"file": file, "line": line}
	if is_variables_file:
		return
	var m := RegEx.create_from_string("^([A-Za-z0-9]+)_(L[0-9]+)_([A-Za-z0-9_]+)$").search(title)
	if m == null:
		_add(file, line, "error", "title-format",
			"Node titles look like <Thread>_<Level>_<Beat>, e.g. %s_%s_Start (letters, digits and _ only)." % [thread, folder if folder != "" else "L1"])
		return
	if m.get_string(1) != thread:
		_add(file, line, "error", "title-thread",
			"Nodes in %s.yarn should start with `%s_` (this one starts with `%s_`)." % [thread, thread, m.get_string(1)])
	if RegEx.create_from_string("^L[0-9]+$").search(folder) and m.get_string(2) != folder:
		_add(file, line, "error", "title-level",
			"This file is in %s/, so its node titles should say `_%s_` (this one says `_%s_`)." % [folder, folder, m.get_string(2)])


# A `<<command ...>>` line: is it a known command, is <<declare>> in the right
# file, and which nodes does it point to (for the entry-point list).
func _check_command(file: String, line: int, text: String, is_variables_file: bool) -> void:
	var inner := text.trim_prefix("<<")
	var end := inner.find(">>")
	if end != -1:
		inner = inner.substr(0, end)
	var words := inner.strip_edges().split(" ", false)
	if words.is_empty():
		return
	var name := words[0]
	if name == "declare" and not is_variables_file:
		_add(file, line, "error", "declare-outside-variables",
			"Declare variables in %s, not here, so every story variable is in one place." % VARIABLES_FILE)
	if name in ["jump", "detour"] and words.size() > 1:
		_references[words[1]] = true
	if name == "start_thread" and words.size() > 2:
		_references[words[2]] = true
		_node_refs.append({"target": words[2], "file": file, "line": line})
	if not (name in BUILT_IN_COMMANDS or _commands.has(name)):
		_add(file, line, "error", "unknown-command",
			"Unknown command <<%s>>. Use one from docs/WRITING_GUIDE.md §8, or ask a programmer to add it." % name)
	if name in ["if", "elseif", "set", "declare"] or _commands.has(name):
		_check_expressions(file, line, inner.substr(name.length()), true)


## Flags calls to functions that are neither built in nor game hooks. In message
## text only {...} is an expression; plain words like "lol(" aren't calls.
func _check_expressions(file: String, line: int, text: String, whole_is_expression: bool) -> void:
	if text.is_empty():
		return
	var without_strings := RegEx.create_from_string("\"(?:[^\"\\\\]|\\\\.)*\"").sub(text, "\"\"", true)
	for m in RegEx.create_from_string("\\b([A-Za-z_][A-Za-z0-9_]*)\\s*\\(").search_all(without_strings):
		var name := m.get_string(1)
		if name in EXPRESSION_KEYWORDS or name in BUILT_IN_FUNCTIONS or _functions.has(name):
			continue
		if not whole_is_expression and not _inside_braces(without_strings, m.get_start()):
			continue
		_add(file, line, "error", "unknown-function",
			"Unknown function %s(). Use one from docs/WRITING_GUIDE.md §8, or ask a programmer to add it." % name)


# Is `position` inside a {...} interpolation?
func _inside_braces(text: String, position: int) -> bool:
	var before := text.substr(0, position)
	return before.rfind("{") > before.rfind("}")


## Returns the timeout in seconds if this is a timeout choice, else -1.
func _check_tags(file: String, line: int, tags: PackedStringArray, role: String) -> float:
	var timeout := -1.0
	for tag in tags:
		var name := tag.get_slice(":", 0)
		var value := tag.substr(name.length() + 1) if tag.contains(":") else ""
		if not name in ALLOWED_TAGS:
			_add(file, line, "error", "unknown-tag",
				"Unknown tag #%s. Allowed: #delay:N, #timeout:N. If `#` is meant as text, write `\\#`." % tag)
			continue
		if name in ["delay", "timeout"] and (not value.is_valid_float() or value.to_float() <= 0.0):
			_add(file, line, "error", "bad-tag-value", "#%s needs a number of seconds above 0, like #%s:3." % [name, name])
			continue
		if name == "timeout":
			if role != "choice":
				_add(file, line, "error", "tag-placement", "#timeout goes on a choice (`-> (no reply) #timeout:15`), not a message.")
			else:
				timeout = value.to_float()
		if name == "delay" and role != "npc":
			_add(file, line, "warning", "tag-placement",
				"#delay only affects incoming messages; it does nothing on %s." % ("a choice" if role == "choice" else "a Me: line"))
	return timeout


## Closes choice sets deeper than `indent` (or at `indent` when the line isn't
## another choice in the same set), checking each set as it closes.
func _close_groups(file: String, groups: Array[Dictionary], choices: Array[Dictionary], indent: int, is_choice := false) -> void:
	while not groups.is_empty():
		var top: Dictionary = groups.back()
		if indent >= 0 and (top.indent < indent or (top.indent == indent and is_choice)):
			return
		groups.pop_back()
		_check_choice_set(file, top)
		if indent < 0:
			choices.clear()


# Rules for one set of choices, checked when the set ends.
func _check_choice_set(file: String, group: Dictionary) -> void:
	var visible := 0
	var timeouts := 0
	for choice in group.choices:
		if choice.timeout > 0.0:
			timeouts += 1
		else:
			visible += 1
			if choice.me_lines == 0:
				_add(file, choice.line, "error", "missing-me-line",
					"Choice \"%s\" needs at least one `Me:` line underneath: the text the player types." % choice.label)
	if timeouts > 1:
		_add(file, group.line, "error", "multiple-timeouts", "A set of choices can have only one #timeout choice.")
	if visible == 0:
		_add(file, group.line, "error", "no-visible-choices", "This set of choices has only a #timeout choice; add at least one choice the player can pick.")
	if visible > MAX_VISIBLE_CHOICES:
		_add(file, group.line, "error", "too-many-choices",
			"%d visible choices; the limit is %d." % [visible, MAX_VISIBLE_CHOICES])


# <<start_thread>> targets can only be checked once every file has been read.
func _check_node_references() -> void:
	for ref in _node_refs:
		if not _titles.has(ref.target):
			_add(ref.file, ref.line, "error", "unknown-node", "<<start_thread>> names a node that doesn't exist: %s" % ref.target)


# Remembers each sender name and where it first appears (for the spelling check).
func _note_speaker(file: String, line: int, speaker: String) -> void:
	if not _speakers.has(speaker):
		_speakers[speaker] = {"file": file, "line": line, "count": 0}
	_speakers[speaker].count += 1


## Warns when the same person seems to be spelled two ways ("John Doe" / "john doe" / "JohnDoe").
func _check_speaker_spellings() -> void:
	var by_key := {}
	for speaker in _speakers:
		var key := RegEx.create_from_string("[^a-z0-9]").sub(speaker.to_lower(), "", true)
		if not by_key.has(key):
			by_key[key] = []
		by_key[key].append(speaker)
	for key in by_key:
		var spellings: Array = by_key[key]
		if spellings.size() < 2:
			continue
		spellings.sort_custom(func(a, b): return _speakers[a].count > _speakers[b].count)
		for rarer in spellings.slice(1):
			var where: Dictionary = _speakers[rarer]
			_add(where.file, where.line, "warning", "speaker-spelling",
				"\"%s\" looks like a different spelling of \"%s\". Sender names must match exactly." % [rarer, spellings[0]])


# --- text helpers -------------------------------------------------------------

## Splits a line into text, a trailing <<if ...>> condition, and #tags.
func _split_line(text: String) -> Dictionary:
	var tags := PackedStringArray()
	var tag_start := _find_unescaped(text, "#")
	if tag_start != -1:
		for tag in text.substr(tag_start).split(" ", false):
			tags.append(tag.trim_prefix("#"))
		text = text.substr(0, tag_start).strip_edges()
	var condition := ""
	var start := text.rfind("<<if ")
	if start != -1 and text.ends_with(">>"):
		condition = text.substr(start)
		text = text.substr(0, start).strip_edges()
	return {"text": text, "condition": condition, "tags": tags}


# Like String.find(), but skips anything escaped with a backslash, so `\#` and
# `\[` aren't mistaken for a tag or markup.
func _find_unescaped(text: String, needle: String, from := 0) -> int:
	var i := from
	while i <= text.length() - needle.length():
		if text[i] == "\\":
			i += 2
			continue
		if text.substr(i, needle.length()) == needle:
			return i
		i += 1
	return -1


# Removes a `// comment` from the end of a line (Yarn ignores those).
func _strip_comment(line: String) -> String:
	var comment := _find_unescaped(line, "//")
	return line if comment == -1 else line.substr(0, comment)


# How far a line is indented, counting a tab as 4 spaces.
func _indent_width(line: String) -> int:
	var width := 0
	for c in line:
		if c == " ":
			width += 1
		elif c == "\t":
			width += 4
		else:
			break
	return width


# The text as the player sees it: `\#` becomes `#`, and so on.
func _unescape(text: String) -> String:
	var result := ""
	var i := 0
	while i < text.length():
		if text[i] == "\\" and i + 1 < text.length():
			result += text[i + 1]
			i += 2
		else:
			result += text[i]
			i += 1
	return result


## How hard a Me: line is to type (docs/WRITING_GUIDE.md §5).
func _typing_tier(text: String) -> String:
	var tier := "easy"
	for c in text:
		if c.unicode_at(0) > 127 or c in ESCAPABLE:
			return "hard"
	if text.contains("//"):
		return "hard"
	for c in text:
		if not c in EASY_CHARS:
			tier = "medium"
	if RegEx.create_from_string("[A-Za-z][0-9]|[0-9][A-Za-z]").search(text):
		tier = "medium"
	return tier
