class_name LevelVariant
extends RefCounted
## One map of a level. Every variant is a test case the program must pass.

var name := ""
var rows := PackedStringArray()
var grid: MazeGrid
var start := Vector2i.ZERO
var facing: int = Tiles.EAST
## Max (and starting) stamina on this map.
var stamina := 0
## Boss stages: the "M" cells, and a rhythm replacing the units' own ("" keeps them).
var boss_cells: Array[Vector2i] = []
var boss_pattern := ""


## A fresh world for one run. The grid is cloned so cut bushes and used items
## come back next run. loadout: {"damage", "defense"} from the player's gear;
## null uses the level's default (its boss's minimum gear).
func make_world(level: LevelData, loadout: Variant = null) -> MazeWorld:
	var w := MazeWorld.new(grid.clone(), start, facing, level.rules, stamina, level.fog)
	if level.is_boss():
		var lo: Dictionary = level.default_loadout() if loadout == null else loadout
		w.setup_combat(level.boss["units"], boss_cells, boss_pattern, int(lo.get("damage", 0)),
				int(lo.get("defense", 0)))
	return w
