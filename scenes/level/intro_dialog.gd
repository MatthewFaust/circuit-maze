class_name IntroDialog
extends Control
## The level briefing: what to do, a "CS note" linking it to real computer
## science, the new blocks, and the goals.

signal closed

@onready var _eyebrow: Label = %Eyebrow
@onready var _title: Label = %Title
@onready var _body: RichTextLabel = %Body
@onready var _cs_text: RichTextLabel = %CSText
@onready var _new_row: Control = %NewRow
@onready var _new_blocks: HFlowContainer = %NewBlocks
@onready var _goals: Label = %Goals
@onready var _start: Button = %StartButton


func _ready() -> void:
	_start.pressed.connect(close)
	_start.focus_mode = Control.FOCUS_NONE
	($Dim as ColorRect).color = get_theme_color(&"dim", &"Palette")
	($Center/Panel/VBox/CSNote/CSBox/CSTitle as Label).add_theme_color_override("font_color",
			get_theme_color(&"accent_strong", &"Palette"))


func open(level: LevelData) -> void:
	_eyebrow.text = "CHAPTER %d · LEVEL %d · %s" % [level.chapter, level.number, level.concept.to_upper()]
	_title.text = level.title
	_body.text = level.intro
	_cs_text.text = level.cs_note
	for c in _new_blocks.get_children():
		c.queue_free()
	for kind in level.new_blocks:
		_new_blocks.add_child(_chip(kind))
	_new_row.visible = not level.new_blocks.is_empty()
	_goals.text = goals_text(level)
	show()


func close() -> void:
	hide()
	closed.emit()


static func goals_text(level: LevelData) -> String:
	var parts := PackedStringArray()
	var maps := level.variants.size()
	parts.append("%d map%s to pass" % [maps, "" if maps == 1 else "s"])
	parts.append("max stamina %d per map" % level.variants[0].stamina)
	if level.block_limit > 0:
		parts.append("block limit %d" % level.block_limit)
	parts.append("par: %d blocks, %d stamina%s" % [level.par_blocks, level.par_stamina,
			" in total" if maps > 1 else ""])
	return "  ·  ".join(parts)


func _chip(kind: String) -> Control:
	var p := PanelContainer.new()
	var l := Label.new()
	l.theme_type_variation = &"BlockLabel"
	l.add_theme_font_size_override("font_size", 15)
	if ProgramModel.SENSORS.has(kind):
		p.theme_type_variation = &"BlockSensing"
		l.text = kind + "()"
		p.tooltip_text = BlockCatalog.sensor_tip(kind)
	elif kind == "not":
		p.theme_type_variation = &"BlockSensing"
		l.text = "not"
		p.tooltip_text = "Flips a condition: while not at_exit() keeps going until the exit."
	else:
		p.theme_type_variation = BlockCatalog.variation(kind)
		l.text = BlockCatalog.label(kind) if not kind.begins_with("call:") else "define/call " + kind.substr(5)
		p.tooltip_text = BlockCatalog.tooltip(kind)
	p.add_child(l)
	return p


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel")):
		close()
		get_viewport().set_input_as_handled()
