extends Node
## Scene navigation (with a short fade), the level catalog, and developer
## options passed on the command line after "--", for example:
##   Godot --path <project> -- --level=2-3 --program=solution --steps=5 --shot=/tmp/a.png
##
## Options: --level=ID  --variant=N (1-based)  --program=solution|starter|empty
##   --steps=N (run N steps instantly)  --autorun  --speed=1|2|4|0 (0 = max)
##   --intro (show the intro dialog)  --result (evaluate and show the result)
##   --code (open the code view)  --screen=menu|select  --shot=PATH (save a PNG and quit)
##   --unlock-all  --save=user://dev.cfg

const MAIN_MENU := "res://scenes/main_menu/main_menu.tscn"
const LEVEL_SELECT := "res://scenes/level_select/level_select.tscn"
const LEVEL_SCREEN := "res://scenes/level/level_screen.tscn"
const FADE_TIME := 0.18

var catalog: LevelCatalog
var current_level_id := ""
var dev := {}
var _dev_routed := false
var _fade: ColorRect
var _busy := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	catalog = LevelCatalog.get_default()
	for e in catalog.errors:
		push_error(e)
	dev = parse_args(OS.get_cmdline_user_args())
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.078, 0.094, 0.141, 1)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.modulate.a = 0.0
	layer.add_child(_fade)


static func parse_args(args: PackedStringArray) -> Dictionary:
	var out := {}
	for arg in args:
		if not arg.begins_with("--"):
			continue
		var body := arg.substr(2)
		var eq := body.find("=")
		if eq < 0:
			out[body] = true
		else:
			out[body.substr(0, eq)] = body.substr(eq + 1)
	return out


func dev_value(key: String, default: Variant = null) -> Variant:
	return dev.get(key, default)


## Called once by the main menu: jumps straight to a screen given on the command line.
func route_dev_args() -> bool:
	if _dev_routed:
		return false
	_dev_routed = true
	if dev.has("level"):
		goto_level(str(dev["level"]), false)
		return true
	if str(dev.get("screen", "")) == "select":
		goto_level_select(false)
		return true
	if dev.has("shot"):
		capture_and_quit(str(dev["shot"]))
	return false


func goto_main_menu() -> void:
	_switch(load(MAIN_MENU).instantiate())


func goto_level_select(fade: bool = true) -> void:
	_switch(load(LEVEL_SELECT).instantiate(), fade)


func goto_level(id: String, fade: bool = true) -> void:
	if catalog.get_level(id) == null:
		push_error("Unknown level '%s'" % id)
		return
	current_level_id = id
	Progress.data.last_level = id
	var screen: Node = load(LEVEL_SCREEN).instantiate()
	screen.set("level_id", id)
	_switch(screen, fade)


func next_level_id(id: String) -> String:
	return catalog.next_id(id)


func reduce_motion() -> bool:
	return bool(Progress.data.settings.get("reduce_motion", false))


func _switch(node: Node, fade: bool = true) -> void:
	if _busy:
		node.queue_free()
		return
	_busy = true
	var use_fade := fade and not reduce_motion()
	if use_fade:
		var t := create_tween()
		t.tween_property(_fade, "modulate:a", 1.0, FADE_TIME)
		await t.finished
	# Deferred: switching inside a scene's _ready() would remove it while the
	# tree is still adding it.
	get_tree().change_scene_to_node.call_deferred(node)
	await get_tree().process_frame
	await get_tree().process_frame
	if use_fade:
		var t2 := create_tween()
		t2.tween_property(_fade, "modulate:a", 0.0, FADE_TIME)
		await t2.finished
	_busy = false


## Saves a screenshot once the current screen has laid out, then quits.
func capture_and_quit(path: String, delay_frames: int = 6) -> void:
	for i in delay_frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(path)
	print("screenshot %s -> %s" % [path, error_string(err)])
	get_tree().quit()
