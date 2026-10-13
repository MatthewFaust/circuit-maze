extends SceneTree
## Prints how every program in a level file performs, to set pars and debug maps.
##
##   Godot --headless --path <project> --script res://tools/level_report.gd [-- --level=4-2]

func _initialize() -> void:
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--level="):
			only = arg.substr("--level=".length())
	var cat := LevelCatalog.load_from(LevelCatalog.DEFAULT_PATH)
	for e in cat.errors:
		printerr(e)
	for id in cat.order:
		if only != "" and id != only:
			continue
		var level := cat.get_level(id)
		print("\n== %s %s  (limit %d, par %d blocks / %d stamina)" % [id, level.title,
				level.block_limit, level.par_blocks, level.par_stamina])
		_report(level, "solution", level.solution_text)
		for alt in level.alt_solutions:
			_report(level, "alt: " + str(alt["name"]), alt["text"])
		for anti in level.anti_solutions:
			_report(level, "anti: " + str(anti["name"]), anti["text"])
	quit(0)


func _report(level: LevelData, label: String, text: String) -> void:
	var r := ProgramParser.parse(text)
	if not bool(r["ok"]):
		print("  %-34s PARSE ERROR %s" % [label, str(r["errors"])])
		return
	var p: Dictionary = r["program"]
	var errs := LevelEvaluator.static_check(level, p)
	var blocks := ProgramModel.count_blocks(p)
	if not errs.is_empty():
		print("  %-34s %2d blocks  NOT ALLOWED: %s" % [label, blocks, "; ".join(errs)])
		return
	var parts := PackedStringArray()
	var total := 0
	var solved := true
	for i in level.variants.size():
		var run := LevelEvaluator.run_variant(level, i, p)
		total += int(run["stamina_spent"])
		solved = solved and bool(run["won"])
		var extra := ""
		if int(run["peak_call_depth"]) > 0:
			extra = " d%d" % int(run["peak_call_depth"])
		parts.append(("won %d" % int(run["stamina_spent"]) if bool(run["won"])
				else "%s %d" % [run["fail_code"], int(run["stamina_spent"])]) + " hp%d" % int(run["hp"]) + extra)
	print("  %-34s %2d blocks  %s  total %d %s" % [label, blocks, " | ".join(parts), total,
			"SOLVED" if solved else "fails"])
