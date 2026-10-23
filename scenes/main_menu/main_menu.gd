extends Control
## Title screen. Also routes command-line developer options (see Game).

const BUSH_TEX := preload("res://art/tiles/bush.svg")
const GARAGE_ICON := preload("res://art/ui/garage.svg")
const BACKDROP_CELL := 96.0
## Room around the buttons inside the calm panel behind them.
const PANEL_PAD := Vector2(48, 36)

@onready var _backdrop: Control = %Backdrop
@onready var _logo: TextureRect = %Logo
@onready var _play: Button = %PlayButton
@onready var _continue: Button = %ContinueButton
@onready var _settings: Button = %SettingsButton
@onready var _quit: Button = %QuitButton
@onready var _settings_dialog: Control = %SettingsDialog


func _ready() -> void:
	# In _ready, not _enter_tree: this is the first scene, and the autoloads
	# load the catalog and the save file in their own _ready().
	_apply_theme()
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
	var look := RobotGear.look(Progress.data)
	if look["skin"] != null:
		_logo.texture = look["skin"]
	RobotGear.dress_rect(_logo, look["armor"], look["weapon"])
	_settings.pressed.connect(_settings_dialog.call.bind("open"))
	_settings_dialog.connect("appearance_changed", _apply_theme)
	_quit.pressed.connect(func() -> void: get_tree().quit())
	if OS.has_feature("web"):
		_quit.hide()
	_build_garage_button()
	_pair_small_buttons()
	_backdrop.draw.connect(_draw_backdrop)
	_backdrop.resized.connect(_backdrop.queue_redraw)
	($Center/VBox as Control).resized.connect(_backdrop.queue_redraw)
	if not Game.reduce_motion():
		var t := create_tween().set_loops()
		t.tween_property(_logo, "position:y", _logo.position.y - 10.0, 1.2).set_trans(Tween.TRANS_SINE)
		t.tween_property(_logo, "position:y", _logo.position.y, 1.2).set_trans(Tween.TRANS_SINE)


## The Garage (shop, equipment, wardrobe): a highlighted button right under Continue.
func _build_garage_button() -> void:
	var garage := Button.new()
	garage.name = "GarageButton"
	garage.text = "Garage"
	garage.icon = GARAGE_ICON
	garage.theme_type_variation = &"AccentButton"
	garage.add_theme_font_size_override("font_size", 20)
	garage.custom_minimum_size = Vector2(_play.custom_minimum_size.x, 54)
	garage.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	garage.focus_mode = Control.FOCUS_NONE
	garage.tooltip_text = "Shop for weapons, see your armor and change skins"
	garage.pressed.connect(func() -> void:
		Sfx.play(&"click")
		Game.goto_garage("menu"))
	_continue.add_sibling(garage)


## Settings and Quit share one row, which keeps the stack short enough to fit.
func _pair_small_buttons() -> void:
	var row := HBoxContainer.new()
	row.name = "SmallButtons"
	row.add_theme_constant_override("separation", 12)
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_settings.add_sibling(row)
	var half := (_play.custom_minimum_size.x - 12.0) / 2.0
	for b: Button in [_settings, _quit]:
		b.reparent(row)
		b.custom_minimum_size = Vector2(half, b.custom_minimum_size.y)
	if not _quit.visible:
		_settings.custom_minimum_size.x = _play.custom_minimum_size.x


## The colors of the chapter last played, in the current light or dark mode.
func _apply_theme() -> void:
	theme = ChapterPalette.theme_for_level(Progress.data.last_level)
	($Center/VBox/Subtitle as Label).add_theme_color_override("font_color",
			get_theme_color(&"accent_strong", &"Palette"))
	_backdrop.queue_redraw()
	_settings_dialog.call("refresh_colors")


## A faint maze pattern behind the menu.
func _draw_backdrop() -> void:
	var bg := get_theme_color(&"bg", &"Palette")
	_backdrop.draw_rect(Rect2(Vector2.ZERO, _backdrop.size), bg)
	var wall := StyleBoxFlat.new()
	wall.bg_color = Color(get_theme_color(&"wall", &"Palette"), 0.7)
	wall.set_corner_radius_all(14)
	var walk := Color(get_theme_color(&"walk", &"Palette"), 0.3)
	var cols := int(ceil(_backdrop.size.x / BACKDROP_CELL)) + 1
	var rows := int(ceil(_backdrop.size.y / BACKDROP_CELL)) + 1
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var canvas := _backdrop.get_canvas_item()
	for y in rows:
		for x in cols:
			var r := Rect2(Vector2(x, y) * BACKDROP_CELL, Vector2(BACKDROP_CELL, BACKDROP_CELL))
			var roll := rng.randf()
			var edge := x == 0 or y == 0 or x == cols - 1 or y == rows - 1
			if edge or roll < 0.18:
				wall.draw(canvas, r.grow(-5))
			else:
				_backdrop.draw_rect(r, walk)
				if roll > 0.93:
					_backdrop.draw_texture_rect(BUSH_TEX, r, false, Color(1, 1, 1, 0.35))
	# A calm panel behind the title and buttons, sized to them so none hangs outside.
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(bg, 0.88)
	panel.set_corner_radius_all(28)
	var box: Control = $Center/VBox
	var r := Rect2(box.global_position - _backdrop.global_position, box.size)
	panel.draw(canvas, r.grow_individual(PANEL_PAD.x, PANEL_PAD.y, PANEL_PAD.x, PANEL_PAD.y))
