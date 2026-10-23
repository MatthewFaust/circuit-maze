class_name ProgressData
extends RefCounted
## The player's progress, independent of disk. The Progress autoload loads and
## saves it as a ConfigFile (which keeps ints as ints, unlike JSON).
##
## Version 2 adds gear: armor (granted when its stage unlocks, the strongest
## owned is equipped automatically), weapons (unlocked by total stars, equipped
## by the player) and skins (won from bosses, equipped automatically).
## refresh_unlocks() grants whatever has been earned; version 1 saves get their
## gear the first time it runs.

const VERSION := 2
const DEFAULT_SETTINGS := {
	"speed": 1.0, "volume": 0.8, "sfx": true, "reduce_motion": false, "unlock_all": false,
	"dark_mode": false,
}

## id -> {"escape", "stamina", "blocks": bool, "best_blocks", "best_stamina",
##        "attempts": int, "program": Dictionary, "intro_seen": bool}
var levels := {}
var settings: Dictionary = DEFAULT_SETTINGS.duplicate()
var last_level := ""
var owned_armor := PackedStringArray()
var owned_weapons := PackedStringArray()
var owned_skins := PackedStringArray([ProgressionCatalog.DEFAULT_SKIN])
## "" = none.
var equipped_armor := ""
var equipped_weapon := ""
var skin := ProgressionCatalog.DEFAULT_SKIN


func entry(id: String) -> Dictionary:
	if not levels.has(id):
		levels[id] = {"escape": false, "stamina": false, "blocks": false, "best_blocks": 0,
				"best_stamina": 0, "attempts": 0, "program": {}, "intro_seen": false}
	return levels[id]


func has_entry(id: String) -> bool:
	return levels.has(id)


func stars(id: String) -> int:
	if not levels.has(id):
		return 0
	var e: Dictionary = levels[id]
	return int(bool(e["escape"])) + int(bool(e["stamina"])) + int(bool(e["blocks"]))


func star_flags(id: String) -> Dictionary:
	if not levels.has(id):
		return {"escape": false, "stamina": false, "blocks": false}
	var e: Dictionary = levels[id]
	return {"escape": e["escape"], "stamina": e["stamina"], "blocks": e["blocks"]}


func is_completed(id: String) -> bool:
	return levels.has(id) and bool((levels[id] as Dictionary)["escape"])


## Stars of the regular stages. With a catalog, boss stages (which record only
## their win) are left out.
func total_stars(catalog: LevelCatalog = null) -> int:
	var n := 0
	for id: String in levels:
		if catalog != null:
			var level := catalog.get_level(id)
			if level != null and level.is_boss():
				continue
		n += stars(id)
	return n


# ------------------------------------------------------------------ gear

## Grants every item earned so far and equips new armor and skins. Returns the
## new items, in the order armor, weapons, skins: [{"kind": "armor"|"weapon"|
## "skin", "id", "name", "detail", "equipped": bool}].
func refresh_unlocks(catalog: LevelCatalog, prog: ProgressionCatalog) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for a in prog.armor:
		if not owned_armor.has(a["id"]) and _stage_reached(str(a["unlock_level"]), catalog):
			owned_armor.append(a["id"])
			var current := prog.armor_by_id(equipped_armor)
			var better := current.is_empty() or int(a["defense"]) > int(current["defense"])
			if better:
				equipped_armor = a["id"]
			out.append({"kind": "armor", "id": a["id"], "name": a["name"],
					"detail": "+%d defense" % int(a["defense"]), "equipped": better})
	var total := total_stars(catalog)
	for w in prog.weapons:
		if not owned_weapons.has(w["id"]) and total >= prog.stars_needed(w, catalog):
			owned_weapons.append(w["id"])
			out.append({"kind": "weapon", "id": w["id"], "name": w["name"],
					"detail": "+%d damage" % int(w["damage"]), "equipped": false})
	for s in prog.skins:
		var boss := str(s["boss_level"])
		if not owned_skins.has(s["id"]) and boss != "" and is_completed(boss):
			owned_skins.append(s["id"])
			skin = s["id"]
			out.append({"kind": "skin", "id": s["id"], "name": s["name"], "detail": "skin", "equipped": true})
	return out


## A stage is reached once the stage before it is escaped (the teachers'
## "unlock all" setting doesn't count).
func _stage_reached(id: String, catalog: LevelCatalog) -> bool:
	var i := catalog.order.find(id)
	if i < 0:
		return false
	return i == 0 or is_completed(catalog.order[i - 1])


## Equips owned gear; "" takes the weapon off. Returns false for gear not owned.
func equip(kind: String, id: String) -> bool:
	match kind:
		"armor":
			if not owned_armor.has(id):
				return false
			equipped_armor = id
		"weapon":
			if id != "" and not owned_weapons.has(id):
				return false
			equipped_weapon = id
		"skin":
			if not owned_skins.has(id):
				return false
			skin = id
		_:
			return false
	return true


## The equipped gear's combat stats: {"damage", "defense"}.
func loadout(prog: ProgressionCatalog) -> Dictionary:
	return prog.loadout(equipped_armor, equipped_weapon)


## The first level is always open; others open once the previous one is escaped.
func is_unlocked(id: String, catalog: LevelCatalog) -> bool:
	if bool(settings.get("unlock_all", false)):
		return true
	var i := catalog.order.find(id)
	if i <= 0:
		return i == 0
	return is_completed(catalog.order[i - 1])


## Each star is kept separately as a best result.
func record_result(id: String, evaluation: Dictionary) -> void:
	var e := entry(id)
	e["attempts"] = int(e["attempts"]) + 1
	var s: Dictionary = evaluation.get("stars", {})
	for k in ["escape", "stamina", "blocks"]:
		e[k] = bool(e[k]) or bool(s.get(k, false))
	if bool(evaluation.get("solved", false)):
		var blocks: int = evaluation.get("blocks", 0)
		var stamina: int = evaluation.get("stamina_total", 0)
		e["best_blocks"] = blocks if int(e["best_blocks"]) == 0 else mini(int(e["best_blocks"]), blocks)
		e["best_stamina"] = stamina if int(e["best_stamina"]) == 0 else mini(int(e["best_stamina"]), stamina)


static func _strings(v: Variant) -> PackedStringArray:
	var out := PackedStringArray()
	if typeof(v) == TYPE_PACKED_STRING_ARRAY or typeof(v) == TYPE_ARRAY:
		for item: Variant in v:
			out.append(str(item))
	return out


func get_program(id: String) -> Dictionary:
	if not levels.has(id):
		return {}
	var raw: Variant = (levels[id] as Dictionary).get("program", {})
	if typeof(raw) != TYPE_DICTIONARY or (raw as Dictionary).is_empty():
		return {}
	var r := ProgramModel.normalize(raw)
	var p: Dictionary = r["program"]
	ProgramModel.assign_ids(p)
	return p


func set_program(id: String, p: Dictionary) -> void:
	entry(id)["program"] = ProgramModel.strip_ids(p)


func to_config() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", VERSION)
	cfg.set_value("meta", "last_level", last_level)
	for k: String in settings:
		cfg.set_value("settings", k, settings[k])
	for id: String in levels:
		var e: Dictionary = levels[id]
		for k: String in e:
			cfg.set_value("level." + id, k, e[k])
	cfg.set_value("gear", "owned_armor", owned_armor)
	cfg.set_value("gear", "owned_weapons", owned_weapons)
	cfg.set_value("gear", "owned_skins", owned_skins)
	cfg.set_value("gear", "armor", equipped_armor)
	cfg.set_value("gear", "weapon", equipped_weapon)
	cfg.set_value("gear", "skin", skin)
	return cfg


static func from_config(cfg: ConfigFile) -> ProgressData:
	var pd := ProgressData.new()
	pd.last_level = str(cfg.get_value("meta", "last_level", ""))
	if cfg.has_section("settings"):
		for k in cfg.get_section_keys("settings"):
			pd.settings[k] = cfg.get_value("settings", k)
	pd.owned_armor = _strings(cfg.get_value("gear", "owned_armor", PackedStringArray()))
	pd.owned_weapons = _strings(cfg.get_value("gear", "owned_weapons", PackedStringArray()))
	pd.owned_skins = _strings(cfg.get_value("gear", "owned_skins", pd.owned_skins))
	if not pd.owned_skins.has(ProgressionCatalog.DEFAULT_SKIN):
		pd.owned_skins.insert(0, ProgressionCatalog.DEFAULT_SKIN)
	pd.equipped_armor = str(cfg.get_value("gear", "armor", ""))
	pd.equipped_weapon = str(cfg.get_value("gear", "weapon", ""))
	pd.skin = str(cfg.get_value("gear", "skin", ProgressionCatalog.DEFAULT_SKIN))
	for section in cfg.get_sections():
		if not section.begins_with("level."):
			continue
		var id := section.substr("level.".length())
		var e := pd.entry(id)
		for k in cfg.get_section_keys(section):
			if e.has(k):
				var v: Variant = cfg.get_value(section, k)
				if typeof(v) == typeof(e[k]):
					e[k] = v
	return pd
