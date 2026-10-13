class_name LevelLoader
extends RefCounted
## Reads level JSON files into LevelData, reporting problems as "path: message".
## JSON numbers arrive as floats; they are converted to ints here, once.


## {"data": Variant, "error": String}
static func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"data": null, "error": "%s: file not found" % path}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {"data": null, "error": "%s:%d: %s" % [path, json.get_error_line(), json.get_error_message()]}
	return {"data": json.data, "error": ""}


## {"level": LevelData or null, "errors": Array[String]}
static func load_level(path: String) -> Dictionary:
	var r := read_json(path)
	if r["error"] != "":
		var errs: Array[String] = [r["error"]]
		return {"level": null, "errors": errs}
	if typeof(r["data"]) != TYPE_DICTIONARY:
		var errs: Array[String] = ["%s: a level must be a JSON object" % path]
		return {"level": null, "errors": errs}
	return level_from_dict(r["data"], path)


static func level_from_dict(d: Dictionary, path: String = "") -> Dictionary:
	var errors: Array[String] = []
	var lv := LevelData.new()
	lv.path = path
	lv.id = get_str(d, "id", "", errors)
	if lv.id == "":
		errors.append("missing id")
	lv.title = get_str(d, "title", lv.id, errors)
	lv.concept = get_str(d, "concept", "", errors)
	lv.intro = get_str(d, "intro", "", errors)
	lv.cs_note = get_str(d, "cs_note", "", errors)
	lv.hints = get_str_array(d, "hints", errors)
	lv.new_blocks = get_str_array(d, "new_blocks", errors)

	var allowed: Dictionary = get_dict(d, "allowed", errors)
	lv.allowed_blocks = get_str_array(allowed, "blocks", errors)
	lv.allowed_sensors = get_str_array(allowed, "sensors", errors)
	lv.allowed_functions = get_str_array(allowed, "functions", errors)
	lv.allow_not = get_bool(allowed, "not", true, errors)
	for b in lv.allowed_blocks:
		if not ProgramModel.BLOCK_TYPES.has(b) or b == "call":
			errors.append("unknown block '%s' in allowed.blocks" % b)
	for s in lv.allowed_sensors:
		if not ProgramModel.SENSORS.has(s):
			errors.append("unknown sensor '%s' in allowed.sensors" % s)
	for f in lv.allowed_functions:
		if not ProgramModel.FUNCTION_NAMES.has(f):
			errors.append("unknown function '%s' in allowed.functions" % f)

	lv.block_limit = get_int(d, "block_limit", 0, errors)
	var par: Dictionary = get_dict(d, "par", errors)
	lv.par_blocks = get_int(par, "blocks", 0, errors)
	lv.par_stamina = get_int(par, "stamina", 0, errors)
	var robot: Dictionary = get_dict(d, "robot", errors)
	var default_stamina := get_int(robot, "stamina", 20, errors)
	lv.rules = MazeRules.from_overrides(get_dict(d, "rules", errors), errors)
	if robot.has("hp"):
		lv.rules.max_hp = get_int(robot, "hp", 100, errors)
	lv.fog = get_bool(d, "fog", false, errors)

	lv.starter_text = get_program_text(d, "starter", errors)
	lv.solution_text = get_program_text(d, "solution", errors)
	if lv.solution_text.strip_edges() == "":
		errors.append("missing solution")
	for key in ["alt_solutions", "anti_solutions"]:
		var raw: Variant = d.get(key, [])
		if typeof(raw) != TYPE_ARRAY:
			errors.append("%s must be an array" % key)
			continue
		for item: Variant in raw:
			if typeof(item) != TYPE_DICTIONARY:
				errors.append("%s entries must be objects" % key)
				continue
			var e: Dictionary = item
			var entry := {
				"name": get_str(e, "name", "unnamed", errors),
				"text": get_program_text(e, "program", errors),
				"expect_fail_code": get_str(e, "expect_fail_code", "", errors),
				"note": get_str(e, "note", "", errors),
			}
			if key == "alt_solutions":
				lv.alt_solutions.append(entry)
			else:
				lv.anti_solutions.append(entry)
	var checks: Dictionary = get_dict(d, "checks", errors)
	lv.hardcode_must_fail = get_bool(checks, "hardcode_must_fail", true, errors)
	lv.inline_must_fail = get_bool(checks, "inline_must_fail", false, errors)

	var raw_variants: Variant = d.get("variants", [])
	if typeof(raw_variants) != TYPE_ARRAY or (raw_variants as Array).is_empty():
		errors.append("a level needs at least one variant")
	else:
		var n := 0
		for item: Variant in raw_variants:
			n += 1
			if typeof(item) != TYPE_DICTIONARY:
				errors.append("variant %d must be an object" % n)
				continue
			var vd: Dictionary = item
			var v := LevelVariant.new()
			v.name = get_str(vd, "name", "Map %d" % n, errors)
			v.rows = get_str_array(vd, "map", errors)
			var parsed := MazeGrid.from_rows(v.rows)
			for e: String in parsed["errors"]:
				errors.append("%s: %s" % [v.name, e])
			v.grid = parsed["grid"]
			v.start = parsed["start"]
			v.facing = Tiles.facing_from_char(get_str(vd, "facing", "E", errors))
			if v.facing < 0:
				errors.append("%s: facing must be N, E, S or W" % v.name)
				v.facing = Tiles.EAST
			v.stamina = get_int(vd, "stamina", default_stamina, errors)
			lv.variants.append(v)

	var prefixed: Array[String] = []
	for e in errors:
		prefixed.append("%s: %s" % [path if path != "" else lv.id, e])
	return {"level": lv if errors.is_empty() else null, "errors": prefixed}


static func get_str(d: Dictionary, key: String, default: String, errors: Array[String]) -> String:
	if not d.has(key):
		return default
	var v: Variant = d[key]
	if typeof(v) != TYPE_STRING:
		errors.append("'%s' must be a string" % key)
		return default
	return v


static func get_int(d: Dictionary, key: String, default: int, errors: Array[String]) -> int:
	if not d.has(key):
		return default
	var v: Variant = d[key]
	if typeof(v) == TYPE_INT:
		return v
	if typeof(v) == TYPE_FLOAT and float(v) == floorf(float(v)):
		return int(v)
	errors.append("'%s' must be an integer" % key)
	return default


static func get_bool(d: Dictionary, key: String, default: bool, errors: Array[String]) -> bool:
	if not d.has(key):
		return default
	var v: Variant = d[key]
	if typeof(v) != TYPE_BOOL:
		errors.append("'%s' must be true or false" % key)
		return default
	return v


static func get_dict(d: Dictionary, key: String, errors: Array[String]) -> Dictionary:
	if not d.has(key):
		return {}
	var v: Variant = d[key]
	if typeof(v) != TYPE_DICTIONARY:
		errors.append("'%s' must be an object" % key)
		return {}
	return v


static func get_str_array(d: Dictionary, key: String, errors: Array[String]) -> PackedStringArray:
	var out := PackedStringArray()
	if not d.has(key):
		return out
	var v: Variant = d[key]
	if typeof(v) != TYPE_ARRAY:
		errors.append("'%s' must be an array of strings" % key)
		return out
	for item: Variant in v:
		if typeof(item) != TYPE_STRING:
			errors.append("'%s' must contain only strings" % key)
			continue
		out.append(item)
	return out


## Programs are stored as an array of lines (JSON has no multi-line strings) or one string.
static func get_program_text(d: Dictionary, key: String, errors: Array[String]) -> String:
	if not d.has(key):
		return ""
	var v: Variant = d[key]
	if typeof(v) == TYPE_STRING:
		return v
	if typeof(v) == TYPE_ARRAY:
		return "\n".join(get_str_array(d, key, errors))
	errors.append("'%s' must be a string or an array of lines" % key)
	return ""
