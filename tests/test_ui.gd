extends "res://tests/suite_base.gd"
## UI smoke tests: every screen loads without errors, the block editor reacts to
## simulated mouse input (click, drag, drop, delete, undo), and a full run of a
## level records stars. Uses a throwaway progress file.

const LEVEL_SCREEN := "res://scenes/level/level_screen.tscn"
const MAIN_MENU := "res://scenes/main_menu/main_menu.tscn"
const LEVEL_SELECT := "res://scenes/level_select/level_select.tscn"

var _progress: Node
var _saved_data: ProgressData
var _saved_path := ""


func _use_temp_progress() -> void:
	_progress = tree.root.get_node("Progress")
	_saved_data = _progress.get("data")
	_saved_path = _progress.get("path")
	_progress.set("data", ProgressData.new())
	_progress.set("path", "user://test_progress.cfg")


func _restore_progress() -> void:
	if _progress != null:
		# A pending debounced save must not write test data anywhere.
		var timer: Timer = _progress.get("_timer")
		if timer != null:
			timer.stop()
		_progress.set("data", _saved_data)
		_progress.set("path", _saved_path)
	if FileAccess.file_exists("user://test_progress.cfg"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_progress.cfg"))


func _frames(n: int) -> void:
	for i in n:
		await tree.process_frame


func _open(path: String, level_id: String = "") -> Node:
	var screen: Node = load(path).instantiate()
	if level_id != "":
		screen.set("level_id", level_id)
	tree.root.add_child(screen)
	await _frames(4)
	return screen


func _close(screen: Node) -> void:
	screen.queue_free()
	await _frames(2)


# Mouse events in viewport (canvas) coordinates.
func _mouse_button(pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	_send(e)


func _mouse_move(pos: Vector2, rel: Vector2, held: bool = true) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	e.relative = rel
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	_send(e)


## Straight into the root viewport: headless runs have no window to route
## Input events through. Input still learns the mouse position, which
## get_global_mouse_position() falls back to without a real mouse.
func _send(e: InputEventMouse) -> void:
	# Input works in screen space: the headless window is tiny and scaled, so
	# convert the canvas position before handing it over.
	var motion := InputEventMouseMotion.new()
	motion.position = tree.root.get_screen_transform() * e.position
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	tree.root.push_input(e, true)


func _drag(from: Vector2, to: Vector2) -> void:
	# A headless window never hears from the OS that the mouse entered it, so
	# Godot would never pick a drop target. With embedded subwindows the root
	# viewport finds the control under the mouse from the event itself.
	tree.root.gui_embed_subwindows = true
	_mouse_move(from, Vector2.ZERO, false)
	await _frames(1)
	_mouse_button(from, true)
	await _frames(1)
	var steps := 12
	var last := from
	for i in range(1, steps + 1):
		var p := from.lerp(to, float(i) / steps)
		_mouse_move(p, p - last)
		last = p
		await _frames(1)
	_mouse_button(to, false)
	await _frames(3)


func _click(pos: Vector2) -> void:
	_mouse_move(pos, Vector2.ZERO, false)
	await _frames(1)
	_mouse_button(pos, true)
	await _frames(1)
	_mouse_button(pos, false)
	await _frames(3)


func _palette_item(editor: ProgramEditor, kind: String) -> PaletteItem:
	for item: PaletteItem in editor._palette_items:
		if item.kind == kind:
			return item
	return null


func _center(c: Control) -> Vector2:
	return c.get_global_rect().get_center()


func test_every_screen_loads() -> void:
	_use_temp_progress()
	for path in [MAIN_MENU, LEVEL_SELECT]:
		var s := await _open(path)
		await _close(s)
	var catalog := LevelCatalog.load_from(LevelCatalog.DEFAULT_PATH)
	for id in catalog.order:
		var s := await _open(LEVEL_SCREEN, id)
		check(s.get("level") != null, "level %s did not load" % id)
		await _close(s)
	_restore_progress()


func test_editor_click_drag_delete_undo() -> void:
	_use_temp_progress()
	var screen := await _open(LEVEL_SCREEN, "1-1")
	var editor: ProgramEditor = screen.find_child("ProgramEditor", true, false)
	(screen.find_child("IntroDialog", true, false) as Control).hide()
	editor.clear_program()
	await _frames(2)
	check_eq(editor.block_count(), 0, "starts empty")
	var move_item := _palette_item(editor, "move")
	if not check(move_item != null, "palette has move()"):
		return

	# Click a palette block: appends it.
	await _click(_center(move_item))
	check_eq(editor.block_count(), 1, "click appends a block")

	# Drag a palette block into the program, below the first block.
	var list: BlockListView = editor._lists[0]
	var target := list.hit_rect().get_center() + Vector2(0, list.hit_rect().size.y * 0.4)
	await _drag(_center(move_item), target)
	check_eq(editor.block_count(), 2, "drag from the palette inserts a block")

	# Drag a program block back onto the palette: deletes it.
	await _frames(2)
	var first: BlockView = editor._lists[0].block_views[0]
	await _drag(_center(first) + Vector2(-first.size.x * 0.3, 0), _center(editor._palette))
	check_eq(editor.block_count(), 1, "drag onto the palette deletes")

	# Undo and redo.
	editor.undo()
	await _frames(2)
	check_eq(editor.block_count(), 2, "undo restores the block")
	editor.redo()
	await _frames(2)
	check_eq(editor.block_count(), 1, "redo deletes it again")
	await _close(screen)
	_restore_progress()


func test_drop_into_loop_and_reject_self_nesting() -> void:
	_use_temp_progress()
	var screen := await _open(LEVEL_SCREEN, "1-4")
	var editor: ProgramEditor = screen.find_child("ProgramEditor", true, false)
	(screen.find_child("IntroDialog", true, false) as Control).hide()
	editor.clear_program()
	editor.append_new("repeat")
	await _frames(3)
	var repeat_view: BlockView = editor._lists[0].block_views[0]
	var body: BlockListView = null
	for l in editor._lists:
		if l.ref == "%d:body" % repeat_view.node_id:
			body = l
	if not check(body != null, "repeat has a body list"):
		return
	await _drag(_center(_palette_item(editor, "move")), body.hit_rect().get_center())
	var p := editor.get_program_copy()
	var rep: Dictionary = (p["main"] as Array)[0]
	check_eq((rep["body"] as Array).size(), 1, "move() dropped inside the repeat")
	# Dragging the repeat into its own body must be refused.
	await _frames(2)
	repeat_view = editor._lists[0].block_views[0]
	for l in editor._lists:
		if l.ref == "%d:body" % repeat_view.node_id:
			body = l
	await _drag(_center(repeat_view) + Vector2(-repeat_view.size.x * 0.35, -repeat_view.size.y * 0.35),
			body.hit_rect().get_center())
	p = editor.get_program_copy()
	check_eq((p["main"] as Array).size(), 1, "repeat is still at the top level")
	await _close(screen)
	_restore_progress()


func test_full_run_records_stars() -> void:
	_use_temp_progress()
	var screen := await _open(LEVEL_SCREEN, "2-2")
	var editor: ProgramEditor = screen.find_child("ProgramEditor", true, false)
	var run: RunController = screen.find_child("RunController", true, false)
	(screen.find_child("IntroDialog", true, false) as Control).hide()
	var level: LevelData = screen.get("level")
	editor.set_program(ProgramParser.parse(level.solution_text)["program"])
	run.set_speed(0.0)
	run.run()
	for i in 600:
		if run.state == RunController.State.FINISHED:
			break
		await tree.process_frame
	check_eq(run.state, RunController.State.FINISHED, "run finished")
	var result: Control = screen.find_child("ResultDialog", true, false)
	var until := Time.get_ticks_msec() + 3000
	while not result.visible and Time.get_ticks_msec() < until:
		await tree.process_frame
	check(result.visible, "result dialog shown")
	var data: ProgressData = _progress.get("data")
	check_eq(data.stars("2-2"), 3, "three stars recorded")
	await _close(screen)
	_restore_progress()



## Typed keys go straight to the focused control.
func _type(text: String) -> void:
	for ch in text:
		for pressed in [true, false]:
			var k := InputEventKey.new()
			k.keycode = OS.find_keycode_from_string(ch)
			k.physical_keycode = k.keycode
			k.unicode = ch.unicode_at(0) if pressed else 0
			k.pressed = pressed
			tree.root.push_input(k)
		await _frames(1)


## Clicks a repeat count, types a new one without pressing Enter, then clicks
## Run or Check: both must use the typed count, not the old one.
func test_typed_repeat_count_applies_on_run_and_check() -> void:
	_use_temp_progress()
	var screen := await _open(LEVEL_SCREEN, "1-5")
	var editor: ProgramEditor = screen.find_child("ProgramEditor", true, false)
	var run: RunController = screen.find_child("RunController", true, false)
	(screen.find_child("IntroDialog", true, false) as Control).hide()
	var level: LevelData = screen.get("level")
	var p: Dictionary = ProgramParser.parse(level.solution_text)["program"]
	((p["main"] as Array)[0] as Dictionary)["count"] = 2
	tree.root.gui_embed_subwindows = true
	run.set_speed(0.0)
	for button in ["RunButton", "CheckButton"]:
		editor.set_program(p)
		await _frames(3)
		var spin: SpinBox = editor._lists[0].block_views[0].widgets[0]
		await _click(_center(spin.get_line_edit()))
		check_eq(spin.get_line_edit().get_selected_text(), "2", "clicking the count selects it")
		await _type("3")
		await _click(_center(screen.find_child(button, true, false)))
		var main: Array = editor.get_program_copy()["main"]
		check_eq(int((main[0] as Dictionary)["count"]), 3, "%s used the typed count" % button)
		if button == "RunButton":
			for i in 600:
				if run.state == RunController.State.FINISHED:
					break
				await tree.process_frame
			var summary: Dictionary = run.results.get(0, {})
			check(bool(summary.get("won", false)), "the run escaped (got %s)" % str(summary.get("fail_code", "")))
			run.reset()
		else:
			var data: ProgressData = _progress.get("data")
			check_eq(data.stars("1-5"), 3, "Check recorded three stars")
		(screen.find_child("ResultDialog", true, false) as Control).hide()
	await _close(screen)
	_restore_progress()
