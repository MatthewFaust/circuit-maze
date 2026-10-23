class_name InspectorPanel
extends PanelContainer
## Shows the robot's memory: the call stack (functions), the breadcrumb stack
## (DFS) and scan statistics (BFS/Dijkstra). Hidden on levels that use none.

const MAX_CHIPS := 14

var show_calls := false
var show_trail := false
var show_scan := false
var show_bosses := false

var _calls_box: VBoxContainer
var _calls_list: VBoxContainer
var _trail_box: VBoxContainer
var _trail_list: VBoxContainer
var _trail_count: Label
var _scan_box: VBoxContainer
var _scan_label: Label
var _loops_label: Label
var _boss_box: VBoxContainer
var _boss_label: Label


func _ready() -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	add_child(col)
	_boss_box = _section(col, "Bosses")
	_boss_label = _small(_boss_box, "")
	_boss_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_calls_box = _section(col, "Call stack")
	_calls_list = VBoxContainer.new()
	_calls_list.add_theme_constant_override("separation", 3)
	_calls_box.add_child(_calls_list)
	_trail_box = _section(col, "Breadcrumbs (a stack)")
	_trail_count = _small(_trail_box, "")
	_trail_list = VBoxContainer.new()
	_trail_list.add_theme_constant_override("separation", 3)
	_trail_box.add_child(_trail_list)
	_scan_box = _section(col, "Scan")
	_scan_label = _small(_scan_box, "No scan yet.")
	_scan_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var loops_box := _section(col, "Loops")
	_loops_label = _small(loops_box, "")
	_loops_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	loops_box.name = "Loops"


func configure(level: LevelData) -> void:
	show_calls = level.uses_functions()
	show_trail = level.shows_trail()
	show_scan = level.shows_scan()
	show_bosses = level.is_boss()
	_calls_box.visible = show_calls
	_trail_box.visible = show_trail
	_scan_box.visible = show_scan
	_boss_box.visible = show_bosses
	visible = show_calls or show_trail or show_scan or show_bosses


func reset(world: MazeWorld) -> void:
	_set_calls(PackedStringArray(["main"]))
	_set_trail(world)
	_scan_label.text = "No scan yet." if not world.has_scan() else _scan_text(world)
	_loops_label.text = ""
	_boss_label.text = _boss_text(world)


## After each step: the interpreter's call stack and loops, and the world's memory.
func update_step(result: Dictionary, world: MazeWorld) -> void:
	if not visible:
		return
	if show_calls:
		_set_calls(result.get("call_stack", PackedStringArray(["main"])))
	if show_trail:
		_set_trail(world)
	if show_scan and world.has_scan():
		_scan_label.text = _scan_text(world)
	if show_bosses:
		_boss_label.text = _boss_text(world)
	var parts := PackedStringArray()
	for l: Dictionary in result.get("loops", []):
		if int(l["total"]) > 0:
			parts.append("repeat: pass %d of %d" % [int(l["iteration"]), int(l["total"])])
		else:
			parts.append("while: pass %d" % int(l["iteration"]))
	_loops_label.text = "\n".join(parts)


func _set_calls(stack: PackedStringArray) -> void:
	for c in _calls_list.get_children():
		c.queue_free()
	var start := maxi(0, stack.size() - MAX_CHIPS)
	if start > 0:
		_small(_calls_list, "... %d more below" % start)
	for i in range(stack.size() - 1, start - 1, -1):
		var name_text := "main" if i == 0 else stack[i] + "()"
		_chip(_calls_list, name_text + ("   ← running" if i == stack.size() - 1 else ""), &"ChipCall")
	_small(_calls_list, "depth %d" % (stack.size() - 1))


func _set_trail(world: MazeWorld) -> void:
	for c in _trail_list.get_children():
		c.queue_free()
	var trail := world.trail
	_trail_count.text = "%d on the stack (top first)" % trail.size()
	var shown := 0
	for i in range(trail.size() - 1, -1, -1):
		if shown >= MAX_CHIPS:
			_small(_trail_list, "... %d more" % (trail.size() - shown))
			break
		var c: Vector2i = trail[i]
		_chip(_trail_list, "(%d, %d)%s" % [c.x, c.y, "   ← top" if shown == 0 else ""], &"ChipTrail")
		shown += 1


## HP of every boss still standing. The rhythm isn't shown: reading it is the puzzle.
func _boss_text(world: MazeWorld) -> String:
	var alive := world.alive_bosses()
	if alive.is_empty():
		return "All defeated!" if world.is_boss_stage() else ""
	var lines := PackedStringArray()
	var charging := world.striker(world.actions_taken) if world.is_running() else {}
	for b in alive:
		var warn := "   ← about to strike!" if not charging.is_empty() and charging["id"] == b["id"] else ""
		lines.append("%s: %d / %d HP%s" % [b["name"], int(b["hp"]), int(b["max_hp"]), warn])
	lines.append("You hit for %d · defense %d" % [world.attack_damage, world.defense])
	return "\n".join(lines)


func _scan_text(world: MazeWorld) -> String:
	var order: PackedInt32Array = world.scan["order"]
	var here := world.scan_distance(world.robot.pos)
	var kind := "Dijkstra (priority queue)" if bool(world.scan["weighted"]) else "BFS (FIFO queue)"
	return "%s\n%d tiles labelled\nlargest queue: %d\nhere: %s" % [kind, order.size(),
			int(world.scan["max_frontier"]), str(here) if here >= 0 else "unreachable"]


func _section(parent: Control, title: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	parent.add_child(box)
	var l := Label.new()
	l.theme_type_variation = &"SectionTitle"
	l.text = title.to_upper()
	box.add_child(l)
	return box


func _small(parent: Control, text: String) -> Label:
	var l := Label.new()
	l.theme_type_variation = &"Muted"
	l.add_theme_font_size_override("font_size", 14)
	l.text = text
	parent.add_child(l)
	return l


func _chip(parent: Control, text: String, variation: StringName) -> void:
	var p := PanelContainer.new()
	p.theme_type_variation = variation
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 14)
	p.add_child(l)
	parent.add_child(p)
