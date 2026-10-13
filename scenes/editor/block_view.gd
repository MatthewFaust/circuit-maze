class_name BlockView
extends PanelContainer
## One block in the program. Holds only the node id; the program Dictionary in
## ProgramEditor is the source of truth. Dragging it moves the block.

enum RunState { NORMAL, ACTIVE, ANCESTOR, ERROR }

const ACTIVE_COLOR := Color(1.0, 0.88, 0.4)
const ANCESTOR_COLOR := Color(1.0, 0.95, 0.75, 0.85)
const ERROR_COLOR := Color(1.0, 0.36, 0.36)

var node_id := -1
var kind := ""
var editor: ProgramEditor
## Widgets the editor disables while a program runs.
var widgets: Array[Control] = []
var run_state: int = RunState.NORMAL


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_default_cursor_shape = Control.CURSOR_DRAG


func _get_drag_data(at_position: Vector2) -> Variant:
	if editor == null:
		return null
	return editor.begin_drag_existing(self, at_position)


func set_run_state(state: int) -> void:
	if state == run_state:
		return
	run_state = state
	remove_theme_stylebox_override("panel")
	if state == RunState.NORMAL:
		return
	var base := get_theme_stylebox("panel")
	if not (base is StyleBoxFlat):
		return
	var sb: StyleBoxFlat = base.duplicate()
	var width := 3 if state != RunState.ANCESTOR else 2
	sb.border_width_left = width
	sb.border_width_top = width
	sb.border_width_right = width
	sb.border_width_bottom = width + 1
	match state:
		RunState.ACTIVE:
			sb.border_color = ACTIVE_COLOR
			sb.shadow_color = Color(1.0, 0.85, 0.3, 0.55)
			sb.shadow_size = 10
		RunState.ANCESTOR:
			sb.border_color = ANCESTOR_COLOR
		RunState.ERROR:
			sb.border_color = ERROR_COLOR
			sb.shadow_color = Color(1.0, 0.2, 0.2, 0.5)
			sb.shadow_size = 10
	add_theme_stylebox_override("panel", sb)
