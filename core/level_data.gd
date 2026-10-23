class_name LevelData
extends RefCounted
## A level as loaded from data/levels/*.json by LevelLoader.

var id := ""
var path := ""
var chapter := 0
## 1-based position inside its chapter.
var number := 0
var title := ""
var concept := ""
var intro := ""
var cs_note := ""
var hints := PackedStringArray()
## Blocks the intro dialog presents as new on this level.
var new_blocks := PackedStringArray()
var allowed_blocks := PackedStringArray()
var allowed_sensors := PackedStringArray()
var allowed_functions := PackedStringArray()
var allow_not := true
## 0 = no limit.
var block_limit := 0
var par_blocks := 0
## Total stamina across all variants for the stamina star.
var par_stamina := 0
var rules: MazeRules = MazeRules.new()
var fog := false
## Program text loaded into the editor on the first visit ("" = empty program).
var starter_text := ""
## The par-setting reference program (must earn all three stars).
var solution_text := ""
## [{"name", "text"}]: must escape, may miss the pars.
var alt_solutions: Array[Dictionary] = []
## [{"name", "text", "expect_fail_code", "note", "passes_with"}]: must not solve
## the level. Boss stages: with the gear in passes_with ({"armor", "weapon"},
## empty = none) the program must win, showing that better gear forgives it.
var anti_solutions: Array[Dictionary] = []
var hardcode_must_fail := true
var inline_must_fail := false
var variants: Array[LevelVariant] = []
## Boss stages only (empty otherwise): {"name", "skin", "min_gear": {"armor",
## "weapon"}, "min_loadout": {"damage", "defense"}, "units": [{"name", "hp",
## "attack", "pattern", "split": [{..., "cell": Vector2i}]}]}. One unit per "M"
## in each map, in reading order.
var boss := {}


## A boss stage: won by defeating every boss, awards no stars.
func is_boss() -> bool:
	return not boss.is_empty()


## The gear the tests and tools fight with: the boss's minimum gear (none
## for regular stages, where gear has no effect).
func default_loadout() -> Dictionary:
	return boss.get("min_loadout", {"damage": 0, "defense": 0})


func uses_functions() -> bool:
	return not allowed_functions.is_empty()


func allows(block: String) -> bool:
	if block == "call" or block.begins_with("call:"):
		return uses_functions()
	return allowed_blocks.has(block)


## Uses breadcrumbs (DFS) and should show the trail/stack in the inspector.
func shows_trail() -> bool:
	return allowed_blocks.has("backtrack") or allowed_sensors.has("unvisited_ahead") \
			or allowed_sensors.has("unvisited_left") or allowed_sensors.has("unvisited_right")


func shows_scan() -> bool:
	return allowed_blocks.has("scan") or allowed_blocks.has("scan_weighted")


func starter_program() -> Dictionary:
	if starter_text.strip_edges() == "":
		return ProgramModel.empty(Array(allowed_functions))
	var r := ProgramParser.parse(starter_text)
	if not bool(r["ok"]):
		return ProgramModel.empty(Array(allowed_functions))
	var p: Dictionary = r["program"]
	var fns: Dictionary = p["functions"]
	for f in allowed_functions:
		if not fns.has(f):
			fns[f] = []
	return p
