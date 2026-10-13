class_name MazePathing
extends RefCounted
## Distance fields used by scan() (BFS) and scan_weighted() (Dijkstra), plus
## reachability checks for level validation.


## Cost of stepping onto c, or -1 if it can't be entered.
## BFS (weighted = false): every enterable tile costs 1 and bushes are walls.
## Dijkstra (weighted = true): a bush costs move + cut, everything else a move.
static func entry_cost(grid: MazeGrid, c: Vector2i, rules: MazeRules, weighted: bool) -> int:
	var t := grid.get_tile(c)
	if t == Tiles.STONE:
		return -1
	if not weighted:
		return -1 if t == Tiles.BUSH else 1
	if t == Tiles.BUSH:
		return rules.move_cost + rules.cut_cost
	return rules.move_cost


## Cheapest cost from every tile to the nearest goal.
## Returns {"dist": PackedInt32Array (-1 = unreachable), "weight": PackedInt32Array
## (entry cost per tile, -1 = can't enter), "order": PackedInt32Array (tile indices
## in the order they were settled), "max_frontier": int (largest queue size seen),
## "weighted": bool}.
## dist[here] == dist[n] + weight[n] for the best neighbor n, so "n is closer"
## means stepping onto n stays on a cheapest path.
static func distance_field(grid: MazeGrid, goals: Array[Vector2i], rules: MazeRules,
		weighted: bool) -> Dictionary:
	var n := grid.size()
	var dist := PackedInt32Array()
	dist.resize(n)
	dist.fill(-1)
	var weight := PackedInt32Array()
	weight.resize(n)
	for i in n:
		weight[i] = entry_cost(grid, grid.cell_at(i), rules, weighted)
	var order := PackedInt32Array()
	var max_frontier := 0

	if not weighted:
		# Breadth-first search: a FIFO queue settles tiles in order of distance.
		var queue := PackedInt32Array()
		var head := 0
		for g in goals:
			if grid.in_bounds(g):
				var gi := grid.index_of(g)
				if dist[gi] < 0:
					dist[gi] = 0
					queue.append(gi)
		while head < queue.size():
			max_frontier = maxi(max_frontier, queue.size() - head)
			var u := queue[head]
			head += 1
			order.append(u)
			var uc := grid.cell_at(u)
			for d: Vector2i in Tiles.DIRS:
				var vc := uc + d
				if not grid.in_bounds(vc):
					continue
				var v := grid.index_of(vc)
				if weight[v] < 0 or dist[v] >= 0:
					continue
				dist[v] = dist[u] + weight[u]
				queue.append(v)
	else:
		# Dijkstra: always settle the cheapest unsettled tile (O(V^2) is plenty
		# for maps of a few hundred tiles).
		var settled := PackedByteArray()
		settled.resize(n)
		for g in goals:
			if grid.in_bounds(g):
				dist[grid.index_of(g)] = 0
		while true:
			var best := -1
			var frontier := 0
			for i in n:
				if settled[i] == 0 and dist[i] >= 0:
					frontier += 1
					if best < 0 or dist[i] < dist[best]:
						best = i
			if best < 0:
				break
			max_frontier = maxi(max_frontier, frontier)
			settled[best] = 1
			order.append(best)
			var bc := grid.cell_at(best)
			for d: Vector2i in Tiles.DIRS:
				var vc := bc + d
				if not grid.in_bounds(vc):
					continue
				var v := grid.index_of(vc)
				if weight[v] < 0 or settled[v] == 1:
					continue
				var cand := dist[best] + weight[best]
				if dist[v] < 0 or cand < dist[v]:
					dist[v] = cand
	return {"dist": dist, "weight": weight, "order": order, "max_frontier": max_frontier,
			"weighted": weighted}


## Can the robot get from a to b? Bushes count as open only if bush_passable.
static func reachable(grid: MazeGrid, a: Vector2i, b: Vector2i, bush_passable: bool) -> bool:
	if not grid.in_bounds(a) or not grid.in_bounds(b):
		return false
	var seen := PackedByteArray()
	seen.resize(grid.size())
	var queue: Array[Vector2i] = [a]
	seen[grid.index_of(a)] = 1
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		if c == b:
			return true
		for d: Vector2i in Tiles.DIRS:
			var nc := c + d
			if not grid.in_bounds(nc) or seen[grid.index_of(nc)] == 1:
				continue
			var t := grid.get_tile(nc)
			if t == Tiles.STONE or (t == Tiles.BUSH and not bush_passable):
				continue
			seen[grid.index_of(nc)] = 1
			queue.append(nc)
	return false
