class_name Tiles
extends RefCounted
## Tile ids, the map legend and facing directions shared by the whole game.

enum { FLOOR, STONE, BUSH, EXIT, SPIKE, BATTERY, REPAIR }

## Map characters, indexed by tile id. "S" marks the start (floor underneath).
const CHARS := [".", "#", "B", "E", "^", "+", "H"]
const NAMES := ["floor", "stone", "bush", "exit", "spike", "battery", "repair kit"]
const START_CHAR := "S"
## "M" marks a boss in boss stages (floor underneath).
const BOSS_CHAR := "M"

## Facing: 0 = north, 1 = east, 2 = south, 3 = west (clockwise, y grows downward).
const NORTH := 0
const EAST := 1
const SOUTH := 2
const WEST := 3
const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const FACING_CHARS := "NESW"
const FACING_NAMES := ["north", "east", "south", "west"]


## Tile id for a map character, or -1. The start marker "S" is not a tile.
static func from_char(c: String) -> int:
	return CHARS.find(c)


## The robot can stand on (and move onto) every tile except stone and bush.
static func is_walkable(t: int) -> bool:
	return t != STONE and t != BUSH


static func dir_vec(facing: int) -> Vector2i:
	return DIRS[posmod(facing, 4)]


## Facing for "N"/"E"/"S"/"W", or -1.
static func facing_from_char(c: String) -> int:
	if c.length() != 1:
		return -1
	return FACING_CHARS.find(c.to_upper())


## Facing that points along a unit step, or -1 if the step is not orthogonal.
static func facing_toward(delta: Vector2i) -> int:
	return DIRS.find(delta)


static func tile_name(t: int) -> String:
	if t < 0 or t >= NAMES.size():
		return "unknown"
	return NAMES[t]
