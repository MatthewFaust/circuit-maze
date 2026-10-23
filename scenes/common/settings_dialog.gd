extends Control
## Volume, sound, motion and unlock settings. Changes apply and save immediately.

signal closed

var _confirm_reset := false

@onready var _volume: HSlider = %Volume
@onready var _sfx: CheckButton = %Sfx
@onready var _reduce_motion: CheckButton = %ReduceMotion
@onready var _unlock_all: CheckButton = %UnlockAll
@onready var _reset: Button = %ResetProgress
@onready var _close: Button = %Close


func _ready() -> void:
	hide()
	_volume.value_changed.connect(func(v: float) -> void: Progress.set_setting("volume", v))
	_sfx.toggled.connect(func(on: bool) -> void: Progress.set_setting("sfx", on))
	_reduce_motion.toggled.connect(func(on: bool) -> void: Progress.set_setting("reduce_motion", on))
	_unlock_all.toggled.connect(func(on: bool) -> void: Progress.set_setting("unlock_all", on))
	_reset.pressed.connect(_on_reset)
	_close.pressed.connect(close)


func open() -> void:
	# Here, not in _ready: the main menu sets its chapter theme after its children are ready.
	($Dim as ColorRect).color = get_theme_color(&"dim", &"Palette")
	_volume.set_value_no_signal(float(Progress.get_setting("volume", 0.8)))
	_sfx.set_pressed_no_signal(bool(Progress.get_setting("sfx", true)))
	_reduce_motion.set_pressed_no_signal(bool(Progress.get_setting("reduce_motion", false)))
	_unlock_all.set_pressed_no_signal(bool(Progress.get_setting("unlock_all", false)))
	_confirm_reset = false
	_reset.text = "Reset progress..."
	show()


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
