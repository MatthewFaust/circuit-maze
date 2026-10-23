extends Control
## Chapters with their levels, locks and stars.

const STAR_ON := preload("res://art/ui/star.svg")
const STAR_OFF := preload("res://art/ui/star_empty.svg")
const LOCK := preload("res://art/ui/lock.svg")

@onready var _back: Button = %BackButton
@onready var _total: Label = %TotalStars
@onready var _chapters: VBoxContainer = %Chapters
@onready var _scroll: ScrollContainer = %Scroll


## The page uses the last chapter played; each chapter card uses its own colors.
func _enter_tree() -> void:
	theme = ChapterPalette.theme_for_level(Progress.data.last_level)


func _ready() -> void:
	($Bg as ColorRect).color = get_theme_color(&"bg", &"Palette")
	_back.pressed.connect(Game.goto_main_menu)
	var catalog := Game.catalog
	var focus: Control = null
	for chapter in catalog.chapters:
		var built := _build_chapter(chapter, catalog)
		_chapters.add_child(built["panel"])
		if focus == null and built["focus"] != null:
			focus = built["focus"]
	_total.text = "%d / %d" % [Progress.data.total_stars(catalog), catalog.max_stars()]
	if focus != null:
		_scroll_to.call_deferred(focus)
	if Game.dev.has("shot"):
		Game.capture_and_quit(str(Game.dev["shot"]))


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Game.goto_main_menu()


func _scroll_to(c: Control) -> void:
	await get_tree().process_frame
	_scroll.ensure_control_visible(c)


## {"panel": Control, "focus": the first unlocked unfinished level button or null}
func _build_chapter(chapter: Dictionary, catalog: LevelCatalog) -> Dictionary:
	var panel := PanelContainer.new()
	panel.theme = ChapterPalette.theme_for_chapter(int(chapter["id"]))
	panel.theme_type_variation = &"ChapterPanel"
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var ids: PackedStringArray = chapter["level_ids"]
	var stars := 0
	for id in ids:
		stars += Progress.data.stars(id)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	vbox.add_child(header)
	var title := Label.new()
	title.theme_type_variation = &"TitleLabel"
	title.text = "Chapter %d · %s" % [int(chapter["id"]), chapter["title"]]
	header.add_child(title)
	var sub := Label.new()
	sub.theme_type_variation = &"Muted"
	sub.text = str(chapter["subtitle"])
	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(sub)
	var count := Label.new()
	count.theme_type_variation = &"Muted"
	count.text = "★ %d / %d" % [stars, ids.size() * 3]
	header.add_child(count)

	var intro := Label.new()
	intro.theme_type_variation = &"Muted"
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.text = str(chapter["intro"])
	vbox.add_child(intro)

	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 12)
	row.add_theme_constant_override("v_separation", 12)
	vbox.add_child(row)
	var focus: Control = null
	var empty_star := ChapterPalette.for_chapter(int(chapter["id"])).color("line_strong")
	for id in ids:
		var level := catalog.get_level(id)
		var unlocked := Progress.data.is_unlocked(id, catalog)
		var button := _level_button(level, unlocked, empty_star)
		row.add_child(button)
		if focus == null and unlocked and not Progress.data.is_completed(id):
			focus = button
	return {"panel": panel, "focus": focus}


## empty_star: tint for unearned stars, in the chapter's colors.
func _level_button(level: LevelData, unlocked: bool, empty_star: Color) -> Button:
	var b := Button.new()
	b.theme_type_variation = &"LevelButton"
	b.custom_minimum_size = Vector2(176, 132)
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = not unlocked
	b.tooltip_text = "%s: %s" % [level.title, level.concept] if unlocked else "Finish the previous level to unlock"
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 4)
	b.add_child(box)
	var number := Label.new()
	number.theme_type_variation = &"TitleLabel"
	number.text = level.id
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(number)
	var name_label := Label.new()
	name_label.text = level.title
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.custom_minimum_size = Vector2(150, 0)
	box.add_child(name_label)
	var stars_row := HBoxContainer.new()
	stars_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stars_row.add_theme_constant_override("separation", 2)
	box.add_child(stars_row)
	if unlocked:
		var flags := Progress.data.star_flags(level.id)
		for k in ["escape", "stamina", "blocks"]:
			var earned := bool(flags[k])
			var star := _icon(STAR_ON if earned else STAR_OFF, 24)
			if not earned:
				# A white outline, tinted to the chapter's border color.
				star.modulate = empty_star
			stars_row.add_child(star)
	else:
		stars_row.add_child(_icon(LOCK, 26))
		b.modulate = Color(1, 1, 1, 0.6)
	b.pressed.connect(func() -> void:
		Sfx.play(&"click")
		Game.goto_level(level.id))
	return b


func _icon(tex: Texture2D, px: int) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.custom_minimum_size = Vector2(px, px)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r
