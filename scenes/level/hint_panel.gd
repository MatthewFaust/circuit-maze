class_name HintPanel
extends PanelContainer
## A card over the maze that reveals a level's hints one at a time and keeps
## the earlier ones visible. The last hint also shows the level's solution as
## blocks, so a stuck player can always finish the level.

signal revealed(count: int)

const CLOSE_ICON := preload("res://art/ui/close.svg")
const WIDTH := 440.0
const MARGIN := 12.0

var _hints := PackedStringArray()
var _solution_text := ""
var _shown := 0
var _count: Label
var _list: VBoxContainer
var _scroll: ScrollContainer
var _next: Button


func _ready() -> void:
	theme_type_variation = &"DialogPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	add_child(col)
	var header := HBoxContainer.new()
	col.add_child(header)
	var title := Label.new()
	title.theme_type_variation = &"TitleLabel"
	title.add_theme_font_size_override("font_size", 20)
	title.text = "Hints"
	header.add_child(title)
	_count = Label.new()
	_count.theme_type_variation = &"Muted"
	_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_count)
	var close := Button.new()
	close.theme_type_variation = &"ToolButton"
	close.icon = CLOSE_ICON
	close.focus_mode = Control.FOCUS_NONE
	close.tooltip_text = "Close the hints (H opens them again)"
	close.add_theme_constant_override("icon_max_width", 14)
	close.pressed.connect(hide)
	header.add_child(close)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 14)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	_next = Button.new()
	_next.theme_type_variation = &"PrimaryButton"
	_next.focus_mode = Control.FOCUS_NONE
	_next.pressed.connect(reveal_next)
	col.add_child(_next)
	hide()
	get_parent().resized.connect(_fit)
	# Wrapped text only knows its height after layout: refit when it changes.
	_list.minimum_size_changed.connect(func() -> void: _fit.call_deferred())


## hints: the level's hints, in order. solution_text: the program shown with the last one.
func setup(hints: PackedStringArray, solution_text: String) -> void:
	_hints = hints
	_solution_text = solution_text
	_shown = 0
	for c in _list.get_children():
		c.queue_free()
	hide()


func shown_count() -> int:
	return _shown


## The Hint button: opens the card (with the first hint), shows the next hint,
## and closes the card once every hint is showing.
func toggle_or_advance() -> void:
	if _hints.is_empty():
		return
	if not visible:
		if _shown == 0:
			reveal_next()
		show()
		_fit.call_deferred()
	elif _shown < _hints.size():
		reveal_next()
	else:
		hide()


func reveal_next() -> void:
	if _shown >= _hints.size():
		return
	_shown += 1
	_list.add_child(_entry(_shown))
	_update_footer()
	show()
	_fit.call_deferred()
	_scroll_to_end.call_deferred()
	revealed.emit(_shown)


func _entry(n: int) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var last := n == _hints.size()
	var heading := Label.new()
	heading.theme_type_variation = &"SectionTitle"
	heading.text = "HINT %d · THE FULL SOLUTION" % n if last else "HINT %d" % n
	box.add_child(heading)
	box.add_child(_rich(_hints[n - 1]))
	if last and _solution_text != "":
		var lead := Label.new()
		lead.theme_type_variation = &"Muted"
		lead.text = "This program escapes every map and earns all three stars:"
		lead.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(lead)
		var code_box := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = get_theme_color(&"well", &"Palette")
		sb.border_color = get_theme_color(&"line", &"Palette")
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(8)
		sb.set_content_margin_all(10)
		code_box.add_theme_stylebox_override("panel", sb)
		var code := _rich("[code]%s[/code]" % _solution_text.replace("[", "[lb]"))
		code.add_theme_font_size_override("mono_font_size", 15)
		code.autowrap_mode = TextServer.AUTOWRAP_OFF
		code_box.add_child(code)
		box.add_child(code_box)
	return box


func _rich(bbcode: String) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.selection_enabled = true
	r.text = bbcode
	return r


func _update_footer() -> void:
	_count.text = "  %d of %d" % [_shown, _hints.size()]
	_next.visible = _shown < _hints.size()
	if _shown == _hints.size() - 1:
		_next.text = "Show hint %d: the full solution" % (_shown + 1)
	else:
		_next.text = "Show hint %d" % (_shown + 1)


## Top-right of the maze, as tall as its content but never taller than the maze.
func _fit() -> void:
	var area: Control = get_parent()
	if area == null or not visible:
		return
	var w := minf(WIDTH, area.size.x - 2.0 * MARGIN)
	custom_minimum_size.x = w
	# Header and button heights: the panel's minimum minus the scroll area's.
	var chrome := get_combined_minimum_size().y - _scroll.custom_minimum_size.y
	var room := maxf(area.size.y - 2.0 * MARGIN - chrome, 80.0)
	var h := minf(_list.get_combined_minimum_size().y, room)
	if not is_equal_approx(_scroll.custom_minimum_size.y, h):
		_scroll.custom_minimum_size.y = h
	size = Vector2(w, 0)
	position = Vector2(area.size.x - w - MARGIN, MARGIN)


func _scroll_to_end() -> void:
	await get_tree().process_frame
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)
