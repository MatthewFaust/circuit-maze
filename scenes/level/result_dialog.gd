class_name ResultDialog
extends Control
## Shown after a run: stars on success, or the reason and a CS tip on failure.
## Boss stages show the win instead of stars. Either way, anything the result
## unlocked (armor, weapons, skins) is listed.

signal retry_requested
signal next_requested
signal levels_requested

const STAR_ON := preload("res://art/ui/star.svg")
const STAR_OFF := preload("res://art/ui/star_empty.svg")
const STAR_NAMES := [["escape", "Escaped", "solved every map"],
		["stamina", "Efficient", "stamina used ≤ par"],
		["blocks", "Elegant", "blocks used ≤ par"]]
## fail code -> [headline, tip]
const FAILURES := {
	"no_stamina": ["Out of stamina", "Every move and turn costs 1 stamina, [b]cut()[/b] costs 3 and a scan costs 5. Look for a cheaper route, or a smarter algorithm."],
	"hp_zero": ["Robot destroyed", "Stone costs 15 HP, a bush 5 and a spike 25. Use a sensor to check what's ahead [i]before[/i] you move."],
	"program_ended": ["The program ended before the exit", "The robot stops when it runs out of blocks. A [b]while not at_exit()[/b] loop keeps it going until it escapes."],
	"op_limit": ["Possible infinite loop", "20,000 operations without escaping. Does your loop's condition ever change?"],
	"action_limit": ["Possible infinite loop", "1,000 actions without escaping. Is the robot going around in circles?"],
	"idle_loop": ["A loop that never acts", "A loop kept checking its condition without doing anything. Make sure every path through the loop body runs an action."],
	"stack_overflow": ["Stack overflow", "A function kept calling itself and never stopped. Every recursive function needs a [b]base case[/b] that returns without calling itself again."],
	"backtrack_empty": ["Nothing left to backtrack to", "[b]backtrack()[/b] needs a breadcrumb to return to. With an empty stack the robot has explored everything it can reach."],
	"static": ["Not allowed on this level", ""],
}
## Boss stages: the tip for losing a fight.
const BOSS_TIPS := {
	"hp_zero": "A boss hits for its attack minus your defense, and a strike interrupts any attack. Watch its rhythm: [b]block()[/b] on the turns it strikes. Better gear from the Garage also lets you survive a few mistakes.",
	"program_ended": "The fight isn't over until every boss is down. Keep attacking until boss_ahead() is false, or count the hits you need: its HP divided by your damage.",
}

@onready var _headline: Label = %Headline
@onready var _stars: HBoxContainer = %Stars
@onready var _reason: Label = %Reason
@onready var _tip: RichTextLabel = %Tip
@onready var _stats: GridContainer = %Stats
@onready var _levels: Button = %LevelsButton
@onready var _retry: Button = %RetryButton
@onready var _next: Button = %NextButton
var _unlocks: RichTextLabel


func _ready() -> void:
	($Dim as ColorRect).color = get_theme_color(&"dim", &"Palette")
	for b: Button in [_levels, _retry, _next]:
		b.focus_mode = Control.FOCUS_NONE
	_unlocks = RichTextLabel.new()
	_unlocks.bbcode_enabled = true
	_unlocks.fit_content = true
	_unlocks.scroll_active = false
	_unlocks.custom_minimum_size = Vector2(520, 0)
	_unlocks.hide()
	_stats.add_sibling(_unlocks)
	_levels.pressed.connect(func() -> void:
		hide()
		levels_requested.emit())
	_retry.pressed.connect(func() -> void:
		hide()
		retry_requested.emit())
	_next.pressed.connect(func() -> void:
		hide()
		next_requested.emit())


## ev comes from LevelEvaluator.evaluate(); unlocked from ProgressData.refresh_unlocks().
func show_success(level: LevelData, ev: Dictionary, has_next: bool, unlocked: Array = []) -> void:
	_show_unlocks(unlocked)
	if level.is_boss():
		_headline.text = "Boss defeated!"
		_headline.add_theme_color_override("font_color", get_theme_color(&"good", &"Palette"))
		_stars.hide()
		_reason.text = "You beat %s%s." % [level.boss["name"],
				" in every arena" if level.variants.size() > 1 else ""]
		_tip.text = "[center]%s[/center]" % level.cs_note
		_tip.visible = true
		_fill_stats(level, ev)
		_retry.text = "Fight again"
		_next.visible = has_next
		_next.text = "Next chapter"
		_pop()
		return
	var count := int(ev["star_count"])
	_headline.text = ["Escaped!", "Escaped!", "Great run!", "Perfect!"][count]
	_headline.add_theme_color_override("font_color", get_theme_color(&"good", &"Palette"))
	_build_stars(ev["stars"], true)
	_stars.show()
	var missing := PackedStringArray()
	if not bool((ev["stars"] as Dictionary)["stamina"]):
		missing.append("use less stamina (par %d)" % level.par_stamina)
	if not bool((ev["stars"] as Dictionary)["blocks"]):
		missing.append("use fewer blocks (par %d)" % level.par_blocks)
	_reason.text = "Your program escaped every map." if missing.is_empty() \
			else "To earn every star: " + " and ".join(missing) + "."
	_tip.text = "[center]%s[/center]" % level.cs_note
	_tip.visible = true
	_fill_stats(level, ev)
	_retry.text = "Keep improving" if count < 3 else "Keep editing"
	_next.visible = has_next
	_next.text = "Next level"
	_pop()


func show_failure(level: LevelData, ev: Dictionary, variant_name: String, code: String, message: String,
		unlocked: Array = []) -> void:
	_show_unlocks(unlocked)
	var f: Array = FAILURES.get(code, ["The robot didn't escape", ""])
	if level.is_boss():
		f = [("The boss is still standing" if code == "program_ended" else str(f[0])),
				BOSS_TIPS.get(code, str(f[1]))]
	_headline.text = str(f[0])
	_headline.add_theme_color_override("font_color", get_theme_color(&"bad", &"Palette"))
	_stars.hide()
	var where := " on %s" % variant_name if level.variants.size() > 1 and variant_name != "" else ""
	_reason.text = message + where
	_tip.text = "[center]%s[/center]" % str(f[1])
	_tip.visible = str(f[1]) != ""
	_fill_stats(level, ev)
	_retry.text = "Fix the program"
	_next.visible = false
	_pop()


func _build_stars(flags: Dictionary, animate: bool) -> void:
	for c in _stars.get_children():
		c.queue_free()
	var i := 0
	for entry: Array in STAR_NAMES:
		var on := bool(flags.get(entry[0], false))
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(72, 72)
		var star := TextureRect.new()
		star.texture = STAR_ON if on else STAR_OFF
		if not on:
			star.modulate = get_theme_color(&"line_strong", &"Palette")
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		star.set_anchors_preset(Control.PRESET_FULL_RECT)
		star.pivot_offset = Vector2(36, 36)
		holder.add_child(star)
		col.add_child(holder)
		var name_label := Label.new()
		name_label.text = str(entry[1])
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(name_label)
		var desc := Label.new()
		desc.theme_type_variation = &"Muted"
		desc.add_theme_font_size_override("font_size", 13)
		desc.text = str(entry[2])
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(desc)
		_stars.add_child(col)
		if animate and on and not Game.reduce_motion():
			star.scale = Vector2.ZERO
			var t := star.create_tween()
			t.tween_interval(0.25 + 0.2 * i)
			t.tween_callback(Sfx.play.bind(&"pickup"))
			t.tween_property(star, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		i += 1


func _fill_stats(level: LevelData, ev: Dictionary) -> void:
	for c in _stats.get_children():
		c.queue_free()
	var variants: Array = ev.get("variants", [])
	var passed := 0
	for v: Dictionary in variants:
		if bool(v["won"]):
			passed += 1
	if level.is_boss():
		_stat("Arenas won", "%d / %d" % [passed, level.variants.size()])
		_stat("Blocks used", "%d%s" % [int(ev["blocks"]), "   (limit %d)" % level.block_limit if level.block_limit > 0 else ""])
		if bool(ev.get("solved", false)):
			_stat("Stamina used", "%d" % int(ev["stamina_total"]))
		return
	_stat("Maps passed", "%d / %d" % [passed, level.variants.size()])
	_stat("Blocks used", "%d   (par %d%s)" % [int(ev["blocks"]), level.par_blocks,
			", limit %d" % level.block_limit if level.block_limit > 0 else ""])
	if bool(ev.get("solved", false)):
		_stat("Stamina used", "%d   (par %d)" % [int(ev["stamina_total"]), level.par_stamina])


## "Unlocked: ..." for new armor, weapons and skins.
func _show_unlocks(unlocked: Array) -> void:
	_unlocks.visible = not unlocked.is_empty()
	if unlocked.is_empty():
		return
	var parts := PackedStringArray()
	for u: Dictionary in unlocked:
		var how := ""
		match str(u["kind"]):
			"armor":
				how = "equipped" if bool(u["equipped"]) else "in the Garage"
			"weapon":
				how = "equip it in the Garage"
			"skin":
				how = "your new look"
		var detail := str(u["detail"])
		var pic := _unlock_icon(u)
		parts.append("%s[b]%s[/b] (%s, %s)" % ["[img=28]%s[/img] " % pic if pic != "" else "", u["name"],
				detail if detail != "skin" else "skin", how])
	_unlocks.text = "[center][color=#%s]UNLOCKED[/color]   %s[/center]" % [
			get_theme_color(&"accent_strong", &"Palette").to_html(false), "  ·  ".join(parts)]


## The picture of an unlocked item, or "".
static func _unlock_icon(u: Dictionary) -> String:
	var prog := ProgressionCatalog.get_default()
	var entry: Dictionary
	match str(u["kind"]):
		"armor":
			entry = prog.armor_by_id(str(u["id"]))
		"weapon":
			entry = prog.weapon_by_id(str(u["id"]))
		"skin":
			entry = prog.skin_by_id(str(u["id"]))
	var path := str(entry.get("icon", entry.get("texture", "")))
	return path if path != "" and ResourceLoader.exists(path) else ""


func _stat(name_text: String, value: String) -> void:
	var a := Label.new()
	a.theme_type_variation = &"Muted"
	a.text = name_text
	_stats.add_child(a)
	var b := Label.new()
	b.text = value
	_stats.add_child(b)


func _pop() -> void:
	show()
	if Game.reduce_motion():
		return
	# Only modulate: the CenterContainer would reset a scale animation.
	var panel: Control = $Center/Panel
	panel.modulate.a = 0.0
	panel.create_tween().tween_property(panel, "modulate:a", 1.0, 0.18)
