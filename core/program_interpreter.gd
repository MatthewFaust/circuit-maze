class_name ProgramInterpreter
extends RefCounted
## Runs a program against a MazeWorld one action at a time, so the UI can
## animate, pause and highlight each step. Uses an explicit frame stack rather
## than GDScript recursion: a runaway recursion in the player's program becomes
## a "stack overflow" failure instead of crashing the game, and the stack can
## be shown in the inspector.

const K_MAIN := 0
const K_BODY := 1
const K_REPEAT := 2
const K_WHILE := 3
const K_CALL := 4
const MAX_CHECKS := 32


class Frame:
	var kind: int = 0
	var nodes: Array = []
	var pc: int = 0
	## Id of the block that owns this body (-1 for main).
	var owner_id: int = -1
	var iteration: int = 0
	var total: int = 0
	var cond: Dictionary = {}
	var func_name: String = ""


var world: MazeWorld
var rules: MazeRules
var ops := 0
var actions := 0
var call_depth := 0
var peak_call_depth := 0
var finished := false
## Every action executed, in order.
var trace := PackedStringArray()
var _functions: Dictionary = {}
var _stack: Array[Frame] = []


func _init(program: Dictionary, p_world: MazeWorld) -> void:
	world = p_world
	rules = p_world.rules
	# A private copy: editing the program while it runs can't affect the run.
	var p: Dictionary = program.duplicate(true)
	_functions = p.get("functions", {})
	var root := Frame.new()
	root.kind = K_MAIN
	root.nodes = p.get("main", [])
	_stack.append(root)


## Runs until one action has executed (or the run ends) and returns
## {status, action, node_id, events, checks, active_ids, call_stack, loops,
##  ops, actions, fail_code, message}.
func step() -> Dictionary:
	var checks: Array[Dictionary] = []
	var no_events: Array[Dictionary] = []
	if finished or not world.is_running():
		finished = true
		return _result("", -1, no_events, checks)
	var idle := 0
	while true:
		ops += 1
		idle += 1
		if ops > rules.max_ops:
			return _abort("op_limit", "Stopped after %d operations without reaching the exit. Is a loop running forever?"
					% rules.max_ops, checks)
		if idle > rules.max_idle_ops:
			return _abort("idle_loop", "%d checks in a row without a single action: a loop is spinning without doing anything. Does its body contain an action, and can its condition change?"
					% rules.max_idle_ops, checks)
		if _stack.is_empty():
			return _abort("program_ended", "The program finished, but the boss is still standing."
					if world.is_boss_stage() else "The program finished, but the robot isn't on the exit.", checks)
		var f: Frame = _stack.back()
		if f.pc >= f.nodes.size():
			# End of a body: loop again or return to the enclosing frame.
			if f.kind == K_REPEAT:
				f.iteration += 1
				if f.iteration < f.total:
					f.pc = 0
					continue
			elif f.kind == K_WHILE:
				if _check(f.cond, f.owner_id, checks):
					f.iteration += 1
					f.pc = 0
					continue
			elif f.kind == K_CALL:
				call_depth -= 1
			_stack.pop_back()
			continue
		var node: Dictionary = f.nodes[f.pc]
		f.pc += 1
		var t: String = node["type"]
		var id: int = node.get("id", -1)
		if t == "repeat":
			var n: int = node["count"]
			if n > 0:
				var rf := _push(K_REPEAT, node["body"], id)
				rf.total = n
		elif t == "while":
			if _check(node["cond"], id, checks):
				var wf := _push(K_WHILE, node["body"], id)
				wf.cond = node["cond"]
		elif t == "if" or t == "if_else":
			if _check(node["cond"], id, checks):
				_push(K_BODY, node["body"], id)
			elif t == "if_else":
				_push(K_BODY, node["else_body"], id)
		elif t == "call":
			var fname: String = node["fn"]
			if call_depth >= rules.max_call_depth:
				return _abort("stack_overflow", "Stack overflow: function %s was called %d levels deep. Does the recursion have a base case that stops it?"
						% [fname, rules.max_call_depth], checks)
			call_depth += 1
			peak_call_depth = maxi(peak_call_depth, call_depth)
			var cf := _push(K_CALL, _functions.get(fname, []), id)
			cf.func_name = fname
		else:
			actions += 1
			if actions > rules.max_actions:
				return _abort("action_limit", "%d actions without reaching the exit. Is a loop running forever?"
						% rules.max_actions, checks)
			trace.append(t)
			var events := world.apply_action(t)
			if not world.is_running():
				finished = true
			return _result(t, id, events, checks)
	return {}


## Steps until the run ends. Always terminates: every step either performs an
## action (capped by max_actions) or spends operations (capped by max_ops).
func run_to_end() -> Dictionary:
	while not finished:
		step()
	return summary()


func summary() -> Dictionary:
	return {
		"status": world.status_name(),
		"won": world.status == MazeWorld.Status.WON,
		"fail_code": world.fail_code,
		"message": world.fail_message,
		"actions": actions,
		"ops": ops,
		"stamina_spent": world.stamina_spent,
		"hp": world.robot.hp,
		"trace": trace,
		"peak_call_depth": peak_call_depth,
		"peak_trail": world.peak_trail,
	}


## Ids of the blocks that own the open frames, outermost first. Includes the
## call block that entered the current function.
func active_ids() -> PackedInt32Array:
	var ids := PackedInt32Array()
	for f in _stack:
		if f.owner_id >= 0:
			ids.append(f.owner_id)
	return ids


func call_stack() -> PackedStringArray:
	var names := PackedStringArray(["main"])
	for f in _stack:
		if f.kind == K_CALL:
			names.append(f.func_name)
	return names


## [{"id", "iteration" (1-based), "total" (0 for while)}] for the open loops.
func loop_states() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for f in _stack:
		if f.kind == K_REPEAT or f.kind == K_WHILE:
			out.append({"id": f.owner_id, "iteration": f.iteration + 1, "total": f.total})
	return out


func _push(kind: int, nodes: Array, owner_id: int) -> Frame:
	var f := Frame.new()
	f.kind = kind
	f.nodes = nodes
	f.owner_id = owner_id
	_stack.append(f)
	return f


func _check(c: Dictionary, owner_id: int, checks: Array[Dictionary]) -> bool:
	var sensor: String = c["sensor"]
	var negate: bool = c.get("negate", false)
	var value := world.sense(sensor) != negate
	checks.append({"id": owner_id, "sensor": sensor, "negate": negate, "value": value})
	if checks.size() > MAX_CHECKS:
		checks.pop_front()
	return value


func _abort(code: String, message: String, checks: Array[Dictionary]) -> Dictionary:
	finished = true
	var events := world.fail(code, message)
	return _result("", -1, events, checks)


func _result(action: String, node_id: int, events: Array[Dictionary], checks: Array[Dictionary]) -> Dictionary:
	return {
		"status": world.status_name(),
		"action": action,
		"node_id": node_id,
		"events": events,
		"checks": checks,
		"active_ids": active_ids(),
		"call_stack": call_stack(),
		"loops": loop_states(),
		"ops": ops,
		"actions": actions,
		"fail_code": world.fail_code,
		"message": world.fail_message,
	}
