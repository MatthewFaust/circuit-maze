extends Control
## Volume, sound, motion, dark mode and unlock settings. Changes apply and save immediately.

signal closed
## Dark mode was switched: the screen behind should rebuild its colors.
signal appearance_changed

var _confirm_reset := false

@onready var _volume: HSlider = %Volume
@onready var _sfx: CheckButton = %Sfx
@onready var _reduce_motion: CheckButton = %ReduceMotion
@onready var _unlock_all: CheckButton = %UnlockAll
@onready var _reset: Button = %ResetProgress
@onready var _close: Button = %Close
var _dark: CheckButton


func _ready() -> void:
	hide()
	_volume.value_changed.connect(func(v: float) -> void: Progress.set_setting("volume", v))
	_sfx.toggled.connect(func(on: bool) -> void: Progress.set_setting("sfx", on))
	_reduce_motion.toggled.connect(func(on: bool) -> void: Progress.set_setting("reduce_motion", on))
	_unlock_all.toggled.connect(func(on: bool) -> void: Progress.set_setting("unlock_all", on))
	# Built here rather than in the scene: one more switch above "Unlock all".
	_dark = CheckButton.new()
	_dark.text = "Dark mode"
	_dark.focus_mode = _sfx.focus_mode
	_dark.tooltip_text = "Switch every chapter between its light and dark colors."
	_unlock_all.add_sibling(_dark)
	_unlock_all.get_parent().move_child(_dark, _unlock_all.get_index())
	_dark.toggled.connect(func(on: bool) -> void:
		Progress.set_setting("dark_mode", on)
		appearance_changed.emit())
	_reset.pressed.connect(_on_reset)
	_close.pressed.connect(close)


func open() -> void:
	refresh_colors()
	# The mode in use (the --dark developer option can switch it without saving).
	_dark.set_pressed_no_signal(ChapterPalette.dark_mode)
	_volume.set_value_no_signal(float(Progress.get_setting("volume", 0.8)))
	_sfx.set_pressed_no_signal(bool(Progress.get_setting("sfx", true)))
	_reduce_motion.set_pressed_no_signal(bool(Progress.get_setting("reduce_motion", false)))
	_unlock_all.set_pressed_no_signal(bool(Progress.get_setting("unlock_all", false)))
	_confirm_reset = false
	_reset.text = "Reset progress..."
	show()


## Here, not in _ready: the main menu sets its chapter theme after its children are ready.
func refresh_colors() -> void:
	($Dim as ColorRect).color = get_theme_color(&"dim", &"Palette")


func close() -> void:
	Progress.save()
	hide()
	closed.emit()


func _on_reset() -> void:
	if not _confirm_reset:
		_confirm_reset = true
		_reset.text = "Click again to erase all stars"
		return
	Progress.reset_progress()
	_confirm_reset = false
	_reset.text = "Progress erased"


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
