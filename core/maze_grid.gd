class_name MazeGrid
extends RefCounted
## A rectangular grid of tile ids. Anything outside the grid counts as stone.

var width: int = 0
var height: int = 0
var cells := PackedByteArray()


func _init(w: int = 0, h: int = 0, fill: int = Tiles.FLOOR) -> void:
	width = w
	height = h
	cells.resize(w * h)
	cells.fill(fill)


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < width and c.y < height


func index_of(c: Vector2i) -> int:
	return c.y * width + c.x


func cell_at(i: int) -> Vector2i:
	@warning_ignore("integer_division")
	return Vector2i(i % width, i / width)


func size() -> int:
	return cells.size()


func get_tile(c: Vector2i) -> int:
	if not in_bounds(c):
		return Tiles.STONE
	return cells[index_of(c)]


func set_tile(c: Vector2i, t: int) -> void:
	if in_bounds(c):
		cells[index_of(c)] = t


func find_all(t: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i in cells.size():
		if cells[i] == t:
			out.append(cell_at(i))
	return out


func clone() -> MazeGrid:
	var g := MazeGrid.new(width, height)
	g.cells = cells.duplicate()
	return g


## Map rows for debugging. marks maps a cell to a character drawn over it.
func to_rows(marks: Dictionary = {}) -> PackedStringArray:
	var rows := PackedStringArray()
	for y in height:
		var line := ""
		for x in width:
			var c := Vector2i(x, y)
			if marks.has(c):
				line += str(marks[c])
			else:
				line += str(Tiles.CHARS[get_tile(c)])
		rows.append(line)
	return rows


## Parses map rows. Returns {"grid": MazeGrid or null, "start": Vector2i,
## "errors": PackedStringArray}. A valid map is rectangular, uses only legend
## characters, and has exactly one S and at least one E.
static func from_rows(rows: PackedStringArray) -> Dictionary:
	var errors := PackedStringArray()
	var h := rows.size()
	var w := 0 if h == 0 else rows[0].length()
	if h == 0 or w == 0:
		errors.append("map is empty")
		return {"grid": null, "start": Vector2i.ZERO, "errors": errors}
	var grid := MazeGrid.new(w, h)
	var starts: Array[Vector2i] = []
	var exits := 0
	for y in h:
		var row: String = rows[y]
		if row.length() != w:
			errors.append("row %d has length %d, expected %d" % [y, row.length(), w])
			continue
		for x in w:
			var ch := row[x]
			if ch == Tiles.START_CHAR:
				starts.append(Vector2i(x, y))
				grid.set_tile(Vector2i(x, y), Tiles.FLOOR)
				continue
			var t := Tiles.from_char(ch)
			if t < 0:
				errors.append("unknown character '%s' at (%d, %d)" % [ch, x, y])
				continue
			if t == Tiles.EXIT:
				exits += 1
			grid.set_tile(Vector2i(x, y), t)
	if starts.size() != 1:
		errors.append("map needs exactly one S, found %d" % starts.size())
	if exits == 0:
		errors.append("map has no exit (E)")
	var start: Vector2i = starts[0] if starts.size() > 0 else Vector2i.ZERO
	return {"grid": grid if errors.is_empty() else null, "start": start, "errors": errors}
