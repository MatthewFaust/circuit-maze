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


## A fresh world for one run. The grid is cloned so cut bushes and used items
## come back next run.
func make_world(level: LevelData) -> MazeWorld:
	return MazeWorld.new(grid.clone(), start, facing, level.rules, stamina, level.fog)
