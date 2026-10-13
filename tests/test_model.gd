extends "res://tests/suite_base.gd"
## ProgramModel: ids, refs, edits, counting, normalizing and inlining.


## main: move(1), repeat 3(2) { turn_left(3), if_else bush_ahead(4) { cut(5) } else { move(6) } }, A()(7)
## A:    turn_right(8)
func _sample() -> Dictionary:
	var p := ProgramModel.empty(["A"])
	var main: Array = p["main"]
	main.append(ProgramModel.action("move"))
	main.append(ProgramModel.repeat(3, [
		ProgramModel.action("turn_left"),
		ProgramModel.if_else(ProgramModel.cond("bush_ahead"), [ProgramModel.action("cut")],
				[ProgramModel.action("move")]),
	]))
	main.append(ProgramModel.call_fn("A"))
	var fns: Dictionary = p["functions"]
	var a: Array = fns["A"]
	a.append(ProgramModel.action("turn_right"))
	ProgramModel.assign_ids(p)
	return p


func _types(list: Array) -> Array:
	var out: Array = []
	for n: Dictionary in list:
		out.append(n["type"])
	return out


func test_assign_ids_in_tree_order() -> void:
	var p := _sample()
	check_eq(ProgramModel.assign_ids(p), 9, "next free id")
	check_eq(ProgramModel.find(p, 5)["node"]["type"], "cut", "id 5 is cut")
	check_eq(ProgramModel.find(p, 8)["node"]["type"], "turn_right", "functions come after main")


func test_find_reports_list_refs() -> void:
	var p := _sample()
	check_eq(ProgramModel.find(p, 3)["ref"], "2:body", "inside repeat")
	check_eq(ProgramModel.find(p, 5)["ref"], "4:body", "if branch")
	check_eq(ProgramModel.find(p, 6)["ref"], "4:else", "else branch")
	check_eq(ProgramModel.find(p, 8)["ref"], "fn:A", "function body")
	check(ProgramModel.find(p, 99).is_empty(), "missing id")
	check(ProgramModel.has_list(p, "4:else"), "if_else has an else list")
	check(not ProgramModel.has_list(p, "1:body"), "an action has no body")


func test_count_blocks_counts_definitions() -> void:
	var p := _sample()
	check_eq(ProgramModel.count_blocks(p), 9, "7 in main + define A + 1")
	var empty_fn := ProgramModel.empty(["A", "B"])
	(empty_fn["main"] as Array).append(ProgramModel.action("move"))
	check_eq(ProgramModel.count_blocks(empty_fn), 1, "empty functions don't count")


func test_insert_and_remove() -> void:
	var p := _sample()
	check(ProgramModel.insert(p, "2:body", 0, ProgramModel.action("cut")), "insert into repeat")
	check_eq(_types(ProgramModel.get_list(p, "2:body")), ["cut", "turn_left", "if_else"], "inserted first")
	check(not ProgramModel.insert(p, "1:body", 0, ProgramModel.action("cut")), "can't insert into an action")
	var removed := ProgramModel.remove(p, 4)
	check_eq(removed["type"], "if_else", "removed the if/else")
	check_eq(ProgramModel.count_blocks(p), 7, "its children went with it")


func test_move_within_same_list_fixes_index() -> void:
	var p := _sample()
	check(ProgramModel.move_node(p, 1, "main", 3), "move first block to the end")
	check_eq(_types(p["main"]), ["repeat", "call", "move"], "order after move")
	ProgramModel.assign_ids(p)
	var last_id: int = (p["main"] as Array)[2]["id"]
	check(ProgramModel.move_node(p, last_id, "main", 0), "move it back to the front")
	check_eq(_types(p["main"]), ["move", "repeat", "call"], "back to the start")


func test_move_into_itself_is_refused() -> void:
	var p := _sample()
	check(not ProgramModel.move_node(p, 2, "2:body", 0), "into its own body")
	check(not ProgramModel.move_node(p, 2, "4:else", 0), "into a nested body")
	check_eq(ProgramModel.count_blocks(p), 9, "nothing changed")


func test_move_between_lists() -> void:
	var p := _sample()
	check(ProgramModel.move_node(p, 5, "fn:A", 1), "cut into A")
	check_eq(_types(ProgramModel.get_list(p, "fn:A")), ["turn_right", "cut"], "A now has cut")
	check(ProgramModel.get_list(p, "4:body").is_empty(), "if branch is empty")


func test_canonical_strips_ids_and_empty_functions() -> void:
	var p := _sample()
	var q := ProgramModel.empty(["A", "B", "C"])
	q["main"] = (p["main"] as Array).duplicate(true)
	(q["functions"] as Dictionary)["A"] = ((p["functions"] as Dictionary)["A"] as Array).duplicate(true)
	ProgramModel.assign_ids(q)
	check(ProgramModel.canonical(p) == ProgramModel.canonical(q), "same program, different empty slots")
	var c := ProgramModel.canonical(p)
	check(not ((c["main"] as Array)[0] as Dictionary).has("id"), "ids stripped")


func test_normalize_turns_json_floats_into_ints() -> void:
	var p := _sample()
	var through_json: Variant = JSON.parse_string(JSON.stringify(ProgramModel.strip_ids(p)))
	var r := ProgramModel.normalize(through_json)
	check_eq((r["errors"] as Array).size(), 0, "no errors")
	var q: Dictionary = r["program"]
	check_eq(typeof(((q["main"] as Array)[1] as Dictionary)["count"]), TYPE_INT, "count is an int again")
	check(ProgramModel.canonical(q) == ProgramModel.canonical(p), "same program after JSON")


func test_normalize_skips_bad_blocks() -> void:
	var raw := {"main": [{"type": "fly"}, {"type": "move"},
			{"type": "while", "cond": {"sensor": "magic"}, "body": []}], "functions": {}}
	var r := ProgramModel.normalize(raw)
	check_eq((r["errors"] as Array).size(), 2, "unknown type and unknown sensor")
	check_eq(_types((r["program"] as Dictionary)["main"]), ["move", "while"], "kept the valid blocks")


func test_inline_calls() -> void:
	var p := _sample()
	var q := ProgramModel.inline_calls(p)
	check_eq(_types(q["main"]), ["move", "repeat", "turn_right"], "call replaced by A's body")
	var rec := ProgramModel.empty(["A"])
	(rec["main"] as Array).append(ProgramModel.call_fn("A"))
	((rec["functions"] as Dictionary)["A"] as Array).append(ProgramModel.call_fn("A"))
	check(ProgramModel.inline_calls(rec).is_empty(), "recursion can't be inlined")


func test_from_actions_and_usage() -> void:
	var p := ProgramModel.from_actions(PackedStringArray(["move", "turn_left", "move"]))
	check_eq(ProgramModel.count_blocks(p), 3, "three blocks")
	var u := ProgramModel.usage(_sample())
	check_eq((u["types"] as Dictionary)["move"], 2, "two moves")
	check_eq((u["sensors"] as Dictionary)["bush_ahead"], 1, "one sensor")
	check_eq((u["calls"] as Dictionary)["A"], 1, "one call")
	check_eq(u["max_repeat"], 3, "max repeat")
