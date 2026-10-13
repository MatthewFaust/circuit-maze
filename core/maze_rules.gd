class_name MazeRules
extends RefCounted
## Every cost, damage amount and limit in the game. A level can override any
## of these through its "rules" object.

var max_hp := 100
var move_cost := 1
var turn_cost := 1
var cut_cost := 3
## Cost of the step itself; backtrack() also pays turn_cost for each turn it needs.
var backtrack_cost := 1
var scan_cost := 5
var bump_stone_damage := 15
var bump_bush_damage := 5
var spike_damage := 25
var battery_amount := 10
var repair_amount := 30
var max_actions := 1000
var max_ops := 20000
var max_idle_ops := 2000
var max_call_depth := 100

const OVERRIDABLE := [
	"max_hp", "move_cost", "turn_cost", "cut_cost", "backtrack_cost", "scan_cost",
	"bump_stone_damage", "bump_bush_damage", "spike_damage", "battery_amount",
	"repair_amount", "max_actions", "max_ops", "max_idle_ops", "max_call_depth",
]


## Builds rules from a level's overrides. Unknown keys and non-integers are
## reported in errors and ignored.
static func from_overrides(overrides: Dictionary, errors: Array[String]) -> MazeRules:
	var r := MazeRules.new()
	for key: Variant in overrides:
		if typeof(key) != TYPE_STRING or not OVERRIDABLE.has(key):
			errors.append("unknown rule '%s'" % str(key))
			continue
		var v: Variant = overrides[key]
		if typeof(v) == TYPE_FLOAT and float(v) == floorf(float(v)):
			v = int(v)
		if typeof(v) != TYPE_INT:
			errors.append("rule '%s' must be an integer" % key)
			continue
		r.set(key, v)
	return r


func duplicate_rules() -> MazeRules:
	var r := MazeRules.new()
	for key: String in OVERRIDABLE:
		r.set(key, get(key))
	return r
