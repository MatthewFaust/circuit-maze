class_name BlockFactory
extends RefCounted
## Builds the editor's controls from the program model: sections, block lists,
## blocks, palette items and drag previews.
##
## Mouse filters matter here: everything between a block and the ProgramEditor
## root must be PASS or IGNORE, or drops would stop there. Interactive widgets
## (STOP by default) forward drops to the editor.

const CLOSE_ICON := preload("res://art/ui/close.svg")
const INDENT := 18
const WELL_MIN_HEIGHT := 34


static func build_section(ed: ProgramEditor, ref: String, nodes: Array) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	var header := PanelContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_PASS
	var is_main := ref == "main"
	header.theme_type_variation = &"SectionMain" if is_main else &"SectionFunc"
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	header.add_child(row)
	var title := Label.new()
	title.theme_type_variation = &"BlockLabel"
	title.text = "Program (main)" if is_main else "define %s():" % ref.substr(3)
	row.add_child(title)
	var hint := Label.new()
	hint.theme_type_variation = &"Muted"
	hint.add_theme_font_size_override("font_size", 14)
	hint.text = "runs first" if is_main else "runs when you call %s()" % ref.substr(3)
	if not is_main:
		hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(hint)
	header.gui_input.connect(func(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			ed.set_active_ref(ref))
	header.tooltip_text = "Click to make this the section that palette clicks add to."
	box.add_child(header)
	box.add_child(build_list(ed, ref, nodes, 0))
	ed.register_section(ref, header)
	return box


## A well containing a BlockListView with the given nodes.
static func build_list(ed: ProgramEditor, ref: String, nodes: Array, depth: int) -> Control:
	var well := PanelContainer.new()
	well.theme_type_variation = &"BodyWell"
	well.mouse_filter = Control.MOUSE_FILTER_PASS
	well.custom_minimum_size = Vector2(0, WELL_MIN_HEIGHT)
	var list := BlockListView.new()
	list.ref = ref
	list.depth = depth
	list.well = well
	list.add_theme_constant_override("separation", 6)
	well.add_child(list)
	ed.register_list(list)
	if nodes.is_empty():
		var empty := Label.new()
		empty.theme_type_variation = &"Muted"
		empty.add_theme_font_size_override("font_size", 14)
		empty.text = "drop blocks here" if depth == 0 else "drop blocks inside"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.modulate = Color(1, 1, 1, 0.6)
		list.add_child(empty)
	for node: Dictionary in nodes:
		var v := build_block(ed, node, depth)
		list.add_child(v)
		list.block_views.append(v)
	return well


static func build_block(ed: ProgramEditor, node: Dictionary, depth: int) -> BlockView:
	var kind := BlockCatalog.kind_of(node)
	var v := BlockView.new()
	v.editor = ed
	v.kind = kind
	v.node_id = node.get("id", -1)
	v.theme_type_variation = BlockCatalog.variation(kind)
	v.tooltip_text = BlockCatalog.tooltip(kind)
	ed.register_view(v)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_PASS
	col.add_theme_constant_override("separation", 4)
	v.add_child(col)
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_PASS
	header.add_theme_constant_override("separation", 6)
	col.add_child(header)
	header.add_child(_icon(kind))
	header.add_child(_label(BlockCatalog.label(kind)))
	var t: String = node["type"]
	var id := v.node_id
	if t == "repeat":
		var spin := SpinBox.new()
		spin.min_value = 1
		spin.max_value = ProgramModel.MAX_REPEAT
		spin.rounded = true
		spin.select_all_on_focus = true
		spin.custom_minimum_size = Vector2(84, 0)
		spin.set_value_no_signal(int(node["count"]))
		spin.value_changed.connect(func(value: float) -> void: ed.set_param(id, "count", int(value)))
		# SpinBox only applies typed text in a deferred call after editing ends,
		# so Run would read the old count. Apply it the moment focus leaves.
		var le := spin.get_line_edit()
		le.focus_exited.connect(spin.apply)
		# select_all_on_focus skips mouse clicks, so typing "8" into "2" would
		# give "28". Select when the click that focused the box is released.
		le.focus_entered.connect(func() -> void: le.set_meta(&"select_on_release", true))
		le.gui_input.connect(func(event: InputEvent) -> void:
			var mb := event as InputEventMouseButton
			if mb != null and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed \
					and le.get_meta(&"select_on_release", false):
				le.set_meta(&"select_on_release", false)
				le.select_all.call_deferred())
		spin.tooltip_text = "How many times to repeat"
		_widget(ed, v, spin)
		header.add_child(spin)
		header.add_child(_label("times"))
	elif ProgramModel.CONTAINERS.has(t):
		header.add_child(build_condition(ed, v, node))
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_PASS
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var del := Button.new()
	del.icon = CLOSE_ICON
	del.theme_type_variation = &"ToolButton"
	del.focus_mode = Control.FOCUS_NONE
	del.tooltip_text = "Delete this block"
	del.add_theme_constant_override("icon_max_width", 14)
	del.pressed.connect(ed.delete_node.bind(id))
	_widget(ed, v, del)
	header.add_child(del)
	if ProgramModel.CONTAINERS.has(t):
		col.add_child(_indented(build_list(ed, "%d:body" % id, node["body"], depth + 1)))
		if t == "if_else":
			col.add_child(_label("else"))
			col.add_child(_indented(build_list(ed, "%d:else" % id, node["else_body"], depth + 1)))
	return v


## The condition pill: [not] [sensor dropdown].
static func build_condition(ed: ProgramEditor, v: BlockView, node: Dictionary) -> Control:
	var id := v.node_id
	var c: Dictionary = node["cond"]
	var pill := PanelContainer.new()
	pill.theme_type_variation = &"BlockSensing"
	pill.mouse_filter = Control.MOUSE_FILTER_PASS
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_theme_constant_override("separation", 4)
	pill.add_child(row)
	if ed.level.allow_not or bool(c.get("negate", false)):
		var neg := Button.new()
		neg.toggle_mode = true
		neg.text = "not"
		neg.focus_mode = Control.FOCUS_NONE
		neg.theme_type_variation = &"NotToggle"
		neg.tooltip_text = "Click to flip the condition (\"not\"): true becomes false and false becomes true."
		neg.set_pressed_no_signal(bool(c.get("negate", false)))
		neg.toggled.connect(func(on: bool) -> void: ed.set_param(id, "negate", on))
		_widget(ed, v, neg)
		row.add_child(neg)
	var opt := OptionButton.new()
	opt.focus_mode = Control.FOCUS_NONE
	opt.fit_to_longest_item = false
	opt.clip_text = true
	opt.custom_minimum_size = Vector2(196, 0)
	opt.add_theme_font_size_override("font_size", 16)
	var sensors: Array = Array(ed.level.allowed_sensors)
	var current := str(c.get("sensor", ""))
	if not sensors.has(current):
		sensors.append(current)
	for s: String in sensors:
		opt.add_item(s + "()")
		opt.set_item_metadata(opt.item_count - 1, s)
		opt.set_item_tooltip(opt.item_count - 1, BlockCatalog.sensor_tip(s))
	opt.select(sensors.find(current))
	opt.tooltip_text = BlockCatalog.sensor_tip(current)
	opt.item_selected.connect(func(index: int) -> void:
		var sensor: String = opt.get_item_metadata(index)
		opt.tooltip_text = BlockCatalog.sensor_tip(sensor)
		ed.set_param(id, "sensor", sensor))
	_widget(ed, v, opt)
	row.add_child(opt)
	return pill


static func build_palette_item(ed: ProgramEditor, kind: String) -> PaletteItem:
	var item := PaletteItem.new()
	item.editor = ed
	item.kind = kind
	item.theme_type_variation = BlockCatalog.variation(kind)
	item.tooltip_text = BlockCatalog.tooltip(kind) + "\n\nDrag into the program, or click to add it at the end."
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	item.add_child(row)
	row.add_child(_icon(kind))
	row.add_child(_label(_palette_label(kind)))
	return item


## A non-interactive copy of a block, used as the drag preview.
static func build_preview(node: Dictionary, depth: int = 0) -> Control:
	var kind := BlockCatalog.kind_of(node)
	var panel := PanelContainer.new()
	panel.theme_type_variation = BlockCatalog.variation(kind)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(col)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)
	row.add_child(_icon(kind))
	row.add_child(_label(_summary(node)))
	var t: String = node.get("type", "")
	if ProgramModel.CONTAINERS.has(t):
		var body: Array = node.get("body", [])
		if depth >= 2 and not body.is_empty():
			col.add_child(_label("  … %d more" % body.size()))
		else:
			for child: Dictionary in body:
				var m := MarginContainer.new()
				m.mouse_filter = Control.MOUSE_FILTER_IGNORE
				m.add_theme_constant_override("margin_left", INDENT)
				m.add_child(build_preview(child, depth + 1))
				col.add_child(m)
	return panel


static func _summary(node: Dictionary) -> String:
	var kind := BlockCatalog.kind_of(node)
	var t: String = node.get("type", "")
	if t == "repeat":
		return "repeat %d times" % int(node.get("count", 2))
	if node.has("cond"):
		return "%s %s" % [BlockCatalog.label(kind), ProgramPrinter.cond_text(node["cond"])]
	return BlockCatalog.label(kind)


static func _palette_label(kind: String) -> String:
	match kind:
		"repeat":
			return "repeat N times"
		"while":
			return "while …"
		"if":
			return "if …"
		"if_else":
			return "if … else"
	return BlockCatalog.label(kind)


static func _icon(kind: String) -> TextureRect:
	var r := TextureRect.new()
	r.texture = BlockCatalog.icon(kind)
	r.custom_minimum_size = Vector2(22, 22)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func _label(text: String) -> Label:
	var l := Label.new()
	l.theme_type_variation = &"BlockLabel"
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func _indented(c: Control) -> Control:
	var m := MarginContainer.new()
	m.mouse_filter = Control.MOUSE_FILTER_PASS
	m.add_theme_constant_override("margin_left", INDENT)
	m.add_child(c)
	return m


static func _widget(ed: ProgramEditor, v: BlockView, c: Control) -> void:
	ed.forward_drops(c)
	v.widgets.append(c)
