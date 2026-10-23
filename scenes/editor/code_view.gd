class_name CodeView
extends CodeEdit
## Read-only view of the program as Python or JavaScript, with the running
## line highlighted.

const PYTHON := "python"
const JAVASCRIPT := "javascript"
const KEYWORDS := {
	PYTHON: ["def", "for", "in", "range", "while", "if", "elif", "else", "not", "pass"],
	JAVASCRIPT: ["function", "for", "let", "while", "if", "else"],
}
const COMMENT := {PYTHON: "#", JAVASCRIPT: "//"}

## CodeView.PYTHON or CodeView.JAVASCRIPT. (TextEdit already has "language".)
var code_language := PYTHON

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
	_build_highlighter()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and is_node_ready():
		_build_highlighter()


## Syntax colors come from the chapter palette.
func _build_highlighter() -> void:
	var h := CodeHighlighter.new()
	h.number_color = _pal(&"code_number")
	h.symbol_color = _pal(&"code_symbol")
	h.function_color = _pal(&"code_function")
	h.member_variable_color = _pal(&"text")
	for kw: String in KEYWORDS[code_language]:
		h.add_keyword_color(kw, _pal(&"code_keyword"))
	for s: String in ProgramModel.SENSORS:
		h.add_keyword_color(s, _pal(&"code_sensor"))
	h.add_color_region(COMMENT[code_language], "", _pal(&"code_comment"), true)
	syntax_highlighter = h


func _pal(role: StringName) -> Color:
	return get_theme_color(role, &"Palette")


func set_code_language(lang: String) -> void:
	if lang == code_language:
		return
	code_language = lang
	_build_highlighter()


func show_program(p: Dictionary) -> void:
	var r := ProgramPrinter.render_js(p) if code_language == JAVASCRIPT else ProgramPrinter.render(p)
	var t: String = r["text"]
	text = t if t != "" else COMMENT[code_language] + " empty program: add blocks on the left"
	_line_of = r["line_of"]
	_highlighted = -1


func highlight_node(id: int) -> void:
	clear_highlight()
	if not _line_of.has(id):
		return
	var line: int = _line_of[id]
	if line < get_line_count():
		set_line_background_color(line, _pal(&"run_line"))
		_highlighted = line
		set_line_as_center_visible(line)


func clear_highlight() -> void:
	if _highlighted >= 0 and _highlighted < get_line_count():
		set_line_background_color(_highlighted, Color(0, 0, 0, 0))
	_highlighted = -1
