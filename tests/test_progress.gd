extends "res://tests/suite_base.gd"
## ProgressData: best results, unlocking and the ConfigFile round trip.


func _eval(escape: bool, stamina: bool, blocks: bool, used_blocks: int, used_stamina: int) -> Dictionary:
	return {"solved": escape, "blocks": used_blocks, "stamina_total": used_stamina,
			"stars": {"escape": escape, "stamina": stamina, "blocks": blocks}}


func _catalog(ids: Array) -> LevelCatalog:
	var cat := LevelCatalog.new()
	for id: String in ids:
		cat.order.append(id)
	return cat


func test_stars_are_kept_per_criterion() -> void:
	var pd := ProgressData.new()
	pd.record_result("1-1", _eval(true, true, false, 9, 20))
	pd.record_result("1-1", _eval(true, false, true, 5, 30))
	check_eq(pd.stars("1-1"), 3, "best of each star")
	var e := pd.entry("1-1")
	check_eq(e["best_blocks"], 5, "fewest blocks")
	check_eq(e["best_stamina"], 20, "least stamina")
	check_eq(e["attempts"], 2, "attempts")
	pd.record_result("1-2", _eval(false, false, false, 3, 0))
	check_eq(pd.stars("1-2"), 0, "a failed run earns nothing")
	check_eq(pd.total_stars(), 3, "total")


func test_unlocking_follows_order() -> void:
	var pd := ProgressData.new()
	var cat := _catalog(["1-1", "1-2", "1-3"])
	check(pd.is_unlocked("1-1", cat), "first level is open")
	check(not pd.is_unlocked("1-2", cat), "second is locked")
	pd.record_result("1-1", _eval(true, false, false, 4, 4))
	check(pd.is_unlocked("1-2", cat), "one star opens the next")
	check(not pd.is_unlocked("1-3", cat), "but not the one after")
	pd.settings["unlock_all"] = true
	check(pd.is_unlocked("1-3", cat), "unlock all")


func test_program_is_saved_without_ids() -> void:
	var pd := ProgressData.new()
	var r := ProgramParser.parse("repeat 3:\n    move()")
	pd.set_program("1-4", r["program"])
	var raw: Dictionary = pd.entry("1-4")["program"]
	check(not ((raw["main"] as Array)[0] as Dictionary).has("id"), "saved without ids")
	var back := pd.get_program("1-4")
	check_eq(((back["main"] as Array)[0] as Dictionary)["id"], 1, "ids reassigned on load")


func test_config_round_trip() -> void:
	var pd := ProgressData.new()
	pd.last_level = "2-3"
	pd.settings["speed"] = 2.0
	pd.record_result("2-3", _eval(true, false, true, 6, 70))
	pd.set_program("2-3", ProgramParser.parse("while not at_exit():\n    move()")["program"])
	var cfg := ConfigFile.new()
	check_eq(cfg.parse(pd.to_config().encode_to_text()), OK, "config text parses")
	var back := ProgressData.from_config(cfg)
	check_eq(back.last_level, "2-3", "last level")
	check_eq(back.settings["speed"], 2.0, "settings")
	check_eq(back.stars("2-3"), 2, "stars")
	check_eq(typeof(back.entry("2-3")["best_blocks"]), TYPE_INT, "ints stay ints")
	check(ProgramModel.canonical(back.get_program("2-3")) == ProgramModel.canonical(pd.get_program("2-3")),
			"program survives")
