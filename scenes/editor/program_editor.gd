class_name ProgramEditor
extends Control
## The drag-and-drop block editor.
##
## The program Dictionary (see ProgramModel) is the single source of truth:
## structural edits (insert, move, delete, undo) change it and rebuild the
## view; parameter edits (repeat count, sensor, not) change it in place so the
## widget keeps focus. Only this root control accepts drops. It finds the
## target list and position from the mouse, so nesting depth doesn't matter.

signal program_changed(structural: bool)
signal message(text: String)

const AUTO_SCROLL_EDGE := 48.0
const AUTO_SCROLL_SPEED := 900.0

var level: LevelData
var program := {}

var _history := EditHistory.new()
var _locked := false
var _lists: Array[BlockListView] = []
var _views := {}
var _sections := {}
var _palette_items: Array[PaletteItem] = []
var _active_ref := "main"
var _drag_source: Control
var _scroll_accum := 0.0
var _highlight_id := -1
var _highlight_ancestors := PackedInt32Array()
var _error_id := -1
var _render_pending := false

@onready var _palette: Control = %Palette
@onready var _palette_list: VBoxContainer = %PaletteList
@onready var _scroll: ScrollContainer = %ProgramScroll
@onready var _root: VBoxContainer = %ProgramRoot
@onready var _count_label: Label = %BlockCount
@onready var _undo_button: Button = %UndoButton
@onready var _redo_button: Button = %RedoButton
@onready var _trash_button: Button = %TrashButton
@onready var _clear_button: Button = %ClearButton
@onready var _code_panel: Control = %CodePanel
@onready var _code_view: CodeView = %CodeView
@onready var _drop_line: Panel = %DropLine
@onready var _lock_banner: Control = %LockBanner


func _ready() -> void:
	set_process(false)
	(_lock_banner.get_child(0) as Label).add_theme_color_override("font_color",
			get_theme_color(&"warn", &"Palette"))
	_undo_button.pressed.connect(undo)
	_redo_button.pressed.connect(redo)
	_clear_button.pressed.connect(clear_program)
	_trash_button.pressed.connect(func() -> void:
		message.emit("Drag a block onto the trash (or back onto the palette) to delete it."))
	for b: Control in [_undo_button, _redo_button, _clear_button, _trash_button]:
		forward_drops(b)


func setup(p_level: LevelData, p_program: Dictionary) -> void:
	level = p_level
	program = p_program.duplicate(true)
	_ensure_function_slots()
	ProgramModel.assign_ids(program)
	_history.clear()
	_active_ref = "main"
	_build_palette()
	_render()


func get_program_copy() -> Dictionary:
	return program.duplicate(true)


## Replaces the whole program (undoable).
func set_program(p: Dictionary) -> void:
	_history.push(program)
	program = p.duplicate(true)
	_ensure_function_slots()
	ProgramModel.assign_ids(program)
	_changed(true)


func block_count() -> int:
	return ProgramModel.count_blocks(program)


func is_locked() -> bool:
	return _locked


func set_locked(on: bool) -> void:
	_locked = on
	_lock_banner.visible = on
	_apply_lock_to_widgets()
	_refresh_status()
	if on and get_viewport() != null and get_viewport().gui_is_dragging():
		get_viewport().gui_cancel_drag()


## Shows or hides the code panel. lang: CodeView.PYTHON or CodeView.JAVASCRIPT.
func show_code(on: bool, lang: String = CodeView.PYTHON) -> void:
	_code_panel.visible = on
	if on:
		_code_view.set_code_language(lang)
		var title := "PYTHON" if lang == CodeView.PYTHON else "JAVASCRIPT"
		(_code_panel.get_child(0) as Label).text = "THE SAME PROGRAM IN " + title
		_code_view.show_program(program)
		if _highlight_id >= 0:
			_code_view.highlight_node(_highlight_id)


func is_code_visible() -> bool:
	return _code_panel.visible


func code_language() -> String:
	return _code_view.code_language


func section_refs() -> Array[String]:
	var refs: Array[String] = ["main"]
	for f in level.allowed_functions:
		refs.append("fn:" + f)
	return refs


func set_active_ref(ref: String) -> void:
	_active_ref = ref
	_update_sections()


# ------------------------------------------------------------------ editing

func append_new(kind: String) -> void:
	if _locked:
		return
	if _at_limit():
		_limit_message()
		return
	var node := _new_node(kind)
	var ref := _active_ref
	_edit_structure(func() -> void: ProgramModel.get_list(program, ref).append(node))
	Sfx.play(&"drop")
	_focus_block.call_deferred(int(node.get("id", -1)))


func delete_node(id: int) -> void:
	if _locked:
		return
	_edit_structure(func() -> void: ProgramModel.remove(program, id))
	Sfx.play(&"delete")


func set_param(id: int, key: String, value: Variant) -> void:
	if _locked:
		return
	var found := ProgramModel.find(program, id)
	if found.is_empty():
		return
	_history.push(program, "%d:%s" % [id, key])
	var node: Dictionary = found["node"]
	match key:
		"count":
			node["count"] = clampi(int(value), 1, ProgramModel.MAX_REPEAT)
		"sensor":
			(node["cond"] as Dictionary)["sensor"] = str(value)
		"negate":
			(node["cond"] as Dictionary)["negate"] = bool(value)
	_changed(false)


func undo() -> void:
	if _locked:
		return
	var prev := _history.undo(program)
	if prev.is_empty():
		return
	program = prev
	_changed(true)


func redo() -> void:
	if _locked:
		return
	var next := _history.redo(program)
	if next.is_empty():
		return
	program = next
	_changed(true)


func clear_program() -> void:
	if _locked or block_count() == 0:
		return
	_edit_structure(func() -> void:
		(program["main"] as Array).clear()
		var fns: Dictionary = program["functions"]
		for f: String in fns:
			(fns[f] as Array).clear())
	message.emit("Program cleared. Undo brings it back.")


func _edit_structure(change: Callable) -> void:
	_history.push(program)
	change.call()
	ProgramModel.assign_ids(program)
	_changed(true)


func _changed(structural: bool) -> void:
	if structural:
		_queue_render()
	else:
		_refresh_status()
	program_changed.emit(structural)


func _new_node(kind: String) -> Dictionary:
	var sensor := "path_ahead"
	if not level.allowed_sensors.is_empty():
		sensor = level.allowed_sensors[0]
	return ProgramModel.new_node(kind, sensor)


func _at_limit() -> bool:
	return level.block_limit > 0 and block_count() >= level.block_limit


func _limit_message() -> void:
	message.emit("Block limit reached (%d). Remove a block, or let a loop or function do the repeating."
			% level.block_limit)


func _ensure_function_slots() -> void:
	if not program.has("functions"):
		program["functions"] = {}
	if not program.has("main"):
		program["main"] = []
	var fns: Dictionary = program["functions"]
	for f in level.allowed_functions:
		if not fns.has(f):
			fns[f] = []


# ------------------------------------------------------------------ highlight

func highlight(id: int, ancestors: PackedInt32Array) -> void:
	_highlight_id = id
	_highlight_ancestors = ancestors
	_error_id = -1
	_apply_highlight()
	if _code_panel.visible:
		_code_view.highlight_node(id)
	if _views.has(id):
		var v: Control = _views[id]
		var vr := v.get_global_rect()
		var sr := _scroll.get_global_rect()
		if vr.position.y < sr.position.y or vr.end.y > sr.end.y:
			_scroll.ensure_control_visible(v)


func mark_error(id: int) -> void:
	_error_id = id
	_apply_highlight()


func clear_highlight() -> void:
	_highlight_id = -1
	_highlight_ancestors = PackedInt32Array()
	_error_id = -1
	_apply_highlight()
	_code_view.clear_highlight()


func _apply_highlight() -> void:
	for vid: int in _views:
		var v: BlockView = _views[vid]
		var state := BlockView.RunState.NORMAL
		if vid == _error_id:
			state = BlockView.RunState.ERROR
		elif vid == _highlight_id:
			state = BlockView.RunState.ACTIVE
		elif _highlight_ancestors.has(vid):
			state = BlockView.RunState.ANCESTOR
		v.set_run_state(state)


# ------------------------------------------------------------------ rendering

func register_list(list: BlockListView) -> void:
	_lists.append(list)


func register_view(v: BlockView) -> void:
	_views[v.node_id] = v


func register_section(ref: String, header: Control) -> void:
	_sections[ref] = header


func forward_drops(c: Control) -> void:
	c.set_drag_forwarding(Callable(), _can_drop_data, _drop_data)


func _queue_render() -> void:
	if _render_pending:
		return
	_render_pending = true
	_render.call_deferred()


func _render() -> void:
	_render_pending = false
	var keep_scroll := _scroll.scroll_vertical
	for c in _root.get_children():
		_root.remove_child(c)
		c.queue_free()
	_lists.clear()
	_views.clear()
	_sections.clear()
	for ref in section_refs():
		_root.add_child(BlockFactory.build_section(self, ref, ProgramModel.get_list(program, ref)))
	var filler := Control.new()
	filler.custom_minimum_size = Vector2(0, 140)
	filler.mouse_filter = Control.MOUSE_FILTER_PASS
	_root.add_child(filler)
	_update_sections()
	_apply_highlight()
	_apply_lock_to_widgets()
	_refresh_status()
	_scroll.set_deferred("scroll_vertical", keep_scroll)


func _build_palette() -> void:
	for c in _palette_list.get_children():
		_palette_list.remove_child(c)
		c.queue_free()
	_palette_items.clear()
	for group: Array in BlockCatalog.palette_for(level):
		_palette_list.add_child(_section_title(str(group[0])))
		for kind: String in group[1]:
			var item := BlockFactory.build_palette_item(self, kind)
			_palette_list.add_child(item)
			_palette_items.append(item)
	if not level.allowed_sensors.is_empty():
		_palette_list.add_child(_section_title("Sensors"))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 4)
		flow.add_theme_constant_override("v_separation", 4)
		for s in level.allowed_sensors:
			var chip := PanelContainer.new()
			chip.theme_type_variation = &"ChipSensor"
			chip.mouse_filter = Control.MOUSE_FILTER_PASS
			chip.tooltip_text = BlockCatalog.sensor_tip(s) + "\n\nPick sensors in the dropdown of a while or if block."
			var l := Label.new()
			l.text = s + "()"
			l.add_theme_font_size_override("font_size", 13)
			chip.add_child(l)
			flow.add_child(chip)
		_palette_list.add_child(flow)
	var tip := Label.new()
	tip.theme_type_variation = &"Muted"
	tip.add_theme_font_size_override("font_size", 13)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.text = "Drag blocks into the program, or click to add one at the end. Drag a block back here to delete it."
	_palette_list.add_child(tip)


func _section_title(text: String) -> Label:
	var l := Label.new()
	l.theme_type_variation = &"SectionTitle"
	l.text = text.to_upper()
	return l


func _update_sections() -> void:
	var several := _sections.size() > 1
	for ref: String in _sections:
		var header: PanelContainer = _sections[ref]
		var active := several and ref == _active_ref
		if ref == "main":
			header.theme_type_variation = &"SectionActive" if active else &"SectionMain"
		else:
			header.self_modulate = Color(1.25, 1.25, 1.25) if active else Color.WHITE


func _refresh_status() -> void:
	if level == null:
		return
	var count := block_count()
	var text := "Blocks: %d" % count
	if level.block_limit > 0:
		text += " / %d" % level.block_limit
	if level.par_blocks > 0:
		text += "   ·   par %d" % level.par_blocks
	_count_label.text = text
	var over := level.block_limit > 0 and count > level.block_limit
	var tone := &"bad" if over else (&"warn" if _at_limit() else &"text")
	_count_label.add_theme_color_override("font_color", get_theme_color(tone, &"Palette"))
	var full := _at_limit()
	for item in _palette_items:
		item.set_enabled(not _locked and not full)
	_undo_button.disabled = _locked or not _history.can_undo()
	_redo_button.disabled = _locked or not _history.can_redo()
	_clear_button.disabled = _locked or count == 0
	if _code_panel.visible:
		_code_view.show_program(program)
		if _highlight_id >= 0:
			_code_view.highlight_node(_highlight_id)


func _apply_lock_to_widgets() -> void:
	for vid: int in _views:
		var v: BlockView = _views[vid]
		v.mouse_default_cursor_shape = Control.CURSOR_ARROW if _locked else Control.CURSOR_DRAG
		for w in v.widgets:
			if w is SpinBox:
				(w as SpinBox).editable = not _locked
			elif w is OptionButton or w.theme_type_variation == &"NotToggle":
				# Keep their look while running (the program must stay readable);
				# just stop them taking clicks.
				w.mouse_filter = Control.MOUSE_FILTER_IGNORE if _locked else Control.MOUSE_FILTER_STOP
			elif w is BaseButton:
				(w as BaseButton).disabled = _locked


func _focus_block(id: int) -> void:
	if not _views.has(id):
		return
	var v: Control = _views[id]
	v.modulate = Color(1.7, 1.7, 1.7)
	v.create_tween().tween_property(v, "modulate", Color.WHITE, 0.4)
	v.resized.connect(func() -> void: _scroll.ensure_control_visible(v), CONNECT_ONE_SHOT)


# ------------------------------------------------------------------ drag and drop

func begin_drag_new(src: Control, kind: String, at: Vector2) -> Variant:
	if _locked:
		return null
	if _at_limit():
		_limit_message()
		return null
	_set_preview(src, BlockFactory.build_preview(_new_node(kind)), at)
	return {"rmz": true, "kind": "new", "block": kind}


func begin_drag_existing(view: BlockView, at: Vector2) -> Variant:
	if _locked:
		return null
	var found := ProgramModel.find(program, view.node_id)
	if found.is_empty():
		return null
	_set_preview(view, BlockFactory.build_preview(found["node"]), at)
	_drag_source = view
	view.modulate.a = 0.35
	return {"rmz": true, "kind": "move", "id": view.node_id}


func _set_preview(src: Control, preview: Control, at: Vector2) -> void:
	var wrapper := Control.new()
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.add_child(preview)
	preview.position = -at
	preview.modulate = Color(1, 1, 1, 0.92)
	src.set_drag_preview(wrapper)


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	var r := _resolve(data)
	_show_feedback(r)
	return bool(r["ok"])


func _drop_data(_at: Vector2, data: Variant) -> void:
	var r := _resolve(data)
	_hide_feedback()
	if not bool(r["ok"]):
		return
	var d: Dictionary = data
	if r["mode"] == "delete":
		delete_node(int(d["id"]))
		return
	var ref: String = r["ref"]
	var index: int = r["index"]
	if d["kind"] == "new":
		var node := _new_node(str(d["block"]))
		_edit_structure(func() -> void: ProgramModel.insert(program, ref, index, node))
		_focus_block.call_deferred(int(node.get("id", -1)))
	else:
		var id := int(d["id"])
		var found := ProgramModel.find(program, id)
		if found.is_empty():
			return
		if found["ref"] == ref and (index == int(found["index"]) or index == int(found["index"]) + 1):
			return
		_edit_structure(func() -> void: ProgramModel.move_node(program, id, ref, index))
	Sfx.play(&"drop")


## Where a drop at the current mouse position would go:
## {"ok": bool, "mode": "insert"|"delete", "ref", "index", "line": Rect2 (global)}
func _resolve(data: Variant) -> Dictionary:
	var no := {"ok": false}
	if _locked or typeof(data) != TYPE_DICTIONARY:
		return no
	var d: Dictionary = data
	if not bool(d.get("rmz", false)):
		return no
	var kind := str(d.get("kind", ""))
	var m := get_global_mouse_position()
	if _palette.get_global_rect().has_point(m) or _trash_button.get_global_rect().has_point(m):
		return {"ok": kind == "move", "mode": "delete"}
	if not _scroll.get_global_rect().has_point(m):
		return no
	if kind == "new" and _at_limit():
		return no
	var list: BlockListView = null
	for i in range(_lists.size() - 1, -1, -1):
		var l := _lists[i]
		if l.is_visible_in_tree() and l.hit_rect().has_point(m):
			list = l
			break
	var index := 0
	if list == null:
		list = _section_list_at(m.y)
		if list == null:
			return no
		index = list.block_views.size()
	else:
		index = list.index_at(m.y)
	if kind == "move" and _would_nest_in_itself(int(d["id"]), list.ref):
		return no
	return {"ok": true, "mode": "insert", "ref": list.ref, "index": index, "line": list.line_rect(index)}


## For drops in empty space: the top-level list of the section above the mouse.
func _section_list_at(global_y: float) -> BlockListView:
	var best: BlockListView = null
	for l in _lists:
		if l.depth != 0:
			continue
		if best == null or l.hit_rect().position.y <= global_y:
			best = l
	return best


func _would_nest_in_itself(id: int, ref: String) -> bool:
	var parts := ref.split(":")
	if parts.size() != 2 or not parts[0].is_valid_int():
		return false
	var owner_id := parts[0].to_int()
	if owner_id == id:
		return true
	var found := ProgramModel.find(program, id)
	return not found.is_empty() and ProgramModel.subtree_contains(found["node"], owner_id)


func _show_feedback(r: Dictionary) -> void:
	if not bool(r.get("ok", false)):
		_drop_line.hide()
		_tint_delete(false)
		return
	if r["mode"] == "delete":
		_drop_line.hide()
		_tint_delete(true)
		return
	_tint_delete(false)
	var rect: Rect2 = r["line"]
	_drop_line.global_position = rect.position
	_drop_line.size = rect.size
	_drop_line.show()


func _hide_feedback() -> void:
	_drop_line.hide()
	_tint_delete(false)


func _tint_delete(on: bool) -> void:
	var c := Color(1.0, 0.55, 0.55) if on else Color.WHITE
	_palette.self_modulate = c
	_trash_button.modulate = c


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		var data: Variant = get_viewport().gui_get_drag_data()
		if typeof(data) == TYPE_DICTIONARY and bool((data as Dictionary).get("rmz", false)):
			# Commits a half-typed repeat count before anything is rebuilt.
			get_viewport().gui_release_focus()
			_scroll_accum = 0.0
			set_process(true)
	elif what == NOTIFICATION_DRAG_END:
		set_process(false)
		_hide_feedback()
		if is_instance_valid(_drag_source):
			_drag_source.modulate.a = 1.0
		_drag_source = null


## While dragging: scroll near the top/bottom edge, and hide the insertion
## line when the mouse leaves (no drop callbacks fire outside the editor).
func _process(delta: float) -> void:
	var vp := get_viewport()
	if not vp.gui_is_dragging():
		set_process(false)
		return
	var m := get_global_mouse_position()
	var r := _scroll.get_global_rect()
	if not get_global_rect().has_point(m):
		_hide_feedback()
	var v := 0.0
	if m.x > r.position.x and m.x < r.end.x:
		if m.y < r.position.y + AUTO_SCROLL_EDGE and m.y > r.position.y - 24.0:
			v = -AUTO_SCROLL_SPEED * (1.0 - clampf((m.y - r.position.y) / AUTO_SCROLL_EDGE, 0.0, 1.0))
		elif m.y > r.end.y - AUTO_SCROLL_EDGE and m.y < r.end.y + 24.0:
			v = AUTO_SCROLL_SPEED * (1.0 - clampf((r.end.y - m.y) / AUTO_SCROLL_EDGE, 0.0, 1.0))
	if v != 0.0:
		_scroll_accum += v * delta
		var step := int(_scroll_accum)
		_scroll_accum -= step
		if step != 0:
			_scroll.scroll_vertical += step
			_show_feedback(_resolve(vp.gui_get_drag_data()))


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or not is_visible_in_tree():
		return
	if k.is_command_or_control_pressed() and k.keycode == KEY_Z:
		if k.shift_pressed:
			redo()
		else:
			undo()
		get_viewport().set_input_as_handled()
	elif k.is_command_or_control_pressed() and k.keycode == KEY_Y:
		redo()
		get_viewport().set_input_as_handled()
