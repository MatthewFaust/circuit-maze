class_name HudBars
extends HBoxContainer
## The health and stamina bars in the top bar.

@onready var _hp_bar: ProgressBar = %HPBar
@onready var _hp_text: Label = %HPText
@onready var _stamina_bar: ProgressBar = %StaminaBar
@onready var _stamina_text: Label = %StaminaText

var _hp_tween: Tween
var _stamina_tween: Tween


func sync(world: MazeWorld) -> void:
	set_hp(world.robot.hp, world.robot.max_hp, false)
	set_stamina(world.robot.stamina, world.robot.max_stamina, false)


func set_hp(value: int, max_value: int, animate: bool = true) -> void:
	_hp_text.text = "%d / %d" % [value, max_value]
	_hp_tween = _set_bar(_hp_bar, _hp_tween, value, max_value, animate)


func set_stamina(value: int, max_value: int, animate: bool = true) -> void:
	_stamina_text.text = "%d / %d" % [value, max_value]
	_stamina_tween = _set_bar(_stamina_bar, _stamina_tween, value, max_value, animate)


## Instant HUD reaction to a world event.
func apply_event(e: Dictionary, animate: bool = true) -> void:
	match str(e["type"]):
		"hp_changed":
			set_hp(int(e["value"]), int(e["max"]), animate)
			if int(e["delta"]) < 0 and animate:
				_flash(_hp_bar, Color(1.6, 0.7, 0.7))
		"stamina_changed":
			set_stamina(int(e["value"]), int(e["max"]), animate)
			if int(e["delta"]) > 0 and animate:
				_flash(_stamina_bar, Color(1.5, 1.4, 0.7))


func _set_bar(bar: ProgressBar, tween: Tween, value: int, max_value: int, animate: bool) -> Tween:
	bar.max_value = maxi(max_value, 1)
	if tween != null and tween.is_valid():
		tween.kill()
	if not animate or Game.reduce_motion():
		bar.value = value
		return null
	var t := bar.create_tween()
	t.tween_property(bar, "value", float(value), 0.18).set_ease(Tween.EASE_OUT)
	return t


func _flash(c: Control, color: Color) -> void:
	c.modulate = color
	c.create_tween().tween_property(c, "modulate", Color.WHITE, 0.35)
