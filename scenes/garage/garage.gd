extends Control
## The Garage: the robot with its stats, and three tabs. Shop: weapons, which
## unlock as the star total grows (stars are never spent) and which the player
## equips. Equipment: armor, granted with stages. Wardrobe: skins won from
## bosses. Gear only matters in boss fights. Everything is built in code.

const BACK_ICON := preload("res://art/ui/back.svg")
const STAR_ICON := preload("res://art/ui/star.svg")
const LOCK_ICON := preload("res://art/ui/lock.svg")
const TABS := ["Shop", "Equipment", "Wardrobe"]

## The screen to go back to: "menu" or "select".
var return_to := "menu"

var _prog: ProgressionCatalog
var _catalog: LevelCatalog
var _tab := 0
var _tab_buttons: Array[Button] = []
var _content: VBoxContainer
var _preview: TextureRect
var _preview_name: Label
var _stats: Label
var _gear_line: Label


func _enter_tree() -> void:
	theme = ChapterPalette.theme_for_level(Progress.data.last_level)


func _ready() -> void:
	_prog = ProgressionCatalog.get_default()
	_catalog = Game.catalog
	($Bg as ColorRect).color = get_theme_color(&"bg", &"Palette")
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	margin.add_child(col)
	col.add_child(_header())
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 20)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	body.add_child(_robot_card())
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 12)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	right.add_child(_tab_row())
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(scroll)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 10)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content)
	var start := TABS.find(str(Game.dev.get("tab", "")).capitalize())
	show_tab(maxi(start, 0))
	if Game.dev.has("shot"):
		Game.capture_and_quit(str(Game.dev["shot"]))


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_back()


func _go_back() -> void:
	Progress.save()
	if return_to == "select":
		Game.goto_level_select()
	else:
		Game.goto_main_menu()


func show_tab(i: int) -> void:
	_tab = i
	for j in _tab_buttons.size():
		_tab_buttons[j].set_pressed_no_signal(j == i)
	_refresh()


## Rebuilds the robot card and the open tab (after every equip).
func _refresh() -> void:
	var data := Progress.data
	var skin := _prog.skin_by_id(data.skin)
	if not skin.is_empty() and ResourceLoader.exists(str(skin["texture"])):
		_preview.texture = load(str(skin["texture"]))
	_preview_name.text = str(skin.get("name", "Starter Bot"))
	var lo := data.loadout(_prog)
	_stats.text = "ATK %d  ·  DEF %d" % [MazeRules.new().base_attack + int(lo["damage"]), int(lo["defense"])]
	var armor := _prog.armor_by_id(data.equipped_armor)
	var weapon := _prog.weapon_by_id(data.equipped_weapon)
	_gear_line.text = "Armor: %s\nWeapon: %s\n\nGear only counts in boss fights." % [
			armor.get("name", "none yet"), weapon.get("name", "none")]
	for c in _content.get_children():
		_content.remove_child(c)
		c.queue_free()
	match _tab:
		0:
			_build_shop()
		1:
			_build_equipment()
		2:
			_build_wardrobe()


func _header() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var back := Button.new()
	back.theme_type_variation = &"ToolButton"
	back.focus_mode = Control.FOCUS_NONE
	back.icon = BACK_ICON
	back.text = "Levels" if return_to == "select" else "Menu"
	back.pressed.connect(_go_back)
	row.add_child(back)
	var title := Label.new()
	title.theme_type_variation = &"TitleLabel"
	title.add_theme_font_size_override("font_size", 30)
	title.text = "Garage"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	row.add_child(_icon(STAR_ICON, 30))
	var total := Label.new()
	total.name = "TotalStars"
	total.theme_type_variation = &"TitleLabel"
	total.text = "%d / %d" % [Progress.data.total_stars(_catalog), _catalog.max_stars()]
	total.tooltip_text = "Stars are never spent: weapons unlock as your total grows."
	total.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(total)
	return row


func _robot_card() -> Control:
	var card := PanelContainer.new()
	card.theme_type_variation = &"ChapterPanel"
	card.custom_minimum_size = Vector2(300, 0)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	card.add_child(col)
	_preview = _icon(null, 200)
	col.add_child(_preview)
	_preview_name = Label.new()
	_preview_name.theme_type_variation = &"TitleLabel"
	_preview_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_preview_name)
	_stats = Label.new()
	_stats.theme_type_variation = &"TitleLabel"
	_stats.add_theme_font_size_override("font_size", 20)
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_stats)
	_gear_line = Label.new()
	_gear_line.theme_type_variation = &"Muted"
	_gear_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gear_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_gear_line)
	return card


func _tab_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for i in TABS.size():
		var b := Button.new()
		b.name = "Tab" + TABS[i]
		b.text = TABS[i]
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(150, 44)
		b.pressed.connect(show_tab.bind(i))
		row.add_child(b)
		_tab_buttons.append(b)
	return row


func _build_shop() -> void:
	_note("Weapons add to your damage in boss fights. Each one unlocks when your star total reaches its goal, and stars are never spent.")
	var total := Progress.data.total_stars(_catalog)
	for w in _prog.weapons:
		var need := _prog.stars_needed(w, _catalog)
		var owned := Progress.data.owned_weapons.has(w["id"])
		var equipped := Progress.data.equipped_weapon == str(w["id"])
		var row := _row(str(w["name"]), "+%d damage" % int(w["damage"]))
		var bar := ProgressBar.new()
		bar.max_value = maxi(need, 1)
		bar.value = mini(total, need)
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(200, 26)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var count := Label.new()
		count.text = "%d / %d ★" % [mini(total, need), need]
		count.add_theme_font_size_override("font_size", 15)
		count.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bar.add_child(count)
		row.add_child(bar)
		if equipped:
			row.add_child(_action("Take off", func() -> void: _equip("weapon", "")))
		elif owned:
			row.add_child(_action("Equip", func() -> void: _equip("weapon", str(w["id"])), true))
		else:
			row.add_child(_action("Locked", Callable(), false, true))


func _build_equipment() -> void:
	_note("Armor lowers the damage boss strikes do. Each piece comes free when you reach its stage, and the strongest is equipped for you.")
	for a in _prog.armor:
		var owned := Progress.data.owned_armor.has(a["id"])
		var equipped := Progress.data.equipped_armor == str(a["id"])
		var row := _row(str(a["name"]), "+%d defense  ·  unlocks at stage %s" % [int(a["defense"]), a["unlock_level"]])
		if equipped:
			row.add_child(_action("Equipped", Callable(), false, true))
		elif owned:
			row.add_child(_action("Equip", func() -> void: _equip("armor", str(a["id"])), true))
		else:
			row.add_child(_action("Reach %s" % a["unlock_level"], Callable(), false, true))


func _build_wardrobe() -> void:
	_note("Skins change how your robot looks, nothing else. Beat a chapter's boss to win its skin.")
	var grid := HFlowContainer.new()
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	_content.add_child(grid)
	for s in _prog.skins:
		var id := str(s["id"])
		var owned := Progress.data.owned_skins.has(id)
		var wearing := Progress.data.skin == id
		var card := Button.new()
		card.name = "Skin_" + id
		card.theme_type_variation = &"LevelButton"
		card.focus_mode = Control.FOCUS_NONE
		card.custom_minimum_size = Vector2(190, 220)
		card.toggle_mode = true
		card.set_pressed_no_signal(wearing)
		card.disabled = not owned
		var box := VBoxContainer.new()
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		card.add_child(box)
		var pic := _icon(load(str(s["texture"])) if ResourceLoader.exists(str(s["texture"])) else null, 110)
		if not owned:
			pic.modulate = Color(0, 0, 0, 0.35)
		box.add_child(pic)
		var name_label := Label.new()
		name_label.theme_type_variation = &"TitleLabel"
		name_label.add_theme_font_size_override("font_size", 18)
		name_label.text = str(s["name"])
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(name_label)
		var status := Label.new()
		status.theme_type_variation = &"Muted"
		status.add_theme_font_size_override("font_size", 14)
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		status.custom_minimum_size = Vector2(170, 0)
		if wearing:
			status.text = "Wearing"
		elif owned:
			status.text = "Click to wear"
		else:
			var boss := _catalog.get_level(str(s["boss_level"]))
			status.text = "Beat %s" % (boss.boss["name"] if boss != null and boss.is_boss() else "its boss")
		box.add_child(status)
		if owned:
			card.pressed.connect(func() -> void: _equip("skin", id))
		grid.add_child(card)


func _equip(kind: String, id: String) -> void:
	if Progress.data.equip(kind, id):
		Sfx.play(&"click")
		Progress.save()
	_refresh()


## A row: name and detail on the left; the caller adds controls on the right.
func _row(title: String, detail: String) -> HBoxContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"ChapterPanel"
	_content.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var t := Label.new()
	t.theme_type_variation = &"TitleLabel"
	t.add_theme_font_size_override("font_size", 20)
	t.text = title
	text.add_child(t)
	var d := Label.new()
	d.theme_type_variation = &"Muted"
	d.text = detail
	text.add_child(d)
	return row


func _action(text: String, on_press: Callable, primary: bool = false, disabled: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(150, 44)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.disabled = disabled
	if primary:
		b.theme_type_variation = &"PrimaryButton"
	if on_press.is_valid():
		b.pressed.connect(on_press)
	return b


func _note(text: String) -> void:
	var l := Label.new()
	l.theme_type_variation = &"Muted"
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.text = text
	_content.add_child(l)


func _icon(tex: Texture2D, px: int) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.custom_minimum_size = Vector2(px, px)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r
