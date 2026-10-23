class_name ProgressionCatalog
extends RefCounted
## Armor, weapons and skins, from data/progression.json.
##
## Armor is granted when its stage unlocks, weapons when the total of stars
## reaches a threshold ("all" means every star of every regular stage), and
## skins when a boss stage is won. Stats only matter in boss fights.

const DEFAULT_PATH := "res://data/progression.json"
const DEFAULT_SKIN := "starter_bot"

static var _default: ProgressionCatalog

## [{"id", "name", "defense", "unlock_level"}], weakest first.
var armor: Array[Dictionary] = []
## [{"id", "name", "damage", "stars": int, or -1 for "all"}], cheapest first.
var weapons: Array[Dictionary] = []
## [{"id", "name", "texture", "boss_level" ("" for the default skin)}]
var skins: Array[Dictionary] = []
var errors: Array[String] = []


static func get_default() -> ProgressionCatalog:
	if _default == null:
		_default = load_from(DEFAULT_PATH)
	return _default


static func load_from(path: String) -> ProgressionCatalog:
	var cat := ProgressionCatalog.new()
	var r := LevelLoader.read_json(path)
	if r["error"] != "" or typeof(r["data"]) != TYPE_DICTIONARY:
		cat.errors.append(r["error"] if r["error"] != "" else "%s: must be a JSON object" % path)
		return cat
	var d: Dictionary = r["data"]
	var errs := cat.errors
	for item: Variant in d.get("armor", []):
		if typeof(item) != TYPE_DICTIONARY:
			errs.append("armor entries must be objects")
			continue
		var a: Dictionary = item
		cat.armor.append({
			"id": LevelLoader.get_str(a, "id", "", errs), "name": LevelLoader.get_str(a, "name", "", errs),
			"defense": LevelLoader.get_int(a, "defense", 0, errs),
			"unlock_level": LevelLoader.get_str(a, "unlock_level", "", errs),
		})
	for item: Variant in d.get("weapons", []):
		if typeof(item) != TYPE_DICTIONARY:
			errs.append("weapon entries must be objects")
			continue
		var w: Dictionary = item
		var stars := -1 if str(w.get("stars", "")) == "all" else LevelLoader.get_int(w, "stars", 0, errs)
		cat.weapons.append({
			"id": LevelLoader.get_str(w, "id", "", errs), "name": LevelLoader.get_str(w, "name", "", errs),
			"damage": LevelLoader.get_int(w, "damage", 0, errs), "stars": stars,
		})
	for item: Variant in d.get("skins", []):
		if typeof(item) != TYPE_DICTIONARY:
			errs.append("skin entries must be objects")
			continue
		var s: Dictionary = item
		cat.skins.append({
			"id": LevelLoader.get_str(s, "id", "", errs), "name": LevelLoader.get_str(s, "name", "", errs),
			"texture": LevelLoader.get_str(s, "texture", "", errs),
			"boss_level": LevelLoader.get_str(s, "boss_level", "", errs),
		})
	for i in errs.size():
		errs[i] = "%s: %s" % [path, errs[i]]
	return cat


func armor_by_id(id: String) -> Dictionary:
	return _find(armor, id)


func weapon_by_id(id: String) -> Dictionary:
	return _find(weapons, id)


func skin_by_id(id: String) -> Dictionary:
	return _find(skins, id)


## Stars a weapon needs; "all" resolves to every star of the regular stages.
func stars_needed(weapon: Dictionary, catalog: LevelCatalog) -> int:
	var n: int = weapon.get("stars", 0)
	return catalog.max_stars() if n < 0 else n


## The combat stats a set of gear gives: {"damage": weapon bonus, "defense": int}.
## Unknown or empty ids add nothing.
func loadout(armor_id: String, weapon_id: String) -> Dictionary:
	return {
		"damage": int(weapon_by_id(weapon_id).get("damage", 0)),
		"defense": int(armor_by_id(armor_id).get("defense", 0)),
	}


static func _find(list: Array[Dictionary], id: String) -> Dictionary:
	for e in list:
		if str(e["id"]) == id:
			return e
	return {}
