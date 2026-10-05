extends SceneTree
## Checks every dialogue file against docs/WRITING_GUIDE.md.
##
## From the repo root:
##   godot --headless --script tools/validate_dialogue.gd
## Options (after `--`):
##   --dialogue <dir>   dialogue folder (default: TextingWhileDriving/dialogue)
##   --hooks <file>     game hooks script (default: TextingWhileDriving/phone/dialogue_hooks.gd)
##   --ysc <path>       Yarn compiler (default: ysc on PATH)
##   --strict           fail on warnings too
##   --quiet            only print problems, no per-file report
## Exits 1 if there are errors (or warnings, with --strict).
## Needs the Yarn compiler: dotnet tool install --global YarnSpinner.Console --version 3.2.2


func _initialize() -> void:
	var repo_root := ProjectSettings.globalize_path(get_script().resource_path).get_base_dir().get_base_dir()
	var options := {
		"dialogue": repo_root.path_join("TextingWhileDriving/dialogue"),
		"hooks": repo_root.path_join("TextingWhileDriving/phone/dialogue_hooks.gd"),
		"ysc": "ysc", "strict": false, "quiet": false,
	}
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		var key := args[i].trim_prefix("--")
		if key in ["strict", "quiet"]:
			options[key] = true
		elif options.has(key) and i + 1 < args.size():
			i += 1
			options[key] = _absolute(args[i]) if key != "ysc" else args[i]
		else:
			printerr("Unknown option: " + args[i])
			quit(2)
			return
		i += 1

	var validator_script: GDScript = load(get_script().resource_path.get_base_dir().path_join("dialogue_validator.gd"))
	if validator_script == null or not validator_script.can_instantiate():
		printerr("Couldn't load tools/dialogue_validator.gd (see the errors above).")
		quit(2)
		return
	var validator = validator_script.new()
	var result: Dictionary = validator.run(options.dialogue, options.hooks, options.ysc)
	var shown_root := _relative_to_cwd(options.dialogue)
	var in_ci := not OS.get_environment("GITHUB_ACTIONS").is_empty()

	var errors := 0
	var warnings := 0
	for issue in result.issues:
		if issue.severity == "error":
			errors += 1
		else:
			warnings += 1
		var where: String = shown_root.path_join(issue.file) if issue.file != "" else shown_root
		print("%s:%d: %s [%s] %s" % [where, issue.line, issue.severity, issue.code, issue.message])
		if in_ci:
			# Shows the problem inline on the pull request.
			print("::%s file=%s,line=%d,title=%s::%s" % [
				issue.severity, where, max(issue.line, 1), issue.code, issue.message.replace("\n", "%0A")])

	if not options.quiet:
		_print_report(result)

	print("")
	if errors == 0 and warnings == 0:
		print("Dialogue OK: %d file(s), no problems." % result.stats.size())
	else:
		print("%d error(s), %d warning(s) in %d file(s)." % [errors, warnings, result.stats.size()])
	quit(1 if errors > 0 or (options.strict and warnings > 0) else 0)


func _print_report(result: Dictionary) -> void:
	if result.stats.is_empty():
		return
	print("")
	print("%-28s %5s %7s %7s %9s %9s %10s   %s" % [
		"File", "Nodes", "Choice", "Choices", "Incoming", "Typed", "Typed", "Typed lines by"])
	print("%-28s %5s %7s %7s %9s %9s %10s   %s" % [
		"", "", "sets", "", "words", "words", "characters", "difficulty (easy/med/hard)"])
	for file in result.stats:
		var s: Dictionary = result.stats[file]
		print("%-28s %5d %7d %7d %9d %9d %10d   %d/%d/%d" % [
			file, s.nodes, s.choice_sets, s.choices, s.npc_words, s.me_words, s.me_characters,
			s.typing_easy, s.typing_medium, s.typing_hard])
	if not result.entry_points.is_empty():
		print("")
		print("Entry points (nothing jumps to these, so the game must start them):")
		print("  " + ", ".join(result.entry_points))


func _absolute(path: String) -> String:
	# Without a project, res:// is the folder godot was started from.
	return path if path.is_absolute_path() else ProjectSettings.globalize_path("res://").path_join(path).simplify_path()


func _relative_to_cwd(path: String) -> String:
	var cwd := ProjectSettings.globalize_path("res://").simplify_path()
	return path.simplify_path().trim_prefix(cwd).trim_prefix("/")
