class_name MazeView
extends Control
## Draws a MazeWorld and animates its events. The board is a Node2D with
## 128-unit cells, scaled to fit this control. Static tiles, breadcrumbs, scan
## numbers and fog are drawn with draw callbacks; tiles that change (bushes,
## items) and the robot are sprites so they can be tweened.
##
## Views get events two ways: append_event(tween, event) adds the event's
## animation to the step's Tween; apply_event(event) applies it instantly (max speed).

const CELL := 128.0
const MAX_SCALE := 0.8
const MOVE_TIME := 0.26
const TURN_TIME := 0.16
const ROBOT_TEX := preload("res://art/robot/robot.svg")
const OBJECT_TEX := {
	Tiles.BUSH: preload("res://art/tiles/bush.svg"),
	Tiles.EXIT: preload("res://art/tiles/exit.svg"),
	Tiles.SPIKE: preload("res://art/tiles/spike.svg"),
	Tiles.BATTERY: preload("res://art/tiles/battery.svg"),
	Tiles.REPAIR: preload("res://art/tiles/repair.svg"),
}
## Gap around each wall block, in board units.
const WALL_INSET := 5.0

var world: MazeWorld
## Draw visited dots and the breadcrumb line (DFS levels).
var show_trail := false

var board: Node2D
var _floor: Node2D
var _marks: Node2D
var _objects: Node2D
var _numbers: Node2D
var _robot: Node2D
var _robot_body: Sprite2D
var _fog: Node2D
var _fx: Node2D
var _banner: Label
var _font: Font
var _sprites := {}
var _anim_pos := Vector2.ZERO
var _anim_rot := 0.0
var _fog_alpha := PackedFloat32Array()
var _scan_dist := PackedInt32Array()
var _scan_max := 0
var _scan_reveal := -1.0
var _scan_weighted := false
var _trail: Array[Vector2i] = []
var _visited := PackedByteArray()
var _idle_tweens: Array[Tween] = []
## Chapter colors (theme type "Palette"), refreshed when the theme changes.
var _pal := {}
var _wall_box: StyleBoxFlat


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = get_theme_default_font()
	_read_palette()
	board = Node2D.new()
	board.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(board)
	_floor = _layer("Floor", _draw_floor)
	_marks = _layer("Marks", _draw_marks)
	_objects = _layer("Objects", Callable())
	_numbers = _layer("Numbers", _draw_numbers)
	_robot = Node2D.new()
	_robot.name = "Robot"
	board.add_child(_robot)
	_robot_body = Sprite2D.new()
	_robot_body.texture = ROBOT_TEX
	_robot.add_child(_robot_body)
	_fog = _layer("Fog", _draw_fog)
	_fx = _layer("Fx", Callable())
	_banner = Label.new()
	_banner.theme_type_variation = &"HeroTitle"
	_banner.add_theme_font_size_override("font_size", 56)
	_banner.add_theme_constant_override("outline_size", 12)
	_banner.add_theme_color_override("font_outline_color", _pal["surface"])
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.hide()
	add_child(_banner)
	resized.connect(_fit)


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and _floor != null:
		_read_palette()
		_banner.add_theme_color_override("font_outline_color", _pal["surface"])
		for layer: Node2D in [_floor, _marks, _numbers, _fog]:
			layer.queue_redraw()


func _read_palette() -> void:
	for role in ["surface", "wall", "wall_top", "wall_edge", "walk", "walk_line", "trail", "visited",
			"fog", "fog_dot", "outline", "accent"]:
		_pal[role] = get_theme_color(StringName(role), &"Palette")
	_wall_box = StyleBoxFlat.new()
	_wall_box.bg_color = _pal["wall"]
	_wall_box.set_corner_radius_all(18)
	_wall_box.border_width_bottom = 8
	_wall_box.border_width_top = 2
	_wall_box.border_color = _pal["wall_edge"]
	_wall_box.border_blend = false


func _layer(layer_name: String, draw_func: Callable) -> Node2D:
	var n := Node2D.new()
	n.name = layer_name
	board.add_child(n)
	if draw_func.is_valid():
		n.draw.connect(draw_func)
	return n


## Rebuilds the board for a fresh world (new variant, reset).
func show_world(w: MazeWorld) -> void:
	world = w
	for t in _idle_tweens:
		if t.is_valid():
			t.kill()
	_idle_tweens.clear()
	for c in _objects.get_children():
		c.queue_free()
	for c in _fx.get_children():
		c.queue_free()
	_sprites.clear()
	var g := world.grid
	for i in g.size():
		var t := g.cells[i]
		if OBJECT_TEX.has(t):
			_add_sprite(g.cell_at(i), t)
	_fog_alpha.resize(g.size())
	for i in g.size():
		_fog_alpha[i] = 0.0 if world.revealed[i] == 1 else 1.0
	_scan_dist = PackedInt32Array()
	_scan_reveal = -1.0
	_scan_max = 0
	_robot.modulate = Color.WHITE
	_robot.scale = Vector2.ONE
	_robot_body.modulate = Color.WHITE
	hide_banner()
	sync()
	_fit()
	_floor.queue_redraw()


## Snaps every visual to the world's current state (after instant runs).
func sync() -> void:
	if world == null:
		return
	_anim_pos = cell_center(world.robot.pos)
	_anim_rot = _facing_angle(world.robot.facing)
	_robot.position = _anim_pos
	_robot_body.rotation = _anim_rot
	for cell: Vector2i in _sprites.keys():
		var t := world.grid.get_tile(cell)
		var s: Sprite2D = _sprites[cell]
		if not OBJECT_TEX.has(t):
			s.queue_free()
			_sprites.erase(cell)
	for i in world.grid.size():
		if world.revealed[i] == 1:
			_fog_alpha[i] = 0.0
	_trail = world.trail.duplicate()
	_visited = world.visited.duplicate()
	if world.has_scan():
		_set_scan_data(world.scan)
		_scan_reveal = float(_scan_max) + 1.0
	_marks.queue_redraw()
	_numbers.queue_redraw()
	_fog.queue_redraw()


func cell_center(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * CELL


func content_size() -> Vector2:
	if world == null:
		return Vector2(CELL, CELL)
	return Vector2(world.grid.width, world.grid.height) * CELL


func show_banner(text: String, color: Color) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner.show()
	_banner.pivot_offset = _banner.size / 2.0
	if Game.reduce_motion():
		return
	_banner.scale = Vector2(0.6, 0.6)
	_banner.modulate.a = 0.0
	var t := _banner.create_tween().set_parallel()
	t.tween_property(_banner, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_banner, "modulate:a", 1.0, 0.2)


func hide_banner() -> void:
	if _banner != null:
		_banner.hide()


## Adds the animation for one event to the step's tween (sequential by default).
func append_event(t: Tween, e: Dictionary) -> void:
	match str(e["type"]):
		"moved", "backtracked":
			var to := cell_center(e["to"])
			_anim_pos = to
			t.tween_callback(Sfx.play.bind(&"move" if e["type"] == "moved" else &"backtrack"))
			t.tween_property(_robot, "position", to, MOVE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			t.tween_callback(_after_enter.bind(e["to"]))
		"turned":
			_anim_rot += int(e["dir"]) * PI / 2.0
			t.tween_callback(Sfx.play.bind(&"turn"))
			t.tween_property(_robot_body, "rotation", _anim_rot, TURN_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		"bumped":
			var dir := Vector2(Vector2i(e["cell"]) - Vector2i(e["from"])).normalized()
			var base := _anim_pos
			t.tween_property(_robot, "position", base + dir * CELL * 0.22, 0.09).set_ease(Tween.EASE_OUT)
			t.tween_callback(_on_bump.bind(base + dir * CELL * 0.48, int(e["tile"])))
			t.tween_property(_robot, "position", base, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		"cut":
			t.tween_callback(_cut_bush.bind(e["cell"]))
			t.tween_interval(0.2)
		"picked_up":
			t.tween_callback(_pickup.bind(e["cell"], str(e["item"]), int(e["amount"]), int(e["wasted"])))
		"hp_changed":
			t.tween_callback(_hp_fx.bind(int(e["delta"]), str(e["cause"])))
		"scanned":
			t.tween_callback(_begin_scan.bind(e))
			var dist: PackedInt32Array = e["dist"]
			var top := 0
			for d in dist:
				top = maxi(top, d)
			t.tween_method(_set_scan_reveal, -0.5, float(top) + 0.5, clampf(0.07 * top, 0.4, 2.2))
		"revealed":
			t.tween_callback(_reveal.bind(e["cells"]))
		"warning":
			t.tween_callback(_float_text.bind("?", _anim_pos + Vector2(0, -CELL * 0.4), Color(1, 0.82, 0.4)))
		"won":
			t.tween_callback(_celebrate)
			t.tween_interval(0.7)
		"failed":
			t.tween_callback(_power_down.bind(str(e["code"])))
			t.tween_interval(0.3)


## Applies an event with no animation (max speed). Call sync() afterwards.
func apply_event(e: Dictionary) -> void:
	match str(e["type"]):
		"cut", "picked_up":
			var cell: Vector2i = e["cell"]
			if _sprites.has(cell):
				(_sprites[cell] as Sprite2D).queue_free()
				_sprites.erase(cell)
		"scanned":
			_set_scan_data(e)
			_scan_reveal = float(_scan_max) + 1.0
			_numbers.queue_redraw()
		"won":
			_celebrate()
		"failed":
			_power_down(str(e["code"]))


func _fit() -> void:
	if board == null:
		return
	var content := content_size()
	var s := minf(size.x / content.x, size.y / content.y)
	s = clampf(s, 0.05, MAX_SCALE)
	board.scale = Vector2(s, s)
	board.position = ((size - content * s) / 2.0).round()


func _facing_angle(facing: int) -> float:
	# The robot sprite faces east.
	return (facing - 1) * PI / 2.0


func _add_sprite(cell: Vector2i, t: int) -> void:
	var s := Sprite2D.new()
	s.texture = OBJECT_TEX[t]
	s.position = cell_center(cell)
	_objects.add_child(s)
	_sprites[cell] = s
	if Game.reduce_motion():
		return
	if t == Tiles.EXIT:
		var tw := s.create_tween().set_loops()
		tw.tween_property(s, "scale", Vector2(1.06, 1.06), 0.8).set_trans(Tween.TRANS_SINE)
		tw.tween_property(s, "scale", Vector2.ONE, 0.8).set_trans(Tween.TRANS_SINE)
		_idle_tweens.append(tw)
	elif t == Tiles.BATTERY or t == Tiles.REPAIR:
		var tw := s.create_tween().set_loops()
		tw.tween_property(s, "position:y", s.position.y - 6.0, 0.7).set_trans(Tween.TRANS_SINE)
		tw.tween_property(s, "position:y", s.position.y, 0.7).set_trans(Tween.TRANS_SINE)
		_idle_tweens.append(tw)


## The animation runs right after the world finished the step, so the world's
## trail already matches the end of this move.
func _after_enter(cell: Vector2i) -> void:
	if world != null:
		_trail = world.trail.duplicate()
		if world.grid.in_bounds(cell) and _visited.size() == world.grid.size():
			_visited[world.grid.index_of(cell)] = 1
	_marks.queue_redraw()


func _on_bump(at: Vector2, tile: int) -> void:
	Sfx.play(&"bump")
	_burst(at, Color(1.0, 0.85, 0.4) if tile == Tiles.STONE else Color(0.3, 0.75, 0.4), 10)
	if Game.reduce_motion():
		return
	var t := _robot_body.create_tween()
	for i in 3:
		t.tween_property(_robot_body, "position", Vector2(randf_range(-6, 6), randf_range(-6, 6)), 0.03)
	t.tween_property(_robot_body, "position", Vector2.ZERO, 0.03)


func _cut_bush(cell: Vector2i) -> void:
	Sfx.play(&"cut")
	if not _sprites.has(cell):
		return
	var s: Sprite2D = _sprites[cell]
	_sprites.erase(cell)
	_burst(s.position, Color(0.35, 0.8, 0.4), 18)
	var t := s.create_tween().set_parallel()
	t.tween_property(s, "scale", Vector2(0.1, 0.1), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.tween_property(s, "rotation", 0.8, 0.22)
	t.chain().tween_callback(s.queue_free)


func _pickup(cell: Vector2i, item: String, amount: int, wasted: int) -> void:
	Sfx.play(&"pickup")
	if _sprites.has(cell):
		var s: Sprite2D = _sprites[cell]
		_sprites.erase(cell)
		var t := s.create_tween().set_parallel()
		t.tween_property(s, "scale", Vector2(1.5, 1.5), 0.25)
		t.tween_property(s, "modulate:a", 0.0, 0.25)
		t.chain().tween_callback(s.queue_free)
	if item == "battery":
		var text := "+%d stamina" % amount
		if wasted > 0:
			text += " (%d wasted)" % wasted
		_float_text(text, cell_center(cell) + Vector2(0, -CELL * 0.5), Color(1, 0.72, 0.1))


func _hp_fx(delta: int, cause: String) -> void:
	if delta < 0:
		Sfx.play(&"damage")
		_float_text("%d HP" % delta, _anim_pos + Vector2(0, -CELL * 0.45), Color(1, 0.35, 0.45))
		var t := _robot_body.create_tween()
		t.tween_property(_robot_body, "modulate", Color(1, 0.3, 0.3), 0.06)
		t.tween_property(_robot_body, "modulate", Color.WHITE, 0.22)
	elif delta > 0 and cause == "repair":
		_float_text("+%d HP" % delta, _anim_pos + Vector2(0, -CELL * 0.45), Color(0.4, 1, 0.6))


func _begin_scan(e: Dictionary) -> void:
	Sfx.play(&"scan")
	_set_scan_data(e)
	_scan_reveal = -1.0
	_marks.queue_redraw()
	_numbers.queue_redraw()


func _set_scan_data(e: Dictionary) -> void:
	_scan_dist = e["dist"]
	_scan_weighted = bool(e.get("weighted", false))
	_scan_max = 0
	for d in _scan_dist:
		_scan_max = maxi(_scan_max, d)


func _set_scan_reveal(v: float) -> void:
	_scan_reveal = v
	_marks.queue_redraw()
	_numbers.queue_redraw()


func _reveal(cells: Array) -> void:
	if world == null:
		return
	var idx := PackedInt32Array()
	for c: Vector2i in cells:
		if world.grid.in_bounds(c):
			idx.append(world.grid.index_of(c))
	if Game.reduce_motion():
		for i in idx:
			_fog_alpha[i] = 0.0
		_fog.queue_redraw()
		return
	var t := _fog.create_tween()
	t.tween_method(func(a: float) -> void:
		for i in idx:
			_fog_alpha[i] = minf(_fog_alpha[i], a)
		_fog.queue_redraw(), 1.0, 0.0, 0.25)


func _celebrate() -> void:
	Sfx.play(&"win")
	if world != null:
		for e in world.exits:
			_burst(cell_center(e), Color(0.3, 1, 0.8), 30)
	if Game.reduce_motion():
		return
	var t := _robot.create_tween()
	t.tween_property(_robot, "scale", Vector2(1.25, 1.25), 0.15)
	t.parallel().tween_property(_robot_body, "rotation", _anim_rot + TAU, 0.5).set_trans(Tween.TRANS_SINE)
	t.tween_property(_robot, "scale", Vector2.ONE, 0.2)


func _power_down(code: String) -> void:
	Sfx.play(&"fail")
	if code == "hp_zero" or code == "no_stamina":
		var t := _robot.create_tween().set_parallel()
		t.tween_property(_robot, "modulate", Color(0.45, 0.45, 0.5), 0.35)
		t.tween_property(_robot, "scale", Vector2(0.9, 0.9), 0.35)
		if code == "hp_zero":
			_burst(_anim_pos, Color(0.5, 0.5, 0.55), 20)


func _float_text(text: String, at: Vector2, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 40)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", _pal["outline"])
	l.add_theme_constant_override("outline_size", 10)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.add_child(l)
	l.position = at - l.get_minimum_size() / 2.0
	var t := l.create_tween().set_parallel()
	t.tween_property(l, "position:y", l.position.y - 50.0, 0.8).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.3)
	t.chain().tween_callback(l.queue_free)


func _burst(at: Vector2, color: Color, amount: int) -> void:
	if Game.reduce_motion():
		return
	var p := CPUParticles2D.new()
	p.position = at
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.55
	p.explosiveness = 0.95
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = 140.0
	p.initial_velocity_max = 320.0
	p.gravity = Vector2(0, 520)
	p.scale_amount_min = 6.0
	p.scale_amount_max = 12.0
	p.color = color
	p.finished.connect(p.queue_free)
	_fx.add_child(p)
	p.emitting = true


func _draw_floor() -> void:
	if world == null:
		return
	var g := world.grid
	var cell := Vector2(CELL, CELL)
	var canvas := _floor.get_canvas_item()
	# Walkable cells first, as one surface with faint grid lines.
	for y in g.height:
		for x in g.width:
			if g.get_tile(Vector2i(x, y)) != Tiles.STONE:
				var r := Rect2(Vector2(x, y) * CELL, cell)
				_floor.draw_rect(r, _pal["walk"])
				_floor.draw_rect(r.grow(-1.5), _pal["walk_line"], false, 3.0)
	# Walls: raised blocks with a light top edge and a darker base.
	for y in g.height:
		for x in g.width:
			if g.get_tile(Vector2i(x, y)) == Tiles.STONE:
				var r := Rect2(Vector2(x, y) * CELL, cell).grow(-WALL_INSET)
				_wall_box.draw(canvas, r)
				_floor.draw_rect(Rect2(r.position + Vector2(18, 10), Vector2(r.size.x - 36, 6)), _pal["wall_top"])


func _draw_marks() -> void:
	if world == null:
		return
	var g := world.grid
	# Scan numbers: a heat map tinted by distance, numbers drawn on top.
	if not _scan_dist.is_empty() and _scan_reveal >= 0.0:
		for i in _scan_dist.size():
			var d := _scan_dist[i]
			if d < 0 or float(d) > _scan_reveal:
				continue
			var c := g.cell_at(i)
			var k := 0.0 if _scan_max == 0 else float(d) / float(_scan_max)
			var tint := Color(0.2, 0.75, 0.95).lerp(Color(0.55, 0.3, 0.95), k)
			tint.a = 0.28
			_marks.draw_rect(Rect2(Vector2(c) * CELL + Vector2(6, 6), Vector2(CELL - 12, CELL - 12)), tint)
	if not show_trail:
		return
	for i in _visited.size():
		if _visited[i] == 1:
			_marks.draw_circle(cell_center(g.cell_at(i)), 9.0, _pal["visited"])
	if not _trail.is_empty():
		var pts := PackedVector2Array()
		for c in _trail:
			pts.append(cell_center(c))
		pts.append(_anim_pos)
		if pts.size() >= 2:
			_marks.draw_polyline(pts, _pal["trail"], 10.0, true)
		for c in _trail:
			_marks.draw_circle(cell_center(c), 14.0, _pal["trail"])


## Scan numbers sit above bushes and items: a bush's cost is part of the answer.
func _draw_numbers() -> void:
	if world == null or _scan_dist.is_empty() or _scan_reveal < 0.0:
		return
	var g := world.grid
	for i in _scan_dist.size():
		var d := _scan_dist[i]
		if d < 0 or float(d) > _scan_reveal:
			continue
		var label := str(d)
		var fs := 40
		var sz := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var pos := cell_center(g.cell_at(i)) + Vector2(-sz.x / 2.0, CELL * 0.36)
		_numbers.draw_string_outline(_font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, _pal["outline"])
		_numbers.draw_string(_font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, _pal["surface"])


func _draw_fog() -> void:
	if world == null or not world.fog:
		return
	var g := world.grid
	for i in _fog_alpha.size():
		var a := _fog_alpha[i]
		if a <= 0.0:
			continue
		var c := g.cell_at(i)
		_fog.draw_rect(Rect2(Vector2(c) * CELL - Vector2(1, 1), Vector2(CELL + 2, CELL + 2)), Color(_pal["fog"], a))
		if a > 0.5:
			_fog.draw_circle(cell_center(c), 6.0, Color(_pal["fog_dot"], a))
