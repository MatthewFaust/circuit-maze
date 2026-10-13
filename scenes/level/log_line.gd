class_name LogLine
extends PanelContainer
## One line of feedback under the maze ("Bump! -15 HP", "Scanned 41 tiles").

const COLORS := {
	"info": Color(0.9, 0.92, 0.95), "good": Color(0.4, 0.95, 0.7),
	"warn": Color(1.0, 0.82, 0.4), "bad": Color(1.0, 0.45, 0.5),
}

var _label: Label


func _ready() -> void:
	_label = Label.new()
	_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_label)


func show_message(text: String, tone: String = "info") -> void:
	_label.text = text
	_label.add_theme_color_override("font_color", COLORS.get(tone, COLORS["info"]))


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
		"won":
			show_message("Escaped!", "good")
		"failed":
			show_message(str(e["message"]), "bad")


func _cause(cause: String) -> String:
	match cause:
		"bump":
			return "Bump"
		"spike":
			return "Spikes"
	return cause.capitalize()
