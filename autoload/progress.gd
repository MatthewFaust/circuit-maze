extends Node
## Loads and saves the player's progress (ProgressData) as a ConfigFile.
## Pass "-- --save=user://dev.cfg" to keep test runs away from real progress.

const DEFAULT_PATH := "user://progress.cfg"
const SAVE_DELAY := 0.6

var path := DEFAULT_PATH
var data := ProgressData.new()
var _timer: Timer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--save="):
			path = arg.substr("--save=".length())
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = SAVE_DELAY
	_timer.timeout.connect(save)
	add_child(_timer)
	load_progress()
	if OS.get_cmdline_user_args().has("--unlock-all"):
		data.settings["unlock_all"] = true
	apply_settings()


func load_progress() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) == OK:
		data = ProgressData.from_config(cfg)


func save() -> void:
	var err := data.to_config().save(path)
	if err != OK:
		push_warning("Could not save progress to %s: %s" % [path, error_string(err)])


## Saves soon; many quick edits become one write.
func queue_save() -> void:
	if _timer != null:
		_timer.start()


func set_setting(key: String, value: Variant) -> void:
	data.settings[key] = value
	apply_settings()
	queue_save()


func get_setting(key: String, default: Variant = null) -> Variant:
	return data.settings.get(key, default)


func apply_settings() -> void:
	ChapterPalette.dark_mode = bool(data.settings.get("dark_mode", false))
	var volume: float = data.settings.get("volume", 0.8)
	var sfx_on: bool = data.settings.get("sfx", true)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(0, not sfx_on or volume <= 0.001)


func reset_progress() -> void:
	var settings := data.settings.duplicate()
	data = ProgressData.new()
	data.settings = settings
	save()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save()
