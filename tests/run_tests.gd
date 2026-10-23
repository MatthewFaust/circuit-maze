extends SceneTree
## Headless test runner (no addons).
##
##   Godot --headless --path <project> --script res://tests/run_tests.gd [-- --filter=<text>]
##
## Runs every method named test_* in every res://tests/test_*.gd suite.
## Exit code: 0 = all passed, 1 = failures, 2 = setup problem.
## After adding or renaming a class_name script, rebuild the class cache first:
##   Godot --headless --path <project> --import

const SUITE_DIR := "res://tests"
## Global classes the suites rely on. If one is missing the class cache is stale.
const REQUIRED_CLASSES := [
	"Tiles", "MazeGrid", "RobotState", "MazeRules", "MazePathing", "MazeWorld",
	"ProgramModel", "ProgramInterpreter", "ProgramParser", "ProgramPrinter",
	"LevelVariant", "LevelData", "LevelLoader", "LevelCatalog", "LevelEvaluator", "ProgressData",
	"ProgressionCatalog",
]


## Counts engine and script errors, which never stop a script on their own:
## a runtime error just aborts the current function and returns null.
class ErrorCounter extends Logger:
	var count := 0
	var _mutex := Mutex.new()

	func _log_error(_function: String, _file: String, _line: int, _code: String,
			_rationale: String, _editor_notify: bool, error_type: int,
			_script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == Logger.ERROR_TYPE_WARNING:
			return
		_mutex.lock()
		count += 1
		_mutex.unlock()


func _initialize() -> void:
	_main.call_deferred()


func _main() -> void:
	var code: int = await _run()
	quit(code)


func _run() -> int:
	var started := Time.get_ticks_msec()
	var missing: Array[String] = []
	var known := {}
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		known[entry["class"]] = true
	for cls: String in REQUIRED_CLASSES:
		if not known.has(cls):
			missing.append(cls)
	if not missing.is_empty():
		printerr("Stale class cache, missing: %s" % ", ".join(missing))
		printerr("Fix: Godot --headless --path <project> --import")
		return 2

	var filter := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--filter="):
			filter = arg.substr("--filter=".length())

	var errors := ErrorCounter.new()
	OS.add_logger(errors)

	var files: Array[String] = []
	for f in DirAccess.get_files_at(SUITE_DIR):
		if f.begins_with("test_") and f.ends_with(".gd"):
			files.append(f)
	files.sort()

	var passed := 0
	var failed := 0
	for file in files:
		var path := SUITE_DIR.path_join(file)
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			printerr("[FAIL] %s: could not load (parse error?)" % file)
			failed += 1
			continue
		var suite: Object = script.new()
		suite.set("tree", self)
		var names: Array[String] = []
		for m: Dictionary in script.get_script_method_list():
			var mname: String = m["name"]
			if mname.begins_with("test_") and not names.has(mname):
				if filter == "" or (file + "::" + mname).contains(filter):
					names.append(mname)
		for mname in names:
			suite.call("_reset")
			var before := errors.count
			await suite.call(mname)
			var problems: Array[String] = []
			problems.assign(suite.get("failures"))
			if errors.count > before:
				problems.append("%d engine/script error(s) logged (see output above)" % (errors.count - before))
			if problems.is_empty():
				passed += 1
			else:
				failed += 1
				printerr("[FAIL] %s::%s" % [file, mname])
				for p in problems:
					printerr("       - " + p)
		if suite.has_method("_cleanup"):
			await suite.call("_cleanup")

	OS.remove_logger(errors)
	var secs := (Time.get_ticks_msec() - started) / 1000.0
	print("%d passed, %d failed in %d suite(s), %.2f s" % [passed, failed, files.size(), secs])
	return 0 if failed == 0 else 1
