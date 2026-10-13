class_name MazeWorld
extends RefCounted
## The simulation: grid + robot + the robot's memory (visited tiles, breadcrumb
## trail, scan numbers). apply_action() runs one action and returns events
## (Dictionaries with a "type" key) for the views to animate.
##
## Order of checks for an action: enough stamina? -> pay -> effect ->
## HP <= 0 fails -> standing on the exit wins.

enum Status { RUNNING, WON, FAILED }

const ACTIONS := ["move", "turn_left", "turn_right", "cut", "backtrack", "scan", "scan_weighted"]
const SENSORS := [
	"path_ahead", "path_left", "path_right", "bush_ahead", "stone_ahead", "spike_ahead",
	"at_exit", "unvisited_ahead", "unvisited_left", "unvisited_right",
	"closer_ahead", "closer_left", "closer_right",
]

var grid: MazeGrid
var robot: RobotState
var rules: MazeRules
var exits: Array[Vector2i] = []
var start := Vector2i.ZERO
var start_facing: int = Tiles.EAST
var status: Status = Status.RUNNING
var fail_code := ""
var fail_message := ""
## Sum of all action costs. Batteries don't reduce it.
var stamina_spent := 0
var actions_taken := 0
var visited := PackedByteArray()
## Breadcrumb stack (DFS): move() pushes the tile it leaves, backtrack() pops.
var trail: Array[Vector2i] = []
var peak_trail := 0
## Last scan result from MazePathing.distance_field(), frozen until the next scan.
var scan := {}
var fog := false
var revealed := PackedByteArray()


func _init(p_grid: MazeGrid, p_start: Vector2i, p_facing: int, p_rules: MazeRules,
		p_stamina: int, p_fog: bool = false) -> void:
	grid = p_grid
	rules = p_rules
	start = p_start
	start_facing = posmod(p_facing, 4)
	robot = RobotState.new()
	robot.pos = p_start
	robot.facing = start_facing
	robot.max_hp = rules.max_hp
	robot.hp = rules.max_hp
	robot.max_stamina = p_stamina
	robot.stamina = p_stamina
	exits = grid.find_all(Tiles.EXIT)
	visited.resize(grid.size())
	visited[grid.index_of(p_start)] = 1
	fog = p_fog
	revealed.resize(grid.size())
	if fog:
		var ignored: Array[Dictionary] = []
		_reveal_around(p_start, ignored)
		for e in exits:
			revealed[grid.index_of(e)] = 1
	else:
		revealed.fill(1)


func is_running() -> bool:
	return status == Status.RUNNING


func status_name() -> String:
	match status:
		Status.WON:
			return "won"
		Status.FAILED:
			return "failed"
	return "running"


## Stamina the action would cost right now (backtrack depends on facing).
func cost_of(action: String) -> int:
	match action:
		"move":
			return rules.move_cost
		"turn_left", "turn_right":
			return rules.turn_cost
		"cut":
			return rules.cut_cost
		"scan", "scan_weighted":
			return rules.scan_cost
		"backtrack":
			return rules.backtrack_cost + _backtrack_turns() * rules.turn_cost
	return 0


func apply_action(action: String) -> Array[Dictionary]:
	var ev: Array[Dictionary] = []
	if status != Status.RUNNING:
		return ev
	if not ACTIONS.has(action):
		return fail("unknown_action", "Unknown action '%s'." % action)
	if action == "backtrack" and trail.is_empty():
		return fail("backtrack_empty",
				"backtrack() with an empty breadcrumb stack: there is nowhere left to go back to.")
	var cost := cost_of(action)
	if robot.stamina < cost:
		return fail("no_stamina", "Out of stamina: %s() needs %d, but only %d is left."
				% [action, cost, robot.stamina])
	stamina_spent += cost
	actions_taken += 1
	_change_stamina(-cost, action, ev)
	match action:
		"move":
			_do_move(ev)
		"turn_left":
			_do_turn(-1, ev)
		"turn_right":
			_do_turn(1, ev)
		"cut":
			_do_cut(ev)
		"backtrack":
			_do_backtrack(ev)
		"scan":
			_do_scan(false, ev)
		"scan_weighted":
			_do_scan(true, ev)
	if robot.hp <= 0:
		ev.append_array(fail("hp_zero", "The robot was destroyed: HP reached 0."))
	elif grid.get_tile(robot.pos) == Tiles.EXIT:
		status = Status.WON
		ev.append({"type": "won", "cell": robot.pos})
	return ev


## Ends the run as a failure. Also used by the interpreter (infinite loops etc.).
func fail(code: String, message: String) -> Array[Dictionary]:
	var ev: Array[Dictionary] = []
	if status != Status.RUNNING:
		return ev
	status = Status.FAILED
	fail_code = code
	fail_message = message
	ev.append({"type": "failed", "code": code, "message": message})
	return ev


## Sensors never change anything and cost nothing.
func sense(sensor: String) -> bool:
	match sensor:
		"path_ahead":
			return Tiles.is_walkable(grid.get_tile(cell_rel(0)))
		"path_left":
			return Tiles.is_walkable(grid.get_tile(cell_rel(-1)))
		"path_right":
			return Tiles.is_walkable(grid.get_tile(cell_rel(1)))
		"bush_ahead":
			return grid.get_tile(cell_rel(0)) == Tiles.BUSH
		"stone_ahead":
			return grid.get_tile(cell_rel(0)) == Tiles.STONE
		"spike_ahead":
			return grid.get_tile(cell_rel(0)) == Tiles.SPIKE
		"at_exit":
			return grid.get_tile(robot.pos) == Tiles.EXIT
		"unvisited_ahead":
			return is_unvisited(cell_rel(0))
		"unvisited_left":
			return is_unvisited(cell_rel(-1))
		"unvisited_right":
			return is_unvisited(cell_rel(1))
		"closer_ahead":
			return is_closer(cell_rel(0))
		"closer_left":
			return is_closer(cell_rel(-1))
		"closer_right":
			return is_closer(cell_rel(1))
	return false


## The cell next to the robot: 0 = ahead, -1 = left, 1 = right, 2 = behind.
func cell_rel(turn: int) -> Vector2i:
	return robot.pos + Tiles.dir_vec(robot.facing + turn)


func is_visited(c: Vector2i) -> bool:
	return grid.in_bounds(c) and visited[grid.index_of(c)] == 1


func is_unvisited(c: Vector2i) -> bool:
	return grid.in_bounds(c) and Tiles.is_walkable(grid.get_tile(c)) and not is_visited(c)


func is_revealed(c: Vector2i) -> bool:
	return grid.in_bounds(c) and revealed[grid.index_of(c)] == 1


func has_scan() -> bool:
	return not scan.is_empty()


## Scan number for a tile, or -1 (no scan, or unreachable).
func scan_distance(c: Vector2i) -> int:
	if scan.is_empty() or not grid.in_bounds(c):
		return -1
	var dist: PackedInt32Array = scan["dist"]
	return dist[grid.index_of(c)]


## True when stepping onto c keeps the robot on a cheapest path to the exit.
func is_closer(c: Vector2i) -> bool:
	if scan.is_empty() or not grid.in_bounds(c):
		return false
	var dist: PackedInt32Array = scan["dist"]
	var weight: PackedInt32Array = scan["weight"]
	var here := dist[grid.index_of(robot.pos)]
	var i := grid.index_of(c)
	return here > 0 and dist[i] >= 0 and weight[i] >= 0 and dist[i] + weight[i] == here


## ASCII picture of the world for test failure messages.
func dump() -> String:
	var arrows := ["^", ">", "v", "<"]
	var rows := grid.to_rows({robot.pos: arrows[robot.facing]})
	return "%s\nHP %d/%d  stamina %d/%d  spent %d  status %s %s" % [
		"\n".join(rows), robot.hp, robot.max_hp, robot.stamina, robot.max_stamina,
		stamina_spent, status_name(), fail_code]


func _do_move(ev: Array[Dictionary]) -> void:
	var from := robot.pos
	var to := from + Tiles.dir_vec(robot.facing)
	var t := grid.get_tile(to)
	if not Tiles.is_walkable(t):
		ev.append({"type": "bumped", "from": from, "cell": to, "tile": t})
		var damage := rules.bump_bush_damage if t == Tiles.BUSH else rules.bump_stone_damage
		_change_hp(-damage, "bump", ev)
		return
	trail.append(from)
	peak_trail = maxi(peak_trail, trail.size())
	_enter(to, "moved", ev)


func _do_turn(direction: int, ev: Array[Dictionary]) -> void:
	var from_facing := robot.facing
	robot.facing = posmod(robot.facing + direction, 4)
	ev.append({"type": "turned", "from_facing": from_facing, "facing": robot.facing, "dir": direction})


func _do_cut(ev: Array[Dictionary]) -> void:
	var ahead := cell_rel(0)
	var t := grid.get_tile(ahead)
	if t == Tiles.BUSH:
		grid.set_tile(ahead, Tiles.FLOOR)
		ev.append({"type": "cut", "cell": ahead})
	else:
		ev.append({"type": "warning", "code": "nothing_to_cut", "cell": ahead,
				"text": "cut() found %s ahead: nothing to cut, %d stamina wasted."
						% [Tiles.tile_name(t), rules.cut_cost]})


func _backtrack_turns() -> int:
	if trail.is_empty():
		return 0
	var target := Tiles.facing_toward(trail.back() - robot.pos)
	if target < 0:
		return 0
	var diff := posmod(target - robot.facing, 4)
	return 2 if diff == 2 else (0 if diff == 0 else 1)


func _do_backtrack(ev: Array[Dictionary]) -> void:
	var prev: Vector2i = trail.back()
	var target := Tiles.facing_toward(prev - robot.pos)
	if target >= 0:
		match posmod(target - robot.facing, 4):
			1:
				_do_turn(1, ev)
			3:
				_do_turn(-1, ev)
			2:
				_do_turn(-1, ev)
				_do_turn(-1, ev)
	trail.pop_back()
	_enter(prev, "backtracked", ev)


func _do_scan(weighted: bool, ev: Array[Dictionary]) -> void:
	scan = MazePathing.distance_field(grid, exits, rules, weighted)
	ev.append({"type": "scanned", "dist": scan["dist"], "order": scan["order"],
			"weighted": weighted, "max_frontier": scan["max_frontier"]})
	if scan_distance(robot.pos) < 0:
		ev.append({"type": "warning", "code": "unreachable", "cell": robot.pos,
				"text": "The scan can't reach the exit from here."})


func _enter(to: Vector2i, kind: String, ev: Array[Dictionary]) -> void:
	var from := robot.pos
	robot.pos = to
	ev.append({"type": kind, "from": from, "to": to, "facing": robot.facing})
	visited[grid.index_of(to)] = 1
	if fog:
		_reveal_around(to, ev)
	match grid.get_tile(to):
		Tiles.SPIKE:
			_change_hp(-rules.spike_damage, "spike", ev)
		Tiles.BATTERY:
			grid.set_tile(to, Tiles.FLOOR)
			var gain := mini(rules.battery_amount, robot.max_stamina - robot.stamina)
			ev.append({"type": "picked_up", "item": "battery", "cell": to, "amount": gain,
					"wasted": rules.battery_amount - gain})
			_change_stamina(gain, "battery", ev)
		Tiles.REPAIR:
			grid.set_tile(to, Tiles.FLOOR)
			var heal := mini(rules.repair_amount, robot.max_hp - robot.hp)
			ev.append({"type": "picked_up", "item": "repair", "cell": to, "amount": heal,
					"wasted": rules.repair_amount - heal})
			_change_hp(heal, "repair", ev)


func _change_hp(delta: int, cause: String, ev: Array[Dictionary]) -> void:
	robot.hp = clampi(robot.hp + delta, 0, robot.max_hp)
	ev.append({"type": "hp_changed", "value": robot.hp, "delta": delta, "max": robot.max_hp,
			"cause": cause})


func _change_stamina(delta: int, cause: String, ev: Array[Dictionary]) -> void:
	robot.stamina = clampi(robot.stamina + delta, 0, robot.max_stamina)
	ev.append({"type": "stamina_changed", "value": robot.stamina, "delta": delta,
			"max": robot.max_stamina, "cause": cause})


func _reveal_around(c: Vector2i, ev: Array[Dictionary]) -> void:
	var cells: Array[Vector2i] = []
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var n := c + Vector2i(dx, dy)
			if grid.in_bounds(n) and revealed[grid.index_of(n)] == 0:
				revealed[grid.index_of(n)] = 1
				cells.append(n)
	if not cells.is_empty():
		ev.append({"type": "revealed", "cells": cells})
