class_name LevelCatalog
extends RefCounted
## All chapters and levels, in play order, from data/levels/catalog.json.
## The catalog lists files explicitly because directory listing behaves
## differently in exported builds.

const DEFAULT_PATH := "res://data/levels/catalog.json"

static var _default: LevelCatalog

## [{"id": int, "title", "subtitle", "intro", "objectives": PackedStringArray, "level_ids": PackedStringArray}]
var chapters: Array[Dictionary] = []
var levels := {}
var order := PackedStringArray()
var errors: Array[String] = []


static func get_default() -> LevelCatalog:
	if _default == null:
		_default = load_from(DEFAULT_PATH)
	return _default


static func load_from(path: String) -> LevelCatalog:
	var cat := LevelCatalog.new()
	var r := LevelLoader.read_json(path)
	if r["error"] != "":
		cat.errors.append(r["error"])
		return cat
	if typeof(r["data"]) != TYPE_DICTIONARY:
		cat.errors.append("%s: must be a JSON object" % path)
		return cat
	var data: Dictionary = r["data"]
	var base := path.get_base_dir()
	var raw_chapters: Variant = data.get("chapters", [])
	if typeof(raw_chapters) != TYPE_ARRAY:
		cat.errors.append("%s: chapters must be an array" % path)
		return cat
	var chapter_no := 0
	for item: Variant in raw_chapters:
		chapter_no += 1
		if typeof(item) != TYPE_DICTIONARY:
			cat.errors.append("%s: chapter %d must be an object" % [path, chapter_no])
			continue
		var cd: Dictionary = item
		var errs: Array[String] = []
		var chapter := {
			"id": chapter_no,
			"title": LevelLoader.get_str(cd, "title", "Chapter %d" % chapter_no, errs),
			"subtitle": LevelLoader.get_str(cd, "subtitle", "", errs),
			"intro": LevelLoader.get_str(cd, "intro", "", errs),
			"objectives": LevelLoader.get_str_array(cd, "objectives", errs),
			"level_ids": PackedStringArray(),
		}
		var ids: PackedStringArray = chapter["level_ids"]
		var number := 0
		for file in LevelLoader.get_str_array(cd, "levels", errs):
			var lr := LevelLoader.load_level(base.path_join(file))
			var level_errors: Array[String] = []
			level_errors.assign(lr["errors"])
			cat.errors.append_array(level_errors)
			if lr["level"] == null:
				continue
			var lv: LevelData = lr["level"]
			if cat.levels.has(lv.id):
				cat.errors.append("%s: duplicate level id '%s'" % [file, lv.id])
				continue
			number += 1
			lv.chapter = chapter_no
			lv.number = number
			cat.levels[lv.id] = lv
			cat.order.append(lv.id)
			ids.append(lv.id)
		chapter["level_ids"] = ids
		for e in errs:
			cat.errors.append("%s: chapter %d: %s" % [path, chapter_no, e])
		cat.chapters.append(chapter)
	return cat


func get_level(id: String) -> LevelData:
	return levels.get(id, null)


## The level after id in play order, or "".
func next_id(id: String) -> String:
	var i := order.find(id)
	if i < 0 or i + 1 >= order.size():
		return ""
	return order[i + 1]


func prev_id(id: String) -> String:
	var i := order.find(id)
	if i <= 0:
		return ""
	return order[i - 1]


func chapter_info(chapter_no: int) -> Dictionary:
	if chapter_no < 1 or chapter_no > chapters.size():
		return {}
	return chapters[chapter_no - 1]
