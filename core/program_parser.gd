class_name ProgramParser
extends RefCounted
## Parses the Python-like text form into a program Dictionary.
##
##   def A():                         define a function (top level only; A, B or C)
##   for _ in range(N):  /  repeat N:  loop N times (1..99)
##   while [not] sensor():
##   if [not] sensor():  /  elif [not] sensor():  /  else:
##   move()  turn_left()  cut() ...    actions
##   A()                               call a function
##   pass                              an empty body
##   # comment
##
## Indents are 4 spaces (a tab counts as 4). A compound header can carry simple
## statements after its colon ("while not at_exit(): move()"), and simple
## statements can be joined with ";". Stops at the first error.

static var _regex_cache := {}


## {"ok": bool, "program": Dictionary, "errors": [{"line": int, "message": String}]}
static func parse(text: String) -> Dictionary:
	var p := ProgramModel.empty()
	var fns: Dictionary = p["functions"]
	var def_lines := {}
	var calls: Array[Dictionary] = []
	var lines := text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
	# Each context is an open block: {"indent", "list", "tail" (last if, for elif/else)}.
	var stack: Array[Dictionary] = [{"indent": 0, "list": p["main"], "tail": null}]
	var pending := {}

	for i in lines.size():
		var lineno := i + 1
		var raw: String = lines[i].replace("\t", "    ")
		var hash_at := raw.find("#")
		if hash_at >= 0:
			raw = raw.substr(0, hash_at)
		var content := raw.strip_edges()
		if content == "":
			continue
		var indent := raw.length() - raw.lstrip(" ").length()

		var ctx: Dictionary = stack.back()
		if not pending.is_empty():
			if indent <= int(ctx["indent"]):
				return _error(lineno, "expected an indented block after '%s' on line %d"
						% [pending["what"], pending["line"]])
			stack.append({"indent": indent, "list": pending["list"], "tail": null})
			pending = {}
			ctx = stack.back()
		elif indent > int(ctx["indent"]):
			return _error(lineno, "unexpected indent")
		else:
			while stack.size() > 1 and indent < int(stack.back()["indent"]):
				stack.pop_back()
			ctx = stack.back()
			if indent != int(ctx["indent"]):
				return _error(lineno, "unindent does not match any outer indentation level")

		var colon := content.find(":")
		var head := content if colon < 0 else content.substr(0, colon).strip_edges()
		var rest := "" if colon < 0 else content.substr(colon + 1).strip_edges()
		var word := _first_word(head)
		var list: Array = ctx["list"]

		if not ["def", "for", "repeat", "while", "if", "elif", "else"].has(word):
			if colon >= 0:
				return _error(lineno, "unexpected ':' in '%s'" % content)
			var err := _parse_simple_into(content, list, lineno, calls)
			if err != "":
				return _error(lineno, err)
			ctx["tail"] = null
			continue

		if colon < 0:
			return _error(lineno, "missing ':' at the end of '%s'" % content)
		var target: Array = []
		if word == "def":
			if stack.size() > 1 or indent != 0:
				return _error(lineno, "'def' is only allowed at the top level")
			var m := _re("^def\\s+([A-Za-z_]\\w*)\\s*\\(\\s*\\)$").search(head)
			if m == null:
				return _error(lineno, "a function definition looks like 'def A():'")
			var fname := m.get_string(1)
			if not ProgramModel.FUNCTION_NAMES.has(fname):
				return _error(lineno, "function names must be A, B or C, not '%s'" % fname)
			if def_lines.has(fname):
				return _error(lineno, "function %s is defined twice (lines %d and %d)"
						% [fname, def_lines[fname], lineno])
			def_lines[fname] = lineno
			fns[fname] = target
			ctx["tail"] = null
		elif word == "for" or word == "repeat":
			var m: RegExMatch
			if word == "for":
				m = _re("^for\\s+_\\s+in\\s+range\\s*\\(\\s*(\\d+)\\s*\\)$").search(head)
			else:
				m = _re("^repeat\\s+(\\d+)$").search(head)
			if m == null:
				return _error(lineno, "a loop looks like 'for _ in range(3):' or 'repeat 3:'")
			var count := m.get_string(1).to_int()
			if count < 1 or count > ProgramModel.MAX_REPEAT:
				return _error(lineno, "repeat count must be between 1 and %d" % ProgramModel.MAX_REPEAT)
			var node := ProgramModel.repeat(count, target)
			list.append(node)
			ctx["tail"] = null
		elif word == "while" or word == "if" or word == "elif":
			var r := _parse_cond(head.substr(word.length()).strip_edges())
			if r.has("error"):
				return _error(lineno, r["error"])
			var c: Dictionary = r["cond"]
			if word == "while":
				list.append(ProgramModel.while_loop(c, target))
				ctx["tail"] = null
			elif word == "if":
				var node := ProgramModel.if_then(c, target)
				list.append(node)
				ctx["tail"] = node
			else:
				var tail: Variant = ctx["tail"]
				if typeof(tail) != TYPE_DICTIONARY:
					return _error(lineno, "'elif' must follow an 'if' at the same indentation")
				var outer: Dictionary = tail
				var inner := ProgramModel.if_then(c, target)
				outer["type"] = "if_else"
				outer["else_body"] = [inner]
				ctx["tail"] = inner
		else:
			if head != "else":
				return _error(lineno, "'else' takes no condition; did you mean 'elif'?")
			var tail: Variant = ctx["tail"]
			if typeof(tail) != TYPE_DICTIONARY:
				return _error(lineno, "'else' must follow an 'if' or 'elif' at the same indentation")
			var outer: Dictionary = tail
			outer["type"] = "if_else"
			outer["else_body"] = target
			ctx["tail"] = null

		if rest != "":
			var err := _parse_simple_into(rest, target, lineno, calls)
			if err != "":
				return _error(lineno, err)
		else:
			pending = {"list": target, "line": lineno, "what": word}

	if not pending.is_empty():
		return _error(int(pending["line"]), "expected an indented block after '%s' on line %d"
				% [pending["what"], pending["line"]])
	for c in calls:
		if not fns.has(c["fn"]):
			return _error(int(c["line"]), "function %s() is called but never defined" % c["fn"])
	ProgramModel.assign_ids(p)
	return {"ok": true, "program": p, "errors": []}


## Parses one or more ";"-separated simple statements into list. Returns "" or an error.
static func _parse_simple_into(text: String, list: Array, lineno: int, calls: Array[Dictionary]) -> String:
	for part in text.split(";"):
		var s := part.strip_edges()
		if s == "" or s == "pass":
			continue
		var m := _re("^([A-Za-z_]\\w*)\\s*\\(\\s*\\)$").search(s)
		if m == null:
			var bare := _re("^([A-Za-z_]\\w*)$").search(s)
			if bare != null:
				return "missing '()' after '%s'" % bare.get_string(1)
			return "can't understand '%s'" % s
		var name := m.get_string(1)
		if ProgramModel.ACTIONS.has(name):
			list.append(ProgramModel.action(name))
		elif ProgramModel.FUNCTION_NAMES.has(name):
			list.append(ProgramModel.call_fn(name))
			calls.append({"fn": name, "line": lineno})
		elif ProgramModel.SENSORS.has(name):
			return "'%s()' is a sensor: use it as an if or while condition" % name
		else:
			return "unknown action '%s()'%s" % [name, _suggest(name, ProgramModel.ACTIONS)]
	return ""


## {"cond": Dictionary} or {"error": String}
static func _parse_cond(text: String) -> Dictionary:
	var m := _re("^(not\\s+)?([A-Za-z_]\\w*)\\s*\\(\\s*\\)$").search(text)
	if m == null:
		var bare := _re("^(not\\s+)?([A-Za-z_]\\w*)$").search(text)
		if bare != null:
			return {"error": "missing '()' after '%s'" % bare.get_string(2)}
		if text == "":
			return {"error": "missing condition"}
		return {"error": "a condition is one sensor, optionally with 'not', e.g. 'not at_exit()'"}
	var sensor := m.get_string(2)
	if not ProgramModel.SENSORS.has(sensor):
		if ProgramModel.ACTIONS.has(sensor):
			return {"error": "'%s()' is an action; a condition must be a sensor such as path_ahead()" % sensor}
		return {"error": "unknown sensor '%s()'%s" % [sensor, _suggest(sensor, ProgramModel.SENSORS)]}
	return {"cond": ProgramModel.cond(sensor, m.get_string(1) != "")}


static func _first_word(s: String) -> String:
	var m := _re("^([A-Za-z_]\\w*)").search(s)
	return "" if m == null else m.get_string(1)


## Suggests the closest known name for a typo (up to 2 edits, swaps count as 1).
static func _suggest(name: String, candidates: Array) -> String:
	var best := ""
	var best_distance := mini(2, maxi(1, floori(name.length() / 3.0)))
	for c: String in candidates:
		var d := _edit_distance(name, c)
		if d <= best_distance and (best == "" or d < _edit_distance(name, best)):
			best = c
	return "" if best == "" else "; did you mean '%s()'?" % best


## Optimal string alignment distance: insertions, deletions, substitutions and
## swaps of two neighboring letters each cost 1.
static func _edit_distance(a: String, b: String) -> int:
	var n := a.length()
	var m := b.length()
	var d: Array[PackedInt32Array] = []
	for i in n + 1:
		var row := PackedInt32Array()
		row.resize(m + 1)
		row[0] = i
		d.append(row)
	for j in m + 1:
		d[0][j] = j
	for i in range(1, n + 1):
		for j in range(1, m + 1):
			var cost := 0 if a[i - 1] == b[j - 1] else 1
			var best := mini(mini(d[i - 1][j] + 1, d[i][j - 1] + 1), d[i - 1][j - 1] + cost)
			if i > 1 and j > 1 and a[i - 1] == b[j - 2] and a[i - 2] == b[j - 1]:
				best = mini(best, d[i - 2][j - 2] + 1)
			d[i][j] = best
	return d[n][m]


static func _re(pattern: String) -> RegEx:
	if not _regex_cache.has(pattern):
		_regex_cache[pattern] = RegEx.create_from_string(pattern)
	return _regex_cache[pattern]


static func _error(line: int, message: String) -> Dictionary:
	return {"ok": false, "program": {}, "errors": [{"line": line, "message": "line %d: %s" % [line, message]}]}
