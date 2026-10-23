extends Control
## The play screen: the maze, bars and run controls on the left, the block
## editor on the right. Wires the views to the RunController and records results.

const CHECK_ICON := preload("res://art/ui/check.svg")
const CROSS_ICON := preload("res://art/ui/cross.svg")
const DOT_ICON := preload("res://art/ui/dot.svg")
const SPEEDS := [1.0, 2.0, 4.0, 0.0]

var level_id := ""
var level: LevelData
var _hints: HintPanel
var _js_button: Button
var _tab_guard := false
var _speed_buttons: Array[Button] = []

@onready var _title: Label = %LevelTitle
@onready var _back: Button = %BackButton
@onready var _info: Button = %InfoButton
@onready var _hud: HudBars = %Hud
@onready var _tabs: TabBar = %VariantTabs
@onready var _maze: MazeView = %MazeView
@onready var _inspector: InspectorPanel = %Inspector
@onready var _log: LogLine = %LogLine
@onready var _run_button: Button = %RunButton
@onready var _pause_button: Button = %PauseButton
@onready var _step_button: Button = %StepButton
@onready var _reset_button: Button = %ResetButton
@onready var _check_button: Button = %CheckButton
@onready var _hint_button: Button = %HintButton
@onready var _code_button: Button = %CodeButton
@onready var _editor: ProgramEditor = %ProgramEditor
@onready var _run: RunController = %RunController
@onready var _intro: IntroDialog = %IntroDialog
@onready var _result: ResultDialog = %ResultDialog


## Before the children's _ready(), so they're built in the chapter's colors.
func _enter_tree() -> void:
	if level != null:
		return
	if level_id == "":
		level_id = str(Game.dev.get("level", Game.current_level_id))
	level = Game.catalog.get_level(level_id)
	if level == null:
		level = Game.catalog.get_level(Game.catalog.order[0])
		level_id = level.id
	theme = ChapterPalette.theme_for_chapter(level.chapter)


func _ready() -> void:
	($Bg as ColorRect).color = get_theme_color(&"bg", &"Palette")
	Game.current_level_id = level_id
	Progress.data.last_level = level_id

	_title.text = "%s   %s" % [level.id, level.title]
	_title.tooltip_text = level.concept
	for v in level.variants:
		_tabs.add_tab(v.name, DOT_ICON)
	_tabs.visible = level.variants.size() > 1
	_tabs.tab_changed.connect(_on_tab_changed)
	_inspector.configure(level)
	_hints = HintPanel.new()
	_maze.add_child(_hints)
	_hints.setup(level.hints, ProgramPrinter.block_text(ProgramParser.parse(level.solution_text)["program"]))

	var program := Progress.data.get_program(level.id)
	if program.is_empty():
		program = level.starter_program()
	_editor.setup(level, program)
	_editor.program_changed.connect(_on_program_changed)
	_editor.message.connect(func(text: String) -> void: _log.show_message(text, "warn"))

	_run.setup(level, _maze, _hud, _inspector, _log, _editor)
	_run.state_changed.connect(_on_state_changed)
	_run.variant_started.connect(_on_variant_started)
	_run.variant_finished.connect(_on_variant_finished)
	_run.run_finished.connect(_on_run_finished)

	_back.pressed.connect(_go_back)
	_info.pressed.connect(func() -> void: _intro.open(level))
	_run_button.pressed.connect(_run.run)
	_pause_button.pressed.connect(_run.pause)
	_step_button.pressed.connect(_run.step)
	_reset_button.pressed.connect(_run.reset)
	_check_button.pressed.connect(_check_all)
	_hint_button.pressed.connect(_show_hint)
	_js_button = _make_js_button()
	_code_button.toggled.connect(_on_code_toggled.bind(CodeView.PYTHON))
	_js_button.toggled.connect(_on_code_toggled.bind(CodeView.JAVASCRIPT))
	var group := ButtonGroup.new()
	_speed_buttons = [%Speed1, %Speed2, %Speed4, %SpeedMax]
	for i in _speed_buttons.size():
		_speed_buttons[i].button_group = group
		_speed_buttons[i].pressed.connect(_set_speed.bind(SPEEDS[i]))
	_set_speed(float(Progress.get_setting("speed", 1.0)))

	_intro.closed.connect(_on_intro_closed)
	_result.retry_requested.connect(func() -> void: _log.show_message("Edit the program and run it again.", "info"))
	_result.next_requested.connect(func() -> void: Game.goto_level(Game.next_level_id(level.id)))
	_result.levels_requested.connect(Game.goto_level_select)

	_on_state_changed(_run.state)
	_log.show_message("%s: %s" % [level.concept, _first_sentence(level.intro)], "info")
	var seen := bool(Progress.data.entry(level.id)["intro_seen"])
	if not Game.dev.has("level"):
		if not seen:
			_intro.open(level)
	_apply_dev_options()


func _go_back() -> void:
	# Applies a half-typed repeat count before saving.
	get_viewport().gui_release_focus()
	_save_program()
	Progress.save()
	Game.goto_level_select()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or k.is_command_or_control_pressed() or k.alt_pressed:
		return
	if _intro.visible or _result.visible:
		return
	var handled := true
	match k.keycode:
		KEY_SPACE:
			if _run.state == RunController.State.RUNNING:
				_run.pause()
			else:
				_run.run()
		KEY_S:
			_run.step()
		KEY_R:
			_run.reset()
		KEY_H:
			_show_hint()
		KEY_C:
			_code_button.button_pressed = not _code_button.button_pressed
		KEY_J:
			_js_button.button_pressed = not _js_button.button_pressed
		KEY_1, KEY_2, KEY_3, KEY_4:
			var i: int = k.keycode - KEY_1
			_speed_buttons[i].button_pressed = true
			_set_speed(SPEEDS[i])
		KEY_ESCAPE:
			_go_back()
		_:
			handled = false
	if handled:
		get_viewport().set_input_as_handled()


## A twin of the Python button, built in code next to it.
func _make_js_button() -> Button:
	var b := Button.new()
	b.name = "JsButton"
	b.text = "JavaScript"
	b.icon = _code_button.icon
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.theme_type_variation = &"ToolButton"
	b.tooltip_text = "Show the program as JavaScript code (J)"
	_code_button.add_sibling(b)
	return b


## Python and JavaScript share one code panel: turning one on turns the other
## off, and the panel closes only when neither is on.
func _on_code_toggled(on: bool, lang: String) -> void:
	var other := _js_button if lang == CodeView.PYTHON else _code_button
	if on:
		other.set_pressed_no_signal(false)
		_editor.show_code(true, lang)
	elif not other.button_pressed:
		_editor.show_code(false)


func _set_speed(s: float) -> void:
	_run.set_speed(s)
	# set_pressed_no_signal() doesn't release the other buttons in the group.
	var i := SPEEDS.find(s)
	for j in _speed_buttons.size():
		_speed_buttons[j].set_pressed_no_signal(j == i)
	if float(Progress.get_setting("speed", 1.0)) != s:
		Progress.set_setting("speed", s)


func _on_state_changed(state: int) -> void:
	var active := state == RunController.State.RUNNING or state == RunController.State.PAUSED
	_run_button.text = "Resume" if state == RunController.State.PAUSED else "Run"
	_run_button.disabled = state == RunController.State.RUNNING
	_pause_button.disabled = state != RunController.State.RUNNING
	_step_button.disabled = state == RunController.State.RUNNING
	_reset_button.disabled = state == RunController.State.IDLE
	_check_button.disabled = active
	for i in _tabs.tab_count:
		_tabs.set_tab_disabled(i, active and i != _tabs.current_tab)


func _on_tab_changed(i: int) -> void:
	if _tab_guard:
		return
	_run.select_variant(i)


func _on_variant_started(i: int) -> void:
	_tab_guard = true
	_tabs.current_tab = i
	_tab_guard = false
	_tabs.set_tab_icon(i, DOT_ICON)
	for t in _tabs.tab_count:
		_tabs.set_tab_disabled(t, t != i)


func _on_variant_finished(i: int, summary: Dictionary) -> void:
	_tabs.set_tab_icon(i, CHECK_ICON if bool(summary["won"]) else CROSS_ICON)
	if bool(summary["won"]):
		_maze.show_banner("ESCAPED!", get_theme_color(&"good", &"Palette"))
	else:
		_maze.show_banner(_short_reason(str(summary["fail_code"])), get_theme_color(&"bad", &"Palette"))


func _on_run_finished(passed: bool, info: Dictionary) -> void:
	var ev := LevelEvaluator.evaluate(level, _editor.get_program_copy())
	_record(ev)
	# A tween callback rather than an await: it simply dies if the screen closes.
	var t := create_tween()
	t.tween_interval(0.9)
	t.tween_callback(_show_run_result.bind(passed, info, ev))


func _show_run_result(passed: bool, info: Dictionary, ev: Dictionary) -> void:
	if _run.state != RunController.State.FINISHED:
		return
	if passed:
		_result.show_success(level, ev, Game.next_level_id(level.id) != "")
	else:
		var summary: Dictionary = info.get("summary", {})
		var vi := int(info.get("variant", 0))
		_result.show_failure(level, ev, level.variants[vi].name, str(summary.get("fail_code", "")),
				str(summary.get("message", "")))


## "Check": runs every map instantly and reports, without animation.
func _check_all() -> void:
	if _run.is_active():
		return
	# Applies a half-typed repeat count, as Run does.
	get_viewport().gui_release_focus()
	var program := _editor.get_program_copy()
	var ev := LevelEvaluator.evaluate(level, program)
	if not bool(ev["valid"]):
		var errs: PackedStringArray = ev["errors"]
		_result.show_failure(level, ev, "", "static", errs[0] if not errs.is_empty() else "")
		return
	var first_fail := -1
	var variants: Array = ev["variants"]
	for i in variants.size():
		var won := bool((variants[i] as Dictionary)["won"])
		_tabs.set_tab_icon(i, CHECK_ICON if won else CROSS_ICON)
		if not won and first_fail < 0:
			first_fail = i
	_record(ev)
	if first_fail < 0:
		_log.show_message("All %d map(s) passed. Press Run to watch it." % variants.size(), "good")
		_result.show_success(level, ev, Game.next_level_id(level.id) != "")
	else:
		var r: Dictionary = variants[first_fail]
		_log.show_message("%s fails: %s" % [level.variants[first_fail].name, str(r["message"])], "bad")
		_result.show_failure(level, ev, level.variants[first_fail].name, str(r["fail_code"]), str(r["message"]))


func _record(ev: Dictionary) -> void:
	if not bool(ev.get("valid", false)):
		return
	Progress.data.record_result(level.id, ev)
	_save_program()
	Progress.save()


func _save_program() -> void:
	Progress.data.set_program(level.id, _editor.get_program_copy())


func _on_program_changed(_structural: bool) -> void:
	_save_program()
	Progress.queue_save()
	if _run.state == RunController.State.FINISHED:
		_run.reset()
	for i in _tabs.tab_count:
		_tabs.set_tab_icon(i, DOT_ICON)


func _on_intro_closed() -> void:
	Progress.data.entry(level.id)["intro_seen"] = true
	Progress.queue_save()


## Opens the hint card, then shows one more hint per press; the last is the full solution.
func _show_hint() -> void:
	_hints.toggle_or_advance()


func _short_reason(code: String) -> String:
	match code:
		"no_stamina":
			return "OUT OF STAMINA"
		"hp_zero":
			return "DESTROYED"
		"program_ended":
			return "PROGRAM ENDED"
		"stack_overflow":
			return "STACK OVERFLOW"
		"op_limit", "action_limit", "idle_loop":
			return "INFINITE LOOP?"
	return "STOPPED"


static func _first_sentence(text: String) -> String:
	var plain := _strip_bbcode(text)
	var dot := plain.find(". ")
	return plain if dot < 0 else plain.substr(0, dot + 1)


static func _strip_bbcode(text: String) -> String:
	var re := RegEx.create_from_string("\\[/?[a-z]+[^\\]]*\\]")
	return re.sub(text, "", true)


func _apply_dev_options() -> void:
	var d := Game.dev
	if str(d.get("level", "")) != level.id:
		return
	match str(d.get("program", "")):
		"solution":
			_editor.set_program(ProgramParser.parse(level.solution_text)["program"])
		"starter":
			_editor.set_program(level.starter_program())
		"empty":
			_editor.set_program(ProgramModel.empty(Array(level.allowed_functions)))
	if d.has("variant"):
		var vi := clampi(int(str(d["variant"])) - 1, 0, level.variants.size() - 1)
		_tab_guard = true
		_tabs.current_tab = vi
		_tab_guard = false
		_run.select_variant(vi)
	if d.has("speed"):
		_set_speed(float(str(d["speed"])))
	if d.has("code"):
		var js := str(d["code"]) == "js"
		(_js_button if js else _code_button).button_pressed = true
	if d.has("intro"):
		_intro.open(level)
	if d.has("hints"):
		for i in clampi(int(str(d["hints"])), 1, level.hints.size()):
			_hints.reveal_next()
	if d.has("steps"):
		_run.fast_forward(int(str(d["steps"])))
	elif d.has("autorun"):
		_run.run()
	if d.has("result"):
		_check_all()
	if d.has("shot"):
		Game.capture_and_quit(str(d["shot"]), 12)
