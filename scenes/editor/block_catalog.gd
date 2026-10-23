class_name BlockCatalog
extends RefCounted
## Display data for blocks and sensors: labels, categories, icons and tooltips.

const VARIATIONS := {
	"motion": &"BlockMotion", "control": &"BlockControl", "function": &"BlockFunction",
	"algorithm": &"BlockAlgorithm", "sensing": &"BlockSensing", "combat": &"BlockCombat",
}
const BLOCKS := {
	"move": {"label": "move()", "category": "motion",
		"tip": "Step forward one tile. Costs 1 stamina.\nWalking into stone costs 15 HP, into a bush 5 HP."},
	"turn_left": {"label": "turn_left()", "category": "motion",
		"tip": "Turn 90° to the robot's left. Costs 1 stamina."},
	"turn_right": {"label": "turn_right()", "category": "motion",
		"tip": "Turn 90° to the robot's right. Costs 1 stamina."},
	"cut": {"label": "cut()", "category": "motion",
		"tip": "Destroy the bush right in front of the robot. Costs 3 stamina,\neven when there is nothing to cut."},
	"repeat": {"label": "repeat", "category": "control",
		"tip": "Run the blocks inside N times.\nIn Python: for _ in range(N):"},
	"while": {"label": "while", "category": "control",
		"tip": "Keep running the blocks inside as long as the condition is true.\nThe condition is checked before every pass."},
	"if": {"label": "if", "category": "control",
		"tip": "Run the blocks inside only when the condition is true."},
	"if_else": {"label": "if", "category": "control",
		"tip": "Run the first branch when the condition is true, otherwise the else branch."},
	"call": {"label": "call", "category": "function",
		"tip": "Run the blocks in this function, then come back here."},
	"attack": {"label": "attack()", "category": "combat",
		"tip": "Hit the boss in front of you: 2 damage plus your weapon's. Costs 1 stamina.\nA boss striking this turn interrupts the attack."},
	"block": {"label": "block()", "category": "combat",
		"tip": "Raise your shield for one turn: a strike this turn does no damage. Costs 1 stamina."},
	"backtrack": {"label": "backtrack()", "category": "algorithm",
		"tip": "Pop the breadcrumb stack: turn toward the tile you came from and step back.\nCosts 1 stamina plus 1 per turn."},
	"scan": {"label": "scan()", "category": "algorithm",
		"tip": "Breadth-first search outward from the exit: every reachable tile gets its\ndistance in steps. Bushes count as walls. Costs 5 stamina."},
	"scan_weighted": {"label": "scan_weighted()", "category": "algorithm",
		"tip": "Dijkstra's algorithm from the exit: every tile gets the stamina needed to escape.\nA bush costs 4 (cut + move). Costs 5 stamina."},
}
const SENSORS := {
	"path_ahead": "The tile in front is open: not stone and not a bush (spikes count as open).",
	"path_left": "The tile to the robot's left is open.",
	"path_right": "The tile to the robot's right is open.",
	"bush_ahead": "A bush is right in front of the robot.",
	"stone_ahead": "Stone (or the map edge) is right in front of the robot.",
	"spike_ahead": "A spike is right in front of the robot.",
	"at_exit": "The robot is on the exit. Reaching the exit ends the run at once, so inside\na running program this is always false: while not at_exit() means \"forever\".",
	"unvisited_ahead": "The tile in front is open and the robot has never stood on it.",
	"unvisited_left": "The tile to the left is open and has never been visited.",
	"unvisited_right": "The tile to the right is open and has never been visited.",
	"closer_ahead": "After scan(): stepping forward keeps you on a cheapest path to the exit.",
	"closer_left": "After scan(): the tile to the left is on a cheapest path to the exit.",
	"closer_right": "After scan(): the tile to the right is on a cheapest path to the exit.",
	"boss_ahead": "A boss is standing right in front of the robot.",
	"boss_charging": "The boss in front of the robot will strike on the next turn: block() now.",
}
const ICONS := {
	"move": preload("res://art/blocks/move.svg"),
	"turn_left": preload("res://art/blocks/turn_left.svg"),
	"turn_right": preload("res://art/blocks/turn_right.svg"),
	"cut": preload("res://art/blocks/cut.svg"),
	"repeat": preload("res://art/blocks/repeat.svg"),
	"while": preload("res://art/blocks/while.svg"),
	"if": preload("res://art/blocks/if.svg"),
	"if_else": preload("res://art/blocks/if_else.svg"),
	"call": preload("res://art/blocks/call.svg"),
	"backtrack": preload("res://art/blocks/backtrack.svg"),
	"scan": preload("res://art/blocks/scan.svg"),
	"scan_weighted": preload("res://art/blocks/scan_weighted.svg"),
	"attack": preload("res://art/blocks/attack.svg"),
	"block": preload("res://art/blocks/block.svg"),
}
const PALETTE_GROUPS := [
	["Actions", ["move", "turn_left", "turn_right", "cut"]],
	["Control", ["repeat", "while", "if", "if_else"]],
	["Algorithms", ["backtrack", "scan", "scan_weighted"]],
	["Combat", ["attack", "block"]],
]


## "move", "repeat", ... or "call:A" for a call block.
static func kind_of(node: Dictionary) -> String:
	var t: String = node.get("type", "")
	if t == "call":
		return "call:" + str(node.get("fn", "A"))
	return t


static func base_type(kind: String) -> String:
	return "call" if kind.begins_with("call:") else kind


static func info(kind: String) -> Dictionary:
	return BLOCKS.get(base_type(kind), {"label": kind, "category": "motion", "tip": ""})


static func variation(kind: String) -> StringName:
	return VARIATIONS[str(info(kind)["category"])]


static func icon(kind: String) -> Texture2D:
	return ICONS.get(base_type(kind), null)


static func label(kind: String) -> String:
	if kind.begins_with("call:"):
		return kind.substr(5) + "()"
	return str(info(kind)["label"])


static func tooltip(kind: String) -> String:
	return str(info(kind)["tip"])


static func sensor_tip(sensor: String) -> String:
	return SENSORS.get(sensor, "")


## [[group title, [kinds]]] for this level's palette, empty groups left out.
static func palette_for(level: LevelData) -> Array:
	var out: Array = []
	for group: Array in PALETTE_GROUPS:
		var kinds: Array = []
		for k: String in group[1]:
			if level.allowed_blocks.has(k):
				kinds.append(k)
		if not kinds.is_empty():
			out.append([group[0], kinds])
	if level.uses_functions():
		var calls: Array = []
		for f in level.allowed_functions:
			calls.append("call:" + f)
		out.insert(mini(2, out.size()), ["Functions", calls])
	return out
