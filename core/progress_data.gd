class_name ProgressData
extends RefCounted
## The player's progress, independent of disk. The Progress autoload loads and
## saves it as a ConfigFile (which keeps ints as ints, unlike JSON).

const VERSION := 1
const DEFAULT_SETTINGS := {
	"speed": 1.0, "volume": 0.8, "sfx": true, "reduce_motion": false, "unlock_all": false,
}

## id -> {"escape", "stamina", "blocks": bool, "best_blocks", "best_stamina",
##        "attempts": int, "program": Dictionary, "intro_seen": bool}
var levels := {}
var settings: Dictionary = DEFAULT_SETTINGS.duplicate()
var last_level := ""


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


func total_stars() -> int:
	var n := 0
	for id: String in levels:
		n += stars(id)
	return n


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
	return cfg


static func from_config(cfg: ConfigFile) -> ProgressData:
	var pd := ProgressData.new()
	pd.last_level = str(cfg.get_value("meta", "last_level", ""))
	if cfg.has_section("settings"):
		for k in cfg.get_section_keys("settings"):
			pd.settings[k] = cfg.get_value("settings", k)
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
