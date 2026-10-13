class_name CodeView
extends CodeEdit
## Read-only Python view of the program, with the running line highlighted.

const RUN_LINE := Color(1.0, 0.82, 0.3, 0.22)

var _line_of := {}
var _highlighted := -1


func _ready() -> void:
	editable = false
	gutters_draw_line_numbers = true
	scroll_fit_content_height = false
	wrap_mode = TextEdit.LINE_WRAPPING_NONE
	context_menu_enabled = false
	shortcut_keys_enabled = false
	focus_mode = Control.FOCUS_NONE
	var h := CodeHighlighter.new()
	h.number_color = Color("#FFD166")
	h.symbol_color = Color("#9AA4B8")
	h.function_color = Color("#7FB5FF")
	h.member_variable_color = Color("#E6EAF2")
	for kw in ["def", "for", "in", "range", "while", "if", "elif", "else", "not", "pass"]:
		h.add_keyword_color(kw, Color("#FF7AB6"))
	for s: String in ProgramModel.SENSORS:
		h.add_keyword_color(s, Color("#5EE6D8"))
	h.add_color_region("#", "", Color("#5D6884"), true)
	syntax_highlighter = h


func show_program(p: Dictionary) -> void:
	var r := ProgramPrinter.render(p)
	var t: String = r["text"]
	text = t if t != "" else "# empty program: add blocks on the left"
	_line_of = r["line_of"]
	_highlighted = -1


func highlight_node(id: int) -> void:
	clear_highlight()
	if not _line_of.has(id):
		return
	var line: int = _line_of[id]
	if line < get_line_count():
		set_line_background_color(line, RUN_LINE)
		_highlighted = line
		set_line_as_center_visible(line)


func clear_highlight() -> void:
	if _highlighted >= 0 and _highlighted < get_line_count():
		set_line_background_color(_highlighted, Color(0, 0, 0, 0))
	_highlighted = -1
