extends "res://tests/suite_base.gd"
## Chapter color themes: every chapter has a light and a dark palette, every
## color in the base theme is mapped to a palette role, text stays readable in
## every chapter in both modes, the screens wear their chapter's theme, and the
## dark mode switch in Settings recolors the menu.

const LEVEL_SCREEN := "res://scenes/level/level_screen.tscn"
const LEVEL_SELECT := "res://scenes/level_select/level_select.tscn"
const MAIN_MENU := "res://scenes/main_menu/main_menu.tscn"
## Minimum WCAG contrast. 4.5 for body text, 3 for bold labels and thin marks.
const TEXT_MIN := 4.5
const LARGE_MIN := 3.0


func test_every_chapter_has_a_palette() -> void:
	var catalog := LevelCatalog.get_default()
	check(catalog.errors.is_empty(), "catalog errors: %s" % str(catalog.errors))
	for ch: Dictionary in catalog.chapters:
		for field in ["palette", "palette_dark"]:
			var pal: Dictionary = ch[field]
			check(str(pal["name"]) != "", "chapter %d %s has a name" % [int(ch["id"]), field])
			for key: String in LevelCatalog.PALETTE_KEYS:
				check(pal.get(key) is Color, "chapter %d %s has %s" % [int(ch["id"]), field, key])


func test_bad_palettes_are_reported() -> void:
	var errs: Array[String] = []
	LevelCatalog._read_palette({"background": "#zzz", "floor": "#fff"}, errs)
	check(errs.size() >= 4, "bad and missing colors reported: %s" % str(errs))
	errs.clear()
	LevelCatalog._read_palette(null, errs)
	check_eq(errs.size(), 1, "a missing palette is reported")


## A new style or color in main_theme.tres must get a role, or it would stay dark.
func test_every_base_theme_color_has_a_role() -> void:
	var base: Theme = ChapterPalette.BASE_THEME
	for type in base.get_type_list():
		for n in base.get_stylebox_list(type):
			if base.get_stylebox(n, type) is StyleBoxFlat:
				var key := "%s/%s" % [type, n]
				check(ChapterPalette.STYLE_ROLES.has(key), "no palette role for style %s" % key)
		for n in base.get_color_list(type):
			var key := "%s/%s" % [type, n]
			check(ChapterPalette.COLOR_ROLES.has(key), "no palette role for color %s" % key)
	for key: String in ChapterPalette.STYLE_ROLES:
		var parts := key.split("/")
		check(base.has_stylebox(parts[1], parts[0]), "STYLE_ROLES names a style the theme lacks: %s" % key)
	for key: String in ChapterPalette.COLOR_ROLES:
		var parts := key.split("/")
		check(base.has_color(parts[1], parts[0]), "COLOR_ROLES names a color the theme lacks: %s" % key)


## An unknown role resolves to magenta; none may reach a built theme.
func test_built_themes_use_only_known_roles() -> void:
	for ch: Dictionary in LevelCatalog.get_default().chapters:
		for dark in [false, true]:
			_check_resolved(ChapterPalette.for_chapter(int(ch["id"]), dark).build_theme(),
					"chapter %d %s" % [int(ch["id"]), "dark" if dark else "light"])


func _check_resolved(t: Theme, tag: String) -> void:
	for type in t.get_type_list():
		for n in t.get_color_list(type):
			check(not _is_magenta(t.get_color(n, type)), "%s: %s/%s is unresolved" % [tag, type, n])
		for n in t.get_stylebox_list(type):
			var sb := t.get_stylebox(n, type) as StyleBoxFlat
			if sb != null:
				check(not _is_magenta(sb.bg_color) and not _is_magenta(sb.border_color)
						and not _is_magenta(sb.shadow_color),
						"%s: style %s/%s is unresolved" % [tag, type, n])


func test_text_is_readable_in_every_chapter() -> void:
	for ch: Dictionary in LevelCatalog.get_default().chapters:
		for dark in [false, true]:
			_check_readable(ChapterPalette.for_chapter(int(ch["id"]), dark), int(ch["id"]))


func _check_readable(p: ChapterPalette, chapter_no: int) -> void:
	var tag := "chapter %d (%s)" % [chapter_no, p.name]
	for bg in ["bg", "surface", "raised", "well", "hover"]:
		_check_contrast(p, "text", bg, TEXT_MIN, tag)
	for bg in ["bg", "surface", "raised"]:
		_check_contrast(p, "muted", bg, TEXT_MIN, tag)
	for tone in ["good", "warn", "bad"]:
		_check_contrast(p, tone, "surface", TEXT_MIN, tag)
	for kind: String in ChapterPalette.KIND_HUES:
		_check_contrast(p, "ink", kind, TEXT_MIN, tag)
	_check_contrast(p, "on_accent", "accent", LARGE_MIN, tag)
	for bg in ["accent_soft", "accent_wash"]:
		_check_contrast(p, "text", bg, TEXT_MIN, tag)
	_check_contrast(p, "accent_strong", "surface", LARGE_MIN, tag)
	_check_contrast(p, "tooltip_text", "tooltip", TEXT_MIN, tag)
	for role in ["code_number", "code_function", "code_keyword", "code_sensor"]:
		_check_contrast(p, role, "surface", TEXT_MIN, tag)


func test_screens_use_their_chapter_theme() -> void:
	var progress: Node = tree.root.get_node("Progress")
	var saved: ProgressData = progress.get("data")
	progress.set("data", ProgressData.new())
	for id in ["1-1", "3-2"]:
		var screen: Control = load(LEVEL_SCREEN).instantiate()
		screen.set("level_id", id)
		tree.root.add_child(screen)
		await tree.process_frame
		var level: LevelData = screen.get("level")
		var want := ChapterPalette.theme_for_chapter(level.chapter)
		check(screen.theme == want, "%s uses chapter %d's theme" % [id, level.chapter])
		var surface := ChapterPalette.for_chapter(level.chapter).color("surface")
		var opt: OptionButton = null
		for o in screen.find_children("*", "OptionButton", true, false):
			opt = o
		if opt == null:
			# 1-1 has no sensors: add a block that has a dropdown.
			var editor: ProgramEditor = screen.find_child("ProgramEditor", true, false)
			editor.append_new("while")
			await tree.process_frame
			await tree.process_frame
			opt = screen.find_children("*", "OptionButton", true, false)[0]
		var box := opt.get_theme_stylebox("normal") as StyleBoxFlat
		check(box != null and box.bg_color == surface, "%s: the sensor dropdown is drawn in the chapter's colors" % id)
		var popup_panel := opt.get_popup().get_theme_stylebox("panel") as StyleBoxFlat
		check(popup_panel != null and popup_panel.bg_color == surface,
				"%s: the dropdown list is drawn in the chapter's colors" % id)
		var bg: ColorRect = screen.get_node("Bg")
		check_eq(bg.color, ChapterPalette.for_chapter(level.chapter).color("bg"), "%s background" % id)
		screen.queue_free()
		await tree.process_frame
	var select: Control = load(LEVEL_SELECT).instantiate()
	tree.root.add_child(select)
	await tree.process_frame
	var panels := select.find_children("*", "PanelContainer", true, false).filter(
			func(c: Control) -> bool: return c.theme_type_variation == &"ChapterPanel")
	check_eq(panels.size(), LevelCatalog.get_default().chapters.size(), "one card per chapter")
	for i in panels.size():
		check((panels[i] as Control).theme == ChapterPalette.theme_for_chapter(i + 1),
				"chapter %d card uses its own theme" % (i + 1))
	select.queue_free()
	await tree.process_frame
	progress.set("data", saved)


## The Settings switch saves the mode and recolors the menu behind it at once.
func test_dark_mode_switch_recolors_the_menu() -> void:
	var progress: Node = tree.root.get_node("Progress")
	var saved: ProgressData = progress.get("data")
	var saved_path: String = progress.get("path")
	progress.set("data", ProgressData.new())
	progress.set("path", "user://test_progress.cfg")
	progress.call("apply_settings")
	check(not ChapterPalette.dark_mode, "light mode by default")
	var menu: Control = load(MAIN_MENU).instantiate()
	tree.root.add_child(menu)
	await tree.process_frame
	check(menu.theme == ChapterPalette.theme_for_chapter(1), "the menu starts in light colors")
	var light_theme := menu.theme
	var dialog: Control = menu.find_child("SettingsDialog", true, false)
	dialog.call("open")
	var switch: CheckButton = null
	for b: CheckButton in dialog.find_children("*", "CheckButton", true, false):
		if b.text == "Dark mode":
			switch = b
	if check(switch != null, "Settings has a Dark mode switch"):
		check(not switch.button_pressed, "the switch shows light mode")
		switch.button_pressed = true
		check(ChapterPalette.dark_mode, "the switch turns dark mode on")
		check(bool(progress.call("get_setting", "dark_mode", false)), "and saves it as a setting")
		check(menu.theme != light_theme and menu.theme == ChapterPalette.theme_for_chapter(1),
				"the menu recolors at once")
		check_eq(menu.get_theme_color(&"bg", &"Palette"), ChapterPalette.for_chapter(1, true).color("bg"),
				"the menu uses chapter 1's dark background")
		switch.button_pressed = false
		check(not ChapterPalette.dark_mode and menu.theme == light_theme, "and back to light")
	menu.queue_free()
	await tree.process_frame
	progress.set("data", saved)
	progress.set("path", saved_path)
	progress.call("apply_settings")
	if FileAccess.file_exists("user://test_progress.cfg"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_progress.cfg"))


func _check_contrast(p: ChapterPalette, fg: String, bg: String, minimum: float, tag: String) -> void:
	var back := p.color(bg)
	# Translucent colors are seen over the panel.
	var front := p.color("surface").blend(p.color(fg))
	var ratio := ChapterPalette.contrast(front, back)
	check(ratio >= minimum, "%s: %s on %s contrast %.2f < %.1f" % [tag, fg, bg, ratio, minimum])


func _is_magenta(c: Color) -> bool:
	return c.is_equal_approx(Color.MAGENTA) or (c.r == 1.0 and c.g == 0.0 and c.b == 1.0)
