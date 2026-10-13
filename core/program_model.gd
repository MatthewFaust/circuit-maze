class_name ProgramModel
extends RefCounted
## Helpers for programs stored as plain Dictionaries (JSON- and save-friendly):
##
##   {"version": 1, "main": [node, ...], "functions": {"A": [node, ...], ...}}
##
##   action:  {"id": 3, "type": "move"}    (also turn_left, turn_right, cut, backtrack, scan, scan_weighted)
##   repeat:  {"id", "type": "repeat", "count": 3, "body": [...]}
##   while:   {"id", "type": "while", "cond": {"sensor": "path_ahead", "negate": false}, "body": [...]}
##   if:      {"id", "type": "if", "cond": {...}, "body": [...]}
##   if_else: {"id", "type": "if_else", "cond": {...}, "body": [...], "else_body": [...]}
##   call:    {"id", "type": "call", "fn": "A"}
##
## Ids are numbered in order through the tree by assign_ids() and are stripped
## before saving. Lists are addressed by refs: "main", "fn:A", "<id>:body", "<id>:else".

const VERSION := 1
const ACTIONS := MazeWorld.ACTIONS
const SENSORS := MazeWorld.SENSORS
const CONTAINERS := ["repeat", "while", "if", "if_else"]
const BLOCK_TYPES := [
	"move", "turn_left", "turn_right", "cut", "backtrack", "scan", "scan_weighted",
	"repeat", "while", "if", "if_else", "call",
]
const FUNCTION_NAMES := ["A", "B", "C"]
const MAX_REPEAT := 99


static func empty(function_names: Array = []) -> Dictionary:
	var fns := {}
	for f: String in function_names:
		fns[f] = []
	return {"version": VERSION, "main": [], "functions": fns}


static func action(t: String) -> Dictionary:
	return {"type": t}


static func cond(sensor: String, negate: bool = false) -> Dictionary:
	return {"sensor": sensor, "negate": negate}


static func repeat(count: int, body: Array = []) -> Dictionary:
	return {"type": "repeat", "count": count, "body": body}


static func while_loop(c: Dictionary, body: Array = []) -> Dictionary:
	return {"type": "while", "cond": c, "body": body}


static func if_then(c: Dictionary, body: Array = []) -> Dictionary:
	return {"type": "if", "cond": c, "body": body}


static func if_else(c: Dictionary, body: Array = [], else_body: Array = []) -> Dictionary:
	return {"type": "if_else", "cond": c, "body": body, "else_body": else_body}


static func call_fn(fname: String) -> Dictionary:
	return {"type": "call", "fn": fname}


## A fresh node for a palette entry: "move", "repeat", "while", "call:A", ...
static func new_node(kind: String, default_sensor: String = "path_ahead") -> Dictionary:
	if kind.begins_with("call:"):
		return call_fn(kind.substr(5))
	match kind:
		"repeat":
			return repeat(2)
		"while":
			return while_loop(cond(default_sensor))
		"if":
			return if_then(cond(default_sensor))
		"if_else":
			return if_else(cond(default_sensor))
	return action(kind)


static func is_action(t: String) -> bool:
	return ACTIONS.has(t)


static func has_cond(node: Dictionary) -> bool:
	return node.has("cond")


## Function names in main-then-alphabetical order, as list refs.
static func root_refs(p: Dictionary) -> Array[String]:
	var refs: Array[String] = ["main"]
	var fns: Dictionary = p.get("functions", {})
	var names: Array = fns.keys()
	names.sort()
	for n: String in names:
		refs.append("fn:" + n)
	return refs


## Child list refs of a node: ["<id>:body"] or ["<id>:body", "<id>:else"].
static func child_refs(node: Dictionary) -> Array[String]:
	var refs: Array[String] = []
	var id: int = node.get("id", -1)
	if node.has("body"):
		refs.append("%d:body" % id)
	if node.has("else_body"):
		refs.append("%d:else" % id)
	return refs


static func has_list(p: Dictionary, ref: String) -> bool:
	if ref == "main":
		return true
	if ref.begins_with("fn:"):
		return FUNCTION_NAMES.has(ref.substr(3))
	var parts := ref.split(":")
	if parts.size() != 2 or not parts[0].is_valid_int():
		return false
	var found := find(p, parts[0].to_int())
	if found.is_empty():
		return false
	var node: Dictionary = found["node"]
	return node.has("else_body" if parts[1] == "else" else "body")


## The live Array behind a ref (edits to it change the program). Function slots
## are created on demand. Returns a new empty Array for an invalid ref; check
## has_list() first when that matters.
static func get_list(p: Dictionary, ref: String) -> Array:
	if ref == "main":
		return p["main"]
	if ref.begins_with("fn:"):
		var fns: Dictionary = p["functions"]
		var fname := ref.substr(3)
		if not fns.has(fname):
			fns[fname] = []
		return fns[fname]
	var parts := ref.split(":")
	if parts.size() == 2 and parts[0].is_valid_int():
		var found := find(p, parts[0].to_int())
		if not found.is_empty():
			var node: Dictionary = found["node"]
			var key := "else_body" if parts[1] == "else" else "body"
			if node.has(key):
				return node[key]
	return []


## {"node": Dictionary, "ref": String, "index": int} for the node with this id, or {}.
static func find(p: Dictionary, id: int) -> Dictionary:
	for ref in root_refs(p):
		var r := _find_in(get_list(p, ref), ref, id)
		if not r.is_empty():
			return r
	return {}


static func _find_in(list: Array, ref: String, id: int) -> Dictionary:
	for i in list.size():
		var node: Dictionary = list[i]
		var node_id: int = node.get("id", -1)
		if node_id == id:
			return {"node": node, "ref": ref, "index": i}
		if node.has("body"):
			var r := _find_in(node["body"], "%d:body" % node_id, id)
			if not r.is_empty():
				return r
		if node.has("else_body"):
			var r := _find_in(node["else_body"], "%d:else" % node_id, id)
			if not r.is_empty():
				return r
	return {}


## Numbers every node in order through the tree. Returns the next free id.
static func assign_ids(p: Dictionary) -> int:
	var n := 1
	for ref in root_refs(p):
		n = _assign(get_list(p, ref), n)
	return n


static func _assign(list: Array, n: int) -> int:
	for node: Dictionary in list:
		node["id"] = n
		n += 1
		if node.has("body"):
			n = _assign(node["body"], n)
		if node.has("else_body"):
			n = _assign(node["else_body"], n)
	return n


## Deep copy without ids (for saving and comparing).
static func strip_ids(p: Dictionary) -> Dictionary:
	var q: Dictionary = p.duplicate(true)
	for ref in root_refs(q):
		_strip(get_list(q, ref))
	return q


static func _strip(list: Array) -> void:
	for node: Dictionary in list:
		node.erase("id")
		if node.has("body"):
			_strip(node["body"])
		if node.has("else_body"):
			_strip(node["else_body"])


## Ids stripped and empty function slots removed, so equal programs compare equal.
static func canonical(p: Dictionary) -> Dictionary:
	var q := strip_ids(p)
	var fns: Dictionary = q.get("functions", {})
	for fname: String in fns.keys():
		var body: Array = fns[fname]
		if body.is_empty():
			fns.erase(fname)
	q["functions"] = fns
	q["version"] = VERSION
	return q


## Every block counts 1: actions, calls, repeat/while/if/if_else (else adds
## nothing) and each non-empty function definition. Conditions are free.
static func count_blocks(p: Dictionary) -> int:
	var total := _count(p.get("main", []))
	var fns: Dictionary = p.get("functions", {})
	for fname: String in fns:
		var body: Array = fns[fname]
		if not body.is_empty():
			total += 1 + _count(body)
	return total


static func _count(list: Array) -> int:
	var n := 0
	for node: Dictionary in list:
		n += 1
		if node.has("body"):
			n += _count(node["body"])
		if node.has("else_body"):
			n += _count(node["else_body"])
	return n


## Which blocks and sensors a program uses:
## {"types": {type: n}, "sensors": {sensor: n}, "negated": n, "calls": {fn: n},
##  "defined": [non-empty function names], "max_repeat": n, "min_repeat": n}
static func usage(p: Dictionary) -> Dictionary:
	var u := {"types": {}, "sensors": {}, "negated": 0, "calls": {}, "defined": [],
			"max_repeat": 0, "min_repeat": MAX_REPEAT}
	_usage(p.get("main", []), u)
	var fns: Dictionary = p.get("functions", {})
	for fname: String in fns:
		var body: Array = fns[fname]
		if not body.is_empty():
			var defined: Array = u["defined"]
			defined.append(fname)
			_usage(body, u)
	return u


static func _usage(list: Array, u: Dictionary) -> void:
	var types: Dictionary = u["types"]
	var sensors: Dictionary = u["sensors"]
	var calls: Dictionary = u["calls"]
	for node: Dictionary in list:
		var t: String = node["type"]
		types[t] = int(types.get(t, 0)) + 1
		if node.has("cond"):
			var c: Dictionary = node["cond"]
			var s: String = c["sensor"]
			sensors[s] = int(sensors.get(s, 0)) + 1
			if bool(c.get("negate", false)):
				u["negated"] = int(u["negated"]) + 1
		if t == "call":
			var f: String = node["fn"]
			calls[f] = int(calls.get(f, 0)) + 1
		if t == "repeat":
			var count: int = node["count"]
			u["max_repeat"] = maxi(int(u["max_repeat"]), count)
			u["min_repeat"] = mini(int(u["min_repeat"]), count)
		if node.has("body"):
			_usage(node["body"], u)
		if node.has("else_body"):
			_usage(node["else_body"], u)


static func insert(p: Dictionary, ref: String, index: int, node: Dictionary) -> bool:
	if not has_list(p, ref):
		return false
	var list := get_list(p, ref)
	list.insert(clampi(index, 0, list.size()), node)
	return true


## Removes the node (and everything inside it). Returns it, or {}.
static func remove(p: Dictionary, id: int) -> Dictionary:
	var found := find(p, id)
	if found.is_empty():
		return {}
	var list := get_list(p, found["ref"])
	list.remove_at(found["index"])
	return found["node"]


## Moves a node to (ref, index), where index counts positions in the target
## list as it is before the move. Refuses to move a node into itself.
static func move_node(p: Dictionary, id: int, ref: String, index: int) -> bool:
	var found := find(p, id)
	if found.is_empty() or not has_list(p, ref):
		return false
	var node: Dictionary = found["node"]
	var parts := ref.split(":")
	if parts.size() == 2 and parts[0].is_valid_int():
		var owner_id := parts[0].to_int()
		if owner_id == id or subtree_contains(node, owner_id):
			return false
	var src_ref: String = found["ref"]
	var src_index: int = found["index"]
	var target := get_list(p, ref)
	var source := get_list(p, src_ref)
	if src_ref == ref and src_index < index:
		# Same list: removing the node first shifts later positions up by one.
		index -= 1
	source.remove_at(src_index)
	target.insert(clampi(index, 0, target.size()), node)
	return true


## Is there a node with this id somewhere inside node (not counting node itself)?
static func subtree_contains(node: Dictionary, id: int) -> bool:
	for key in ["body", "else_body"]:
		if node.has(key):
			for child: Dictionary in node[key]:
				if int(child.get("id", -1)) == id or subtree_contains(child, id):
					return true
	return false


## A flat program that replays a fixed list of actions (used to prove that a
## level can't be solved by hard-coding one map's moves).
static func from_actions(actions: PackedStringArray) -> Dictionary:
	var p := empty()
	var main: Array = p["main"]
	for a in actions:
		main.append(action(a))
	return p


## Copies every function body in place of its calls. Returns {} if the
## functions recurse (then there is no finite inlined program).
static func inline_calls(p: Dictionary) -> Dictionary:
	var fns: Dictionary = p.get("functions", {})
	var stack: Array[String] = []
	var result := _inline_list(p.get("main", []), fns, stack)
	if result.is_empty():
		return {}
	var q := empty()
	q["main"] = result["list"]
	return q


static func _inline_list(list: Array, fns: Dictionary, stack: Array[String]) -> Dictionary:
	var out: Array = []
	for node: Dictionary in list:
		var t: String = node["type"]
		if t == "call":
			var f: String = node["fn"]
			if stack.has(f):
				return {}
			stack.append(f)
			var r := _inline_list(fns.get(f, []), fns, stack)
			stack.pop_back()
			if r.is_empty():
				return {}
			out.append_array(r["list"])
			continue
		var copy: Dictionary = node.duplicate(false)
		copy.erase("id")
		for key in ["body", "else_body"]:
			if node.has(key):
				var r := _inline_list(node[key], fns, stack)
				if r.is_empty():
					return {}
				copy[key] = r["list"]
		out.append(copy)
	return {"list": out}


## Cleans a program that came from JSON or a save file: integer-valued floats
## become ints, unknown keys are dropped, invalid nodes are skipped.
## Returns {"program": Dictionary, "errors": Array[String]}.
static func normalize(raw: Variant) -> Dictionary:
	var errors: Array[String] = []
	var p := empty()
	if typeof(raw) != TYPE_DICTIONARY:
		errors.append("program must be a Dictionary")
		return {"program": p, "errors": errors}
	var d: Dictionary = raw
	p["main"] = _normalize_list(d.get("main", []), errors)
	var fns_raw: Variant = d.get("functions", {})
	if typeof(fns_raw) == TYPE_DICTIONARY:
		var fns_in: Dictionary = fns_raw
		var fns: Dictionary = p["functions"]
		for fname: Variant in fns_in:
			if typeof(fname) == TYPE_STRING and FUNCTION_NAMES.has(fname):
				fns[fname] = _normalize_list(fns_in[fname], errors)
			else:
				errors.append("unknown function '%s'" % str(fname))
	return {"program": p, "errors": errors}


static func _normalize_list(raw: Variant, errors: Array[String]) -> Array:
	var out: Array = []
	if typeof(raw) != TYPE_ARRAY:
		errors.append("block list must be an Array")
		return out
	for item: Variant in raw:
		if typeof(item) != TYPE_DICTIONARY:
			errors.append("block must be a Dictionary")
			continue
		var d: Dictionary = item
		var t: String = str(d.get("type", ""))
		if not BLOCK_TYPES.has(t):
			errors.append("unknown block type '%s'" % t)
			continue
		var node := {"type": t}
		match t:
			"repeat":
				node["count"] = clampi(_to_int(d.get("count", 1), 1), 1, MAX_REPEAT)
			"while", "if", "if_else":
				var c: Variant = d.get("cond", {})
				var sensor := "path_ahead"
				var negate := false
				if typeof(c) == TYPE_DICTIONARY:
					var cd: Dictionary = c
					sensor = str(cd.get("sensor", sensor))
					negate = bool(cd.get("negate", false))
				if not SENSORS.has(sensor):
					errors.append("unknown sensor '%s'" % sensor)
					sensor = "path_ahead"
				node["cond"] = cond(sensor, negate)
			"call":
				var f := str(d.get("fn", "A"))
				if not FUNCTION_NAMES.has(f):
					errors.append("unknown function '%s'" % f)
					continue
				node["fn"] = f
		if CONTAINERS.has(t):
			node["body"] = _normalize_list(d.get("body", []), errors)
		if t == "if_else":
			node["else_body"] = _normalize_list(d.get("else_body", []), errors)
		out.append(node)
	return out


static func _to_int(v: Variant, fallback: int) -> int:
	match typeof(v):
		TYPE_INT:
			return v
		TYPE_FLOAT:
			return int(v)
		TYPE_STRING:
			var s: String = v
			return s.to_int() if s.is_valid_int() else fallback
	return fallback
