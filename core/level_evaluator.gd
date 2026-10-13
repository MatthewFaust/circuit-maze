class_name LevelEvaluator
extends RefCounted
## Checks a program against a level: allowed blocks, the block limit, and a
## run on every map variant. Used by "Check all tests", stars and the tests.


## Problems that stop the program from running on this level at all.
static func static_check(level: LevelData, p: Dictionary) -> PackedStringArray:
	var errs := PackedStringArray()
	var u := ProgramModel.usage(p)
	var types: Dictionary = u["types"]
	for t: String in types:
		if t == "call":
			continue
		if not level.allowed_blocks.has(t):
			errs.append("The %s block isn't available on this level." % t)
	var sensors: Dictionary = u["sensors"]
	for s: String in sensors:
		if not level.allowed_sensors.has(s):
			errs.append("The %s() sensor isn't available on this level." % s)
	if int(u["negated"]) > 0 and not level.allow_not:
		errs.append("'not' isn't available on this level.")
	var calls: Dictionary = u["calls"]
	for f: String in calls:
		if not level.allowed_functions.has(f):
			errs.append("Function %s isn't available on this level." % f)
	for f: String in u["defined"]:
		if not level.allowed_functions.has(f):
			errs.append("Function %s isn't available on this level." % f)
	if int(u["max_repeat"]) > ProgramModel.MAX_REPEAT or int(u["min_repeat"]) < 1:
		errs.append("Repeat counts must be between 1 and %d." % ProgramModel.MAX_REPEAT)
	var blocks := ProgramModel.count_blocks(p)
	if level.block_limit > 0 and blocks > level.block_limit:
		errs.append("The program uses %d blocks, but the limit here is %d." % [blocks, level.block_limit])
	return errs


## Runs the program on one variant. Returns the interpreter summary plus "variant".
static func run_variant(level: LevelData, index: int, p: Dictionary) -> Dictionary:
	var world := level.variants[index].make_world(level)
	var interp := ProgramInterpreter.new(p, world)
	var result := interp.run_to_end()
	result["variant"] = index
	return result


## {"valid", "errors", "blocks", "variants": [summary...], "solved", "stamina_total",
##  "stars": {"escape", "stamina", "blocks"}, "star_count"}
static func evaluate(level: LevelData, p: Dictionary) -> Dictionary:
	var errs := static_check(level, p)
	var blocks := ProgramModel.count_blocks(p)
	var out := {
		"valid": errs.is_empty(), "errors": errs, "blocks": blocks, "variants": [],
		"solved": false, "stamina_total": 0,
		"stars": {"escape": false, "stamina": false, "blocks": false}, "star_count": 0,
	}
	if not errs.is_empty():
		return out
	var results: Array = out["variants"]
	var solved := true
	var total := 0
	for i in level.variants.size():
		var r := run_variant(level, i, p)
		results.append(r)
		solved = solved and bool(r["won"])
		total += int(r["stamina_spent"])
	out["solved"] = solved
	out["stamina_total"] = total
	out["stars"] = stars_for(level, solved, total, blocks)
	out["star_count"] = star_count(out["stars"])
	return out


static func stars_for(level: LevelData, solved: bool, stamina_total: int, blocks: int) -> Dictionary:
	return {
		"escape": solved,
		"stamina": solved and (level.par_stamina <= 0 or stamina_total <= level.par_stamina),
		"blocks": solved and (level.par_blocks <= 0 or blocks <= level.par_blocks),
	}


static func star_count(stars: Dictionary) -> int:
	var n := 0
	for k in ["escape", "stamina", "blocks"]:
		if bool(stars.get(k, false)):
			n += 1
	return n
