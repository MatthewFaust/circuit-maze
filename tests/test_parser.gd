extends "res://tests/suite_base.gd"
## ProgramParser and ProgramPrinter: syntax, error messages and round trips.


func _parse(text: String) -> Dictionary:
	var r := ProgramParser.parse(text)
	check(bool(r["ok"]), "should parse: %s\n%s" % [str(r["errors"]), text])
	return r.get("program", {})


func _error_of(text: String) -> String:
	var r := ProgramParser.parse(text)
	if bool(r["ok"]):
		fail("should not parse:\n" + text)
		return ""
	return str(((r["errors"] as Array)[0] as Dictionary)["message"])


func _types(list: Array) -> Array:
	var out: Array = []
	for n: Dictionary in list:
		out.append(n["type"])
	return out


func test_actions_and_loops() -> void:
	var p := _parse("move()\nturn_left()\nfor _ in range(3):\n    move()\n    cut()\nturn_right()")
	check_eq(_types(p["main"]), ["move", "turn_left", "repeat", "turn_right"], "top level")
	var rep: Dictionary = (p["main"] as Array)[2]
	check_eq(rep["count"], 3, "count")
	check_eq(_types(rep["body"]), ["move", "cut"], "body")


func test_repeat_forms_are_equal() -> void:
	var a := _parse("repeat 3:\n    move()")
	var b := _parse("for _ in range(3):\n    move()")
	check(ProgramModel.canonical(a) == ProgramModel.canonical(b), "repeat N == for _ in range(N)")


func test_while_if_elif_else() -> void:
	var p := _parse("while not at_exit():\n    if bush_ahead():\n        cut()\n    elif path_ahead():\n        move()\n    else:\n        turn_left()")
	var w: Dictionary = (p["main"] as Array)[0]
	check_eq(w["type"], "while", "while")
	check_eq((w["cond"] as Dictionary)["negate"], true, "not")
	var outer: Dictionary = (w["body"] as Array)[0]
	check_eq(outer["type"], "if_else", "elif makes an if/else")
	var inner: Dictionary = (outer["else_body"] as Array)[0]
	check_eq(inner["type"], "if_else", "inner if has the final else")
	check_eq((inner["cond"] as Dictionary)["sensor"], "path_ahead", "elif condition")
	check_eq(_types(inner["else_body"]), ["turn_left"], "else body")


func test_inline_suites_semicolons_and_comments() -> void:
	var p := _parse("# a comment\nwhile not at_exit(): move(); turn_left()  # trailing\n\nif bush_ahead(): cut()\nelse: move()")
	var w: Dictionary = (p["main"] as Array)[0]
	check_eq(_types(w["body"]), ["move", "turn_left"], "inline body with ;")
	var i: Dictionary = (p["main"] as Array)[1]
	check_eq(i["type"], "if_else", "inline else attaches")


func test_tabs_count_as_four_spaces() -> void:
	var p := _parse("repeat 2:\n\tmove()\n    turn_left()")
	check_eq(_types((p["main"] as Array)[0]["body"]), ["move", "turn_left"], "tab == 4 spaces")


func test_functions_and_calls() -> void:
	var p := _parse("def B():\n    move()\ndef A():\n    B()\n    turn_left()\nA()\npass")
	check_eq(_types(p["main"]), ["call"], "pass makes nothing")
	var fns: Dictionary = p["functions"]
	check_eq(_types(fns["A"]), ["call", "turn_left"], "A calls B")
	check_eq(_types(fns["B"]), ["move"], "B")


func test_error_messages() -> void:
	var cases := [
		["move", "missing '()' after 'move'"],
		["while path_ahead()\n    move()", "missing ':'"],
		["    move()", "unexpected indent"],
		["while path_ahead():\nmove()", "expected an indented block after 'while' on line 1"],
		["repeat 2:\n        move()\n    move()", "unindent does not match"],
		["mvoe()", "did you mean 'move()'"],
		["if bush_ahaed():\n    cut()", "did you mean 'bush_ahead()'"],
		["path_ahead()", "is a sensor"],
		["while move():\n    move()", "is an action"],
		["else:\n    move()", "'else' must follow an 'if'"],
		["move()\nelif path_ahead():\n    move()", "'elif' must follow an 'if'"],
		["repeat 2:\n    def A():\n        move()", "only allowed at the top level"],
		["A()", "never defined"],
		["repeat 0:\n    move()", "between 1 and 99"],
		["def X():\n    move()", "must be A, B or C"],
		["def A():\n    move()\ndef A():\n    move()", "defined twice"],
		["if path_ahead():", "expected an indented block after 'if' on line 1"],
	]
	for c: Array in cases:
		var text: String = c[0]
		var expected: String = c[1]
		var msg := _error_of(text)
		check(msg.contains(expected), "for %s expected '%s' in '%s'" % [text.c_escape(), expected, msg])


func test_error_reports_line_number() -> void:
	var r := ProgramParser.parse("move()\nmove()\nfly()")
	check_eq(((r["errors"] as Array)[0] as Dictionary)["line"], 3, "line 3")


func test_printer_output() -> void:
	var p := _parse("def A():\n    move()\nrepeat 2:\n    A()\nif bush_ahead():\n    cut()\nelse:\n    if path_left():\n        turn_left()")
	var expected := "def A():\n    move()\n\nfor _ in range(2):\n    A()\nif bush_ahead():\n    cut()\nelif path_left():\n    turn_left()"
	check_eq(ProgramPrinter.to_text(p), expected, "printed text")


func test_printer_line_map() -> void:
	var p := _parse("def A():\n    move()\nA()\nwhile path_ahead():\n    move()")
	var r := ProgramPrinter.render(p)
	var line_of: Dictionary = r["line_of"]
	# Ids: main A() = 1, while = 2, its move = 3; A's move = 4. Lines: 0 def, 1 move, 2 blank, 3 A(), 4 while, 5 move.
	check_eq(line_of[1], 3, "call line")
	check_eq(line_of[2], 4, "while line")
	check_eq(line_of[3], 5, "body line")
	check_eq(line_of[4], 1, "function body line")


func test_empty_bodies_print_pass() -> void:
	var p := ProgramModel.empty()
	(p["main"] as Array).append(ProgramModel.while_loop(ProgramModel.cond("path_ahead")))
	(p["main"] as Array).append(ProgramModel.if_else(ProgramModel.cond("bush_ahead")))
	var text := ProgramPrinter.to_text(p)
	check_eq(text, "while path_ahead():\n    pass\nif bush_ahead():\n    pass\nelse:\n    pass", "pass for empty bodies")
	var back := _parse(text)
	check(ProgramModel.canonical(back) == ProgramModel.canonical(p), "round trip of empty bodies")


func test_round_trip_texts() -> void:
	var texts := [
		"move()",
		"for _ in range(3):\n    move()\n    turn_left()",
		"while not at_exit():\n    if bush_ahead():\n        cut()\n    elif path_ahead():\n        move()\n    else:\n        turn_left()",
		"def A():\n    if path_ahead():\n        move()\n        A()\n        move()\n    else:\n        turn_left()\n\nA()\nturn_right()\nmove()",
		"scan()\nwhile not at_exit():\n    if closer_ahead():\n        move()\n    elif closer_left():\n        turn_left()\n    else:\n        turn_right()",
	]
	for t: String in texts:
		var p := _parse(t)
		check_eq(ProgramPrinter.to_text(p), t, "canonical text survives a round trip")


func test_round_trip_random_programs() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261013
	for i in 200:
		var p := ProgramModel.empty()
		p["main"] = _random_list(rng, 0, true)
		var fns: Dictionary = p["functions"]
		fns["A"] = _random_list(rng, 1, false)
		fns["B"] = _random_list(rng, 1, false)
		ProgramModel.assign_ids(p)
		var text := ProgramPrinter.to_text(p)
		var r := ProgramParser.parse(text)
		if not check(bool(r["ok"]), "random program %d didn't parse: %s\n%s" % [i, str(r["errors"]), text]):
			return
		if not check(ProgramModel.canonical(r["program"]) == ProgramModel.canonical(p),
				"random program %d changed in the round trip:\n%s" % [i, text]):
			return


func _random_list(rng: RandomNumberGenerator, depth: int, allow_calls: bool) -> Array:
	var out: Array = []
	var n := rng.randi_range(0 if depth > 0 else 1, 3)
	for i in n:
		var roll := rng.randi_range(0, 9)
		var sensor: String = ProgramModel.SENSORS[rng.randi_range(0, ProgramModel.SENSORS.size() - 1)]
		var c := ProgramModel.cond(sensor, rng.randi_range(0, 1) == 1)
		if depth >= 3 or roll < 4:
			out.append(ProgramModel.action(ProgramModel.ACTIONS[rng.randi_range(0, ProgramModel.ACTIONS.size() - 1)]))
		elif roll == 4 and allow_calls:
			out.append(ProgramModel.call_fn(["A", "B"][rng.randi_range(0, 1)]))
		elif roll == 5:
			out.append(ProgramModel.repeat(rng.randi_range(1, 99), _random_list(rng, depth + 1, allow_calls)))
		elif roll == 6:
			out.append(ProgramModel.while_loop(c, _random_list(rng, depth + 1, allow_calls)))
		elif roll == 7:
			out.append(ProgramModel.if_then(c, _random_list(rng, depth + 1, allow_calls)))
		else:
			out.append(ProgramModel.if_else(c, _random_list(rng, depth + 1, allow_calls),
					_random_list(rng, depth + 1, allow_calls)))
	return out
