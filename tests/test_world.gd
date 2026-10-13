extends "res://tests/suite_base.gd"
## Grid, world rules and sensors: one test per rule in the rules table.


func _world(rows: Array, facing: int = Tiles.EAST, stamina: int = 20, fog: bool = false,
		rules: MazeRules = null) -> MazeWorld:
	var parsed := MazeGrid.from_rows(PackedStringArray(rows))
	var grid: MazeGrid = parsed["grid"]
	return MazeWorld.new(grid, parsed["start"], facing, rules if rules != null else MazeRules.new(),
			stamina, fog)


func _types(events: Array[Dictionary]) -> Array:
	var out: Array = []
	for e in events:
		out.append(str(e["type"]))
	return out


func test_grid_from_rows_valid() -> void:
	var r := MazeGrid.from_rows(PackedStringArray(["#####", "#S.E#", "#####"]))
	check_eq((r["errors"] as PackedStringArray).size(), 0, "no errors")
	var g: MazeGrid = r["grid"]
	check_eq(g.width, 5, "width")
	check_eq(g.height, 3, "height")
	check_eq(r["start"], Vector2i(1, 1), "start")
	check_eq(g.get_tile(Vector2i(1, 1)), Tiles.FLOOR, "start is floor")
	check_eq(g.get_tile(Vector2i(3, 1)), Tiles.EXIT, "exit")


func test_grid_from_rows_errors() -> void:
	var cases := {
		"ragged": ["####", "#S.E#", "####"],
		"unknown char": ["#####", "#SQE#", "#####"],
		"no start": ["#####", "#..E#", "#####"],
		"two starts": ["#####", "#SSE#", "#####"],
		"no exit": ["#####", "#S..#", "#####"],
	}
	for name: String in cases:
		var r := MazeGrid.from_rows(PackedStringArray(cases[name]))
		check((r["errors"] as PackedStringArray).size() > 0, "%s should be an error" % name)
		check(r["grid"] == null, "%s should give no grid" % name)


func test_out_of_bounds_is_stone() -> void:
	var w := _world(["S.E"])
	check_eq(w.grid.get_tile(Vector2i(-1, 0)), Tiles.STONE, "left of map")
	check_eq(w.grid.get_tile(Vector2i(0, 5)), Tiles.STONE, "below map")


func test_move_onto_floor() -> void:
	var w := _world(["#####", "#S.E#", "#####"])
	var ev := w.apply_action("move")
	check_eq(w.robot.pos, Vector2i(2, 1), "moved")
	check_eq(w.robot.stamina, 19, "stamina")
	check_eq(w.stamina_spent, 1, "spent")
	check_list(_types(ev), ["stamina_changed", "moved"], "events")
	check_list(w.trail, [Vector2i(1, 1)], "trail")
	check(w.is_visited(Vector2i(2, 1)), "visited")


func test_bump_stone_costs_hp_and_stamina() -> void:
	var w := _world(["#####", "#S.E#", "#####"], Tiles.NORTH)
	var ev := w.apply_action("move")
	check_eq(w.robot.pos, Vector2i(1, 1), "didn't move")
	check_eq(w.robot.hp, 85, "-15 HP")
	check_eq(w.robot.stamina, 19, "-1 stamina")
	check_list(_types(ev), ["stamina_changed", "bumped", "hp_changed"], "events")
	check(w.trail.is_empty(), "a bump pushes no breadcrumb")


func test_bump_map_edge_counts_as_stone() -> void:
	var w := _world(["S.E"], Tiles.WEST)
	w.apply_action("move")
	check_eq(w.robot.hp, 85, "edge bump")


func test_bump_bush_costs_5() -> void:
	var w := _world(["#####", "#SBE#", "#####"])
	w.apply_action("move")
	check_eq(w.robot.pos, Vector2i(1, 1), "blocked")
	check_eq(w.robot.hp, 95, "-5 HP")


func test_turns() -> void:
	var w := _world(["#####", "#S.E#", "#####"])
	w.apply_action("turn_left")
	check_eq(w.robot.facing, Tiles.NORTH, "left of east is north")
	w.apply_action("turn_left")
	check_eq(w.robot.facing, Tiles.WEST, "then west")
	w.apply_action("turn_right")
	w.apply_action("turn_right")
	w.apply_action("turn_right")
	check_eq(w.robot.facing, Tiles.SOUTH, "three rights from west is south")
	check_eq(w.stamina_spent, 5, "turns cost 1 each")


func test_cut_bush() -> void:
	var w := _world(["#####", "#SBE#", "#####"])
	var ev := w.apply_action("cut")
	check_eq(w.grid.get_tile(Vector2i(2, 1)), Tiles.FLOOR, "bush gone")
	check_eq(w.robot.stamina, 17, "cut costs 3")
	check(_types(ev).has("cut"), "cut event")
	w.apply_action("move")
	w.apply_action("move")
	check_eq(w.status, MazeWorld.Status.WON, "escaped")


func test_cut_nothing_wastes_stamina() -> void:
	var w := _world(["#####", "#S.E#", "#####"])
	var ev := w.apply_action("cut")
	check_eq(w.robot.stamina, 17, "still costs 3")
	check(_types(ev).has("warning"), "warning event")


func test_spike_hurts_every_time_and_stays() -> void:
	var w := _world(["######", "#S^.E#", "######"])
	w.apply_action("move")
	check_eq(w.robot.hp, 75, "-25 HP")
	check_eq(w.grid.get_tile(Vector2i(2, 1)), Tiles.SPIKE, "spike stays")
	w.apply_action("turn_left")
	w.apply_action("turn_left")
	w.apply_action("move")
	w.apply_action("turn_left")
	w.apply_action("turn_left")
	w.apply_action("move")
	check_eq(w.robot.hp, 50, "hurts again")


func test_battery_restores_capped_and_is_used_up() -> void:
	var w := _world(["######", "#S+.E#", "######"], Tiles.EAST, 15)
	var ev := w.apply_action("move")
	check_eq(w.robot.stamina, 15, "capped at max (14 + 10 -> 15)")
	check_eq(w.stamina_spent, 1, "batteries don't reduce stamina spent")
	check_eq(w.grid.get_tile(Vector2i(2, 1)), Tiles.FLOOR, "battery used up")
	var pickup := {}
	for e in ev:
		if e["type"] == "picked_up":
			pickup = e
	check_eq(pickup.get("amount", -1), 1, "gained 1")
	check_eq(pickup.get("wasted", -1), 9, "wasted 9")


func test_repair_kit_heals_capped() -> void:
	var w := _world(["#######", "#S^H.E#", "#######"])
	w.apply_action("move")
	w.apply_action("move")
	check_eq(w.robot.hp, 100, "75 + 30 capped at 100")
	check_eq(w.grid.get_tile(Vector2i(3, 1)), Tiles.FLOOR, "kit used up")


func test_reaching_exit_wins_immediately() -> void:
	var w := _world(["#####", "#S.E#", "#####"])
	w.apply_action("move")
	var ev := w.apply_action("move")
	check_eq(w.status, MazeWorld.Status.WON, "won")
	check_eq(_types(ev).back(), "won", "won is the last event")
	check(w.apply_action("move").is_empty(), "actions after the end do nothing")


func test_out_of_stamina() -> void:
	var w := _world(["######", "#S..E#", "######"], Tiles.EAST, 2)
	w.apply_action("move")
	w.apply_action("move")
	check_eq(w.robot.stamina, 0, "landing on exactly 0 is fine")
	check_eq(w.status, MazeWorld.Status.RUNNING, "still running")
	var ev := w.apply_action("move")
	check_eq(w.fail_code, "no_stamina", "then it fails")
	check_list(_types(ev), ["failed"], "only a failed event")
	check_eq(w.robot.pos, Vector2i(3, 1), "didn't move")


func test_exit_with_zero_stamina_is_a_win() -> void:
	var w := _world(["#####", "#S.E#", "#####"], Tiles.EAST, 2)
	w.apply_action("move")
	w.apply_action("move")
	check_eq(w.status, MazeWorld.Status.WON, "won on the last point")


func test_hp_zero_destroys_robot() -> void:
	var w := _world(["########", "#S^^^^E#", "########"])
	for i in 4:
		w.apply_action("move")
	check_eq(w.robot.hp, 0, "four spikes")
	check_eq(w.fail_code, "hp_zero", "destroyed")


func test_basic_sensors() -> void:
	var w := _world([
		"#####",
		"#.B.#",
		"#^S.#",
		"#E..#",
		"#####",
	], Tiles.NORTH)
	check(w.sense("bush_ahead"), "bush ahead")
	check(not w.sense("path_ahead"), "a bush is not a path")
	check(w.sense("path_left"), "spike to the west counts as a path")
	check(w.sense("path_right"), "floor to the east")
	check(not w.sense("stone_ahead"), "no stone ahead")
	check(not w.sense("at_exit"), "not at exit")
	w.apply_action("turn_left")
	check(w.sense("spike_ahead"), "spike ahead after turning west")
	w.apply_action("turn_left")
	check(w.sense("path_ahead"), "south is floor")
	w.apply_action("turn_left")
	w.apply_action("move")
	check(w.sense("stone_ahead"), "stone at the east wall")


func test_unvisited_sensors() -> void:
	var w := _world(["#####", "#S..#", "#..E#", "#####"])
	check(w.sense("unvisited_ahead"), "ahead is new")
	check(w.is_visited(Vector2i(1, 1)), "start counts as visited")
	w.apply_action("move")
	w.apply_action("turn_left")
	w.apply_action("turn_left")
	check(not w.sense("unvisited_ahead"), "the start is visited")
	check(w.sense("unvisited_left"), "south of (2,1) is new")
	check(not w.sense("unvisited_right"), "north is stone")


func test_backtrack_pops_turns_and_costs() -> void:
	var w := _world(["######", "#S..E#", "######"])
	w.apply_action("move")
	w.apply_action("move")
	check_eq(w.trail.size(), 2, "two breadcrumbs")
	var before := w.stamina_spent
	var ev := w.apply_action("backtrack")
	check_eq(w.robot.pos, Vector2i(2, 1), "stepped back")
	check_eq(w.robot.facing, Tiles.WEST, "faces the direction of travel")
	check_eq(w.stamina_spent - before, 3, "two turns + one step")
	check_eq(_types(ev).count("turned"), 2, "two turn events")
	check(_types(ev).has("backtracked"), "backtracked event")
	before = w.stamina_spent
	w.apply_action("backtrack")
	check_eq(w.stamina_spent - before, 1, "already facing: just the step")
	check_eq(w.robot.pos, Vector2i(1, 1), "back at start")
	w.apply_action("backtrack")
	check_eq(w.fail_code, "backtrack_empty", "empty stack fails")


func test_scan_bfs_treats_bushes_as_walls() -> void:
	var w := _world([
		"######",
		"#S.B.#",
		"#....#",
		"#...E#",
		"######",
	])
	check(not w.sense("closer_ahead"), "no closer before a scan")
	var ev := w.apply_action("scan")
	check_eq(w.stamina_spent, 5, "scan costs 5")
	check(_types(ev).has("scanned"), "scanned event")
	check_eq(w.scan_distance(Vector2i(4, 3)), 0, "exit is 0")
	check_eq(w.scan_distance(Vector2i(3, 1)), -1, "the bush gets no number")
	check_eq(w.scan_distance(Vector2i(1, 1)), 5, "start is 5 steps away")
	check(w.sense("closer_ahead"), "east is on a shortest path")
	w.apply_action("turn_right")
	check(w.sense("closer_ahead"), "south is also on a shortest path")
	check(not w.sense("closer_right"), "west is stone")


func test_scan_weighted_prices_bushes() -> void:
	var w := _world([
		"#######",
		"#SBBBE#",
		"#.###.#",
		"#.....#",
		"#######",
	])
	w.apply_action("scan_weighted")
	check_eq(w.scan_distance(Vector2i(1, 1)), 8, "around (8 steps) beats through (4+4+4+1)")
	check(not w.sense("closer_ahead"), "the bush route isn't cheapest")
	check(w.sense("closer_right"), "going south is")
	var w2 := _world(["#######", "#SB..E#", "#.###.#", "#.....#", "#######"])
	w2.apply_action("scan_weighted")
	check_eq(w2.scan_distance(Vector2i(1, 1)), 7, "one bush (4) + 3 steps beats 8")
	check(w2.sense("closer_ahead"), "now the bush route is cheapest")


func test_fog_reveals_neighbors() -> void:
	var w := _world(["#######", "#S...E#", "#######"], Tiles.EAST, 20, true)
	check(w.is_revealed(Vector2i(2, 1)), "next to the start")
	check(not w.is_revealed(Vector2i(4, 1)), "far tile hidden")
	check(w.is_revealed(Vector2i(5, 1)), "the exit is shown")
	var ev := w.apply_action("move")
	check(_types(ev).has("revealed"), "revealed event")
	check(w.is_revealed(Vector2i(3, 1)), "revealed after moving")
