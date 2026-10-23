class_name LogLine
extends PanelContainer
## One line of feedback under the maze ("Bump! -15 HP", "Scanned 41 tiles").

## Tones, as roles of the chapter palette.
const TONES := ["info", "good", "warn", "bad"]

var _label: Label
## Says "Boss defeated!" instead of "Escaped!" on a win.
var _boss_stage := false


func set_boss_stage(on: bool) -> void:
	_boss_stage = on


func _ready() -> void:
	_label = Label.new()
	_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_label)


func show_message(text: String, tone: String = "info") -> void:
	_label.text = text
	_label.add_theme_color_override("font_color",
			get_theme_color(StringName(tone if TONES.has(tone) else "info"), &"Palette"))


func clear() -> void:
	show_message("")


func apply_event(e: Dictionary) -> void:
	match str(e["type"]):
		"bumped":
			var t := int(e["tile"])
			show_message("Bump! The robot walked into %s." % ("a bush" if t == Tiles.BUSH else "stone"), "bad")
		"hp_changed":
			var delta := int(e["delta"])
			if delta < 0:
				show_message("%s: %d HP (%d left)" % [_cause(str(e["cause"])), delta, int(e["value"])], "bad")
			elif delta > 0:
				show_message("Repair kit: +%d HP" % delta, "good")
		"picked_up":
			if str(e["item"]) == "battery":
				var wasted := int(e["wasted"])
				show_message("Battery: +%d stamina%s" % [int(e["amount"]),
						" (%d wasted: you were nearly full)" % wasted if wasted > 0 else ""], "good")
		"cut":
			show_message("Snip! The bush is gone.", "info")
		"warning":
			show_message(str(e["text"]), "warn")
		"scanned":
			var order: PackedInt32Array = e["order"]
			show_message("%s labelled %d tiles; the queue peaked at %d tiles." % [
					"Dijkstra" if bool(e["weighted"]) else "BFS", order.size(), int(e["max_frontier"])], "info")
		"boss_hit":
			show_message("Hit! -%d (%d / %d left)" % [int(e["damage"]), int(e["hp"]), int(e["max_hp"])], "good")
		"attack_interrupted":
			show_message("Interrupted: the boss struck first, so the attack missed.", "warn")
		"boss_struck":
			if bool(e["blocked"]):
				show_message("Blocked! The shield took the strike.", "good")
		"boss_split":
			show_message("It split into %d!" % (e["children"] as Array).size(), "warn")
		"boss_defeated":
			show_message("%s is down!" % str(e["name"]), "good")
		"blocked":
			show_message("Shield up.", "info")
		"won":
			show_message("Boss defeated!" if _boss_stage else "Escaped!", "good")
		"failed":
			show_message(str(e["message"]), "bad")


func _cause(cause: String) -> String:
	match cause:
		"bump":
			return "Bump"
		"boss":
			return "The boss hits"
		"spike":
			return "Spikes"
	return cause.capitalize()
