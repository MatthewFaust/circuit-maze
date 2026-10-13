extends Control
## Title screen. Also routes command-line developer options (see Game).

const FLOOR_TEX := preload("res://art/tiles/floor.svg")
const STONE_TEX := preload("res://art/tiles/stone.svg")
const BUSH_TEX := preload("res://art/tiles/bush.svg")
const BACKDROP_CELL := 96.0

@onready var _backdrop: Control = %Backdrop
@onready var _logo: TextureRect = %Logo
@onready var _play: Button = %PlayButton
@onready var _continue: Button = %ContinueButton
@onready var _settings: Button = %SettingsButton
@onready var _quit: Button = %QuitButton
@onready var _settings_dialog: Control = %SettingsDialog


func _ready() -> void:
	if Game.route_dev_args():
		return
	for b: Button in [_play, _continue, _settings, _quit]:
		b.focus_mode = Control.FOCUS_NONE
	_play.pressed.connect(func() -> void:
		Sfx.play(&"click")
		Game.goto_level_select())
	var last := Progress.data.last_level
	var last_level: LevelData = Game.catalog.get_level(last) if last != "" else null
	if last_level != null:
		_continue.text = "Continue: %s %s" % [last_level.id, last_level.title]
		_continue.pressed.connect(func() -> void: Game.goto_level(last))
	else:
		_continue.hide()
	_settings.pressed.connect(_settings_dialog.call.bind("open"))
	_quit.pressed.connect(func() -> void: get_tree().quit())
	if OS.has_feature("web"):
		_quit.hide()
	_backdrop.draw.connect(_draw_backdrop)
	_backdrop.resized.connect(_backdrop.queue_redraw)
	if not Game.reduce_motion():
		var t := create_tween().set_loops()
		t.tween_property(_logo, "position:y", _logo.position.y - 10.0, 1.2).set_trans(Tween.TRANS_SINE)
		t.tween_property(_logo, "position:y", _logo.position.y, 1.2).set_trans(Tween.TRANS_SINE)


## A dim maze pattern behind the menu.
func _draw_backdrop() -> void:
	var cols := int(ceil(_backdrop.size.x / BACKDROP_CELL)) + 1
	var rows := int(ceil(_backdrop.size.y / BACKDROP_CELL)) + 1
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var dim := Color(1, 1, 1, 0.22)
	for y in rows:
		for x in cols:
			var r := Rect2(Vector2(x, y) * BACKDROP_CELL, Vector2(BACKDROP_CELL, BACKDROP_CELL))
			var roll := rng.randf()
			var edge := x == 0 or y == 0 or x == cols - 1 or y == rows - 1
			if edge or roll < 0.18:
				_backdrop.draw_texture_rect(STONE_TEX, r, false, dim)
			else:
				_backdrop.draw_texture_rect(FLOOR_TEX, r, false, dim)
				if roll > 0.93:
					_backdrop.draw_texture_rect(BUSH_TEX, r, false, dim)
	# Darken the middle so the title stays readable.
	var c := _backdrop.size / 2.0
	_backdrop.draw_rect(Rect2(c - Vector2(420, 330), Vector2(840, 660)), Color(0.078, 0.094, 0.141, 0.82))
