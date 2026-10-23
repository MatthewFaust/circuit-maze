extends "res://tests/suite_base.gd"
## Every level must be solvable AND must force the concept it teaches:
## the reference solution earns 3 stars, alt solutions escape, anti-solutions
## fail, a hard-coded replay of one map's moves fails, and so on.

const EXPECTED_LEVELS := 26
const EXPECTED_BOSSES := 4

var _catalog: LevelCatalog


func _levels() -> Array[LevelData]:
	if _catalog == null:
		_catalog = LevelCatalog.load_from(LevelCatalog.DEFAULT_PATH)
	var out: Array[LevelData] = []
	for id in _catalog.order:
		out.append(_catalog.get_level(id))
	return out


func _program(level: LevelData, text: String, what: String) -> Dictionary:
	var r := ProgramParser.parse(text)
	if not check(bool(r["ok"]), "%s %s doesn't parse: %s" % [level.id, what, str(r["errors"])]):
		return {}
	return r["program"]


func _describe(ev: Dictionary) -> String:
	var parts := PackedStringArray()
	for v: Dictionary in ev["variants"]:
		parts.append("%s %d" % ["won" if bool(v["won"]) else str(v["fail_code"]), int(v["stamina_spent"])])
	return "[%s] total %d, %d blocks" % [", ".join(parts), int(ev["stamina_total"]), int(ev["blocks"])]


func test_catalog_loads() -> void:
	var levels := _levels()
	check(_catalog.errors.is_empty(), "catalog errors:\n" + "\n".join(_catalog.errors))
	check_eq(levels.size(), EXPECTED_LEVELS, "level count")
	check_eq(_catalog.chapters.size(), 4, "chapters")
	var bosses := levels.filter(func(l: LevelData) -> bool: return l.is_boss())
	check_eq(bosses.size(), EXPECTED_BOSSES, "boss stages")
	for ch: Dictionary in _catalog.chapters:
		var ids: PackedStringArray = ch["level_ids"]
		check(_catalog.get_level(ids[ids.size() - 1]).is_boss(), "chapter %d ends with its boss" % int(ch["id"]))
	check_eq(_catalog.max_stars(), (EXPECTED_LEVELS - EXPECTED_BOSSES) * 3, "stars come from regular stages")


func test_maps_are_valid_and_solvable() -> void:
	for level in _levels():
		var cut_allowed := level.allowed_blocks.has("cut") or level.allowed_blocks.has("scan_weighted")
		for v in level.variants:
			var exit_ok := false
			var goals: Array[Vector2i] = v.grid.find_all(Tiles.EXIT)
			goals.append_array(v.boss_cells)
			for e in goals:
				if MazePathing.reachable(v.grid, v.start, e, cut_allowed):
					exit_ok = true
			check(exit_ok, "%s %s: exit (or boss) unreachable" % [level.id, v.name])
			check(v.stamina > 0, "%s %s: no stamina" % [level.id, v.name])
			if level.chapter == 4:
				var w := v.make_world(level)
				check(w.sense("path_ahead") or w.sense("path_left") or w.sense("path_right"),
						"%s %s: in chapter 4 the start needs an open tile ahead, left or right" % [level.id, v.name])


func test_reference_solutions_earn_three_stars() -> void:
	for level in _levels():
		var p := _program(level, level.solution_text, "solution")
		if p.is_empty():
			continue
		var ev := LevelEvaluator.evaluate(level, p)
		if not check(bool(ev["valid"]), "%s solution is not allowed here: %s" % [level.id, str(ev["errors"])]):
			continue
		check(bool(ev["solved"]), "%s solution fails: %s" % [level.id, _describe(ev)])
		if level.is_boss():
			# Boss stages award no stars; the solution must win with the minimum gear.
			check_eq(ev["star_count"], 1, "%s records only the win" % level.id)
			continue
		check_eq(ev["star_count"], 3, "%s solution stars %s (par %d stamina / %d blocks)"
				% [level.id, _describe(ev), level.par_stamina, level.par_blocks])
		if level.par_stamina > 0 and int(ev["stamina_total"]) * 5 < level.par_stamina * 4:
			print("  WARN %s: stamina par %d is loose (solution uses %d)" % [level.id, level.par_stamina, int(ev["stamina_total"])])


## Bosses are beatable with the armor the player is given and no weapon, and
## better gear rescues the sloppy programs that minimum gear can't.
func test_boss_gear() -> void:
	var prog := ProgressionCatalog.get_default()
	check(prog.errors.is_empty(), "progression data: %s" % str(prog.errors))
	for level in _levels():
		if not level.is_boss():
			continue
		var gear: Dictionary = level.boss["min_gear"]
		check(str(gear["weapon"]) == "", "%s must not need a weapon" % level.id)
		var armor := prog.armor_by_id(str(gear["armor"]))
		if check(not armor.is_empty(), "%s min armor exists" % level.id):
			var i := _catalog.order.find(str(armor["unlock_level"]))
			check(i >= 0 and i < _catalog.order.find(level.id), "%s: its armor unlocks before the boss" % level.id)
		check(prog.skin_by_id(str(level.boss["skin"])).get("boss_level", "") == level.id,
				"%s unlocks skin %s" % [level.id, level.boss["skin"]])
		var rescued := false
		for anti in level.anti_solutions:
			var pw: Dictionary = anti["passes_with"]
			if pw.is_empty():
				continue
			rescued = true
			var p := _program(level, anti["text"], "anti '%s'" % anti["name"])
			var ev := LevelEvaluator.evaluate(level, p, prog.loadout(str(pw.get("armor", "")), str(pw.get("weapon", ""))))
			check(bool(ev["solved"]), "%s anti '%s' should win with %s: %s" % [level.id, anti["name"], str(pw), _describe(ev)])
		check(rescued, "%s shows that better gear helps (an anti-solution with passes_with)" % level.id)


func test_alt_solutions_escape() -> void:
	for level in _levels():
		for alt in level.alt_solutions:
			var p := _program(level, alt["text"], "alt '%s'" % alt["name"])
			if p.is_empty():
				continue
			var ev := LevelEvaluator.evaluate(level, p)
			check(bool(ev["valid"]) and bool(ev["solved"]),
					"%s alt '%s' should escape: %s %s" % [level.id, alt["name"], str(ev["errors"]), _describe(ev)])


func test_anti_solutions_fail() -> void:
	for level in _levels():
		for anti in level.anti_solutions:
			var p := _program(level, anti["text"], "anti '%s'" % anti["name"])
			if p.is_empty():
				continue
			var ev := LevelEvaluator.evaluate(level, p)
			if not bool(ev["valid"]):
				continue
			check(not bool(ev["solved"]), "%s anti '%s' should fail but solves: %s"
					% [level.id, anti["name"], _describe(ev)])
			var code: String = anti["expect_fail_code"]
			if code != "":
				var seen := false
				for v: Dictionary in ev["variants"]:
					if v["fail_code"] == code:
						seen = true
				check(seen, "%s anti '%s' should fail with %s: %s" % [level.id, anti["name"], code, _describe(ev)])


func test_hardcoded_replays_fail() -> void:
	for level in _levels():
		if not level.hardcode_must_fail:
			continue
		var p := _program(level, level.solution_text, "solution")
		if p.is_empty():
			continue
		for i in level.variants.size():
			var run := LevelEvaluator.run_variant(level, i, p)
			var flat := ProgramModel.from_actions(run["trace"])
			var ev := LevelEvaluator.evaluate(level, flat)
			check(not (bool(ev["valid"]) and bool(ev["solved"])),
					"%s: replaying %s's %d moves solves the level, so it doesn't force a general program"
					% [level.id, level.variants[i].name, (run["trace"] as PackedStringArray).size()])


func test_inlined_functions_exceed_limit() -> void:
	for level in _levels():
		if not level.inline_must_fail:
			continue
		var p := _program(level, level.solution_text, "solution")
		if p.is_empty():
			continue
		var inlined := ProgramModel.inline_calls(p)
		if inlined.is_empty():
			continue
		check(level.block_limit > 0 and ProgramModel.count_blocks(inlined) > level.block_limit,
				"%s: the solution without functions uses %d blocks, within the limit %d"
				% [level.id, ProgramModel.count_blocks(inlined), level.block_limit])


func test_solutions_round_trip_and_are_deterministic() -> void:
	for level in _levels():
		var p := _program(level, level.solution_text, "solution")
		if p.is_empty():
			continue
		var again := ProgramParser.parse(ProgramPrinter.to_text(p))
		check(bool(again["ok"]) and ProgramModel.canonical(again["program"]) == ProgramModel.canonical(p),
				"%s solution doesn't survive print + parse" % level.id)
		var a := LevelEvaluator.evaluate(level, p)
		var b := LevelEvaluator.evaluate(level, p)
		check_eq(a["stamina_total"], b["stamina_total"], "%s determinism" % level.id)


func test_starters_and_fog_rules() -> void:
	for level in _levels():
		if level.starter_text.strip_edges() != "":
			var p := _program(level, level.starter_text, "starter")
			if not p.is_empty():
				var errs := LevelEvaluator.static_check(level, p)
				check(errs.is_empty(), "%s starter uses blocks that aren't allowed: %s" % [level.id, str(errs)])
		if level.fog:
			check(not level.shows_scan(), "%s: fog levels can't allow scan" % level.id)
		check(level.intro != "" and level.cs_note != "", "%s needs intro and cs_note" % level.id)
		# Hints go from a nudge to the strategy to the full solution (the hint
		# card shows the solution program under the last one).
		check_eq(level.hints.size(), 3, "%s hint count" % level.id)
		for h in level.hints:
			check(h.strip_edges() != "", "%s has an empty hint" % level.id)
