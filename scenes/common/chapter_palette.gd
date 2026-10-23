class_name ChapterPalette
extends RefCounted
## A chapter's colors and the theme built from them.
##
## Each chapter in data/levels/catalog.json names five colors: background,
## floor, path, accent and text. They're expanded here into roles (panel
## surface, inset well, hover, borders, muted text, pastel block colors...).
## build_theme() copies ui/theme/main_theme.tres, which still supplies fonts,
## sizes, margins and corner radii, and replaces every color in it with a role
## from STYLE_ROLES / COLOR_ROLES. test_palette.gd fails if a theme item has
## no role, so a new style can't stay dark by accident.
##
## Hand-drawn colors (the maze, highlights, the code view) read the same roles
## from the theme type "Palette": get_theme_color(&"accent", &"Palette").

const BASE_THEME := preload("res://ui/theme/main_theme.tres")
const PALETTE_TYPE := &"Palette"

## Block colors stay distinct by kind; each chapter softens them to pastels.
const KIND_HUES := {
	"motion": Color("#4c97ff"), "control": Color("#ffab19"), "sensing": Color("#2bb8b0"),
	"function": Color("#9966ff"), "algorithm": Color("#59c059"), "combat": Color("#e5484d"),
}
const HP_COLOR := Color("#ef476f")
const STAMINA_COLOR := Color("#ffb703")
## Status text, dark enough to read on every chapter's light panels.
const GOOD := Color("#1d7a4f")
const WARN := Color("#a15c00")
const BAD := Color("#c0354a")

## "Type/stylebox": [bg, border, shadow]. A role name, "role@alpha", or "" to
## leave that color alone.
const STYLE_ROLES := {
	"BlockAlgorithm/panel": ["algorithm", "algorithm_edge"],
	"BlockControl/panel": ["control", "control_edge"],
	"BlockFunction/panel": ["function", "function_edge"],
	"BlockMotion/panel": ["motion", "motion_edge"],
	"BlockSensing/panel": ["sensing", "sensing_edge"],
	"BodyWell/panel": ["surface@0.75", "ink@0.12"],
	"Button/disabled": ["well", "line_soft"],
	"Button/hover": ["hover", "accent"],
	"Button/normal": ["raised", "line"],
	"Button/pressed": ["accent_soft", "accent"],
	"CSNotePanel/panel": ["accent_wash", "accent"],
	"ChapterPanel/panel": ["surface", "line"],
	"Chip/panel": ["raised", ""],
	"ChipCall/panel": ["function", ""],
	"ChipSensor/panel": ["sensing", ""],
	"ChipTrail/panel": ["algorithm", ""],
	"CodeEdit/normal": ["surface", "line"],
	"CodeEdit/read_only": ["surface", "line"],
	"DialogPanel/panel": ["surface", "line", "shadow"],
	"DropLine/panel": ["accent_strong", "", "accent@0.5"],
	"HPBar/fill": ["hp", ""],
	"HSlider/grabber_area": ["accent", ""],
	"HSlider/grabber_area_highlight": ["accent_hover", ""],
	"HSlider/slider": ["well", "line"],
	"LevelButton/disabled": ["well", "line_soft"],
	"LevelButton/hover": ["hover", "accent"],
	"LevelButton/normal": ["raised", "line"],
	"LevelButton/pressed": ["accent_soft", "accent"],
	"LineEdit/focus": ["surface", "accent"],
	"LineEdit/normal": ["surface", "line"],
	"LineEdit/read_only": ["well", "line_soft"],
	"LogBar/panel": ["surface", "line"],
	"MazeFrame/panel": ["well", "line"],
	"NotToggle/disabled": ["ink@0.05", ""],
	"NotToggle/hover": ["ink@0.12", "ink@0.45"],
	"NotToggle/hover_pressed": ["accent_hover", "accent_edge"],
	"NotToggle/normal": ["ink@0.07", "ink@0.25"],
	"NotToggle/pressed": ["accent", "accent_edge"],
	"PalettePanel/panel": ["surface", "line"],
	"Panel/panel": ["surface", "line"],
	"PanelContainer/panel": ["surface", "line"],
	"PopupMenu/hover": ["hover", ""],
	"PopupMenu/panel": ["surface", "line"],
	"PrimaryButton/hover": ["accent_hover", "accent_edge"],
	"PrimaryButton/normal": ["accent", "accent_edge"],
	"PrimaryButton/pressed": ["accent_pressed", "accent_edge"],
	"ProgramPanel/panel": ["surface", "line"],
	"ProgressBar/background": ["well", "line"],
	"ProgressBar/fill": ["accent", ""],
	"SectionActive/panel": ["raised", "accent_strong"],
	"SectionFunc/panel": ["function", "function_edge"],
	"SectionMain/panel": ["raised", "line"],
	"SidePanel/panel": ["surface", "line"],
	"StaminaBar/fill": ["stamina", ""],
	"TabBar/tab_disabled": ["well", ""],
	"TabBar/tab_hovered": ["hover", ""],
	"TabBar/tab_selected": ["surface", "accent_strong"],
	"TabBar/tab_unselected": ["well", ""],
	"ToolButton/disabled": ["", ""],
	"ToolButton/hover": ["hover", ""],
	"ToolButton/normal": ["", ""],
	"ToolButton/pressed": ["accent_soft", ""],
	"TooltipPanel/panel": ["tooltip", "tooltip"],
	"TopBar/panel": ["surface", "line"],
	"VScrollBar/grabber": ["line", ""],
	"VScrollBar/grabber_highlight": ["line_strong", ""],
	"VScrollBar/grabber_pressed": ["accent", ""],
	"VScrollBar/scroll": ["well", ""],
}

## "Type/color": role.
const COLOR_ROLES := {
	"BlockLabel/font_color": "ink",
	"BlockLabel/font_shadow_color": "surface@0.35",
	"Button/font_color": "text",
	"Button/font_disabled_color": "faint",
	"Button/font_focus_color": "text",
	"Button/font_hover_color": "text",
	"Button/font_pressed_color": "text",
	"Button/icon_disabled_color": "faint",
	"Button/icon_normal_color": "text",
	"CheckBox/font_color": "text",
	"CheckButton/font_color": "text",
	"CodeEdit/current_line_color": "",
	"CodeEdit/font_color": "text",
	"CodeEdit/font_readonly_color": "text",
	"CodeEdit/line_number_color": "faint",
	"HeroTitle/font_color": "text",
	"HeroTitle/font_shadow_color": "text@0.12",
	"Label/font_color": "text",
	"LineEdit/font_color": "text",
	"Muted/font_color": "muted",
	"NotToggle/font_color": "ink@0.5",
	"NotToggle/font_disabled_color": "ink@0.3",
	"NotToggle/font_hover_color": "ink@0.85",
	"NotToggle/font_hover_pressed_color": "on_accent",
	"NotToggle/font_pressed_color": "on_accent",
	"PopupMenu/font_color": "text",
	"PopupMenu/font_hover_color": "text",
	"PrimaryButton/font_color": "on_accent",
	"PrimaryButton/font_hover_color": "on_accent",
	"PrimaryButton/font_pressed_color": "on_accent",
	"PrimaryButton/icon_hover_color": "on_accent",
	"PrimaryButton/icon_normal_color": "on_accent",
	"PrimaryButton/icon_pressed_color": "on_accent",
	"ProgressBar/font_color": "text",
	"RichTextLabel/default_color": "text",
	"SectionTitle/font_color": "muted",
	"TabBar/font_hovered_color": "text",
	"TabBar/font_selected_color": "text",
	"TabBar/font_unselected_color": "muted",
	"TooltipLabel/font_color": "tooltip_text",
}

## Colors the base theme leaves to the engine defaults, which are made for dark
## backgrounds (white icons, white hover text, a white caret).
const EXTRA_COLORS := {
	"Button/font_hover_pressed_color": "text",
	"Button/icon_focus_color": "text",
	"Button/icon_hover_color": "text",
	"Button/icon_hover_pressed_color": "text",
	"Button/icon_pressed_color": "text",
	"PrimaryButton/font_focus_color": "on_accent",
	"PrimaryButton/font_hover_pressed_color": "on_accent",
	"PrimaryButton/icon_focus_color": "on_accent",
	"PrimaryButton/icon_hover_pressed_color": "on_accent",
	"OptionButton/font_color": "text",
	"OptionButton/font_disabled_color": "faint",
	"OptionButton/font_focus_color": "text",
	"OptionButton/font_hover_color": "text",
	"OptionButton/font_hover_pressed_color": "text",
	"OptionButton/font_pressed_color": "text",
	"OptionButton/icon_normal_color": "text",
	"OptionButton/icon_hover_color": "text",
	"OptionButton/icon_pressed_color": "text",
	"OptionButton/icon_focus_color": "text",
	"CheckBox/font_focus_color": "text",
	"CheckBox/font_hover_color": "text",
	"CheckBox/font_hover_pressed_color": "text",
	"CheckBox/font_pressed_color": "text",
	"CheckButton/font_focus_color": "text",
	"CheckButton/font_hover_color": "text",
	"CheckButton/font_hover_pressed_color": "text",
	"CheckButton/font_pressed_color": "text",
	"CodeEdit/caret_color": "text",
	"CodeEdit/font_selected_color": "text",
	"CodeEdit/selection_color": "accent@0.3",
	"LineEdit/caret_color": "text",
	"LineEdit/clear_button_color": "muted",
	"LineEdit/font_placeholder_color": "faint",
	"LineEdit/font_selected_color": "text",
	"LineEdit/font_uneditable_color": "faint",
	"LineEdit/selection_color": "accent@0.35",
	"PopupMenu/font_accelerator_color": "muted",
	"PopupMenu/font_disabled_color": "faint",
	"PopupMenu/font_separator_color": "muted",
	"SpinBox/down_disabled_icon_modulate": "faint",
	"SpinBox/down_hover_icon_modulate": "text",
	"SpinBox/down_icon_modulate": "muted",
	"SpinBox/down_pressed_icon_modulate": "accent_strong",
	"SpinBox/up_disabled_icon_modulate": "faint",
	"SpinBox/up_hover_icon_modulate": "text",
	"SpinBox/up_icon_modulate": "muted",
	"SpinBox/up_pressed_icon_modulate": "accent_strong",
	"TabBar/font_disabled_color": "faint",
}

## Styles the base theme leaves to the engine (a dark grey box): "Type/style" -> base style it copies.
const EXTRA_STYLES := {
	"OptionButton/normal": "LineEdit/normal",
	"OptionButton/hover": "LineEdit/focus",
	"OptionButton/pressed": "LineEdit/focus",
	"OptionButton/disabled": "LineEdit/read_only",
	"OptionButton/focus": "Button/focus",
	"Button/hover_pressed": "Button/pressed",
	"PrimaryButton/hover_pressed": "PrimaryButton/hover",
	"PrimaryButton/disabled": "Button/disabled",
}

## Dark mode (a setting). Screens read it when they build their theme.
static var dark_mode := false
## Type variations the base theme doesn't have: "Type" -> {"base": base type,
## "styles": {style name: ["Type/style" it copies, [bg role, border role],
## border width (0 keeps the copied one)]}}.
const EXTRA_VARIATIONS := {
	"BlockCombat": {"base": &"PanelContainer", "styles": {
		"panel": ["BlockMotion/panel", ["combat", "combat_edge"], 0],
	}},
	# A button that stands out without competing with the primary action (the Garage).
	"AccentButton": {"base": &"Button", "styles": {
		"normal": ["Button/normal", ["accent_soft", "accent_strong"], 2],
		"hover": ["Button/hover", ["accent_wash", "accent_strong"], 2],
		"pressed": ["Button/pressed", ["accent_soft", "accent_edge"], 2],
		"disabled": ["Button/disabled", ["well", "line_soft"], 0],
	}},
}

static var _cache := {}

var name := ""
var dark := false
## Role name -> Color.
var roles := {}


## The palette for a chapter (1-based), in the current mode unless dark is given.
## Unknown chapters get chapter 1's.
static func for_chapter(chapter_no: int, dark: Variant = null) -> ChapterPalette:
	var is_dark: bool = dark_mode if dark == null else bool(dark)
	var key := "palette_dark" if is_dark else "palette"
	var catalog := LevelCatalog.get_default()
	var info := catalog.chapter_info(chapter_no)
	if info.is_empty() or (info[key] as Dictionary).size() < 1 + LevelCatalog.PALETTE_KEYS.size():
		info = catalog.chapter_info(1)
	var colors: Dictionary = info.get(key, {})
	return ChapterPalette.new(colors, is_dark)


## The palette of the chapter a level belongs to (chapter 1 for "").
static func for_level(level_id: String) -> ChapterPalette:
	var level := LevelCatalog.get_default().get_level(level_id)
	return for_chapter(level.chapter if level != null else 1)


## The theme of the chapter a level belongs to (chapter 1 for "").
static func theme_for_level(level_id: String) -> Theme:
	var level := LevelCatalog.get_default().get_level(level_id)
	return theme_for_chapter(level.chapter if level != null else 1)


## The theme for a chapter in the current mode, built once and shared.
static func theme_for_chapter(chapter_no: int) -> Theme:
	var key := "%d:%s" % [chapter_no, "dark" if dark_mode else "light"]
	if not _cache.has(key):
		_cache[key] = for_chapter(chapter_no).build_theme()
	return _cache[key]


## WCAG contrast ratio between two opaque colors (1 to 21).
static func contrast(a: Color, b: Color) -> float:
	var la := _relative_luminance(a)
	var lb := _relative_luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _relative_luminance(c: Color) -> float:
	var l := c.srgb_to_linear()
	return 0.2126 * l.r + 0.7152 * l.g + 0.0722 * l.b


## colors: {"name", "background", "floor", "path", "accent", "text"}, as LevelCatalog
## reads them. p_dark: the colors are a dark palette (light text on a dark page).
func _init(colors: Dictionary = {}, p_dark: bool = false) -> void:
	name = str(colors.get("name", ""))
	dark = p_dark
	var bg: Color = colors.get("background", Color("#F2FAF5"))
	var fl: Color = colors.get("floor", Color("#D6F0E0"))
	var pa: Color = colors.get("path", Color("#A8DCC0"))
	var ac: Color = colors.get("accent", Color("#4FB286"))
	var tx: Color = colors.get("text", Color("#1E4D3A"))
	var r := roles
	r["bg"] = bg
	r["floor"] = fl
	r["path"] = pa
	r["accent"] = ac
	r["text"] = tx
	r["line_soft"] = fl.lerp(pa, 0.4)
	r["line"] = pa
	r["hp"] = HP_COLOR
	r["stamina"] = STAMINA_COLOR
	r["info"] = tx
	# The maze: walls in the floor color, walkable cells in the path color.
	r["wall"] = fl
	r["walk"] = pa
	r["walk_line"] = pa.darkened(0.07)
	r["visited"] = Color(ac, 0.45)
	r["run_glow"] = Color(ac, 0.55)
	r["run_ancestor"] = Color(ac, 0.8)
	r["run_line"] = Color(ac, 0.25)
	if dark:
		_derive_dark(bg, fl, pa, ac, tx)
	else:
		_derive_light(bg, fl, pa, ac, tx)
	var strong: Color = r["accent_strong"]
	r["trail"] = Color(strong, 0.85)
	r["run_active"] = strong
	r["error"] = r["bad"]
	r["error_glow"] = Color(r["bad"], 0.45)
	r["accent_soft"] = ac.lerp(r["surface"], 0.7)
	r["accent_wash"] = ac.lerp(r["surface"], 0.88)
	r["code_symbol"] = r["muted"]
	r["code_comment"] = r["faint"]
	r["code_number"] = r["warn"]
	r["dim"] = Color(r["outline"], 0.42 if not dark else 0.6)


## Light mode: white-ish panels on the page, pastel blocks with dark labels.
func _derive_light(bg: Color, fl: Color, pa: Color, ac: Color, tx: Color) -> void:
	var r := roles
	r["surface"] = bg.lerp(Color.WHITE, 0.7)
	r["well"] = bg.lerp(fl, 0.5)
	r["raised"] = fl
	r["hover"] = fl.lerp(pa, 0.55)
	r["line_strong"] = pa.lerp(tx, 0.25)
	r["accent_hover"] = ac.lerp(Color.WHITE, 0.2)
	r["accent_pressed"] = ac.darkened(0.12)
	r["accent_edge"] = ac.darkened(0.3)
	# An accent dark enough for thin lines and small marks on light panels.
	r["accent_strong"] = _until_contrast(ac, r["surface"], 3.0, false)
	r["on_accent"] = _best_on(ac, [tx.darkened(0.5), Color.WHITE])
	r["muted"] = tx.lerp(bg, 0.18)
	r["faint"] = tx.lerp(bg, 0.55)
	r["ink"] = tx.darkened(0.3)
	r["shadow"] = Color(tx, 0.22)
	r["tooltip"] = tx.darkened(0.15)
	r["tooltip_text"] = r["surface"]
	r["label_fill"] = r["surface"]
	r["halo"] = r["surface"]
	r["knob"] = r["surface"]
	for kind: String in KIND_HUES:
		var hue: Color = KIND_HUES[kind]
		var soft := hue.lerp(ac, 0.12).lerp(Color.WHITE, 0.42)
		r[kind] = soft
		r[kind + "_edge"] = soft.darkened(0.16)
	r["good"] = GOOD
	r["warn"] = WARN
	r["bad"] = BAD
	r["wall_top"] = fl.lerp(Color.WHITE, 0.45)
	r["wall_edge"] = fl.darkened(0.14)
	r["fog"] = fl.lerp(tx, 0.5)
	r["fog_dot"] = fl.lerp(tx, 0.3)
	r["outline"] = tx.darkened(0.45)
	r["code_function"] = Color("#1f5fbf")
	r["code_keyword"] = Color("#a62a6b")
	r["code_sensor"] = Color("#0e7068")


## Dark mode: panels a step lighter than the page, deep block colors with light
## labels, and light status and syntax colors.
func _derive_dark(bg: Color, fl: Color, pa: Color, ac: Color, tx: Color) -> void:
	var r := roles
	r["surface"] = bg.lerp(fl, 0.55)
	r["well"] = bg.lerp(fl, 0.2)
	r["raised"] = fl.lerp(pa, 0.45)
	r["hover"] = pa
	r["line_strong"] = pa.lerp(tx, 0.3)
	r["accent_hover"] = ac.lerp(Color.WHITE, 0.15)
	r["accent_pressed"] = ac.darkened(0.15)
	r["accent_edge"] = ac.darkened(0.4)
	# Bright enough for thin lines and small marks on dark panels.
	r["accent_strong"] = _until_contrast(ac, r["surface"], 3.0, true)
	r["on_accent"] = _best_on(ac, [bg.darkened(0.5), Color.WHITE])
	r["muted"] = tx.lerp(bg, 0.3)
	r["faint"] = tx.lerp(bg, 0.55)
	r["ink"] = tx.lerp(Color.WHITE, 0.5)
	r["shadow"] = Color(0, 0, 0, 0.45)
	r["tooltip"] = bg.darkened(0.45)
	r["tooltip_text"] = tx
	r["label_fill"] = tx
	r["halo"] = bg.darkened(0.45)
	r["knob"] = tx
	for kind: String in KIND_HUES:
		var hue: Color = KIND_HUES[kind]
		# Deep enough that the light block labels stay readable.
		var deep := _until_contrast(hue.lerp(ac, 0.12).lerp(bg, 0.2), r["ink"], 4.8, false)
		r[kind] = deep
		r[kind + "_edge"] = deep.darkened(0.3)
	r["good"] = Color("#6fe0aa")
	r["warn"] = Color("#f5c463")
	r["bad"] = Color("#ff8597")
	r["wall_top"] = fl.lerp(pa, 0.7)
	r["wall_edge"] = fl.darkened(0.4)
	r["fog"] = bg.darkened(0.55)
	r["fog_dot"] = fl
	r["outline"] = bg.darkened(0.6)
	r["code_function"] = Color("#8fbfff")
	r["code_keyword"] = Color("#ff8cc0")
	r["code_sensor"] = Color("#6ee8da")


## Darkens (or lightens) c until it has at least ratio contrast with other.
static func _until_contrast(c: Color, other: Color, ratio: float, lighten: bool) -> Color:
	for i in 16:
		if contrast(c, other) >= ratio:
			break
		c = c.lightened(0.08) if lighten else c.darkened(0.08)
	return c


## Whichever candidate reads best on bg.
static func _best_on(bg: Color, candidates: Array) -> Color:
	var best: Color = candidates[0]
	for c: Color in candidates:
		if contrast(c, bg) > contrast(best, bg):
			best = c
	return best


func color(role: String) -> Color:
	return _resolve(role, Color.MAGENTA)


func build_theme() -> Theme:
	var t := Theme.new()
	var base := BASE_THEME
	t.default_font = base.default_font
	t.default_font_size = base.default_font_size
	t.default_base_scale = base.default_base_scale
	for type in base.get_type_list():
		var variation_base := base.get_type_variation_base(type)
		if variation_base != &"":
			t.set_type_variation(type, variation_base)
		for dt in Theme.DATA_TYPE_MAX:
			for item in base.get_theme_item_list(dt, type):
				var v: Variant = base.get_theme_item(dt, item, type)
				if dt == Theme.DATA_TYPE_STYLEBOX and v is StyleBox:
					v = (v as StyleBox).duplicate()
				t.set_theme_item(dt, item, type, v)
	for key: String in STYLE_ROLES:
		var parts := key.split("/")
		if not t.has_stylebox(parts[1], parts[0]):
			continue
		var sb := t.get_stylebox(parts[1], parts[0]) as StyleBoxFlat
		if sb == null:
			continue
		var spec: Array = STYLE_ROLES[key]
		sb.bg_color = _resolve(str(spec[0]), sb.bg_color)
		sb.border_color = _resolve(str(spec[1]), sb.border_color)
		if spec.size() > 2:
			sb.shadow_color = _resolve(str(spec[2]), sb.shadow_color)
	# After recoloring, so the copies get the palette colors too.
	for key: String in EXTRA_STYLES:
		var src: PackedStringArray = (EXTRA_STYLES[key] as String).split("/")
		var dst: PackedStringArray = key.split("/")
		if t.has_stylebox(src[1], src[0]):
			t.set_stylebox(dst[1], dst[0], t.get_stylebox(src[1], src[0]).duplicate())
	for table: Dictionary in [COLOR_ROLES, EXTRA_COLORS]:
		for key: String in table:
			var parts := key.split("/")
			var fallback := t.get_color(parts[1], parts[0]) if t.has_color(parts[1], parts[0]) else Color.MAGENTA
			if str(table[key]) == "" and not t.has_color(parts[1], parts[0]):
				continue
			t.set_color(parts[1], parts[0], _resolve(str(table[key]), fallback))
	for type: String in EXTRA_VARIATIONS:
		var spec: Dictionary = EXTRA_VARIATIONS[type]
		t.set_type_variation(type, spec["base"])
		var styles: Dictionary = spec["styles"]
		for style: String in styles:
			var entry: Array = styles[style]
			var src: PackedStringArray = str(entry[0]).split("/")
			if not t.has_stylebox(src[1], src[0]):
				continue
			var sb := t.get_stylebox(src[1], src[0]).duplicate() as StyleBoxFlat
			if sb == null:
				continue
			var roles_for: Array = entry[1]
			sb.bg_color = _resolve(str(roles_for[0]), sb.bg_color)
			sb.border_color = _resolve(str(roles_for[1]), sb.border_color)
			if int(entry[2]) > 0:
				sb.set_border_width_all(int(entry[2]))
			t.set_stylebox(style, type, sb)
	_add_icons(t)
	for role: String in roles:
		t.set_color(role, PALETTE_TYPE, roles[role])
	return t


## The engine's switch and radio icons are white, drawn for dark backgrounds,
## and icons can't be tinted by the theme, so draw them in the palette colors.
func _add_icons(t: Theme) -> void:
	var on := color("accent")
	var off := color("line_strong")
	var knob := color("knob")
	var faint := color("line_soft")
	for type in ["CheckButton"]:
		t.set_icon("checked", type, _svg_icon(_switch_svg(on, knob, true)))
		t.set_icon("unchecked", type, _svg_icon(_switch_svg(off, knob, false)))
		t.set_icon("checked_disabled", type, _svg_icon(_switch_svg(faint, knob, true)))
		t.set_icon("unchecked_disabled", type, _svg_icon(_switch_svg(faint, knob, false)))
	t.set_icon("grabber", "HSlider", _svg_icon(_knob_svg(color("accent_strong"), knob)))
	t.set_icon("grabber_highlight", "HSlider", _svg_icon(_knob_svg(color("accent"), knob)))
	t.set_icon("grabber_disabled", "HSlider", _svg_icon(_knob_svg(faint, knob)))
	t.set_icon("radio_checked", "PopupMenu", _svg_icon(_radio_svg(color("accent_strong"), true)))
	t.set_icon("radio_unchecked", "PopupMenu", _svg_icon(_radio_svg(off, false)))
	t.set_icon("checked", "PopupMenu", _svg_icon(_radio_svg(color("accent_strong"), true)))
	t.set_icon("unchecked", "PopupMenu", _svg_icon(_radio_svg(off, false)))


static func _switch_svg(track: Color, knob: Color, on: bool) -> String:
	return ('<svg xmlns="http://www.w3.org/2000/svg" width="44" height="24" viewBox="0 0 44 24">'
			+ '<rect x="1" y="2" width="42" height="20" rx="10" fill="#%s"/>'
			+ '<circle cx="%d" cy="12" r="7.5" fill="#%s"/></svg>') % [
				track.to_html(false), 33 if on else 11, knob.to_html(false)]


static func _knob_svg(c: Color, ring: Color) -> String:
	return ('<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 20 20">'
			+ '<circle cx="10" cy="10" r="8" fill="#%s" stroke="#%s" stroke-width="2.5"/></svg>') % [
				c.to_html(false), ring.to_html(false)]


static func _radio_svg(c: Color, on: bool) -> String:
	var dot := '<circle cx="8" cy="8" r="3.5" fill="#%s"/>' % c.to_html(false) if on else ""
	return ('<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16">'
			+ '<circle cx="8" cy="8" r="6.2" fill="none" stroke="#%s" stroke-width="1.6"/>%s</svg>') % [
				c.to_html(false), dot]


static func _svg_icon(svg: String) -> ImageTexture:
	var img := Image.new()
	img.load_svg_from_string(svg, 1.0)
	return ImageTexture.create_from_image(img)


## "role" or "role@alpha"; "" keeps fallback.
func _resolve(spec: String, fallback: Color) -> Color:
	if spec == "":
		return fallback
	var at := spec.find("@")
	var role := spec if at < 0 else spec.substr(0, at)
	var c: Color = roles.get(role, Color.MAGENTA)
	if at >= 0:
		c.a = spec.substr(at + 1).to_float()
	return c
