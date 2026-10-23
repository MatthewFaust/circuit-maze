class_name RobotGear
extends RefCounted
## How the equipped gear sits on the robot: the weapon mounted at the front-top
## corner (the robot faces east), the armor as a badge on its back. Offsets are
## in the robot texture's 128 px space, from its center. The maze, the Garage
## preview and the main-menu logo all dress the robot through here.

const ROBOT_PX := 128.0
const WEAPON_OFFSET := Vector2(30, -34)
const WEAPON_SCALE := 0.42
const ARMOR_OFFSET := Vector2(-44, 18)
const ARMOR_SCALE := 0.38


## The equipped look: {"skin", "armor", "weapon"} textures (null for none).
static func look(data: ProgressData) -> Dictionary:
	var prog := ProgressionCatalog.get_default()
	return {
		"skin": _texture(prog.skin_by_id(data.skin).get("texture", "")),
		"armor": _texture(prog.armor_by_id(data.equipped_armor).get("icon", "")),
		"weapon": _texture(prog.weapon_by_id(data.equipped_weapon).get("icon", "")),
	}


## Adds (or replaces) "Armor" and "Weapon" child sprites on the robot's body
## sprite, so they turn and flash with it.
static func dress_sprite(body: Sprite2D, armor: Texture2D, weapon: Texture2D) -> void:
	_sprite(body, "Armor", armor, ARMOR_OFFSET, ARMOR_SCALE)
	_sprite(body, "Weapon", weapon, WEAPON_OFFSET, WEAPON_SCALE)


## The same for a TextureRect showing the robot (it must not be a container).
static func dress_rect(rect: TextureRect, armor: Texture2D, weapon: Texture2D) -> void:
	_rect(rect, "Armor", armor, ARMOR_OFFSET, ARMOR_SCALE)
	_rect(rect, "Weapon", weapon, WEAPON_OFFSET, WEAPON_SCALE)


static func _sprite(body: Sprite2D, node_name: String, tex: Texture2D, offset: Vector2, s: float) -> void:
	var old := body.get_node_or_null(node_name)
	if old != null:
		body.remove_child(old)
		old.queue_free()
	if tex == null:
		return
	var sp := Sprite2D.new()
	sp.name = node_name
	sp.texture = tex
	sp.position = offset
	sp.scale = Vector2(s, s)
	body.add_child(sp)


static func _rect(rect: TextureRect, node_name: String, tex: Texture2D, offset: Vector2, s: float) -> void:
	var old := rect.get_node_or_null(node_name)
	if old != null:
		rect.remove_child(old)
		old.queue_free()
	if tex == null:
		return
	var r := TextureRect.new()
	r.name = node_name
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_meta(&"gear_offset", offset)
	r.set_meta(&"gear_scale", s)
	rect.add_child(r)
	var place := Callable(RobotGear, "_place_all").bind(rect)
	if not rect.resized.is_connected(place):
		rect.resized.connect(place)
	place.call_deferred()


## Positions the overlays from the robot rect's size (the robot fills its shorter side).
static func _place_all(rect: TextureRect) -> void:
	if not is_instance_valid(rect):
		return
	var k := minf(rect.size.x, rect.size.y) / ROBOT_PX
	for child in rect.get_children():
		if not child.has_meta(&"gear_offset"):
			continue
		var r := child as TextureRect
		var side := ROBOT_PX * float(r.get_meta(&"gear_scale")) * k
		r.size = Vector2(side, side)
		r.position = rect.size / 2.0 + Vector2(r.get_meta(&"gear_offset")) * k - r.size / 2.0


static func _texture(path: Variant) -> Texture2D:
	var p := str(path)
	return load(p) if p != "" and ResourceLoader.exists(p) else null
