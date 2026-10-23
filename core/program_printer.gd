class_name ProgramPrinter
extends RefCounted
## Prints a program as Python-like text: functions first, then main.
## repeat prints as "for _ in range(N):", and an else that holds a single if
## prints as "elif". ProgramParser reads this text back to the same program.
##
## render_js() prints the same program as JavaScript for the code view. It is
## for reading only; nothing parses it back.

const INDENT := "    "
const JS_INDENT := "  "
## Loop counters for nested repeats in JavaScript: i, then j, then k...
const JS_LOOP_VARS := ["i", "j", "k", "m", "n"]


static func to_text(p: Dictionary) -> String:
	return render(p)["text"]


## {"text": String, "line_of": {node id: 0-based line}} so the code view can
## highlight the line of the block that is running.
static func render(p: Dictionary) -> Dictionary:
	var lines := PackedStringArray()
	var line_of := {}
	var fns: Dictionary = p.get("functions", {})
	var called: Dictionary = ProgramModel.usage(p)["calls"]
	var names: Array = fns.keys()
	names.sort()
	for fname: String in names:
		var body: Array = fns[fname]
		if body.is_empty() and not called.has(fname):
			continue
		lines.append("def %s():" % fname)
		_emit_list(body, 1, lines, line_of)
		lines.append("")
	_emit_list(p.get("main", []), 0, lines, line_of)
	while lines.size() > 0 and lines[lines.size() - 1] == "":
		lines.remove_at(lines.size() - 1)
	return {"text": "\n".join(lines), "line_of": line_of}


## The program as JavaScript: {"text": String, "line_of": {node id: 0-based line}},
## like render(). repeat N prints as a counted for loop, "not" as "!", and an
## else that holds a single if as "} else if (...) {".
static func render_js(p: Dictionary) -> Dictionary:
	var lines := PackedStringArray()
	var line_of := {}
	var fns: Dictionary = p.get("functions", {})
	var called: Dictionary = ProgramModel.usage(p)["calls"]
	var names: Array = fns.keys()
	names.sort()
	for fname: String in names:
		var body: Array = fns[fname]
		if body.is_empty() and not called.has(fname):
			continue
		lines.append("function %s() {" % fname)
		_emit_js_list(body, 1, 0, lines, line_of)
		lines.append("}")
		lines.append("")
	_emit_js_list(p.get("main", []), 0, 0, lines, line_of)
	while lines.size() > 0 and lines[lines.size() - 1] == "":
		lines.remove_at(lines.size() - 1)
	return {"text": "\n".join(lines), "line_of": line_of}


static func cond_js(c: Dictionary) -> String:
	var negate: bool = c.get("negate", false)
	return ("!" if negate else "") + str(c.get("sensor", "?")) + "()"


## loops: how many repeats enclose this list, to pick the next loop counter.
static func _emit_js_list(list: Array, depth: int, loops: int, lines: PackedStringArray, line_of: Dictionary) -> void:
	for node: Dictionary in list:
		_emit_js_node(node, depth, loops, lines, line_of)


static func _emit_js_node(node: Dictionary, depth: int, loops: int, lines: PackedStringArray, line_of: Dictionary) -> void:
	var prefix := JS_INDENT.repeat(depth)
	var id: int = node.get("id", -1)
	if id >= 0:
		line_of[id] = lines.size()
	var t: String = node["type"]
	match t:
		"call":
			lines.append(prefix + str(node["fn"]) + "();")
		"repeat":
			var v: String = JS_LOOP_VARS[loops] if loops < JS_LOOP_VARS.size() else "i%d" % (loops + 1)
			lines.append(prefix + "for (let %s = 0; %s < %d; %s++) {" % [v, v, int(node["count"]), v])
			_emit_js_list(node["body"], depth + 1, loops + 1, lines, line_of)
			lines.append(prefix + "}")
		"while":
			lines.append(prefix + "while (" + cond_js(node["cond"]) + ") {")
			_emit_js_list(node["body"], depth + 1, loops, lines, line_of)
			lines.append(prefix + "}")
		"if", "if_else":
			lines.append(prefix + "if (" + cond_js(node["cond"]) + ") {")
			_emit_js_list(node["body"], depth + 1, loops, lines, line_of)
			var current := node
			# Follow the else chain: an else holding one if prints as "else if".
			while str(current["type"]) == "if_else":
				var else_body: Array = current["else_body"]
				var inner: Dictionary = else_body[0] if else_body.size() == 1 else {}
				var it: String = inner.get("type", "")
				if it == "if" or it == "if_else":
					var inner_id: int = inner.get("id", -1)
					if inner_id >= 0:
						line_of[inner_id] = lines.size()
					lines.append(prefix + "} else if (" + cond_js(inner["cond"]) + ") {")
					_emit_js_list(inner["body"], depth + 1, loops, lines, line_of)
					current = inner
				else:
					lines.append(prefix + "} else {")
					_emit_js_list(else_body, depth + 1, loops, lines, line_of)
					break
			lines.append(prefix + "}")
		_:
			lines.append(prefix + t + "();")


## The program as the block editor shows it: main first, then each function
## that has blocks, with "repeat N times", "while ...", "if ..." / "else" and
## calls as "A()". Used for the full-solution hint.
static func block_text(p: Dictionary) -> String:
	var lines := PackedStringArray()
	var fns: Dictionary = p.get("functions", {})
	var names: Array = fns.keys().filter(func(f: String) -> bool: return not (fns[f] as Array).is_empty())
	names.sort()
	var depth := 0
	if not names.is_empty():
		lines.append("Program (main):")
		depth = 1
	_emit_blocks(p.get("main", []), depth, lines)
	for fname: String in names:
		lines.append("define %s():" % fname)
		_emit_blocks(fns[fname], 1, lines)
	return "\n".join(lines)


static func _emit_blocks(list: Array, depth: int, lines: PackedStringArray) -> void:
	var prefix := INDENT.repeat(depth)
	if list.is_empty():
		lines.append(prefix + "(empty)")
		return
	for node: Dictionary in list:
		var t: String = node["type"]
		match t:
			"call":
				lines.append(prefix + str(node["fn"]) + "()")
			"repeat":
				lines.append(prefix + "repeat %d times" % int(node["count"]))
				_emit_blocks(node["body"], depth + 1, lines)
			"while", "if", "if_else":
				lines.append(prefix + ("while " if t == "while" else "if ") + cond_text(node["cond"]))
				_emit_blocks(node["body"], depth + 1, lines)
				if t == "if_else":
					lines.append(prefix + "else")
					_emit_blocks(node["else_body"], depth + 1, lines)
			_:
				lines.append(prefix + t + "()")


static func cond_text(c: Dictionary) -> String:
	var negate: bool = c.get("negate", false)
	return ("not " if negate else "") + str(c.get("sensor", "?")) + "()"


static func _emit_list(list: Array, depth: int, lines: PackedStringArray, line_of: Dictionary) -> void:
	if list.is_empty():
		if depth > 0:
			lines.append(INDENT.repeat(depth) + "pass")
		return
	for node: Dictionary in list:
		_emit_node(node, depth, lines, line_of)


static func _emit_node(node: Dictionary, depth: int, lines: PackedStringArray, line_of: Dictionary) -> void:
	var prefix := INDENT.repeat(depth)
	var id: int = node.get("id", -1)
	if id >= 0:
		line_of[id] = lines.size()
	var t: String = node["type"]
	match t:
		"call":
			lines.append(prefix + str(node["fn"]) + "()")
		"repeat":
			lines.append(prefix + "for _ in range(%d):" % int(node["count"]))
			_emit_list(node["body"], depth + 1, lines, line_of)
		"while":
			lines.append(prefix + "while " + cond_text(node["cond"]) + ":")
			_emit_list(node["body"], depth + 1, lines, line_of)
		"if", "if_else":
			lines.append(prefix + "if " + cond_text(node["cond"]) + ":")
			_emit_list(node["body"], depth + 1, lines, line_of)
			if t == "if_else":
				_emit_else(node["else_body"], depth, lines, line_of)
		_:
			lines.append(prefix + t + "()")


## Prints "elif" for an else that holds exactly one if, otherwise "else:".
static func _emit_else(else_body: Array, depth: int, lines: PackedStringArray, line_of: Dictionary) -> void:
	var prefix := INDENT.repeat(depth)
	if else_body.size() == 1:
		var inner: Dictionary = else_body[0]
		var it: String = inner["type"]
		if it == "if" or it == "if_else":
			var id: int = inner.get("id", -1)
			if id >= 0:
				line_of[id] = lines.size()
			lines.append(prefix + "elif " + cond_text(inner["cond"]) + ":")
			_emit_list(inner["body"], depth + 1, lines, line_of)
			if it == "if_else":
				_emit_else(inner["else_body"], depth, lines, line_of)
			return
	lines.append(prefix + "else:")
	_emit_list(else_body, depth + 1, lines, line_of)
