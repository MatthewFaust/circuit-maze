class_name RunController
extends Node
## Runs the player's program one step at a time and animates it.
##
## Each step: interpreter.step() -> highlight the block -> one Tween holds the
## step's animations -> await it. Pause pauses that tween; Reset kills it and
## bumps a generation counter that is checked after every await, so a stale
## run simply stops. The loop never awaits SceneTree timers, so nothing can
## resume after the level screen is freed.

signal state_changed(state: int)
signal variant_started(index: int)
signal variant_finished(index: int, summary: Dictionary)
signal run_finished(passed: bool, info: Dictionary)
signal _resumed
signal _frame
## Emitted when the current step's animation ends, or when it is cancelled.
signal _step_over

enum State { IDLE, RUNNING, PAUSED, FINISHED }

const STEP_GAP := 0.05
## At max speed, how long to simulate per frame before letting the screen update.
const FRAME_BUDGET_USEC := 6000

var state: int = State.IDLE
## Animation speed multiplier; 0 means max (no animation).
var speed := 1.0
var level: LevelData
var variant_index := 0
var world: MazeWorld
var interp: ProgramInterpreter
## Variant index -> interpreter summary of the last run.
var results := {}

var maze: MazeView
var hud: HudBars
var inspector: InspectorPanel
var log_line: LogLine
var editor: ProgramEditor

var _program := {}
var _gen := 0
var _tween: Tween
var _single_step := false
var _skip_steps := 0


func _process(_delta: float) -> void:
	_frame.emit()


func setup(p_level: LevelData, p_maze: MazeView, p_hud: HudBars, p_inspector: InspectorPanel,
		p_log: LogLine, p_editor: ProgramEditor) -> void:
	level = p_level
	maze = p_maze
	hud = p_hud
	inspector = p_inspector
	log_line = p_log
	editor = p_editor
	maze.show_trail = level.shows_trail()
	_load_variant(0)


func is_active() -> bool:
	return state == State.RUNNING or state == State.PAUSED


func select_variant(i: int) -> void:
	if is_active() or i < 0 or i >= level.variants.size():
		return
	variant_index = i
	if state == State.FINISHED:
		_set_state(State.IDLE)
		editor.clear_highlight()
	_load_variant(i)


func run() -> void:
	if state == State.PAUSED:
		resume()
	elif state != State.RUNNING:
		_start(false)


func step() -> void:
	if state == State.PAUSED:
		_single_step = true
		resume()
	elif state != State.RUNNING:
		_start(true)


## Runs the first n steps instantly and pauses (used for screenshots and tests).
func fast_forward(n: int) -> void:
	_skip_steps = maxi(n, 1)
	_start(false)


func pause() -> void:
	if state != State.RUNNING:
		return
	_set_state(State.PAUSED)
	if _tween != null and _tween.is_valid():
		_tween.pause()


func resume() -> void:
	if state != State.PAUSED:
		return
	_set_state(State.RUNNING)
	if _tween != null and _tween.is_valid():
		_tween.play()
	_resumed.emit()


func reset() -> void:
	_cancel()
	_single_step = false
	_skip_steps = 0
	results.clear()
	editor.set_locked(false)
	editor.clear_highlight()
	_set_state(State.IDLE)
	_load_variant(variant_index)
	log_line.clear()


## Stops the running coroutine: it wakes up, sees a new generation and returns.
func _cancel() -> void:
	_gen += 1
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	_step_over.emit()
	_resumed.emit()
	_frame.emit()


func _exit_tree() -> void:
	_cancel()


func set_speed(s: float) -> void:
	speed = s
	if _tween != null and _tween.is_valid():
		_tween.set_speed_scale(_tween_speed())


func _tween_speed() -> float:
	return speed if speed > 0.0 else 4.0


func _set_state(s: int) -> void:
	state = s
	state_changed.emit(s)


func _load_variant(i: int) -> void:
	world = level.variants[i].make_world(level)
	maze.show_world(world)
	hud.sync(world)
	inspector.reset(world)


func _start(single: bool) -> void:
	get_viewport().gui_release_focus()
	var p := editor.get_program_copy()
	var errs := LevelEvaluator.static_check(level, p)
	if not errs.is_empty():
		log_line.show_message(errs[0], "bad")
		return
	if ProgramModel.count_blocks(p) == 0:
		log_line.show_message("The program is empty. Drag some blocks into it first.", "warn")
		return
	_program = p
	results.clear()
	_gen += 1
	_single_step = single
	editor.clear_highlight()
	editor.set_locked(true)
	_set_state(State.RUNNING)
	_run_all(_gen)


## Runs the selected map first, then the others; stops at the first failure.
func _run_all(gen: int) -> void:
	var order: Array[int] = [variant_index]
	for i in level.variants.size():
		if i != variant_index:
			order.append(i)
	for n in order.size():
		var i := order[n]
		variant_index = i
		_load_variant(i)
		variant_started.emit(i)
		interp = ProgramInterpreter.new(_program, world)
		var summary: Dictionary = await _run_variant(gen)
		if gen != _gen:
			return
		results[i] = summary
		variant_finished.emit(i, summary)
		if not bool(summary["won"]):
			_finish(false, {"variant": i, "summary": summary})
			return
		if n < order.size() - 1:
			await _wait(0.8)
			if gen != _gen:
				return
	_finish(true, {"variant": variant_index})


func _run_variant(gen: int) -> Dictionary:
	var budget := Time.get_ticks_usec() + FRAME_BUDGET_USEC
	while true:
		while state == State.PAUSED:
			await _resumed
			if gen != _gen:
				return {}
		var r := interp.step()
		var events: Array[Dictionary] = r["events"]
		var skipping := _skip_steps > 0
		if skipping or (speed <= 0.0 and not _single_step):
			for e in events:
				maze.apply_event(e)
				hud.apply_event(e, false)
				log_line.apply_event(e)
			if skipping:
				_skip_steps -= 1
				if _skip_steps == 0 and r["status"] == "running":
					_sync_views(r)
					_set_state(State.PAUSED)
			elif Time.get_ticks_usec() > budget:
				_sync_views(r)
				await _frame
				if gen != _gen:
					return {}
				budget = Time.get_ticks_usec() + FRAME_BUDGET_USEC
		else:
			editor.highlight(r["node_id"], r["active_ids"])
			inspector.update_step(r, world)
			_tween = create_tween()
			_tween.set_speed_scale(_tween_speed())
			for e in events:
				maze.append_event(_tween, e)
				_tween.tween_callback(_notify.bind(e))
			_tween.tween_interval(STEP_GAP)
			_tween.finished.connect(_step_over.emit)
			await _step_over
			if gen != _gen:
				return {}
		if r["status"] != "running":
			_sync_views(r)
			if r["status"] == "failed" and int(r["node_id"]) >= 0:
				editor.mark_error(int(r["node_id"]))
			var summary := interp.summary()
			summary["node_id"] = r["node_id"]
			return summary
		if _single_step:
			_single_step = false
			_set_state(State.PAUSED)
	return {}


func _notify(e: Dictionary) -> void:
	hud.apply_event(e)
	log_line.apply_event(e)


func _sync_views(r: Dictionary) -> void:
	maze.sync()
	hud.sync(world)
	inspector.update_step(r, world)
	editor.highlight(r["node_id"], r["active_ids"])


func _wait(seconds: float) -> void:
	_tween = create_tween()
	_tween.tween_interval(seconds)
	_tween.finished.connect(_step_over.emit)
	await _step_over


func _finish(passed: bool, info: Dictionary) -> void:
	_set_state(State.FINISHED)
	editor.set_locked(false)
	run_finished.emit(passed, info)
