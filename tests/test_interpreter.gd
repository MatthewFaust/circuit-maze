extends "res://tests/suite_base.gd"
## ProgramInterpreter: stepping, every block type, highlighting data and limits.


func _setup(rows: Array, text: String, facing: int = Tiles.EAST, stamina: int = 50,
		rules: MazeRules = null) -> ProgramInterpreter:
	var parsed := MazeGrid.from_rows(PackedStringArray(rows))
	var world := MazeWorld.new(parsed["grid"], parsed["start"], facing,
			rules if rules != null else MazeRules.new(), stamina)
	var pr := ProgramParser.parse(text)
	if not check(bool(pr["ok"]), "parse failed: %s" % str(pr["errors"])):
		return ProgramInterpreter.new(ProgramModel.empty(), world)
	return ProgramInterpreter.new(pr["program"], world)


const CORRIDOR := ["#######", "#S...E#", "#######"]


func test_each_step_runs_one_action() -> void:
	var it := _setup(CORRIDOR, "move()\nmove()\nmove()\nmove()")
	var r := it.step()
	check_eq(r["action"], "move", "first action")
	check_eq(r["node_id"], 1, "first block")
	check_eq(r["status"], "running", "still running")
	for i in 3:
		r = it.step()
	check_eq(r["node_id"], 4, "fourth block")
	check_eq(r["status"], "won", "escaped")
	check(it.finished, "finished")


func test_repeat_and_loop_states() -> void:
	var it := _setup(CORRIDOR, "for _ in range(4):\n    move()")
	it.step()
	var r := it.step()
	var loops: Array = r["loops"]
	check_eq(loops.size(), 1, "one open loop")
	check_eq((loops[0] as Dictionary)["iteration"], 2, "second iteration")
	check_eq((loops[0] as Dictionary)["total"], 4, "of four")
	check_eq(it.run_to_end()["status"], "won", "escaped")


func test_nested_repeat_multiplies() -> void:
	var it := _setup(CORRIDOR, "repeat 2:\n    repeat 3:\n        turn_left()")
	var s := it.run_to_end()
	check_eq(s["actions"], 6, "2 x 3 turns")
	check_eq(s["fail_code"], "program_ended", "never reached the exit")


func test_while_and_if_else() -> void:
	var it := _setup(["########", "#S.B.BE#", "########"],
			"while not at_exit():\n    if bush_ahead():\n        cut()\n    else:\n        move()")
	var s := it.run_to_end()
	check_eq(s["status"], "won", "escaped")
	check_eq(Array(s["trace"]).count("cut"), 2, "cut both bushes")
	check_eq(s["stamina_spent"], 5 + 6, "5 moves + 2 cuts")


func test_if_without_else_skips() -> void:
	var it := _setup(CORRIDOR, "if bush_ahead():\n    cut()\nmove()")
	var r := it.step()
	check_eq(r["action"], "move", "the if body was skipped")
	var checks: Array = r["checks"]
	check_eq(checks.size(), 1, "one condition checked")
	check_eq((checks[0] as Dictionary)["value"], false, "bush_ahead was false")


func test_functions_report_call_stack() -> void:
	var it := _setup(CORRIDOR, "def A():\n    move()\n    move()\nA()\nA()")
	# Ids: main's calls are 1 and 2, then A's moves are 3 and 4.
	var r := it.step()
	check_eq(r["node_id"], 3, "first move inside A")
	check_list(Array(r["call_stack"]), ["main", "A"], "call stack")
	check_list(Array(r["active_ids"]), [1], "the first call block is active")
	it.step()
	r = it.step()
	check_list(Array(r["active_ids"]), [2], "now the second call block")
	check_eq(it.run_to_end()["status"], "won", "two calls of two moves")


func test_recursion_with_base_case() -> void:
	var it := _setup([
		"######",
		"###.E#",
		"###.##",
		"#S..##",
		"######",
	], "def A():\n    if path_ahead():\n        move()\n        A()\n        move()\n    else:\n        turn_left()\nA()\nturn_right()\nmove()")
	var s := it.run_to_end()
	check_eq(s["status"], "won", "the stack remembered the distance")
	check_eq(s["actions"], 7, "2N + 3 with N = 2")
	check_eq(s["peak_call_depth"], 3, "three nested calls")


func test_stack_overflow() -> void:
	var it := _setup(CORRIDOR, "def A():\n    A()\nA()")
	check_eq(it.run_to_end()["fail_code"], "stack_overflow", "no base case")


func test_call_depth_limit_comes_from_rules() -> void:
	var rules := MazeRules.new()
	rules.max_call_depth = 3
	var it := _setup(CORRIDOR, "def A():\n    move()\n    A()\nA()", Tiles.EAST, 50, rules)
	var s := it.run_to_end()
	check_eq(s["fail_code"], "stack_overflow", "depth 4 is over the limit of 3")
	check_eq(s["actions"], 3, "three moves happened first")


func test_idle_loop() -> void:
	var it := _setup(CORRIDOR, "while path_ahead():\n    pass")
	check_eq(it.run_to_end()["fail_code"], "idle_loop", "a loop with no action")


func test_op_limit() -> void:
	var rules := MazeRules.new()
	rules.max_ops = 30
	var it := _setup(CORRIDOR, "while not at_exit():\n    turn_left()", Tiles.EAST, 50, rules)
	check_eq(it.run_to_end()["fail_code"], "op_limit", "operation cap")


func test_action_limit() -> void:
	var rules := MazeRules.new()
	rules.max_actions = 5
	var it := _setup(CORRIDOR, "while not at_exit():\n    turn_left()", Tiles.EAST, 50, rules)
	var s := it.run_to_end()
	check_eq(s["fail_code"], "action_limit", "action cap")
	check_eq(s["actions"], 6, "the sixth action tripped it")


func test_program_ended() -> void:
	var it := _setup(CORRIDOR, "move()")
	var s := it.run_to_end()
	check_eq(s["fail_code"], "program_ended", "stopped short")
	check_eq(s["actions"], 1, "one action")


func test_empty_program_ends_immediately() -> void:
	var it := _setup(CORRIDOR, "")
	check_eq(it.run_to_end()["fail_code"], "program_ended", "nothing to do")


func test_runs_are_deterministic() -> void:
	var text := "while not at_exit():\n    if path_ahead():\n        move()\n    else:\n        turn_left()"
	var a := _setup(CORRIDOR, text).run_to_end()
	var b := _setup(CORRIDOR, text).run_to_end()
	check_list(Array(a["trace"]), Array(b["trace"]), "same trace")
	check_eq(a["stamina_spent"], b["stamina_spent"], "same stamina")


func test_editing_after_start_does_not_change_run() -> void:
	var pr := ProgramParser.parse("move()\nmove()\nmove()\nmove()")
	var program: Dictionary = pr["program"]
	var parsed := MazeGrid.from_rows(PackedStringArray(CORRIDOR))
	var world := MazeWorld.new(parsed["grid"], parsed["start"], Tiles.EAST, MazeRules.new(), 50)
	var it := ProgramInterpreter.new(program, world)
	(program["main"] as Array).clear()
	check_eq(it.run_to_end()["status"], "won", "the interpreter has its own copy")
