class_name PaletteItem
extends PanelContainer
## A block in the palette. Drag it into the program, or click it to append it
## to the active section.

var kind := ""
var editor: ProgramEditor
var enabled := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func() -> void:
		if enabled:
			self_modulate = Color(1.15, 1.15, 1.15))
	mouse_exited.connect(func() -> void: self_modulate = Color.WHITE)


func set_enabled(on: bool) -> void:
	enabled = on
	modulate = Color(1, 1, 1, 1.0 if on else 0.4)


func _get_drag_data(at_position: Vector2) -> Variant:
	if editor == null or not enabled or editor.is_locked():
		return null
	return editor.begin_drag_new(self, kind, at_position)


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT or mb.pressed:
		return
	# A release that wasn't part of a drag is a click.
	if editor != null and enabled and not editor.is_locked():
		editor.append_new(kind)
	accept_event()
