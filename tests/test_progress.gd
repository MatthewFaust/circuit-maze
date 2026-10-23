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


# ------------------------------------------------------------------ gear

func _complete(pd: ProgressData, ids: Array, all_stars: bool = true) -> void:
	for id: String in ids:
		pd.record_result(id, _eval(true, all_stars, all_stars, 1, 1))


## Every regular stage up to (not including) stop_id.
func _ids_before(stop_id: String) -> Array:
	var cat := LevelCatalog.get_default()
	var out: Array = []
	for id in cat.order:
		if id == stop_id:
			break
		out.append(id)
	return out


func test_armor_comes_with_its_stage_and_is_equipped() -> void:
	var cat := LevelCatalog.get_default()
	var prog := ProgressionCatalog.get_default()
	var pd := ProgressData.new()
	check(pd.refresh_unlocks(cat, prog).is_empty(), "nothing earned yet")
	check_eq(pd.skin, "starter_bot", "the default skin")
	_complete(pd, ["1-1", "1-2", "1-3"])
	check(pd.refresh_unlocks(cat, prog).is_empty(), "1-5 isn't open yet")
	_complete(pd, ["1-4"])
	var got := pd.refresh_unlocks(cat, prog)
	check(got.size() >= 1 and got[0]["id"] == "tin_shell" and bool(got[0]["equipped"]), "Tin Shell when 1-5 opens: %s" % str(got))
	check_eq(pd.equipped_armor, "tin_shell", "equipped")
	check(pd.refresh_unlocks(cat, prog).is_empty(), "granted only once")
	pd.settings["unlock_all"] = true
	check(not pd.owned_armor.has("signal_shield"), "unlock all doesn't grant armor")
	check_eq(pd.loadout(prog)["defense"], 1, "defense from the armor")


func test_stronger_armor_replaces_the_equipped_one() -> void:
	var cat := LevelCatalog.get_default()
	var prog := ProgressionCatalog.get_default()
	var pd := ProgressData.new()
	_complete(pd, _ids_before("2-2"))
	pd.refresh_unlocks(cat, prog)
	check_eq(pd.equipped_armor, "signal_shield", "the strongest owned armor")
	check(pd.equip("armor", "tin_shell"), "the player can switch to owned armor")
	check(not pd.equip("armor", "firewall_armor"), "but not to armor they don't own")
	_complete(pd, _ids_before("3-4"))
	pd.refresh_unlocks(cat, prog)
	check_eq(pd.equipped_armor, "mirror_plating", "new, stronger armor is equipped")


func test_weapons_unlock_by_stars_and_wait_to_be_equipped() -> void:
	var cat := LevelCatalog.get_default()
	var prog := ProgressionCatalog.get_default()
	var pd := ProgressData.new()
	_complete(pd, ["1-1", "1-2", "1-3", "1-4"])
	check(not pd.owned_weapons.has("loop_blaster"), "12 stars: not yet")
	_complete(pd, ["1-5"])
	var got := pd.refresh_unlocks(cat, prog)
	var weapon_ids: Array = got.filter(func(g: Dictionary) -> bool: return g["kind"] == "weapon").map(func(g: Dictionary) -> String: return g["id"])
	check_eq(weapon_ids, ["loop_blaster"], "15 stars: the Loop Blaster")
	check_eq(pd.equipped_weapon, "", "not equipped automatically")
	check(pd.equip("weapon", "loop_blaster"), "the player equips it")
	check_eq(pd.loadout(prog)["damage"], 1, "its damage")
	check(pd.equip("weapon", ""), "and can take it off")
	# Every star of every regular stage opens the Pathfinder Lance.
	var regular: Array = Array(cat.order).filter(func(id: String) -> bool: return not cat.get_level(id).is_boss())
	_complete(pd, regular)
	check_eq(pd.total_stars(cat), cat.max_stars(), "all stars")
	pd.refresh_unlocks(cat, prog)
	check(pd.owned_weapons.has("pathfinder_lance"), "ALL stars: the Pathfinder Lance")


func test_boss_wins_unlock_skins_but_no_stars() -> void:
	var cat := LevelCatalog.get_default()
	var prog := ProgressionCatalog.get_default()
	var pd := ProgressData.new()
	_complete(pd, _ids_before("1-B"))
	var before := pd.total_stars(cat)
	pd.record_result("1-B", {"solved": true, "blocks": 5, "stamina_total": 14,
			"stars": {"escape": true, "stamina": false, "blocks": false}})
	check_eq(pd.total_stars(cat), before, "boss stages add no stars")
	check(pd.is_unlocked("2-1", cat), "beating the boss opens chapter 2")
	var got := pd.refresh_unlocks(cat, prog)
	check(got.any(func(g: Dictionary) -> bool: return g["id"] == "circuit_green" and bool(g["equipped"])), "Circuit Green, equipped: %s" % str(got))
	check_eq(pd.skin, "circuit_green", "the new skin is worn")
	check(pd.equip("skin", "starter_bot"), "the default skin stays available")


func test_gear_survives_save_and_old_saves_get_their_gear() -> void:
	var cat := LevelCatalog.get_default()
	var prog := ProgressionCatalog.get_default()
	var pd := ProgressData.new()
	_complete(pd, _ids_before("1-B"))
	pd.refresh_unlocks(cat, prog)
	pd.equip("weapon", "loop_blaster")
	var back := ProgressData.from_config(pd.to_config())
	check_eq(back.owned_armor, pd.owned_armor, "owned armor")
	check_eq(back.owned_weapons, pd.owned_weapons, "owned weapons")
	check_eq(back.equipped_armor, "tin_shell", "equipped armor")
	check_eq(back.equipped_weapon, "loop_blaster", "equipped weapon")
	check_eq(back.skin, "starter_bot", "skin")
	# A version 1 save has no [gear] section.
	var old := pd.to_config()
	old.erase_section("gear")
	old.set_value("meta", "version", 1)
	var migrated := ProgressData.from_config(old)
	check(migrated.owned_armor.is_empty() and migrated.owned_skins.has("starter_bot"), "loads without gear")
	migrated.refresh_unlocks(cat, prog)
	check_eq(migrated.equipped_armor, "tin_shell", "and gets the armor it had earned")


func test_every_weapon_and_armor_has_a_picture() -> void:
	var prog := ProgressionCatalog.get_default()
	for item in prog.armor + prog.weapons:
		var icon := str(item.get("icon", ""))
		check(icon != "" and ResourceLoader.exists(icon), "%s has a picture (%s)" % [item["id"], icon])
