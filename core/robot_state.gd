class_name RobotState
extends RefCounted
## Where the robot is, which way it faces, and its health and stamina.

var pos := Vector2i.ZERO
var facing: int = Tiles.EAST
var hp: int = 100
var max_hp: int = 100
var stamina: int = 10
var max_stamina: int = 10


func clone() -> RobotState:
	var r := RobotState.new()
	r.pos = pos
	r.facing = facing
	r.hp = hp
	r.max_hp = max_hp
	r.stamina = stamina
	r.max_stamina = max_stamina
	return r
